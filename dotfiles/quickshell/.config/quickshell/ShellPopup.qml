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

    // 0 -> 1 as the popup opens; it stays mapped until it has faded out.
    // Every popup animates the same way: a short fade, sliding in from the
    // bar's edge (or easing in, when centered).
    property real progress: shown ? 1 : 0
    Behavior on progress { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    screen: ShellState.popupScreen
    visible: shown || progress > 0.001
    color: dim ? Qt.rgba(Theme.bgOverlay.r, Theme.bgOverlay.g, Theme.bgOverlay.b, Theme.bgOverlay.a * progress) : "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    // Let go of the keyboard and pointer as soon as it starts closing
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: shown ? null : emptyRegion

    Region { id: emptyRegion }
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
        opacity: popup.progress
        scale: popup.centered ? 0.97 + 0.03 * popup.progress : 1
        transform: Translate {
            y: popup.centered ? 0 : (1 - popup.progress) * 10 * (Desktop.barOnTop ? -1 : 1)
        }
        color: Theme.bgPanel
        // The active surface: accent, like a focused window (PanelFocus.qml)
        border.color: Theme.accent
        border.width: Theme.panelBorderWidth
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
