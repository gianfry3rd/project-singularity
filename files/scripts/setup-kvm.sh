#!/usr/bin/env bash
set -euo pipefail

# Enable the libvirt default NAT network for autostart.
# libvirt-daemon-config-network provides /etc/libvirt/qemu/networks/default.xml.
# The autostart symlink makes the network start automatically on first libvirtd activation.

NETWORKS_DIR="/etc/libvirt/qemu/networks"
install -dm755 "${NETWORKS_DIR}/autostart"

if [[ -f "${NETWORKS_DIR}/default.xml" ]]; then
    ln -sf "${NETWORKS_DIR}/default.xml" "${NETWORKS_DIR}/autostart/default.xml"
    echo "setup-kvm.sh: default NAT network enabled for autostart"
else
    echo "WARNING: ${NETWORKS_DIR}/default.xml not found — run 'virsh net-autostart default' after first boot"
fi

echo "setup-kvm.sh: completed"
echo "NOTE: Add your user to libvirt and kvm groups after installation:"
echo "      sudo usermod -aG libvirt,kvm \$USER"
