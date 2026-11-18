#!/bin/bash
# Résumé compact pour la capture console : installation et service.
set -uo pipefail
. /etc/os-release

echo "srv-web — installation et état du service"
echo "système : $PRETTY_NAME — noyau $(uname -r)"
printf "paquets : nginx %s · openssl %s\n" \
  "$(dpkg-query -W -f='${Version}' nginx)" "$(dpkg-query -W -f='${Version}' openssl)"
echo "service : $(systemctl is-enabled nginx) / $(systemctl is-active nginx)"
echo "ens4    : $(ip -brief address show ens4 | awk '{print $2, $3}')"
echo "ens3    : $(ip -brief address show ens3 | awk '{print $2, $3}')"
echo
echo "--- écoute ---"
ss -tln | awk 'NR==1 || /:80 |:443 /'
echo
echo "--- fichiers du site ---"
find /var/www/site.lab.local -type f -printf '%M %u:%g %6s  %p\n' | sort -k4
echo
echo "--- certificat et clé ---"
ls -l /etc/nginx/tls/
