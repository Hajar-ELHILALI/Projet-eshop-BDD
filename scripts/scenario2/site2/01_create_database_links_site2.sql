-- ============================================================
-- SCENARIO 2 | SITE 2 -- Liens PRIVES (identique Scenario 1)
-- ------------------------------------------------------------
-- Deux liens prives crees par l'utilisateur eshop_site2 :
--   link_central → Master (lecture/ecriture globale)
--   link_site1   → Site 1 (routage croise pour R1)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_site2;

CONNECT eshop_site2/EshopPassword123@//localhost:1521/XEPDB1

-- Lien vers le Master (base globale)
CREATE DATABASE LINK link_central
CONNECT TO eshop_admin IDENTIFIED BY "EshopPassword123"
USING 'BD-MASTER';

-- Lien vers Site 1 (routage croise : lignes qui passent en R1)
CREATE DATABASE LINK link_site1
CONNECT TO eshop_site1 IDENTIFIED BY "EshopPassword123"
USING 'BD-SITE1';
