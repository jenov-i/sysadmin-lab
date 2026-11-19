#!/bin/bash
# Résumé compact pour la capture console : installation, service, fichiers.
set -uo pipefail
. /etc/os-release

echo "srv-time — installation et état du service"
echo "système : $PRETTY_NAME — noyau $(uname -r)"
echo
echo "chrony    : $(dpkg-query -W -f='${Version}' chrony 2>/dev/null) · \
$(systemctl is-enabled chrony)/$(systemctl is-active chrony)"
echo "timesyncd : $(dpkg-query -W -f='${Status}' systemd-timesyncd 2>/dev/null \
  | grep -q 'install ok installed' && echo 'installé' || echo 'retiré') \
· $(systemctl is-active systemd-timesyncd 2>&1)"
echo
echo "fuseau : $(timedatectl show -p Timezone --value) · RTC en UTC : \
$( [ "$(timedatectl show -p LocalRTC --value)" = "no" ] && echo oui || echo non)"
echo "heure  : $(date +'%Y-%m-%d %H:%M:%S %Z') (UTC $(date -u +%H:%M:%S))"
echo "epoch  : $(date +%s)"
echo
echo "--- horloge matérielle ---"
hwclock --show 2>&1
echo
echo "--- fichiers ---"
[ -e /etc/timezone ] && ls -l /etc/timezone \
  || echo "/etc/timezone     : absent (Debian 13 ne l'écrit plus)"
ls -l /etc/localtime /etc/chrony/chrony.conf
