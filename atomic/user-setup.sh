#!/usr/bin/env bash
# Per-user setup on fedcandor Atomic, run at login by fedcandor-setup.service.
# Links /usr/share/fedcandor/dotfiles into $HOME (stow, no folding) the first
# time and again whenever the image ships a new fedcandor version. Customize
# via ~/.config/sway/config.d/80-local.conf, or clone the repo to ~/fedcandor
# and run ./install.sh from there (then this script leaves your links alone).
set -euo pipefail

SRC=/usr/share/fedcandor
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/fedcandor"
mkdir -p "$STATE"

if [ -d "$HOME/fedcandor/.git" ]; then
    echo "fedcandor: using your ~/fedcandor checkout; not relinking image dotfiles"
    exit 0
fi

version=$(cat "$SRC/IMAGE_VERSION" 2>/dev/null || echo unknown)
if [ "$(cat "$STATE/linked-version" 2>/dev/null)" = "$version" ]; then
    exit 0
fi

"$SRC/install.sh" --user-only dotfiles session
echo "$version" > "$STATE/linked-version"
