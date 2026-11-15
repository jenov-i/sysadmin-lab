#!/bin/bash
# Simule un client du lab : bascule temporairement /etc/resolv.conf sur le
# serveur Bind9, résout des noms dans les deux sens, puis restaure le résolveur
# systemd.
#
# Deux pièges évités ici :
#  - /etc/resolv.conf est un lien symbolique : écrire dedans modifierait le
#    fichier de systemd-resolved, il faut d'abord supprimer le lien.
#  - nsswitch.conf place « resolve » avant « dns » : getent passe par
#    systemd-resolved, qui ne connaît pas lab.local. `getent -s dns` force le
#    module DNS et interroge réellement 10.0.3.10.
set -euo pipefail

SAVE=/tmp/resolv.conf.avant-test

restaurer() {
  if [ -e "$SAVE" ] || [ -L "$SAVE" ]; then
    rm -f /etc/resolv.conf
    mv "$SAVE" /etc/resolv.conf
  fi
}
trap restaurer EXIT

echo "== 1. Résolveur actuel =="
ls -l /etc/resolv.conf
grep -vE '^#|^$' /etc/resolv.conf

echo
echo "== 2. Bascule du client sur 10.0.3.10 =="
rm -f "$SAVE"
cp -a /etc/resolv.conf "$SAVE"
rm -f /etc/resolv.conf
printf 'nameserver 10.0.3.10\nsearch lab.local\n' > /etc/resolv.conf
cat /etc/resolv.conf

echo
echo "== 3. Résolution directe (getent, comme n'importe quelle application) =="
for nom in www.lab.local intranet.lab.local mail.lab.local; do
  getent -s dns hosts "$nom"
done

echo
echo "== 4. Résolution inverse =="
getent -s dns hosts 10.0.3.10
dig +short -x 10.0.3.10

echo
echo "== 5. Restauration du résolveur systemd =="
restaurer
trap - EXIT
ls -l /etc/resolv.conf
