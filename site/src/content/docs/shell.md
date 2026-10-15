---
title: The shell
description: Everything the Quickshell desktop shell does, feature by feature.
section: Using fedcandor
order: 2
---

The shell is one Quickshell program, themed as a whole and run as a systemd service that restarts
itself if it ever crashes. Only one popup is open at a time, and it opens on the screen you're using.

## Launcher

<kbd>Super</kbd>+<kbd>D</kbd>. Fuzzy search across app names, descriptions and keywords. Apps you launch
often rise to the top. Other inputs:

- `= 1240 * 1.0825` evaluates arithmetic; <kbd>Enter</kbd> copies the result.
- If nothing matches, <kbd>Enter</kbd> runs what you typed as a shell command.

Launched apps run in their own systemd scope, so restarting the shell never closes your work.

## Clipboard history

<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd>. The last 200 copies (text and images, with image previews),
searchable. <kbd>Enter</kbd> copies an entry back; <kbd>Del</kbd> or right-click removes one. Copies that a
password manager marks as sensitive are never recorded.

## Screenshots and recording

<kbd>Print</kbd>. Choose a **target** (area, window or screen) and an **action**:

| Action | Result |
|--------|--------|
| Copy | Image to the clipboard |
| Save | PNG in `~/Pictures/Screenshots` |
| Annotate | Opens in swappy to draw, highlight and blur |
| Record | MP4 screen recording. Stop it from the red `● REC` pill in the bar. |

<kbd>D</kbd> cycles a 3, 5 or 10 second delay.

## Notifications

Pop-ups appear at the top right and pause while you hover over them. Clicking a notification runs its
default action (usually opening the app it came from), and right-click dismisses it. Action buttons (Reply, Open, and so on) work.
**Do Not Disturb** (<kbd>D</kbd> in the center, or right-click the bell) silences everything except
critical alerts, such as low battery. History is kept in the notification center
(<kbd>Super</kbd>+<kbd>N</kbd>).

## Wi-Fi and DNS

Connect, disconnect and forget networks; passwords are passed to NetworkManager privately, never
on a command line. The DNS row switches the current connection between automatic, **Cloudflare**
(1.1.1.1, IPv4 and IPv6) and **custom** servers.

## Bluetooth

Scan, pair, connect and forget devices, with battery levels where available. Pairing is
**deny-by-default**: see [Security](../security/#bluetooth).

## Audio

Output and input volume, device switching (speakers, headphones, HDMI, Bluetooth, …), per-application volume and
mute, and a microphone mute indicator. Volume, mic and brightness keys show an on-screen display.

## Quick settings

The cog in the bar gathers appearance and everyday toggles in one place: the current theme (click
for the [theme picker](../themes/)), screen brightness, **warmth** (night light: Off, Auto or On,
with a slider), **keep awake** (stops the screen sleeping during a presentation), **Do Not Disturb**, and
one-click access to the screenshot tool, clipboard history and the shortcut cheatsheet.

**Auto** warmth follows the sun: warm from sunset to sunrise, neutral by day. The times are worked
out from your timezone's coordinates in the system's timezone database, so no location service is
involved and nothing leaves your machine. If the timezone can't be mapped, Auto uses 19:00–07:00.

## System

The right-most button shows the battery and opens the System panel: charge, time remaining,
battery health, live CPU, memory and temperature, power profiles (saver, balanced, performance),
and lock, suspend, log out, reboot and power off. Log out, reboot and power off ask for a second
press. At 15% battery you get a warning; at 5% the machine suspends after a 60-second countdown,
unless you plug in. <kbd>M</kbd> opens a task manager (`top`).

## Lock screen

The lock screen locks after 5 minutes idle, before suspend, or from the System panel (<kbd>L</kbd>).
It uses the system's standard login authentication (PAM), and the compositor keeps the session
locked even if the shell were to crash.

## Everything else

- **Themes**: five built in, plus any Omarchy theme; one switch recolors everything. See [Themes](../themes/).
- **Polkit dialog**: a themed password prompt when an app needs administrator rights.
- **System tray**: icons and menus for apps that provide them.
- **Keybinding cheatsheet**: <kbd>Super</kbd>+<kbd>/</kbd>, generated from your live sway configuration.

## Scripting it

Every popup and toggle is scriptable over IPC, so you can bind anything to a key:

```bash
qs ipc show                         # list every target and function
qs ipc call launcher toggle
qs ipc call notifications toggleDnd
qs ipc call nightlight setTemperature 3500
```
