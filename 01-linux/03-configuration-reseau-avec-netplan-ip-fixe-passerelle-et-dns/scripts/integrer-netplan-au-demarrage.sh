#!/bin/bash
# Rend netplan effectif au démarrage sur Debian et retire ifupdown du chemin.
set -euo pipefail

echo "== 1. Unité de génération au démarrage =="
install -m 644 /root/netplan-generate.service /etc/systemd/system/netplan-generate.service
systemctl daemon-reload
systemctl enable netplan-generate.service
systemctl status netplan-generate.service --no-pager | head -4 || true

echo
echo "== 2. /etc/network/interfaces ne doit plus toucher ens3 =="
cp -a /etc/network/interfaces /etc/network/interfaces.avant-netplan
cat > /etc/network/interfaces <<'CONF'
# Géré par netplan : /etc/netplan/01-lab.yaml
# Seule la boucle locale reste ici, pour éviter que ifupdown et
# systemd-networkd ne se disputent ens3 (règle allow-hotplug + udev).
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
CONF
cat /etc/network/interfaces

echo
echo "== 3. Régénération et redémarrage du réseau =="
/usr/sbin/netplan generate
ls -l /run/systemd/network/
systemctl restart systemd-networkd
sleep 3
ip -4 -br addr
