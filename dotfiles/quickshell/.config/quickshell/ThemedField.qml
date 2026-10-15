import QtQuick
import QtQuick.Controls

TextField {
    height: 44
    leftPadding: Theme.inputPadding
    rightPadding: Theme.inputPadding
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontLarge
    color: Theme.textPrimary
    placeholderTextColor: Theme.textPlaceholder
    background: Rectangle {
        color: Theme.bgItem
        border.color: Theme.border
        border.width: Theme.borderWidth
        radius: Theme.radius
    }
}
