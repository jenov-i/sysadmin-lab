#!/bin/bash
# Sauvegarde de /etc dans /var/backups/lab, avec rotation sur les 3 dernières.
# Appelé par cron, sans environnement ni terminal : tout doit être absolu.
set -euo pipefail

DEST=/var/backups/lab
JOURNAL=/var/log/lab-sauvegarde.log
mkdir -p "$DEST"

ARCHIVE="$DEST/etc-$(date +%Y%m%d-%H%M).tar.gz"
# /etc change pendant la lecture (fichiers de lock, resolv.conf...) :
# l'avertissement de tar est normal, on ne veut pas d'échec pour autant.
tar -czf "$ARCHIVE" --warning=no-file-changed /etc 2>/dev/null || true

TAILLE=$(stat -c %s "$ARCHIVE")
printf '%s archive=%s taille=%s octets\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$ARCHIVE" "$TAILLE" >> "$JOURNAL"

# Rotation : ne conserver que les 3 archives les plus récentes.
ls -1t "$DEST"/etc-*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f
