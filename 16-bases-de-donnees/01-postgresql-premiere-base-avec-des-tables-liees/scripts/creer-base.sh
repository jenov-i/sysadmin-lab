#!/bin/bash
# Crée le rôle, la base, le schéma et les données de lab_stock, puis ouvre
# l'accès TCP sur le réseau du lab.
# Exécuté tel quel sur srv-debian13 le 15/11/2026.
# `sudo` n'est pas installé sur cette Debian minimale : on passe par runuser.
set -euo pipefail

echo "== 1. Rôle applicatif et base =="
runuser -u postgres -- psql -v ON_ERROR_STOP=1 <<'SQL'
DROP DATABASE IF EXISTS lab_stock;
DROP ROLE IF EXISTS lab_admin;
CREATE ROLE lab_admin LOGIN;
CREATE DATABASE lab_stock OWNER lab_admin;
SQL

# Mot de passe généré, jamais affiché : il part dans /root/.pgpass (600).
# od + tr plutôt que « tr | head » : avec pipefail, head qui ferme le tube
# ferait échouer le script en SIGPIPE (code 141).
MDP=$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')
printf '10.0.3.10:5432:lab_stock:lab_admin:%s\n' "$MDP" > /root/.pgpass
chmod 600 /root/.pgpass
runuser -u postgres -- psql -q -v ON_ERROR_STOP=1 \
  -c "ALTER ROLE lab_admin PASSWORD '$MDP'"
unset MDP
echo "rôle lab_admin créé, mot de passe dans /root/.pgpass (non publié)"

echo
echo "== 2. Schéma =="
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d lab_stock < /root/schema-lab-stock.sql

echo
echo "== 3. Données =="
runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d lab_stock < /root/donnees-lab-stock.sql
runuser -u postgres -- psql -d lab_stock -c "
  SELECT 'fournisseur' AS table, count(*) FROM fournisseur
  UNION ALL SELECT 'article', count(*) FROM article
  UNION ALL SELECT 'mouvement', count(*) FROM mouvement;"

echo
echo "== 4. Écoute sur le réseau du lab =="
runuser -u postgres -- psql -q -c "ALTER SYSTEM SET listen_addresses = 'localhost,10.0.3.10'"
HBA=/etc/postgresql/17/main/pg_hba.conf
if ! grep -q 'lab_stock lab_admin 10.0.3.0/24' "$HBA"; then
  cp -a "$HBA" "$HBA.avant-lab"
  # La première règle qui correspond gagne : cette ligne doit être en tête.
  printf '%s\n' \
    '# lab sysadmin-lab : accès applicatif depuis le réseau du lab uniquement' \
    'host    lab_stock    lab_admin    10.0.3.0/24    scram-sha-256' \
    | cat - "$HBA.avant-lab" > "$HBA"
fi
systemctl restart postgresql
sleep 3
pg_lsclusters
ss -tlnp | grep 5432

echo
echo "== 5. Connexion TCP avec le rôle applicatif =="
psql -h 10.0.3.10 -U lab_admin -d lab_stock -Atc \
  "SELECT current_user || ' sur ' || inet_server_addr() || ':' || inet_server_port()
          || ' — ' || split_part(version(), ',', 1);"
