#!/usr/bin/env python3
"""Mesure l'écart entre l'horloge système et un serveur NTP public.

Client SNTP minimal (RFC 4330) : une requête UDP de 48 octets, et l'écart se
calcule à partir des quatre horodatages.

  python3 sntp-ecart.py                                  # une mesure
  python3 sntp-ecart.py --serie 8 --intervalle 20        # dérive sur 2 min 20
  python3 sntp-ecart.py --serveur 10.0.2.2               # un serveur précis

L'option --serie affiche un tableau puis la pente de l'écart en ppm
(parties par million), c'est-à-dire la dérive de l'horloge locale.
"""
import argparse
import socket
import struct
import sys
import time

EPOQUE_NTP = 2_208_988_800  # 1900-01-01 → 1970-01-01, en secondes


def horodatage(octets: bytes) -> float:
    """Champ NTP de 64 bits : secondes depuis 1900 puis fraction."""
    secondes, fraction = struct.unpack(">II", octets)
    return secondes - EPOQUE_NTP + fraction / 2**32


def requete(serveur: str, delai: float = 3.0) -> tuple[float, float]:
    """Renvoie (écart en secondes, aller-retour en secondes)."""
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(delai)
        paquet = bytes([0x23]) + 47 * b"\x00"  # LI 0, version 4, mode 3
        t1 = time.time()
        sock.sendto(paquet, (serveur, 123))
        data = sock.recv(48)
        t4 = time.time()
    if len(data) < 48:
        raise ValueError(f"réponse trop courte ({len(data)} octets)")
    t2 = horodatage(data[32:40])  # réception côté serveur
    t3 = horodatage(data[40:48])  # émission côté serveur
    ecart = ((t2 - t1) + (t3 - t4)) / 2
    aller_retour = (t4 - t1) - (t3 - t2)
    return ecart, aller_retour


def pente(series: list[tuple[float, float]]) -> float:
    """Moindres carrés sur (t, écart) → pente en secondes par seconde."""
    n = len(series)
    mt = sum(t for t, _ in series) / n
    me = sum(e for _, e in series) / n
    num = sum((t - mt) * (e - me) for t, e in series)
    den = sum((t - mt) ** 2 for t, _ in series)
    return num / den if den else 0.0


def pente_et_erreur(series: list[tuple[float, float]]) -> tuple[float, float]:
    """Pente et erreur-type de la pente (régression linéaire simple)."""
    n = len(series)
    p = pente(series)
    mt = sum(t for t, _ in series) / n
    me = sum(e for _, e in series) / n
    sxx = sum((t - mt) ** 2 for t, _ in series)
    residus = [e - (me + p * (t - mt)) for t, e in series]
    if n > 2 and sxx:
        variance = sum(r * r for r in residus) / (n - 2)
        return p, (variance / sxx) ** 0.5
    return p, 0.0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--serveur", default=None, help="serveur NTP (défaut : pool Debian)")
    ap.add_argument("--serie", type=int, default=1)
    ap.add_argument("--intervalle", type=float, default=20.0)
    ap.add_argument("--delai", type=float, default=3.0)
    ap.add_argument("--meilleur", type=int, default=0,
                    help="N échantillons, garder celui au plus court aller-retour")
    args = ap.parse_args()

    serveur = args.serveur or "0.debian.pool.ntp.org"
    try:
        ip = socket.gethostbyname(serveur)
    except OSError as exc:
        print(f"résolution impossible de {serveur} : {exc}", file=sys.stderr)
        return 2

    if args.meilleur > 1:
        meilleur = None
        for i in range(args.meilleur):
            if i:
                time.sleep(args.intervalle)
            try:
                ecart, ar = requete(ip, args.delai)
            except OSError as exc:
                print(f"  mesure {i + 1} : erreur {exc}", file=sys.stderr)
                continue
            if meilleur is None or ar < meilleur[1]:
                meilleur = (ecart, ar)
        if meilleur is None:
            print("aucune mesure aboutie", file=sys.stderr)
            return 1
        ecart, ar = meilleur
        print(f"{serveur} ({ip})  écart {ecart * 1000:+.3f} ms  "
              f"aller-retour {ar * 1000:.3f} ms "
              f"(meilleur de {args.meilleur} échantillons)")
        return 0

    if args.serie == 1:
        ecart, ar = requete(ip, args.delai)
        print(f"{serveur} ({ip})  écart {ecart * 1000:+.3f} ms  "
              f"aller-retour {ar * 1000:.3f} ms")
        return 0

    print(f"serveur {serveur} ({ip}) — {args.serie} mesures, "
          f"une toutes les {args.intervalle:.0f} s")
    print("  n°   temps écoulé   écart        aller-retour")
    series: list[tuple[float, float]] = []
    brut: list[tuple[float, float, float]] = []
    debut = time.monotonic()
    for i in range(args.serie):
        if i:
            time.sleep(args.intervalle)
        try:
            ecart, ar = requete(ip, args.delai)
        except OSError as exc:
            print(f"  {i + 1:2d}   erreur : {exc}")
            continue
        t = time.monotonic() - debut
        series.append((t, ecart))
        brut.append((t, ecart, ar))
        print(f"  {i + 1:2d}   +{t:7.1f} s     {ecart * 1000:+9.3f} ms   {ar * 1000:.3f} ms")

    if len(series) < 2:
        print("moins de deux mesures exploitables", file=sys.stderr)
        return 1

    p = pente(series)
    aml = p * 86_400
    print()
    print(f"pente brute : {p * 1e6:+.2f} ppm  ({p * 1000:+.3f} ms/s)")
    print(f"projection  : {aml * 1000:+.1f} ms par jour, soit {aml * 365:+.2f} s par an")
    ecarts = [e for _, e in series]
    print(f"dispersion  : min {min(ecarts) * 1000:+.3f} ms · max {max(ecarts) * 1000:+.3f} ms "
          f"· amplitude {(max(ecarts) - min(ecarts)) * 1000:.3f} ms")

    # Le bruit du réseau se voit sur l'aller-retour : on ne garde que les
    # échantillons dont l'aller-retour reste proche du meilleur observé, puis
    # on écarte les points aberrants par rapport à la droite (MAD).
    if len(brut) >= 4:
        retours = [r for _, _, r in brut]
        plancher = min(retours)
        gardes = [(t, e) for t, e, r in brut if r <= 1.5 * plancher]
        if len(gardes) >= 5:
            p1 = pente(gardes)
            mt = sum(t for t, _ in gardes) / len(gardes)
            me = sum(e for _, e in gardes) / len(gardes)
            res = sorted(abs(e - (me + p1 * (t - mt))) for t, e in gardes)
            mad = res[len(res) // 2]
            if mad:
                gardes = [(t, e) for t, e in gardes
                          if abs(e - (me + p1 * (t - mt))) <= 3 * 1.4826 * mad]
        if 3 <= len(gardes) <= len(brut):
            pf, ef = pente_et_erreur(gardes)
            print()
            print(f"filtre      : {len(gardes)}/{len(brut)} mesures gardées "
                  f"(aller-retour ≤ {1.5 * plancher * 1000:.0f} ms, puis 3 MAD)")
            print(f"pente filtrée : {pf * 1e6:+.2f} ppm ± {ef * 1e6:.2f} ppm (erreur-type)")
            print(f"projection    : {pf * 86_400 * 1000:+.1f} ms par jour, "
                  f"soit {pf * 86_400 * 365:+.2f} s par an")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
