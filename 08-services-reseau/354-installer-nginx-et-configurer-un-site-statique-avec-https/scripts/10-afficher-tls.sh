#!/bin/bash
# Résumé compact pour la capture console : protocoles et en-têtes TLS.
set -uo pipefail
H=site.lab.local
CRT=/etc/nginx/tls/site.lab.local.crt

echo "TLS négocié — site.lab.local:443"
echo
echo "--- TLS 1.3 ---"
openssl s_client -connect 10.0.3.10:443 -servername "$H" -CAfile "$CRT" -tls1_3 \
  -brief </dev/null 2>&1 | grep -E 'Protocol version|Ciphersuite|Verification|group' | sed 's/^/  /'
echo
echo "--- TLS 1.2 ---"
openssl s_client -connect 10.0.3.10:443 -servername "$H" -CAfile "$CRT" -tls1_2 \
  -brief </dev/null 2>&1 | grep -E 'Protocol version|Ciphersuite|Verification' | sed 's/^/  /'
echo
echo "--- ALPN ---"
printf "  "; openssl s_client -connect 10.0.3.10:443 -servername "$H" -alpn h2,http/1.1 \
  </dev/null 2>/dev/null | grep 'ALPN protocol'
echo
echo "--- protocoles obsolètes (client abaissé à SECLEVEL=0) ---"
for v in tls1 tls1_1; do
  msg=$(timeout 10 openssl s_client -connect 10.0.3.10:443 -servername "$H" -"$v" \
        -cipher 'DEFAULT@SECLEVEL=0' </dev/null 2>&1 | grep -m1 -o 'alert protocol version')
  echo "  $v : ${msg:-accepté}"
done
echo
echo "--- journaux ---"
echo "  accès : $(wc -l < /var/log/nginx/site.lab.local.access.log) lignes · \
erreurs : $( [ -s /var/log/nginx/site.lab.local.error.log ] && wc -l < /var/log/nginx/site.lab.local.error.log || echo 0) ligne(s)"
tail -n 3 /var/log/nginx/site.lab.local.access.log | sed 's/^/  /'
