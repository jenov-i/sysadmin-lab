-- Jeu de données de démonstration — lab_stock
-- Les mouvements sont datés par défaut (now()) : le stock est calculé, pas stocké.

SET ROLE lab_admin;

INSERT INTO fournisseur (nom, pays) VALUES
  ('Tech Distribution', 'FR'),
  ('Nordic Hardware',   'SE'),
  ('Accessoires Lyon',  'FR');

INSERT INTO article (reference, libelle, prix_ht, fournisseur_id) VALUES
  ('SW-24P',       'Switch 24 ports',          189.90, 1),
  ('RJ45-CAT6-305','Bobine câble Cat6 305 m',  129.50, 1),
  ('SSD-1TO',      'SSD NVMe 1 To',             89.00, 2),
  ('ALIM-650W',    'Alimentation 650 W',        74.90, 2),
  ('BAIE-12U',     'Baie murale 12U',          219.00, 3);

INSERT INTO mouvement (article_id, sens, quantite) VALUES
  (1, 'entree', 10), (1, 'sortie', 3),
  (2, 'entree',  5), (2, 'sortie', 1),
  (3, 'entree', 20), (3, 'sortie', 12),
  (4, 'entree',  8), (4, 'sortie', 2),
  (5, 'entree',  4);

-- Deux sorties datées dans le passé pour que la vue ne soit pas uniforme.
INSERT INTO mouvement (article_id, sens, quantite, le) VALUES
  (3, 'entree', 10, now() - interval '30 days'),
  (3, 'sortie',  6, now() - interval '12 days');
