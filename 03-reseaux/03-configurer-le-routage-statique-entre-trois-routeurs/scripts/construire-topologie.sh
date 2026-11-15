#!/bin/bash
# Topologie de routage statique : client — R1 — R2 — R3 — serveur.
# Trois « routeurs » sont des namespaces réseau Linux : le noyau fait
# réellement le routage, les tables sont de vraies tables de routage.
# Exécuté sur srv-debian13 le 15/11/2026.
set -euo pipefail

NOMS="client r1 r2 r3 serveur"

echo "== 1. Nettoyage et création des namespaces =="
for ns in $NOMS; do ip netns del "$ns" 2>/dev/null || true; done
for ns in $NOMS; do ip netns add "$ns"; done
ip netns list

echo
echo "== 2. Liens point à point =="
compteur=0
lien() {  # lien <ns1> <dev1> <ns2> <dev2>
  # Les deux extrémités d'un veth ne peuvent pas porter le même nom dans le
  # même namespace : on crée des noms temporaires uniques, puis on renomme
  # dans chaque namespace.
  compteur=$((compteur + 1))
  local tmp1="tmp${compteur}a" tmp2="tmp${compteur}b"
  ip link add "$tmp1" type veth peer name "$tmp2"
  ip link set "$tmp1" netns "$1"
  ip link set "$tmp2" netns "$3"
  ip -n "$1" link set "$tmp1" name "$2"
  ip -n "$3" link set "$tmp2" name "$4"
  ip -n "$1" link set "$2" up
  ip -n "$3" link set "$4" up
  echo "  $1:$2 <-> $3:$4"
}
lien client  eth0 r1 eth0        # LAN client  192.168.10.0/24
lien r1      eth1 r2 eth0        # lien R1-R2  10.0.12.0/30
lien r2      eth1 r3 eth0        # lien R2-R3  10.0.23.0/30
lien r3      eth1 serveur eth0   # LAN serveur 192.168.30.0/24

echo
echo "== 3. Adressage =="
ip -n client  addr add 192.168.10.10/24 dev eth0
ip -n r1      addr add 192.168.10.1/24  dev eth0
ip -n r1      addr add 10.0.12.1/30     dev eth1
ip -n r2      addr add 10.0.12.2/30     dev eth0
ip -n r2      addr add 10.0.23.1/30     dev eth1
ip -n r3      addr add 10.0.23.2/30     dev eth0
ip -n r3      addr add 192.168.30.1/24  dev eth1
ip -n serveur addr add 192.168.30.10/24 dev eth0
for ns in $NOMS; do ip -n "$ns" link set lo up; done
for ns in $NOMS; do ip -n "$ns" -br addr show | sed "s/^/  $ns /"; done

echo
echo "== 4. Routage activé sur les trois routeurs =="
for ns in r1 r2 r3; do
  ip netns exec "$ns" sysctl -qw net.ipv4.ip_forward=1
  echo "  $ns : ip_forward=$(ip netns exec "$ns" cat /proc/sys/net/ipv4/ip_forward)"
done

echo
echo "== 5. Routes statiques =="
ip -n client  route add default via 192.168.10.1
ip -n r1      route add 192.168.30.0/24 via 10.0.12.2
# Les /30 des liens distants ne sont pas connus des routeurs d'extrémité :
# sans ces deux routes, les réponses ICMP de R3 vers le client (et donc
# traceroute) sont perdues faute de chemin retour.
ip -n r1      route add 10.0.23.0/30 via 10.0.12.2
ip -n r2      route add 192.168.10.0/24 via 10.0.12.1
ip -n r2      route add 192.168.30.0/24 via 10.0.23.2
ip -n r3      route add 192.168.10.0/24 via 10.0.23.1
ip -n r3      route add 10.0.12.0/30 via 10.0.23.1
ip -n serveur route add default via 192.168.30.1

for ns in r1 r2 r3; do
  echo "--- $ns"
  ip -n "$ns" route | sed 's/^/  /'
done
