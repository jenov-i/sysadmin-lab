#!/bin/bash
# Vérifie le routage de bout en bout, puis prouve que la panne vient bien
# de la route statique et pas d'autre chose.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Chemin choisi par le client =="
ip netns exec client ip route get 192.168.30.10

echo
echo "== 2. Ping client -> serveur =="
ip netns exec client ping -c 3 -W 1 192.168.30.10

echo
echo "== 3. Chemin réel, saut par saut =="
ip netns exec client traceroute -n -w 1 -q 1 192.168.30.10

echo
echo "== 4. Retour serveur -> client =="
ip netns exec serveur ping -c 2 -W 1 192.168.10.10

echo
echo "== 5. Table de routage de R2 =="
ip -n r2 route
