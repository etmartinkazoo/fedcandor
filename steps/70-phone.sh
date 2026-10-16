#!/usr/bin/env bash
# [user] Phone panel: build fedcandor-phone (texts + calls) and start its service
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

# The Atomic image ships a prebuilt /usr/bin/fedcandor-phone. A build here
# (from a checkout, with Go installed) goes to ~/.local/bin, which the unit
# prefers, so hacking on the daemon works on the image too.
if command -v go >/dev/null 2>&1 && [ -d "$FEDCANDOR_ROOT/.git" -o ! -x /usr/bin/fedcandor-phone ]; then
    info "Building fedcandor-phone"
    mkdir -p "$HOME/.local/bin"
    ( cd "$FEDCANDOR_ROOT/phone" && go build -trimpath -o "$HOME/.local/bin/fedcandor-phone" ./cmd/fedcandor-phone )
    ok "fedcandor-phone installed to ~/.local/bin"
elif [ -x /usr/bin/fedcandor-phone ]; then
    ok "fedcandor-phone comes with the fedcandor image"
else
    warn "Go isn't installed: skipping the phone panel (install Go, then: ./install.sh phone)"
    exit 0
fi

systemctl --user daemon-reload
systemctl --user enable fedcandor-phone.service >/dev/null
if [ -n "${SWAYSOCK:-}" ]; then
    # --no-block: this step also runs from fedcandor-setup.service at login.
    systemctl --user --no-block restart fedcandor-phone.service
fi
ok "fedcandor-phone.service enabled"

if [ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/fedcandor/phone/session.json" ]; then
    info "Pair your phone: open \"Pair Phone\" from the launcher"
fi
