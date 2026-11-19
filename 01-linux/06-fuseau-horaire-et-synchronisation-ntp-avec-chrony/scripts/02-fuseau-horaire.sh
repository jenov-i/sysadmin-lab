#!/bin/bash
# 02 — fuseau horaire : changer la zone sans toucher à l'heure UTC, puis
# replacer la RTC en UTC.
set -uo pipefail

etat() {
  printf "%-22s | %s | %s | %s\n" "$1" \
    "$(date +'%Y-%m-%d %H:%M:%S %Z')" "$(date -u +'%H:%M:%S')" "$(date +%s)"
}

echo "le format : zone | heure locale | heure UTC | epoch"
echo
etat "départ"
timedatectl set-timezone Africa/Brazzaville
etat "Africa/Brazzaville"
timedatectl set-timezone Asia/Tokyo
etat "Asia/Tokyo"
timedatectl set-timezone Africa/Brazzaville
etat "retour Brazzaville"

echo
echo "-- ce qui a changé sur le disque --"
readlink -f /etc/localtime
cat /etc/timezone
echo
echo "fuseaux disponibles : $(timedatectl list-timezones | wc -l)"
echo
echo "-- RTC en UTC (recommandé pour un serveur) --"
timedatectl set-local-rtc 0
timedatectl show -p LocalRTC -p Timezone -p NTPSynchronized
echo
hwclock --show
echo
timedatectl
