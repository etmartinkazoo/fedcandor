import QtQuick

// Keyboard hint line at the bottom of a popup.
Text {
    width: parent ? parent.width : implicitWidth
    color: Theme.textSecondary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSmall
    elide: Text.ElideRight
}
