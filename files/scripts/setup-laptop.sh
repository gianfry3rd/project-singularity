#!/usr/bin/env bash
set -euo pipefail

# Fix greetd config ownership.
# greetd requires /etc/greetd/config.toml to be owned by root:greeter and not world-readable.
# The greeter user is created by the greetd RPM; this runs after package install.
if getent group greeter &>/dev/null; then
    chown root:greeter /etc/greetd/config.toml
    chmod 640 /etc/greetd/config.toml
else
    echo "WARNING: 'greeter' group not found; greetd config permissions not set"
fi

# Polkit rule: allow wheel group members to perform power actions without password prompt.
cat > /etc/polkit-1/rules.d/10-power-management.rules << 'EOF'
polkit.addRule(function(action, subject) {
    var powerActions = [
        "org.freedesktop.login1.power-off",
        "org.freedesktop.login1.power-off-multiple-sessions",
        "org.freedesktop.login1.reboot",
        "org.freedesktop.login1.reboot-multiple-sessions",
        "org.freedesktop.login1.suspend",
        "org.freedesktop.login1.suspend-multiple-sessions",
        "org.freedesktop.login1.hibernate",
        "org.freedesktop.login1.hibernate-multiple-sessions"
    ];
    if (powerActions.indexOf(action.id) !== -1 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# Polkit rule: allow wheel group members to change power profile without password.
cat > /etc/polkit-1/rules.d/11-power-profiles.rules << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "net.hadess.PowerProfiles.switch-profile" &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

echo "setup-laptop.sh: completed"
