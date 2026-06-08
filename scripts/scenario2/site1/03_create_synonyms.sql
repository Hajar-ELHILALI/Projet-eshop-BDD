-- ============================================================
-- SCENARIO 2 | SITE 1 -- Synonymes (identiques Scenario 1)
-- Les synonymes pointent vers le master (via link_central) et
-- vers Site 2 (via link_site2), pour un acces transparent
-- aux donnees distantes dans les procedures et triggers.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site1;

-- Synonymes vers le Master (tables globales)
CREATE OR REPLACE SYNONYM clients        FOR clients@link_central;
CREATE OR REPLACE SYNONYM produits       FOR produits@link_central;
CREATE OR REPLACE SYNONYM commandes      FOR commandes@link_central;
CREATE OR REPLACE SYNONYM lignecommandes FOR lignecommandes@link_central;

-- Synonymes vers Site 2 (fragment R2 : quantite < 100)
CREATE OR REPLACE SYNONYM clients2        FOR clients2@link_site2;
CREATE OR REPLACE SYNONYM produits2       FOR produits2@link_site2;
CREATE OR REPLACE SYNONYM commandes2      FOR commandes2@link_site2;
CREATE OR REPLACE SYNONYM lignecommandes2 FOR lignecommandes2@link_site2;
