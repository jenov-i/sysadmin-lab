-- Vérification que les contraintes font vraiment leur travail.
-- Chaque essai est dans une transaction annulée : la base reste intacte.
\echo '--- 1. Clé étrangère : article rattaché à un fournisseur inexistant'
BEGIN;
INSERT INTO article (reference, libelle, prix_ht, fournisseur_id)
VALUES ('TEST-FK', 'Article orphelin', 10.00, 999);
ROLLBACK;

\echo '--- 2. CHECK : quantité nulle refusée'
BEGIN;
INSERT INTO mouvement (article_id, sens, quantite) VALUES (1, 'entree', 0);
ROLLBACK;

\echo '--- 3. CHECK : prix négatif refusé'
BEGIN;
UPDATE article SET prix_ht = -5 WHERE id = 1;
ROLLBACK;

\echo '--- 4. ON DELETE CASCADE : supprimer un article supprime ses mouvements'
SELECT count(*) AS mouvements_article_1 FROM mouvement WHERE article_id = 1;
BEGIN;
DELETE FROM article WHERE id = 1;
SELECT count(*) AS mouvements_apres_delete FROM mouvement WHERE article_id = 1;
ROLLBACK;
SELECT count(*) AS mouvements_apres_rollback FROM mouvement WHERE article_id = 1;

\echo '--- 5. État final : aucune donnée de test'
SELECT count(*) AS articles FROM article;
SELECT count(*) AS mouvements FROM mouvement;
