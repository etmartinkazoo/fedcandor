import QtQuick

// Selectable tile with an icon and a label or two (power menu, profiles, presets...).
Rectangle {
    id: tile
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool selected: false
    property bool enabled: true
    property int iconSize: 18
    readonly property bool hovered: mouse.containsMouse
    signal clicked()
    signal entered()

    height: 60
    opacity: enabled ? 1.0 : 0.45
    color: selected || (hovered && enabled) ? Theme.bgSelected : Theme.bgItem
    border.width: 0
    radius: Theme.radius

    Column {
        anchors.centerIn: parent
        width: parent.width - 8
        spacing: 4

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: tile.icon !== ""
            text: tile.icon
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: tile.iconSize
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.label
            color: tile.selected ? Theme.textPrimary : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCaption
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: tile.sublabel !== ""
            text: tile.sublabel
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onEntered: tile.entered()
        onClicked: if (tile.enabled) tile.clicked()
    }
}
