#!/bin/bash
# Relevé de l'état des quotas et de la configuration OMV après les tests SMB.
set -uo pipefail
M=$(findmnt -no TARGET -S /dev/vdb1)

echo "=== système de fichiers ==="
findmnt -no SOURCE,TARGET,FSTYPE,OPTIONS -S /dev/vdb1
df -h "$M" | tail -1

echo
echo "=== état des quotas XFS ==="
xfs_quota -x -c "state" "$M" | sed -n '1,10p'

echo
echo "=== consommation des comptes ==="
xfs_quota -x -c "report -u -b -h" "$M"
echo
repquota -u -s "$M"

echo
echo "=== limites vues par l'API OpenMediaVault ==="
omv-rpc -u admin Quota get '{"uuid":"eaa46f06-2017-41b0-8c9d-047989b6e920"}' \
    | python3 -m json.tool

echo
echo "=== contenu du partage ==="
ls -ls "$M/sauvegardes"

echo
echo "=== service de quotas (persistance au démarrage) ==="
systemctl is-enabled quota
systemctl is-active quota

echo
echo "=== état OMV ==="
dpkg -l openmediavault | tail -1 | awk '{print "paquet :", $2, $3}'
omv-rpc -u admin Config get '{"id":"version"}' 2>/dev/null || true
echo "--- services"
systemctl is-active nginx smbd openmediavault-engined | tr '\n' ' '; echo
echo "--- partage SMB"
omv-rpc -u admin Smb getShareList '{"start":0,"limit":10}' \
    | python3 -c 'import json,sys
for s in json.load(sys.stdin)["data"]:
    print(" ", s["sharedfoldername"], "| guest=" + s["guest"], "| readonly=" + str(s["readonly"]), "| dossier=" + s["sharedfolderref"])'
echo "--- comptes"
omv-rpc -u admin UserMgmt enumerateUsers '{"detail":"basic"}' \
    | python3 -c 'import json,sys
for u in json.load(sys.stdin):
    print(" ", u["name"], "| uid", u["uid"], "| groupes", ",".join(u["groups"]))'
