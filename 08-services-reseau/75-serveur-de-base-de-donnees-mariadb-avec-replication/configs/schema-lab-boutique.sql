-- ============================================================
-- Base applicative du lab : lab_boutique
-- Exécuté sur le primaire (lab-linux-01) puis répliqué tel quel
-- ============================================================

-- Script de préparation : repart d'une base vide, pour être rejouable.
DROP DATABASE IF EXISTS lab_boutique;
CREATE DATABASE lab_boutique
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE lab_boutique;

-- ------------------------------------------------------------
-- Schéma
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS clients (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  nom     VARCHAR(80)  NOT NULL,
  ville   VARCHAR(60)  NOT NULL,
  cree_le DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS produits (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  libelle    VARCHAR(80)  NOT NULL,
  prix_cents INT UNSIGNED NOT NULL,
  stock      INT          NOT NULL DEFAULT 0,
  CONSTRAINT ck_produit_prix CHECK (prix_cents > 0)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS commandes (
  id          BIGINT AUTO_INCREMENT PRIMARY KEY,
  client_id   INT          NOT NULL,
  statut      ENUM('panier','payee','expediee') NOT NULL DEFAULT 'panier',
  cree_le     DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  total_cents INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_commande_client FOREIGN KEY (client_id) REFERENCES clients (id)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS lignes_commande (
  commande_id          BIGINT            NOT NULL,
  produit_id           INT               NOT NULL,
  quantite             SMALLINT UNSIGNED NOT NULL,
  prix_unitaire_cents  INT UNSIGNED      NOT NULL,
  PRIMARY KEY (commande_id, produit_id),
  CONSTRAINT fk_ligne_commande FOREIGN KEY (commande_id)
    REFERENCES commandes (id) ON DELETE CASCADE,
  CONSTRAINT fk_ligne_produit FOREIGN KEY (produit_id)
    REFERENCES produits (id)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- Jeu de données (moteur de séquences MariaDB : seq_1_to_N)
-- ------------------------------------------------------------

INSERT INTO clients (nom, ville)
SELECT CONCAT('client-', LPAD(seq, 3, '0')),
       ELT(1 + (seq % 4), 'Cotonou', 'Porto-Novo', 'Parakou', 'Abomey')
FROM seq_1_to_60;

INSERT INTO produits (libelle, prix_cents, stock)
SELECT ELT(1 + (seq % 6), 'Cafe 250 g', 'The vert 100 g', 'Riz 5 kg',
                            'Huile 1 L', 'Savon', 'Sucre 1 kg'),
       500 + (seq * 137) % 4000,
       10 + (seq * 7) % 90
FROM seq_1_to_24;

INSERT INTO commandes (client_id, statut, cree_le)
SELECT 1 + (seq % 60),
       ELT(1 + (seq % 3), 'panier', 'payee', 'expediee'),
       NOW(3) - INTERVAL (seq % 30) DAY
FROM seq_1_to_300;

-- 900 lignes = 37 commandes x 24 produits : la clé (commande_id, produit_id)
-- est unique par construction, là où deux modulo indépendants se recouvrent
INSERT INTO lignes_commande (commande_id, produit_id, quantite, prix_unitaire_cents)
SELECT 1 + (seq - 1) DIV 24,
       1 + (seq - 1) % 24,
       1 + (seq % 5),
       (SELECT prix_cents FROM produits WHERE id = 1 + (seq - 1) % 24)
FROM seq_1_to_900;

UPDATE commandes c
  JOIN (SELECT commande_id, SUM(quantite * prix_unitaire_cents) AS total
        FROM lignes_commande GROUP BY commande_id) l
    ON l.commande_id = c.id
  SET c.total_cents = l.total;
