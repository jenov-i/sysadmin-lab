#!/bin/bash
# Vérification du schéma de partitionnement — exécuté sur srv-debian13 après installation.
# Sortie non nulle si un point de contrôle échoue.
set -u

fail=0
check() { # check "libellé" condition
  if eval "$2"; then
    printf '  [ OK ] %s\n' "$1"
  else
    printf '  [FAIL] %s\n' "$1"
    fail=1
  fi
}

echo "== Disque et partitions =="
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS

echo
echo "== Points de contrôle =="
check "/boot monté en ext4" "mountpoint -q /boot && [ \"\$(findmnt -no FSTYPE /boot)\" = ext4 ]"
check "/ = volume logique ext4" "[ \"\$(findmnt -no FSTYPE /)\" = ext4 ] && [[ \$(findmnt -no SOURCE /) == /dev/mapper/debian--vg-root ]]"
check "/var séparé" "mountpoint -q /var"
check "/home séparé" "mountpoint -q /home"
check "/tmp séparé" "mountpoint -q /tmp"
check "swap actif sur volume logique" "[ \"\$(swapon --show=NAME --noheadings)\" = /dev/dm-0 ]"
check "groupe de volumes debian-vg présent" "vgs --noheadings -o vg_name | grep -q debian-vg"
check "5 volumes logiques" "[ \"\$(lvs --noheadings | wc -l)\" -eq 5 ]"
check "rotation des logs active sur /var" "grep -q ' /var ' /etc/fstab"

echo
if [ "$fail" -eq 0 ]; then
  echo "Résultat : 9/9 points de contrôle validés."
else
  echo "Résultat : au moins un point de contrôle en échec."
fi
exit "$fail"
