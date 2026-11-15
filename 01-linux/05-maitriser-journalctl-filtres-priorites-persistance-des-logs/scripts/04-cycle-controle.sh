#!/bin/bash
# Cycle contrôlé : volatil → retour à la configuration par défaut, en suivant
# le PID de journald et l'emplacement réel du journal à chaque étape.
# Exécuté sur srv-debian13 le 15/11/2026 après un premier redémarrage.
set -euo pipefail

etat() {
  echo "PID journald : $(systemctl show -p MainPID --value systemd-journald)"
  journalctl --header | grep 'File path' | sed -n '1,3p'
}

echo "== 1. État de départ, configuration par défaut =="
grep -n '^#\?Storage' /etc/systemd/journald.conf
etat

echo
echo "== 2. Bascule en Storage=volatile =="
cat > /etc/systemd/journald.conf.d/90-lab-volatile.conf <<'EOF'
[Journal]
Storage=volatile
EOF
systemctl restart systemd-journald
sleep 2
etat
logger -p local0.notice -t lab-journal "MARQUEUR-VOLATIL-2 ecrit en mode volatil"
sleep 1
journalctl -t lab-journal -g MARQUEUR-VOLATIL-2 -o cat --no-pager

echo
echo "== 3. Retour à la configuration par défaut, service redémarré =="
rm -f /etc/systemd/journald.conf.d/90-lab-volatile.conf
systemctl restart systemd-journald
sleep 3
etat
logger -p local0.notice -t lab-journal "MARQUEUR-RETOUR-2 ecrit apres le retour"
sleep 1
journalctl -t lab-journal -g MARQUEUR-RETOUR-2 -o cat --no-pager

echo
echo "== 4. Où chaque marqueur est réellement stocké =="
for tag in VOLATIL-2 RETOUR-2; do
  printf -- '--- %s\n' "$tag"
  if journalctl --header -g "$tag" 2>/dev/null | grep -q 'File path'; then
    journalctl --header -g "$tag" 2>/dev/null | grep 'File path' | tail -2
  else
    echo "pas de fichier identifié par --header pour ce filtre"
  fi
  grep -l "$tag" /run/log/journal/*/system*.journal 2>/dev/null && echo "(présent dans /run)" || echo "(absent de /run)"
done
