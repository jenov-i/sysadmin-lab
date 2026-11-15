#!/bin/bash
# Corrige la tâche cron (saut de ligne final) et montre la différence.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Ajout du saut de ligne final =="
printf '\n' >> /etc/cron.d/lab-sauvegarde
tail -c 40 /etc/cron.d/lab-sauvegarde | od -c | head -4
systemctl reload cron 2>/dev/null || systemctl restart cron

echo
echo "== 2. Attente de deux exécutions (130 s) =="
sleep 130

echo
echo "== 3. Journal de la sauvegarde =="
cat /var/log/lab-sauvegarde.log

echo
echo "== 4. Traces laissées par cron =="
journalctl -u cron --since "-5 min" --no-pager | tail -6

echo
echo "== 5. Archives réellement produites =="
ls -lh /var/backups/lab/
