-- Schéma de la base lab_stock — serveur srv-debian13, PostgreSQL 17
--
-- Trois tables liées :
--   fournisseur 1 --- N article 1 --- N mouvement
-- et une vue qui calcule le stock restant à partir des mouvements.

SET ROLE lab_admin;

DROP VIEW IF EXISTS stock_par_article;
DROP TABLE IF EXISTS mouvement;
DROP TABLE IF EXISTS article;
DROP TABLE IF EXISTS fournisseur;

CREATE TABLE fournisseur (
    id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom   text    NOT NULL UNIQUE,
    pays  char(2) NOT NULL
);

CREATE TABLE article (
    id             integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference      text          NOT NULL UNIQUE,
    libelle        text          NOT NULL,
    prix_ht        numeric(10,2) NOT NULL CHECK (prix_ht > 0),
    fournisseur_id integer       NOT NULL REFERENCES fournisseur(id)
);

CREATE TABLE mouvement (
    id         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    article_id integer     NOT NULL REFERENCES article(id) ON DELETE CASCADE,
    sens       text        NOT NULL CHECK (sens IN ('entree', 'sortie')),
    quantite   integer     NOT NULL CHECK (quantite > 0),
    le         timestamptz NOT NULL DEFAULT now()
);

-- Les requêtes de stock filtrent par article et trient par date :
-- sans cet index, chaque calcul de stock lit toute la table.
CREATE INDEX idx_mouvement_article ON mouvement (article_id, le);

CREATE VIEW stock_par_article AS
SELECT a.reference,
       a.libelle,
       f.nom AS fournisseur,
       a.prix_ht,
       COALESCE(SUM(CASE m.sens WHEN 'entree' THEN m.quantite
                               WHEN 'sortie' THEN -m.quantite END), 0) AS quantite,
       ROUND(COALESCE(SUM(CASE m.sens WHEN 'entree' THEN m.quantite
                                     WHEN 'sortie' THEN -m.quantite END), 0)
             * a.prix_ht, 2) AS valeur_stock
FROM article a
JOIN fournisseur f ON f.id = a.fournisseur_id
LEFT JOIN mouvement m ON m.article_id = a.id
GROUP BY a.id, a.reference, a.libelle, f.nom, a.prix_ht
ORDER BY a.reference;
