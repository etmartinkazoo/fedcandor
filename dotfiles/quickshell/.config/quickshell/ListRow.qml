import QtQuick

// Selectable list row background with hover/select handling. Put content inside.
Rectangle {
    id: row
    property bool selected: false
    property bool outlined: false
    property bool critical: false
    readonly property bool hovered: mouse.containsMouse
    default property alias content: inner.data
    signal clicked(var mouse)
    signal entered()

    height: 36
    color: selected || hovered ? Theme.bgSelected : Theme.bgItem
    border.color: critical ? Theme.borderCritical : (selected || outlined ? Theme.border : Theme.borderSubtle)
    border.width: Theme.borderWidth
    radius: Theme.radius

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: row.entered()
        onClicked: function(m) { row.clicked(m); }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
    }
}
