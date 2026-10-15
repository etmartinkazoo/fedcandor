import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Quick settings: appearance and everyday toggles in one panel. Replaces the
// separate night light, caffeine, theme, clipboard and screenshot buttons.
Scope {
    id: qs

    required property var nightLight   // NightLight.qml
    required property var caffeine     // Caffeine.qml

    readonly property bool active: ShellState.activePopup === "quick"

    // Bar icon: the settings glyph, plus any state you'd want to notice.
    readonly property string barText: "󰒓" + (caffeine.enabled ? " 󰅶" : "") + (ShellState.settings.dnd ? " 󰂛" : "")

    // ---- Brightness (brightnessctl; hidden on machines without a backlight) ----
    property int brightness: -1

    onActiveChanged: if (active) brightnessRead.running = true

    function setBrightness(pct) {
        brightness = Math.max(1, Math.min(100, Math.round(pct)));
        Quickshell.execDetached(["brightnessctl", "-q", "set", brightness + "%"]);
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                // device,class,current,percent,max
                const f = text.trim().split("\n")[0].split(",");
                qs.brightness = f.length >= 4 && f[1] === "backlight" ? parseInt(f[3]) : -1;
            }
        }
    }

    function openTool(name) {
        ShellState.openPopup(name, ShellState.popupScreen, ShellState.popupAnchorX);
    }

    IpcHandler {
        target: "quick"
        function open() { ShellState.openPopup("quick"); }
        function hide() { ShellState.closePopup("quick"); }
        function toggle() { ShellState.togglePopup("quick"); }
    }

    ShellPopup {
        name: "quick"
        panelWidth: 440
        defaultRightOffset: 260

        Column {
            id: col
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onLeftPressed: if (qs.brightness >= 0) qs.setBrightness(qs.brightness - 5)
            Keys.onRightPressed: if (qs.brightness >= 0) qs.setBrightness(qs.brightness + 5)
            Keys.onPressed: function(event) {
                switch (event.key) {
                case Qt.Key_N: qs.nightLight.cycleMode(); break;
                case Qt.Key_A: qs.caffeine.toggle(); break;
                case Qt.Key_D: ShellState.settings.dnd = !ShellState.settings.dnd; break;
                case Qt.Key_T: qs.openTool("themes"); break;
                case Qt.Key_S: qs.openTool("screenshot"); break;
                case Qt.Key_V: qs.openTool("clipboard"); break;
                case Qt.Key_Slash: qs.openTool("keybinds"); break;
                default: return;
                }
                event.accepted = true;
            }

            PanelTitle { text: "QUICK SETTINGS" }

            // Theme
            Rectangle {
                width: parent.width
                height: 48
                color: themeMouse.containsMouse ? Theme.bgSelected : Theme.bgItem
                border.color: Theme.border
                border.width: Theme.borderWidth
                radius: Theme.radius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: "󰔎"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontIcon + 2
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Caption { text: "THEME" }
                        Text {
                            text: Theme.currentTheme
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                        }
                    }
                    Row {
                        spacing: 3
                        Repeater {
                            model: [Theme.accent, Theme.red, Theme.yellow, Theme.green, Theme.blue, Theme.magenta]
                            delegate: Rectangle {
                                required property color modelData
                                width: 10; height: 18
                                color: modelData
                            }
                        }
                    }
                    Caption { text: "[T]" }
                }

                MouseArea {
                    id: themeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: qs.openTool("themes")
                }
            }

            // Brightness
            Column {
                width: parent.width
                spacing: 4
                visible: qs.brightness >= 0
                RowLayout {
                    width: parent.width
                    Caption { text: "󰃠  BRIGHTNESS"; Layout.fillWidth: true }
                    Text {
                        text: qs.brightness + "%"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                    }
                }
                Meter {
                    width: parent.width
                    height: 14
                    interactive: true
                    value: qs.brightness / 100
                    onMoved: function(v) { qs.setBrightness(v * 100); }
                }
            }

            // Warmth (night light): directly under brightness
            Column {
                width: parent.width
                spacing: 6
                RowLayout {
                    width: parent.width
                    Caption {
                        text: (qs.nightLight.enabled ? "󰖔" : "󰖙") + "  WARMTH [N]"
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: [{ mode: "off", label: "OFF" }, { mode: "auto", label: "AUTO" }, { mode: "on", label: "ON" }]
                        delegate: SmallButton {
                            required property var modelData
                            text: modelData.label
                            highlighted: qs.nightLight.mode === modelData.mode
                            onClicked: qs.nightLight.setMode(modelData.mode)
                        }
                    }
                }
                Meter {
                    width: parent.width
                    height: 14
                    interactive: true
                    opacity: qs.nightLight.enabled ? 1 : 0.45
                    // 6000K (left, neutral) .. 2500K (right, warm)
                    value: (6000 - qs.nightLight.temperature) / 3500
                    onMoved: function(v) { qs.nightLight.setTemp(Math.round((6000 - v * 3500) / 50) * 50); }
                }
                RowLayout {
                    width: parent.width
                    Caption {
                        text: qs.nightLight.modeText
                        Layout.fillWidth: true
                    }
                    Caption { text: qs.nightLight.temperature + "K" }
                }
            }

            // Toggles
            Row {
                width: parent.width
                spacing: Theme.spacingMedium
                readonly property real w: (width - spacing) / 2

                OptionTile {
                    width: parent.w
                    height: 82
                    icon: qs.caffeine.enabled ? "󰅶" : "󰾪"
                    label: "Keep awake [A]"
                    sublabel: qs.caffeine.enabled ? "Screen stays on" : "Off"
                    selected: qs.caffeine.enabled
                    onClicked: qs.caffeine.toggle()
                }
                OptionTile {
                    width: parent.w
                    height: 82
                    icon: ShellState.settings.dnd ? "󰂛" : "󰂚"
                    label: "Do not disturb [D]"
                    sublabel: ShellState.settings.dnd ? "Only critical" : "Off"
                    selected: ShellState.settings.dnd
                    onClicked: ShellState.settings.dnd = !ShellState.settings.dnd
                }
            }

            // Tools
            Row {
                width: parent.width
                spacing: Theme.spacingMedium
                readonly property real w: (width - spacing * 2) / 3
                Repeater {
                    model: [
                        { icon: "󰄀", label: "Screenshot [S]", popup: "screenshot" },
                        { icon: "󰅌", label: "Clipboard [V]", popup: "clipboard" },
                        { icon: "󰌌", label: "Shortcuts [/]", popup: "keybinds" }
                    ]
                    delegate: OptionTile {
                        required property var modelData
                        width: parent.w
                        height: 62
                        iconSize: 15
                        icon: modelData.icon
                        label: modelData.label
                        onClicked: qs.openTool(modelData.popup)
                    }
                }
            }

            Hint { text: "←/→ brightness • letters in [brackets] are shortcuts • Esc close" }
        }
    }
}
