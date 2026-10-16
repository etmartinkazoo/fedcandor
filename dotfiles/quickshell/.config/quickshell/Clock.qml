pragma Singleton
import QtQuick
import Quickshell

// One clock for every bar, with the formats each desktop mode uses.
Singleton {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date date: clock.date

    function time() {
        const h12 = date.getHours() % 12 || 12;
        return h12 + ":" + ("0" + date.getMinutes()).slice(-2) + (date.getHours() >= 12 ? "pm" : "am");
    }

    // Tiling bar: "Thu, Oct 15 - 7:05pm" (long: "Thursday, October 15 - 7:05pm")
    function full(long) {
        return Qt.formatDate(date, long ? "dddd, MMMM d" : "ddd, MMM d") + " - " + time();
    }

    // macOS top bar: "Thu Oct 15  7:05pm"
    function menubar() {
        return Qt.formatDate(date, "ddd MMM d") + "  " + time();
    }

    // Windows taskbar: "7:05pm" over "10/15/2026"
    function shortDate() {
        return Qt.formatDate(date, "M/d/yyyy");
    }
}
