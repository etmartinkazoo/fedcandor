import QtQuick
import Quickshell
import Quickshell.I3
import Quickshell.Io

// While a panel is open, it's the active surface: the focused window gives up
// its accent border (the panel wears it instead, 2px, see ShellPopup.qml), and
// gets it back when the panel closes. The title-bar colors stay as they are.
//
// The focused window's colors come from the theme's sway drop-in, so this
// follows theme switches.
Scope {
    id: pf

    readonly property bool panelOpen: ShellState.activePopup !== ""
    // "client.focused <border> <background> <text> <indicator> <child_border>"
    property var focusedColors: null

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/sway/config.d/99-theme.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("client.focused "));
            const cols = line ? line.trim().split(/\s+/).slice(1) : [];
            // Colors only: they end up in a sway command
            pf.focusedColors = cols.length === 5 && cols.every(c => /^#[0-9a-fA-F]{6,8}$/.test(c)) ? cols : null;
            pf.apply();
        }
    }

    function apply() {
        const c = focusedColors;
        if (!c) return;
        if (panelOpen) {
            const clear = c[1].slice(0, 7) + "00";   // transparent
            I3.dispatch(`client.focused ${clear} ${c[1]} ${c[2]} ${clear} ${clear}`);
        } else {
            I3.dispatch(`client.focused ${c.join(" ")}`);
        }
    }

    onPanelOpenChanged: apply()
}
