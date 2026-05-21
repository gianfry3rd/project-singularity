#!/usr/bin/env bash
set -euo pipefail

# Polkit rule: allow users in the 'libvirt' group to manage VMs without password.
install -dm755 /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-libvirt.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.libvirt.") === 0 && subject.isInGroup("libvirt")) {
        return polkit.Result.YES;
    }
});
EOF

# udev rule: ensure /dev/kvm is accessible to the 'kvm' group.
# On Fedora this is typically already correct via qemu-kvm's udev rules,
# but we make it explicit for reliability.
install -dm755 /etc/udev/rules.d
cat > /etc/udev/rules.d/99-kvm.rules << 'EOF'
KERNEL=="kvm", GROUP="kvm", MODE="0660", TAG+="uaccess"
EOF

# Pre-configure the libvirt default NAT network for autostart.
# libvirt-daemon-config-network installs /etc/libvirt/qemu/networks/default.xml.
# Creating the autostart symlink here means the network starts on first libvirtd activation.
NETWORKS_DIR="/etc/libvirt/qemu/networks"
install -dm755 "${NETWORKS_DIR}/autostart"

if [[ -f "${NETWORKS_DIR}/default.xml" ]]; then
    ln -sf "${NETWORKS_DIR}/default.xml" \
        "${NETWORKS_DIR}/autostart/default.xml"
    echo "setup-kvm.sh: default NAT network enabled for autostart"
else
    echo "WARNING: ${NETWORKS_DIR}/default.xml not found — default network not pre-configured"
    echo "         Run 'virsh net-define /usr/share/libvirt/networks/default.xml' after first boot"
fi

echo "setup-kvm.sh: completed"
echo "NOTE: Add your user to libvirt and kvm groups after installation:"
echo "      sudo usermod -aG libvirt,kvm \$USER"
