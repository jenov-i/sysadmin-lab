#!/bin/bash
# Aide-mémoire journalctl : chaque commande est exécutée et sa sortie réelle
# est conservée. Les messages de test sont écrits avec logger, tag lab-journal.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 0. Messages de test, à trois priorités =="
logger -p local0.err     -t lab-journal "erreur volontaire du lab (priorite err)"
logger -p local0.warning -t lab-journal "avertissement volontaire du lab (priorite warning)"
logger -p local0.info    -t lab-journal "information volontaire du lab (priorite info)"
sleep 1
journalctl -t lab-journal --no-pager

echo
echo "== 1. Dernières lignes, sans pagination =="
journalctl -n 5 --no-pager

echo
echo "== 2. Journal du démarrage courant, par unité =="
journalctl -b -u lab-nettoyage.service --no-pager | tail -4

echo
echo "== 3. Filtre de priorité : erreurs et plus graves =="
journalctl -p err -b --no-pager | tail -6

echo
echo "== 4. Filtre de priorité : avertissements et plus graves, tag du lab =="
journalctl -p warning -t lab-journal --no-pager

echo
echo "== 5. Fenêtre temporelle =="
journalctl --since "-15 min" --until "+1 min" -t lab-journal --no-pager

echo
echo "== 6. Recherche plein texte =="
journalctl -b -g 'nettoyage :' --no-pager | tail -3

echo
echo "== 7. Par identifiant de processus =="
journalctl _PID=1 -n 3 --no-pager

echo
echo "== 8. Champs disponibles et transports =="
journalctl -F _TRANSPORT --no-pager | sed -n '1,6p'
echo "PRIORITES : $(journalctl -F PRIORITY --no-pager | tr '\n' ' ')"

echo
echo "== 9. Sortie JSON, un enregistrement =="
journalctl -t lab-journal -n 1 -o json-pretty --no-pager | sed -n '1,12p'

echo
echo "== 10. Format verbeux : tous les champs d'un message =="
journalctl -t lab-journal -n 1 -o verbose --no-pager | grep -E 'PRIORITY|SYSLOG_IDENTIFIER|MESSAGE'

echo
echo "== 11. Messages du noyau =="
journalctl -k -n 4 --no-pager

echo
echo "== 12. Volume occupé et intégrité des fichiers =="
journalctl --disk-usage
journalctl --verify 2>&1 | tail -3

echo
echo "== 13. Emplacement réel du journal courant =="
journalctl --header | grep -m2 -E 'File path|Sequential'
