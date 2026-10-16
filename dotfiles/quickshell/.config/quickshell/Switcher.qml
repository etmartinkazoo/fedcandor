import QtQuick
import Quickshell
import Quickshell.Io

// App and window switcher, the same in every desktop mode.
//
//   Super+Tab   apps, most recently used first. Hold Super, tap Tab to move,
//               release Super to switch.
//   Alt+Tab     the focused app's windows, the same way with Alt (like
//               macOS's Cmd+`).
//
// Shift goes backwards. While it's open, arrows move, Enter switches, Esc
// cancels, and clicking a tile switches to it.
Scope {
    id: sw

    readonly property bool active: ShellState.activePopup === "switcher"
    property string kind: "apps"     // "apps" | "windows"
    property var items: []           // snapshot taken when the switcher opens
    property int index: 0

    // Open the switcher, or step through it if it's already open.
    function step(newKind, delta) {
        if (active && kind === newKind) {
            index = (index + delta + items.length) % items.length;
            return;
        }
        const focused = WindowList.focusedWindow;
        const list = newKind === "apps" ? WindowList.apps
            : (focused ? WindowList.windowsOf(focused.appId) : []);
        if (list.length === 0) return;
        // One window of this app: nothing to switch to.
        if (newKind === "windows" && list.length < 2) return;
        kind = newKind;
        items = list;
        // Start on the previous app/window, so a quick tap flips between two.
        index = list.length > 1 ? (delta > 0 ? 1 : list.length - 1) : 0;
        ShellState.openPopup("switcher");
    }

    function commit() {
        if (!active) return;
        const item = items[index];
        ShellState.closePopup("switcher");
        if (!item) return;
        if (kind === "apps") WindowList.focus(item.windows[0].id);
        else WindowList.focus(item.id);
    }

    IpcHandler {
        target: "switcher"
        function apps() { sw.step("apps", 1); }
        function appsBack() { sw.step("apps", -1); }
        function windows() { sw.step("windows", 1); }
        function windowsBack() { sw.step("windows", -1); }
        function commit() { sw.commit(); }
        function hide() { ShellState.closePopup("switcher"); }
    }

    ShellPopup {
        name: "switcher"
        centered: true
        dim: false
        panelWidth: Math.max(440, Math.min(row.implicitWidth, (screen ? screen.width : 1920) - 96) + Theme.paddingLarge * 2)

        Column {
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            // Releasing the modifier that opened the switcher switches.
            Keys.onReleased: function(event) {
                const k = event.key;
                const superKey = k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_Meta;
                if ((sw.kind === "apps" && superKey) || (sw.kind === "windows" && k === Qt.Key_Alt)) {
                    sw.commit();
                    event.accepted = true;
                }
            }
            Keys.onPressed: function(event) {
                switch (event.key) {
                case Qt.Key_Tab: sw.index = (sw.index + 1) % sw.items.length; break;
                case Qt.Key_Backtab: sw.index = (sw.index - 1 + sw.items.length) % sw.items.length; break;
                default: return;
                }
                event.accepted = true;
            }
            Keys.onRightPressed: sw.index = (sw.index + 1) % sw.items.length
            Keys.onLeftPressed: sw.index = (sw.index - 1 + sw.items.length) % sw.items.length
            Keys.onReturnPressed: sw.commit()
            Keys.onEnterPressed: sw.commit()

            Flickable {
                id: strip
                width: Math.min(parent.width, row.implicitWidth)
                anchors.horizontalCenter: parent.horizontalCenter
                height: 104
                contentWidth: row.implicitWidth
                clip: true
                interactive: false
                contentX: {
                    const tile = tileRepeater.itemAt(sw.index);
                    if (!tile) return 0;
                    const max = Math.max(0, contentWidth - width);
                    return Math.max(0, Math.min(max, tile.x + tile.width / 2 - width / 2));
                }

                Row {
                    id: row
                    spacing: Theme.spacingMedium

                    Repeater {
                        id: tileRepeater
                        model: sw.items
                        delegate: Column {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property string appId: modelData.appId
                            width: sw.kind === "apps" ? 88 : 152
                            spacing: Theme.paddingSmall

                            AppTile {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: cell.width
                                height: 72
                                appId: cell.appId
                                iconSize: 48
                                indicator: "dot"
                                running: sw.kind === "apps" && (cell.modelData.windows?.length ?? 0) > 1
                                selected: cell.index === sw.index
                                onLeftClicked: {
                                    sw.index = cell.index;
                                    sw.commit();
                                }
                            }

                            Text {
                                width: cell.width
                                horizontalAlignment: Text.AlignHCenter
                                text: sw.kind === "apps" ? WindowList.nameFor(cell.appId) : (cell.modelData.title ?? "")
                                color: cell.index === sw.index ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                font.bold: cell.index === sw.index
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Hint {
                text: (sw.kind === "apps" ? "hold Super, Tab to move, release to switch"
                    : WindowList.nameFor(sw.items.length > 0 ? sw.items[0].appId : "") + " windows • hold Alt, Tab to move, release to switch")
                    + " • ←/→ • Enter • Esc"
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
