import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit as Pk

// Themed polkit authentication agent (replaces lxqt-policykit-agent).
Scope {
    id: polkitScope

    Pk.PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    readonly property bool showing: agent.isActive && flow !== null

    PanelWindow {
        screen: ShellState.focusedScreen
        visible: polkitScope.showing
        color: Theme.bgOverlay
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-polkit"

        onVisibleChanged: {
            if (visible) {
                authField.text = "";
                Qt.callLater(() => authField.forceActiveFocus());
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 440
            height: authCol.implicitHeight + Theme.paddingLarge * 2
            color: Theme.bgPanel
            border.color: polkitScope.flow && polkitScope.flow.supplementaryIsError ? Theme.borderCritical : Theme.border
            border.width: Theme.borderWidth
            radius: Theme.radius

            Column {
                id: authCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.paddingLarge
                spacing: Theme.spacingLarge

                PanelTitle { text: "󰒃  AUTHENTICATION REQUIRED" }

                Text {
                    width: parent.width
                    text: polkitScope.flow ? polkitScope.flow.message : ""
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    wrapMode: Text.Wrap
                }

                Caption {
                    width: parent.width
                    text: polkitScope.flow ? polkitScope.flow.actionId : ""
                    color: Theme.textMuted
                }

                ThemedField {
                    id: authField
                    width: parent.width
                    enabled: polkitScope.flow !== null && polkitScope.flow.isResponseRequired
                    echoMode: polkitScope.flow && polkitScope.flow.responseVisible ? TextInput.Normal : TextInput.Password
                    placeholderText: polkitScope.flow && polkitScope.flow.inputPrompt !== "" ? polkitScope.flow.inputPrompt : "Password"
                    onAccepted: {
                        if (polkitScope.flow && polkitScope.flow.isResponseRequired) {
                            polkitScope.flow.submit(text);
                            text = "";
                        }
                    }
                    Keys.onEscapePressed: if (polkitScope.flow) polkitScope.flow.cancelAuthenticationRequest()
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: polkitScope.flow ? polkitScope.flow.supplementaryMessage : ""
                    color: polkitScope.flow && polkitScope.flow.supplementaryIsError ? Theme.borderCritical : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingMedium

                    Hint {
                        text: "Enter authenticate • Esc cancel"
                        Layout.fillWidth: true
                    }

                    SmallButton {
                        text: "CANCEL"
                        onClicked: if (polkitScope.flow) polkitScope.flow.cancelAuthenticationRequest()
                    }

                    SmallButton {
                        text: "AUTHENTICATE"
                        highlighted: true
                        onClicked: authField.accepted()
                    }
                }
            }
        }
    }
}
