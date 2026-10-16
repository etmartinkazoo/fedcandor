import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking as Net

Scope {
    id: wifiScope

    readonly property bool active: ShellState.activePopup === "wifi"
    property int selectedIndex: 0
    property string passwordSsid: ""
    property bool customDnsVisible: false
    property string dnsMode: ""        // "cloudflare" | "custom" | "" (automatic); read from NM on open
    property string customDnsValue: ""
    property string connectingSsid: ""

    readonly property bool isEnabled: Net.Networking.wifiEnabled

    readonly property var wifiDevice: {
        const devs = Net.Networking.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === Net.DeviceType.Wifi) return devs[i];
        }
        return null;
    }

    onActiveChanged: {
        if (wifiDevice) wifiDevice.scannerEnabled = active;
        passwordSsid = "";
        customDnsVisible = false;
        if (active) {
            selectedIndex = 0;
            dnsReadProc.running = true;
        }
    }

    readonly property var sortedNetworks: {
        if (!wifiDevice || !wifiDevice.networks || !isEnabled) return [];
        const raw = wifiDevice.networks.values;
        const seen = {};
        for (let i = 0; i < raw.length; i++) {
            const n = raw[i];
            if (!n || !n.name || n.name.trim() === "") continue;
            const prev = seen[n.name];
            if (!prev || (n.connected && !prev.connected) || (!prev.connected && n.signalStrength > prev.signalStrength)) {
                seen[n.name] = n;
            }
        }
        const list = Object.keys(seen).map(k => seen[k]);
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return list;
    }

    onSortedNetworksChanged: {
        if (selectedIndex >= sortedNetworks.length) selectedIndex = Math.max(0, sortedNetworks.length - 1);
    }

    // Diffing model: signal-strength updates reorder rows in place instead of
    // rebuilding the list and jumping the scroll position to the top.
    ScriptModel {
        id: netModel
        values: wifiScope.sortedNetworks
    }

    readonly property var connectedNet: {
        for (let i = 0; i < sortedNetworks.length; i++) {
            if (sortedNetworks[i].connected) return sortedNetworks[i];
        }
        return null;
    }

    function signalIcon(net) {
        if (!net) return "󰤯";
        const s = net.signalStrength;
        if (s >= 0.75) return "󰤨";
        if (s >= 0.50) return "󰤥";
        if (s >= 0.25) return "󰤢";
        return "󰤟";
    }

    readonly property string barIcon: !isEnabled ? "󰤭" : (connectedNet ? signalIcon(connectedNet) : "󰤯")

    function move(delta) {
        const n = sortedNetworks.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        netList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function selectedNetwork() {
        return selectedIndex >= 0 && selectedIndex < sortedNetworks.length ? sortedNetworks[selectedIndex] : null;
    }

    function activateNetwork(net) {
        if (!net) return;
        if (net.connected) {
            net.disconnect();
            return;
        }
        if (net.known || net.security === Net.WifiSecurityType.Open) {
            net.connect();
            return;
        }
        customDnsVisible = false;
        passwordSsid = net.name;
        passInput.text = "";
        passInput.focusInput();
    }

    // The password goes over stdin (nmcli --ask), never on the command line.
    function submitPassword() {
        const ssid = passwordSsid;
        const pass = passInput.text;
        passwordSsid = "";
        passInput.text = "";
        keyRoot.forceActiveFocus();
        if (ssid === "" || pass === "" || connectProc.running) return;
        connectingSsid = ssid;
        connectProc.pendingPassword = pass;
        connectProc.command = ["nmcli", "--ask", "device", "wifi", "connect", ssid];
        connectProc.running = true;
    }

    Process {
        id: connectProc
        property string pendingPassword: ""
        stdinEnabled: true
        stderr: StdioCollector { id: connectErr }
        onStarted: {
            write(pendingPassword + "\n");
            pendingPassword = "";
            stdinEnabled = false;
        }
        onExited: function(code) {
            if (code !== 0) {
                Quickshell.execDetached(["notify-send", "-u", "normal", "Wi-Fi",
                    "Couldn't connect to " + wifiScope.connectingSsid + ": " + (connectErr.text.trim() || ("exit " + code))]);
            }
            wifiScope.connectingSsid = "";
            stdinEnabled = true;
        }
    }

    // ---- DNS ----
    // Shared prelude: finds the active connection/device. Values are passed as
    // positional args ($1 = servers or "auto", $2 = label), never interpolated.
    readonly property string dnsPrelude:
        "CONN=$(nmcli -t -f NAME,TYPE connection show --active | awk -F: '$2 ~ /wireless|ethernet/ {print $1; exit}'); " +
        "DEV=$(nmcli -t -f DEVICE,STATE device | awk -F: '$2==\"connected\"{print $1; exit}'); " +
        "[ -n \"$CONN\" ] || exit 1; "

    function applyDns(servers, label) {
        const v4 = [], v6 = [];
        servers.trim().split(/[\s,]+/).forEach(s => {
            if (s === "" || s === "auto") return;
            if (s.indexOf(":") >= 0) v6.push(s); else v4.push(s);
        });
        const script = dnsPrelude +
            "if [ \"$1\" = auto ]; then " +
            "  nmcli connection modify \"$CONN\" ipv4.ignore-auto-dns no ipv4.dns '' ipv6.ignore-auto-dns no ipv6.dns ''; " +
            "else " +
            "  nmcli connection modify \"$CONN\" ipv4.ignore-auto-dns yes ipv4.dns \"$2\" ipv6.ignore-auto-dns yes ipv6.dns \"$3\"; " +
            "fi && " +
            "(nmcli device reapply \"$DEV\" 2>/dev/null || nmcli connection up \"$CONN\") && " +
            "notify-send -t 2500 'DNS Updated' \"$4\"";
        const mode = v4.length + v6.length === 0 ? "auto" : "set";
        Quickshell.execDetached(["sh", "-c", script, "_", mode, v4.join(" "), v6.join(" "), label]);
    }

    readonly property string cloudflareServers: "1.1.1.1 1.0.0.1 2606:4700:4700::1111 2606:4700:4700::1001"

    function setCloudflareDns() {
        customDnsVisible = false;
        dnsMode = "cloudflare";
        applyDns(cloudflareServers, "Cloudflare (1.1.1.1)");
        keyRoot.forceActiveFocus();
    }

    function toggleCustomDns() {
        passwordSsid = "";
        customDnsVisible = !customDnsVisible;
        if (customDnsVisible) {
            dnsInput.text = customDnsValue;
            dnsInput.focusInput();
        } else {
            keyRoot.forceActiveFocus();
        }
    }

    function submitCustomDns() {
        const val = dnsInput.text.trim();
        customDnsVisible = false;
        keyRoot.forceActiveFocus();
        if (val === "") return;
        if (val.toLowerCase() === "auto") {
            dnsMode = "";
            customDnsValue = "";
            applyDns("auto", "Automatic (DHCP)");
        } else {
            dnsMode = "custom";
            customDnsValue = val;
            applyDns(val, "Custom (" + val + ")");
        }
    }

    // Reads the active connection's DNS settings so the buttons reflect reality.
    Process {
        id: dnsReadProc
        command: ["sh", "-c", wifiScope.dnsPrelude + "nmcli -g ipv4.ignore-auto-dns,ipv4.dns connection show \"$CONN\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length < 2 || lines[0] !== "yes" || lines[1].trim() === "") {
                    wifiScope.dnsMode = "";
                    return;
                }
                const servers = lines[1].replace(/\\/g, "").split(",").map(s => s.trim()).join(" ");
                if (servers.indexOf("1.1.1.1") === 0) {
                    wifiScope.dnsMode = "cloudflare";
                } else {
                    wifiScope.dnsMode = "custom";
                    wifiScope.customDnsValue = servers;
                }
            }
        }
    }

    IpcHandler {
        target: "wifi"
        function open() { ShellState.openPopup("wifi"); }
        function hide() { ShellState.closePopup("wifi"); }
        function toggle() { ShellState.togglePopup("wifi"); }
    }

    component DnsButton: Rectangle {
        id: db
        property string text: ""
        property bool selected: false
        signal clicked()
        height: Theme.rowHeightCompact
        color: selected || dbMouse.containsMouse ? Theme.bgSelected : Theme.bgItem
        border.color: selected ? Theme.border : Theme.borderSubtle
        border.width: Theme.borderWidth
        radius: Theme.radius

        Text {
            anchors.centerIn: parent
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: db.text
            color: db.selected ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
        }

        MouseArea {
            id: dbMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: db.clicked()
        }
    }

    component InlineInput: Rectangle {
        id: ii
        property alias text: tf.text
        property alias placeholderText: tf.placeholderText
        property alias echoMode: tf.echoMode
        signal accepted()
        signal escaped()
        function focusInput() { tf.forceActiveFocus(); }

        height: Theme.rowHeight
        color: Theme.bgItem
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius

        TextField {
            id: tf
            anchors.fill: parent
            leftPadding: Theme.inputPadding
            rightPadding: Theme.inputPadding
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            color: Theme.textPrimary
            placeholderTextColor: Theme.textPlaceholder
            background: Item {}
            onAccepted: ii.accepted()
            Keys.onEscapePressed: ii.escaped()
        }
    }

    ShellPopup {
        name: "wifi"
        panelHeight: 430
        defaultRightOffset: 70

        Item {
            id: keyRoot
            anchors.fill: parent
            focus: true

                Keys.onDownPressed: wifiScope.move(1)
                Keys.onUpPressed: wifiScope.move(-1)
                Keys.onReturnPressed: wifiScope.activateNetwork(wifiScope.selectedNetwork())
                Keys.onEnterPressed: wifiScope.activateNetwork(wifiScope.selectedNetwork())
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_T) {
                        Net.Networking.wifiEnabled = !Net.Networking.wifiEnabled;
                    } else if (event.key === Qt.Key_R && wifiScope.isEnabled) {
                        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
                    } else if (event.key === Qt.Key_F) {
                        const net = wifiScope.selectedNetwork();
                        if (net && net.known) net.forget();
                    } else {
                        return;
                    }
                    event.accepted = true;
                }

        Column {
            id: mainCol
            anchors.fill: parent
            spacing: Theme.spacingMedium

            RowLayout {
                width: parent.width
                height: Theme.headerHeight

                PanelTitle {
                    text: wifiScope.connectingSsid !== "" ? "WI-FI • connecting…" : "WI-FI"
                    Layout.fillWidth: true
                }

                SmallButton {
                    visible: wifiScope.isEnabled
                    text: "SCAN [R]"
                    onClicked: Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"])
                }

                SmallButton {
                    text: wifiScope.isEnabled ? "ON [T]" : "OFF [T]"
                    highlighted: wifiScope.isEnabled
                    onClicked: Net.Networking.wifiEnabled = !Net.Networking.wifiEnabled
                }
            }

            Column {
                id: dnsSection
                width: parent.width
                spacing: Theme.paddingSmall

                Caption { text: "DNS" + (wifiScope.dnsMode === "" ? " (automatic)" : "") }

                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium

                    DnsButton {
                        width: (mainCol.width - Theme.spacingMedium) / 2
                        text: "Cloudflare"
                        selected: wifiScope.dnsMode === "cloudflare"
                        onClicked: wifiScope.setCloudflareDns()
                    }

                    DnsButton {
                        width: (mainCol.width - Theme.spacingMedium) / 2
                        text: wifiScope.dnsMode === "custom" && wifiScope.customDnsValue !== ""
                            ? "Custom (" + wifiScope.customDnsValue + ")" : "Custom"
                        selected: wifiScope.dnsMode === "custom" || wifiScope.customDnsVisible
                        onClicked: wifiScope.toggleCustomDns()
                    }
                }

                InlineInput {
                    id: dnsInput
                    width: parent.width
                    visible: wifiScope.customDnsVisible
                    placeholderText: "DNS servers (e.g. 9.9.9.9 2620:fe::fe) or auto"
                    onAccepted: wifiScope.submitCustomDns()
                    onEscaped: {
                        wifiScope.customDnsVisible = false;
                        keyRoot.forceActiveFocus();
                    }
                }
            }

            InlineInput {
                id: passInput
                width: parent.width
                visible: wifiScope.passwordSsid !== ""
                echoMode: TextInput.Password
                placeholderText: "Password for " + wifiScope.passwordSsid + "..."
                onAccepted: wifiScope.submitPassword()
                onEscaped: {
                    wifiScope.passwordSsid = "";
                    keyRoot.forceActiveFocus();
                }
            }

            ListView {
                id: netList
                width: parent.width
                height: parent.height - 28 - dnsSection.height - (passInput.visible ? passInput.height + Theme.spacingMedium : 0)
                    - wifiHint.implicitHeight - Theme.spacingMedium * 3
                clip: true
                model: netModel
                currentIndex: wifiScope.selectedIndex
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: netList.width
                    selected: index === wifiScope.selectedIndex
                    outlined: modelData.connected
                    onEntered: wifiScope.selectedIndex = index
                    onClicked: {
                        wifiScope.selectedIndex = index;
                        wifiScope.activateNetwork(modelData);
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingMedium

                        Text {
                            text: wifiScope.signalIcon(modelData)
                            color: modelData.connected ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLarge
                        }

                        Text {
                            text: modelData.name
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.security !== Net.WifiSecurityType.Open
                            text: "󰌾"
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            text: Math.round((modelData.signalStrength || 0) * 100) + "%"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }

                        Text {
                            text: modelData.connected ? "Connected"
                                : (modelData.stateChanging || wifiScope.connectingSsid === modelData.name) ? "..."
                                : (modelData.known ? "Saved" : "")
                            color: modelData.connected ? Theme.textPrimary : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                            visible: text !== ""
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: wifiScope.sortedNetworks.length === 0
                    text: !wifiScope.isEnabled ? "Wi-Fi is disabled ([T] to enable)"
                        : !wifiScope.wifiDevice ? "No Wi-Fi device"
                        : "Scanning... ([R] to rescan)"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                }
            }

            Hint {
                id: wifiHint
                text: "↑/↓ select • Enter connect • [R] scan • [F] forget • [T] power"
            }
        }
        }
    }
}
