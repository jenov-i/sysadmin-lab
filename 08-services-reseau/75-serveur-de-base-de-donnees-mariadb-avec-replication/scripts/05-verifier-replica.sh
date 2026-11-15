#!/bin/bash
# Vérifie que l'écriture faite sur le primaire est bien arrivée sur le réplica.
set -euo pipefail

echo "--- état du réplica"
mariadb lab_boutique -e "
SELECT 'clients' AS table_nom, COUNT(*) AS lignes FROM clients
UNION ALL SELECT 'commandes', COUNT(*) FROM commandes
UNION ALL SELECT 'lignes_commande', COUNT(*) FROM lignes_commande;
SELECT c.id, c.nom, c.ville, cmd.id AS commande, cmd.total_cents
  FROM clients c JOIN commandes cmd ON cmd.client_id = c.id
 WHERE c.nom = 'client-preuve-01';"

echo "--- position GTID et santé de la réplication"
mariadb -e "SELECT @@gtid_current_pos AS gtid_current_pos, @@gtid_slave_pos AS gtid_slave_pos,
                   @@read_only AS read_only"
mariadb -e "SHOW SLAVE STATUS\G" | grep -E \
  "Using_Gtid|Gtid_IO_Pos|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_SQL_Error"
