#!/bin/bash
# 01 — état initial : fuseau, horloge matérielle, services de temps, puis
# installation de chrony.
set -uo pipefail
. /etc/os-release

echo "=== État initial ==="
date -Is
echo "UTC    : $(date -u +'%Y-%m-%d %H:%M:%S')"
echo
echo "-- fuseau horaire --"
timedatectl
cat /etc/timezone 2>/dev/null || echo "(pas de /etc/timezone)"
readlink -f /etc/localtime
echo
echo "-- horloge matérielle (RTC) --"
hwclock --show 2>&1
echo "RTC en heure locale : $(timedatectl show -p LocalRTC --value)"
echo
echo "-- paquets et services de temps --"
dpkg-query -W -f='${Package} ${Version}\n' chrony systemd-timesyncd tzdata 2>/dev/null
echo "systemd-timesyncd : $(systemctl is-active systemd-timesyncd 2>&1)"
echo "chrony            : $(systemctl is-active chrony 2>&1)"
ls /etc/chrony 2>/dev/null || echo "/etc/chrony absent"

echo
echo "=== Installation de chrony ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends chrony tzdata
echo
chronyd -v
echo
dpkg-query -W -f='${Package} ${Version}\n' chrony systemd-timesyncd tzdata 2>/dev/null
echo "systemd-timesyncd : $(systemctl is-active systemd-timesyncd 2>&1)"
echo "chrony            : $(systemctl is-enabled chrony) / $(systemctl is-active chrony)"
