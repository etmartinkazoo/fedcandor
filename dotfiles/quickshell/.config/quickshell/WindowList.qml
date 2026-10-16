pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

// Every open window, read from sway's tree and refreshed on window events.
// Used by the bars, the dock, the switchers, the overview and the title-bar
// buttons.
//
// Minimizing a window moves it to sway's scratchpad; restoring shows it again
// on the current workspace. Floating windows can be maximized and snapped to
// halves and quarters of the screen (sway itself only has fullscreen).
Singleton {
    id: wl

    // [{ id, appId, title, focused, minimized, workspace, output, floating,
    //    fullscreen, visible, toplevelId, frame: {x, y, width, height}, titleHeight }]
    // in tree order. `frame` is the whole window in layout coordinates, title
    // bar included; `titleHeight` is 0 without a title bar.
    property var windows: []
    // Usable area (bars excluded) per workspace and per output: name -> {x, y, width, height}
    property var workspaceRects: ({})
    property var outputRects: ({})
    // Window ids, most recently focused first
    property var mru: []
    // appId -> when it last had focus (ms), for notification badges
    property var lastFocused: ({})

    // Apps with open windows, most recently used first:
    // [{ appId, windows: [window, ...] (MRU order) }]
    readonly property var apps: {
        const byApp = {};
        const out = [];
        for (const w of windowsByMru) {
            if (!(w.appId in byApp)) {
                byApp[w.appId] = { appId: w.appId, windows: [] };
                out.push(byApp[w.appId]);
            }
            byApp[w.appId].windows.push(w);
        }
        return out;
    }

    readonly property var windowsByMru: {
        const order = id => { const i = mru.indexOf(id); return i < 0 ? 1e9 : i; };
        return windows.slice().sort((a, b) => order(a.id) - order(b.id));
    }

    readonly property var focusedWindow: windows.find(w => w.focused) ?? null

    // Taskbar/dock order: pinned apps first, then other running apps in the
    // order their windows opened (stable, unlike MRU).
    function barApps(pinned) {
        const out = pinned.map(a => ({ appId: a, pinned: true }));
        for (const w of windows) {
            if (!out.some(x => x.appId === w.appId)) out.push({ appId: w.appId, pinned: false });
        }
        return out;
    }

    function isRunning(appId) {
        return windows.some(w => w.appId === appId);
    }

    // Left click on an app tile: switch to it, or start it
    function clickApp(appId) {
        if (!activateApp(appId)) launch(appId);
    }

    function windowsOf(appId) {
        return windowsByMru.filter(w => w.appId === appId);
    }

    // ---- Actions ----
    function focus(id) {
        const w = windows.find(x => x.id === id);
        if (w && w.minimized) restore(id);
        else I3.dispatch(`[con_id=${id}] focus`);
    }

    // ---- Minimize (to sway's scratchpad), keeping each window's place ----
    // id -> { frame, floating } from just before it was minimized
    property var minimizedState: ({})

    function minimize(id) {
        const w = find(id);
        if (w && !w.minimized) {
            const ms = Object.assign({}, minimizedState);
            ms[id] = { frame: w.frame, floating: w.floating };
            minimizedState = ms;
        }
        I3.dispatch(`[con_id=${id}] move scratchpad`);
    }

    // Bring a minimized window back where it was (scratchpad show alone would
    // center it as a floating window)
    function restore(id) {
        const st = minimizedState[id];
        const ms = Object.assign({}, minimizedState);
        delete ms[id];
        minimizedState = ms;
        if (st && !st.floating) {
            I3.dispatch(`[con_id=${id}] scratchpad show, floating disable`);
        } else if (st) {
            I3.dispatch(`[con_id=${id}] scratchpad show`);
            setFrame(id, st.frame);
        } else {
            I3.dispatch(`[con_id=${id}] scratchpad show`);
        }
    }

    // Alt+H: hide every window of the focused app (like macOS's Hide)
    function hideFocusedApp() {
        const w = focusedWindow;
        if (!w) return;
        for (const x of windows) {
            if (x.appId === w.appId && !x.minimized) minimize(x.id);
        }
    }

    // Alt+D: minimize every window on the current workspace; again brings
    // them all back, the previously focused one on top.
    property var desktopShown: ({ workspace: "", ids: [], focused: -1 })

    function toggleDesktop() {
        const ws = I3.focusedWorkspace ? I3.focusedWorkspace.name : "";
        const back = desktopShown.ids.filter(id => { const w = find(id); return w && w.minimized; });
        if (desktopShown.workspace === ws && back.length > 0) {
            for (const id of back) if (id !== desktopShown.focused) restore(id);
            if (back.includes(desktopShown.focused)) restore(desktopShown.focused);
            desktopShown = { workspace: "", ids: [], focused: -1 };
            return;
        }
        const visible = windows.filter(w => w.workspace === ws && !w.minimized);
        if (visible.length === 0) return;
        desktopShown = { workspace: ws, ids: visible.map(w => w.id), focused: focusedWindow ? focusedWindow.id : -1 };
        for (const w of visible) minimize(w.id);
    }

    function close(id) {
        I3.dispatch(`[con_id=${id}] kill`);
    }

    // ---- Maximize and snapping (floating windows) ----
    // id -> zone ("max", "left", "right", "tl", "tr", "bl", "br")
    property var snapped: ({})
    // id -> the frame to go back to when un-snapped
    property var restoreFrames: ({})

    function find(id) {
        return windows.find(w => w.id === id) ?? null;
    }

    // Snapped to "max", or simply filling its workspace (also after a shell
    // restart, when the snap state is gone)
    function isMaximized(id) {
        if (snapped[id] === "max") return true;
        const w = find(id);
        const t = w && w.floating ? zoneRect(w, "max") : null;
        return t !== null && Math.abs(t.x - w.frame.x) <= 2 && Math.abs(t.y - w.frame.y) <= 2
            && Math.abs(t.width - w.frame.width) <= 2 && Math.abs(t.height - w.frame.height) <= 2;
    }

    function zoneRect(win, zone) {
        const a = workspaceRects[win.workspace];
        if (!a) return null;
        const hw = Math.round(a.width / 2), hh = Math.round(a.height / 2);
        switch (zone) {
        case "max": return { x: a.x, y: a.y, width: a.width, height: a.height };
        case "left": return { x: a.x, y: a.y, width: hw, height: a.height };
        case "right": return { x: a.x + hw, y: a.y, width: a.width - hw, height: a.height };
        case "tl": return { x: a.x, y: a.y, width: hw, height: hh };
        case "tr": return { x: a.x + hw, y: a.y, width: a.width - hw, height: hh };
        case "bl": return { x: a.x, y: a.y + hh, width: hw, height: a.height - hh };
        case "br": return { x: a.x + hw, y: a.y + hh, width: a.width - hw, height: a.height - hh };
        }
        return null;
    }

    function setFrame(id, f) {
        snapTimer.restart();
        geometryChanged();
        I3.dispatch(`[con_id=${id}] resize set ${Math.round(f.width)} ${Math.round(f.height)}, move absolute position ${Math.round(f.x)} ${Math.round(f.y)}`);
    }

    function snap(id, zone) {
        const w = find(id);
        if (!w || !w.floating || w.fullscreen) return;
        const target = zoneRect(w, zone);
        if (!target) return;
        if (!(id in snapped)) {
            const rf = Object.assign({}, restoreFrames);
            rf[id] = w.frame;
            restoreFrames = rf;
        }
        const sn = Object.assign({}, snapped);
        sn[id] = zone;
        snapped = sn;
        setFrame(id, target);
    }

    // Back to the size and place it had before it was snapped or maximized
    function unsnap(id) {
        const f = restoreFrames[id];
        forget(id);
        if (f) setFrame(id, f);
    }

    function forget(id) {
        const sn = Object.assign({}, snapped);
        const rf = Object.assign({}, restoreFrames);
        delete sn[id];
        delete rf[id];
        snapped = sn;
        restoreFrames = rf;
    }

    function toggleMaximize(id) {
        if (!isMaximized(id)) {
            snap(id, "max");
        } else if (restoreFrames[id]) {
            unsnap(id);
        } else {
            // Maximized before we knew its size: restore to 70%, centered
            const w = find(id);
            const a = w ? workspaceRects[w.workspace] : null;
            forget(id);
            if (a) setFrame(id, { x: a.x + a.width * 0.15, y: a.y + a.height * 0.15, width: a.width * 0.7, height: a.height * 0.7 });
        }
    }

    // Super+Alt+arrows on the focused window, like Windows: left/right snap to
    // a half; up/down from a half go to a quarter; up maximizes; down
    // un-maximizes, then minimizes.
    function snapKey(dir) {
        const w = focusedWindow;
        if (!w || !w.floating) return;
        const z = snapped[w.id] ?? "";
        const moves = {
            left:  { "": "left", max: "left", right: "", left: "left", tl: "tl", tr: "tl", bl: "bl", br: "bl" },
            right: { "": "right", max: "right", left: "", right: "right", tl: "tr", tr: "tr", bl: "br", br: "br" },
            up:    { "": "max", max: "max", left: "tl", right: "tr", tl: "tl", tr: "tr", bl: "left", br: "right" },
            down:  { "": "minimize", max: "", left: "bl", right: "br", tl: "left", tr: "right", bl: "bl", br: "br" }
        };
        const next = moves[dir][z];
        if (next === "minimize") minimize(w.id);
        else if (next === "") unsnap(w.id);
        else if (next !== z) snap(w.id, next);
    }

    // ---- Window snapshots (overview, taskbar/dock previews) ----
    // Captured with grim, one PNG per window, into a private runtime folder.
    // Not live: refreshed whenever a preview or the overview opens.
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/fedcandor/thumbs"
    property int thumbVersion: 0
    property var pendingCaptures: []

    function thumbFor(id) {
        return "file://" + thumbDir + "/" + id + ".png?v=" + thumbVersion;
    }

    function capture(list) {
        const args = [];
        for (const w of list) {
            if (w.toplevelId && /^[0-9a-f]+$/.test(w.toplevelId)) args.push(String(w.id), w.toplevelId);
        }
        if (args.length === 0) return;
        if (captureProc.running) {
            pendingCaptures = pendingCaptures.concat(list);
            return;
        }
        captureProc.command = ["sh", Quickshell.shellPath("scripts/window-thumbs.sh"), thumbDir].concat(args);
        captureProc.running = true;
    }

    Process {
        id: captureProc
        onExited: {
            wl.thumbVersion++;
            if (wl.pendingCaptures.length > 0) {
                const next = wl.pendingCaptures;
                wl.pendingCaptures = [];
                wl.capture(next);
            }
        }
    }

    // Taskbar/dock click: focus the app; if it's already focused, minimize
    // it; with several windows, cycle through them.
    function activateApp(appId) {
        const ws = windowsOf(appId);
        if (ws.length === 0) return false;
        const focused = ws.find(w => w.focused);
        if (!focused) focus(ws[0].id);
        else if (ws.length === 1) minimize(focused.id);
        else focus(ws[ws.length - 1].id);   // least recent: cycles through all of them
        return true;
    }

    // ---- Desktop entries ----
    function entryFor(appId) {
        return DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
    }

    function iconFor(appId) {
        const e = entryFor(appId);
        return Quickshell.iconPath(e && e.icon ? e.icon : appId, "application-x-executable");
    }

    function nameFor(appId) {
        const e = entryFor(appId);
        return e && e.name ? e.name : appId;
    }

    function launch(appId) {
        const e = entryFor(appId);
        if (!e) return;
        const argv = [];
        for (let i = 0; i < e.command.length; i++) argv.push(e.command[i]);
        if (argv.length === 0) return;
        if (e.runInTerminal) ShellState.launchInTerminal(argv);
        else ShellState.launch(argv, e.workingDirectory);
    }

    // ---- Reading the tree ----
    Process {
        id: treeProc
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    wl.windows = wl.parse(JSON.parse(text));
                } catch (e) {
                    console.warn("windowlist: bad tree", e);
                }
            }
        }
    }

    function parse(root) {
        const out = [];
        const wsRects = {};
        const outRects = {};
        const walk = (node, output, workspace) => {
            if (node.type === "output") {
                output = node.name;
                outRects[node.name] = node.rect;
            }
            if (node.type === "workspace") {
                workspace = node.name;
                wsRects[node.name] = node.rect;
            }
            if ((node.type === "con" || node.type === "floating_con") && node.pid) {
                const appId = node.app_id || (node.window_properties && node.window_properties.class) || "unknown";
                const floating = node.type === "floating_con";
                // A floating window's rect starts below its title bar (deco_rect)
                const titleHeight = floating && node.deco_rect ? node.deco_rect.height : 0;
                out.push({
                    id: node.id,
                    appId: appId,
                    title: node.name || appId,
                    focused: node.focused,
                    minimized: workspace === "__i3_scratch",
                    workspace: workspace,
                    output: output,
                    floating: floating,
                    fullscreen: (node.fullscreen_mode || 0) > 0,
                    visible: node.visible === true,
                    toplevelId: node.foreign_toplevel_identifier || "",
                    titleHeight: titleHeight,
                    frame: {
                        x: node.rect.x,
                        y: node.rect.y - titleHeight,
                        width: node.rect.width,
                        height: node.rect.height + titleHeight
                    }
                });
                if (node.focused && mru[0] !== node.id) mru = [node.id].concat(mru.filter(x => x !== node.id));
                if (node.focused) {
                    const lf = Object.assign({}, lastFocused);
                    lf[appId] = Date.now();
                    lastFocused = lf;
                }
            }
            for (const c of (node.nodes || [])) walk(c, output, workspace);
            for (const c of (node.floating_nodes || [])) walk(c, output, workspace);
        };
        walk(root, "", "");
        const alive = new Set(out.map(w => w.id));
        mru = mru.filter(id => alive.has(id));
        workspaceRects = wsRects;
        outputRects = outRects;
        // Forget snaps of closed windows, and of windows moved or resized since
        for (const id in snapped) {
            const w = out.find(x => String(x.id) === id);
            const target = w ? zoneRect(w, snapped[id]) : null;
            if (!w || !w.floating || !target || Math.abs(target.x - w.frame.x) > 2 || Math.abs(target.y - w.frame.y) > 2
                || Math.abs(target.width - w.frame.width) > 2 || Math.abs(target.height - w.frame.height) > 2) {
                if (!w || !pendingSnap(id)) forget(Number(id));
            }
        }
        return out;
    }

    // A snap was just requested and sway may not have applied it yet
    function pendingSnap(id) {
        return snapTimer.running;
    }

    function refresh() {
        if (!treeProc.running) treeProc.running = true;
        else refreshAgain.restart();
    }

    // Grace period after a snap, before a mismatched frame counts as "moved"
    Timer {
        id: snapTimer
        interval: 400
    }

    // Moving or resizing a floating window sends no sway event: re-read the
    // tree shortly after we do it ourselves.
    Timer {
        id: geometryRefresh
        interval: 120
        onTriggered: wl.refresh()
    }

    function geometryChanged() {
        geometryRefresh.restart();
    }

    // Coalesce bursts of events (a new window sends several)
    Timer {
        id: refreshAgain
        interval: 60
        onTriggered: wl.refresh()
    }

    I3IpcListener {
        subscriptions: ["window", "workspace", "output"]
        onIpcEvent: refreshAgain.restart()
    }

    // A desktop mode switch swaps the bars, which changes every workspace's
    // usable area without a sway event.
    Connections {
        target: Desktop
        function onModeChanged() { geometryRefresh.restart(); }
    }

    Component.onCompleted: refresh()
}
