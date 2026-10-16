import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Scope {
    id: audioScope

    readonly property bool active: ShellState.activePopup === "audio"
    property bool osdVisible: false
    property string osdTitle: "Volume"
    property string osdIcon: "󰕾"
    property int osdValue: 0
    property bool readyForOsd: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool isMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property int volumePct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false
    readonly property int micPct: source && source.audio ? Math.round(source.audio.volume * 100) : 0

    readonly property string barIcon: {
        if (!sink || isMuted || volumePct === 0) return "󰝟";
        if (volumePct < 35) return "󰕿";
        if (volumePct < 70) return "󰖀";
        return "󰕾";
    }
    readonly property string barText: barIcon + " " + (isMuted ? "MUTE" : (volumePct + "%"))
    readonly property string micIcon: micMuted ? "󰍭" : "󰍬"

    function nodesWhere(pred) {
        const list = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].audio && pred(list[i])) out.push(list[i]);
        }
        return out;
    }

    readonly property var audioSinks: nodesWhere(n => n.isSink && !n.isStream)
    readonly property var audioSources: nodesWhere(n => !n.isSink && !n.isStream)
    // Application playback streams (Quickshell marks them isStream + isSink).
    // Not filtered on `audio`/`properties`: those only populate once the node
    // is tracked, which happens in the PwObjectTracker below.
    readonly property var candidateStreams: {
        const list = Pipewire.nodes.values;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (n && n.isStream && n.isSink && n.name.indexOf("speech-dispatcher") !== 0) out.push(n);
        }
        return out;
    }

    // Hide stale/unbound nodes (no audio interface once tracked).
    readonly property var appStreams: candidateStreams.filter(n => n.ready && n.audio)

    PwObjectTracker {
        objects: [audioScope.sink, audioScope.source].concat(audioScope.candidateStreams)
    }

    function nodeLabel(n) {
        if (!n) return "";
        const p = n.properties || {};
        return n.description || n.nickname || p["application.name"] || n.name;
    }

    function streamLabel(n) {
        const p = n.properties || {};
        const app = p["application.name"] || n.name;
        const media = p["media.name"];
        return media && media !== app ? app + " — " + media : app;
    }

    // Startup grace period so the initial property values don't flash the OSD.
    Timer {
        interval: 800
        running: true
        onTriggered: audioScope.readyForOsd = true
    }

    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: audioScope.osdVisible = false
    }

    function showOsd(title, icon, value) {
        if (!readyForOsd || active) return;
        osdTitle = title;
        osdIcon = icon;
        osdValue = value;
        osdVisible = true;
        osdTimer.restart();
    }

    function showVolumeOsd() {
        showOsd(isMuted ? "Muted" : "Volume", barIcon, isMuted ? 0 : volumePct);
    }

    onVolumePctChanged: showVolumeOsd()
    onIsMutedChanged: showVolumeOsd()
    onMicMutedChanged: showOsd(micMuted ? "Microphone Muted" : "Microphone On", micIcon, micMuted ? 0 : micPct)

    function setVolume(node, pct) {
        if (!node || !node.audio) return;
        node.audio.volume = Math.max(0, Math.min(100, pct)) / 100.0;
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted;
    }

    IpcHandler {
        target: "audio"
        function open() { ShellState.openPopup("audio"); }
        function hide() { ShellState.closePopup("audio"); }
        function toggle() { ShellState.togglePopup("audio"); }
        function toggleMute() { audioScope.toggleMute(); }
        function toggleMicMute() { audioScope.toggleMicMute(); }
        function brightness(val: string) {
            audioScope.showOsd("Brightness", "󰃠", Math.max(0, Math.min(100, parseInt(val) || 0)));
        }
    }

    // Compact OSD for volume, mic and brightness
    PanelWindow {
        screen: ShellState.focusedScreen
        color: "transparent"
        anchors { bottom: true }
        margins { bottom: 48 }
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"
        implicitWidth: 280
        implicitHeight: 58
        visible: audioScope.osdVisible && !audioScope.active

        Rectangle {
            anchors.fill: parent
            color: Theme.bgPanel
            border.color: Theme.border
            border.width: Theme.borderWidth
            radius: Theme.radius

            Column {
                anchors.fill: parent
                anchors.margins: Theme.paddingLarge
                spacing: Theme.paddingSmall

                RowLayout {
                    width: parent.width
                    Text {
                        text: audioScope.osdIcon + "  " + audioScope.osdTitle
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        Layout.fillWidth: true
                    }
                    Text {
                        text: audioScope.osdValue + "%"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                    }
                }

                Meter {
                    width: parent.width
                    value: audioScope.osdValue / 100
                }
            }
        }
    }

    // Reusable "label + % + slider" block
    component VolumeControl: Column {
        id: vc
        property var node: null
        property string title: ""
        property bool muted: node && node.audio ? node.audio.muted : false
        readonly property int pct: node && node.audio ? Math.round(node.audio.volume * 100) : 0
        // Some streams (e.g. the PipeWire ALSA plugin) expose no channel volumes.
        readonly property bool hasVolume: node !== null && node.audio !== null && node.audio.volumes.length > 0
        spacing: Theme.spacingCompact

        RowLayout {
            width: parent.width
            Text {
                text: vc.title
                color: vc.muted ? Theme.textMuted : Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: !vc.hasVolume ? "n/a" : (vc.muted ? "MUTED" : vc.pct + "%")
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
            }
        }

        Meter {
            width: parent.width
            height: 14
            interactive: vc.hasVolume
            opacity: vc.hasVolume ? 1 : 0.4
            value: vc.muted || !vc.hasVolume ? 0 : vc.pct / 100
            onMoved: function(v) { if (vc.node && vc.node.audio) vc.node.audio.volume = Math.round(v * 100) / 100; }
        }
    }

    component DeviceRow: ListRow {
        id: dr
        property var node: null
        property bool isDefault: false
        height: Theme.rowHeightCompact
        outlined: isDefault
        selected: isDefault

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: (dr.isDefault ? "• " : "  ") + (dr.node ? (dr.node.description || dr.node.nickname || dr.node.name) : "")
            color: dr.isDefault ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            elide: Text.ElideRight
        }
    }

    ShellPopup {
        name: "audio"
        panelWidth: 380
        defaultRightOffset: 150

        Column {
            id: audioCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onLeftPressed: audioScope.setVolume(audioScope.sink, audioScope.volumePct - 5)
            Keys.onRightPressed: audioScope.setVolume(audioScope.sink, audioScope.volumePct + 5)
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_M) audioScope.toggleMute();
                else if (event.key === Qt.Key_N) audioScope.toggleMicMute();
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                PanelTitle {
                    text: "AUDIO"
                    Layout.fillWidth: true
                }
                SmallButton {
                    text: audioScope.micMuted ? "󰍭 MIC [N]" : "󰍬 MIC [N]"
                    highlighted: audioScope.micMuted
                    critical: audioScope.micMuted
                    onClicked: audioScope.toggleMicMute()
                }
                SmallButton {
                    text: audioScope.isMuted ? "UNMUTE [M]" : "MUTE [M]"
                    highlighted: audioScope.isMuted
                    onClicked: audioScope.toggleMute()
                }
            }

            // Output
            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                VolumeControl {
                    width: parent.width
                    node: audioScope.sink
                    title: "OUTPUT"
                }

                Repeater {
                    model: audioScope.audioSinks
                    delegate: DeviceRow {
                        required property var modelData
                        width: audioCol.width
                        node: modelData
                        isDefault: audioScope.sink !== null && modelData.id === audioScope.sink.id
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            // Input
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: audioScope.audioSources.length > 0

                VolumeControl {
                    width: parent.width
                    node: audioScope.source
                    title: "INPUT"
                }

                Repeater {
                    model: audioScope.audioSources
                    delegate: DeviceRow {
                        required property var modelData
                        width: audioCol.width
                        node: modelData
                        isDefault: audioScope.source !== null && modelData.id === audioScope.source.id
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            // Per-application volume
            Column {
                width: parent.width
                spacing: Theme.spacingMedium
                visible: audioScope.appStreams.length > 0

                Caption { text: "APPLICATIONS" }

                Repeater {
                    model: audioScope.appStreams
                    delegate: RowLayout {
                        id: appRow
                        required property var modelData
                        width: audioCol.width
                        spacing: Theme.spacingMedium

                        VolumeControl {
                            node: appRow.modelData
                            title: audioScope.streamLabel(appRow.modelData)
                            Layout.fillWidth: true
                        }

                        SmallButton {
                            text: appRow.modelData.audio && appRow.modelData.audio.muted ? "󰝟" : "󰕾"
                            highlighted: appRow.modelData.audio && appRow.modelData.audio.muted
                            Layout.alignment: Qt.AlignBottom
                            onClicked: if (appRow.modelData.audio) appRow.modelData.audio.muted = !appRow.modelData.audio.muted
                        }
                    }
                }
            }

            Hint { text: "←/→ volume • M mute • N mic mute • click device to switch" }
        }
    }
}
