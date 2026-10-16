# Themes

A fedcandor theme is a folder with:

```
<name>/
  colors.toml        the palette (required)
  backgrounds/       wallpapers, cycled in order (optional; without them the shell
                     draws a generated wallpaper from the palette)
```

`colors.toml` uses the same format as [Omarchy](https://github.com/omacom/omarchy), so Omarchy
themes work as-is:

```bash
fedcandor-theme install omarchy:gruvbox              # a theme from Omarchy's repository
fedcandor-theme install https://github.com/<user>/<omarchy-theme-repo>
fedcandor-theme set gruvbox
```

Installed themes go to `~/.local/share/fedcandor/themes/`. A theme there with the same name as
a built-in one replaces it.

## Palette keys

`mode` (`dark` or `light`), `accent`, `selection`, `muted`, `background`, `dark_background`,
`darker_background`, `lighter_background`, `foreground`, `dark_foreground`, `light_foreground`,
`bright_foreground`, `red`, `yellow`, `orange`, `green`, `cyan`, `blue`, `magenta`, `brown`,
and the `bright_*` variants of the six ANSI colors. Missing keys are derived from the others,
following Omarchy's rules, so minimal and older themes work too.

## Templates

Built-in templates cover Quickshell, sway, kitty, foot, Neovim, GTK and Firefox, plus a
resolved `colors.toml` that terminal apps such as tern read.
`fedcandor-theme set` renders every file in `templates/` (overridable per user in
`~/.config/fedcandor/templates/`) with the palette:

| Token | Example output |
|-------|----------------|
| `{{ accent }}` | `#7aa2f7` |
| `{{ accent_strip }}` | `7aa2f7` |
| `{{ accent_rgb }}` | `122,162,247` |
| `{{ mix background accent 30% }}` | the color 30% of the way from background to accent |
| `{{ name }}`, `{{ mode }}` | theme name, `dark` or `light` |

## Credits and licenses

- **candor**, **candor-light**, **graphite** and **graphite-light** are original to fedcandor.
- **tokyo-night**, **catppuccin** and **flexoki-light** palettes and wallpapers come from
  [Omarchy](https://github.com/omacom/omarchy) (MIT License, © David Heinemeier Hansson and
  contributors). The underlying color schemes are
  [Tokyo Night](https://github.com/enkia/tokyo-night-vscode-theme) by enkia (MIT),
  [Catppuccin](https://github.com/catppuccin/catppuccin) (MIT) and
  [Flexoki](https://stephango.com/flexoki) by Steph Ango (MIT).
- The wallpapers were converted to JPEG and scaled to cover 4K. Omarchy-branded wallpapers, and
  wallpapers depicting third-party characters or trademarks, are deliberately not included.
