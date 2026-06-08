-- ============================================================
-- SITE 2 -- Liens PRIVES vers le Master et le Site 1
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE DATABASE LINK TO eshop_site2;

CONNECT eshop_site2/EshopPassword123@//localhost:1521/XEPDB1

CREATE DATABASE LINK link_central
CONNECT TO eshop_admin IDENTIFIED BY "EshopPassword123"
USING 'BD-MASTER';

CREATE DATABASE LINK link_site1
CONNECT TO eshop_site1 IDENTIFIED BY "EshopPassword123"
USING 'BD-SITE1';
