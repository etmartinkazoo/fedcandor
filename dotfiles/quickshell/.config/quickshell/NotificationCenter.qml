import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications as Notif

Scope {
    id: notifScope

    readonly property bool active: ShellState.activePopup === "notifications"
    readonly property bool dnd: ShellState.settings.dnd
    // History survives config reloads (not restarts, so nothing hits disk).
    // Stored as JSON: JS values can't cross into the reloaded engine.
    property var history: []
    onHistoryChanged: persist.historyJson = JSON.stringify(history)

    readonly property int count: history.length
    readonly property string barIcon: dnd ? "󰂛" : "󰂚"
    readonly property string barText: count > 0 ? (barIcon + " " + count) : barIcon

    function setDnd(on) { ShellState.settings.dnd = on; }

    // Badge count for an app's icon: its notifications since you last
    // switched to it.
    function countFor(appId) {
        const since = WindowList.lastFocused[appId] ?? 0;
        const name = WindowList.nameFor(appId).toLowerCase();
        const id = appId.toLowerCase();
        return history.filter(n => (n.ts ?? 0) > since
            && ((n.desktopEntry && n.desktopEntry.toLowerCase() === id)
                || (n.appName && (n.appName.toLowerCase() === name || n.appName.toLowerCase() === id)))).length;
    }

    PersistentProperties {
        id: persist
        reloadableId: "notificationHistory"
        property string historyJson: "[]"
        onReloaded: {
            try {
                notifScope.history = JSON.parse(historyJson);
            } catch (e) {
                notifScope.history = [];
            }
        }
    }

    // Quickshell reports expireTimeout in seconds; guard against ms just in case.
    function timeoutMs(n) {
        const t = n.expireTimeout;
        if (n.urgency === Notif.NotificationUrgency.Critical) return 0; // stays until dismissed
        if (!(t > 0)) return 5000;
        return t < 1000 ? t * 1000 : t;
    }

    function defaultAction(n) {
        const acts = n.actions;
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default") return acts[i];
        }
        return null;
    }

    function buttonActions(n) {
        const out = [];
        const acts = n.actions;
        for (let i = 0; i < acts.length; i++) {
            if (acts[i].identifier !== "default" && acts[i].text !== "") out.push(acts[i]);
        }
        return out;
    }

    Notif.NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            // Re-delivered after a config reload: already in history.
            if (notification.lastGeneration) {
                notification.tracked = true;
                return;
            }
            const d = new Date();
            const mins = ("0" + d.getMinutes()).slice(-2);
            const h12 = d.getHours() % 12 || 12;
            const ampm = d.getHours() >= 12 ? "pm" : "am";
            const critical = notification.urgency === Notif.NotificationUrgency.Critical;
            notifScope.history = [{
                summary: notification.summary || "Notification",
                body: notification.body || "",
                appName: notification.appName || "",
                desktopEntry: notification.desktopEntry || "",
                ts: Date.now(),
                critical: critical,
                time: h12 + ":" + mins + ampm
            }].concat(notifScope.history.slice(0, 49));

            // Critical notifications (e.g. low battery) always show, even in DND.
            if (notifScope.dnd && !critical) {
                notification.dismiss();
                return;
            }
            notification.tracked = true;
            const tracked = server.trackedNotifications.values;
            for (let i = 0; i < tracked.length - 3; i++) {
                if (tracked[i].urgency !== Notif.NotificationUrgency.Critical) tracked[i].expire();
            }
        }
    }

    function clearHistory() {
        history = [];
        const tracked = server.trackedNotifications.values.slice();
        for (let i = 0; i < tracked.length; i++) tracked[i].dismiss();
    }

    function removeAt(idx) {
        const next = history.slice();
        next.splice(idx, 1);
        history = next;
    }

    IpcHandler {
        target: "notifications"
        function open() { ShellState.openPopup("notifications"); }
        function hide() { ShellState.closePopup("notifications"); }
        function toggle() { ShellState.togglePopup("notifications"); }
        function clear() { notifScope.clearHistory(); }
        function toggleDnd() { notifScope.setDnd(!notifScope.dnd); }
    }

    // Live toast popups (top right of the focused screen)
    PanelWindow {
        id: toastPanel
        screen: ShellState.focusedScreen
        color: "transparent"
        anchors { top: true; right: true }
        margins { top: 10; right: 10 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        implicitWidth: 360
        implicitHeight: toastCol.implicitHeight
        visible: !notifScope.active && server.trackedNotifications.values.length > 0

        // Diffing model keeps existing toasts (and their timers) alive when a new one arrives.
        ScriptModel {
            id: toastModel
            values: server.trackedNotifications.values.slice(-4).reverse()
        }

        Column {
            id: toastCol
            width: parent.width
            spacing: Theme.spacingMedium

            Repeater {
                model: toastModel
                delegate: Rectangle {
                    id: toast
                    required property var modelData
                    readonly property bool critical: modelData.urgency === Notif.NotificationUrgency.Critical
                    readonly property var defAction: notifScope.defaultAction(modelData)
                    readonly property var buttons: notifScope.buttonActions(modelData)
                    width: toastCol.width
                    height: toastBody.implicitHeight + Theme.paddingMedium * 2
                    color: critical ? Theme.bgCritical : (toastMouse.containsMouse ? Theme.bgSelected : Theme.bgPanel)
                    border.color: critical ? Theme.borderCritical : Theme.border
                    border.width: Theme.borderWidth
                    radius: Theme.radius

                    MouseArea {
                        id: toastMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // Left click runs the default action (if any); right click dismisses.
                        onClicked: function(m) {
                            if (m.button === Qt.LeftButton && toast.defAction) toast.defAction.invoke();
                            else toast.modelData.dismiss();
                        }
                    }

                    Timer {
                        interval: Math.max(1000, notifScope.timeoutMs(toast.modelData))
                        running: notifScope.timeoutMs(toast.modelData) > 0 && !toastMouse.containsMouse
                        onTriggered: toast.modelData.expire()
                    }

                    RowLayout {
                        id: toastBody
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Theme.paddingMedium
                        }
                        spacing: Theme.spacingMedium

                        Image {
                            readonly property string src: toast.modelData.image || (toast.modelData.appIcon ? Quickshell.iconPath(toast.modelData.appIcon, true) : "")
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            Layout.alignment: Qt.AlignTop
                            visible: src !== "" && status !== Image.Error
                            source: src
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 80
                            sourceSize.height: 80
                            asynchronous: true
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                width: parent.width
                                Text {
                                    text: toast.modelData.summary
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontNormal
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: toast.modelData.appName
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSmall
                                }
                            }

                            Text {
                                width: parent.width
                                text: toast.modelData.body
                                visible: text !== ""
                                color: Theme.textSecondary
                                linkColor: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 6
                                elide: Text.ElideRight
                                onLinkActivated: function(link) { ShellState.launch(["xdg-open", link]); }
                            }

                            Flow {
                                width: parent.width
                                spacing: Theme.spacingSmall + 2
                                visible: toast.buttons.length > 0
                                topPadding: 2

                                Repeater {
                                    model: toast.buttons
                                    delegate: SmallButton {
                                        required property var modelData
                                        text: modelData.text
                                        onClicked: modelData.invoke()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Notification center
    ShellPopup {
        name: "notifications"
        panelHeight: 400
        panelWidth: 360
        defaultRightOffset: 50

        Column {
            anchors.fill: parent
            spacing: Theme.spacingMedium
            focus: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_D) notifScope.setDnd(!notifScope.dnd);
                else if (event.key === Qt.Key_C) notifScope.clearHistory();
                else return;
                event.accepted = true;
            }

            RowLayout {
                width: parent.width
                height: 28

                PanelTitle {
                    text: "NOTIFICATIONS"
                    Layout.fillWidth: true
                }

                SmallButton {
                    text: notifScope.dnd ? "DND: ON [D]" : "DND: OFF [D]"
                    highlighted: notifScope.dnd
                    onClicked: notifScope.setDnd(!notifScope.dnd)
                }

                SmallButton {
                    text: "CLEAR [C]"
                    onClicked: notifScope.clearHistory()
                }
            }

            ListView {
                id: histList
                width: parent.width
                height: parent.height - 28 - notifHint.implicitHeight - Theme.spacingMedium * 2
                clip: true
                model: notifScope.history
                spacing: Theme.spacingSmall

                delegate: ListRow {
                    required property var modelData
                    required property int index
                    width: histList.width
                    height: itemCol.implicitHeight + 16
                    outlined: true
                    critical: modelData.critical
                    onClicked: notifScope.removeAt(index)

                    Column {
                        id: itemCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 8
                        }
                        spacing: 4

                        RowLayout {
                            width: parent.width
                            Text {
                                text: modelData.summary
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontNormal
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (modelData.appName ? modelData.appName + " • " : "") + modelData.time
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSmall
                            }
                        }

                        Text {
                            width: parent.width
                            text: modelData.body
                            visible: text !== ""
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                            textFormat: Text.StyledText
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifScope.history.length === 0
                    text: "No notifications"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontNormal
                }
            }

            Hint {
                id: notifHint
                text: "[D] DND • [C] clear • click to remove • toast: click = open, right-click = dismiss"
            }
        }
    }
}
