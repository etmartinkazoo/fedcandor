import QtQuick

// "● REC 0:42" while the screen is being recorded; click to stop.
BarButton {
    required property var tools
    visible: tools.screenshot.recording
    icon: false
    text: tools.screenshot.recordText
    critical: true
    textColor: Theme.borderCritical
    onLeftClicked: tools.screenshot.stopRecording()
}
