#!/bin/bash
# Résumé compact pour la capture console : décalage de 5 s puis correction.
set -uo pipefail

S=/root/projet/scripts/sntp-ecart.py

echo "Correction d'un décalage de 5 s par chrony"
echo
echo "--- avant ---"
python3 "$S"
echo "chrony : $(chronyc tracking | grep 'System time' | sed 's/.*: //')"
echo
systemctl stop chrony
date -s "+5 seconds" >/dev/null
echo "décalage appliqué : $(date +'%H:%M:%S') (5 s d'avance)"
python3 "$S"
echo
echo "--- chrony redémarré ---"
systemctl start chrony
chronyc waitsync 30 0.01 >/dev/null 2>&1 || true
sleep 6
chronyc makestep >/dev/null 2>&1 || true
sleep 2
python3 "$S"
echo
chronyc tracking | grep -E "System time|Last offset|Frequency"
echo "RTC              : $(hwclock --show | cut -d. -f1) · LocalRTC=no"
echo "timedatectl      : $(timedatectl show -p NTPSynchronized --value) (mis à jour après ~1 min)"
