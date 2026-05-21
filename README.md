# Singularity

Custom Fedora Atomic image for an AMD Ryzen 5800 laptop (iGPU only) running Hyprland.  
Built with [BlueBuild](https://blue-build.org) and published to GitHub Container Registry.

---

## Overview

**Singularity** is a minimal Fedora Atomic (rpm-ostree) image designed as a daily-driver laptop system with:

- **Hyprland** as the Wayland compositor
- **KVM/libvirt** for local virtualization
- Fingerprint authentication, brightness, Bluetooth, PipeWire audio
- No NVIDIA, no VFIO, no gaming stack, no user applications

Target hardware: AMD Ryzen 7 5800 with integrated AMD GPU only.

---

## Technical Base

### Base image: `ghcr.io/ublue-os/base-main:42`

[Universal Blue](https://universal-blue.org)'s minimal Fedora 42 Atomic base.

| Alternative considered | Why not chosen |
|---|---|
| `quay.io/fedora/fedora-bootc:42` | Excellent for pure bootc workflow; less tested with BlueBuild's rpm-ostree pipeline and has fewer built-in fixes |
| `ghcr.io/ublue-os/sway-atomic-main` | Pre-installs Sway — we want Hyprland from a clean base |
| `ghcr.io/ublue-os/silverblue-main` | Pre-installs GNOME — significant unnecessary bloat |
| Bazzite / Aurora | Opinionated consumer images (gaming/productivity stack) |

> **On Hyprland bases**: As of 2025 there is no official Universal Blue Hyprland image. Community forks exist but are inconsistently maintained. Building from `base-main` is the recommended path.

### ISO build: `jasonn3/build-container-installer@v1.4.0`

> `ublue-os/isogenerator` was **archived on April 22, 2024** and is no longer maintained. This repo uses `build-container-installer` as the current recommended replacement.

---

## File Structure

```
project-singularity/
├── .github/workflows/
│   ├── build-image.yml          # Build and push OCI image to GHCR
│   └── build-iso.yml            # Build bootable ISO from GHCR image
├── recipes/
│   └── laptop-hyprland.yml      # BlueBuild recipe (main build definition)
├── config/
│   └── laptop.toml              # Hardware/build configuration reference (not consumed by build)
├── files/
│   ├── scripts/
│   │   ├── setup-laptop.sh      # greetd permissions, polkit power/backlight rules
│   │   ├── setup-fingerprint.sh # authselect: PAM + fprintd
│   │   └── setup-kvm.sh         # polkit libvirt, udev KVM, default network autostart
│   └── system/etc/
│       ├── greetd/config.toml          # tuigreet → Hyprland session
│       ├── modprobe.d/kvm-amd.conf     # AMD nested virtualization
│       └── environment.d/10-hyprland.conf  # XDG_SESSION_TYPE=wayland
├── cosign.pub                   # Public key for image verification (replace with yours)
├── .gitignore
└── README.md
```

---

## Prerequisites

- A GitHub account
- GitHub Container Registry (GHCR) — enabled by default for all accounts
- `git` installed locally
- Optional: `cosign` for image signing

---

## Setup

### 1. Replace placeholders

Before pushing, replace every occurrence of `YOUR_GITHUB_USERNAME`:

| Placeholder | File | Replace with |
|---|---|---|
| `YOUR_GITHUB_USERNAME` | `.github/workflows/build-iso.yml` | Your GitHub username |

The image name `singularity` is set in `recipes/laptop-hyprland.yml` under `name:`.  
After a successful build it will be available at `ghcr.io/YOUR_GITHUB_USERNAME/singularity`.

### 2. Create the GitHub repository

```bash
# With GitHub CLI
gh repo create YOUR_GITHUB_USERNAME/project-singularity --public

# Or manually at https://github.com/new
# Repository name: project-singularity
# Visibility: Public (required for unauthenticated ISO pulls)
```

### 3. Generate signing keys (optional but recommended)

```bash
# Install cosign (Fedora)
sudo dnf install cosign

# Generate key pair in the repo root
cd project-singularity
cosign generate-key-pair
# Produces: cosign.key (private) and cosign.pub (public)
```

Commit `cosign.pub` (replace the placeholder), then add the private key to GitHub:

**Repository → Settings → Secrets and variables → Actions → New repository secret**
- Name: `COSIGN_KEY`
- Value: full contents of `cosign.key`

Then delete `cosign.key` from your machine or ensure it is in `.gitignore`.

> If you skip this step the build still succeeds — image signing is skipped.

### 4. Connect and push

```bash
cd project-singularity

git init
git add .
git commit -m "chore: initial singularity image setup"

git remote add origin https://github.com/YOUR_GITHUB_USERNAME/project-singularity.git
git branch -M main
git push -u origin main
```

### 5. Set GHCR package visibility (after first successful build)

After the first image build, a package named `singularity` will appear in your GitHub profile under **Packages**.

1. Open the package page → **Package settings**
2. Link it to the `project-singularity` repository
3. Set visibility to **Public** (required for the ISO build to pull without authentication)

---

## How the Workflows Work

### `build-image.yml`

**Triggers:** push to `main`, pull request to `main`, daily at 06:00 UTC, manual dispatch.

1. Checks out the repo
2. Runs BlueBuild with `recipes/laptop-hyprland.yml`
3. Builds the OCI image and pushes it to `ghcr.io/YOUR_GITHUB_USERNAME/singularity`
4. Signs the image with cosign (if `COSIGN_KEY` secret is set)

Tags applied: `latest`, `42` (Fedora version), `YYYYMMDD.N` (date stamp).

### `build-iso.yml`

**Triggers:** manual dispatch, or automatically after a successful `Build Image` run on `main`.

1. Authenticates to GHCR
2. Pulls `ghcr.io/YOUR_GITHUB_USERNAME/singularity:latest`
3. Runs `jasonn3/build-container-installer` to produce a bootable ISO
4. Uploads `singularity-N.iso` + SHA256 checksum as a GitHub Actions artifact

---

## Building the Image

### Manually

1. GitHub → **Actions** → **Build Image** → **Run workflow** → select `main` → **Run workflow**
2. The build takes roughly 15–25 minutes

### On push

Any push to `main` (excluding `.md` and `config/` changes) triggers a build automatically.

---

## Building the ISO

### Manually

1. GitHub → **Actions** → **Build ISO** → **Run workflow**
2. Optionally specify an image tag (default: `latest`)
3. **Run workflow**

Build time: 10–20 minutes.

### Find the ISO

After the job completes:

1. **Actions** → **Build ISO** → click the completed run
2. Scroll to **Artifacts** at the bottom of the page
3. Download `singularity-iso-N` (contains `.iso` + `-CHECKSUM`)

> Artifacts expire after **7 days**. Download and store the ISO externally if you need it longer. Adjust `retention-days` in `build-iso.yml` to change this.

---

## Writing the ISO to USB

```bash
# Identify your USB device — verify carefully
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Write (replace /dev/sdX — ALL DATA ON THE DEVICE WILL BE ERASED)
sudo dd if=singularity-N.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

> Double-check the device path before running `dd`. Writing to the wrong device destroys data.

---

## Testing the Live USB

1. Boot from USB — press F12, F10, or F2 (varies by laptop) during POST for the boot menu
2. Select the USB drive
3. Anaconda loads — choose **Try Singularity** or **Install to Hard Drive**
4. greetd starts tuigreet → select **Hyprland** → session launches

The live user is `liveuser` with no password.

---

## First Boot (after installation)

Anaconda guides you through keyboard, timezone, user creation, and partitioning.

### Required post-install steps

```bash
# Add your user to the libvirt and kvm groups for VM management
sudo usermod -aG libvirt,kvm $USER
# Log out and back in (or reboot) for group membership to take effect

# Verify the libvirt default network is active
sudo virsh net-list --all
# If it shows "inactive":
sudo virsh net-start default
sudo virsh net-autostart default
```

### Optional post-install steps

```bash
# Install Nerd Fonts for waybar icon glyphs (not in Fedora repos)
# Option 1: https://www.nerdfonts.com — download and install to ~/.local/share/fonts/
# Option 2: via a Flatpak font manager

# Set power profile
powerprofilesctl set balanced   # or: performance, power-saver
```

---

## Component Verification

### Hyprland

```bash
# Inside a Hyprland session
hyprctl version
hyprctl monitors

# XDG portal status
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-hyprland.service
```

### Fingerprint (ELAN ARM-M4, USB 04f3:0c00)

```bash
# Service status
systemctl status fprintd.service

# Verify sensor is detected
fprintd-list $USER

# Enroll fingerprint
fprintd-enroll

# Test verification
fprintd-verify
```

> Verify sensor support at [fprint.freedesktop.org/supported-devices.html](https://fprint.freedesktop.org/supported-devices.html).  
> ELAN USB sensors (04f3:*) are generally well-supported by the libfprint `elan` driver.

### Webcam (Luxvisions HP TrueVision HD, USB 30c9:0064)

```bash
# List video devices
v4l2-ctl --list-devices

# Device capabilities
v4l2-ctl --device=/dev/video0 --all

# Visual test (if mpv is available)
mpv /dev/video0
```

### Audio

```bash
# PipeWire and WirePlumber status
systemctl --user status pipewire.service wireplumber.service

# List sinks and sources
pactl list sinks short
pactl list sources short

# GUI volume control
pavucontrol
```

### Brightness

```bash
# List backlight devices
ls /sys/class/backlight/

# Adjust brightness
brightnessctl set +10%
brightnessctl set 10%-
brightnessctl set 50%
```

> If brightness requires sudo, add your user to the `video` group:
> `sudo usermod -aG video $USER`

### Bluetooth (Realtek RTL8761B, USB 0bda:b00c)

```bash
# Service status
systemctl status bluetooth.service

# Interactive control
bluetoothctl
# Inside bluetoothctl:
#   power on
#   scan on
#   pair <MAC>
#   connect <MAC>

# GUI manager
blueman-manager
```

### KVM / libvirt

```bash
# KVM module loaded
lsmod | grep kvm_amd

# libvirt socket active
systemctl status libvirtd.socket

# List VMs
virsh list --all

# Default network
virsh net-list --all

# VM manager GUI
virt-manager
```

### Hardware monitoring

```bash
# Interactive system monitor
btop

# AMD GPU usage
radeontop

# Power profile status
powerprofilesctl
```

---

## Placeholders to Customize

| Placeholder | File | What to set |
|---|---|---|
| `YOUR_GITHUB_USERNAME` | `.github/workflows/build-iso.yml` | Your GitHub username |

The image name (`singularity`) appears in `recipes/laptop-hyprland.yml` under `name:`. If you rename it, update `build-iso.yml` accordingly.

---

## Known Limitations

- **Fingerprint sensor**: Not all sensors are supported by libfprint. Verify `04f3:0c00` at the supported devices list before relying on fingerprint auth. If unsupported, `fprintd-enroll` will fail gracefully.
- **Nerd Fonts**: Not included (not in Fedora repos). Waybar icon glyphs will render as boxes until Nerd Fonts are installed manually.
- **greetd is TUI**: `tuigreet` is a text-based greeter. If you prefer a graphical login screen, layer SDDM after installation: `rpm-ostree install sddm`.
- **ISO artifact retention**: Expires in 7 days by default. Increase `retention-days` in `build-iso.yml` or download promptly.
- **Private GHCR image**: If the package visibility is Private, the ISO build workflow will fail to pull the image. Set the package to Public or add explicit credentials to the workflow.
- **AI assistant**: No local AI tool is included. `ollama` and similar tools can be installed separately but are not part of this system image.
- **User applications**: Browser, office suite, messaging apps — install as Flatpaks after first boot.
