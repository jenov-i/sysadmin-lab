#!/bin/bash
# 05 — la mesure courte (04) est dominée par le bruit du réseau : on refait le
# même relevé sur huit minutes, avec un filtre sur l'aller-retour, et on compare
# le résultat à l'estimation de chrony.
set -uo pipefail

S=/root/projet/scripts/sntp-ecart.py

echo "=== Estimation de chrony avant l'arrêt ==="
chronyc tracking | grep -E "Reference ID|Stratum|Frequency|Skew"

echo
echo "=== chrony arrêté pendant huit minutes ==="
systemctl stop chrony
echo "chrony : $(systemctl is-active chrony)"
echo "départ : $(date -Is)"
echo
python3 "$S" --serie 16 --intervalle 30

echo
echo "=== Redémarrage de chrony ==="
systemctl start chrony
chronyc waitsync 60 0.05 >/dev/null || true
echo
chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset|Frequency|Skew"
echo
echo "écart à l'instant : $(python3 "$S")"
