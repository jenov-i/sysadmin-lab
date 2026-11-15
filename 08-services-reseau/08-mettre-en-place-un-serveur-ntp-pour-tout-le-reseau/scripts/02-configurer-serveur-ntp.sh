#!/bin/bash
# Configuration du serveur NTP du lab et vérification côté serveur.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Configuration en place =="
install -m 644 /root/chrony.conf /etc/chrony/chrony.conf
grep -vE '^\s*(#|$)' /etc/chrony/chrony.conf

echo
echo "== 2. Redémarrage et écoute =="
systemctl restart chrony
sleep 3
systemctl is-active chrony
ss -lunp | grep ':123' || echo "aucun socket UDP 123"

echo
echo "== 3. Synchronisation avec l'amont =="
chronyc tracking
echo
chronyc sources -v | sed -n '1,8p'

echo
echo "== 4. Réglages de service =="
chronyc serverstats | sed -n '1,6p'
