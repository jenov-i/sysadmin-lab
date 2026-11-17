#!/bin/bash
# Capture console : refus d'écriture au-delà du quota, vu depuis le client.
set -uo pipefail
PASS=$(cat /root/.labpass)

echo "Client $(hostname) -> NAS 192.168.99.1:4450 (SMB redirigé)"
echo "Compte sauvegarde : quota 512 Mio, 320 Mio déjà stockés."
echo "Tentative de dépôt d'un fichier de 300 Mio :"
dd if=/dev/zero of=/tmp/trop-gros.bin bs=1M count=300 status=none
smbclient //192.168.99.1/sauvegardes -p 4450 -U "sauvegarde%$PASS" \
    -c "put /tmp/trop-gros.bin trop-gros.bin" 2>&1 | tail -3
echo "code retour smbclient : ${PIPESTATUS[0]}"
rm -f /tmp/trop-gros.bin
