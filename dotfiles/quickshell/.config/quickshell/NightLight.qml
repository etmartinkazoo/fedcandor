import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: nightScope

    readonly property bool active: ShellState.activePopup === "nightlight"
    readonly property bool enabled: ShellState.settings.nightLight
    readonly property int temperature: ShellState.settings.nightLightTemp
    readonly property string barIcon: enabled ? "󰖔" : "󰖙"

    readonly property var presets: [
        { temp: 3000, label: "3000K", desc: "Candle" },
        { temp: 4000, label: "4000K", desc: "Warm" },
        { temp: 5000, label: "5000K", desc: "Soft" }
    ]

    function toggleEnabled() {
        ShellState.settings.nightLight = !ShellState.settings.nightLight;
    }

    function setTemp(t) {
        ShellState.settings.nightLightTemp = Math.max(2500, Math.min(6000, t));
        ShellState.settings.nightLight = true;
    }

    // wlsunset is owned by this Process: it runs exactly while night light is
    // enabled, so the bar can't drift out of sync with reality. Any stray
    // instance from an older setup is killed once at startup.
    property bool strayKilled: false

    Process {
        command: ["pkill", "-x", "wlsunset"]
        running: true
        onExited: nightScope.strayKilled = true
    }

    Process {
        id: sunset
        running: nightScope.strayKilled && ShellState.settingsLoaded && nightScope.enabled
        command: ["wlsunset", "-t", String(nightScope.temperature), "-T", String(nightScope.temperature + 1)]
    }

    // Restart with the new temperature.
    onTemperatureChanged: {
        if (sunset.running) {
            sunset.running = false;
            Qt.callLater(() => { sunset.running = Qt.binding(() => nightScope.strayKilled && ShellState.settingsLoaded && nightScope.enabled); });
        }
    }

    IpcHandler {
        target: "nightlight"
        function open() { ShellState.openPopup("nightlight"); }
        function hide() { ShellState.closePopup("nightlight"); }
        function toggle() { ShellState.togglePopup("nightlight"); }
        function togglePower() { nightScope.toggleEnabled(); }
        function setTemperature(kelvin: int) { nightScope.setTemp(kelvin); }
    }

    ShellPopup {
        name: "nightlight"
        panelWidth: 424
        defaultRightOffset: 180

        Column {
            id: nlCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onLeftPressed: nightScope.setTemp(nightScope.temperature - 250)
            Keys.onRightPressed: nightScope.setTemp(nightScope.temperature + 250)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_T) nightScope.toggleEnabled();
                else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) nightScope.setTemp(nightScope.presets[event.key - Qt.Key_1].temp);
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "NIGHT LIGHT"
                    Layout.fillWidth: true
                }
                SmallButton {
                    text: nightScope.enabled ? "ON [T]" : "OFF [T]"
                    highlighted: nightScope.enabled
                    onClicked: nightScope.toggleEnabled()
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Caption { text: "COLOR TEMPERATURE (" + nightScope.temperature + "K)" }

                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium
                    Repeater {
                        model: nightScope.presets
                        delegate: OptionTile {
                            required property var modelData
                            required property int index
                            width: (nlCol.width - Theme.spacingMedium * 2) / 3
                            height: 54
                            icon: ""
                            label: modelData.label
                            sublabel: modelData.desc + " [" + (index + 1) + "]"
                            selected: nightScope.enabled && nightScope.temperature === modelData.temp
                            onClicked: nightScope.setTemp(modelData.temp)
                        }
                    }
                }

                Meter {
                    width: parent.width
                    height: 14
                    interactive: true
                    // 6000K (left, neutral) .. 2500K (right, warm)
                    value: (6000 - nightScope.temperature) / 3500
                    onMoved: function(v) { nightScope.setTemp(Math.round((6000 - v * 3500) / 50) * 50); }
                }
            }

            Hint { text: "1-3 preset • ←/→ or drag fine tune • [T] toggle • Esc close" }
        }
    }
}
