#!/bin/bash
# 01b — nom d'hôte : le preseed n'est pas appliqué (voir README, incidents).
set -euo pipefail

echo "=== Avant ==="
hostname
grep -n . /etc/hosts

echo
echo "=== Correction ==="
hostnamectl set-hostname srv-time
cat > /etc/hosts <<'EOF'
127.0.0.1	localhost
127.0.1.1	srv-time.lab.local srv-time

::1	localhost ip6-localhost ip6-loopback
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
EOF
systemctl restart systemd-hostnamed 2>/dev/null || true

echo
echo "=== Après ==="
hostname
hostname -f
hostname -I
grep -n . /etc/hosts
