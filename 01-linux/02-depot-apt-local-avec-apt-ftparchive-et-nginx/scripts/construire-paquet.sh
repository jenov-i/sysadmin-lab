#!/bin/bash
# Construit un paquet Debian maison (lab-bienvenue) et l'injecte dans le dépôt local.
set -euo pipefail

BUILD=/tmp/build-lab-bienvenue
DEPOT=/srv/depot

rm -rf "$BUILD"
mkdir -p "$BUILD/DEBIAN" "$BUILD/usr/local/bin" "$BUILD/usr/share/doc/lab-bienvenue"

cat > "$BUILD/DEBIAN/control" <<CTRL
Package: lab-bienvenue
Version: 1.0
Architecture: all
Maintainer: Jenovi Dandou <dandoujenovi@gmail.com>
Section: admin
Priority: optional
Depends: coreutils
Description: Message d'accueil des serveurs du lab sysadmin-lab
 Installe la commande bienvenue, qui affiche le role du serveur,
 son nom et les volumes logiques montes.
CTRL

cat > "$BUILD/usr/local/bin/bienvenue" <<'CMD'
#!/bin/sh
echo "Bienvenue sur $(hostname) — $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "Role : serveur du lab sysadmin-lab"
echo "Volumes montes :"
findmnt -rno TARGET,SOURCE,FSTYPE | grep -E "^/( |$)|^/(boot|var|home|tmp) " | sort
CMD
chmod 755 "$BUILD/usr/local/bin/bienvenue"

cat > "$BUILD/usr/share/doc/lab-bienvenue/README" <<'DOC'
Paquet interne du lab sysadmin-lab.
Construit avec dpkg-deb, distribue par le depot APT local (nginx + apt-ftparchive).
DOC

dpkg-deb --build --root-owner-group "$BUILD" "$DEPOT/pool/lab-bienvenue_1.0_all.deb"
cd "$DEPOT"
apt-ftparchive packages pool > Packages
gzip -kf Packages
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="sysadmin-lab" \
  -o APT::FTPArchive::Release::Label="Dépôt local sysadmin-lab" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Codename="trixie" \
  -o APT::FTPArchive::Release::Architectures="amd64" \
  release . > Release
apt-get update -qq
echo "paquets dans l'index :"
grep -c '^Package:' Packages
