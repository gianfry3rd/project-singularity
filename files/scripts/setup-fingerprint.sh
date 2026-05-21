#!/usr/bin/env bash
set -euo pipefail

# Configure PAM via authselect to enable fingerprint authentication.
#
# Hardware: ELAN Microelectronics ELAN:ARM-M4 (USB ID 04f3:0c00)
# Driver:   libfprint elan USB driver (included in fprintd package)
#
# authselect is the Fedora-standard tool for managing PAM configuration.
# Profile 'sssd' is the Fedora default; 'with-fingerprint' adds fprintd to PAM.
# '--force' overwrites any existing PAM config without prompting.

if ! command -v authselect &>/dev/null; then
    echo "WARNING: authselect not found — skipping PAM fingerprint configuration"
    exit 0
fi

authselect select sssd with-fingerprint with-silent-lastlog --force

echo "setup-fingerprint.sh: PAM configured with fingerprint support (sssd + with-fingerprint)"
echo "NOTE: Run 'fprintd-enroll' after first login to register your fingerprint."
