import QtQuick
import Quickshell
import Quickshell.Wayland

// macOS mode: the dock, centered at the bottom of each screen. Launcher, then
// pinned and running apps; a dot marks running apps. Same clicks as the
// Windows taskbar: click to switch (again to minimize), middle-click for a new
// window, right-click to pin or unpin.
PanelWindow {
    id: dock

    required property var modelData
    required property var tools

    screen: modelData
    visible: Desktop.mode === "macos"
    color: "transparent"
    anchors { bottom: true }
    margins { bottom: Desktop.edgeGap }
    exclusiveZone: Desktop.dockHeight + Desktop.edgeGap
    implicitWidth: frame.width
    implicitHeight: Desktop.dockHeight
    WlrLayershell.namespace: "quickshell-dock"

    Rectangle {
        id: frame
        width: tiles.width + Desktop.dockPadding * 2
        height: Desktop.dockHeight
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius

        Row {
            id: tiles
            x: Desktop.dockPadding
            y: Desktop.dockPadding
            spacing: Theme.spacingSmall

            AppTile {
                id: launchTile
                width: Desktop.dockTile
                height: Desktop.dockTile
                glyph: "󰀻"
                tooltip: "Apps (Super+Space)"
                iconSize: Desktop.dockIcon
                indicator: "dot"
                focused: dock.tools.launcher.active
                onLeftClicked: ShellState.togglePopup("launcher", dock.screen, launchTile.centerX())
            }

            // Separator between the launcher and the apps
            Rectangle {
                width: Theme.borderWidth
                height: Desktop.dockTile - Desktop.dockPadding * 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.borderSubtle
            }

            Repeater {
                model: WindowList.barApps(ShellState.settings.pinnedApps, dock.modelData.name)
                delegate: AppTile {
                    required property var modelData
                    width: Desktop.dockTile
                    height: Desktop.dockTile
                    appId: modelData.appId
                    iconSize: Desktop.dockIcon
                    indicator: "dot"
                    running: WindowList.isRunning(modelData.appId, dock.modelData.name)
                    focused: WindowList.isFocusedApp(modelData.appId, dock.modelData.name)
                    badge: dock.tools.notifications.countFor(modelData.appId)
                    tooltip: running ? "" : WindowList.nameFor(modelData.appId)
                    onHoveredChanged: hovered ? previews.show(this, modelData.appId, dock.modelData.name) : previews.leave()
                    onLeftClicked: {
                        previews.hide();
                        WindowList.clickApp(modelData.appId, dock.modelData.name);
                    }
                    onMiddleClicked: WindowList.launch(modelData.appId)
                    onRightClicked: ShellState.togglePin(modelData.appId)
                }
            }
        }
    }

    WindowPreviews {
        id: previews
        barWindow: dock
    }
}
