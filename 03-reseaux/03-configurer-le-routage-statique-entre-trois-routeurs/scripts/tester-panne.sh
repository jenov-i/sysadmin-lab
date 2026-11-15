#!/bin/bash
# Casse volontairement une route sur R1, montre la panne, puis restaure
# et remontre le fonctionnement. C'est la preuve que la connectivité
# dépend bien des routes statiques configurées.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Route présente sur R1 =="
ip -n r1 route
PING="ping -c 2 -W 1 192.168.30.10"
echo "--- ping avant la panne"
ip netns exec client $PING

echo
echo "== 2. Suppression de la route 192.168.30.0/24 sur R1 =="
ip -n r1 route del 192.168.30.0/24 via 10.0.12.2
ip -n r1 route
echo "--- ping pendant la panne"
if ip netns exec client $PING; then
  echo "INATTENDU : le ping passe encore"
else
  echo "-> échec attendu : R1 n'a plus de route vers le LAN serveur"
fi

echo
echo "== 3. Remise en place de la route =="
ip -n r1 route add 192.168.30.0/24 via 10.0.12.2
ip -n r1 route
echo "--- ping après restauration"
ip netns exec client $PING
