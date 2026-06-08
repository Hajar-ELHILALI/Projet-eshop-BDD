-- ============================================================
-- SCENARIO 2 | SITE 1 -- Liens PRIVES (identique Scenario 1)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_site1;

CONNECT eshop_site1/EshopPassword123@//localhost:1521/XEPDB1

-- Lien vers le Master (base globale)
CREATE DATABASE LINK link_central
CONNECT TO eshop_admin IDENTIFIED BY "EshopPassword123"
USING 'BD-MASTER';

-- Lien vers Site 2 (routage croise)
CREATE DATABASE LINK link_site2
CONNECT TO eshop_site2 IDENTIFIED BY "EshopPassword123"
USING 'BD-SITE2';
