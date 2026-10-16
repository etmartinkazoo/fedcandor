#!/usr/bin/env bash
# Per-user setup on fedcandor Atomic, run at login by fedcandor-setup.service.
# Links the dotfiles into $HOME (stow, no folding) and enables the user
# services: from /usr/share/fedcandor the first time and again whenever the
# image ships a new fedcandor version, or from a ~/fedcandor checkout (as
# bootstrap.sh clones) once, after which you re-run ./install.sh there
# yourself. Customize via ~/.config/sway/config.d/80-local.conf.
set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/fedcandor"
mkdir -p "$STATE"

if [ -d "$HOME/fedcandor/.git" ]; then
    root="$HOME/fedcandor"
    version=checkout
else
    root=/usr/share/fedcandor
    version=$(cat "$root/IMAGE_VERSION" 2>/dev/null || echo unknown)
fi
if [ "$(cat "$STATE/linked-version" 2>/dev/null)" = "$version" ]; then
    exit 0
fi

"$root/install.sh" --user-only dotfiles session phone
echo "$version" > "$STATE/linked-version"
