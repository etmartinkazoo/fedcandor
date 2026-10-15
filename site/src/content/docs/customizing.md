---
title: Customizing
description: Change wallpaper, keyboard, displays, keybindings and themes without fighting updates.
section: Running it
order: 3
---

fedcandor separates **what it ships** from **what's yours**, so updates never overwrite your
changes and your changes never block updates.

## Per-machine settings: `80-local.conf`

`~/.config/sway/config.d/80-local.conf` is yours and is never touched by updates. Use it for
anything specific to one machine or person:

```ini
# Wallpaper
output * bg ~/Pictures/wallpaper.jpg fill

# Displays: run `swaymsg -t get_outputs` for names
output eDP-1 scale 1.5
output DP-1 resolution 2560x1440 position 1920,0

# Keyboard
input "type:keyboard" {
    xkb_layout us,de
    xkb_options ctrl:nocaps,grp:alt_shift_toggle
}

# Your own shortcuts
bindsym $mod+Shift+t exec flatpak run org.mozilla.Thunderbird
```

Apply it with <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> (reload sway). New bindings show up in the
<kbd>Super</kbd>+<kbd>/</kbd> cheatsheet automatically. For `exec` bindings, a `#` comment line just
above the binding becomes its description.

## Themes

Five themes ship built in, and any Omarchy theme installs with one command. See [Themes](../themes/).

## Changing the desktop itself

The configuration is plain text in the [fedcandor repository](https://github.com/etmartinkazoo/fedcandor):

```
dotfiles/sway/        sway config and drop-ins
dotfiles/quickshell/  the shell (QML)
dotfiles/bin/         helper scripts
```

To make deeper changes, clone it and link from your checkout:

```bash
git clone https://github.com/etmartinkazoo/fedcandor ~/fedcandor
cd ~/fedcandor && ./install.sh --user-only dotfiles session
```

Your config files are then symlinks into `~/fedcandor`. Edit them, and the shell reloads live.
On Atomic, the login setup sees your checkout and leaves your links alone.

## What not to edit

Files that are **generated**: `fedcandor-theme` rewrites them whenever you switch theme.

- `~/.config/sway/config.d/99-theme.conf`
- `~/.config/kitty/theme.conf` (put your own kitty tweaks in `~/.config/kitty/local.conf`)
- `~/.config/nvim/colors/fedcandor.lua`
- `~/.config/foot/theme.ini`
- `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini`

To change what they contain, override the template instead (see [Themes](../themes/#making-a-theme)).
