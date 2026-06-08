-- ============================================================
-- SCENARIO 2 | MASTER -- Liens PRIVES vers les sites
-- ------------------------------------------------------------
-- Identique au Scenario 1 : l'infrastructure physique ne change pas.
-- R1 = sigma(quantite >= 100) --> Site 1
-- R2 = sigma(quantite <  100) --> Site 2
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_admin;

CONNECT eshop_admin/EshopPassword123@//localhost:1521/XEPDB1

CREATE DATABASE LINK link_site1
CONNECT TO eshop_site1 IDENTIFIED BY "EshopPassword123"
USING 'BD-SITE1';

CREATE DATABASE LINK link_site2
CONNECT TO eshop_site2 IDENTIFIED BY "EshopPassword123"
USING 'BD-SITE2';
