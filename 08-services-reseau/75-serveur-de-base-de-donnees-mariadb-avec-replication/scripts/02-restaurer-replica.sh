#!/bin/bash
# Restaure l'instantané du primaire sur le réplica et cale la position GTID.
# Le dump est déposé par l'administrateur dans /root/lab-boutique.sql.
set -euo pipefail

DUMP=${1:-/root/lab-boutique.sql}
[ -r "$DUMP" ] || { echo "instantané introuvable : $DUMP"; exit 1; }

echo "--- instantané"
ls -l "$DUMP"
grep -E "^-- CHANGE MASTER TO MASTER_LOG_FILE" "$DUMP"

# mariadb-dump écrit la position GTID en commentaire : elle doit être appliquée
# à la main, sinon le réplica tente de rejouer le journal depuis le début.
GTID=$(grep -oE "SET GLOBAL gtid_slave_pos='[^']+'" "$DUMP" | head -1 | grep -oE "'[^']+'" | tr -d "'")
echo "position GTID annoncée par l'instantané : ${GTID:-aucune}"

echo
echo "--- restauration"
mariadb -e "STOP SLAVE" 2>/dev/null || true
mariadb < "$DUMP"

echo
echo "--- position appliquée"
if [ -n "${GTID:-}" ]; then
  mariadb -e "SET GLOBAL gtid_slave_pos='$GTID'; SELECT @@gtid_slave_pos AS gtid_slave_pos"
fi

echo
echo "--- contenu restauré"
mariadb lab_boutique -e "SELECT COUNT(*) AS clients FROM clients;
                         SELECT COUNT(*) AS commandes FROM commandes;
                         SELECT COUNT(*) AS lignes FROM lignes_commande;"
mariadb lab_boutique -e "SELECT id, nom, ville FROM clients ORDER BY id LIMIT 3;"
