import QtQuick
import Quickshell
import Quickshell.Io

// CPU / memory / temperature sampler for the bar pill.
Scope {
    id: sysScope

    property real cpuPct: 0
    property real memPct: 0
    property real tempC: 0
    property var lastCpu: null

    readonly property bool hot: cpuPct >= 90 || tempC >= 85 || memPct >= 90
    readonly property string barText: "󰍛 " + Math.round(cpuPct) + "%  󰘚 " + Math.round(memPct) + "%"
        + (tempC > 0 ? "  " + Math.round(tempC) + "°" : "")

    function openMonitor() {
        ShellState.launchInTerminal(["top"]);
    }

    Process {
        id: sampler
        command: ["sh", "-c",
            "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; " +
            "for z in /sys/class/thermal/thermal_zone*; do printf 'T %s %s\\n' \"$(cat $z/type)\" \"$(cat $z/temp)\"; done 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: sysScope.parse(text)
        }
    }

    function parse(text) {
        let memTotal = 0, memAvail = 0;
        const temps = {};
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f[0] === "cpu") {
                const vals = f.slice(1).map(Number);
                const idle = vals[3] + (vals[4] || 0);
                const total = vals.reduce((a, b) => a + b, 0);
                if (lastCpu && total > lastCpu.total) {
                    cpuPct = 100 * (1 - (idle - lastCpu.idle) / (total - lastCpu.total));
                }
                lastCpu = { idle: idle, total: total };
            } else if (f[0] === "MemTotal:") {
                memTotal = Number(f[1]);
            } else if (f[0] === "MemAvailable:") {
                memAvail = Number(f[1]);
            } else if (f[0] === "T" && f.length >= 3) {
                temps[f.slice(1, -1).join(" ")] = Number(f[f.length - 1]) / 1000;
            }
        }
        if (memTotal > 0) memPct = 100 * (1 - memAvail / memTotal);
        const prefs = ["x86_pkg_temp", "TCPU", "k10temp", "cpu_thermal", "acpitz"];
        for (let i = 0; i < prefs.length; i++) {
            if (temps[prefs[i]] > 0) {
                tempC = temps[prefs[i]];
                break;
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: sampler.running = true
    }
}
