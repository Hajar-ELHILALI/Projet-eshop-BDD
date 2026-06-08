-- ============================================================
-- SCENARIO 2 | SITE 2 -- Synonymes
-- ------------------------------------------------------------
-- Synonymes vers le master (tables globales) et vers Site 1
-- (pour les appels de routage croise).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

-- Synonymes vers le Master (tables globales)
CREATE OR REPLACE SYNONYM clients        FOR clients@link_central;
CREATE OR REPLACE SYNONYM produits       FOR produits@link_central;
CREATE OR REPLACE SYNONYM commandes      FOR commandes@link_central;
CREATE OR REPLACE SYNONYM lignecommandes FOR lignecommandes@link_central;

-- Synonymes vers Site 1 (fragment R1 : quantite >= 100)
CREATE OR REPLACE SYNONYM clients1        FOR clients1@link_site1;
CREATE OR REPLACE SYNONYM produits1       FOR produits1@link_site1;
CREATE OR REPLACE SYNONYM commandes1      FOR commandes1@link_site1;
CREATE OR REPLACE SYNONYM lignecommandes1 FOR lignecommandes1@link_site1;
