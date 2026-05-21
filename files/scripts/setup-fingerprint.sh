#!/usr/bin/env bash
set -euo pipefail

# Configure PAM via authselect to enable fingerprint authentication.
# Hardware: ELAN ARM-M4 (USB 04f3:0c00) — supported by libfprint elan driver.
# authselect is the Fedora-standard PAM management tool.

if ! command -v authselect &>/dev/null; then
    echo "WARNING: authselect not found — skipping PAM fingerprint configuration"
    exit 0
fi

authselect select sssd with-fingerprint with-silent-lastlog --force

echo "setup-fingerprint.sh: PAM configured with fingerprint support"
echo "NOTE: Run 'fprintd-enroll' after first login to register your fingerprint."
