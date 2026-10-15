import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Scope {
    id: batteryScope

    readonly property bool active: ShellState.activePopup === "battery"
    readonly property int lowThreshold: 15
    readonly property int criticalThreshold: 5

    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: dev && dev.ready && dev.isLaptopBattery && dev.isPresent
    readonly property int pct: hasBattery ? Math.round(dev.percentage * (dev.percentage <= 1.0 ? 100 : 1)) : 100
    readonly property bool onAc: !UPower.onBattery
    readonly property bool isCharging: hasBattery && dev.state === UPowerDeviceState.Charging
    readonly property bool isFull: hasBattery && dev.state === UPowerDeviceState.FullyCharged
    // Plugged in but held (charge threshold / PendingCharge).
    readonly property bool isHeld: hasBattery && onAc && !isCharging && !isFull
    readonly property bool isLow: hasBattery && !onAc && pct <= lowThreshold

    readonly property string stateText: {
        if (!hasBattery) return "AC Power";
        if (isCharging) return "Charging";
        if (isFull) return "Full";
        if (isHeld) return "Plugged in, not charging";
        return "On battery";
    }

    function formatDuration(secs) {
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string timeText: {
        if (!hasBattery) return "";
        if (isCharging && dev.timeToFull > 0) return formatDuration(dev.timeToFull) + " until full";
        if (!onAc && dev.timeToEmpty > 0) return formatDuration(dev.timeToEmpty) + " remaining";
        return "";
    }

    readonly property string barIcon: {
        if (!hasBattery) {
            if (PowerProfiles.profile === PowerProfile.Performance) return "󰓅";
            if (PowerProfiles.profile === PowerProfile.PowerSaver) return "󰌪";
            return "󰾅";
        }
        if (isCharging) return "󰂄";
        if (isHeld || isFull) return "󰚥";
        if (pct >= 90) return "󰁹";
        if (pct >= 70) return "󰂀";
        if (pct >= 50) return "󰁾";
        if (pct >= 30) return "󰁼";
        if (pct >= 15) return "󰁺";
        return "󰂃";
    }

    readonly property string barText: hasBattery ? (barIcon + " " + pct + "%") : barIcon

    // ---- Low / critical battery handling ----
    property bool notifiedLow: false
    property bool suspendPending: false

    function checkLevels() {
        if (!hasBattery) return;
        if (onAc) {
            notifiedLow = false;
            if (suspendPending) {
                suspendPending = false;
                suspendTimer.stop();
                Quickshell.execDetached(["notify-send", "-u", "normal", "Suspend cancelled", "Charger connected"]);
            }
            return;
        }
        if (pct <= lowThreshold && !notifiedLow) {
            notifiedLow = true;
            Quickshell.execDetached(["notify-send", "-u", "critical", "Low Battery", "Battery is at " + pct + "%"]);
        }
        if (pct <= criticalThreshold && !suspendPending) {
            suspendPending = true;
            suspendTimer.restart();
            Quickshell.execDetached(["notify-send", "-u", "critical", "Battery Critical",
                "Battery at " + pct + "%. Suspending in 60 seconds unless plugged in."]);
        }
    }

    onPctChanged: checkLevels()
    onOnAcChanged: checkLevels()
    onHasBatteryChanged: checkLevels()

    Timer {
        id: suspendTimer
        interval: 60000
        onTriggered: {
            batteryScope.suspendPending = false;
            if (!batteryScope.onAc) Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    readonly property var profiles: [
        { profile: PowerProfile.PowerSaver, label: "Power Saver", icon: "󰌪" },
        { profile: PowerProfile.Balanced, label: "Balanced", icon: "󰾅" },
        { profile: PowerProfile.Performance, label: "Performance", icon: "󰓅" }
    ]

    IpcHandler {
        target: "battery"
        function open() { ShellState.openPopup("battery"); }
        function hide() { ShellState.closePopup("battery"); }
        function toggle() { ShellState.togglePopup("battery"); }
    }

    ShellPopup {
        name: "battery"
        panelWidth: 424
        defaultRightOffset: 120

        Column {
            id: batCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_1) PowerProfiles.profile = PowerProfile.PowerSaver;
                else if (event.key === Qt.Key_2) PowerProfiles.profile = PowerProfile.Balanced;
                else if (event.key === Qt.Key_3 && PowerProfiles.hasPerformanceProfile) PowerProfiles.profile = PowerProfile.Performance;
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "POWER & BATTERY"
                    Layout.fillWidth: true
                }
                Text {
                    text: batteryScope.hasBattery ? batteryScope.pct + "% • " + batteryScope.stateText : batteryScope.stateText
                    color: batteryScope.isLow ? Theme.borderCritical : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }

            Column {
                width: parent.width
                spacing: 4
                visible: batteryScope.hasBattery

                Meter {
                    width: parent.width
                    height: 20
                    value: batteryScope.pct / 100
                    critical: batteryScope.isLow
                }

                RowLayout {
                    width: parent.width
                    Caption {
                        text: batteryScope.timeText
                        Layout.fillWidth: true
                    }
                    Caption {
                        visible: batteryScope.dev && batteryScope.dev.healthSupported
                        text: batteryScope.dev ? "Health " + Math.round(batteryScope.dev.healthPercentage) + "%" : ""
                    }
                }

                Caption {
                    visible: batteryScope.suspendPending
                    text: "Suspending soon — plug in to cancel"
                    color: Theme.borderCritical
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Caption { text: "POWER PROFILE" }

                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium
                    Repeater {
                        model: batteryScope.profiles
                        delegate: OptionTile {
                            required property var modelData
                            required property int index
                            width: (batCol.width - Theme.spacingMedium * 2) / 3
                            iconSize: 16
                            icon: modelData.icon
                            label: modelData.label + " [" + (index + 1) + "]"
                            selected: PowerProfiles.profile === modelData.profile
                            enabled: modelData.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                            onClicked: PowerProfiles.profile = modelData.profile
                        }
                    }
                }
            }

            Hint { text: "1-3 switch profile • Esc close" }
        }
    }
}
