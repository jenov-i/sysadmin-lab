#!/bin/bash
# 03 — site statique, hôte virtuel HTTPS, activation et rechargement.
set -euo pipefail

SRC=/root/projet
DOC=/var/www/site.lab.local/html
SAVE=/root/avant-nginx

echo "=== Contenu du site ==="
install -d -m 755 -o www-data -g www-data /var/www/site.lab.local
install -d -m 755 -o www-data -g www-data "$DOC"
install -m 644 -o www-data -g www-data "$SRC/configs/site/index.html" "$DOC/index.html"
install -m 644 -o www-data -g www-data "$SRC/configs/site/style.css"  "$DOC/style.css"
printf 'User-agent: *\nAllow: /\n' > "$DOC/robots.txt"
chown www-data:www-data "$DOC/robots.txt"
chmod 644 "$DOC/robots.txt"
find /var/www/site.lab.local -printf '%M %u:%g %s\t%p\n' | sort -k3

echo
echo "=== Hôte virtuel ==="
install -d -m 755 "$SAVE"
[ -e /etc/nginx/sites-enabled/default ] && cp -a /etc/nginx/sites-enabled/default "$SAVE/default-site.conf"
install -m 644 "$SRC/configs/site.lab.local.conf" /etc/nginx/sites-available/site.lab.local.conf
ln -sfn /etc/nginx/sites-available/site.lab.local.conf /etc/nginx/sites-enabled/site.lab.local.conf
rm -f /etc/nginx/sites-enabled/default
ls -l /etc/nginx/sites-enabled/

echo
echo "=== Validation de la configuration ==="
nginx -t 2>&1

echo
echo "=== Rechargement ==="
systemctl reload nginx
sleep 1
systemctl --no-pager --lines=0 status nginx

echo
echo "=== Ecoute ==="
ss -tlnp | grep -E ':(80|443)\b'
