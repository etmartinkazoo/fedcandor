import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Side chat (Super+A): a persistent conversation for ideas, plans, writing.
// A sheet on the left, the same size as the phone sheet on the right.
//
// Under the hood: fedcandor-chat, a bridge to the opencode service with the
// free DeepSeek model. It's conversation only: every tool request is
// rejected, so the model never runs commands or reads files.
//
// Select text anywhere and an "Ask in chat" chip appears at the left edge for
// a few seconds; Super+Shift+A sends the selection directly. Selections stay
// in memory and only reach the chat when you click.
Scope {
    id: chat

    readonly property bool active: ShellState.activePopup === "chat"
    property var messages: []          // [{ role, text, time }]
    property string streaming: ""      // the answer as it arrives
    property bool busy: false
    property string error: ""
    property string model: ""

    function toggle() { ShellState.togglePopup("chat"); }

    // base64 → UTF-8 text (Qt.atob is deprecated and works on Latin-1)
    function decodeBase64Utf8(b64) {
        const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        let bits = 0, value = 0, pct = "";
        for (const ch of b64) {
            const v = abc.indexOf(ch);
            if (v < 0) continue;            // padding, whitespace
            value = (value << 6) | v;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                pct += "%" + ((value >> bits) & 0xff).toString(16).padStart(2, "0");
            }
        }
        return decodeURIComponent(pct);
    }

    function send(text) {
        const t = text.trim();
        if (t === "" || busy) return;
        messages = messages.concat([{ role: "user", text: t, time: Date.now() / 1000 }]);
        busy = true;
        streaming = "";
        error = "";
        bridge.write(JSON.stringify({ cmd: "send", text: t }) + "\n");
        input.text = "";
        scrollSoon.restart();
    }

    function stop() { bridge.write(JSON.stringify({ cmd: "stop" }) + "\n"); }

    function newChat() {
        if (busy) stop();
        bridge.write(JSON.stringify({ cmd: "new" }) + "\n");
    }

    // Open the chat with `text` quoted in the input, ready for a question
    function askAbout(text) {
        const quoted = text.trim().split("\n").map(l => "> " + l).join("\n");
        ShellState.openPopup("chat");
        input.text = quoted + "\n\n";
        Qt.callLater(() => {
            input.forceActiveFocus();
            input.cursorPosition = input.text.length;
        });
        chip.hide();
    }

    // ---- The bridge ----
    Process {
        id: bridge
        command: [Quickshell.env("HOME") + "/.local/bin/fedcandor-chat"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: function(line) {
                let ev;
                try { ev = JSON.parse(line); } catch (e) { return; }
                if (ev.type === "history") {
                    chat.messages = ev.messages;
                    chat.model = ev.model ?? "";
                    chat.busy = false;
                    chat.streaming = "";
                } else if (ev.type === "delta") {
                    chat.streaming += ev.text;
                    scrollSoon.restart();
                } else if (ev.type === "done" || ev.type === "error") {
                    if (chat.streaming.trim() !== "")
                        chat.messages = chat.messages.concat([{ role: "assistant", text: chat.streaming, time: Date.now() / 1000 }]);
                    chat.streaming = "";
                    chat.busy = false;
                    chat.error = ev.type === "error" ? (ev.message ?? "") : "";
                    scrollSoon.restart();
                }
            }
        }
        // Restart if it ever exits
        onExited: restartBridge.restart()
    }

    Timer {
        id: restartBridge
        interval: 3000
        onTriggered: bridge.running = true
    }

    Timer {
        id: scrollSoon
        interval: 30
        onTriggered: list.positionViewAtEnd()
    }

    // ---- Text selection → "Ask in chat" ----
    // wl-paste prints each new primary selection, base64 on one line.
    Process {
        id: selectionWatch
        running: ShellState.settings.chatSelectionChip
        command: ["wl-paste", "--primary", "--type", "text", "--watch", "sh", "-c", "head -c 8000 | base64 -w0; echo"]
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    chip.pending = chat.decodeBase64Utf8(line.trim());
                } catch (e) {
                    return;
                }
                chipDelay.restart();
            }
        }
    }

    // Wait for the selection to settle (it changes while dragging)
    Timer {
        id: chipDelay
        interval: 600
        onTriggered: {
            const t = chip.pending.trim();
            if (t.length >= 3 && t !== chip.text && !chat.active && ShellState.activePopup === "") chip.show(t);
        }
    }

    // Super+Shift+A: the current selection, straight into the chat
    Process {
        id: readSelection
        command: ["wl-paste", "--primary", "--type", "text", "--no-newline"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") chat.askAbout(text.slice(0, 8000));
                else ShellState.openPopup("chat");
            }
        }
    }

    IpcHandler {
        target: "chat"
        function toggle() { chat.toggle(); }
        function open() { ShellState.openPopup("chat"); }
        function hide() { ShellState.closePopup("chat"); }
        function askSelection() { readSelection.running = true; }
        function ask(text: string) { chat.askAbout(text); }
        function send(text: string) { ShellState.openPopup("chat"); chat.send(text); }
        function newChat() { chat.newChat(); }
    }

    // ---- The chip ----
    PanelWindow {
        id: chip

        property string pending: ""
        property string text: ""
        property bool shown: false

        function show(t) {
            text = t;
            shown = true;
            chipHide.restart();
        }
        function hide() {
            shown = false;
            chipHide.stop();
        }

        screen: ShellState.focusedScreen
        visible: shown
        color: "transparent"
        anchors { left: true }
        margins { left: Desktop.edgeGap }
        implicitWidth: chipBox.width
        implicitHeight: chipBox.height
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "fedcandor-chat-chip"

        Timer {
            id: chipHide
            interval: 6000
            onTriggered: if (!chipMouse.containsMouse) chip.hide(); else restart()
        }

        Rectangle {
            id: chipBox
            width: chipRow.implicitWidth + Theme.paddingLarge * 2
            height: Theme.rowHeight
            color: chipMouse.containsMouse ? Theme.bgSelected : Theme.bgPanel
            border.color: Theme.border
            border.width: Theme.borderWidth
            radius: Theme.radius

            RowLayout {
                id: chipRow
                anchors.centerIn: parent
                spacing: Theme.spacingMedium

                Text {
                    text: "󰭹"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontIcon
                }
                Text {
                    text: "Ask in chat"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    font.bold: true
                }
                Caption {
                    text: "“" + chip.text.replace(/\s+/g, " ").slice(0, 32) + (chip.text.length > 32 ? "…" : "") + "”"
                    Layout.maximumWidth: 240
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function(m) {
                    if (m.button === Qt.RightButton) chip.hide();
                    else chat.askAbout(chip.text);
                }
            }
        }
    }

    // ---- The sheet ----
    PanelWindow {
        id: panel

        // 0 = shown, 1 = off-screen to the left
        property real slide: chat.active ? 0 : 1
        Behavior on slide { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        screen: ShellState.popupScreen
        visible: chat.active || slide < 1
        color: "transparent"
        anchors { top: true; bottom: true; left: true }
        margins {
            top: Desktop.barOnTop ? Desktop.popupInset : Desktop.edgeGap
            bottom: Desktop.barOnTop ? Desktop.edgeGap : Desktop.popupInset
            left: Desktop.edgeGap
        }
        implicitWidth: 440
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: chat.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-chat"

        onVisibleChanged: if (visible && chat.active) Qt.callLater(() => { input.forceActiveFocus(); list.positionViewAtEnd(); })

        Rectangle {
            id: frame
            width: parent.width
            height: parent.height
            x: -panel.slide * (parent.width + Desktop.edgeGap)
            color: Theme.bgPanel
            border.color: Theme.border
            border.width: Theme.borderWidth
            radius: Theme.radius

            FocusScope {
                anchors.fill: parent
                anchors.margins: Theme.paddingLarge
                focus: true
                Keys.onEscapePressed: ShellState.closePopup("chat")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingMedium

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.headerHeight
                        spacing: Theme.paddingSmall

                        PanelTitle { text: "CHAT" }
                        Caption {
                            Layout.fillWidth: true
                            text: chat.model.replace(/-/g, " ").replace(" free", " · free")
                            elide: Text.ElideRight
                        }
                        SmallButton {
                            text: ShellState.settings.chatSelectionChip ? "󰒅 ON" : "󰒅 OFF"
                            highlighted: ShellState.settings.chatSelectionChip
                            onClicked: ShellState.settings.chatSelectionChip = !ShellState.settings.chatSelectionChip
                        }
                        SmallButton {
                            text: "NEW"
                            onClicked: chat.newChat()
                        }
                    }

                    // Conversation
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.spacingLarge
                        boundsBehavior: Flickable.StopAtBounds
                        model: chat.busy ? chat.messages.concat([{ role: "assistant", text: chat.streaming, live: true }]) : chat.messages

                        delegate: Item {
                            id: msg
                            required property var modelData
                            readonly property bool mine: modelData.role === "user"
                            width: list.width
                            height: bubble.height

                            Rectangle {
                                id: bubble
                                anchors.right: msg.mine ? parent.right : undefined
                                anchors.left: msg.mine ? undefined : parent.left
                                width: msg.mine ? Math.min(list.width * 0.85, body.implicitWidth + Theme.paddingLarge * 2) : list.width
                                height: body.implicitHeight + (msg.mine ? Theme.paddingMedium * 2 : 0)
                                color: msg.mine ? Theme.bgSelected : "transparent"
                                radius: Theme.radius

                                TextEdit {
                                    id: body
                                    x: msg.mine ? Theme.paddingLarge : 0
                                    y: msg.mine ? Theme.paddingMedium : 0
                                    width: msg.mine ? Math.min(list.width * 0.85 - Theme.paddingLarge * 2, implicitWidth) : list.width
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    textFormat: msg.mine ? TextEdit.PlainText : TextEdit.MarkdownText
                                    text: msg.modelData.live && msg.modelData.text === "" ? "…" : msg.modelData.text
                                    color: Theme.textPrimary
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.bgPanel
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                    onLinkActivated: function(link) { Qt.openUrlExternally(link); }
                                }
                            }
                        }

                        // Empty conversation
                        Column {
                            anchors.centerIn: parent
                            width: parent.width - Theme.paddingLarge * 2
                            visible: chat.messages.length === 0 && !chat.busy
                            spacing: Theme.spacingMedium
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "󰭹"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: 32
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: "Think out loud: ideas, plans, writing, questions."
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                wrapMode: Text.Wrap
                            }
                            Caption {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: "Select text anywhere to bring it here (or Super+Shift+A). The chat can't see your screen or files, and keeps going between sessions."
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    // Status: error, or stop while answering
                    RowLayout {
                        Layout.fillWidth: true
                        visible: chat.busy || chat.error !== ""
                        Caption {
                            Layout.fillWidth: true
                            text: chat.busy ? (chat.streaming === "" ? "thinking…" : "writing…") : chat.error
                            color: chat.busy ? Theme.textSecondary : Theme.borderCritical
                            wrapMode: Text.Wrap
                        }
                        SmallButton {
                            visible: chat.busy
                            text: "STOP"
                            onClicked: chat.stop()
                        }
                    }

                    // Input
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(160, Math.max(Theme.rowHeight + 6, input.implicitHeight + Theme.paddingMedium * 2))
                        color: Theme.bgItem
                        radius: Theme.radius

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: Theme.paddingMedium

                            TextArea {
                                id: input
                                focus: true
                                wrapMode: TextArea.Wrap
                                placeholderText: chat.busy ? "Wait for the answer, or Stop" : "Message…   (Enter sends, Shift+Enter for a new line)"
                                placeholderTextColor: Theme.textPlaceholder
                                color: Theme.textPrimary
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.bgPanel
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                background: null
                                padding: 0

                                Keys.onPressed: function(event) {
                                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                        chat.send(input.text);
                                        event.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    Hint {
                        Layout.fillWidth: true
                        text: "Enter send • Shift+Enter new line • Esc close • NEW starts over"
                    }
                }
            }
        }
    }
}
