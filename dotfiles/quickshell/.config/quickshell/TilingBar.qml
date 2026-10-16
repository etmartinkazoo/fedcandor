import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Tiling mode: the bar along the bottom. Launch button, workspaces, media and
// recording on the left; the clock centered; the shared status cluster on the right.
PanelWindow {
    id: bar

    required property var modelData
    required property var tools

    screen: modelData
    visible: Desktop.mode === "tiling"
    color: Theme.bgPanel
    anchors { bottom: true; left: true; right: true }
    implicitHeight: Desktop.barHeight
    WlrLayershell.namespace: "quickshell-bar"

    Rectangle {
        anchors.fill: parent
        color: Theme.bgPanel
        border.width: 0   // flush against the screen edge: no frame
        radius: Theme.radius

        // Clock, at the exact center of the bar
        Text {
            anchors.centerIn: parent
            text: Clock.full(bar.width >= 1600)
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontNormal
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.paddingMedium
            anchors.rightMargin: Theme.paddingMedium
            spacing: Theme.spacingMedium

            Row {
                spacing: Theme.paddingSmall

                BarButton {
                    id: launchBtn
                    icon: false
                    text: "LAUNCH"
                    tooltip: "Apps (Super+Space)"
                    highlighted: bar.tools.launcher.active
                    onLeftClicked: ShellState.togglePopup("launcher", bar.screen)
                }

                WorkspacePills { screenName: bar.modelData.name }

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
            }

            Item { Layout.fillWidth: true }

            StatusArea { barWindow: bar; tools: bar.tools }
        }
    }
}
