import QtQuick

// A single bar pill. Icon pills get the icon font size and a minimum width;
// text pills (volume, battery, media) use the caption size.
Rectangle {
    id: btn

    property string text: ""
    property bool icon: true
    property bool highlighted: false
    property bool critical: false
    property bool dim: false
    property color textColor: dim ? Theme.textSecondary : Theme.textPrimary
    readonly property bool hovered: mouse.containsMouse

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(int delta)

    // Horizontal center in window coordinates, used to anchor popups.
    function centerX() {
        return mapToItem(null, width / 2, 0).x;
    }

    height: 24
    width: icon ? Math.max(28, label.implicitWidth + 12) : label.implicitWidth + 16
    color: highlighted || hovered ? Theme.bgSelected : Theme.bgItem
    border.color: critical ? Theme.borderCritical : Theme.border
    border.width: Theme.borderWidth
    radius: Theme.radius

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: btn.textColor
        font.family: Theme.fontFamily
        font.pixelSize: btn.icon ? Theme.fontIcon : Theme.fontCaption
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: function(m) {
            if (m.button === Qt.RightButton) btn.rightClicked();
            else if (m.button === Qt.MiddleButton) btn.middleClicked();
            else btn.leftClicked();
        }
        onWheel: function(w) { btn.scrolled(w.angleDelta.y); }
    }
}
