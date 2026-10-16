#!/usr/bin/env bash
# Runs inside the image build (as root). Bakes packages, fonts, icons, user
# units and security defaults into the image; per-user dotfiles are linked
# from /usr/share/fedcandor at login by fedcandor-setup.service.
set -euo pipefail

ROOT=/usr/share/fedcandor
IMAGE_REF=${IMAGE_REF:-ghcr.io/etmartinkazoo/fedcandor}
source "$ROOT/lib/common.sh"

info "Packages"
mapfile -t pkgs < <(package_list)
dnf5 -y install --setopt=install_weak_deps=False "${pkgs[@]}"
# Quickshell is the notification daemon, bar and polkit agent: remove what
# would compete for the same D-Bus names or duplicate the bar.
for p in mako dunst swaync waybar lxqt-policykit; do
    if rpm -q "$p" >/dev/null 2>&1; then dnf5 -y remove "$p"; fi
done
dnf5 clean all

info "Fonts and icons (system-wide)"
FEDCANDOR_FONT_DIR=/usr/share/fonts/0xProto bash "$ROOT/steps/30-fonts.sh"
FEDCANDOR_ICON_DIR=/usr/share/icons bash "$ROOT/steps/40-icons.sh"
fc-cache -f >/dev/null

info "Firefox theme extension"
FEDCANDOR_FIREFOX_PREFIX=/usr bash "$ROOT/steps/25-firefox.sh"

info "User units"
install -Dm644 "$ROOT/dotfiles/systemd/.config/systemd/user/quickshell.service" \
    /usr/lib/systemd/user/quickshell.service
install -Dm644 "$ROOT/atomic/fedcandor-setup.service" /usr/lib/systemd/user/fedcandor-setup.service
systemctl --global enable quickshell.service fedcandor-setup.service

info "Security defaults"
# Image updates are downloaded and staged automatically, applied on reboot;
# the previous image stays bootable for rollback.
sed -i 's/^#\?AutomaticUpdatePolicy=.*/AutomaticUpdatePolicy=stage/' /etc/rpm-ostreed.conf
systemctl enable rpm-ostreed-automatic.timer firewalld.service
zone=$(firewall-offline-cmd --get-default-zone)
firewall-offline-cmd --zone="$zone" --remove-service=ssh >/dev/null 2>&1 || true

# Only accept updates for this image when they're signed with our key.
if [ -f "$ROOT/atomic/cosign.pub" ]; then
    install -Dm644 "$ROOT/atomic/cosign.pub" /etc/pki/containers/fedcandor.pub
    install -Dm644 /dev/stdin /etc/containers/registries.d/fedcandor.yaml <<YAML
docker:
  ${IMAGE_REF}:
    use-sigstore-attachments: true
YAML
    tmp=$(mktemp)
    jq --arg ref "$IMAGE_REF" \
        '.transports.docker[$ref] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/fedcandor.pub", "signedIdentity": {"type": "matchRepository"}}]' \
        /etc/containers/policy.json > "$tmp"
    install -m644 "$tmp" /etc/containers/policy.json
    rm -f "$tmp"
else
    warn "atomic/cosign.pub missing: image signature verification not configured"
fi

echo "${IMAGE_VERSION:-dev}" > "$ROOT/IMAGE_VERSION"
ok "fedcandor image build done (${IMAGE_VERSION:-dev})"
