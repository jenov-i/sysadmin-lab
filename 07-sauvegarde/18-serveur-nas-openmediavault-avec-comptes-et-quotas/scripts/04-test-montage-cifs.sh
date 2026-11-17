#!/bin/bash
# Après nettoyage des fichiers partiels : écriture directe par un montage CIFS.
set -uo pipefail
NAS=192.168.99.1
PORT=4450
PARTAGE=sauvegardes
PASS=$(cat /root/.labpass)
TMP=$(mktemp -d /tmp/montage-nas.XXXXXX)
MNT=/mnt/nas-test
trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null; rm -rf "$TMP"' EXIT

mkdir -p "$MNT"
echo "=== montage CIFS (SMB 3.0) ==="
mount -t cifs "//$NAS/$PARTAGE" "$MNT" \
    -o "username=sauvegarde,password=$PASS,port=$PORT,vers=3.0,uid=1000,gid=1000" && echo "montage réussi"
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS "$MNT"
echo
echo "=== espace vu par le client ==="
df -h "$MNT" | tail -1
echo
echo "=== écriture de 64 Mio à travers le montage ==="
dd if=/dev/urandom of="$TMP/source-64m.bin" bs=1M count=64 status=none
sha256sum "$TMP/source-64m.bin"
cp "$TMP/source-64m.bin" "$MNT/depuis-le-montage.bin"
ls -l "$MNT/depuis-le-montage.bin"
echo
echo "=== relecture depuis le montage ==="
sha256sum "$MNT/depuis-le-montage.bin"
cmp "$TMP/source-64m.bin" "$MNT/depuis-le-montage.bin" && echo "contenu identique (cmp)"
echo
echo "=== permissions vues par le client ==="
stat -c '%n %U:%G %a %s' "$MNT/depuis-le-montage.bin"
umount "$MNT"
echo "démonté"
