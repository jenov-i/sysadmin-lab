#!/bin/bash
# 03 — configuration de chrony : sources du pool, correction de départ,
# écriture de la RTC, et vérification de la synchronisation.
set -euo pipefail

SAVE=/root/avant-chrony
install -d -m 700 "$SAVE"
[ -f /etc/chrony/chrony.conf ] && cp -a /etc/chrony/chrony.conf "$SAVE/chrony.conf.debian"
grep -n "pool\|server" /etc/chrony/chrony.conf | head -5 || true

install -m 644 /root/projet/configs/chrony.conf /etc/chrony/chrony.conf

echo
echo "--- configuration appliquée ---"
grep -v '^#\|^$' /etc/chrony/chrony.conf

echo
echo "=== Démarrage ==="
systemctl restart chrony
sleep 3
systemctl --no-pager --lines=0 status chrony | head -6

echo
echo "=== Attente de la synchronisation (30 s au plus) ==="
chronyc waitsync 30 0.01 || true
echo
echo "--- sources ---"
chronyc sources -v
echo
echo "--- état du suivi ---"
chronyc tracking
echo
echo "--- statistiques par source ---"
chronyc sourcestats
echo
echo "--- activité ---"
chronyc activity
echo
echo "--- vu par systemd ---"
timedatectl | sed -n '1,8p'
