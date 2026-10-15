import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: powerScope

    readonly property bool active: ShellState.activePopup === "power"
    property int selectedIndex: 0
    property int armedIndex: -1   // destructive actions need a second press

    readonly property var actions: [
        { id: "lock", label: "Lock", key: "L", icon: "󰌾", confirm: false, cmd: ["loginctl", "lock-session"] },
        { id: "suspend", label: "Suspend", key: "S", icon: "󰤄", confirm: false, cmd: ["systemctl", "suspend"] },
        { id: "logout", label: "Exit Sway", key: "E", icon: "󰍃", confirm: true, cmd: ["swaymsg", "exit"] },
        { id: "reboot", label: "Reboot", key: "R", icon: "󰜉", confirm: true, cmd: ["systemctl", "reboot"] },
        { id: "poweroff", label: "Power Off", key: "P", icon: "⏻", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    onActiveChanged: {
        selectedIndex = 0;
        armedIndex = -1;
    }

    function trigger(index) {
        if (index < 0 || index >= actions.length) return;
        const item = actions[index];
        selectedIndex = index;
        if (item.confirm && armedIndex !== index) {
            armedIndex = index;
            disarmTimer.restart();
            return;
        }
        ShellState.closePopup("power");
        Quickshell.execDetached(item.cmd);
    }

    Timer {
        id: disarmTimer
        interval: 3000
        onTriggered: powerScope.armedIndex = -1
    }

    IpcHandler {
        target: "power"
        function open() { ShellState.openPopup("power"); }
        function hide() { ShellState.closePopup("power"); }
        function toggle() { ShellState.togglePopup("power"); }
    }

    ShellPopup {
        name: "power"
        panelWidth: 536
        defaultRightOffset: 20

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            readonly property int count: powerScope.actions.length
            Keys.onLeftPressed: powerScope.selectedIndex = (powerScope.selectedIndex + count - 1) % count
            Keys.onUpPressed: powerScope.selectedIndex = (powerScope.selectedIndex + count - 1) % count
            Keys.onRightPressed: powerScope.selectedIndex = (powerScope.selectedIndex + 1) % count
            Keys.onDownPressed: powerScope.selectedIndex = (powerScope.selectedIndex + 1) % count
            Keys.onReturnPressed: powerScope.trigger(powerScope.selectedIndex)
            Keys.onEnterPressed: powerScope.trigger(powerScope.selectedIndex)
            Keys.onPressed: function(event) {
                const keys = [Qt.Key_L, Qt.Key_S, Qt.Key_E, Qt.Key_R, Qt.Key_P];
                let idx = keys.indexOf(event.key);
                if (idx < 0 && event.key >= Qt.Key_1 && event.key <= Qt.Key_5) idx = event.key - Qt.Key_1;
                if (idx >= 0) {
                    powerScope.trigger(idx);
                    event.accepted = true;
                }
            }

            PanelTitle { text: "POWER MENU" }

            Row {
                width: parent.width
                spacing: Theme.spacingMedium

                Repeater {
                    model: powerScope.actions
                    delegate: OptionTile {
                        required property var modelData
                        required property int index
                        readonly property bool armed: powerScope.armedIndex === index
                        width: (contentCol.width - Theme.spacingMedium * (contentCol.count - 1)) / contentCol.count
                        height: 88
                        iconSize: 20
                        icon: modelData.icon
                        label: armed ? "Press again" : modelData.label
                        sublabel: "[" + modelData.key + "]"
                        selected: powerScope.selectedIndex === index
                        border.color: armed ? Theme.borderCritical : (selected ? Theme.border : Theme.borderSubtle)
                        color: armed ? Theme.bgCritical : (selected || hovered ? Theme.bgSelected : Theme.bgItem)
                        onEntered: powerScope.selectedIndex = index
                        onClicked: powerScope.trigger(index)
                    }
                }
            }

            Hint {
                text: powerScope.armedIndex >= 0
                    ? "Press " + powerScope.actions[powerScope.armedIndex].key + " / Enter again to confirm • Esc to cancel"
                    : "←/→ select • Enter or [L/S/E/R/P] • Exit/Reboot/Power Off ask twice"
            }
        }
    }
}
