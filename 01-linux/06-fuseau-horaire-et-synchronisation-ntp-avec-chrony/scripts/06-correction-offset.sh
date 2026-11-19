#!/bin/bash
# 06 — on décale volontairement l'horloge de 5 s et on regarde chrony la
# remettre en place, avec les mesures avant, pendant et après.
set -uo pipefail

S=/root/projet/scripts/sntp-ecart.py

echo "=== Avant ==="
python3 "$S"
chronyc tracking | grep -E "System time|Last offset|Frequency"

echo
echo "=== Décalage volontaire de +5 s, chrony arrêté ==="
systemctl stop chrony
date -s "+5 seconds"
date +'%Y-%m-%d %H:%M:%S %Z'
echo
echo "--- écart réellement constaté ---"
python3 "$S"

echo
echo "=== Redémarrage de chrony : makestep doit corriger d'un coup ==="
systemctl start chrony
chronyc waitsync 30 0.01 || true
sleep 7
chronyc makestep || true
echo
echo "--- écart après correction ---"
for i in $(seq 1 10); do
  ligne=$(python3 "$S")
  echo "  $ligne"
  ms=$(echo "$ligne" | sed -n 's/.*écart \([-+][0-9.]*\) ms.*/\1/p')
  ok=$(awk -v v="${ms:-99}" 'BEGIN { v = (v < 0 ? -v : v); print (v < 5) ? 1 : 0 }')
  [ "$ok" = "1" ] && break
  sleep 2
done

echo
echo "--- état final ---"
chronyc tracking
echo
chronyc activity
echo
echo "--- ce que dit systemd ---"
timedatectl | sed -n '1,8p'
