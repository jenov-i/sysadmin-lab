#!/bin/bash
# Vérifie le certificat serveur en conditions réelles : HTTPS avec la CA,
# handshake détaillé, puis refus quand la CA ou le nom ne correspondent pas.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

CA=/root/pki/ca.crt
HOTE=srv-debian13.lab.local
IP=10.0.3.10

echo "== 1. Requête HTTPS validée par la CA du lab =="
curl -sS --cacert "$CA" --resolve "$HOTE:8443:$IP" "https://$HOTE:8443/" \
  | grep -o '<h1>.*</h1>'
curl -sS -o /dev/null -w 'code HTTP %{http_code} · ssl_verify_result %{ssl_verify_result}\n' \
  --cacert "$CA" --resolve "$HOTE:8443:$IP" "https://$HOTE:8443/"

echo
echo "== 2. Handshake OpenSSL avec vérification du nom =="
openssl s_client -connect "$IP:8443" -servername "$HOTE" \
  -CAfile "$CA" -verify_hostname "$HOTE" -verify_return_error </dev/null 2>&1 \
  | grep -E 'depth=|verify error|Verify return code|subject=|issuer=|Protocol|Cipher is'

echo
echo "== 3. Sans la CA, la chaîne n'est pas reconnue =="
if curl -sS -o /dev/null --resolve "$HOTE:8443:$IP" "https://$HOTE:8443/" 2>/tmp/curl-sans-ca.err; then
  echo "INATTENDU : accepté sans la CA"
else
  echo "refusé : $(grep -o 'SSL certificate problem.*' /tmp/curl-sans-ca.err | head -1)"
fi

echo
echo "== 4. Mauvais nom d'hôte : la chaîne est bonne, le nom non =="
if openssl s_client -connect "$IP:8443" -servername "$HOTE" \
     -CAfile "$CA" -verify_hostname mauvais.lab.local -verify_return_error \
     </dev/null >/tmp/tls-mauvais-nom.log 2>&1; then
  echo "INATTENDU : accepté avec un mauvais nom"
else
  grep -E 'verify error|Verify return code' /tmp/tls-mauvais-nom.log | head -3
fi
