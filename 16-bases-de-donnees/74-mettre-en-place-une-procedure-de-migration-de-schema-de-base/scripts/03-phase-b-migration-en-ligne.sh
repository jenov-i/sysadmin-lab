#!/bin/bash
# Phase B — la migration en ligne : colonne ajoutée sans réécriture, remplissage
# par lots, index CONCURRENTLY, contrainte NOT VALID puis VALIDATE, et enfin
# SET NOT NULL qui réutilise la contrainte validée. Même charge qu'en phase A.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

D=/tmp/labmig-b
LOT=10000
rm -rf "$D"; mkdir -p "$D"; chmod 777 "$D"

duree=0
timeit() {
  local a b
  a=$(date +%s.%N)
  "$@"
  b=$(date +%s.%N)
  duree=$(awk -v x="$a" -v y="$b" 'BEGIN { printf "%.2f", y - x }')
}

resume() {
  awk -v libelle="$2" '
    { n++; s += $1; if ($1 > m) m = $1; if ($1 >= 1000) lents++; if ($2 != "ok") echecs++ }
    END { printf "  %-9s %7d requêtes · moyenne %6.2f ms · max %7.1f ms · >= 1 s : %-3d échecs : %d\n",
                 libelle, n, s / n, m, lents + 0, echecs + 0 }
  ' "$1"
}

psql_srv() { runuser -u postgres -- psql -q -d lab_migration "$@"; }

echo "== 0. Remise à l'état d'avant migration (essai rejouable) =="
psql_srv -c 'ALTER TABLE commandes DROP CONSTRAINT IF EXISTS canal_non_nul'
psql_srv -c 'ALTER TABLE commandes DROP CONSTRAINT IF EXISTS montant_positif'
psql_srv -c 'ALTER TABLE commandes DROP COLUMN IF EXISTS canal'
psql_srv -c 'DROP INDEX IF EXISTS idx_commandes_canal'

echo
echo "== 1. Charge continue : 4 écrivains (timeout 1 s) + 2 lecteurs =="
runuser -u postgres -- python3 /tmp/charge.py ecriture 26 "$D/ecriture.log" 4 &
W=$!
runuser -u postgres -- python3 /tmp/charge.py lecture 26 "$D/lecture.log" 2 &
R=$!
echo "   écrivains pid $W, lecteurs pid $R"
sleep 3

echo
echo "== 2. Nouvelle colonne, sans réécriture de la table =="
timeit psql_srv -c 'ALTER TABLE commandes ADD COLUMN canal text'
DUREE_COLONNE=$duree
echo "   ALTER TABLE ADD COLUMN : $DUREE_COLONNE s"

echo
echo "== 3. Remplissage par lots de $LOT lignes =="
MAXID=$(psql_srv -At -c 'SELECT max(id) FROM commandes')
NB=$(( (MAXID + LOT - 1) / LOT ))
{
  echo '\timing on'
  for ((i = 0; i < NB; i++)); do
    lo=$((i * LOT)); hi=$((lo + LOT))
    echo 'BEGIN;'
    echo "UPDATE commandes SET canal = CASE WHEN client_id % 2 = 0 THEN 'web' ELSE 'magasin' END WHERE id > $lo AND id <= $hi AND canal IS NULL;"
    echo 'COMMIT;'
  done
} > "$D/lots.sql"
timeit runuser -u postgres -- psql -d lab_migration -f "$D/lots.sql" > "$D/lots.out" 2>&1
DUREE_LOTS=$duree
read -r LOT_MAX LOT_MOY < <(awk '/^Time:/ { t = $2 + 0; if (t >= 1) { n++; s += t; if (t > m) m = t } }
                                  END { printf "%.0f %.0f\n", m, (n ? s / n : 0) }' "$D/lots.out")
echo "   $NB lots en $DUREE_LOTS s (moyenne $LOT_MOY ms, lot le plus lent $LOT_MAX ms)"

echo
echo "== 4. Index construit en ligne =="
(
  sleep 1
  runuser -u postgres -- psql -d lab_migration -c "
    SELECT phase, blocks_done, blocks_total,
           round(100.0 * blocks_done / nullif(blocks_total, 0), 1) AS pourcent
    FROM pg_stat_progress_create_index;" > "$D/progression.txt" 2>&1
) &
PROG=$!
timeit runuser -u postgres -- psql -q -d lab_migration \
  -c 'CREATE INDEX CONCURRENTLY idx_commandes_canal ON commandes (canal)'
DUREE_INDEX=$duree
echo "   CREATE INDEX CONCURRENTLY : $DUREE_INDEX s"
wait "$PROG" || true

echo
echo "== 5. Contrainte sur une colonne existante, pendant la charge =="
timeit psql_srv -c 'ALTER TABLE commandes ADD CONSTRAINT montant_positif CHECK (montant >= 0) NOT VALID'
DUREE_CHECK=$duree
timeit psql_srv -c 'ALTER TABLE commandes VALIDATE CONSTRAINT montant_positif'
DUREE_VALIDATE=$duree
echo "   CHECK ... NOT VALID : $DUREE_CHECK s"
echo "   VALIDATE montant_positif : $DUREE_VALIDATE s"

wait "$W"
wait "$R"

echo
echo "== 6. NOT NULL : les écritures doivent d'abord fournir la colonne =="
psql_srv -c "UPDATE commandes SET canal = CASE WHEN client_id % 2 = 0 THEN 'web' ELSE 'magasin' END WHERE canal IS NULL"
NULLS=$(psql_srv -At -c 'SELECT count(*) FROM commandes WHERE canal IS NULL')
timeit psql_srv -c 'ALTER TABLE commandes ADD CONSTRAINT canal_non_nul CHECK (canal IS NOT NULL) NOT VALID'
timeit psql_srv -c 'ALTER TABLE commandes VALIDATE CONSTRAINT canal_non_nul'
DUREE_VALIDATE2=$duree
timeit psql_srv -c 'ALTER TABLE commandes ALTER COLUMN canal SET NOT NULL'
DUREE_NOTNULL=$duree
echo "   canal NULL restants : $NULLS"
echo "   VALIDATE canal_non_nul : $DUREE_VALIDATE2 s"
echo "   ALTER COLUMN SET NOT NULL : $DUREE_NOTNULL s"

echo
echo "== Récapitulatif de la phase B =="
printf "  %-27s %s s\n" "ADD COLUMN canal" "$DUREE_COLONNE"
printf "  %-27s %s s (%d lots)\n" "remplissage par lots" "$DUREE_LOTS" "$NB"
printf "  %-27s %s s\n" "CREATE INDEX CONCURRENTLY" "$DUREE_INDEX"
printf "  %-27s %s s\n" "VALIDATE contrainte" "$DUREE_VALIDATE"
printf "  %-27s %s s\n" "SET NOT NULL (3 M lignes)" "$DUREE_NOTNULL"
resume "$D/ecriture.log" "écrivains"
resume "$D/lecture.log"  "lecteurs"
echo
echo "== Progression de l'index en ligne (photo) =="
cat "$D/progression.txt"
