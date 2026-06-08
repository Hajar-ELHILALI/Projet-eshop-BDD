ALTER SESSION SET CONTAINER = XEPDB1;

-- ==========================================
-- Synonymes pointant vers le MASTER (Global)
-- ==========================================
CREATE OR REPLACE PUBLIC SYNONYM clients FOR clients@link_central;
CREATE OR REPLACE PUBLIC SYNONYM produits FOR produits@link_central;
CREATE OR REPLACE PUBLIC SYNONYM commandes FOR commandes@link_central;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes FOR lignecommandes@link_central;

-- ==========================================
-- Synonymes pointant vers le SITE 2 (Horizontal)
-- ==========================================
CREATE OR REPLACE PUBLIC SYNONYM clients2 FOR clients2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM produits2 FOR produits2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM commandes2 FOR commandes2@link_site2;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes2 FOR lignecommandes2@link_site2;