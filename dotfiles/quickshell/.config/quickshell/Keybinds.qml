import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Fuzzy.js" as Fuzzy

// Keybind cheatsheet, generated from the live sway config on every open.
Scope {
    id: kbScope

    readonly property bool active: ShellState.activePopup === "keybinds"
    property int selectedIndex: 0
    property string query: ""
    property var bindings: []

    readonly property var filteredBindings: Fuzzy.filter(bindings, query, b => [[b.keys, 0], [b.desc, 0]])

    onActiveChanged: {
        if (active) {
            kbInput.text = "";
            selectedIndex = 0;
            loader.running = true;
        }
    }

    function move(delta) {
        const n = filteredBindings.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        kbList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    Process {
        id: loader
        command: ["python3", "-I", Quickshell.shellPath("scripts/sway-keybinds.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    kbScope.bindings = JSON.parse(text);
                } catch (e) {
                    console.warn("keybinds: bad output", e);
                }
            }
        }
    }

    IpcHandler {
        target: "keybinds"
        function open() { ShellState.openPopup("keybinds"); }
        function hide() { ShellState.closePopup("keybinds"); }
        function toggle() { ShellState.togglePopup("keybinds"); }
    }

    ShellPopup {
        name: "keybinds"
        centered: true
        panelWidth: 600
        panelHeight: 480

        Column {
            anchors.fill: parent
            spacing: Theme.spacingMedium

            ThemedField {
                id: kbInput
                width: parent.width
                focus: true
                placeholderText: "Search keybinds..."
                onTextChanged: {
                    kbScope.query = text;
                    kbScope.selectedIndex = 0;
                    kbList.positionViewAtBeginning();
                }
                Keys.onDownPressed: kbScope.move(1)
                Keys.onUpPressed: kbScope.move(-1)
            }

            ListView {
                id: kbList
                width: parent.width
                height: parent.height - kbInput.height - kbHint.implicitHeight - Theme.spacingMedium * 2
                clip: true
                model: kbScope.filteredBindings
                currentIndex: kbScope.selectedIndex
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: kbList.width
                    height: 32
                    selected: index === kbScope.selectedIndex
                    onEntered: kbScope.selectedIndex = index

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        Text {
                            text: modelData.keys
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontNormal
                            font.bold: true
                            Layout.preferredWidth: 220
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.desc
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Hint {
                id: kbHint
                text: "↑/↓ navigate • type to filter • read from your sway config • Esc close"
            }
        }
    }
}
