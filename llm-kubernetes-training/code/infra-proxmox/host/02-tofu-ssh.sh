#!/usr/bin/env bash
set -euo pipefail
apt-get install -y sudo
id tofu >/dev/null 2>&1 || useradd -m -s /bin/bash tofu
install -d -m 700 -o tofu -g tofu /home/tofu/.ssh
cat > /etc/sudoers.d/tofu <<'SUDO'
tofu ALL=(root) NOPASSWD: /usr/sbin/pvesm apiinfo
tofu ALL=(root) NOPASSWD: /usr/bin/tee /var/lib/vz/snippets/[a-zA-Z0-9_][a-zA-Z0-9_.-]*
SUDO
chmod 440 /etc/sudoers.d/tofu
visudo -cf /etc/sudoers.d/tofu
pvesm set local --content iso,vztmpl,backup,snippets
