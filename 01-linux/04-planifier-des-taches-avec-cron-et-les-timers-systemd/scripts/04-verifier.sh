#!/bin/bash
# État final : les deux planifications tournent, et on compare leurs traces.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Les deux planifications sont actives =="
echo "cron               : $(systemctl is-active cron)"
echo "lab-nettoyage.timer: $(systemctl is-active lab-nettoyage.timer)"
systemctl list-timers 'lab-*' --no-pager

echo
echo "== 2. Fichiers de planification réellement en place =="
cat /etc/cron.d/lab-sauvegarde
systemctl cat lab-nettoyage.timer | grep -E 'OnCalendar|Persistent|Unit='

echo
echo "== 3. Résultat côté cron =="
cat /var/log/lab-sauvegarde.log

echo
echo "== 4. Résultat côté systemd =="
journalctl -u lab-nettoyage.service --no-pager | tail -5

echo
echo "== 5. Les deux mécanismes ont tourné à la même minute =="
echo "cron    : $(tail -1 /var/log/lab-sauvegarde.log | cut -d' ' -f1-2)"
echo "systemd : $(journalctl -u lab-nettoyage.service -o cat -g 'nettoyage :' --no-pager | tail -1 | cut -d' ' -f1-2)"
