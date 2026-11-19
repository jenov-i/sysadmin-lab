#!/bin/bash
# Résumé compact pour la capture console : le fuseau horaire.
set -uo pipefail

ligne() {
  printf "%-22s %-21s %-9s %s\n" "$1" "$(date +'%Y-%m-%d %H:%M:%S')" \
    "$(date -u +%H:%M:%S)" "$(date +%s)"
}

echo "Changer de fuseau ne change pas l'instant"
echo
printf "%-22s %-21s %-9s %s\n" "zone" "heure locale" "UTC" "epoch"
ligne "départ"
timedatectl set-timezone Asia/Tokyo
ligne "Asia/Tokyo"
timedatectl set-timezone Africa/Brazzaville
ligne "Africa/Brazzaville"
echo
echo "/etc/localtime -> $(readlink -f /etc/localtime)"
echo "/etc/timezone  : $( [ -e /etc/timezone ] && cat /etc/timezone \
  || echo 'absent (Debian 13 ne l’écrit plus)' )"
echo "zones connues  : $(timedatectl list-timezones | wc -l)"
echo
echo "--- RTC ---"
echo "LocalRTC : $(timedatectl show -p LocalRTC --value)"
hwclock --show 2>&1
echo
timedatectl | sed -n '1,7p'
