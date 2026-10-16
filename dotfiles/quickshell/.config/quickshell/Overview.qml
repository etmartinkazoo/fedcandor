import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Overview (Super+Ctrl+↑, like macOS's Mission Control or Windows' Task View):
// every open window as a snapshot, current workspace first. Type to filter,
// arrows to move, Enter or click to switch, Shift+Delete or the × to close.
//
// Snapshots come from grim (sway can't stream windows to the shell), taken
// when the overview opens.
Scope {
    id: ov

    readonly property bool active: ShellState.activePopup === "overview"
    property string query: ""
    property int index: 0

    // Current workspace first, then the others in order; minimized last
    readonly property var items: {
        const words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        const current = WindowList.focusedWindow ? WindowList.focusedWindow.workspace : "";
        const rank = w => w.minimized ? 2 : (w.workspace === current ? 0 : 1);
        return WindowList.windows
            .filter(w => {
                const hay = (w.title + " " + WindowList.nameFor(w.appId) + " " + w.workspace).toLowerCase();
                return words.every(x => hay.includes(x));
            })
            .sort((a, b) => rank(a) - rank(b) || a.workspace.localeCompare(b.workspace, undefined, { numeric: true }));
    }

    onActiveChanged: {
        if (active) {
            filter.text = "";
            index = 0;
            WindowList.capture(WindowList.windows);
        }
    }

    onItemsChanged: index = Math.max(0, Math.min(index, items.length - 1))

    function move(delta) {
        if (items.length === 0) return;
        index = Math.max(0, Math.min(items.length - 1, index + delta));
        const card = cards.itemAt(index);
        if (card) {
            if (card.y < flick.contentY) flick.contentY = card.y;
            else if (card.y + card.height > flick.contentY + flick.height) flick.contentY = card.y + card.height - flick.height;
        }
    }

    function activate(i) {
        const w = items[i];
        ShellState.closePopup("overview");
        if (w) WindowList.focus(w.id);
    }

    IpcHandler {
        target: "overview"
        function toggle() { ShellState.togglePopup("overview"); }
        function open() { ShellState.openPopup("overview"); }
        function hide() { ShellState.closePopup("overview"); }
    }

    ShellPopup {
        id: popup
        name: "overview"
        centered: true

        readonly property real screenWidth: screen ? screen.width : 1920
        readonly property real screenHeight: screen ? screen.height : 1080
        panelWidth: screenWidth - 48
        panelHeight: screenHeight - 48

        Column {
            id: col
            anchors.fill: parent
            spacing: Theme.spacingLarge

            RowLayout {
                id: header
                width: parent.width
                spacing: Theme.spacingLarge

                PanelTitle { text: "OVERVIEW" }

                ThemedField {
                    id: filter
                    Layout.preferredWidth: 360
                    focus: true
                    placeholderText: "Filter windows..."
                    onTextChanged: {
                        ov.query = text;
                        ov.index = 0;
                        flick.contentY = 0;
                    }
                    Keys.onLeftPressed: function(event) { if (text === "") ov.move(-1); else event.accepted = false; }
                    Keys.onRightPressed: function(event) { if (text === "") ov.move(1); else event.accepted = false; }
                    Keys.onUpPressed: ov.move(-grid.columns)
                    Keys.onDownPressed: ov.move(grid.columns)
                    Keys.onTabPressed: ov.move(1)
                    Keys.onBacktabPressed: ov.move(-1)
                    Keys.onReturnPressed: ov.activate(ov.index)
                    Keys.onEnterPressed: ov.activate(ov.index)
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier) && ov.items[ov.index]) {
                            WindowList.close(ov.items[ov.index].id);
                            event.accepted = true;
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Caption { text: ov.items.length + (ov.items.length === 1 ? " window" : " windows") }
            }

            Flickable {
                id: flick
                width: parent.width
                height: parent.height - header.height - hint.implicitHeight - col.spacing * 2
                clip: true
                contentWidth: width
                contentHeight: grid.height
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: grid
                    width: flick.width
                    spacing: Theme.spacingLarge

                    // As many columns as it takes for the cards to fit on screen,
                    // without making them tiny or huge.
                    readonly property real cardRatio: 10 / 16
                    columns: {
                        const n = Math.max(1, ov.items.length);
                        for (let c = 1; c <= 6; c++) {
                            const w = (width - spacing * (c - 1)) / c;
                            const h = w * cardRatio + 40;
                            const rows = Math.ceil(n / c);
                            if (w <= 460 && rows * h + (rows - 1) * spacing <= flick.height) return c;
                        }
                        return 6;
                    }
                    readonly property real cardWidth: (width - spacing * (columns - 1)) / columns

                    Repeater {
                        id: cards
                        model: ov.items

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === ov.index
                            width: grid.cardWidth
                            height: thumb.height + 40
                            color: Theme.bgItem
                            border.color: Theme.accent
                            border.width: selected ? 2 : 0
                            radius: Theme.radius

                            // Snapshot, or the app icon until it arrives
                            Rectangle {
                                id: thumb
                                x: 6
                                y: 6
                                width: parent.width - 12
                                height: width * grid.cardRatio
                                color: Theme.darkerBackground
                                clip: true

                                Image {
                                    id: shot
                                    anchors.fill: parent
                                    source: ov.active ? WindowList.thumbFor(card.modelData.id) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: width * 2
                                }

                                AppTile {
                                    visible: shot.status !== Image.Ready
                                    anchors.centerIn: parent
                                    width: 64
                                    height: 64
                                    appId: card.modelData.appId
                                    iconSize: 48
                                    enabled: false
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                spacing: Theme.paddingSmall

                                AppTile {
                                    width: 20
                                    height: 20
                                    appId: card.modelData.appId
                                    iconSize: 16
                                    color: "transparent"
                                    border.width: 0
                                }

                                Text {
                                    width: parent.width - 20 - wsLabel.width - parent.spacing * 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.modelData.title
                                    color: card.selected ? Theme.textPrimary : Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    font.bold: card.selected
                                    elide: Text.ElideRight
                                }

                                Caption {
                                    id: wsLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: card.modelData.minimized ? "minimized" : card.modelData.workspace
                                }
                            }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onEntered: ov.index = card.index
                                onClicked: function(m) {
                                    if (m.button === Qt.MiddleButton) WindowList.close(card.modelData.id);
                                    else ov.activate(card.index);
                                }
                            }

                            // Close
                            Rectangle {
                                visible: cardMouse.containsMouse || closeMouse.containsMouse
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 10
                                width: 26
                                height: 26
                                color: closeMouse.containsMouse ? Theme.red : Theme.bgPanel
                                radius: Theme.radius

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰖭"
                                    color: closeMouse.containsMouse ? Theme.bgPanel : Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: WindowList.close(card.modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            Hint {
                id: hint
                text: "type to filter • arrows move • Enter or click switches • Shift+Delete, middle-click or × closes • Esc"
            }
        }
    }
}
