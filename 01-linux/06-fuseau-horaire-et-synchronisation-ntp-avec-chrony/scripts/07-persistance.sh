#!/bin/bash
# 07 — après redémarrage : fuseau, RTC, chrony et dérive enregistrée.
set -uo pipefail

echo "=== Après redémarrage ==="
echo "démarrage : $(uptime -s)   ·   maintenant : $(date -Is)"
echo
timedatectl
echo
echo "-- RTC --"
hwclock --show 2>&1
echo "RTC en heure locale : $(timedatectl show -p LocalRTC --value)"
echo
echo "-- chrony --"
echo "service : $(systemctl is-enabled chrony) / $(systemctl is-active chrony)"
chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset|Frequency|Skew"
echo
chronyc sources
echo
echo "-- dérive enregistrée au dernier arrêt --"
cat /var/lib/chrony/chrony.drift 2>/dev/null || echo "(pas encore de fichier)"
echo
echo "-- écart mesuré maintenant --"
python3 /root/projet/scripts/sntp-ecart.py
