-- ============================================================
-- SCENARIO 2 | MASTER -- Synonymes publics (identique Scenario 1)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- Le Master n'a pas besoin de synonymes vers lui-meme.
-- Les synonymes suivants sont utilises par les triggers du Master
-- pour appeler les procedures sur les sites distants via EXECUTE IMMEDIATE.
-- Les DB Links link_site1 et link_site2 suffisent pour le routage.

CREATE OR REPLACE PUBLIC SYNONYM clients1 FOR clients1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM produits1 FOR produits1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM commandes1 FOR commandes1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes1 FOR lignecommandes1@link_site1;

-- ==========================================
-- Synonymes pointant vers le SITE 2
-- ==========================================
CREATE OR REPLACE PUBLIC SYNONYM clients2 FOR clients2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM produits2 FOR produits2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM commandes2 FOR commandes2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes2 FOR lignecommandes2@link_site2;
