#!/bin/bash
# Construit un dépôt APT local servi par nginx sur srv-debian13.
# Exécuté tel quel sur la VM le 15/11/2026.
set -euo pipefail

DEPOT=/srv/depot
PORT=8080

echo "== 1. Outils =="
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq dpkg-dev apt-utils nginx >/dev/null
echo "dpkg-dev $(dpkg-query -W -f='${Version}' dpkg-dev) · nginx $(dpkg-query -W -f='${Version}' nginx)"

echo
echo "== 2. Récupération des paquets =="
mkdir -p "$DEPOT/pool"
# Téléchargement dans un répertoire lisible par l'utilisateur _apt : sinon apt
# prévient « Download is performed unsandboxed as root ».
TMP=$(mktemp -d)
cd "$TMP"
for pkg in sl tree htop; do
  apt-get download "$pkg"
done
mv ./*.deb "$DEPOT/pool/"
rmdir "$TMP"
cd "$DEPOT"
ls -lh pool/

echo
echo "== 3. Index du dépôt =="
apt-ftparchive packages pool > Packages
gzip -kf Packages
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="sysadmin-lab" \
  -o APT::FTPArchive::Release::Label="Dépôt local sysadmin-lab" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Codename="trixie" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  release . > Release
head -8 Release

echo
echo "== 4. Publication HTTP =="
cat > /etc/nginx/sites-available/depot <<CONF
server {
    listen ${PORT};
    listen [::]:${PORT};
    server_name _;
    root ${DEPOT};
    autoindex on;
}
CONF
ln -sf /etc/nginx/sites-available/depot /etc/nginx/sites-enabled/depot
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo "nginx écoute :"
ss -tlnp | grep ":${PORT}"

echo
echo "== 5. Déclaration côté client =="
echo "deb [trusted=yes] http://127.0.0.1:${PORT}/ ./" > /etc/apt/sources.list.d/depot-local.list
apt-get update -qq
echo "sources du dépôt :"
apt-cache policy | grep -A1 "127.0.0.1" | head -4
