import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Windows mode: a taskbar along the bottom. Start button and app buttons
// (pinned first, then running) on the left; workspaces, the shared status
// cluster and a two-line clock on the right.
//
// App buttons: click to switch to the app (again to minimize it; with several
// windows, click cycles them), middle-click for a new window, right-click to
// pin or unpin.
PanelWindow {
    id: bar

    required property var modelData
    required property var tools

    screen: modelData
    visible: Desktop.mode === "windows"
    color: Theme.bgPanel
    anchors { bottom: true; left: true; right: true }
    implicitHeight: Desktop.barHeight
    WlrLayershell.namespace: "quickshell-bar"

    readonly property int tileHeight: Desktop.barHeight - 4

    Rectangle {
        anchors.fill: parent
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingMedium
            anchors.rightMargin: Theme.paddingMedium
            spacing: Theme.spacingMedium

            Row {
                spacing: Theme.spacingSmall

                AppTile {
                    id: startBtn
                    width: Desktop.taskTile
                    height: bar.tileHeight
                    glyph: "󰣛"
                    iconSize: Desktop.taskIcon
                    focused: bar.tools.start.active
                    onLeftClicked: ShellState.togglePopup("start", bar.screen, startBtn.centerX())
                }

                AppTile {
                    id: overviewBtn
                    width: Desktop.taskTile
                    height: bar.tileHeight
                    glyph: "󰕰"
                    iconSize: Desktop.taskIcon
                    focused: bar.tools.overview.active
                    onLeftClicked: ShellState.togglePopup("overview", bar.screen)
                }

                Repeater {
                    model: WindowList.barApps(ShellState.settings.pinnedApps)
                    delegate: AppTile {
                        required property var modelData
                        width: Desktop.taskTile
                        height: bar.tileHeight
                        appId: modelData.appId
                        iconSize: Desktop.taskIcon
                        running: WindowList.isRunning(modelData.appId)
                        focused: WindowList.focusedWindow !== null && WindowList.focusedWindow.appId === modelData.appId
                        badge: bar.tools.notifications.countFor(modelData.appId)
                        onHoveredChanged: hovered ? previews.show(this, modelData.appId) : previews.leave()
                        onLeftClicked: {
                            previews.hide();
                            WindowList.clickApp(modelData.appId);
                        }
                        onMiddleClicked: WindowList.launch(modelData.appId)
                        onRightClicked: ShellState.togglePin(modelData.appId)
                    }
                }

                RecordingPill {
                    anchors.verticalCenter: parent.verticalCenter
                    tools: bar.tools
                }
            }

            Item { Layout.fillWidth: true }

            WorkspacePills {
                screenName: bar.modelData.name
                hideSingle: true
            }

            StatusArea { barWindow: bar; tools: bar.tools }

            Column {
                Layout.leftMargin: Theme.paddingSmall
                Text {
                    anchors.right: parent.right
                    text: Clock.time()
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                }
                Text {
                    anchors.right: parent.right
                    text: Clock.shortDate()
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }

    WindowPreviews {
        id: previews
        barWindow: bar
    }
}
