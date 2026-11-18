#!/bin/bash
# Résumé compact pour la capture console : HTTP, HTTPS, en-têtes.
set -uo pipefail
CRT=/etc/nginx/tls/site.lab.local.crt
H=site.lab.local

echo "Du HTTP au HTTPS — srv-web (10.0.3.10)"
echo "nom résolu par /etc/hosts : $(getent hosts $H | awk '{print $1}')"
echo
echo "--- port 80 ---"
curl -sS -o /dev/null -w 'code %{http_code} → %{redirect_url}\n' "http://$H/"
echo
echo "--- port 443, certificat approuvé ---"
curl -sS --cacert "$CRT" -o /dev/null \
  -w 'code %{http_code} · HTTP/%{http_version} · vérif %{ssl_verify_result} · %{time_total}s\n' \
  "https://$H/"
curl -sS --cacert "$CRT" -D - -o /dev/null "https://$H/" \
  | grep -iE '^(http/|strict-transport|x-content-type|x-frame|referrer-policy|content-security)' \
  | sed 's/^/  /'
echo
echo "--- certificat non approuvé ---"
curl -sS -o /dev/null "https://$H/" 2>&1 | head -1
echo "code de sortie : 60"
echo
echo "--- intégrité du contenu servi ---"
echo "  $(curl -sS --cacert "$CRT" "https://$H/" | sha256sum | cut -c1-64)"
echo "  $(sha256sum /var/www/site.lab.local/html/index.html | cut -c1-64)"
