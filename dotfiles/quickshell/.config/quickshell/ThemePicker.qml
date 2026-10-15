import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Visual theme picker. Each card previews the theme's wallpaper (or a mini
// mock-up from its palette) and color swatches. Enter applies live and keeps
// the picker open, so you can compare themes.
Scope {
    id: picker

    readonly property bool active: ShellState.activePopup === "themes"
    readonly property int columns: 3
    property var themes: []
    property int selectedIndex: 0

    onActiveChanged: if (active) lister.running = true

    function move(delta) {
        if (themes.length === 0) return;
        selectedIndex = Math.max(0, Math.min(themes.length - 1, selectedIndex + delta));
    }

    function applySelected() {
        if (selectedIndex >= 0 && selectedIndex < themes.length) Theme.setTheme(themes[selectedIndex].name);
    }

    Process {
        id: lister
        command: [Theme.cli, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text);
                    picker.themes = list;
                    const cur = list.findIndex(t => t.current);
                    picker.selectedIndex = cur >= 0 ? cur : 0;
                } catch (e) {
                    console.warn("theme picker: bad list output", e);
                }
            }
        }
    }

    IpcHandler {
        target: "theme"
        function picker() { ShellState.togglePopup("themes"); }
        function next() { Theme.nextTheme(); }
        function set(name: string) { Theme.setTheme(name); }
        function bgNext() { Theme.nextBackground(); }
    }

    ShellPopup {
        name: "themes"
        centered: true
        panelWidth: 760

        Column {
            id: col
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onLeftPressed: picker.move(-1)
            Keys.onRightPressed: picker.move(1)
            Keys.onUpPressed: picker.move(-picker.columns)
            Keys.onDownPressed: picker.move(picker.columns)
            Keys.onReturnPressed: picker.applySelected()
            Keys.onEnterPressed: picker.applySelected()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_B) {
                    Theme.nextBackground();
                    event.accepted = true;
                }
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "THEMES"
                    Layout.fillWidth: true
                }
                Caption { text: "current: " + Theme.currentTheme }
            }

            Grid {
                id: grid
                width: parent.width
                columns: picker.columns
                spacing: Theme.spacingMedium

                Repeater {
                    model: picker.themes
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property var c: modelData.colors
                        readonly property bool isCurrent: modelData.name === Theme.currentTheme
                        readonly property bool isSelected: index === picker.selectedIndex
                        width: (grid.width - grid.spacing * (picker.columns - 1)) / picker.columns
                        height: preview.height + info.implicitHeight + 16
                        color: Theme.bgItem
                        border.color: isSelected ? Theme.accent : (isCurrent ? Theme.border : Theme.borderSubtle)
                        border.width: isSelected ? 2 : Theme.borderWidth
                        radius: Theme.radius

                        // Preview: wallpaper, or a mini desktop drawn from the palette
                        Rectangle {
                            id: preview
                            x: 6
                            y: 6
                            width: parent.width - 12
                            height: width * 9 / 16
                            color: card.c.background
                            clip: true

                            Image {
                                anchors.fill: parent
                                visible: card.modelData.preview !== ""
                                source: card.modelData.preview !== "" ? "file://" + card.modelData.preview : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 480
                                sourceSize.height: 270
                            }

                            // Two tiled "windows"
                            Row {
                                visible: card.modelData.preview === ""
                                x: parent.width * 0.06
                                y: parent.height * 0.1
                                spacing: parent.width * 0.03
                                Rectangle {
                                    width: preview.width * 0.5; height: preview.height * 0.62
                                    color: card.c.dark_background; border.color: card.c.accent; border.width: 1
                                }
                                Rectangle {
                                    width: preview.width * 0.35; height: preview.height * 0.62
                                    color: card.c.dark_background; border.color: Qt.alpha(card.c.foreground, 0.2); border.width: 1
                                }
                            }

                            // Bar with an accent pill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.13
                                color: Qt.alpha(card.c.background, 0.92)
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 6
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        delegate: Rectangle {
                                            required property int index
                                            width: index === 0 ? 18 : 8; height: 7
                                            color: index === 0 ? card.c.accent : card.c.dark_background
                                            border.color: Qt.alpha(card.c.foreground, 0.25); border.width: 1
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            id: info
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: preview.bottom
                            anchors.margins: 8
                            anchors.topMargin: 6
                            spacing: 5

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: card.modelData.name
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: card.isCurrent ? "● current" : (card.modelData.mode === "light" ? "light" : "")
                                    color: card.isCurrent ? Theme.accent : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                }
                            }

                            Row {
                                spacing: 3
                                Repeater {
                                    model: ["accent", "red", "yellow", "green", "cyan", "blue", "magenta", "foreground"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 14; height: 10
                                        color: card.c[modelData]
                                        border.color: Qt.alpha(Theme.textPrimary, 0.15); border.width: 1
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: picker.selectedIndex = card.index
                            onClicked: {
                                picker.selectedIndex = card.index;
                                picker.applySelected();
                            }
                        }
                    }
                }
            }

            Hint {
                text: "←→↑↓ select • Enter apply • B next wallpaper • more: fedcandor-theme install omarchy:<name>"
            }
        }
    }
}
