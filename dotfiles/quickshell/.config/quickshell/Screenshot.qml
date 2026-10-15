import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: screenshotScope

    readonly property bool active: ShellState.activePopup === "screenshot"
    property int targetIndex: 0 // 0: area, 1: window, 2: screen
    property int modeIndex: 0   // index into modes
    property int delayIndex: 0  // index into delays

    // Recording state (wf-recorder)
    readonly property bool recording: recorder.running && recordFile !== ""
    property string recordFile: ""
    property int recordSeconds: 0
    readonly property string recordText: {
        const m = Math.floor(recordSeconds / 60);
        const s = recordSeconds % 60;
        return "● REC " + m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property var targets: [
        { id: "area", label: "Select Area", icon: "󰩭" },
        { id: "window", label: "Window", icon: "󰖯" },
        { id: "screen", label: "Screen", icon: "󰍹" }
    ]

    readonly property var modes: [
        { id: "copy", label: "Copy", icon: "󰆏", key: "C" },
        { id: "save", label: "Save", icon: "󰆓", key: "S" },
        { id: "edit", label: "Annotate", icon: "󰏫", key: "A" },
        { id: "record", label: "Record", icon: "󰑋", key: "R" }
    ]

    readonly property var delays: [0, 3, 5, 10]
    readonly property bool isRecordMode: modes[modeIndex].id === "record"

    // Shell snippets. Arguments: $1 = output name, $2 = delay seconds.
    readonly property string slurpStyle: "-b 000000a0 -c " + String(Theme.border).replace("#", "") + "ff -s 00000040 -w 1"
    readonly property string geomScript: {
        const t = targets[targetIndex].id;
        if (t === "area") return "GEOM=$(slurp -d " + slurpStyle + ") || exit 0; ";
        if (t === "window") {
            return "GEOM=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"' | slurp -r "
                + slurpStyle + ") || exit 0; ";
        }
        return "GEOM=''; ";
    }
    readonly property string fileScript:
        "DIR=\"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\"; mkdir -p \"$DIR\"; STAMP=$(date +%Y-%m-%d_%H-%M-%S); "

    function triggerCapture() {
        const mode = modes[modeIndex].id;
        ShellState.closePopup("screenshot");
        if (mode === "record") {
            startRecording();
            return;
        }

        const label = targets[targetIndex].label;
        const shot = "shot() { if [ -n \"$GEOM\" ]; then grim -g \"$GEOM\" \"$@\"; else grim -o \"$OUT\" \"$@\"; fi; }; ";
        let action = "";
        if (mode === "copy") {
            action = "shot - | wl-copy --type image/png && notify-send -t 3000 'Screenshot' '" + label + " copied to clipboard'";
        } else if (mode === "save") {
            action = "FILE=\"$DIR/screenshot_$STAMP.png\"; shot \"$FILE\" && notify-send -t 3000 -i \"$FILE\" 'Screenshot Saved' \"$(basename \"$FILE\")\"";
        } else {
            action = "shot - | swappy -f -";
        }
        const script = "OUT=\"$1\"; sleep 0.2; " + geomScript + "sleep \"$2\"; " + fileScript
            + shot + action;
        // Own scope: swappy (annotate) is a GUI app that should outlive a shell restart.
        ShellState.launch(["sh", "-c", script, "_", outputName(), String(delays[delayIndex])]);
    }

    function outputName() {
        const s = ShellState.focusedScreen;
        return s ? s.name : "";
    }

    function startRecording() {
        if (recorder.running) return;
        recordFile = "";
        recordSeconds = 0;
        // Prints the target file once a region is chosen, then execs wf-recorder
        // so SIGINT reaches it directly and the file is finalized.
        const script = "OUT=\"$1\"; sleep 0.2; " + geomScript + fileScript
            + "FILE=\"$DIR/recording_$STAMP.mp4\"; echo \"$FILE\"; "
            + "if [ -n \"$GEOM\" ]; then exec wf-recorder -g \"$GEOM\" -f \"$FILE\"; else exec wf-recorder -o \"$OUT\" -f \"$FILE\"; fi";
        recorder.command = ["sh", "-c", script, "_", outputName()];
        recorder.running = true;
    }

    function stopRecording() {
        if (recorder.running) recorder.signal(2); // SIGINT
    }

    Process {
        id: recorder
        stdout: SplitParser {
            onRead: function(line) {
                if (screenshotScope.recordFile === "") screenshotScope.recordFile = line.trim();
            }
        }
        onExited: function(code) {
            const file = screenshotScope.recordFile;
            screenshotScope.recordFile = "";
            if (file !== "") {
                Quickshell.execDetached(["notify-send", "-t", "4000", "Recording Saved", file.split("/").pop()]);
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: screenshotScope.recording
        onTriggered: screenshotScope.recordSeconds++
    }

    IpcHandler {
        target: "screenshot"
        function open() { ShellState.openPopup("screenshot"); }
        function hide() { ShellState.closePopup("screenshot"); }
        function toggle() { ShellState.togglePopup("screenshot"); }
        function stopRecording() { screenshotScope.stopRecording(); }
    }

    ShellPopup {
        name: "screenshot"
        centered: true
        panelWidth: 500

        Column {
            id: contentCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onReturnPressed: screenshotScope.triggerCapture()
            Keys.onEnterPressed: screenshotScope.triggerCapture()
            Keys.onLeftPressed: screenshotScope.targetIndex = (screenshotScope.targetIndex + 2) % 3
            Keys.onRightPressed: screenshotScope.targetIndex = (screenshotScope.targetIndex + 1) % 3
            Keys.onUpPressed: screenshotScope.modeIndex = (screenshotScope.modeIndex + screenshotScope.modes.length - 1) % screenshotScope.modes.length
            Keys.onDownPressed: screenshotScope.modeIndex = (screenshotScope.modeIndex + 1) % screenshotScope.modes.length
            Keys.onTabPressed: screenshotScope.modeIndex = (screenshotScope.modeIndex + 1) % screenshotScope.modes.length
            Keys.onPressed: function(event) {
                const k = event.key;
                if (k >= Qt.Key_1 && k <= Qt.Key_3) screenshotScope.targetIndex = k - Qt.Key_1;
                else if (k === Qt.Key_C) screenshotScope.modeIndex = 0;
                else if (k === Qt.Key_S) screenshotScope.modeIndex = 1;
                else if (k === Qt.Key_A) screenshotScope.modeIndex = 2;
                else if (k === Qt.Key_R) screenshotScope.modeIndex = 3;
                else if (k === Qt.Key_D) screenshotScope.delayIndex = (screenshotScope.delayIndex + 1) % screenshotScope.delays.length;
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "SCREENSHOT"
                    Layout.fillWidth: true
                }
                SmallButton {
                    visible: screenshotScope.recording
                    text: "STOP " + screenshotScope.recordText
                    critical: true
                    onClicked: screenshotScope.stopRecording()
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                Caption { text: "TARGET" }
                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium
                    Repeater {
                        model: screenshotScope.targets
                        delegate: OptionTile {
                            required property var modelData
                            required property int index
                            width: (contentCol.width - Theme.spacingMedium * 2) / 3
                            height: 64
                            icon: modelData.icon
                            label: modelData.label + " [" + (index + 1) + "]"
                            selected: screenshotScope.targetIndex === index
                            onClicked: screenshotScope.targetIndex = index
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                Caption { text: "ACTION" }
                Row {
                    width: parent.width
                    spacing: Theme.spacingMedium
                    Repeater {
                        model: screenshotScope.modes
                        delegate: OptionTile {
                            required property var modelData
                            required property int index
                            width: (contentCol.width - Theme.spacingMedium * 3) / 4
                            height: 54
                            iconSize: Theme.fontLarge
                            icon: modelData.icon
                            label: modelData.label + " [" + modelData.key + "]"
                            selected: screenshotScope.modeIndex === index
                            onClicked: screenshotScope.modeIndex = index
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width
                Caption {
                    text: "DELAY [D]"
                    Layout.fillWidth: true
                }
                Repeater {
                    model: screenshotScope.delays
                    delegate: SmallButton {
                        required property int modelData
                        required property int index
                        text: modelData === 0 ? "NONE" : modelData + "s"
                        highlighted: screenshotScope.delayIndex === index
                        opacity: screenshotScope.isRecordMode ? 0.4 : 1.0
                        onClicked: screenshotScope.delayIndex = index
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 42
                color: captureMouse.containsMouse ? Theme.bgSelected : Theme.bgItem
                border.color: screenshotScope.isRecordMode ? Theme.borderCritical : Theme.border
                border.width: Theme.borderWidth
                radius: Theme.radius

                Text {
                    anchors.centerIn: parent
                    text: (screenshotScope.isRecordMode ? (screenshotScope.recording ? "ALREADY RECORDING" : "START RECORDING (")
                                                        : "CAPTURE (")
                        + (screenshotScope.recording && screenshotScope.isRecordMode ? ""
                           : screenshotScope.targets[screenshotScope.targetIndex].label.toUpperCase() + " - "
                             + screenshotScope.modes[screenshotScope.modeIndex].label.toUpperCase()
                             + (screenshotScope.delays[screenshotScope.delayIndex] > 0 && !screenshotScope.isRecordMode
                                ? ", " + screenshotScope.delays[screenshotScope.delayIndex] + "s" : "") + ")")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                    font.bold: true
                }

                MouseArea {
                    id: captureMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: screenshotScope.triggerCapture()
                }
            }

            Hint {
                text: "←/→ 1-3 target • ↑/↓ C/S/A/R action • D delay • Enter capture"
            }
        }
    }
}
