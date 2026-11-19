#!/bin/bash
# Résumé compact pour la capture console : après redémarrage.
set -uo pipefail

echo "srv-time — après redémarrage"
echo "démarrage : $(uptime -s)   ·   maintenant : $(date +%H:%M:%S)"
echo "fuseau    : $(timedatectl show -p Timezone --value) · RTC en UTC : \
$( [ "$(timedatectl show -p LocalRTC --value)" = "no" ] && echo oui || echo non)"
echo "chrony    : $(systemctl is-enabled chrony) / $(systemctl is-active chrony)"
echo
echo "--- écart avec le serveur, à l'instant ---"
python3 /root/projet/scripts/sntp-ecart.py --meilleur 5 --intervalle 3
echo
echo "--- suivi chrony ---"
chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset|Frequency|Skew"
echo
echo "--- sources ---"
chronyc -n sources | sed -n '1,4p'
echo
echo "--- dérive enregistrée ---"
cat /var/lib/chrony/chrony.drift 2>/dev/null
echo
hwclock --show 2>&1
