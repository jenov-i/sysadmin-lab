#!/usr/bin/env python3
"""Charge continue sur la base lab_migration.

Usage : charge.py ecriture|lecture DUREE_S JOURNAL NB_CLIENTS

Chaque client ouvre sa propre connexion et enchaîne une transaction par
requête. Les écrivains ont un statement_timeout de 1 s : une requête bloquée
échoue au bout d'une seconde et le client continue (contrairement à pgbench,
qui abandonne le client au premier échec).

Le journal contient une ligne par requête : « latence_ms statut ».
"""
import random
import sys
import threading
import time

import psycopg2

mode = sys.argv[1]
duree = float(sys.argv[2])
journal_nom = sys.argv[3]
nb_clients = int(sys.argv[4])

ECRITURE = """
INSERT INTO commandes (client_id, montant, statut, cree_le, notes)
VALUES (%s, %s, 'en_attente', now(), 'charge continue')
"""
LECTURE = "SELECT id, statut FROM commandes WHERE id = %s"

verrou = threading.Lock()
journal = open(journal_nom, "w", buffering=1)
erreurs = open(journal_nom + ".erreurs", "w", buffering=1)
aleatoire = random.Random(20261115)


def client(numero):
    conn = psycopg2.connect(
        dbname="lab_migration", options="-c statement_timeout=1000"
    )
    conn.autocommit = True
    fin = time.monotonic() + duree
    tampon = []
    while time.monotonic() < fin:
        debut = time.perf_counter()
        statut = "ok"
        try:
            with conn.cursor() as cur:
                if mode == "ecriture":
                    cur.execute(ECRITURE, (aleatoire.randint(1, 9999), 10 + numero))
                else:
                    cur.execute(LECTURE, (aleatoire.randint(1, 3_000_000),))
                    cur.fetchall()
        except Exception as erreur:  # timeout ou erreur SQL : on continue
            statut = "timeout" if "statement timeout" in str(erreur) else "erreur"
            with verrou:
                erreurs.write(f"{time.strftime('%H:%M:%S')} {statut} {erreur}\n")
            try:
                conn.rollback()
            except Exception:
                pass
        latence = (time.perf_counter() - debut) * 1000
        tampon.append(f"{latence:.1f} {statut} {time.strftime('%H:%M:%S')}\n")
        if len(tampon) >= 100:
            with verrou:
                journal.writelines(tampon)
            tampon = []
        if mode == "lecture":
            time.sleep(0.005)  # ~200 lectures/s et par client
    with verrou:
        journal.writelines(tampon)
    conn.close()


threads = [
    threading.Thread(target=client, args=(i,), daemon=True) for i in range(nb_clients)
]
for t in threads:
    t.start()
for t in threads:
    t.join()
journal.close()
erreurs.close()
