#!/bin/bash
# Déploie le serveur DNS autoritaire de srv-debian13 et le valide.
# Exécuté tel quel sur la VM le 15/11/2026.
set -euo pipefail

SRC=/root/dns

echo "== 1. Sauvegarde de la configuration d'origine =="
for f in named.conf.options named.conf.local; do
  cp -a "/etc/bind/$f" "/etc/bind/$f.avant-lab"
done
ls -l /etc/bind/*.avant-lab

echo
echo "== 2. Installation des fichiers =="
install -o root -g bind -m 644 "$SRC/named.conf.options" /etc/bind/named.conf.options
install -o root -g bind -m 644 "$SRC/named.conf.local"   /etc/bind/named.conf.local
install -o root -g bind -m 644 "$SRC/db.lab.local"       /etc/bind/db.lab.local
install -o root -g bind -m 644 "$SRC/db.10.0.3"          /etc/bind/db.10.0.3
ls -l /etc/bind/db.lab.local /etc/bind/db.10.0.3

echo
echo "== 3. Validation avant rechargement =="
named-checkconf -z /etc/bind/named.conf
named-checkzone lab.local /etc/bind/db.lab.local
named-checkzone 3.0.10.in-addr.arpa /etc/bind/db.10.0.3

echo
echo "== 4. Redémarrage du service =="
systemctl restart named
sleep 2
systemctl is-active named
ss -ulpn | grep ':53'

echo
echo "== 5. Première résolution =="
dig @10.0.3.10 srv-debian13.lab.local A +short
