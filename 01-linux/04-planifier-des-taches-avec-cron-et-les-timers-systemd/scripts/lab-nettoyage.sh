#!/bin/bash
# Tâche systemd : compte les archives et l'espace libre, et l'écrit dans le journal.
set -euo pipefail

NB=$(find /var/backups/lab -name 'etc-*.tar.gz' | wc -l)
LIBRE=$(df -h /var/backups | awk 'NR==2 {print $4}')
echo "[$(date '+%Y-%m-%d %H:%M:%S')] nettoyage : ${NB} archives, ${LIBRE} libres sur /var"
