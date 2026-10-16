import QtQuick
import QtQuick.Layouts

import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth as BT

Scope {
    id: btScope

    readonly property bool active: ShellState.activePopup === "bluetooth"
    property int selectedIndex: 0

    // Action feedback (pair/connect/disconnect)
    property string pendingAddress: ""
    property string pendingAction: ""   // "pairing" | "connecting" | "disconnecting"
    property string failedAddress: ""

    readonly property var adapter: BT.Bluetooth.defaultAdapter
    readonly property bool isEnabled: adapter ? adapter.enabled : false
    readonly property bool isBlocked: adapter ? adapter.state === BT.BluetoothAdapterState.Blocked : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false

    readonly property var sortedDevices: {
        const raw = BT.Bluetooth.devices.values;
        const list = [];
        for (let i = 0; i < raw.length; i++) {
            const d = raw[i];
            if (d && (d.name || d.deviceName || d.paired || d.connected)) {
                list.push(d);
            }
        }
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            const na = (a.name || a.deviceName || a.address || "").toLowerCase();
            const nb = (b.name || b.deviceName || b.address || "").toLowerCase();
            return na.localeCompare(nb);
        });
        return list;
    }

    readonly property int connectedCount: {
        let c = 0;
        for (let i = 0; i < sortedDevices.length; i++) {
            if (sortedDevices[i].connected) c++;
        }
        return c;
    }

    readonly property string barIcon: {
        if (!isEnabled) return "󰂲";
        if (connectedCount > 0) return "󰂱";
        return "󰂯";
    }

    // Keep discovery on while the panel is open so the list stays fresh and
    // a clicked device is actually reachable when we try to pair/connect.
    // The adapter is only pairable while this panel is open, so nothing can
    // start a new pairing in the background. Existing devices still reconnect.
    onActiveChanged: {
        if (active) {
            selectedIndex = 0;
            if (adapter && adapter.enabled && !adapter.discovering) adapter.discovering = true;
        } else if (adapter && adapter.discovering) {
            adapter.discovering = false;
        }
        syncPairable();
    }

    function syncPairable() {
        if (adapter && adapter.enabled && adapter.pairable !== active) adapter.pairable = active;
    }

    onAdapterChanged: syncPairable()
    onIsEnabledChanged: syncPairable()

    // bluetoothd starts pairable; turn that off once the adapter has loaded.
    Timer {
        interval: 3000
        running: true
        onTriggered: btScope.syncPairable()
    }

    // Tell the deny-by-default agent that the user initiated this device.
    function allowInAgent(addr) {
        if (bluezAgent.running) bluezAgent.write("allow " + addr + "\n");
    }

    // Turning on a soft-blocked adapter silently fails, so unblock rfkill first.
    function togglePower() {
        if (adapter && adapter.enabled) {
            adapter.enabled = false;
            return;
        }
        Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
        enableTimer.restart();
    }

    Timer {
        id: enableTimer
        interval: 800
        onTriggered: if (btScope.adapter) btScope.adapter.enabled = true
    }

    function move(delta) {
        const n = sortedDevices.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        devList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    function activateSelected() {
        if (selectedIndex >= 0 && selectedIndex < sortedDevices.length) deviceAction(sortedDevices[selectedIndex]);
    }

    function clearPending() {
        if (pendingAddress !== "" && bluezAgent.running) bluezAgent.write("revoke " + pendingAddress + "\n");
        pendingAddress = "";
        pendingAction = "";
    }

    function markFailed(addr) {
        clearPending();
        failedAddress = addr;
        failTimer.restart();
    }

    function deviceByAddress(addr) {
        const list = sortedDevices;
        for (let i = 0; i < list.length; i++) {
            if (list[i].address === addr) return list[i];
        }
        return null;
    }

    function deviceAction(dev) {
        if (!dev || !dev.address) return;
        failedAddress = "";

        if (dev.pairing) {                 // cancel an in-progress pairing
            dev.cancelPair();
            clearPending();
            return;
        }

        if (dev.connected) {
            pendingAddress = dev.address;
            pendingAction = "disconnecting";
            pendingTimer.restart();
            dev.disconnect();
            return;
        }

        if (dev.paired || dev.bonded) {    // bonded: connect directly
            pendingAddress = dev.address;
            pendingAction = "connecting";
            pendingTimer.restart();
            allowInAgent(dev.address);   // untrusted devices may need service authorization
            dev.connect();
            return;
        }

        // Unpaired: pair natively. The bundled BlueZ agent answers the pairing
        // requests; on success the delegate below auto-connects.
        pendingAddress = dev.address;
        pendingAction = "pairing";
        pendingTimer.restart();
        allowInAgent(dev.address);
        dev.pair();
    }

    IpcHandler {
        target: "bluetooth"
        function open() { ShellState.openPopup("bluetooth"); }
        function hide() { ShellState.closePopup("bluetooth"); }
        function toggle() { ShellState.togglePopup("bluetooth"); }
        function togglePower() { btScope.togglePower(); }
    }

    // Persistent BlueZ pairing agent. BlueZ refuses to pair without a
    // registered agent and Quickshell does not provide one. The agent rejects
    // everything except devices allowed via stdin (see allowInAgent()).
    Process {
        id: bluezAgent
        command: [Quickshell.env("HOME") + "/.local/bin/quickshell-bluez-agent"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: function(line) { console.log("bluez-agent:", line) }
        }
        stderr: SplitParser {
            onRead: function(line) { console.log("bluez-agent[err]:", line) }
        }
        onExited: function(code) {
            console.log("bluez-agent exited:", code);
            agentRestart.restart();
        }
    }

    Timer {
        id: agentRestart
        interval: 2000
        repeat: false
        onTriggered: bluezAgent.running = true
    }

    // Safety net: surface a failure if an action stalls.
    Timer {
        id: pendingTimer
        interval: 25000
        repeat: false
        onTriggered: {
            if (btScope.pendingAddress === "") return;
            if (btScope.pendingAction === "disconnecting") btScope.clearPending();
            else btScope.markFailed(btScope.pendingAddress);
        }
    }

    // Pairing ended without bonding.
    Timer {
        id: pairFailTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (btScope.pendingAction !== "pairing") return;
            const d = btScope.deviceByAddress(btScope.pendingAddress);
            if (d && !d.paired && !d.pairing) btScope.markFailed(d.address);
        }
    }

    Timer {
        id: failTimer
        interval: 4000
        repeat: false
        onTriggered: btScope.failedAddress = ""
    }

    // Diffing model: reorders update rows in place instead of rebuilding the
    // list, so clicking a device no longer scrolls the ListView to the top.
    ScriptModel {
        id: devModel
        values: btScope.isEnabled ? btScope.sortedDevices : []
    }

    ShellPopup {
        name: "bluetooth"
        panelHeight: 360
        defaultRightOffset: 100

        Column {
            anchors.fill: parent
            spacing: Theme.spacingMedium
            focus: true

            Keys.onDownPressed: btScope.move(1)
            Keys.onUpPressed: btScope.move(-1)
            Keys.onReturnPressed: btScope.activateSelected()
            Keys.onEnterPressed: btScope.activateSelected()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_T) {
                    btScope.togglePower();
                } else if (event.key === Qt.Key_S && btScope.adapter && btScope.isEnabled) {
                    btScope.adapter.discovering = !btScope.adapter.discovering;
                } else if (event.key === Qt.Key_F && btScope.selectedIndex >= 0 && btScope.selectedIndex < btScope.sortedDevices.length) {
                    btScope.sortedDevices[btScope.selectedIndex].forget();
                } else {
                    return;
                }
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                height: Theme.headerHeight

                PanelTitle {
                    text: "BLUETOOTH"
                    Layout.fillWidth: true
                }

                SmallButton {
                    visible: btScope.isEnabled
                    text: btScope.isDiscovering ? "SCAN... [S]" : "SCAN [S]"
                    highlighted: btScope.isDiscovering
                    onClicked: if (btScope.adapter) btScope.adapter.discovering = !btScope.adapter.discovering
                }

                SmallButton {
                    text: btScope.isBlocked ? "BLOCKED [T]" : (btScope.isEnabled ? "ON [T]" : "OFF [T]")
                    highlighted: btScope.isEnabled
                    critical: btScope.isBlocked
                    onClicked: btScope.togglePower()
                }
            }

            ListView {
                id: devList
                width: parent.width
                height: parent.height - 28 - btHint.implicitHeight - Theme.spacingMedium * 2
                clip: true
                model: devModel
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: devList.width
                    height: Theme.rowHeight
                    readonly property bool isPending: btScope.pendingAddress === modelData.address
                    readonly property bool isFailed: btScope.failedAddress === modelData.address
                    readonly property string statusText: {
                        if (isFailed) return "Failed";
                        if (modelData.connected) return "Connected";
                        if (isPending) {
                            if (btScope.pendingAction === "pairing") return "Pairing…";
                            if (btScope.pendingAction === "disconnecting") return "Disconnecting…";
                            return "Connecting…";
                        }
                        if (modelData.pairing) return "Pairing…";
                        if (modelData.paired) return "Paired";
                        return "Available";
                    }
                    selected: index === btScope.selectedIndex
                    outlined: modelData.connected
                    critical: isFailed
                    onEntered: btScope.selectedIndex = index
                    onClicked: {
                        btScope.selectedIndex = index;
                        btScope.deviceAction(modelData);
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingMedium

                        Text {
                            text: modelData.connected ? "󰂱" : (modelData.paired ? "󰂯" : "󰂰")
                            color: modelData.connected ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLarge
                        }

                        Text {
                            text: modelData.name || modelData.deviceName || modelData.address
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.batteryAvailable
                            text: Math.round(modelData.battery * (modelData.battery <= 1.0 ? 100 : 1)) + "%"
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                        }

                        Text {
                            text: statusText
                            color: isFailed ? Theme.borderCritical : (modelData.connected ? Theme.textPrimary : Theme.textMuted)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSmall
                        }
                    }

                    Connections {
                        target: modelData

                        // Tell the UI once an action settles.
                        function onConnectedChanged() {
                            if (modelData.connected && btScope.pendingAddress === modelData.address)
                                btScope.clearPending();
                        }

                        // Bonded: trust (for auto-reconnect) then connect.
                        function onPairedChanged() {
                            if (modelData.paired
                                    && btScope.pendingAddress === modelData.address
                                    && !modelData.connected && !modelData.pairing) {
                                modelData.trusted = true;
                                btScope.pendingAction = "connecting";
                                modelData.connect();
                            }
                        }

                        // Pairing stopped without bonding -> report failure.
                        function onPairingChanged() {
                            if (btScope.pendingAddress !== modelData.address) return;
                            if (modelData.pairing || modelData.paired) return;
                            pairFailTimer.restart();
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: !btScope.isEnabled || btScope.sortedDevices.length === 0
                    text: !btScope.adapter ? "No Bluetooth adapter ([T] to unblock)"
                        : btScope.isBlocked ? "Bluetooth is blocked by rfkill ([T] to unblock)"
                        : !btScope.isEnabled ? "Bluetooth is disabled ([T] to enable)"
                        : (btScope.isDiscovering ? "Scanning for devices..." : "No devices ([S] to scan)")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                }
            }

            Hint {
                id: btHint
                text: "↑/↓ select • Enter connect • [S] scan • [F] forget • [T] power"
            }
        }
    }
}
