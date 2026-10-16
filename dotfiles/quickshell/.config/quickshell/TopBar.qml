import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// macOS mode: the bar along the top. Launcher button, the focused app's name
// and workspaces on the left; the shared status cluster and the clock on the
// right. The dock (Dock.qml) sits at the bottom.
PanelWindow {
    id: bar

    required property var modelData
    required property var tools

    screen: modelData
    visible: Desktop.mode === "macos"
    color: Theme.bgPanel
    anchors { top: true; left: true; right: true }
    implicitHeight: Desktop.barHeight
    WlrLayershell.namespace: "quickshell-bar"

    Rectangle {
        anchors.fill: parent
        color: Theme.bgPanel
        border.width: 0   // flush against the screen edge: no frame
        radius: Theme.radius

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingMedium
            anchors.rightMargin: Theme.paddingMedium
            spacing: Theme.spacingMedium

            BarButton {
                id: logoBtn
                text: "󰣛"
                tooltip: "Apps (Super+Space)"
                textColor: Theme.accent
                highlighted: bar.tools.launcher.active
                onLeftClicked: ShellState.togglePopup("launcher", bar.screen, logoBtn.centerX())
            }

            Text {
                text: WindowList.focusedWindow ? WindowList.nameFor(WindowList.focusedWindow.appId) : "Desktop"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: 280
            }

            WorkspacePills {
                screenName: bar.modelData.name
                hideSingle: true
            }

            BarButton {
                id: mediaBtn
                visible: bar.tools.media.hasPlayer
                icon: false
                text: bar.tools.media.barText
                highlighted: bar.tools.media.active
                onLeftClicked: ShellState.togglePopup("media", bar.screen, mediaBtn.centerX())
                onMiddleClicked: if (bar.tools.media.player) bar.tools.media.player.togglePlaying()
            }

            RecordingPill { tools: bar.tools }

            Item { Layout.fillWidth: true }

            StatusArea { barWindow: bar; tools: bar.tools }

            Text {
                Layout.leftMargin: Theme.paddingSmall
                text: Clock.menubar()
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontNormal
            }
        }
    }
}
