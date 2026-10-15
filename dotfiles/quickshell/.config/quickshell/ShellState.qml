pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// Shared shell state: which popup is open (only one at a time), which screen
// it opens on, and settings that persist across restarts.
Singleton {
    id: root

    // ---- Popup coordination ----
    property string activePopup: ""
    property var popupScreen: focusedScreen
    property real popupAnchorX: -1

    readonly property var focusedScreen: {
        const screens = Quickshell.screens;
        const mon = I3.focusedMonitor;
        if (mon) {
            for (let i = 0; i < screens.length; i++) {
                if (screens[i].name === mon.name) return screens[i];
            }
        }
        return screens.length > 0 ? screens[0] : null;
    }

    function openPopup(name, screen, anchorX) {
        popupScreen = screen || focusedScreen;
        popupAnchorX = anchorX === undefined ? -1 : anchorX;
        activePopup = name;
    }

    function closePopup(name) {
        if (name === undefined || activePopup === name) activePopup = "";
    }

    function togglePopup(name, screen, anchorX) {
        if (activePopup === name) closePopup();
        else openPopup(name, screen, anchorX);
    }

    // ---- Launching apps ----
    // Quickshell runs as a systemd user service; anything started directly
    // would live in its cgroup and die whenever the shell restarts. Each
    // user-facing launch gets its own transient scope instead.
    function launch(argv, workingDirectory) {
        const cmd = ["systemd-run", "--user", "--scope", "--collect", "--quiet"];
        if (workingDirectory) cmd.push("--working-directory=" + workingDirectory);
        Quickshell.execDetached(cmd.concat(["--"], argv));
    }

    // ---- Persisted settings (~/.local/state/quickshell/...) ----
    property alias settings: adapter
    property bool settingsLoaded: false

    FileView {
        path: Quickshell.statePath("settings.json")
        onAdapterUpdated: writeAdapter()
        onLoaded: root.settingsLoaded = true
        onLoadFailed: function(error) {
            root.settingsLoaded = true;
            writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property string theme: "win11"
            property bool dnd: false
            property bool nightLight: false
            property int nightLightTemp: 4000
            // { "<app name>": { count: n, last: epochMs } }
            property var launchStats: ({})
        }
    }
}
