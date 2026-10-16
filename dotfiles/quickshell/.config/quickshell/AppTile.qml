import QtQuick
import Quickshell.Widgets

// An app's icon as a clickable tile, shared by the Windows taskbar, the dock
// and the switchers so all three look and behave alike. `indicator` is "bar"
// (a line under the tile: short when running, full when focused) or "dot".
Rectangle {
    id: tile

    property string appId: ""
    property string iconSource: appId !== "" ? WindowList.iconFor(appId) : ""
    property int iconSize: 24
    property bool running: false
    property bool focused: false
    property bool selected: false        // keyboard selection (switchers)
    property string indicator: "bar"
    property string glyph: ""            // a Nerd Font icon instead of an app icon (start button, dock launcher)
    property int badge: 0                // unread notifications, shown top-right
    readonly property bool hovered: mouse.containsMouse

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()

    function centerX() {
        return mapToItem(null, width / 2, 0).x;
    }

    color: selected || focused ? Theme.bgSelected : (hovered ? Theme.bgItem : "transparent")
    border.color: selected ? Theme.accent : (focused ? Theme.border : (hovered ? Theme.borderSubtle : "transparent"))
    border.width: selected ? 2 : Theme.borderWidth
    radius: Theme.radius

    IconImage {
        visible: tile.glyph === ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: tile.indicator === "dot" ? -2 : 0
        implicitSize: tile.iconSize
        source: tile.glyph === "" ? tile.iconSource : ""
        asynchronous: true
    }

    Text {
        visible: tile.glyph !== ""
        anchors.centerIn: parent
        anchors.verticalCenterOffset: tile.indicator === "dot" ? -2 : 0
        text: tile.glyph
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(tile.iconSize * 0.8)
    }

    // Running / focused indicator
    Rectangle {
        visible: tile.running || tile.focused
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: tile.indicator === "dot" ? 3 : 0
        width: tile.indicator === "dot" ? 4 : (tile.focused ? parent.width - 8 : 12)
        height: tile.indicator === "dot" ? 4 : 2
        radius: tile.indicator === "dot" ? 2 : 0
        color: tile.focused ? Theme.accent : Theme.textSecondary

        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    // Notification badge
    Rectangle {
        visible: tile.badge > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        width: Math.max(16, badgeText.implicitWidth + 8)
        height: 16
        radius: 8
        color: Theme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: tile.badge > 9 ? "9+" : tile.badge
            color: Theme.bgPanel
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            font.bold: true
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(m) {
            if (m.button === Qt.RightButton) tile.rightClicked();
            else if (m.button === Qt.MiddleButton) tile.middleClicked();
            else tile.leftClicked();
        }
    }
}
