#!/bin/bash
# 01b — nom d'hôte : le preseed n'a pas été appliqué (voir README, incidents).
set -euo pipefail

echo "=== Avant ==="
hostname
hostnamectl --static
grep -n . /etc/hosts

echo
echo "=== Correction ==="
hostnamectl set-hostname srv-web
cat > /etc/hosts <<'EOF'
127.0.0.1	localhost
10.0.3.10	srv-web.lab.local srv-web

::1	localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
EOF
systemctl restart systemd-hostnamed 2>/dev/null || true

echo
echo "=== Après ==="
hostname
hostnamectl --static
hostname -f
hostname -I
grep -n . /etc/hosts
