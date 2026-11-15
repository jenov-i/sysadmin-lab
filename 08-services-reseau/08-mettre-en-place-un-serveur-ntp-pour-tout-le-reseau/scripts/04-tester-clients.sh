#!/bin/bash
# Deux clients réels dans des namespaces réseau : un sur le LAN autorisé
# (10.0.9.0/24) et un hors du réseau autorisé (10.0.8.0/24).
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

echo "== 1. Deux LAN de test rattachés à la machine =="
for ns in client-ntp client-refuse; do ip netns del "$ns" 2>/dev/null || true; ip netns add "$ns"; done
ip link add veth-ntp type veth peer name eth0
ip link set eth0 netns client-ntp
ip link add veth-ref type veth peer name eth0
ip link set eth0 netns client-refuse
# Les extrémités ne peuvent pas porter le même nom dans le même namespace :
# on renomme à l'intérieur de chaque namespace.
ip -n client-ntp link set eth0 name ntp0
ip -n client-refuse link set eth0 name ref0

ip addr add 10.0.9.1/24 dev veth-ntp
ip addr add 10.0.8.1/24 dev veth-ref
ip link set veth-ntp up
ip link set veth-ref up
ip -n client-ntp addr add 10.0.9.50/24 dev ntp0
ip -n client-ntp link set ntp0 up
ip -n client-ntp link set lo up
ip -n client-refuse addr add 10.0.8.50/24 dev ref0
ip -n client-refuse link set ref0 up
ip -n client-refuse link set lo up

echo "--- côté serveur"
ip -br addr show veth-ntp | sed 's/^/  /'
ip -br addr show veth-ref | sed 's/^/  /'
echo "--- côté clients"
ip netns exec client-ntp ip -br addr show ntp0 | sed 's/^/  client-ntp   /'
ip netns exec client-refuse ip -br addr show ref0 | sed 's/^/  client-refuse /'

echo
echo "== 2. Client autorisé : une requête NTP réelle =="
ip netns exec client-ntp chronyd -Q 'server 10.0.9.1 iburst' 2>&1
echo "code du client autorisé : $?"

echo
echo "== 3. Ce que le serveur a vu =="
chronyc clients 2>/dev/null | sed -n '1,5p'
chronyc serverstats | sed -n '1,4p'

echo
echo "== 4. Client hors réseau autorisé =="
if ip netns exec client-refuse chronyd -Q -t 6 'server 10.0.8.1 iburst' 2>&1; then
  echo "INATTENDU : le client non autorisé a reçu l'heure"
else
  echo "-> refus attendu : le serveur ignore les paquets venant de 10.0.8.0/24"
fi
