-- ============================================================
-- BASE DE SECOURS -- Lien PRIVE vers le Master (mode pull)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_backup;

CONNECT eshop_backup/EshopPassword123@//localhost:1521/XEPDB1

CREATE DATABASE LINK link_central
CONNECT TO eshop_admin IDENTIFIED BY "EshopPassword123"
USING 'BD-MASTER';
