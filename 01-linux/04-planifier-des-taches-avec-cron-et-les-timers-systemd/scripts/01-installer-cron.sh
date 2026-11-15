#!/bin/bash
# Première tentative : dépôt de la tâche cron telle qu'on l'écrit naturellement,
# c'est-à-dire sans saut de ligne final. On regarde ce qui se passe vraiment.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Script de sauvegarde et tâche cron =="
install -m 755 /root/sauvegarde-etc.sh /usr/local/bin/sauvegarde-etc.sh
ls -l /usr/local/bin/sauvegarde-etc.sh
printf '%s' "$(cat /root/cron-lab-sauvegarde)" > /etc/cron.d/lab-sauvegarde
chmod 644 /etc/cron.d/lab-sauvegarde
echo
echo "--- fichier déposé (les 40 derniers octets, en clair) ---"
tail -c 40 /etc/cron.d/lab-sauvegarde | od -c | head -4
systemctl reload cron 2>/dev/null || systemctl restart cron
systemctl is-active cron

echo
echo "== 2. Attente d'une exécution (75 s) =="
sleep 75

echo
echo "== 3. Journal de la sauvegarde =="
if [ -s /var/log/lab-sauvegarde.log ]; then
  cat /var/log/lab-sauvegarde.log
else
  echo "aucune ligne : la tâche n'a pas tourné"
fi

echo
echo "== 4. Ce que cron a réellement journalisé =="
journalctl -u cron --since "-3 min" --no-pager | tail -8
