#!/usr/bin/env bash
# [user] Tela icon theme from its GitHub release (pinned + verified).
# Installs the blue and grey folder colors (each with light/dark variants);
# the Quickshell theme picks Tela-blue-dark or Tela-grey-dark.
set -euo pipefail
source "$(dirname "$0")/../lib/common.sh"

VERSION="2026-07-07"
SHA256="6b8c28f637067a15551459ab90e6720c5aba1215b777b6f1f506fea188a1ddf9"
URL="https://github.com/vinceliuice/Tela-icon-theme/archive/refs/tags/${VERSION}.tar.gz"
COLORS=(blue grey)
DEST="${FEDCANDOR_ICON_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/icons}"
STAMP="$DEST/.fedcandor-tela-version"

if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$VERSION" ]; then
    ok "Tela icon theme $VERSION already installed"
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
info "Downloading Tela icon theme $VERSION"
download_verified "$URL" "$SHA256" "$tmp/tela.tar.gz"
tar -xzf "$tmp/tela.tar.gz" -C "$tmp"

mkdir -p "$DEST"
info "Installing Tela (${COLORS[*]}) to $DEST"
(cd "$tmp/Tela-icon-theme-$VERSION" && ./install.sh -d "$DEST" "${COLORS[@]}" >/dev/null)
echo "$VERSION" > "$STAMP"
ok "Tela icon theme $VERSION installed"
