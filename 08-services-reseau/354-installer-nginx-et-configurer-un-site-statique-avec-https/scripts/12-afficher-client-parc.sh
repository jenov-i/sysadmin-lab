#!/bin/bash
# Requête réelle depuis lab-linux-01 vers srv-web, affichage compact pour la
# capture de la console. Le certificat public a été copié dans /tmp.
set -uo pipefail
CRT=/tmp/site.lab.local.crt
H=site.lab.local
S=192.168.99.1
P=8443

echo
echo
echo "lab-linux-01 → srv-web (VM QEMU, redirection 8443 de l'hôte)"
echo "client : $(hostname) · $(ip -brief address show scope global | awk '{print $3}' | paste -sd, -)"
echo
echo "--- requête HTTPS ---"
curl -sS --cacert "$CRT" --resolve "$H:$P:$S" -o /tmp/page-client.html \
  -w 'code %{http_code} · HTTP/%{http_version} · vérif %{ssl_verify_result} · %{time_total}s\n' \
  "https://$H:$P/"
echo "sha256 reçu : $(sha256sum /tmp/page-client.html | cut -c1-64)"
echo
echo "--- en-têtes reçus ---"
curl -sS --cacert "$CRT" --resolve "$H:$P:$S" -D - -o /dev/null "https://$H:$P/" \
  | sed -n '1p;/^strict-transport/p;/^content-security/p' | sed 's/^/  /'
echo
echo "--- sans approuver le certificat ---"
curl -sS --resolve "$H:$P:$S" -o /dev/null "https://$H:$P/" 2>&1 | head -1
echo
echo "--- handshake vu du client ---"
openssl s_client -connect "$S:$P" -servername "$H" -CAfile "$CRT" -brief </dev/null 2>&1 \
  | grep -E 'Protocol version|Ciphersuite|Verification|Temp Key' | sed 's/^/  /'
