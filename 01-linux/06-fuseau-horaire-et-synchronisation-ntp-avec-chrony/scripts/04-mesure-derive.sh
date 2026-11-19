#!/bin/bash
# 04 — dérive mesurée sans correction : chrony est arrêté, l'écart avec un
# serveur NTP est relevé toutes les 20 s pendant deux minutes.
set -uo pipefail

echo "=== Ce que chrony avait estimé ==="
chronyc tracking | grep -E "Reference ID|Stratum|System time|Frequency|Skew"

echo
echo "=== Sans NTP : la dérive se voit ==="
systemctl stop chrony
echo "chrony : $(systemctl is-active chrony)"
echo
echo "--- écart mesuré sur deux minutes ---"
python3 /root/projet/scripts/sntp-ecart.py --serie 7 --intervalle 20

echo
echo "=== Redémarrage de chrony ==="
systemctl start chrony
chronyc waitsync 30 0.01 || true
echo
chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset|Frequency|Skew"
