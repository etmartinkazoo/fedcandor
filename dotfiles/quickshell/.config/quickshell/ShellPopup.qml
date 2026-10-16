import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared popup frame. Either anchored next to the bar (at ShellState.popupAnchorX)
// or centered with a dimmed backdrop. Content goes into a FocusScope, so a child
// with `focus: true` receives keys when the popup opens. Escape closes the popup
// unless a child handles it first.
PanelWindow {
    id: popup

    required property string name
    property bool centered: false
    property bool dim: centered
    property int panelWidth: 340
    property int panelHeight: 0          // 0 = size to content
    property real defaultRightOffset: 150 // fallback x (from right edge) when opened via IPC
    readonly property bool shown: ShellState.activePopup === name
    readonly property alias focusScope: scope
    default property alias content: scope.data

    function close() { ShellState.closePopup(name); }

    screen: ShellState.popupScreen
    visible: shown
    color: dim ? Theme.bgOverlay : "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-popup"

    onShownChanged: if (shown) Qt.callLater(() => scope.forceActiveFocus())

    MouseArea {
        anchors.fill: parent
        onClicked: popup.close()
    }

    Rectangle {
        id: frame
        x: popup.centered
            ? (parent.width - width) / 2
            : Math.max(10, Math.min(parent.width - width - 10,
                (ShellState.popupAnchorX >= 0 ? ShellState.popupAnchorX : parent.width - popup.defaultRightOffset) - width / 2))
        y: popup.centered ? (parent.height - height) / 2
            : (Desktop.barOnTop ? Desktop.popupInset : parent.height - height - Desktop.popupInset)
        width: popup.panelWidth
        height: popup.panelHeight > 0 ? popup.panelHeight : scope.childrenRect.height + Theme.paddingLarge * 2
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius

        MouseArea {
            anchors.fill: parent
            onClicked: scope.forceActiveFocus()
        }

        FocusScope {
            id: scope
            anchors.fill: parent
            anchors.margins: Theme.paddingLarge
            focus: true
            Keys.onEscapePressed: popup.close()
        }
    }
}
