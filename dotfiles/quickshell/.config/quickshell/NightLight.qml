import QtQuick
import Quickshell
import Quickshell.Io

// Night light ("warmth"), with three modes:
//   off   neutral screen
//   auto  warm from sunset to sunrise, neutral by day. Sun times come from your
//         timezone's coordinates in the system tz database: no location
//         service, nothing leaves the machine. Falls back to 07:00-19:00.
//   on    always warm
// The controls live in Quick Settings.
Scope {
    id: nightScope

    // Older settings stored a plain on/off flag; treat that as "on"/"off".
    readonly property string mode: {
        const m = ShellState.settings.nightLightMode;
        if (m === "off" || m === "auto" || m === "on") return m;
        return ShellState.settings.nightLight ? "on" : "off";
    }
    readonly property bool enabled: mode !== "off"
    readonly property int temperature: ShellState.settings.nightLightTemp
    readonly property string modeText: mode === "auto" ? (location ? "Auto (sunset to sunrise)" : "Auto (19:00 to 07:00)")
        : mode === "on" ? "On" : "Off"

    // { lat, lon } from the timezone, or null
    property var location: null

    readonly property var modes: ["off", "auto", "on"]

    function setMode(m) {
        if (modes.indexOf(m) < 0) return;
        ShellState.settings.nightLightMode = m;
    }

    function cycleMode() {
        setMode(modes[(modes.indexOf(mode) + 1) % modes.length]);
    }

    // Kept for IPC compatibility: toggles between off and on.
    function toggleEnabled() {
        setMode(enabled ? "off" : "on");
    }

    function setTemp(t) {
        ShellState.settings.nightLightTemp = Math.max(2500, Math.min(6000, t));
        if (!enabled) setMode("on");
    }

    // ISO 6709 (zone1970.tab): +DDMM[SS]+DDDMM[SS]
    function parseCoords(s) {
        const m = s.trim().match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/);
        if (!m) return null;
        const dms = (sign, d, mm, ss) => (sign === "-" ? -1 : 1) * (Number(d) + Number(mm) / 60 + Number(ss || 0) / 3600);
        return { lat: dms(m[1], m[2], m[3], m[4]).toFixed(2), lon: dms(m[5], m[6], m[7], m[8]).toFixed(2) };
    }

    Process {
        command: ["sh", "-c",
            "tz=$(timedatectl show -p Timezone --value 2>/dev/null); " +
            "[ -n \"$tz\" ] || tz=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||'); " +
            "awk -v tz=\"$tz\" '$3 == tz { print $2; exit }' /usr/share/zoneinfo/zone1970.tab"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: nightScope.location = nightScope.parseCoords(text)
        }
    }

    readonly property var sunsetCommand: {
        const low = String(temperature);
        if (mode === "on") return ["wlsunset", "-t", low, "-T", String(temperature + 1)];
        if (location) return ["wlsunset", "-t", low, "-T", "6500", "-l", location.lat, "-L", location.lon];
        return ["wlsunset", "-t", low, "-T", "6500", "-S", "07:00", "-s", "19:00"];
    }

    // wlsunset is owned by this Process: it runs exactly while warmth is on, so
    // the UI can't drift out of sync with reality. Any stray instance from an
    // older setup is killed once at startup.
    property bool strayKilled: false

    Process {
        command: ["pkill", "-x", "wlsunset"]
        running: true
        onExited: nightScope.strayKilled = true
    }

    readonly property bool shouldRun: strayKilled && ShellState.settingsLoaded && enabled

    Process {
        id: sunset
        command: nightScope.sunsetCommand
        running: false
    }

    function restart() {
        sunset.running = false;
        if (shouldRun) Qt.callLater(() => { sunset.running = nightScope.shouldRun; });
    }

    onShouldRunChanged: restart()
    onSunsetCommandChanged: restart()

    IpcHandler {
        target: "nightlight"
        function open() { ShellState.openPopup("quick"); }
        function hide() { ShellState.closePopup("quick"); }
        function toggle() { ShellState.togglePopup("quick"); }
        function togglePower() { nightScope.toggleEnabled(); }
        function setMode(mode: string) { nightScope.setMode(mode); }
        function setTemperature(kelvin: int) { nightScope.setTemp(kelvin); }
    }
}
