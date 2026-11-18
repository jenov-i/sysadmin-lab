#!/bin/bash
# Résumé compact pour la capture de l'après-redémarrage.
set -uo pipefail
CRT=/etc/nginx/tls/site.lab.local.crt
H=site.lab.local

echo "srv-web — après redémarrage"
echo "démarrage : $(uptime -s)   ·   maintenant : $(date +%H:%M:%S)"
echo "service   : $(systemctl is-enabled nginx) / $(systemctl is-active nginx)"
echo "adresse   : ens4 $(ip -brief address show ens4 | awk '{print $3}')"
echo
echo "--- écoute ---"
ss -tln | awk 'NR==1 || /:80 |:443 /'
echo
echo "--- chaîne complète ---"
curl -sS -o /dev/null -w '  http  : %{http_code} → %{redirect_url}\n' "http://$H/"
curl -sS --cacert "$CRT" -o /tmp/apres.html \
  -w '  https : %{http_code} · HTTP/%{http_version} · vérif %{ssl_verify_result}\n' "https://$H/"
echo "  contenu : $(sha256sum /tmp/apres.html | cut -c1-64)"
echo "  fichier : $(sha256sum /var/www/site.lab.local/html/index.html | cut -c1-64)"
echo
echo "--- certificat inchangé ---"
echo "  $(openssl x509 -in "$CRT" -noout -enddate)"
echo "  $(openssl x509 -in "$CRT" -noout -fingerprint -sha256 | sed 's/.*=//' | cut -c1-55)…"
