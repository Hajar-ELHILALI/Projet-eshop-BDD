ALTER SESSION SET CONTAINER = XEPDB1;

-- ==========================================
-- Synonymes pointant vers le MASTER (Global)
-- ==========================================
CREATE OR REPLACE PUBLIC SYNONYM clients FOR clients@link_central;
CREATE OR REPLACE PUBLIC SYNONYM produits FOR produits@link_central;
CREATE OR REPLACE PUBLIC SYNONYM commandes FOR commandes@link_central;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes FOR lignecommandes@link_central;

-- ==========================================
-- Synonymes pointant vers le SITE 1 (Horizontal)
-- ==========================================
CREATE OR REPLACE PUBLIC SYNONYM clients1 FOR clients1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM produits1 FOR produits1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM commandes1 FOR commandes1@link_site1;
CREATE OR REPLACE PUBLIC SYNONYM lignecommandes1 FOR lignecommandes1@link_site1;