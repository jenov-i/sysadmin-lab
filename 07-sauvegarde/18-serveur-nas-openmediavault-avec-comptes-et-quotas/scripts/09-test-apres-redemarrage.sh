#!/bin/bash
# Après redémarrage du NAS : le partage et les quotas répondent toujours.
set -uo pipefail
NAS=192.168.99.1
PORT=4450
PASS=$(cat /root/.labpass)
TMP=$(mktemp -d /tmp/apres-reboot.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo "=== NAS joignable ==="
smbclient -L "//$NAS" -p "$PORT" -U "sauvegarde%$PASS" 2>&1 | sed -n '3,8p'

echo
echo "=== écriture et relecture d'un fichier de 8 Mio ==="
dd if=/dev/urandom of="$TMP/apres.bin" bs=1M count=8 status=none
sha256sum "$TMP/apres.bin"
smbclient "//$NAS/sauvegardes" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "put $TMP/apres.bin apres-redemarrage.bin" 2>&1 | tail -2
smbclient "//$NAS/sauvegardes" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "get apres-redemarrage.bin $TMP/relu.bin" 2>&1 | tail -2
sha256sum "$TMP/relu.bin"
cmp "$TMP/apres.bin" "$TMP/relu.bin" && echo "contenu identique (cmp)"

echo
echo "=== suppression du fichier de test ==="
smbclient "//$NAS/sauvegardes" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "del apres-redemarrage.bin" 2>&1 | tail -1
