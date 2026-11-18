#!/bin/bash
# 05 — après redémarrage : le site revient-il tout seul ?
set -uo pipefail

CRT=/etc/nginx/tls/site.lab.local.crt
HOTE=site.lab.local

echo "=== Redémarrage précédent / démarrage courant ==="
uptime -s
echo "maintenant : $(date -Is)"

echo
echo "=== Services ==="
systemctl is-enabled nginx
systemctl is-active nginx
ss -tlnp | grep -E ':(80|443)\b'

echo
echo "=== Chaîne complète après démarrage ==="
curl -sS -o /dev/null -D - "http://$HOTE/" | sed -n '1,4p'
curl -sS --cacert "$CRT" -o /dev/null \
  -w 'code=%{http_code} version=%{http_version}\n' "https://$HOTE/"

echo
echo "=== Certificat toujours en place ==="
openssl x509 -in "$CRT" -noout -subject -dates -fingerprint -sha256

echo
echo "=== Adresse fixe ==="
ip -brief address show ens4

echo
echo "=== Journal nginx depuis le démarrage ==="
journalctl -u nginx --since "$(uptime -s)" --no-pager | tail -n 10
