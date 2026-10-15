import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: caffeineScope

    required property var barWindow
    property bool enabled: false

    readonly property string barIcon: enabled ? "󰅶" : "󰾪"

    IdleInhibitor {
        window: caffeineScope.barWindow
        enabled: caffeineScope.enabled
    }

    function toggle() {
        enabled = !enabled;
    }

    IpcHandler {
        target: "caffeine"
        function toggle() { caffeineScope.toggle(); }
        function enable() { caffeineScope.enabled = true; }
        function disable() { caffeineScope.enabled = false; }
    }
}
