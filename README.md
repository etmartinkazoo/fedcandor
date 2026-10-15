<p align="center"><img src="site/public/logo.svg" width="96" alt="fedcandor logo"></p>

# fedcandor

**Stable. Secure. Beautiful. No compromises.** A desktop for people who want to get things done:
Fedora Atomic for stability and security, sway for productivity, and Quickshell for beauty.

**Website & docs: <https://etmartinkazoo.github.io/fedcandor/>**

- **Fedora** with fixed releases, SELinux enforcing, LUKS and firewalld, instead of a rolling distro.
- **sway**: a mature, i3-compatible compositor that changes slowly.
- **Quickshell**: one themed shell providing the bar, launcher (with calculator), notifications,
  clipboard history, screenshots and screen recording, Wi-Fi, Bluetooth, audio mixer, battery
  and power profiles, night light, lock screen, polkit dialog, system tray and a keybind cheatsheet.
- **Fedora Atomic image** (`atomic/`): the whole desktop as a signed, bootable image.
  Updates apply atomically, and the previous version is always one reboot away.

## Install (Fedora Workstation, Server or Everything)

```bash
git clone https://github.com/etmartinkazoo/fedcandor ~/fedcandor
cd ~/fedcandor
./install.sh
```

| Step              | Runs as | What it does |
|-------------------|---------|--------------|
| `system-packages` | sudo    | `dnf install` everything in `packages/fedora.txt` |
| `system-security` | sudo    | automatic security updates, closes unused ssh in the firewall, reports SELinux/Secure Boot/LUKS status |
| `fonts`           | user    | 0xProto Nerd Font from its GitHub release (pinned version, SHA-256 verified) |
| `icons`           | user    | Tela icon theme from its GitHub release (pinned version, SHA-256 verified) |
| `dotfiles`        | user    | links `dotfiles/*` into `$HOME` with GNU stow (`--no-folding`); anything in the way goes to `~/.local/state/fedcandor/backup-*` |
| `session`         | user    | enables `quickshell.service`, reloads sway |

`./install.sh --list` shows the steps. `./install.sh fonts icons` runs just those, and
`./install.sh --user-only` skips the sudo steps. Every step is idempotent, so re-running is how you update.

For **Fedora Atomic**, see [atomic/README.md](atomic/README.md).

## Layout

```
install.sh           entry point
lib/common.sh        shared helpers (logging, verified downloads)
steps/NN-*.sh        install steps, run in order
packages/fedora.txt  dnf package list (also used by the Atomic image)
dotfiles/<pkg>/      stow packages: sway, quickshell, foot, swappy, autostart, systemd, bin
atomic/              bootc image: Containerfile, build script, first-login setup
site/                website and docs (Astro); deployed to GitHub Pages
```

## Customizing

- **Per-machine sway settings** (wallpaper, keyboard options, output scaling) go in
  `~/.config/sway/config.d/80-local.conf`. It isn't tracked; `install.sh` creates a template.
- **Generated files** aren't tracked: `sway/config.d/99-theme.conf`, `foot/theme.ini`,
  `gtk-3.0/settings.ini` and `quickshell/firefox-theme/theme.json` all come from `apply-theme`,
  which runs whenever you switch theme in the bar.
- **Everything else** is a symlink into this repo: edit it here, then commit.

## Operating

- Quickshell runs as a systemd user service and restarts if it crashes.
  Logs: `journalctl --user -u quickshell -f`
- Lock: `loginctl lock-session` (or Super+Shift+E → L). `fedcandor-lock` waits until the lock
  is confirmed before allowing suspend, and falls back to swaylock.
- IPC: `qs ipc show` lists everything you can bind, e.g. `qs ipc call launcher toggle`.

## Security notes

- Bluetooth pairing is deny-by-default: only devices you pair from the Bluetooth menu are accepted,
  and the adapter is only pairable while the menu is open.
- Clipboard history (cliphist) is capped at 200 entries, and skips entries that password managers mark sensitive.
- Apps launched from the shell run in their own systemd scopes, so a shell restart never takes them down.
