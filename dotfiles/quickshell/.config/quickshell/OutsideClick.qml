import QtQuick
import Quickshell
import Quickshell.Wayland

// Clicking anywhere outside the open panel closes it. ShellPopups cover their
// screen and do this themselves; this catches the rest (the slide-in Phone
// and Chat panels, and other screens). One transparent overlay per screen,
// mapped once at startup so every panel, mapped later, stacks above it. It
// only takes input while a panel is open.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-outside-click"
        mask: ShellState.activePopup !== "" ? null : emptyRegion

        Region { id: emptyRegion }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: ShellState.closePopup()
        }
    }
}
