#!/bin/bash
# 01 — état initial, adresse fixe, installation de nginx et openssl.
set -euo pipefail

echo "=== Etat initial ==="
date -Is
. /etc/os-release
echo "${PRETTY_NAME} — noyau $(uname -r)"
echo
ip -brief address
echo
echo "-- paquets déjà présents --"
dpkg-query -W -f='${Package} ${Version}\n' nginx nginx-common openssl 2>/dev/null \
  || echo "nginx absent"
echo
echo "-- service nginx --"
systemctl is-enabled nginx 2>&1 || true
systemctl is-active nginx 2>&1 || true

echo
echo "=== Adresse fixe 10.0.3.10 sur ens4 ==="
cat > /etc/network/interfaces.d/ens4 <<'EOF'
auto ens4
iface ens4 inet static
    address 10.0.3.10/24
EOF
ifdown ens4 2>/dev/null || true
ifup ens4
ip -brief address show ens4

echo
echo "=== Installation ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends nginx openssl
echo
nginx -v 2>&1
openssl version
echo
systemctl is-enabled nginx
systemctl is-active nginx
echo
echo "-- version exacte --"
dpkg-query -W -f='${Package} ${Version}\n' nginx nginx-common openssl
