-- Requêtes de démonstration — exécutées avec psql en TCP sur 10.0.3.10
\echo '--- 1. Relations de la base'
\dt

\echo '--- 2. Structure de la table article (clé étrangère incluse)'
\d article

\echo '--- 3. Jointure article / fournisseur'
SELECT a.reference, a.libelle, f.nom AS fournisseur, a.prix_ht
FROM article a
JOIN fournisseur f ON f.id = a.fournisseur_id
ORDER BY a.reference;

\echo '--- 4. Stock calculé par la vue'
SELECT * FROM stock_par_article;

\echo '--- 5. Totaux du stock'
SELECT sum(quantite) AS unites, sum(valeur_stock) AS valeur_totale
FROM stock_par_article;

\echo '--- 6. Derniers mouvements, avec le nom de l article'
SELECT a.reference, m.sens, m.quantite, to_char(m.le, 'DD/MM/YYYY') AS date
FROM mouvement m
JOIN article a ON a.id = m.article_id
ORDER BY m.le DESC, m.id DESC
LIMIT 6;

\echo '--- 7. Répartition des mouvements par sens'
SELECT sens, count(*) AS nombre, sum(quantite) AS unites
FROM mouvement
GROUP BY sens
ORDER BY sens;
