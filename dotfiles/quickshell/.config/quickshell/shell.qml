//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.I3
import Quickshell.Services.SystemTray

ShellRoot {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    function clockText(long) {
        const d = clock.date;
        const h12 = d.getHours() % 12 || 12;
        const ampm = d.getHours() >= 12 ? "pm" : "am";
        return Qt.formatDate(d, long ? "dddd, MMMM d" : "ddd, MMM d") + " - " + h12 + ":" + ("0" + d.getMinutes()).slice(-2) + ampm;
    }

    // Plugins (all themed via Theme.qml, popups coordinated by ShellState.qml)
    Launcher { id: launcher }
    Screenshot { id: screenshotTool }
    PowerMenu { id: powerMenu }
    Audio { id: audioTool }
    Clipboard { id: clipboardTool }
    Battery { id: batteryTool }
    Media { id: mediaTool }
    NotificationCenter { id: notifCenter }
    BluetoothMenu { id: btMenu }
    WifiMenu { id: wifiMenu }
    Caffeine { id: caffeineTool; barWindow: bars.instances.length > 0 ? bars.instances[0] : null }
    NightLight { id: nightLightTool }
    Keybinds { id: keybindsTool }
    SysMon { id: sysMon }
    LockScreen { id: lockScreen }
    Polkit { id: polkitAgent }

    Wallpaper {}
    ThemePicker { id: themePicker }

    // One bar per monitor
    Variants {
        id: bars
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            color: Theme.bgPanel
            anchors { bottom: true; left: true; right: true }
            implicitHeight: 34
            WlrLayershell.namespace: "quickshell-bar"

            function toggle(name, button) {
                ShellState.togglePopup(name, bar.screen, button.centerX());
            }

            readonly property var workspaces: I3.workspaces.values
                .filter(w => !w.monitor || w.monitor.name === bar.modelData.name)
                .sort((a, b) => (a.num - b.num) || a.name.localeCompare(b.name))

            Rectangle {
                anchors.fill: parent
                color: Theme.bgPanel
                border.color: Theme.border
                border.width: Theme.borderWidth
                radius: Theme.radius

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.paddingMedium
                    anchors.rightMargin: Theme.paddingMedium
                    spacing: Theme.spacingMedium

                    // Left: launcher, workspaces, media, recording
                    Row {
                        spacing: Theme.paddingSmall

                        BarButton {
                            icon: false
                            text: "LAUNCH"
                            highlighted: launcher.active
                            onLeftClicked: ShellState.togglePopup("launcher", bar.screen)
                        }

                        Repeater {
                            model: bar.workspaces
                            delegate: BarButton {
                                required property var modelData
                                icon: false
                                text: modelData.name
                                highlighted: modelData.active
                                critical: modelData.urgent
                                dim: !modelData.active
                                border.color: modelData.urgent ? Theme.borderCritical : (modelData.active ? Theme.border : Theme.borderSubtle)
                                onLeftClicked: modelData.activate()
                            }
                        }

                        BarButton {
                            id: mediaBtn
                            visible: mediaTool.hasPlayer
                            icon: false
                            text: mediaTool.barText
                            highlighted: mediaTool.active
                            onLeftClicked: bar.toggle("media", mediaBtn)
                            onMiddleClicked: if (mediaTool.player) mediaTool.player.togglePlaying()
                        }

                        BarButton {
                            visible: screenshotTool.recording
                            icon: false
                            text: screenshotTool.recordText
                            critical: true
                            textColor: Theme.borderCritical
                            onLeftClicked: screenshotTool.stopRecording()
                        }
                    }

                    // Center: clock, centered in the space between the two sides
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.clockText(bar.width >= 1600)
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontNormal
                        elide: Text.ElideRight
                    }

                    // Right: tray, system & plugin modules
                    Row {
                        spacing: Theme.paddingSmall

                        Repeater {
                            model: SystemTray.items
                            delegate: Rectangle {
                                id: trayItem
                                required property var modelData
                                width: 24
                                height: 24
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
                                    anchor.edges: Edges.Top
                                    anchor.gravity: Edges.Top
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
                            icon: false
                            text: sysMon.barText
                            critical: sysMon.hot
                            onLeftClicked: sysMon.openMonitor()
                        }

                        BarButton {
                            id: batBtn
                            icon: false
                            text: batteryTool.barText
                            highlighted: batteryTool.active
                            critical: batteryTool.isLow
                            onLeftClicked: bar.toggle("battery", batBtn)
                        }

                        BarButton {
                            id: volBtn
                            icon: false
                            text: audioTool.barText
                            highlighted: audioTool.active
                            dim: audioTool.isMuted
                            onLeftClicked: bar.toggle("audio", volBtn)
                            onRightClicked: audioTool.toggleMute()
                            onScrolled: function(delta) { audioTool.setVolume(audioTool.sink, audioTool.volumePct + (delta > 0 ? 5 : -5)); }
                        }

                        BarButton {
                            visible: audioTool.micMuted
                            text: audioTool.micIcon
                            critical: true
                            onLeftClicked: audioTool.toggleMicMute()
                        }

                        BarButton {
                            id: wifiBtn
                            text: wifiMenu.barIcon
                            highlighted: wifiMenu.active
                            onLeftClicked: bar.toggle("wifi", wifiBtn)
                        }

                        BarButton {
                            id: btBtn
                            text: btMenu.barIcon
                            highlighted: btMenu.active
                            onLeftClicked: bar.toggle("bluetooth", btBtn)
                            onRightClicked: btMenu.togglePower()
                        }

                        BarButton {
                            id: nlBtn
                            text: nightLightTool.barIcon
                            highlighted: nightLightTool.active || nightLightTool.enabled
                            dim: !nightLightTool.enabled
                            onLeftClicked: bar.toggle("nightlight", nlBtn)
                            onRightClicked: nightLightTool.toggleEnabled()
                        }

                        BarButton {
                            text: caffeineTool.barIcon
                            highlighted: caffeineTool.enabled
                            dim: !caffeineTool.enabled
                            onLeftClicked: caffeineTool.toggle()
                        }

                        BarButton {
                            id: themeBtn
                            text: "󰔎"
                            highlighted: themePicker.active
                            onLeftClicked: ShellState.togglePopup("themes", bar.screen)
                            onRightClicked: Theme.nextTheme()
                        }

                        BarButton {
                            id: clipBtn
                            text: "󰅌"
                            highlighted: clipboardTool.active
                            onLeftClicked: bar.toggle("clipboard", clipBtn)
                        }

                        BarButton {
                            id: shotBtn
                            text: "󰄀"
                            highlighted: screenshotTool.active
                            onLeftClicked: ShellState.togglePopup("screenshot", bar.screen)
                        }

                        BarButton {
                            id: notifBtn
                            icon: false
                            text: notifCenter.barText
                            highlighted: notifCenter.active || notifCenter.dnd
                            onLeftClicked: bar.toggle("notifications", notifBtn)
                            onRightClicked: notifCenter.setDnd(!notifCenter.dnd)
                        }

                        BarButton {
                            id: powerBtn
                            text: "⏻"
                            highlighted: powerMenu.active
                            onLeftClicked: bar.toggle("power", powerBtn)
                        }
                    }
                }
            }
        }
    }
}
