#!/bin/bash
# 04 — batterie de tests : redirection, confiance, protocoles, en-têtes.
# Le nom site.lab.local est résolu localement par /etc/hosts (comme le ferait
# un poste du lab avec son serveur DNS).
set -uo pipefail

CRT=/etc/nginx/tls/site.lab.local.crt
HOTE=site.lab.local

grep -q "$HOTE" /etc/hosts || echo "10.0.3.10 $HOTE www.$HOTE" >> /etc/hosts

echo "=== 0. Résolution et écoute ==="
getent hosts "$HOTE"
ss -tlnp | grep -E ':(80|443)\b'

echo
echo "=== 1. HTTP en clair : redirection 301 ==="
curl -sS -o /dev/null -D - "http://$HOTE/" | sed -n '1,10p'
echo "-- cible de la redirection --"
curl -sS -o /dev/null -D - "http://$HOTE/" | grep -i '^location:'
echo "-- une page précise est conservée --"
curl -sS -o /dev/null -D - "http://$HOTE/style.css" | grep -i '^location:'

echo
echo "=== 2. HTTPS avec le certificat approuvé ==="
curl -sS --cacert "$CRT" -o /dev/null \
  -w 'code=%{http_code} version=%{http_version} tls=%{ssl_verify_result} temps=%{time_total}s\n' \
  "https://$HOTE/"
curl -sS --cacert "$CRT" -o /dev/null \
  -w 'code=%{http_code} version=%{http_version}\n' "https://www.$HOTE/"

echo
echo "=== 3. HTTPS sans approuver le certificat (doit échouer) ==="
curl -sS -o /dev/null "https://$HOTE/" ; echo "code de sortie curl : $?"

echo
echo "=== 4. En-têtes de la page et d'un fichier statique ==="
curl -sS --cacert "$CRT" -D - -o /dev/null "https://$HOTE/" | sed -n '1,20p'
echo "-- style.css --"
curl -sS --cacert "$CRT" -D - -o /dev/null "https://$HOTE/style.css" | sed -n '1,20p'

echo
echo "=== 5. Le contenu servi est bien le fichier déposé ==="
curl -sS --cacert "$CRT" "https://$HOTE/" -o /tmp/page-servie.html
sha256sum /tmp/page-servie.html /var/www/site.lab.local/html/index.html

echo
echo "=== 6. Handshake TLS 1.3 ==="
openssl s_client -connect 10.0.3.10:443 -servername "$HOTE" -CAfile "$CRT" \
  -verify_return_error -brief </dev/null 2>&1 | sed -n '1,12p'

echo
echo "=== 7. Handshake TLS 1.2 ==="
openssl s_client -connect 10.0.3.10:443 -servername "$HOTE" -CAfile "$CRT" \
  -tls1_2 -verify_return_error -brief </dev/null 2>&1 | sed -n '1,8p'

echo
echo "=== 8. Négociation ALPN (HTTP/2) ==="
openssl s_client -connect 10.0.3.10:443 -servername "$HOTE" -alpn h2,http/1.1 \
  </dev/null 2>/dev/null | grep -E "ALPN protocol|Protocol|Cipher is" 

echo
echo "=== 9. Refus des protocoles obsolètes ==="
for v in tls1 tls1_1; do
  echo "-- $v --"
  timeout 10 openssl s_client -connect 10.0.3.10:443 -servername "$HOTE" -"$v" \
    </dev/null 2>&1 | grep -iE "error|alert|no protocols|Cipher is|Protocol" | head -3
  echo "code : ${PIPESTATUS[0]}"
done

echo
echo "=== 9b. Même essai en abaissant le niveau de sécurité du client ==="
echo "(sans cela, OpenSSL refuse lui-même TLS 1.0/1.1 avant tout échange :"
echo " la mesure porterait sur le client et non sur le serveur)"
for v in tls1 tls1_1; do
  echo "-- $v --"
  timeout 10 openssl s_client -connect 10.0.3.10:443 -servername "$HOTE" -"$v" \
    -cipher 'DEFAULT@SECLEVEL=0' </dev/null 2>&1 \
    | grep -iE "alert|error|no peer certificate|Cipher is" | head -3
done

echo
echo "=== 10. Chemin inexistant ==="
curl -sS --cacert "$CRT" -o /dev/null -w 'code=%{http_code}\n' "https://$HOTE/inexistant"

echo
echo "=== 11. Journal d'accès du site ==="
tail -n 8 /var/log/nginx/site.lab.local.access.log
echo
echo "=== 12. Journal d'erreurs ==="
if [ -s /var/log/nginx/site.lab.local.error.log ]; then
  tail -n 10 /var/log/nginx/site.lab.local.error.log
else
  echo "(vide)"
fi
