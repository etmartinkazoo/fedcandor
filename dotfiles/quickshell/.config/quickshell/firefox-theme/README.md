# Quickshell Theme Sync (Firefox WebExtension)

Applies the desktop palette (generated from `~/.config/quickshell/Theme.qml` by
`~/.local/bin/apply-theme`) to Firefox using the **supported** `theme`
WebExtension API.

This is the supported replacement for the old `userContent.css` new-tab hacks.
One `browser.theme.update()` call covers:

- browser chrome / toolbar / URL bar
- tabs (selected colour, separator)
- menus and panels
- sidebar
- **new tab page** via `ntp_background`, `ntp_text`, `ntp_card_background`
- content colour scheme (forced dark)

## Files

| File | Purpose |
| --- | --- |
| `manifest.json` | MV3 manifest (Firefox `browser_specific_settings`). |
| `background.js` | Reads `theme.json`, calls `browser.theme.update()`. |
| `theme.json` | Palette. **Auto-generated** by `apply-theme` — do not edit. |
| `icons/icon.svg` | Toolbar/add-on icon. |

## Loading it

### Quick / temporary (no account, no signing)

```sh
~/.local/bin/firefox-theme temp
```

Then `about:debugging#/runtime/this-firefox` → **Load Temporary Add-on…** →
pick `manifest.json` here.

Temporary add-ons read `theme.json` **live from this directory**, so after the
desktop theme changes you just press **Reload** in `about:debugging`. Nothing to
repack.

### Permanent (Firefox release requires signing)

Firefox **release** ignores `xpinstall.signatures.required=false`, so an
unsigned add-on cannot be installed permanently. Get a free unlisted
signature from AMO:

1. Create an account at <https://addons.mozilla.org>.
2. Generate API credentials: <https://addons.mozilla.org/developers/addon/api/key/>
3. Export them and sign:

   ```sh
   export AMO_JWT_ISSUER='user:xxxxx:yyy'
   export AMO_JWT_SECRET='zzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'
   ~/.local/bin/firefox-theme sign
   ~/.local/bin/firefox-theme install
   ```

`install` drops the signed XPI into `<profile>/extensions/quickshell-theme@local.xpi`.
If Firefox starts with it disabled, enable it once in `about:addons`.

Alternatives that allow unsigned add-ons: **Firefox Developer Edition** or
**ESR** with `xpinstall.signatures.required=false`.

## Refreshing colours

The signed XPI bakes `theme.json` in at sign time, so after a theme change:

```sh
~/.local/bin/apply-theme ...   # already run automatically by Quickshell
~/.local/bin/firefox-theme build
~/.local/bin/firefox-theme sign && ~/.local/bin/firefox-theme install
```

For temporary/source-dir loads, just hit **Reload** in `about:debugging`.
