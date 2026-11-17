#!/bin/bash
# Résumé compact destiné à la capture d'écran de la console du NAS.
set -uo pipefail
M=$(findmnt -no TARGET -S /dev/vdb1)
U=eaa46f06-2017-41b0-8c9d-047989b6e920

echo "NAS $(hostname) — OpenMediaVault $(dpkg-query -W -f='${Version}' openmediavault)"
echo "services : $(systemctl is-active nginx smbd openmediavault-engined | tr '\n' ' ')"
echo "partage  : $(omv-rpc -u admin Smb getShareList '{"start":0,"limit":10}' \
    | python3 -c 'import json,sys; s=json.load(sys.stdin)["data"][0]; print(s["sharedfoldername"], "guest="+s["guest"], "lecture/ecriture="+str(not s["readonly"]))')"
echo "comptes  : $(omv-rpc -u admin UserMgmt enumerateUsers '{"detail":"basic"}' \
    | python3 -c 'import json,sys; print(", ".join(u["name"] for u in json.load(sys.stdin)))')"
echo
echo "--- quotas XFS sur $(basename "$M") ---"
xfs_quota -x -c 'report -u -b -h' "$M" | tail -4
echo
echo "--- repquota ---"
repquota -u -s "$M" | tail -4
