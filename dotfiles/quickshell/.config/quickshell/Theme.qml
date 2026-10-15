pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: theme

    // Active palette: "win11" (Windows 11 Dark) or "graphite" (Original Dark).
    // Persisted in ShellState so it survives restarts.
    readonly property string currentTheme: palettes[ShellState.settings.theme] ? ShellState.settings.theme : "win11"

    readonly property var palettes: ({
        "win11": {
            label: "Windows 11 Dark",
            iconTheme: "Tela-blue-dark",
            bgOverlay: "#a0050a14",
            bgPanel: "#141d2b",
            bgItem: "#0d1420",
            bgSelected: "#1f3d6e",
            bgCritical: "#3a141c",
            border: "#385a94",
            borderSubtle: "#1f2e47",
            borderCritical: "#9e3344",
            textPrimary: "#f0f5ff",
            textSecondary: "#8fa8cc",
            textMuted: "#6b82a6",
            textPlaceholder: "#566b8c"
        },
        "graphite": {
            label: "Graphite Dark",
            iconTheme: "Tela-grey-dark",
            bgOverlay: "#a0000000",
            bgPanel: "#1a1a1a",
            bgItem: "#121212",
            bgSelected: "#2e2e2e",
            bgCritical: "#2d1212",
            border: "#444444",
            borderSubtle: "#2a2a2a",
            borderCritical: "#7a2f2f",
            textPrimary: "#e0e0e0",
            textSecondary: "#888888",
            textMuted: "#777777",
            textPlaceholder: "#666666"
        }
    })

    readonly property var active: palettes[currentTheme] || palettes["win11"]

    // Colors - Surfaces
    readonly property color bgOverlay: active.bgOverlay
    readonly property color bgPanel: active.bgPanel
    readonly property color bgItem: active.bgItem
    readonly property color bgSelected: active.bgSelected
    readonly property color bgCritical: active.bgCritical

    // Colors - Borders
    readonly property color border: active.border
    readonly property color borderSubtle: active.borderSubtle
    readonly property color borderCritical: active.borderCritical

    // Colors - Text
    readonly property color textPrimary: active.textPrimary
    readonly property color textSecondary: active.textSecondary
    readonly property color textMuted: active.textMuted
    readonly property color textPlaceholder: active.textPlaceholder

    // Typography
    readonly property string fontFamily: "0xProto Nerd Font"
    readonly property int fontSmall: 10
    readonly property int fontCaption: 11
    readonly property int fontNormal: 12
    readonly property int fontMedium: 13
    readonly property int fontLarge: 14
    readonly property int fontIcon: 15

    // Geometry & Spacing
    readonly property int radius: 0
    readonly property int borderWidth: 1
    readonly property int paddingSmall: 6
    readonly property int paddingMedium: 8
    readonly property int paddingLarge: 12
    readonly property int inputPadding: 14
    readonly property int spacingSmall: 2
    readonly property int spacingMedium: 8
    readonly property int spacingLarge: 12

    function syncExternalApps() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.local/bin/apply-theme",
            active.bgPanel,
            active.bgItem,
            active.bgSelected,
            active.bgCritical,
            active.border,
            active.borderSubtle,
            active.borderCritical,
            active.textPrimary,
            active.textSecondary,
            active.textMuted,
            fontFamily,
            active.iconTheme
        ]);
    }

    // Sync once the saved theme is known, then on every change.
    onCurrentThemeChanged: if (ShellState.settingsLoaded) syncExternalApps()

    Connections {
        target: ShellState
        function onSettingsLoadedChanged() {
            if (ShellState.settingsLoaded) theme.syncExternalApps();
        }
    }

    function setTheme(name) {
        if (!palettes[name]) return;
        ShellState.settings.theme = name;
    }

    function toggleTheme() {
        setTheme(currentTheme === "win11" ? "graphite" : "win11");
    }
}
