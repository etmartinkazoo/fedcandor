import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

// Session lock (ext-session-lock). Locked via `fedcandor-lock`, which swayidle
// runs for idle, before-sleep and `loginctl lock-session`; it waits for
// isSecure() so suspend can't race the lock.
// Authenticates through the same PAM stack as swaylock (/etc/pam.d/swaylock).
Scope {
    id: lockScope

    property string password: ""
    property string status: ""
    property bool busy: false
    readonly property bool locked: sessionLock.locked
    readonly property string userName: Quickshell.env("USER") || ""

    signal clearInputs()

    function lock() {
        if (sessionLock.locked) return;
        password = "";
        status = "";
        busy = false;
        ShellState.closePopup();
        sessionLock.locked = true;
    }

    function tryUnlock() {
        if (busy || password === "") return;
        busy = true;
        status = "Checking…";
        if (!pam.start()) {
            busy = false;
            status = "Couldn't start authentication";
        }
    }

    function finish(message) {
        busy = false;
        status = message;
        password = "";
        clearInputs();
    }

    PamContext {
        id: pam
        config: "swaylock"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(lockScope.password);
            else if (pam.message !== "") lockScope.status = pam.message;
        }

        onCompleted: function(result) {
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                lockScope.finish("");
            } else {
                lockScope.finish(result === PamResult.MaxTries ? "Too many attempts" : "Wrong password");
            }
        }

        onError: function(err) {
            lockScope.finish("Authentication error: " + PamError.toString(err));
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: sessionLock.locked
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: surface
            color: Theme.darkerBackground

            Rectangle {
                anchors.centerIn: parent
                width: 380
                height: lockCol.implicitHeight + Theme.paddingLarge * 2 + 8
                color: Theme.bgPanel
                border.color: lockScope.status !== "" && !lockScope.busy ? Theme.borderCritical : Theme.border
                border.width: Theme.borderWidth
                radius: Theme.radius

                Column {
                    id: lockCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.paddingLarge * 2 - 8
                    spacing: Theme.spacingLarge

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            const d = clock.date;
                            const h = d.getHours() % 12 || 12;
                            return h + ":" + ("0" + d.getMinutes()).slice(-2) + (d.getHours() >= 12 ? "pm" : "am");
                        }
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 44
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.formatDate(clock.date, "dddd, MMMM d")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                    }

                    TextField {
                        id: passField
                        width: parent.width
                        height: 44
                        focus: true
                        enabled: !lockScope.busy
                        echoMode: TextInput.Password
                        horizontalAlignment: TextInput.AlignHCenter
                        leftPadding: Theme.inputPadding
                        rightPadding: Theme.inputPadding
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLarge
                        color: Theme.textPrimary
                        placeholderText: "󰌾  Password for " + lockScope.userName
                        placeholderTextColor: Theme.textPlaceholder
                        background: Rectangle {
                            color: Theme.bgItem
                            border.color: Theme.border
                            border.width: Theme.borderWidth
                            radius: Theme.radius
                        }
                        onTextChanged: lockScope.password = text
                        onAccepted: lockScope.tryUnlock()
                        Keys.onEscapePressed: text = ""
                        Component.onCompleted: forceActiveFocus()

                        Connections {
                            target: lockScope
                            function onClearInputs() {
                                passField.text = "";
                                passField.forceActiveFocus();
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: lockScope.status !== "" ? lockScope.status : "Enter to unlock"
                        color: lockScope.status !== "" && !lockScope.busy ? Theme.borderCritical : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock() { lockScope.lock(); }
        function isLocked(): bool { return sessionLock.locked; }
        // True once the compositor confirms every output is covered.
        function isSecure(): bool { return sessionLock.secure; }
    }
}
