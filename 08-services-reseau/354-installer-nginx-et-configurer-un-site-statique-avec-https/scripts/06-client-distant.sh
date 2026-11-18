#!/bin/bash
# 06 — test depuis un client extérieur au serveur.
#   ./06-client-distant.sh <adresse-du-serveur> <port> <certificat-public>
set -uo pipefail

SERVEUR=${1:?adresse du serveur}
PORT=${2:?port HTTPS}
CRT=${3:?chemin du certificat}
HOTE=site.lab.local
RESOLVE="--resolve $HOTE:$PORT:$SERVEUR"

echo "client      : $(hostname) — $(ip -brief address show scope global | awk '{print $3}' | paste -sd, -)"
echo "serveur     : $SERVEUR:$PORT (nom $HOTE)"
echo

echo "=== Redirection HTTP (port 8080) ==="
curl -sS -o /dev/null -D - --resolve "$HOTE:8080:$SERVEUR" "http://$HOTE:8080/" \
  | sed -n '1,4p'

echo
echo "=== Page servie en HTTPS ==="
curl -sS --cacert "$CRT" $RESOLVE -o /tmp/page-distante.html \
  -w 'code=%{http_code} version=%{http_version} tls=%{ssl_verify_result}\n' \
  "https://$HOTE:$PORT/"
sha256sum /tmp/page-distante.html

echo
echo "=== Sans le certificat : rejet attendu ==="
curl -sS -o /dev/null $RESOLVE "https://$HOTE:$PORT/" ; echo "code de sortie : $?"

echo
echo "=== Handshake vu du client ==="
openssl s_client -connect "$SERVEUR:$PORT" -servername "$HOTE" -CAfile "$CRT" \
  -verify_return_error -brief </dev/null 2>&1 | sed -n '1,10p'

echo
echo "=== Détail du certificat reçu ==="
openssl s_client -connect "$SERVEUR:$PORT" -servername "$HOTE" </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -fingerprint -sha256 -ext subjectAltName
