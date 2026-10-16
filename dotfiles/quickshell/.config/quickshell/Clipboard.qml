import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "Fuzzy.js" as Fuzzy

// Clipboard history backed by cliphist. The watcher runs from here, so it
// records every copy (text and images) whether or not Quickshell has focus.
Scope {
    id: clipScope

    readonly property bool active: ShellState.activePopup === "clipboard"
    property int selectedIndex: 0
    property string query: ""
    property var entries: []   // [{ id, line, text, isImage }]
    property string previewPath: ""

    readonly property var filteredItems: Fuzzy.filter(entries, query, e => [[e.text, 0]])
    readonly property var selected: selectedIndex >= 0 && selectedIndex < filteredItems.length ? filteredItems[selectedIndex] : null
    readonly property string cacheDir: Quickshell.cachePath("clip")

    function refresh() { listProc.running = true; }

    function selectCurrent() {
        const e = selected;
        ShellState.closePopup("clipboard");
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "_", e.id]);
    }

    function deleteCurrent() {
        const e = selected;
        if (!e) return;
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "_", e.line]);
        entries = entries.filter(x => x.id !== e.id);
        selectedIndex = Math.min(selectedIndex, Math.max(0, filteredItems.length - 1));
    }

    function clearAll() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        entries = [];
        selectedIndex = 0;
    }

    function move(delta) {
        const n = filteredItems.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        clipList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    onActiveChanged: {
        if (active) {
            searchInput.text = "";
            selectedIndex = 0;
            refresh();
        } else {
            // Don't leave decoded clipboard images lying around in the cache.
            previewPath = "";
            Quickshell.execDetached(["rm", "-rf", "--", cacheDir]);
        }
    }

    // Decode the selected image into the cache so it can be previewed.
    onSelectedChanged: {
        if (!active || !selected || !selected.isImage) {
            previewPath = "";
            return;
        }
        const path = cacheDir + "/" + selected.id + ".img";
        previewProc.target = path;
        previewProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && [ -s \"$2\" ] || cliphist decode \"$1\" > \"$2\"", "_", selected.id, path];
        previewProc.running = true;
    }

    Process {
        id: watcher
        // Capped history; cliphist also skips entries password managers mark
        // sensitive (CLIPBOARD_STATE=sensitive from wl-clipboard).
        command: ["wl-paste", "--watch", "cliphist", "-max-items", "200", "store"]
        running: true
        onExited: watcherRestart.restart()
    }

    Timer {
        id: watcherRestart
        interval: 2000
        onTriggered: watcher.running = true
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const body = line.slice(tab + 1);
                    out.push({
                        id: line.slice(0, tab),
                        line: line,
                        text: body,
                        isImage: /^\[\[ binary data .* (png|jpe?g|gif|bmp|webp) /.test(body)
                    });
                }
                clipScope.entries = out;
            }
        }
    }

    Process {
        id: previewProc
        property string target: ""
        onExited: function(code) {
            if (code === 0 && clipScope.selected && clipScope.selected.isImage) clipScope.previewPath = "file://" + target;
        }
    }

    IpcHandler {
        target: "clipboard"
        function open() { ShellState.openPopup("clipboard"); }
        function hide() { ShellState.closePopup("clipboard"); }
        function toggle() { ShellState.togglePopup("clipboard"); }
        function clear() { clipScope.clearAll(); }
    }

    ShellPopup {
        name: "clipboard"
        panelWidth: 400
        panelHeight: 440
        defaultRightOffset: 260

        Column {
            anchors.fill: parent
            spacing: Theme.spacingMedium

            ThemedField {
                id: searchInput
                width: parent.width
                focus: true
                placeholderText: "Search clipboard history..."
                onTextChanged: {
                    clipScope.query = text;
                    clipScope.selectedIndex = 0;
                    clipList.positionViewAtBeginning();
                }
                Keys.onDownPressed: clipScope.move(1)
                Keys.onUpPressed: clipScope.move(-1)
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Delete) {
                        clipScope.deleteCurrent();
                        event.accepted = true;
                    }
                }
                onAccepted: clipScope.selectCurrent()
            }

            Rectangle {
                id: previewBox
                width: parent.width
                height: 120
                visible: clipScope.previewPath !== ""
                color: Theme.bgItem
                border.width: 0

                Image {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingCompact
                    source: clipScope.previewPath
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                }
            }

            ListView {
                id: clipList
                width: parent.width
                height: parent.height - searchInput.height - clipHint.implicitHeight - Theme.spacingMedium * 2
                    - (previewBox.visible ? previewBox.height + Theme.spacingMedium : 0)
                clip: true
                model: clipScope.filteredItems
                currentIndex: clipScope.selectedIndex
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: clipList.width
                    selected: index === clipScope.selectedIndex
                    onEntered: clipScope.selectedIndex = index
                    onClicked: function(m) {
                        clipScope.selectedIndex = index;
                        if (m.button === Qt.RightButton) clipScope.deleteCurrent();
                        else clipScope.selectCurrent();
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: (modelData.isImage ? "󰋩  " : "") + modelData.text.replace(/\s*\n\s*/g, " ↵ ")
                        color: modelData.isImage ? Theme.textSecondary : Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: clipScope.filteredItems.length === 0
                    text: "No clipboard items"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }

            RowLayout {
                id: clipHint
                width: parent.width

                Hint {
                    text: "Enter copy • Del/right-click remove"
                    Layout.fillWidth: true
                }

                Text {
                    text: "Clear All"
                    color: clearMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSmall
                    visible: clipScope.entries.length > 0

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: clipScope.clearAll()
                    }
                }
            }
        }
    }
}
