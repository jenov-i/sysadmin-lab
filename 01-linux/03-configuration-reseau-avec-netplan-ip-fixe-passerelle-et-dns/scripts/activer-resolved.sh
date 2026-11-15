#!/bin/bash
# Sans systemd-resolved, netplan n'écrit pas /etc/resolv.conf : les résolveurs
# déclarés dans 01-lab.yaml ne sont jamais utilisés. Ce script active resolved
# et rebascule /etc/resolv.conf sur le stub local.
set -euo pipefail

echo "== 1. État avant =="
grep -v '^#' /etc/resolv.conf | sed '/^$/d'
ls -l /etc/resolv.conf

echo
echo "== 2. Installation de systemd-resolved =="
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd-resolved >/dev/null
systemctl enable --now systemd-resolved
sleep 2

echo
echo "== 3. Bascule de /etc/resolv.conf =="
cp -a /etc/resolv.conf /etc/resolv.conf.avant-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
ls -l /etc/resolv.conf

echo
echo "== 4. Résolveurs réellement utilisés =="
resolvectl dns
echo
resolvectl status ens4 | sed -n '1,12p'
