#!/bin/bash
# Émet un second certificat, le révoque, publie la CRL et vérifie que la
# révocation est bien appliquée — sans toucher au certificat du serveur.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

PKI=/root/pki
CONF=$PKI/openssl.cnf
PASSIN="file:$PKI/ca.pass"

echo "== 1. Émission d'un certificat de test =="
openssl genrsa -out "$PKI/certs/obsolete.key" 2048 2>/dev/null
openssl req -new -sha256 -key "$PKI/certs/obsolete.key" -config "$CONF" \
  -subj "/C=FR/O=Lab sysadmin-lab/CN=obsolete.lab.local" \
  -out "$PKI/certs/obsolete.csr"
openssl ca -batch -config "$CONF" -passin "$PASSIN" \
  -extensions server_cert -days 30 -notext -md sha256 \
  -in "$PKI/certs/obsolete.csr" -out "$PKI/certs/obsolete.crt" 2>/dev/null
openssl verify -CAfile "$PKI/ca.crt" "$PKI/certs/obsolete.crt"

echo
echo "== 2. Révocation =="
openssl ca -config "$CONF" -passin "$PASSIN" -revoke "$PKI/certs/obsolete.crt"
echo "ligne de la base de la CA :"
grep obsolete "$PKI/index.txt"

echo
echo "== 3. Publication de la CRL =="
openssl ca -config "$CONF" -passin "$PASSIN" -gencrl -out "$PKI/crl/ca.crl" 2>/dev/null
openssl crl -in "$PKI/crl/ca.crl" -noout -lastupdate -nextupdate
openssl crl -in "$PKI/crl/ca.crl" -noout -text | sed -n '/Revoked Certificates/,/Signature Algorithm/p' | head -6

echo
echo "== 4. Vérification avec la CRL =="
if openssl verify -CAfile "$PKI/ca.crt" -crl_check -CRLfile "$PKI/crl/ca.crl" \
     "$PKI/certs/obsolete.crt"; then
  echo "INATTENDU : le certificat révoqué est accepté"
else
  echo "-> refus attendu ci-dessus (error 23 = certificate revoked)"
fi

echo
echo "== 5. Le certificat du serveur reste valide =="
openssl verify -CAfile "$PKI/ca.crt" -crl_check -CRLfile "$PKI/crl/ca.crl" \
  "$PKI/certs/server.crt"
