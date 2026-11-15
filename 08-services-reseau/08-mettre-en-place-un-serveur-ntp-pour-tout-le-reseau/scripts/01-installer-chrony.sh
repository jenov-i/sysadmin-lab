#!/bin/bash
# Installation de chrony et remplacement de systemd-timesyncd.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get install -y chrony 2>&1 | tail -8

echo
echo "== systemd-timesyncd désactivé au profit de chrony =="
systemctl disable --now systemd-timesyncd 2>&1 | tail -2
systemctl enable --now chrony
sleep 2
echo "chrony             : $(systemctl is-active chrony)"
echo "systemd-timesyncd  : $(systemctl is-active systemd-timesyncd)"
chronyd -v
