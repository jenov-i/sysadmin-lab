#!/bin/bash
# Après chaque démarrage, nginx et smbd restaient inactifs : le boot attendait
# indéfiniment systemd-networkd-wait-online, alors que le réseau est géré par
# ifupdown (systemd-networkd ne gère aucun lien). Correctif : désactiver
# l'attente de networkd, activer celle d'ifupdown.
set -euo pipefail

echo "=== constat ==="
systemctl show systemd-networkd-wait-online -p TimeoutStartUSec
networkctl list
systemctl is-enabled systemd-networkd-wait-online ifupdown-wait-online networking

echo
echo "=== nettoyage des fichiers de test interrompus ==="
M=$(findmnt -no TARGET -S /dev/vdb1)
rm -f "$M/sauvegardes/trop-gros.bin"
ls -l "$M/sauvegardes"

echo "=== correctif ==="
systemctl disable --now systemd-networkd-wait-online.service
systemctl enable ifupdown-wait-online.service
systemctl daemon-reload

echo
echo "=== état après correctif ==="
systemctl is-enabled systemd-networkd-wait-online 2>&1 || true
systemctl is-enabled ifupdown-wait-online
systemctl list-jobs | head -5
