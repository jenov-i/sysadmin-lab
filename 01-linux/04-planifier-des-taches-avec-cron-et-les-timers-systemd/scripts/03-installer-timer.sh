#!/bin/bash
# Mise en place du timer systemd. On active volontairement avant tout
# daemon-reload explicite, pour voir si systemd 257 connaît déjà l'unité.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Dépôt des unités =="
install -m 755 /root/lab-nettoyage.sh /usr/local/bin/lab-nettoyage.sh
install -m 644 /root/lab-nettoyage.service /etc/systemd/system/lab-nettoyage.service
install -m 644 /root/lab-nettoyage.timer   /etc/systemd/system/lab-nettoyage.timer
ls -l /etc/systemd/system/lab-nettoyage.*

echo
echo "== 2. Activation demandée avant daemon-reload =="
if systemctl enable --now lab-nettoyage.timer; then
  echo "-> activé du premier coup : systemd 257 recharge les unités à la demande"
else
  echo "-> refusé : un daemon-reload explicite est nécessaire"
fi

echo
echo "== 3. daemon-reload explicite, puis vérification =="
systemctl daemon-reload
systemctl enable --now lab-nettoyage.timer
systemctl list-timers 'lab-*' --no-pager

echo
echo "== 4. Attente d'un déclenchement (75 s) =="
sleep 75
systemctl list-timers 'lab-*' --no-pager

echo
echo "== 5. Ce que le service a écrit dans le journal =="
journalctl -u lab-nettoyage.service --no-pager | tail -6
