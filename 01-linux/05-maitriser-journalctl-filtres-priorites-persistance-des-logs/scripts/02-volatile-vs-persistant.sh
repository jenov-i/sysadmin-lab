#!/bin/bash
# Passe le journal en mode volatil, écrit un marqueur, puis revient au mode
# persistant et écrit un second marqueur. Le redémarrage qui suit dira lequel
# des deux a survécu.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Marqueur écrit en mode persistant =="
logger -p local0.notice -t lab-journal "MARQUEUR-PERSISTANT ecrit avant le passage en volatil"
journalctl -t lab-journal -g MARQUEUR-PERSISTANT -o cat --no-pager
journalctl --header | grep -m1 'File path'

echo
echo "== 2. Passage en Storage=volatile =="
install -d /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/90-lab-volatile.conf <<'EOF'
[Journal]
Storage=volatile
EOF
systemctl restart systemd-journald
sleep 1
journalctl --header | grep -m1 'File path'
echo "répertoire utilisé :"
ls -d /run/log/journal/*/ 2>/dev/null | head -2

echo
echo "== 3. Marqueur écrit en mode volatil =="
logger -p local0.notice -t lab-journal "MARQUEUR-VOLATIL ecrit pendant le mode volatil"
sleep 1
journalctl -t lab-journal -g MARQUEUR-VOLATIL -o cat --no-pager

echo
echo "== 4. Retour au mode persistant =="
rm -f /etc/systemd/journald.conf.d/90-lab-volatile.conf
systemctl restart systemd-journald
sleep 1
journalctl --header | grep -m1 'File path'
logger -p local0.notice -t lab-journal "MARQUEUR-APRES-RETOUR ecrit apres le retour en persistant"

echo
echo "== 5. Les trois marqueurs visibles avant redémarrage =="
journalctl -t lab-journal -g 'MARQUEUR' -o cat --no-pager
