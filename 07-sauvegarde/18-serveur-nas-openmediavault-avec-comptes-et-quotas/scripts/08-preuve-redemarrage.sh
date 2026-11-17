#!/bin/bash
# Preuve après redémarrage : les services montent seuls et les quotas survivent.
set -uo pipefail
M=$(findmnt -no TARGET -S /dev/vdb1)

echo "Démarrage du $(uptime -s) — $(systemd-analyze | head -1 | sed 's/Startup finished in //')"
echo "services actifs : $(systemctl is-active nginx smbd openmediavault-engined quota | tr '\n' ' ')"
echo "attente réseau  : networkd=$(systemctl is-enabled systemd-networkd-wait-online 2>&1) ifupdown=$(systemctl is-enabled ifupdown-wait-online)"
echo "montage         : $(findmnt -no SOURCE,TARGET,FSTYPE -S /dev/vdb1)"
echo
echo "--- quotas après redémarrage ---"
xfs_quota -x -c 'report -u -b -h' "$M" | tail -4
