import QtQuick
import Quickshell.I3

// Workspace buttons for one screen. `hideSingle` hides them while there's only
// one workspace (the Windows and macOS bars, where workspaces are optional).
Row {
    id: pills

    required property string screenName
    property bool hideSingle: false

    readonly property var workspaces: I3.workspaces.values
        .filter(w => !w.monitor || w.monitor.name === screenName)
        .sort((a, b) => (a.num - b.num) || a.name.localeCompare(b.name))

    visible: !hideSingle || workspaces.length > 1
    spacing: Theme.paddingSmall

    Repeater {
        model: pills.workspaces
        delegate: BarButton {
            required property var modelData
            icon: false
            text: modelData.name
            tooltip: "Workspace " + modelData.name
            highlighted: modelData.active
            critical: modelData.urgent
            dim: !modelData.active
            onLeftClicked: modelData.activate()
        }
    }
}
