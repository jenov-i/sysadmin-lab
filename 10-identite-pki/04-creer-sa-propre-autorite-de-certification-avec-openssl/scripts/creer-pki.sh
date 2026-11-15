#!/bin/bash
# Crée la CA racine du lab, émet le certificat serveur et publie le site en HTTPS.
# Exécuté tel quel sur srv-debian13 le 15/11/2026.
set -euo pipefail

PKI=/root/pki
CONF=$PKI/openssl.cnf

echo "== 1. Arborescence de la CA =="
mkdir -p "$PKI"/{newcerts,crl,certs}
chmod 700 "$PKI"
: > "$PKI/index.txt"
printf '1000\n' > "$PKI/serial"
printf '1000\n' > "$PKI/crlnumber"
# Phrase de passe de la clé racine : fichier 600, jamais publié.
od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > "$PKI/ca.pass"
chmod 600 "$PKI/ca.pass"
ls -l "$PKI"

echo
echo "== 2. Clé et certificat racine =="
openssl genrsa -aes256 -passout file:"$PKI/ca.pass" -out "$PKI/ca.key" 4096 2>/dev/null
openssl req -x509 -new -sha256 -days 3650 \
  -key "$PKI/ca.key" -passin file:"$PKI/ca.pass" \
  -config "$CONF" -extensions v3_ca \
  -subj "/C=FR/O=Lab sysadmin-lab/OU=PKI/CN=lab-sysadmin Root CA" \
  -out "$PKI/ca.crt"
openssl x509 -in "$PKI/ca.crt" -noout -subject -issuer -dates
openssl x509 -in "$PKI/ca.crt" -noout -text | grep -A2 'Basic Constraints'

echo
echo "== 3. Clé et demande du serveur =="
openssl genrsa -out "$PKI/certs/server.key" 2048 2>/dev/null
openssl req -new -sha256 -key "$PKI/certs/server.key" \
  -config "$CONF" \
  -subj "/C=FR/O=Lab sysadmin-lab/CN=srv-debian13.lab.local" \
  -out "$PKI/certs/server.csr"
openssl req -in "$PKI/certs/server.csr" -noout -subject

echo
echo "== 4. Signature par la CA =="
openssl ca -batch -config "$CONF" \
  -passin file:"$PKI/ca.pass" \
  -extensions server_cert -days 397 -notext -md sha256 \
  -in "$PKI/certs/server.csr" -out "$PKI/certs/server.crt"
openssl x509 -in "$PKI/certs/server.crt" -noout -subject -issuer -dates

echo
echo "== 5. Chaîne vérifiée =="
openssl verify -CAfile "$PKI/ca.crt" "$PKI/certs/server.crt"
openssl x509 -in "$PKI/certs/server.crt" -noout -ext subjectAltName,extendedKeyUsage

echo
echo "== 6. Publication HTTPS =="
install -d -m 750 /etc/nginx/ssl
install -m 644 "$PKI/certs/server.crt" /etc/nginx/ssl/server.crt
install -m 600 "$PKI/certs/server.key" /etc/nginx/ssl/server.key
install -d -m 755 /srv/www-tls
cat > /srv/www-tls/index.html <<'HTML'
<!doctype html>
<html lang="fr">
<head><meta charset="utf-8"><title>Site interne — lab.local</title></head>
<body style="font-family:sans-serif;padding:2rem">
<h1>Site interne du lab</h1>
<p>Servi par nginx en HTTPS avec un certificat émis par la CA <strong>lab-sysadmin Root CA</strong>.</p>
<p>Nom vérifié : <code>srv-debian13.lab.local</code> — port 8443.</p>
</body>
</html>
HTML
install -m 644 /root/nginx-tls.conf /etc/nginx/sites-available/tls-lab
ln -sf /etc/nginx/sites-available/tls-lab /etc/nginx/sites-enabled/tls-lab
nginx -t
systemctl reload nginx
ss -tlnp | grep 8443
