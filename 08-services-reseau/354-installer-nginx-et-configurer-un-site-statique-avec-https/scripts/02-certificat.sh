#!/bin/bash
# 02 — clé privée et certificat auto-signé avec les noms du site.
set -euo pipefail

CONF=/root/projet/configs/openssl-san.cnf
TLS=/etc/nginx/tls
CRT=$TLS/site.lab.local.crt
KEY=$TLS/site.lab.local.key

install -d -m 750 -o root -g root "$TLS"

echo "=== Génération (RSA 3072, SHA-256) ==="
openssl req -x509 -new -newkey rsa:3072 -nodes -sha256 -days 825 \
  -config "$CONF" -keyout "$KEY" -out "$CRT" 2>/dev/null
chmod 600 "$KEY"
chmod 644 "$CRT"
ls -l "$TLS"

echo
echo "=== Contenu du certificat ==="
openssl x509 -in "$CRT" -noout -subject -issuer -serial -dates -fingerprint -sha256
echo
openssl x509 -in "$CRT" -noout -text \
  | sed -n '/X509v3 extensions/,/Signature Algorithm/p' | sed '$d'

echo
echo "=== Contrôles ==="
openssl rsa -in "$KEY" -noout -check
echo
echo "-- le certificat est bien auto-signé (émetteur = sujet) --"
openssl x509 -in "$CRT" -noout -subject -issuer
echo
echo "-- vérification en tant que racine de confiance --"
openssl verify -CAfile "$CRT" "$CRT" || true
echo
echo "-- la clé et le certificat vont-ils ensemble ? --"
A=$(openssl x509 -in "$CRT" -noout -pubkey | openssl sha256 | awk '{print $NF}')
B=$(openssl pkey -in "$KEY" -pubout | openssl sha256 | awk '{print $NF}')
echo "certificat : $A"
echo "clé        : $B"
[ "$A" = "$B" ] && echo "identiques : OK" || { echo "DIFFERENTES"; exit 1; }
