#!/bin/bash
# Résumé compact pour la capture console : le certificat.
set -uo pipefail
CRT=/etc/nginx/tls/site.lab.local.crt
KEY=/etc/nginx/tls/site.lab.local.key
SUBJ=$(openssl x509 -in "$CRT" -noout -subject | sed 's/^subject=//')
ISSU=$(openssl x509 -in "$CRT" -noout -issuer | sed 's/^issuer=//')

echo "Certificat auto-signé — /etc/nginx/tls"
echo "sujet    : $(echo "$SUBJ" | grep -o 'CN=[^,]*')"
echo "           $(echo "$SUBJ" | sed 's/ST=[^,]*, L=[^,]*, //; s/, CN=[^,]*$//')"
openssl x509 -in "$CRT" -noout -dates
echo
echo "--- extensions ---"
openssl x509 -in "$CRT" -noout -ext basicConstraints,keyUsage,extendedKeyUsage,subjectAltName
echo
echo "--- contrôles ---"
echo "clé        : RSA $(openssl x509 -in "$CRT" -noout -text | grep -m1 'Public-Key' | tr -dc '0-9') bits"
echo "signature  : $(openssl x509 -in "$CRT" -noout -text | grep -m1 'Signature Algorithm' | sed 's/.*: //')"
echo "auto-signé : $( [ "$SUBJ" = "$ISSU" ] && echo 'émetteur = sujet' || echo 'non')"
echo "empreinte  : $(openssl x509 -in "$CRT" -noout -fingerprint -sha256 | sed 's/.*=//' | cut -c1-55)…"
echo "clé privée : $(stat -c '%A %U:%G' "$KEY")"
echo "appariement: $( [ "$(openssl x509 -in "$CRT" -noout -pubkey | openssl sha256)" = \
  "$(openssl pkey -in "$KEY" -pubout | openssl sha256)" ] \
  && echo 'clé publique identique dans .crt et .key' || echo 'DIFFÉRENTE')"
echo "vérification : $(openssl verify -CAfile "$CRT" "$CRT" 2>&1 | sed 's|.*crt: ||')"
