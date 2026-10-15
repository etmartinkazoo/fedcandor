# fedcandor on Fedora Atomic

The fedcandor desktop as a **bootable container image** on top of
[Fedora Sway Atomic](https://fedoraproject.org/atomic-desktops/sway/). Everything in this repo
is baked into one image, and the OS updates as a whole:

- **Atomic updates**: an update is a new image, staged in the background and applied on reboot.
  It never half-applies.
- **Rollback**: the previous image stays installed. Pick it in the boot menu, or run
  `rpm-ostree rollback`.
- **Signed**: CI signs every image with cosign, and the image only accepts signed updates.
- **Read-only `/usr`**: the dotfiles live in `/usr/share/fedcandor` and are symlinked into your
  home on login, so an image update updates your desktop too.

## Install

1. Install **Fedora Sway Atomic 45** from the ISO, with disk encryption enabled.
   (Any Fedora Atomic edition works as the starting point.)
2. Rebase to fedcandor. The first rebase is unverified, because the system doesn't have the
   signing key yet; the second one switches to signature-enforced updates:

   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/etmartinkazoo/fedcandor:latest
   systemctl reboot
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/etmartinkazoo/fedcandor:latest
   systemctl reboot
   ```

3. Log into the **Sway** session. On first login, `fedcandor-setup.service` links the dotfiles,
   and Quickshell starts.

Pin a Fedora release with the `:45` tag instead of `:latest`.

## Day to day

| Task | Command |
|------|---------|
| Status / pending update | `rpm-ostree status` |
| Update now (instead of waiting for the timer) | `rpm-ostree upgrade && systemctl reboot` |
| Roll back | `rpm-ostree rollback && systemctl reboot` |
| Add a package locally | `rpm-ostree install <pkg>` (better: add it to `packages/fedora.txt`) |
| GUI apps | Flatpak (`flatpak install flathub <app>`) |
| Dev tools | `toolbox create && toolbox enter` |

Updates are downloaded and staged automatically by `rpm-ostreed-automatic.timer`.

## Customizing

- Per-machine sway settings: `~/.config/sway/config.d/80-local.conf`.
- To hack on the desktop itself, clone the repo to `~/fedcandor` and run
  `./install.sh --user-only dotfiles session`. The links then point at your checkout, and the
  login setup leaves them alone.

## Building and publishing (maintainers)

CI (`.github/workflows/build-image.yml`) builds on every push to `main` and daily, to pick up
Fedora's base image updates. It pushes `ghcr.io/etmartinkazoo/fedcandor:{latest,45,45-YYYYMMDD}`
and signs the digest.

One-time setup:

```bash
cosign generate-key-pair                        # creates cosign.key + cosign.pub
mv cosign.pub atomic/cosign.pub && git add atomic/cosign.pub
gh secret set COSIGN_PRIVATE_KEY < cosign.key   # then delete cosign.key, or keep it offline
gh secret set COSIGN_PASSWORD                   # the password you chose
```

Then make the GHCR package public: GitHub → Packages → fedcandor → Package settings.

Local build (podman is preinstalled on Atomic):

```bash
podman build -f atomic/Containerfile -t localhost/fedcandor .
sudo bootc switch --transport containers-storage localhost/fedcandor   # test it on a spare machine/VM
```
