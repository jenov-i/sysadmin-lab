# Aide-mémoire journalctl — 15 commandes testées

Toutes les commandes ci-dessous ont été exécutées sur `srv-debian13` (systemd 257,
Debian 13.2) le 15/11/2026. Les sorties réelles sont dans
[`logs/02-filtres.txt`](logs/02-filtres.txt).

| # | Commande | Ce qu'elle fait |
|---|---|---|
| 1 | `journalctl -n 20 --no-pager` | Les 20 dernières entrées, sans passer par un pager |
| 2 | `journalctl -b` | Tout le démarrage courant |
| 3 | `journalctl -b -1` | Le démarrage précédent |
| 4 | `journalctl --list-boots` | Liste des démarrages conservés, avec leurs bornes |
| 5 | `journalctl -u lab-nettoyage.service` | Entrées d'une unité systemd |
| 6 | `journalctl -p err -b` | Priorité `err` et plus grave, sur le boot courant |
| 7 | `journalctl -p warning -t lab-journal` | Priorité `warning` et plus grave, limité à un tag syslog |
| 8 | `journalctl --since "-15 min" --until "+1 min"` | Fenêtre temporelle relative |
| 9 | `journalctl -g 'nettoyage :'` | Recherche plein texte (regex PCRE) sur le message |
| 10 | `journalctl _PID=1` | Filtre sur un champ : ici le PID 1 |
| 11 | `journalctl -F _TRANSPORT` | Valeurs possibles d'un champ (`syslog`, `journal`, `stdout`, `driver`, `kernel`) |
| 12 | `journalctl -o json-pretty -n 1` | Un enregistrement complet en JSON |
| 13 | `journalctl -o verbose -n 1` | Tous les champs, en clair |
| 14 | `journalctl -k` | Messages du noyau seulement |
| 15 | `journalctl --disk-usage` / `journalctl --verify` | Volume occupé et intégrité des fichiers de journal |

## À retenir

- `-b -1` ne fonctionne que si le journal est persistant : en mode volatil, tout
  disparaît au redémarrage.
- `journalctl` renvoie **1** quand aucun enregistrement ne correspond : dans un
  script en `set -e`, tester le code (`if journalctl ... | grep -q`) ou ajouter
  `|| echo absent`.
- `-p` accepte un nom (`err`, `warning`, `info`) ou un numéro (0–7).
- Sans `--no-pager`, la sortie part dans `less` et bloque un script non interactif.
