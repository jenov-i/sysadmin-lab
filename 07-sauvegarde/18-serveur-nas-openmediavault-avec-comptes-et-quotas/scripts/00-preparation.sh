#!/bin/bash
# Préparation du NAS : nom d'hôte, résolution locale, disque de données.
set -euo pipefail

echo "=== nom d'hôte ==="
hostnamectl set-hostname nas-omv8
if grep -q '^127.0.1.1' /etc/hosts; then
    sed -i 's/^127\.0\.1\.1.*/127.0.1.1 nas-omv8/' /etc/hosts
else
    echo '127.0.1.1 nas-omv8' >> /etc/hosts
fi
hostname
getent hosts nas-omv8

echo "=== prérequis OpenMediaVault ==="
systemctl is-active systemd-resolved
systemctl is-active systemd-timesyncd || true
dpkg -l | grep -cE '^ii[[:space:]]+(apache2|nginx)[[:space:]]' | sed 's/^/serveur web déjà installé : /' || true

echo "=== /etc/hosts ==="
cat /etc/hosts

echo "=== disques ==="
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
df -h /

echo "=== partition de données /dev/vdb ==="
sfdisk /dev/vdb <<'PART'
label: gpt
,,L
PART
udevadm settle
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT /dev/vdb
