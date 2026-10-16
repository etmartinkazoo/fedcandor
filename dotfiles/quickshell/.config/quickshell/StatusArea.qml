import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

// The right-hand cluster every bar shares: tray, quick settings, volume,
// Wi-Fi, Bluetooth, notifications and the system menu. One component, so
// spacing, sizes and behavior are identical in every desktop mode.
Row {
    id: area

    required property var barWindow     // the PanelWindow this sits in (popups open on its screen)
    required property var tools          // shell.qml's tool objects

    spacing: Theme.paddingSmall

    function toggle(name, item) {
        ShellState.togglePopup(name, barWindow.screen, item.centerX());
    }

    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: trayItem
            required property var modelData
            width: Desktop.pillHeight
            height: Desktop.pillHeight
            color: trayMouse.containsMouse ? Theme.bgSelected : Theme.bgItem
            border.color: Theme.borderSubtle
            border.width: Theme.borderWidth
            radius: Theme.radius

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayItem.modelData.icon
            }

            QsMenuAnchor {
                id: trayMenu
                menu: trayItem.modelData.menu
                anchor.item: trayItem
                anchor.edges: Desktop.barOnTop ? Edges.Bottom : Edges.Top
                anchor.gravity: Desktop.barOnTop ? Edges.Bottom : Edges.Top
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: function(m) {
                    const item = trayItem.modelData;
                    if (m.button === Qt.MiddleButton) item.secondaryActivate();
                    else if (m.button === Qt.LeftButton && !item.onlyMenu) item.activate();
                    else if (item.hasMenu) trayMenu.open();
                }
                onWheel: function(w) { trayItem.modelData.scroll(w.angleDelta.y, false); }
            }
        }
    }

    BarButton {
        id: quickBtn
        text: area.tools.quick.barText
        highlighted: area.tools.quick.active || area.tools.themes.active
        onLeftClicked: area.toggle("quick", quickBtn)
    }

    BarButton {
        id: volBtn
        icon: false
        // A muted microphone shows inside the volume pill.
        text: area.tools.audio.barText + (area.tools.audio.micMuted ? "  " + area.tools.audio.micIcon : "")
        critical: area.tools.audio.micMuted
        highlighted: area.tools.audio.active
        dim: area.tools.audio.isMuted
        onLeftClicked: area.toggle("audio", volBtn)
        onRightClicked: area.tools.audio.toggleMute()
        onScrolled: function(delta) { area.tools.audio.setVolume(area.tools.audio.sink, area.tools.audio.volumePct + (delta > 0 ? 5 : -5)); }
    }

    BarButton {
        id: wifiBtn
        text: area.tools.wifi.barIcon
        highlighted: area.tools.wifi.active
        onLeftClicked: area.toggle("wifi", wifiBtn)
    }

    BarButton {
        id: btBtn
        text: area.tools.bluetooth.barIcon
        highlighted: area.tools.bluetooth.active
        onLeftClicked: area.toggle("bluetooth", btBtn)
        onRightClicked: area.tools.bluetooth.togglePower()
    }


    BarButton {
        id: notifBtn
        icon: false
        text: area.tools.notifications.barText
        highlighted: area.tools.notifications.active || area.tools.notifications.dnd
        onLeftClicked: area.toggle("notifications", notifBtn)
        onRightClicked: area.tools.notifications.setDnd(!area.tools.notifications.dnd)
    }

    BarButton {
        id: systemBtn
        icon: !area.tools.battery.hasBattery
        text: area.tools.system.barText
        highlighted: area.tools.system.active
        critical: area.tools.battery.isLow
        onLeftClicked: area.toggle("system", systemBtn)
    }
}
