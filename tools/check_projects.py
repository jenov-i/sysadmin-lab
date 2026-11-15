#!/usr/bin/env python3
"""Contrôle automatique des projets publiés dans ce dépôt.

  python3 tools/check_projects.py              # tout le dépôt
  python3 tools/check_projects.py replication  # les dossiers dont le nom contient « replication »
  python3 tools/check_projects.py --strict     # un avertissement suffit à échouer
  python3 tools/check_projects.py --catalogue ../catalogue.json

Deux niveaux :

  ERREUR          bloque la publication — lien mort, image absente ou vide,
                  secret repéré, README muet.
  AVERTISSEMENT   faiblesse de forme — section manquante, capture non numérotée,
                  journal vide, marqueur .gitkeep oublié.

Code de retour : 0 si aucune erreur (en --strict : ni erreur ni avertissement),
1 sinon, 2 en cas d'usage incorrect.

Ce fichier est la seule règle : `bin/publish.py` l'appelle avant de committer et
la CI GitHub l'exécute à chaque push. Une règle, deux endroits.
"""
import argparse
import json
import re
import struct
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent

SECTIONS = [
    "## Objectif",
    "## Environnement",
    ("## Architecture", "## Schéma"),
    ("## Étapes clés", "## Étapes"),
    "## Résultat prouvé",
    "## Problèmes rencontrés",
    ("## Durée", "## Durée et publication"),
]

# Motifs de fuite : volontairement peu nombreux et testés sur le dépôt entier.
SECRETS = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "clé privée"),
    (re.compile(r"IDENTIFIED BY PASSWORD '\*[0-9A-Fa-f]{40}'"), "hash de mot de passe MySQL"),
    (re.compile(r"authentication_string[^\n]*\*[0-9A-F]{40}"), "hash de mot de passe MySQL"),
    (re.compile(r"AKIA[0-9A-Z]{16}"), "clé d'accès AWS"),
    (re.compile(r"ghp_[A-Za-z0-9]{30,}"), "jeton GitHub"),
    (re.compile(r"(?i)(password|passwd|mot de passe)\s*[:=]\s*[\"'][^\"'\s]{8,}[\"']"), "mot de passe en clair"),
]

BINAIRE = {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".vmdk", ".iso"}


class Verdict:
    def __init__(self, projet: Path):
        self.projet = projet
        self.erreurs: list[str] = []
        self.avertissements: list[str] = []

    def erreur(self, message: str) -> None:
        self.erreurs.append(message)

    def avertir(self, message: str) -> None:
        self.avertissements.append(message)

    @property
    def nom(self) -> str:
        return f"{self.projet.parent.name}/{self.projet.name}"


def taille_png(chemin: Path) -> tuple[int, int] | None:
    """Lit la taille dans l'en-tête IHDR, sans dépendance externe."""
    with chemin.open("rb") as flux:
        entete = flux.read(26)
    if len(entete) < 26 or entete[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    if entete[12:16] != b"IHDR":
        return None
    largeur, hauteur = struct.unpack(">II", entete[16:24])
    return largeur, hauteur


def verifier_image(chemin: Path, verdict: Verdict) -> None:
    if not chemin.exists():
        verdict.erreur(f"image introuvable : {chemin.relative_to(verdict.projet)}")
        return
    octets = chemin.stat().st_size
    if octets < 1024:
        verdict.erreur(f"image quasi vide ({octets} octets) : {chemin.relative_to(verdict.projet)}")
        return
    if chemin.suffix.lower() != ".png":
        return
    taille = taille_png(chemin)
    if taille is None:
        verdict.erreur(f"fichier .png illisible : {chemin.relative_to(verdict.projet)}")
        return
    largeur, hauteur = taille
    if largeur < 600 or hauteur < 400:
        verdict.erreur(f"capture trop petite ({largeur}×{hauteur}) : {chemin.relative_to(verdict.projet)}")
    elif largeur < 800:
        verdict.avertir(f"capture étroite ({largeur}×{hauteur}) : {chemin.relative_to(verdict.projet)}")


def verifier_liens(readme: Path, verdict: Verdict) -> None:
    texte = readme.read_text(encoding="utf-8")
    for cible in re.findall(r"\]\(([^)\s]+)", texte):
        if cible.startswith(("http://", "https://", "mailto:", "#")):
            continue
        chemin = cible.split("#")[0]
        if not chemin:
            continue
        cible_reelle = (readme.parent / chemin).resolve()
        if not cible_reelle.exists():
            verdict.erreur(f"lien mort : {chemin}")
        elif cible_reelle.suffix.lower() in BINAIRE:
            verifier_image(cible_reelle, verdict)


def verifier_secrets(verdict: Verdict) -> None:
    for fichier in verdict.projet.rglob("*"):
        if not fichier.is_file() or fichier.suffix.lower() in BINAIRE:
            continue
        if ".git" in fichier.parts:
            continue
        try:
            texte = fichier.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for motif, libelle in SECRETS:
            trouve = motif.search(texte)
            if trouve:
                extrait = trouve.group(0)[:60].replace("\n", " ")
                verdict.erreur(f"{libelle} dans {fichier.relative_to(verdict.projet)} : {extrait}")


def verifier_projet(projet: Path) -> Verdict:
    verdict = Verdict(projet)
    readme = projet / "README.md"
    if not readme.exists():
        verdict.erreur("README.md absent")
        return verdict
    texte = readme.read_text(encoding="utf-8")
    if not texte.startswith("# "):
        verdict.erreur("README.md ne commence pas par un titre de niveau 1")

    for attendu in SECTIONS:
        variantes = attendu if isinstance(attendu, tuple) else (attendu,)
        if not any(v in texte for v in variantes):
            verdict.avertir(f"section absente : {variantes[0]}")

    verifier_liens(readme, verdict)

    for dossier in ("screenshots", "schemas"):
        chemin = projet / dossier
        if chemin.exists() and not any(chemin.iterdir()):
            verdict.avertir(f"dossier vide : {dossier}/")

    captures = projet / "screenshots"
    if captures.exists():
        for image in sorted(captures.glob("*.png")):
            if not re.match(r"^\d{2}-", image.name):
                verdict.avertir(f"capture non numérotée : screenshots/{image.name}")

    journaux = projet / "logs"
    if journaux.exists():
        fichiers = [f for f in journaux.iterdir() if f.is_file()]
        if not fichiers:
            verdict.avertir("logs/ vide")
        for journal in fichiers:
            if journal.stat().st_size < 200:
                verdict.avertir(f"journal très court : logs/{journal.name}")
    else:
        verdict.avertir("dossier logs/ absent")

    for marqueur in projet.rglob(".gitkeep"):
        verdict.avertir(f"marqueur oublié : {marqueur.relative_to(projet)}")

    verifier_secrets(verdict)
    return verdict


def projets(racine: Path) -> list[Path]:
    trouve = []
    for categorie in sorted(racine.iterdir()):
        if not categorie.is_dir() or not re.match(r"^\d{2}-", categorie.name):
            continue
        for projet in sorted(categorie.iterdir()):
            if projet.is_dir() and (projet / "README.md").exists():
                trouve.append(projet)
    return trouve


def verifier_catalogue(catalogue: Path, racine: Path) -> list[str]:
    """Le catalogue et le dépôt doivent dire la même chose."""
    messages = []
    try:
        donnees = json.loads(catalogue.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"catalogue illisible : {exc}"]

    faits = {p["slug"]: p for p in donnees.get("projects", [])
             if p.get("status") == "done" and p.get("slug")}
    sur_disque = {p.relative_to(racine).as_posix() for p in projets(racine)}

    for slug in sorted(set(faits) - sur_disque):
        messages.append(f"catalogue marque « done » sans dossier : {slug}")
    for slug in sorted(sur_disque - set(faits)):
        messages.append(f"projet publié absent du catalogue (ou statut ≠ done) : {slug}")
    return messages


def main() -> int:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("motif", nargs="?", default=None)
    analyseur.add_argument("--strict", action="store_true")
    analyseur.add_argument("--catalogue", type=Path, default=None)
    analyseur.add_argument("--racine", type=Path, default=RACINE)
    options = analyseur.parse_args()

    racine = options.racine.resolve()
    if not racine.is_dir():
        print(f"racine introuvable : {racine}", file=sys.stderr)
        return 2

    liste = projets(racine)
    if options.motif:
        liste = [p for p in liste if options.motif in p.name or options.motif in p.parent.name]
    if not liste:
        print("aucun projet à contrôler", file=sys.stderr)
        return 2

    total_erreurs = total_avertissements = 0
    for projet in liste:
        verdict = verifier_projet(projet)
        total_erreurs += len(verdict.erreurs)
        total_avertissements += len(verdict.avertissements)
        symbole = "OK " if not verdict.erreurs else "KO "
        print(f"{symbole}{verdict.nom}")
        for message in verdict.erreurs:
            print(f"     ERREUR  {message}")
        for message in verdict.avertissements:
            print(f"     noté    {message}")

    if options.catalogue:
        messages = verifier_catalogue(options.catalogue, racine)
        total_erreurs += len(messages)
        print(("\nCohérence avec le catalogue : " if messages else "\nCatalogue cohérent."),
              end="\n" if messages else "")
        for message in messages:
            print(f"     ERREUR  {message}")

    print(f"\n{len(liste)} projet(s) · {total_erreurs} erreur(s) · "
          f"{total_avertissements} avertissement(s)")
    if total_erreurs:
        return 1
    if options.strict and total_avertissements:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
