import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Keybinds overlay (Super+.): every binding on one screen, grouped by the
// "## Section" headings of the live sway config and laid out in balanced
// columns. Type to filter; the scripts/sway-keybinds.py parser re-reads the
// config on every open, so your own bindings show up too.
Scope {
    id: kbScope

    readonly property bool active: ShellState.activePopup === "keybinds"
    property string query: ""
    property var bindings: []

    readonly property int columnWidth: 340
    readonly property int rowHeight: 21
    readonly property int headerHeight: 30

    // [{name, entries}] in config order, filtered by every word of the query
    readonly property var sections: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        const out = [];
        const index = {};
        for (const b of bindings) {
            const hay = (b.keys + " " + b.desc + " " + b.section).toLowerCase();
            if (!words.every(w => hay.includes(w))) continue;
            if (!(b.section in index)) {
                index[b.section] = out.length;
                out.push({ name: b.section, entries: [] });
            }
            out[index[b.section]].entries.push(b);
        }
        return out;
    }

    // One key combo as a flat list of keycaps and separators, so a long one can
    // wrap between keys: [{sep: "or"}, {cap: "Super"}, {sep: "+"}, {cap: "H"}, {sep: "/"}, ...]
    function tokens(combo, alternative) {
        const out = alternative ? [{ sep: "or" }] : [];
        combo.mods.forEach(m => out.push({ cap: m }, { sep: "+" }));
        combo.keys.forEach((k, j) => {
            if (j > 0) out.push({ sep: "/" });
            out.push({ cap: k });
        });
        return out;
    }

    // Rough line count of an entry's keycaps at the current column width:
    // each alternative combo starts its own line.
    function entryLines(entry) {
        return entry.combos.reduce((lines, combo, i) => {
            const width = tokens(combo, i > 0).reduce((w, t) => w + 3 + (t.cap !== undefined ? t.cap.length * 7 + 12 : t.sep.length * 7), 0);
            return lines + Math.max(1, Math.ceil(width / Math.max(1, keysWidth)));
        }, 0);
    }

    readonly property real keysWidth: columnsRow.columnWidth * 0.55

    readonly property int matchCount: sections.reduce((n, s) => n + s.entries.length, 0)

    onActiveChanged: {
        if (active) {
            kbInput.text = "";
            loader.running = true;
        }
    }

    // Split sections into `n` columns of similar height, keeping reading order.
    function columnsFor(n) {
        const height = s => headerHeight + s.entries.reduce((h, e) => h + entryLines(e) * 21 + 3, 0);
        const total = sections.reduce((h, s) => h + height(s), 0);
        const target = total / n;
        const cols = [[]];
        let h = 0;
        for (const s of sections) {
            if (h > 0 && h + height(s) / 2 > target && cols.length < n) {
                cols.push([]);
                h = 0;
            }
            cols[cols.length - 1].push(s);
            h += height(s);
        }
        return cols;
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

    // One token of a binding: a keycap, or a faint separator ("+", "/", "or")
    component KeyToken: Rectangle {
        property var token
        readonly property bool isCap: token.cap !== undefined
        implicitWidth: isCap ? Math.max(18, label.implicitWidth + 12) : label.implicitWidth
        implicitHeight: 18
        color: isCap ? Theme.bgSelected : "transparent"
        radius: Theme.radius

        Text {
            id: label
            anchors.centerIn: parent
            text: parent.isCap ? parent.token.cap : parent.token.sep
            color: parent.isCap ? Theme.textPrimary : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: parent.isCap
        }
    }

    ShellPopup {
        id: kbPopup
        name: "keybinds"
        centered: true

        readonly property real screenWidth: screen ? screen.width : 1920
        readonly property real screenHeight: screen ? screen.height : 1080
        panelWidth: Math.min(screenWidth - 48, 1680)
        panelHeight: screenHeight - 48

        Column {
            id: kbCol
            anchors.fill: parent
            spacing: Theme.spacingLarge

            RowLayout {
                id: kbHeader
                width: parent.width
                spacing: Theme.spacingLarge

                PanelTitle { text: "KEYBINDS" }

                ThemedField {
                    id: kbInput
                    Layout.preferredWidth: 360
                    focus: true
                    placeholderText: "Filter keybinds..."
                    onTextChanged: {
                        kbScope.query = text;
                        flick.contentY = 0;
                    }
                    Keys.onDownPressed: flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 60)
                    Keys.onUpPressed: flick.contentY = Math.max(0, flick.contentY - 60)
                }

                Item { Layout.fillWidth: true }

                Caption {
                    text: kbScope.query === "" ? kbScope.matchCount + " bindings"
                        : kbScope.matchCount + " match" + (kbScope.matchCount === 1 ? "" : "es")
                }
            }

            Flickable {
                id: flick
                width: parent.width
                height: parent.height - kbHeader.height - kbHint.implicitHeight - kbCol.spacing * 2
                clip: true
                contentWidth: width
                contentHeight: columnsRow.height
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: columnsRow
                    readonly property int count: Math.max(1, Math.floor((flick.width + spacing) / (kbScope.columnWidth + spacing)))
                    readonly property real columnWidth: (width - spacing * (count - 1)) / count
                    width: flick.width
                    spacing: Theme.paddingLarge * 2

                    Repeater {
                        model: kbScope.columnsFor(columnsRow.count)

                        delegate: Column {
                            required property var modelData
                            width: columnsRow.columnWidth
                            spacing: Theme.spacingLarge

                            Repeater {
                                model: parent.modelData

                                delegate: Column {
                                    id: section
                                    required property var modelData
                                    width: parent.width

                                    Caption {
                                        height: kbScope.headerHeight - 8
                                        verticalAlignment: Text.AlignTop
                                        text: section.modelData.name.toUpperCase()
                                        color: Theme.accent
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: section.modelData.entries

                                        delegate: Item {
                                            id: entry
                                            required property var modelData
                                            width: section.width
                                            height: Math.max(kbScope.rowHeight, keyFlow.height + 3)

                                            Column {
                                                id: keyFlow
                                                width: parent.width * 0.55
                                                y: 3
                                                spacing: 3

                                                Repeater {
                                                    model: entry.modelData.combos
                                                    delegate: Flow {
                                                        required property var modelData
                                                        required property int index
                                                        width: keyFlow.width
                                                        spacing: 3

                                                        Repeater {
                                                            model: kbScope.tokens(parent.modelData, parent.index > 0)
                                                            delegate: KeyToken {
                                                                required property var modelData
                                                                token: modelData
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Text {
                                                x: parent.width * 0.57
                                                y: 3
                                                width: parent.width * 0.43
                                                height: 18
                                                verticalAlignment: Text.AlignVCenter
                                                text: entry.modelData.desc
                                                color: Theme.textSecondary
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontCaption
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Hint {
                id: kbHint
                text: "type to filter • ↑/↓ scroll • read from your sway config: add a \"## Section\" and \"# description\" above your own bindings • Esc close"
            }
        }
    }
}
