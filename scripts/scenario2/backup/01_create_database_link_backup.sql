-- ============================================================
-- SCENARIO 2 | BASE DE SECOURS -- Lien PRIVE vers le Master
-- ------------------------------------------------------------
-- Identique au Scenario 1 : la base de secours se connecte
-- uniquement au Master pour recopier la base globale complete.
-- La strategie de sauvegarde ne change pas entre les scenarios.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_backup;

CONNECT eshop_backup/EshopPassword123@//localhost:1521/XEPDB1

CREATE DATABASE LINK link_central
CONNECT TO eshop_admin IDENTIFIED BY "EshopPassword123"
USING 'BD-MASTER';
