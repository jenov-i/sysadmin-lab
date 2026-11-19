#!/bin/bash
# Mesure longue (huit minutes) : chrony arrêté, écart relevé toutes les 40 s,
# puis filtre sur l'aller-retour et sur l'écart à la droite.
# Script destiné à la capture console : il dure huit minutes.
set -uo pipefail

S=/root/projet/scripts/sntp-ecart.py

echo "Dérive mesurée sans correction — chrony arrêté pendant 8 min"
echo "chrony : $(chronyc tracking | grep Frequency | sed 's/.*: //') · \
sources $(chronyc -n sources | awk 'NR>3 {print $2}' | paste -sd' ' -)"
echo
systemctl stop chrony
python3 "$S" --serie 12 --intervalle 40
echo
systemctl start chrony
chronyc waitsync 60 0.05 >/dev/null 2>&1
echo "chrony redémarré : $(systemctl is-active chrony) — \
$(chronyc tracking | grep Frequency | sed 's/.*: //')"
