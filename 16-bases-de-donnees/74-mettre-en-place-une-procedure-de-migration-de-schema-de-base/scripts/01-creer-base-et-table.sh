#!/bin/bash
# Création de la base de test et d'une table « commandes » volumineuse
# (3 000 000 de lignes) pour rendre les migrations mesurables.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

runuser -u postgres -- dropdb --if-exists lab_migration
runuser -u postgres -- createdb lab_migration

echo "== 1. Table commandes =="
runuser -u postgres -- psql -q -d lab_migration -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE commandes (
  id        bigserial PRIMARY KEY,
  client_id integer      NOT NULL,
  montant   numeric(10,2) NOT NULL,
  statut    text         NOT NULL,
  cree_le   timestamptz  NOT NULL,
  notes     text
);

\timing on
INSERT INTO commandes (client_id, montant, statut, cree_le, notes)
SELECT 1 + floor(random() * 9999)::int,
       round((random() * 500)::numeric, 2),
       (ARRAY['en_attente','payee','expediee','livree','annulee'])[1 + floor(random() * 5)::int],
       now() - ((random() * 365)::int || ' days')::interval,
       'commande de test'
FROM generate_series(1, 3000000);
\timing off

ANALYZE commandes;
SQL

echo
echo "== 2. Volume réel de la table =="
runuser -u postgres -- psql -d lab_migration -c "
SELECT count(*) AS lignes,
       pg_size_pretty(pg_total_relation_size('commandes')) AS taille_totale,
       pg_size_pretty(pg_relation_size('commandes'))       AS table_seule
FROM commandes;"

echo "== 3. Réglages qui influencent la durée des migrations =="
runuser -u postgres -- psql -d lab_migration -c "SHOW work_mem; SHOW maintenance_work_mem; SHOW max_parallel_maintenance_workers;"
