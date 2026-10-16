#!/usr/bin/env bash
# [user] Phone panel: build fedcandor-phone (texts + calls) and start its service
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

if ! command -v go >/dev/null 2>&1; then
    warn "Go isn't installed: skipping the phone panel (install Go, then: ./install.sh phone)"
    exit 0
fi
info "Building fedcandor-phone"
mkdir -p "$HOME/.local/bin"
( cd "$FEDCANDOR_ROOT/phone" && go build -trimpath -o "$HOME/.local/bin/fedcandor-phone" ./cmd/fedcandor-phone )
ok "fedcandor-phone installed to ~/.local/bin"

systemctl --user daemon-reload
systemctl --user enable fedcandor-phone.service >/dev/null
if [ -n "${SWAYSOCK:-}" ]; then
    systemctl --user restart fedcandor-phone.service
fi
ok "fedcandor-phone.service enabled"

if [ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/fedcandor/phone/session.json" ]; then
    info "Pair your phone: open \"Pair Phone\" from the launcher"
fi
