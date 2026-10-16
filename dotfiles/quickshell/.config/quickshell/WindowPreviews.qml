import QtQuick
import Quickshell

// Window previews above a taskbar or dock tile: hover a running app for half
// a second to see its windows. Click one to switch to it, × to close it.
// One instance per bar; tiles call show()/leave() as the pointer moves.
PopupWindow {
    id: pv

    required property var barWindow

    property var tile: null
    property string appId: ""
    property var pendingTile: null
    property string pendingAppId: ""

    readonly property var wins: appId !== "" ? WindowList.windowsOf(appId) : []
    readonly property int cardWidth: 220

    function show(t, id) {
        if (WindowList.windowsOf(id).length === 0) {
            leave();
            return;
        }
        closeTimer.stop();
        pendingTile = t;
        pendingAppId = id;
        if (visible) openTimer.triggered();   // already open: follow the pointer at once
        else openTimer.restart();
    }

    function leave() {
        openTimer.stop();
        closeTimer.restart();
    }

    function hide() {
        openTimer.stop();
        closeTimer.stop();
        tile = null;
        appId = "";
    }

    Timer {
        id: openTimer
        interval: 500
        onTriggered: {
            pv.tile = pv.pendingTile;
            pv.appId = pv.pendingAppId;
            WindowList.capture(WindowList.windowsOf(pv.appId));
        }
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: if (!popHover.hovered) pv.hide()
    }

    visible: tile !== null && wins.length > 0 && ShellState.activePopup === ""
    color: "transparent"
    implicitWidth: frame.width
    implicitHeight: frame.height + Desktop.edgeGap

    anchor.window: barWindow
    anchor.rect.x: tile ? tile.mapToItem(null, 0, 0).x + tile.width / 2 : 0
    anchor.rect.y: 0
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.SlideX

    HoverHandler {
        id: popHover
        onHoveredChanged: if (!hovered) pv.leave()
    }

    Rectangle {
        id: frame
        width: cards.width + Theme.paddingLarge * 2
        height: cards.height + Theme.paddingLarge * 2
        color: Theme.bgPanel
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius

        Row {
            id: cards
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            spacing: Theme.spacingMedium

            Repeater {
                model: pv.wins

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: pv.cardWidth
                    height: shotBox.height + 36
                    color: cardMouse.containsMouse ? Theme.bgSelected : Theme.bgItem
                    border.color: card.modelData.focused ? Theme.accent : (cardMouse.containsMouse ? Theme.border : Theme.borderSubtle)
                    border.width: Theme.borderWidth
                    radius: Theme.radius

                    Rectangle {
                        id: shotBox
                        x: 6
                        y: 6
                        width: parent.width - 12
                        height: width * 10 / 16
                        color: Theme.darkerBackground
                        clip: true

                        Image {
                            id: shot
                            anchors.fill: parent
                            source: pv.visible ? WindowList.thumbFor(card.modelData.id) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            sourceSize.width: width * 2
                        }

                        AppTile {
                            visible: shot.status !== Image.Ready
                            anchors.centerIn: parent
                            width: 48
                            height: 48
                            appId: card.modelData.appId
                            iconSize: 36
                            enabled: false
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        text: (card.modelData.minimized ? "󰖰 " : "") + card.modelData.title
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: function(m) {
                            if (m.button === Qt.MiddleButton) WindowList.close(card.modelData.id);
                            else {
                                WindowList.focus(card.modelData.id);
                                pv.hide();
                            }
                        }
                    }

                    Rectangle {
                        visible: cardMouse.containsMouse || closeMouse.containsMouse
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 24
                        height: 24
                        color: closeMouse.containsMouse ? Theme.red : Theme.bgPanel
                        border.color: Theme.border
                        border.width: Theme.borderWidth
                        radius: Theme.radius

                        Text {
                            anchors.centerIn: parent
                            text: "󰖭"
                            color: closeMouse.containsMouse ? Theme.bgPanel : Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: WindowList.close(card.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
