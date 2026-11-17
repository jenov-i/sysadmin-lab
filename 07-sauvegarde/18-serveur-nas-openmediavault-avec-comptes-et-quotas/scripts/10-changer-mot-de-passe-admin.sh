#!/bin/bash
# Remplace le mot de passe admin par défaut d'OpenMediaVault par celui du lab,
# conservé dans /root/.labpass (hors dépôt). Vérifie que l'ancien est refusé.
set -uo pipefail
PASS=$(cat /root/.labpass)

essai() {
    local mdp="$1"
    local r
    r=$(curl -s -H 'Content-Type: application/json' -X POST http://127.0.0.1/rpc.php \
        -d "{\"service\":\"Session\",\"method\":\"login\",\"params\":{\"username\":\"admin\",\"password\":\"$mdp\"}}")
    if printf '%s' "$r" | grep -q '"status":"authenticated"'; then echo "accepté"; else echo "refusé"; fi
}

echo "avant : $(essai openmediavault)"
echo "admin:$PASS" | chpasswd
echo "mot de passe admin remplacé (valeur hors dépôt)"
echo "après, ancien mot de passe : $(essai openmediavault)"
echo "après, nouveau mot de passe : $(essai "$PASS")"
