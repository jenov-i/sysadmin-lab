#!/bin/bash
# Après un second redémarrage : quels marqueurs ont survécu, et où le journal
# courant est-il réellement stocké ?
# Exécuté sur srv-debian13 le 15/11/2026 après reboot.
set -euo pipefail

cherche() {  # cherche <tag> <boot>
  if journalctl -b "$2" -t lab-journal -g "$1" -o cat --no-pager | grep -q "$1"; then
    echo "  $1 (boot $2) : présent"
  else
    echo "  $1 (boot $2) : absent"
  fi
}

echo "== 1. Démarrages conservés =="
journalctl --list-boots --no-pager | tail -4

echo
echo "== 2. Configuration et emplacement du journal courant =="
grep -n '^#\?Storage' /etc/systemd/journald.conf
journalctl --header | grep 'File path' | sed -n '1,2p'
if [ -d /run/log/journal ]; then
  echo "/run/log/journal existe encore : $(find /run/log/journal -name '*.journal' | wc -l) fichier(s)"
else
  echo "/run/log/journal absent (mémoire volatile vidée au redémarrage)"
fi

echo
echo "== 3. Marqueurs écrits avant le premier redémarrage (boot -2) =="
cherche MARQUEUR-PERSISTANT -2
cherche MARQUEUR-VOLATIL -2
cherche MARQUEUR-APRES-RETOUR -2

echo
echo "== 4. Marqueurs écrits pendant le cycle contrôlé (boot -1) =="
cherche MARQUEUR-VOLATIL-2 -1
cherche MARQUEUR-RETOUR-2 -1

echo
echo "== 5. Preuve que le journal est de nouveau persistant =="
logger -p local0.notice -t lab-journal "MARQUEUR-APRES-REBOOT journal persistant confirme"
sleep 1
journalctl -b 0 -t lab-journal -g MARQUEUR-APRES-REBOOT -o cat --no-pager
journalctl --header | grep 'File path' | sed -n '1,2p'
journalctl --disk-usage
