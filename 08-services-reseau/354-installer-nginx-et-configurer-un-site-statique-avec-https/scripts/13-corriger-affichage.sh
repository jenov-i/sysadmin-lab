#!/bin/bash
# 13 — la carte « Contenu » débordait sur la capture : la valeur longue
# (/var/www/site.lab.local/html) sortait du cadre. Correction du CSS et
# redéploiement du seul fichier concerné.
set -euo pipefail

SRC=/root/projet/configs/site/style.css
DOC=/var/www/site.lab.local/html

grep -n "overflow-wrap\|max-content" "$SRC"

install -m 644 -o www-data -g www-data "$SRC" "$DOC/style.css"
echo
echo "--- empreintes ---"
sha256sum "$SRC" "$DOC/style.css"
echo
echo "--- ce que sert nginx ---"
curl -sS --cacert /etc/nginx/tls/site.lab.local.crt "https://site.lab.local/style.css" \
  | sha256sum
echo "code : $(curl -sS -o /dev/null -w '%{http_code}' --cacert /etc/nginx/tls/site.lab.local.crt \
  https://site.lab.local/style.css)"
