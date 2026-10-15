---
title: Themes
description: Five built-in themes, live switching, and any Omarchy theme with one command.
section: Using fedcandor
order: 3
---

One theme colors everything at once, live and without restarting anything:

| What | How it follows the theme |
|------|--------------------------|
| Bar, popups, lock screen, wallpaper | instantly |
| Window borders (sway) | instantly |
| **kitty** (the default terminal) | instantly, in every open window |
| **Neovim** | instantly in every running Neovim using the `fedcandor` colorscheme (full Tree-sitter/LSP highlighting via mini.nvim when installed) |
| foot | instantly, if you use it |
| GTK apps and icons | light/dark and icon theme switch immediately |
| Firefox | via the bundled theme extension |

To make Neovim follow the theme, set the colorscheme in your `init.lua` (after your plugins load):

```lua
vim.cmd.colorscheme("fedcandor")
```

## Switching

Press <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd>, or click the theme in Quick Settings (the cog in the
bar), to open the picker. Arrow keys move, <kbd>Enter</kbd> applies (the picker stays open so you can compare), and
<kbd>B</kbd> shows the theme's next wallpaper.

From a terminal:

```bash
fedcandor-theme list
fedcandor-theme set tokyo-night
fedcandor-theme next
fedcandor-theme bg-next
```

## Built-in themes

| Theme | Mode | Character |
|-------|------|-----------|
| **candor** | dark | fedcandor's own: deep navy, clear blue accent. The default. |
| **graphite** | dark | Quiet and neutral, near-black with soft grey accents. |
| **tokyo-night** | dark | Cool blues and purples, with synthwave wallpapers. |
| **catppuccin** | dark | Soft pastels on a warm dark base. |
| **flexoki-light** | light | Warm, paper-like light theme for bright rooms and daytime. |

Themes without wallpaper images get a generated one, drawn by the shell from the theme's colors,
so it's sharp at any resolution.

## More themes from Omarchy

fedcandor uses the same palette format as [Omarchy](https://github.com/omacom/omarchy), so its
themes, and the community's, install directly:

```bash
fedcandor-theme install omarchy:gruvbox        # any theme in Omarchy's repository
fedcandor-theme install omarchy:nord
fedcandor-theme install https://github.com/<user>/<omarchy-theme-repo>
fedcandor-theme set gruvbox
```

Omarchy ships, among others, everforest, gruvbox, kanagawa, matte-black, nord, osaka-jade,
ristretto, rose-pine, catppuccin-latte and white. Installed themes live in
`~/.local/share/fedcandor/themes/`; remove one with `fedcandor-theme remove <name>`.

> Imported themes are only used as data. Every color must be a plain hex value; anything else is
> ignored, so a theme can't smuggle commands into your configuration.

## Your own wallpaper

```bash
fedcandor-theme wallpaper ~/Pictures/my-wallpaper.jpg   # use it with every theme
fedcandor-theme wallpaper --clear                       # back to the theme's wallpapers
```

## Making a theme

A theme is a folder with a `colors.toml`, plus optionally a `backgrounds/` folder of images:

```toml
mode = "dark"

accent = "#7aa2f7"
background = "#1a1b26"
foreground = "#a9b1d6"
# … plus red, green, yellow, blue, magenta, cyan and their bright_ variants
```

Missing keys are derived from the ones you set. Put the folder in
`~/.local/share/fedcandor/themes/<name>/`, or run `fedcandor-theme install ./my-theme`. The full
key list and the template syntax are in the
[themes README](https://github.com/etmartinkazoo/fedcandor/tree/main/themes).

To theme another app (for example Alacritty, Ghostty, btop or tmux), add a template to `~/.config/fedcandor/templates/`. Each `*.tpl` file
there is rendered to `~/.local/state/fedcandor/theme/rendered/` on every theme change, using
tokens like `{{ accent }}`, `{{ background_strip }}` or `{{ mix background accent 30% }}`.
