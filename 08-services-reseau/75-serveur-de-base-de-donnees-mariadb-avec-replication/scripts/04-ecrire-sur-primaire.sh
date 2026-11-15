#!/bin/bash
# Écrit une commande réelle sur le primaire, avec le compte applicatif
# (connexion TCP sur l'adresse du lab, pas la socket root).
set -euo pipefail

. /root/.lab-secrets
export MYSQL_PWD=$APP

# script rejouable : la preuve précédente est retirée avant de réécrire
mariadb lab_boutique -e "DELETE FROM clients WHERE nom = 'client-preuve-01'" 2>/dev/null || true

echo "--- écriture applicative sur 192.168.99.11"
mariadb -h 192.168.99.11 -u app_boutique lab_boutique <<'SQL'
START TRANSACTION;
INSERT INTO clients (nom, ville) VALUES ('client-preuve-01', 'Cotonou');
SET @c = LAST_INSERT_ID();
INSERT INTO commandes (client_id, statut) VALUES (@c, 'payee');
SET @cmd = LAST_INSERT_ID();
INSERT INTO lignes_commande (commande_id, produit_id, quantite, prix_unitaire_cents)
  VALUES (@cmd, 2, 3, (SELECT prix_cents FROM produits WHERE id = 2)),
         (@cmd, 5, 1, (SELECT prix_cents FROM produits WHERE id = 5));
UPDATE commandes
   SET total_cents = (SELECT SUM(quantite * prix_unitaire_cents)
                        FROM lignes_commande WHERE commande_id = @cmd)
 WHERE id = @cmd;
COMMIT;
SELECT @c AS client_id, @cmd AS commande_id;
SQL

echo
echo "--- état du primaire"
mariadb lab_boutique -e "
SELECT 'clients' AS table_nom, COUNT(*) AS lignes FROM clients
UNION ALL SELECT 'commandes', COUNT(*) FROM commandes
UNION ALL SELECT 'lignes_commande', COUNT(*) FROM lignes_commande;
SELECT c.id, c.nom, c.ville, cmd.id AS commande, cmd.total_cents
  FROM clients c JOIN commandes cmd ON cmd.client_id = c.id
 WHERE c.nom = 'client-preuve-01';"
mariadb -e "SHOW MASTER STATUS; SELECT @@gtid_binlog_pos AS gtid_binlog_pos"

echo
echo "--- un client qui vise le réplica : l'écriture doit être refusée"
mariadb -h 192.168.99.12 -u app_boutique lab_boutique \
  -e "INSERT INTO clients (nom, ville) VALUES ('interdit', 'Cotonou')" 2>&1 | grep -E "^ERROR" || true
