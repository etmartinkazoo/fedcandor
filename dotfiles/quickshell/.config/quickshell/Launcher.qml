import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "Fuzzy.js" as Fuzzy

Scope {
    id: launcherScope

    readonly property bool active: ShellState.activePopup === "launcher"
    property int selectedIndex: 0
    property string query: ""

    // Frecency: launch count, decayed by days since last launch.
    function frecency(app) {
        const s = ShellState.settings.launchStats[app.name];
        if (!s) return 0;
        const days = (Date.now() - s.last) / 86400000;
        return s.count / (1 + days / 7);
    }

    function recordLaunch(app) {
        const stats = Object.assign({}, ShellState.settings.launchStats);
        const prev = stats[app.name] || { count: 0, last: 0 };
        stats[app.name] = { count: prev.count + 1, last: Date.now() };
        ShellState.settings.launchStats = stats;
    }

    // "= 2*(3+4)" -> "14". Only arithmetic characters are evaluated.
    readonly property string calcResult: {
        const q = query.trim();
        if (!q.startsWith("=")) return "";
        const expr = q.slice(1).trim();
        if (expr === "" || !/^[0-9+\-*/%().,^\s]+$/.test(expr)) return "";
        try {
            const v = Function("return (" + expr.replace(/\^/g, "**").replace(/,/g, "") + ");")();
            if (typeof v !== "number" || !isFinite(v)) return "";
            return String(Math.round(v * 1e10) / 1e10);
        } catch (e) {
            return "";
        }
    }

    readonly property var filteredApps: {
        if (calcResult !== "" || query.trim().startsWith("=")) return [];
        return search(query);
    }

    // App search shared with the Start menu: fuzzy over name, generic name,
    // command, comment and keywords, nudged by frecency. An empty query lists
    // every app, most used first.
    function search(text) {
        const all = DesktopEntries.applications.values.filter(app => !app.noDisplay);
        const q = text.trim();
        if (q === "") {
            return all.slice().sort((a, b) => (frecency(b) - frecency(a)) || a.name.localeCompare(b.name));
        }
        const scored = [];
        for (let i = 0; i < all.length; i++) {
            const app = all[i];
            const best = Math.max(
                Fuzzy.score(app.name, q),
                Fuzzy.score(app.genericName, q) - 50,
                Fuzzy.score(app.execString, q) - 80,
                Fuzzy.score(app.comment, q) - 100,
                Fuzzy.score(Fuzzy.joined(app.keywords), q) - 60);
            if (best >= 0) scored.push({ app: app, score: best + Math.min(150, frecency(app) * 20) });
        }
        scored.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));
        return scored.map(s => s.app);
    }

    readonly property int rowCount: calcResult !== "" ? 1 : filteredApps.length

    function launchSelected() {
        const text = query.trim();
        ShellState.closePopup("launcher");
        if (calcResult !== "") {
            Quickshell.execDetached(["wl-copy", "--", calcResult]);
            Quickshell.execDetached(["notify-send", "-t", "2000", "Copied", text.slice(1).trim() + " = " + calcResult]);
            return;
        }
        if (selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launchApp(filteredApps[selectedIndex]);
            return;
        }
        // No match: run the text as a shell command.
        if (text !== "" && !text.startsWith("=")) ShellState.launch(["sh", "-c", text]);
    }

    function show() {
        if (Desktop.mode === "windows") ShellState.openPopup("start", undefined, 0);
        else ShellState.openPopup("launcher");
    }

    // Start a desktop entry (and count it for frecency)
    function launchApp(app) {
        recordLaunch(app);
        const argv = [];
        for (let i = 0; i < app.command.length; i++) argv.push(app.command[i]);
        if (argv.length === 0) return;
        if (app.runInTerminal) ShellState.launchInTerminal(argv);
        else ShellState.launch(argv, app.workingDirectory);
    }

    function move(delta) {
        if (rowCount === 0) return;
        selectedIndex = (selectedIndex + delta + rowCount) % rowCount;
        resultsList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    onActiveChanged: {
        if (active) {
            launcherInput.text = "";
            selectedIndex = 0;
        }
    }

    IpcHandler {
        target: "launcher"
        // In Windows mode, the launcher key (Super+Space) opens the Start menu
        function open() { launcherScope.show(); }
        function show() { launcherScope.show(); }
        function hide() { ShellState.closePopup("launcher"); ShellState.closePopup("start"); }
        function toggle() {
            if (ShellState.activePopup === "launcher" || ShellState.activePopup === "start") hide();
            else launcherScope.show();
        }
    }

    ShellPopup {
        name: "launcher"
        centered: true
        panelWidth: 480
        panelHeight: 400

        Column {
            anchors.fill: parent
            spacing: Theme.spacingMedium

            ThemedField {
                id: launcherInput
                width: parent.width
                focus: true
                placeholderText: "Search apps...  (= for calculator)"
                onTextChanged: {
                    launcherScope.query = text;
                    launcherScope.selectedIndex = 0;
                    resultsList.positionViewAtBeginning();
                }
                Keys.onDownPressed: launcherScope.move(1)
                Keys.onUpPressed: launcherScope.move(-1)
                Keys.onTabPressed: launcherScope.move(1)
                onAccepted: launcherScope.launchSelected()
            }

            // Calculator result
            ListRow {
                width: parent.width
                height: 44
                visible: launcherScope.calcResult !== ""
                selected: true
                onClicked: launcherScope.launchSelected()

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.spacingMedium
                    Text {
                        text: "󰃬"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontIcon
                    }
                    Text {
                        text: launcherScope.calcResult
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLarge
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Enter to copy"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSmall
                    }
                }
            }

            ListView {
                id: resultsList
                width: parent.width
                height: parent.height - launcherInput.height - hintText.implicitHeight - Theme.spacingMedium * 2
                visible: launcherScope.calcResult === ""
                clip: true
                model: launcherScope.filteredApps
                currentIndex: launcherScope.selectedIndex
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: resultsList.width
                    selected: index === launcherScope.selectedIndex
                    onEntered: launcherScope.selectedIndex = index
                    onClicked: {
                        launcherScope.selectedIndex = index;
                        launcherScope.launchSelected();
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.spacingMedium

                        IconImage {
                            implicitSize: 20
                            source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                        }

                        Text {
                            text: modelData.name
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontMedium
                            elide: Text.ElideRight
                            Layout.maximumWidth: resultsList.width * 0.55
                        }

                        Text {
                            text: modelData.genericName || modelData.comment || ""
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: launcherScope.filteredApps.length === 0
                    text: launcherScope.query.trim().startsWith("=") ? "Enter an expression" : "No apps. Enter runs it as a command"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }

            Hint {
                id: hintText
                text: "↑/↓ navigate • Enter launch • =2+2 calculate • Esc cancel"
            }
        }
    }
}
