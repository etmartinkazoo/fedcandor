import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Scope {
    id: nightScope

    readonly property bool enabled: ShellState.settings.nightLight
    readonly property int temperature: ShellState.settings.nightLightTemp
    readonly property string barIcon: enabled ? "󰖔" : "󰖙"

    readonly property var presets: [
        { temp: 3000, label: "3000K", desc: "Candle" },
        { temp: 4000, label: "4000K", desc: "Warm" },
        { temp: 5000, label: "5000K", desc: "Soft" }
    ]

    function toggleEnabled() {
        ShellState.settings.nightLight = !ShellState.settings.nightLight;
    }

    function setTemp(t) {
        ShellState.settings.nightLightTemp = Math.max(2500, Math.min(6000, t));
        ShellState.settings.nightLight = true;
    }

    // wlsunset is owned by this Process: it runs exactly while night light is
    // enabled, so the bar can't drift out of sync with reality. Any stray
    // instance from an older setup is killed once at startup.
    property bool strayKilled: false

    Process {
        command: ["pkill", "-x", "wlsunset"]
        running: true
        onExited: nightScope.strayKilled = true
    }

    Process {
        id: sunset
        running: nightScope.strayKilled && ShellState.settingsLoaded && nightScope.enabled
        command: ["wlsunset", "-t", String(nightScope.temperature), "-T", String(nightScope.temperature + 1)]
    }

    // Restart with the new temperature.
    onTemperatureChanged: {
        if (sunset.running) {
            sunset.running = false;
            Qt.callLater(() => { sunset.running = Qt.binding(() => nightScope.strayKilled && ShellState.settingsLoaded && nightScope.enabled); });
        }
    }

    IpcHandler {
        target: "nightlight"
        // The controls live in Quick Settings now.
        function open() { ShellState.openPopup("quick"); }
        function hide() { ShellState.closePopup("quick"); }
        function toggle() { ShellState.togglePopup("quick"); }
        function togglePower() { nightScope.toggleEnabled(); }
        function setTemperature(kelvin: int) { nightScope.setTemp(kelvin); }
    }
}
