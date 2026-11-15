#!/bin/bash
# Retrait de « local stratum 10 », redémarrage et vérification de la vraie
# synchronisation amont.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Configuration corrigée =="
install -m 644 /root/chrony.conf /etc/chrony/chrony.conf
grep -vE '^\s*(#|$)' /etc/chrony/chrony.conf

echo
echo "== 2. Redémarrage, puis 20 s de convergence =="
systemctl restart chrony
sleep 20
systemctl is-active chrony
chronyc tracking

echo
echo "== 3. Sources amont réellement utilisées =="
chronyc sources | sed -n '1,6p'

echo
echo "== 4. Le serveur a bien reçu des paquets NTP de l'amont =="
chronyc serverstats | sed -n '1,4p'
ss -lunp | grep ':123'
