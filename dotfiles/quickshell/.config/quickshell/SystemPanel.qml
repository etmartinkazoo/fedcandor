import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// System panel (the bar's right-most button): battery, CPU/memory/temperature,
// power profiles and session actions in one place. Replaces the separate
// battery, system-monitor and power-menu buttons.
Scope {
    id: sys

    required property var battery   // Battery.qml
    required property var sysmon    // SysMon.qml

    readonly property bool active: ShellState.activePopup === "system"
    property int armedIndex: -1     // destructive actions need a second press

    readonly property var actions: [
        { label: "Lock", key: "L", icon: "󰌾", confirm: false, cmd: ["loginctl", "lock-session"] },
        { label: "Suspend", key: "S", icon: "󰤄", confirm: false, cmd: ["systemctl", "suspend"] },
        { label: "Log out", key: "E", icon: "󰍃", confirm: true, cmd: ["swaymsg", "exit"] },
        { label: "Reboot", key: "R", icon: "󰜉", confirm: true, cmd: ["systemctl", "reboot"] },
        { label: "Power off", key: "P", icon: "⏻", confirm: true, cmd: ["systemctl", "poweroff"] }
    ]

    // Bar pill: battery if there is one, otherwise just the power symbol.
    readonly property string barText: battery.hasBattery ? battery.barText + "  ⏻" : "⏻"

    onActiveChanged: armedIndex = -1

    function trigger(index) {
        const item = actions[index];
        if (!item) return;
        if (item.confirm && armedIndex !== index) {
            armedIndex = index;
            disarm.restart();
            return;
        }
        ShellState.closePopup("system");
        Quickshell.execDetached(item.cmd);
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: sys.armedIndex = -1
    }

    IpcHandler {
        target: "power"
        function open() { ShellState.openPopup("system"); }
        function hide() { ShellState.closePopup("system"); }
        function toggle() { ShellState.togglePopup("system"); }
    }

    IpcHandler {
        target: "system"
        function open() { ShellState.openPopup("system"); }
        function hide() { ShellState.closePopup("system"); }
        function toggle() { ShellState.togglePopup("system"); }
    }

    component Stat: Column {
        id: stat
        property string label
        property string value
        property real fraction
        property bool hot: false
        spacing: 4
        RowLayout {
            width: parent.width
            Caption { text: stat.label; Layout.fillWidth: true }
            Text {
                text: stat.value
                color: stat.hot ? Theme.borderCritical : Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
            }
        }
        Meter {
            width: parent.width
            height: 6
            value: stat.fraction
            critical: stat.hot
        }
    }

    ShellPopup {
        name: "system"
        panelWidth: 460
        defaultRightOffset: 40

        Column {
            id: col
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onPressed: function(event) {
                const keys = [Qt.Key_L, Qt.Key_S, Qt.Key_E, Qt.Key_R, Qt.Key_P];
                const idx = keys.indexOf(event.key);
                if (idx >= 0) {
                    sys.trigger(idx);
                } else if (event.key === Qt.Key_1) {
                    PowerProfiles.profile = PowerProfile.PowerSaver;
                } else if (event.key === Qt.Key_2) {
                    PowerProfiles.profile = PowerProfile.Balanced;
                } else if (event.key === Qt.Key_3 && PowerProfiles.hasPerformanceProfile) {
                    PowerProfiles.profile = PowerProfile.Performance;
                } else if (event.key === Qt.Key_M) {
                    sys.sysmon.openMonitor();
                    ShellState.closePopup("system");
                } else {
                    return;
                }
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "SYSTEM"
                    Layout.fillWidth: true
                }
                Caption {
                    text: sys.battery.hasBattery
                        ? sys.battery.pct + "% • " + sys.battery.stateText
                        : sys.battery.stateText
                    color: sys.battery.isLow ? Theme.borderCritical : Theme.textSecondary
                }
            }

            // Battery
            Column {
                width: parent.width
                spacing: 4
                visible: sys.battery.hasBattery

                Meter {
                    width: parent.width
                    height: 14
                    value: sys.battery.pct / 100
                    critical: sys.battery.isLow
                }
                RowLayout {
                    width: parent.width
                    Caption {
                        text: sys.battery.timeText
                        Layout.fillWidth: true
                    }
                    Caption {
                        visible: sys.battery.dev && sys.battery.dev.healthSupported
                        text: sys.battery.dev ? "Health " + Math.round(sys.battery.dev.healthPercentage) + "%" : ""
                    }
                }
                Caption {
                    visible: sys.battery.suspendPending
                    text: "Suspending soon: plug in to cancel"
                    color: Theme.borderCritical
                }
            }

            // Load
            Row {
                width: parent.width
                spacing: Theme.spacingLarge
                readonly property real w: (width - spacing * 2) / 3

                Stat {
                    width: parent.w
                    label: "CPU"
                    value: Math.round(sys.sysmon.cpuPct) + "%"
                    fraction: sys.sysmon.cpuPct / 100
                    hot: sys.sysmon.cpuPct >= 90
                }
                Stat {
                    width: parent.w
                    label: "MEMORY"
                    value: Math.round(sys.sysmon.memPct) + "%"
                    fraction: sys.sysmon.memPct / 100
                    hot: sys.sysmon.memPct >= 90
                }
                Stat {
                    width: parent.w
                    label: "TEMP"
                    value: sys.sysmon.tempC > 0 ? Math.round(sys.sysmon.tempC) + "°C" : "n/a"
                    fraction: sys.sysmon.tempC / 100
                    hot: sys.sysmon.tempC >= 85
                }
            }

            // Power profile
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                Caption { text: "POWER PROFILE" }
                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium
                    Repeater {
                        model: sys.battery.profiles
                        delegate: OptionTile {
                            required property var modelData
                            required property int index
                            width: (col.width - Theme.spacingMedium * 2) / 3
                            height: 60
                            iconSize: 15
                            icon: modelData.icon
                            label: modelData.label + " [" + (index + 1) + "]"
                            selected: PowerProfiles.profile === modelData.profile
                            enabled: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                            onClicked: PowerProfiles.profile = modelData.profile
                        }
                    }
                }
            }

            // Session
            Row {
                width: parent.width
                spacing: Theme.spacingMedium
                Repeater {
                    model: sys.actions
                    delegate: OptionTile {
                        required property var modelData
                        required property int index
                        readonly property bool armed: sys.armedIndex === index
                        width: (col.width - Theme.spacingMedium * 4) / 5
                        height: 74
                        icon: modelData.icon
                        label: armed ? "Again" : modelData.label
                        sublabel: "[" + modelData.key + "]"
                        selected: armed
                        border.color: armed ? Theme.borderCritical : (hovered ? Theme.border : Theme.borderSubtle)
                        color: armed ? Theme.bgCritical : (hovered ? Theme.bgSelected : Theme.bgItem)
                        onClicked: sys.trigger(index)
                    }
                }
            }

            Hint {
                text: sys.armedIndex >= 0
                    ? "Press " + sys.actions[sys.armedIndex].key + " again to confirm • Esc to cancel"
                    : "L/S/E/R/P session • 1-3 profile • M task manager • Esc close"
            }
        }
    }
}
