#!/usr/bin/env bash
set -euo pipefail

# Fix greetd config ownership.
# greetd requires config readable only by root and greeter group.
if getent group greeter &>/dev/null; then
    chown root:greeter /etc/greetd/config.toml
    chmod 640 /etc/greetd/config.toml
else
    echo "WARNING: 'greeter' group not found; greetd config permissions not set"
fi

echo "setup-laptop.sh: completed"
