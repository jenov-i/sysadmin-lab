#!/bin/bash
# Vérification de l'état final : structure, contraintes réellement validées,
# index utilisables, volumétrie et cohérence des données.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

psql_srv() { runuser -u postgres -- psql -d lab_migration "$@"; }

echo "== 1. Structure de la table =="
psql_srv -c '\d commandes'

echo "== 2. Contraintes : validées ou seulement déclarées ? =="
psql_srv -c "
SELECT conname AS contrainte, convalidated AS validee,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'commandes'::regclass AND contype = 'c'
ORDER BY conname;"

echo "== 3. Index réellement utilisables =="
psql_srv -c "
SELECT c.relname AS index, i.indisvalid AS valide,
       pg_size_pretty(pg_relation_size(c.oid)) AS taille
FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
WHERE i.indrelid = 'commandes'::regclass
ORDER BY c.relname;"

echo "== 4. Volumétrie et cohérence =="
psql_srv -c "
SELECT count(*) AS lignes,
       count(*) FILTER (WHERE canal IS NULL) AS canal_null,
       count(DISTINCT canal) AS valeurs_canal,
       pg_size_pretty(pg_total_relation_size('commandes')) AS taille_totale
FROM commandes;"

echo "== 5. Répartition de la nouvelle colonne =="
psql_srv -c "SELECT canal, count(*) FROM commandes GROUP BY 1 ORDER BY 2 DESC;"
