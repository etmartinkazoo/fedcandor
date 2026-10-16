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

    // ---- Terminal ----
    // The default terminal (matches $term in the sway config).
    readonly property string terminal: "kitty"

    // Run a command in a new terminal window.
    function launchInTerminal(argv) {
        launch([terminal].concat(argv));
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

    // ---- Pinned apps ----
    function togglePin(appId) {
        const p = settings.pinnedApps.slice();
        const i = p.indexOf(appId);
        if (i >= 0) p.splice(i, 1);
        else p.push(appId);
        settings.pinnedApps = p;
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
            property bool dnd: false
            property bool nightLight: false      // legacy; superseded by nightLightMode
            property string nightLightMode: ""    // "off" | "auto" | "on"
            property int nightLightTemp: 4000
            // Apps pinned to the Windows taskbar and the macOS dock (desktop entry ids)
            property var pinnedApps: ["kitty", "org.mozilla.firefox"]
            // Apps pinned to the Start menu (missing ones are skipped)
            property var startPinned: ["kitty", "org.mozilla.firefox", "chromium-browser", "thunar", "nvim", "mpv",
                "org.pulseaudio.pavucontrol", "blueman-manager", "system-config-printer"]
            // { "<app name>": { count: n, last: epochMs } }
            property var launchStats: ({})
        }
    }
}
