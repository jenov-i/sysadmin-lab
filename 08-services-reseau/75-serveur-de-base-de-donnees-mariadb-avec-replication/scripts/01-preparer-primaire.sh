#!/bin/bash
# Prépare le primaire (lab-linux-01) : base applicative, comptes, instantané initial.
# Les mots de passe sont générés sur la machine et restent dans /root/.lab-secrets
# (mode 600) : aucun ne part dans le dépôt ni dans les journaux.
set -euo pipefail

SECRETS=/root/.lab-secrets
SCHEMA=/root/schema-lab-boutique.sql
DUMP=/var/backups/lab-boutique.sql

if [ ! -f "$SECRETS" ]; then
  umask 077
  printf 'APP=%s\nREPL=%s\n' "$(openssl rand -hex 12)" "$(openssl rand -hex 12)" > "$SECRETS"
  echo "secrets générés dans $SECRETS"
else
  echo "secrets déjà présents dans $SECRETS"
fi
# shellcheck disable=SC1090
. "$SECRETS"

echo
echo "--- schéma et jeu de données"
mariadb < "$SCHEMA"

echo
echo "--- comptes"
mariadb <<SQL
CREATE USER IF NOT EXISTS 'app_boutique'@'192.168.99.%' IDENTIFIED BY '$APP';
GRANT SELECT, INSERT, UPDATE, DELETE ON lab_boutique.* TO 'app_boutique'@'192.168.99.%';
CREATE USER IF NOT EXISTS 'repl'@'192.168.99.%' IDENTIFIED BY '$REPL';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl'@'192.168.99.%';
FLUSH PRIVILEGES;
SQL
mariadb -e "SELECT User, Host, plugin FROM mysql.user WHERE User IN ('app_boutique','repl')"
# SHOW GRANTS renvoie le hash du mot de passe : il est masqué avant publication
mariadb -e "SHOW GRANTS FOR 'repl'@'192.168.99.%'" |
  sed -E "s/IDENTIFIED BY PASSWORD '[^']*'/IDENTIFIED BY PASSWORD '<masque>'/"
mariadb -e "SHOW GRANTS FOR 'app_boutique'@'192.168.99.%'" |
  sed -E "s/IDENTIFIED BY PASSWORD '[^']*'/IDENTIFIED BY PASSWORD '<masque>'/" 

echo
echo "--- volumes"
mariadb lab_boutique -e "
SELECT 'clients' AS table_nom, COUNT(*) AS lignes FROM clients
UNION ALL SELECT 'produits', COUNT(*) FROM produits
UNION ALL SELECT 'commandes', COUNT(*) FROM commandes
UNION ALL SELECT 'lignes_commande', COUNT(*) FROM lignes_commande;"
mariadb lab_boutique -e "SELECT id, nom, ville FROM clients ORDER BY id LIMIT 3;
                         SELECT id, libelle, prix_cents, stock FROM produits ORDER BY id LIMIT 3;"

echo
echo "--- instantané cohérent (transaction unique + position GTID)"
install -d -m 750 /var/backups
mariadb-dump --single-transaction --master-data=2 --gtid --routines --events \
             --databases lab_boutique > "$DUMP"
ls -l "$DUMP"
grep -E "^(-- CHANGE MASTER|SET @@GLOBAL.GTID_POS|-- GTID state)" "$DUMP" | head -5
grep -c "^INSERT INTO" "$DUMP" | sed 's/^/nombre d INSERT dans le dump : /'
