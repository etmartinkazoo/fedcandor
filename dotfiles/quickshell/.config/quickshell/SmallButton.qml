import QtQuick

// Compact header button, e.g. "ON [T]" or "CLEAR".
Rectangle {
    id: btn
    property string text: ""
    property bool highlighted: false
    property bool critical: false
    signal clicked()

    implicitHeight: 24
    implicitWidth: label.implicitWidth + 14
    color: highlighted || mouse.containsMouse ? Theme.bgSelected : Theme.bgItem
    border.color: Theme.borderCritical
    border.width: critical ? Theme.borderWidth : 0
    radius: Theme.radius

    Text {
        id: label
        anchors.centerIn: parent
        text: btn.text
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
