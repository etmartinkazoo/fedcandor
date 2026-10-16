import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Scope {
    id: mediaScope

    readonly property bool active: ShellState.activePopup === "media"
    property string pinnedPlayer: ""   // dbusName chosen by the user; "" = auto

    readonly property var players: Mpris.players.values
    readonly property var player: {
        if (pinnedPlayer !== "") {
            for (let i = 0; i < players.length; i++) {
                if (players[i].dbusName === pinnedPlayer) return players[i];
            }
        }
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool isPlaying: player ? player.isPlaying : false
    readonly property string title: player && player.trackTitle ? player.trackTitle : "No Media"
    readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
    readonly property string barText: {
        if (!player) return "";
        const t = title.length > 24 ? (title.slice(0, 24) + "…") : title;
        return (isPlaying ? "󰏤" : "󰐊") + " " + t;
    }

    function cyclePlayer() {
        if (players.length < 2) return;
        const idx = players.indexOf(player);
        pinnedPlayer = players[(idx + 1) % players.length].dbusName;
    }

    function formatTime(secs) {
        if (!isFinite(secs) || secs < 0) return "0:00";
        const s = Math.floor(secs);
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    function seekBy(delta) {
        if (player && player.canSeek) player.position = Math.max(0, player.position + delta);
    }

    // MPRIS doesn't push position updates; poll while visible and playing.
    Timer {
        interval: 1000
        repeat: true
        running: mediaScope.active && mediaScope.isPlaying
        onTriggered: if (mediaScope.player) mediaScope.player.positionChanged()
    }

    IpcHandler {
        target: "media"
        function open() { ShellState.openPopup("media"); }
        function hide() { ShellState.closePopup("media"); }
        function toggle() { ShellState.togglePopup("media"); }
        function playPause() { if (mediaScope.player) mediaScope.player.togglePlaying(); }
    }

    ShellPopup {
        name: "media"
        panelWidth: 440
        defaultRightOffset: 9999   // left side of the screen when opened via IPC

        Column {
            id: mediaCol
            width: parent.width
            spacing: Theme.spacingLarge
            focus: true

            Keys.onSpacePressed: { if (mediaScope.player) mediaScope.player.togglePlaying(); }
            Keys.onLeftPressed: { if (mediaScope.player && mediaScope.player.canGoPrevious) mediaScope.player.previous(); }
            Keys.onRightPressed: { if (mediaScope.player && mediaScope.player.canGoNext) mediaScope.player.next(); }
            Keys.onTabPressed: mediaScope.cyclePlayer()
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Comma) mediaScope.seekBy(-10);
                else if (event.key === Qt.Key_Period) mediaScope.seekBy(10);
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width

                PanelTitle {
                    text: "NOW PLAYING"
                    Layout.fillWidth: true
                }

                // Player picker (only when there's a choice)
                Repeater {
                    model: mediaScope.players.length > 1 ? mediaScope.players : []
                    delegate: SmallButton {
                        required property var modelData
                        text: modelData.identity || modelData.dbusName
                        highlighted: modelData === mediaScope.player
                        onClicked: mediaScope.pinnedPlayer = modelData.dbusName
                    }
                }

                Caption {
                    visible: mediaScope.players.length <= 1
                    text: mediaScope.player ? (mediaScope.player.identity || "") : "Idle"
                }
            }

            RowLayout {
                width: parent.width
                spacing: Theme.spacingLarge

                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    color: Theme.bgItem
                    border.color: Theme.border
                    border.width: Theme.borderWidth
                    radius: Theme.radius

                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "󰎈"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: 28
                    }

                    Image {
                        id: art
                        anchors.fill: parent
                        anchors.margins: 1
                        source: mediaScope.player ? mediaScope.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 144
                        sourceSize.height: 144
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: Theme.spacingCompact

                    Text {
                        width: parent.width
                        text: mediaScope.title
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMedium
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: mediaScope.artist !== "" ? mediaScope.artist : (mediaScope.hasPlayer ? "Unknown Artist" : "Start playing media in any app")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: mediaScope.player ? mediaScope.player.trackAlbum : ""
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingCompact
                visible: mediaScope.player !== null && mediaScope.player.lengthSupported && mediaScope.player.length > 0

                Meter {
                    width: parent.width
                    height: 8
                    interactive: mediaScope.player !== null && mediaScope.player.canSeek
                    value: mediaScope.player && mediaScope.player.length > 0 ? mediaScope.player.position / mediaScope.player.length : 0
                    onMoved: function(v) { mediaScope.player.position = v * mediaScope.player.length; }
                }

                RowLayout {
                    width: parent.width
                    Caption {
                        text: mediaScope.player ? mediaScope.formatTime(mediaScope.player.position) : ""
                        Layout.fillWidth: true
                    }
                    Caption { text: mediaScope.player ? mediaScope.formatTime(mediaScope.player.length) : "" }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingMedium

                Repeater {
                    model: [
                        { label: "󰒮  Prev", action: "prev" },
                        { label: mediaScope.isPlaying ? "󰏤  Pause" : "󰐊  Play", action: "toggle" },
                        { label: "󰒭  Next", action: "next" }
                    ]
                    delegate: OptionTile {
                        required property var modelData
                        width: (mediaCol.width - Theme.spacingMedium * 2) / 3
                        height: 40
                        icon: ""
                        label: modelData.label
                        selected: false
                        onClicked: {
                            const p = mediaScope.player;
                            if (!p) return;
                            if (modelData.action === "prev" && p.canGoPrevious) p.previous();
                            else if (modelData.action === "toggle") p.togglePlaying();
                            else if (modelData.action === "next" && p.canGoNext) p.next();
                        }
                    }
                }
            }

            Hint {
                text: "Space play/pause • ←/→ prev/next • ,/. seek 10s" + (mediaScope.players.length > 1 ? " • Tab player" : "")
            }
        }
    }
}
