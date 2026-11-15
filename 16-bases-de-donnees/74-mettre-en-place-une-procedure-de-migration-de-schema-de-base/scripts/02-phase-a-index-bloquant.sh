#!/bin/bash
# Phase A — la migration naïve : CREATE INDEX sans CONCURRENTLY, pendant que
# 4 clients insèrent et 2 clients lisent. Les inserts ont un statement_timeout
# de 1 s : le verrou SHARE pris par la construction de l'index les fait échouer.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

D=/tmp/labmig-a
rm -rf "$D"; mkdir -p "$D"; chmod 777 "$D"

resume() {
  awk -v libelle="$2" '
    { n++; s += $1; if ($1 > m) m = $1; if ($1 >= 1000) lents++; if ($2 != "ok") echecs++ }
    END { printf "  %-9s %7d requêtes · moyenne %6.2f ms · max %7.1f ms · >= 1 s : %-3d échecs : %d\n",
                 libelle, n, s / n, m, lents + 0, echecs + 0 }
  ' "$1"
}

lignes_avant=$(runuser -u postgres -- psql -At -d lab_migration -c 'SELECT count(*) FROM commandes')
runuser -u postgres -- psql -q -d lab_migration -c 'DROP INDEX IF EXISTS idx_commandes_statut'

echo "== 1. Charge continue : 4 écrivains (timeout 1 s) + 2 lecteurs =="
runuser -u postgres -- python3 /tmp/charge.py ecriture 24 "$D/ecriture.log" 4 &
W=$!
runuser -u postgres -- python3 /tmp/charge.py lecture 24 "$D/lecture.log" 2 &
R=$!
echo "   écrivains pid $W, lecteurs pid $R"
sleep 4

echo
echo "== 2. Migration naïve : CREATE INDEX sans CONCURRENTLY =="
(
  for essai in $(seq 1 60); do
    attente=$(runuser -u postgres -- psql -At -d lab_migration \
      -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'lab_migration' AND wait_event_type = 'Lock'")
    if [ "${attente:-0}" -gt 0 ]; then
      runuser -u postgres -- psql -d lab_migration -c "
        SELECT wait_event_type AS attente, count(*) AS sessions,
               left(min(regexp_replace(query, '\s+', ' ', 'g')), 30) AS exemple
        FROM pg_stat_activity
        WHERE datname = 'lab_migration' AND pid <> pg_backend_pid()
        GROUP BY 1 ORDER BY 1 NULLS FIRST;" > "$D/photo.txt"
      runuser -u postgres -- psql -d lab_migration -c "
        SELECT mode AS verrou, granted AS accorde, count(*) AS sessions
        FROM pg_locks
        WHERE locktype = 'relation' AND relation = 'commandes'::regclass
        GROUP BY 1, 2 ORDER BY 2, 1;" >> "$D/photo.txt"
      break
    fi
    sleep 0.1
  done
) &
PHOTO=$!

START=$(date +%s.%N)
runuser -u postgres -- psql -q -d lab_migration \
  -c 'CREATE INDEX idx_commandes_statut ON commandes (statut)'
END=$(date +%s.%N)
DUREE=$(awk -v a="$START" -v b="$END" 'BEGIN { printf "%.2f", b - a }')
echo "   durée du CREATE INDEX : $DUREE s"
wait "$PHOTO"

wait "$W"
wait "$R"

lignes_apres=$(runuser -u postgres -- psql -At -d lab_migration -c 'SELECT count(*) FROM commandes')

echo
echo "== Récapitulatif de la phase A =="
echo "  CREATE INDEX bloquant : $DUREE s"
resume "$D/ecriture.log" "écrivains"
resume "$D/lecture.log"  "lecteurs"
echo "  lignes réellement insérées : $((lignes_apres - lignes_avant))"
echo "  index construit : $(runuser -u postgres -- psql -At -d lab_migration -c "SELECT pg_size_pretty(pg_relation_size('idx_commandes_statut'))")"

echo
echo "== Photo prise pendant le verrou =="
cat "$D/photo.txt"
