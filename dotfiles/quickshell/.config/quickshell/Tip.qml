import QtQuick
import Quickshell

// Tooltip: the one used everywhere (bar buttons, taskbar, dock, title-bar
// buttons). Shows `text` next to `target` after the pointer rests on it;
// above the target, unless `below` (top bar, title bars).
Scope {
    id: tip

    required property Item target
    property string text: ""
    property bool hovered: false
    property bool below: Desktop.barOnTop

    property bool shown: false
    onHoveredChanged: {
        if (hovered && text !== "") delay.restart();
        else {
            delay.stop();
            shown = false;
        }
    }

    Timer {
        id: delay
        interval: 600
        onTriggered: tip.shown = true
    }

    LazyLoader {
        active: tip.shown && tip.text !== "" && ShellState.activePopup === ""

        PopupWindow {
            visible: true
            color: "transparent"
            anchor.item: tip.target
            anchor.edges: tip.below ? Edges.Bottom : Edges.Top
            anchor.gravity: tip.below ? Edges.Bottom : Edges.Top
            anchor.adjustment: PopupAdjustment.SlideX
            implicitWidth: box.width
            implicitHeight: box.height + gap

            readonly property int gap: 6

            Rectangle {
                id: box
                y: tip.below ? parent.gap : 0
                width: label.implicitWidth + Theme.paddingMedium * 2
                height: label.implicitHeight + Theme.paddingSmall * 2
                color: Theme.bgPanel
                border.color: Theme.border
                border.width: Theme.borderWidth
                radius: Theme.radius

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tip.text
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                }
            }
        }
    }
}
