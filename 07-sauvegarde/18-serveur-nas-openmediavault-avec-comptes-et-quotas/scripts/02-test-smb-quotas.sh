#!/bin/bash
# Test réel du NAS depuis une machine distincte (lab-linux-01, 192.168.99.11).
# Le NAS est joint par la redirection de ports de l'hôte : 192.168.99.1:4450.
# Le mot de passe des comptes OMV est lu dans /root/.labpass (hors dépôt).
set -uo pipefail

NAS=192.168.99.1
PORT=4450
PARTAGE=sauvegardes
PASS=$(cat /root/.labpass)
TMP=$(mktemp -d /tmp/test-nas.XXXXXX)
MNT=/mnt/nas-test
trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null; rm -rf "$TMP"' EXIT

echo "=== client ==="
hostname
ip -4 addr show ens33 | grep 'inet '
smbclient --version | head -1

echo
echo "=== 1. énumération des partages (compte sauvegarde) ==="
smbclient -L "//$NAS" -p "$PORT" -U "sauvegarde%$PASS" 2>&1 | sed -n '1,25p'

echo
echo "=== 2. dépôt d'un fichier de 256 Mio ==="
dd if=/dev/zero of="$TMP/fichier-256m.bin" bs=1M count=256 status=none
sha256sum "$TMP/fichier-256m.bin"
time smbclient "//$NAS/$PARTAGE" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "put $TMP/fichier-256m.bin fichier-256m.bin" 2>&1 | tail -5

echo
echo "=== 3. relecture et comparaison d'empreinte ==="
smbclient "//$NAS/$PARTAGE" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "get fichier-256m.bin $TMP/relu.bin" 2>&1 | tail -3
sha256sum "$TMP/relu.bin"
cmp "$TMP/fichier-256m.bin" "$TMP/relu.bin" && echo "contenu identique (cmp)"

echo
echo "=== 4. dépassement du quota de 512 Mio (300 Mio de plus) ==="
dd if=/dev/zero of="$TMP/fichier-300m.bin" bs=1M count=300 status=none
smbclient "//$NAS/$PARTAGE" -p "$PORT" -U "sauvegarde%$PASS" \
    -c "put $TMP/fichier-300m.bin fichier-300m.bin" 2>&1 | tail -6
echo "code retour smbclient : $?"

echo
echo "=== 5. quota du compte archive (256 Mio) ==="
smbclient "//$NAS/$PARTAGE" -p "$PORT" -U "archive%$PASS" \
    -c "put $TMP/fichier-300m.bin archive-300m.bin" 2>&1 | tail -5
echo "code retour smbclient : $?"

echo
echo "=== 6. montage CIFS et écriture directe ==="
mkdir -p "$MNT"
mount -t cifs "//$NAS/$PARTAGE" "$MNT" \
    -o "username=sauvegarde,password=$PASS,port=$PORT,vers=3.0,uid=1000,gid=1000" 2>&1
mount | grep "$MNT"
df -h "$MNT" | tail -1
echo "depuis le montage : $(date -Is)" > "$MNT/depuis-le-montage.txt"
cat "$MNT/depuis-le-montage.txt"
ls -l "$MNT"
umount "$MNT"

echo
echo "=== 7. fichiers visibles côté client ==="
smbclient "//$NAS/$PARTAGE" -p "$PORT" -U "sauvegarde%$PASS" -c "ls" 2>&1 | sed -n '1,20p'
