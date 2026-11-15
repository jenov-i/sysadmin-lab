#!/bin/bash
# Applique la configuration netplan de srv-debian13 et vérifie l'adressage.
# Exécuté sur la VM le 15/11/2026.
set -euo pipefail

echo "== 1. Dépôt du fichier de configuration =="
install -m 600 /root/01-lab.yaml /etc/netplan/01-lab.yaml
chmod 600 /etc/netplan/01-lab.yaml
cat /etc/netplan/01-lab.yaml | head -5
echo "..."

echo
echo "== 2. Validation =="
netplan generate
echo "netplan generate : OK"

echo
echo "== 3. Bascule de ifupdown vers systemd-networkd =="
systemctl enable systemd-networkd
systemctl disable networking

echo
echo "== 4. Application =="
netplan apply
sleep 3

echo
echo "== 5. État obtenu =="
ip -4 -br addr
echo
ip route
echo
ss -tlnp | grep sshd
