import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Start menu (Windows mode): opened from the taskbar's Fedora button or
// Super+Space. Search at the top; pinned apps and your most used apps below;
// "All apps" lists everything A-Z. Right-click an app to pin or unpin it.
// The footer has your name, lock, suspend and the power menu.
Scope {
    id: start

    required property var launcher    // Launcher.qml: search, frecency, launching

    readonly property bool active: ShellState.activePopup === "start"
    property string query: ""
    property string view: "home"      // "home" | "all" ("search" while typing)
    property int index: 0

    readonly property int columns: 6
    readonly property string userName: Quickshell.env("USER") || ""

    readonly property var allApps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var pinned: ShellState.settings.startPinned
        .map(id => DesktopEntries.byId(id))
        .filter(a => a !== null && a !== undefined)

    // Most used, not already pinned, only apps you've launched
    readonly property var recommended: launcher.search("")
        .filter(a => launcher.frecency(a) > 0 && !ShellState.settings.startPinned.includes(a.id))
        .slice(0, columns)

    readonly property string mode: query.trim() !== "" ? "search" : view
    readonly property var results: mode === "search" ? launcher.search(query)
        : (mode === "all" ? allApps : pinned.concat(recommended))

    onActiveChanged: {
        if (active) {
            field.text = "";
            view = "home";
            index = 0;
        }
    }

    onModeChanged: index = 0

    function togglePin(app) {
        const p = ShellState.settings.startPinned.slice();
        const i = p.indexOf(app.id);
        if (i >= 0) p.splice(i, 1);
        else p.push(app.id);
        ShellState.settings.startPinned = p;
    }

    function launch(app) {
        ShellState.closePopup("start");
        if (app) launcher.launchApp(app);
    }

    // Grid on the home view, a list otherwise
    function move(dx, dy) {
        const n = results.length;
        if (n === 0) return;
        const step = mode === "home" ? dx + dy * columns : dy + dx;
        index = Math.max(0, Math.min(n - 1, index + step));
        if (mode !== "home") list.positionViewAtIndex(index, ListView.Contain);
    }

    IpcHandler {
        target: "start"
        function toggle() { ShellState.togglePopup("start", undefined, 0); }
        function open() { ShellState.openPopup("start", undefined, 0); }
        function hide() { ShellState.closePopup("start"); }
    }

    // An app as a tile: icon over its name (pinned and recommended grids)
    component AppCell: Rectangle {
        id: cell
        required property var app
        required property int cellIndex
        readonly property bool selected: start.index === cellIndex
        height: 84
        color: selected || cellMouse.containsMouse ? Theme.bgSelected : "transparent"
        border.color: selected ? Theme.accent : (cellMouse.containsMouse ? Theme.borderSubtle : "transparent")
        border.width: Theme.borderWidth
        radius: Theme.radius

        Column {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: Theme.paddingSmall

            IconImage {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitSize: 36
                source: Quickshell.iconPath(cell.app.icon, "application-x-executable")
                asynchronous: true
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: cell.app.name
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: start.index = cell.cellIndex
            onClicked: function(m) {
                if (m.button === Qt.RightButton) start.togglePin(cell.app);
                else start.launch(cell.app);
            }
        }
    }

    ShellPopup {
        id: popup
        name: "start"
        panelWidth: 560
        panelHeight: Math.min(620, (screen ? screen.height : 900) - Desktop.popupInset - 40)

        Column {
            id: col
            anchors.fill: parent
            spacing: Theme.spacingLarge

            ThemedField {
                id: field
                width: parent.width
                focus: true
                placeholderText: "Search apps..."
                onTextChanged: {
                    start.query = text;
                    start.index = 0;
                }
                Keys.onLeftPressed: function(event) { if (text === "" && start.mode === "home") start.move(-1, 0); else event.accepted = false; }
                Keys.onRightPressed: function(event) { if (text === "" && start.mode === "home") start.move(1, 0); else event.accepted = false; }
                Keys.onUpPressed: start.move(0, -1)
                Keys.onDownPressed: start.move(0, 1)
                Keys.onTabPressed: start.move(1, 0)
                Keys.onBacktabPressed: start.move(-1, 0)
                onAccepted: start.launch(start.results[start.index])
            }

            // ---- Home: pinned + most used ----
            Flickable {
                id: home
                visible: start.mode === "home"
                width: parent.width
                height: parent.height - field.height - footer.height - col.spacing * 2
                clip: true
                contentHeight: homeCol.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: homeCol
                    width: parent.width
                    spacing: Theme.spacingMedium

                    RowLayout {
                        width: parent.width
                        Caption { text: "PINNED"; font.bold: true; Layout.fillWidth: true }
                        SmallButton {
                            text: "All apps  ›"
                            onClicked: {
                                start.view = "all";
                                field.forceActiveFocus();
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: start.columns
                        spacing: Theme.spacingSmall
                        readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                        Repeater {
                            model: start.pinned
                            delegate: AppCell {
                                required property var modelData
                                required property int index
                                width: parent.cellWidth
                                app: modelData
                                cellIndex: index
                            }
                        }
                    }

                    Caption {
                        visible: start.pinned.length === 0
                        text: "Right-click an app in All apps to pin it here."
                    }

                    Caption {
                        visible: start.recommended.length > 0
                        topPadding: Theme.spacingMedium
                        text: "MOST USED"
                        font.bold: true
                    }

                    Grid {
                        width: parent.width
                        columns: start.columns
                        spacing: Theme.spacingSmall
                        readonly property real cellWidth: (width - spacing * (columns - 1)) / columns

                        Repeater {
                            model: start.recommended
                            delegate: AppCell {
                                required property var modelData
                                required property int index
                                width: parent.cellWidth
                                app: modelData
                                cellIndex: start.pinned.length + index
                            }
                        }
                    }
                }
            }

            // ---- All apps / search results: a list ----
            Column {
                visible: start.mode !== "home"
                width: parent.width
                height: parent.height - field.height - footer.height - col.spacing * 2
                spacing: Theme.spacingMedium

                RowLayout {
                    id: listHeader
                    width: parent.width
                    Caption {
                        text: start.mode === "search" ? "RESULTS" : "ALL APPS"
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    SmallButton {
                        visible: start.mode === "all"
                        text: "‹  Back"
                        onClicked: {
                            start.view = "home";
                            field.forceActiveFocus();
                        }
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - listHeader.height - parent.spacing
                    clip: true
                    model: start.mode !== "home" ? start.results : []
                    spacing: Theme.spacingSmall
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Column {
                        id: entry
                        required property var modelData
                        required property int index
                        width: list.width

                        // A–Z heading in All apps, above the first app of each letter
                        readonly property string letter: modelData.name.charAt(0).toUpperCase()
                        Caption {
                            visible: start.mode === "all"
                                && (entry.index === 0 || start.results[entry.index - 1].name.charAt(0).toUpperCase() !== entry.letter)
                            text: entry.letter
                            color: Theme.accent
                            font.bold: true
                            topPadding: entry.index === 0 ? 0 : Theme.paddingSmall
                            bottomPadding: 2
                        }

                        ListRow {
                            id: row
                            readonly property var modelData: entry.modelData
                            width: list.width
                            height: 40
                            selected: entry.index === start.index
                            onEntered: start.index = entry.index
                            onClicked: start.launch(entry.modelData)

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingMedium

                                IconImage {
                                    implicitSize: 24
                                    source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                                    asynchronous: true
                                }
                                Text {
                                    text: row.modelData.name
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: ShellState.settings.startPinned.includes(row.modelData.id) ? "󰐃" : ""
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                onClicked: start.togglePin(row.modelData)
                            }
                        }
                    }
                }
            }

            // ---- Footer: user, lock, suspend, power ----
            Rectangle {
                id: footer
                width: parent.width
                height: 44
                color: Theme.bgItem
                border.color: Theme.borderSubtle
                border.width: Theme.borderWidth
                radius: Theme.radius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.rightMargin: Theme.paddingSmall
                    spacing: Theme.paddingSmall

                    Text {
                        text: "󰀄"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontIcon
                    }
                    Text {
                        text: start.userName
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: [
                            { icon: "󰌾", tip: "Lock", cmd: ["loginctl", "lock-session"] },
                            { icon: "󰤄", tip: "Suspend", cmd: ["systemctl", "suspend"] },
                            { icon: "⏻", tip: "Power", popup: "system" }
                        ]
                        delegate: BarButton {
                            id: footBtn
                            required property var modelData
                            text: modelData.icon
                            onLeftClicked: {
                                if (footBtn.modelData.popup) {
                                    ShellState.openPopup(footBtn.modelData.popup, popup.screen, footBtn.centerX());
                                } else {
                                    ShellState.closePopup("start");
                                    Quickshell.execDetached(footBtn.modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
