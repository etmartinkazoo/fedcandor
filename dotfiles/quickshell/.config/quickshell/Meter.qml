import QtQuick

// Horizontal fill bar. Set `interactive` to drag/click a new value (0..1).
Rectangle {
    id: meter
    property real value: 0
    property bool critical: false
    property bool interactive: false
    signal moved(real value)

    height: 10
    color: Theme.bgItem
    border.width: 0
    radius: Theme.radius

    Rectangle {
        x: 1
        y: 1
        height: parent.height - 2
        width: Math.max(0, (parent.width - 2) * Math.max(0, Math.min(1, meter.value)))
        color: meter.critical ? Theme.borderCritical : Theme.bgSelected
    }

    MouseArea {
        anchors.fill: parent
        enabled: meter.interactive
        cursorShape: meter.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(m) { meter.moved(Math.max(0, Math.min(1, m.x / width))); }
        onPositionChanged: function(m) {
            if (pressed) meter.moved(Math.max(0, Math.min(1, m.x / width)));
        }
    }
}
