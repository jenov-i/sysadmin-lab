#!/bin/bash
# Installation d'OpenMediaVault 8 (dépôt officiel « synchrony », base Debian 13).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LANG=C.UTF-8
export APT_LISTCHANGES_FRONTEND=none

echo "=== dépôt OpenMediaVault ==="
apt-get update
apt-get install -y --no-install-recommends gnupg curl ca-certificates

curl -fsSL https://packages.openmediavault.org/public/archive.key \
    | gpg --dearmor --yes -o /usr/share/keyrings/openmediavault-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/openmediavault-archive-keyring.gpg] https://packages.openmediavault.org/public synchrony main" \
    > /etc/apt/sources.list.d/openmediavault.list
apt-get update
apt-cache policy openmediavault | sed -n '1,6p'

echo "=== installation (postfix sans configuration interactive) ==="
echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections
echo "postfix postfix/mailname string nas-omv8.lab.local" | debconf-set-selections
apt-get install -y --no-install-recommends \
    --allow-downgrades --allow-change-held-packages \
    -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    openmediavault

echo "=== état après installation ==="
dpkg -l openmediavault | tail -1
systemctl is-enabled openmediavault-engined
systemctl is-active nginx
systemctl is-active smbd 2>/dev/null || true
ss -ltnp | grep -E ':80 |:443 |:445 ' || true
df -h / /var
