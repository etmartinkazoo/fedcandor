import QtQuick
import QtQuick.Effects

// Soft drop shadow behind a floating surface (popup, panel, card): declare it
// before the surface it belongs to, as a sibling, with `target` set to it.
// The window must leave Theme.shadowMargin of room around the surface.
RectangularShadow {
    required property Item target
    x: target.x
    y: target.y
    width: target.width
    height: target.height
    visible: target.visible && target.opacity > 0
    radius: target.radius !== undefined ? target.radius : Theme.radius
    blur: Theme.shadowBlur
    spread: 0
    offset.x: 0
    offset.y: Theme.shadowOffset
    color: Theme.shadowColor
}
