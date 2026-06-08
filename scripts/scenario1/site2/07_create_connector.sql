-- ============================================================
-- SITE 2 — Compte connecteur 'eshop_link' (moindre privilège)
-- Utilisé par les liens entrants (Master, Site 1). Droits limités
-- aux tables et procédures du fragment Site 2.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER eshop_link IDENTIFIED BY "LinkPwd123";
GRANT CREATE SESSION TO eshop_link;

GRANT SELECT  ON eshop_site2.clients2         TO eshop_link;
GRANT SELECT  ON eshop_site2.produits2        TO eshop_link;
GRANT SELECT  ON eshop_site2.commandes2       TO eshop_link;
GRANT SELECT  ON eshop_site2.lignecommandes2  TO eshop_link;
GRANT EXECUTE ON eshop_site2.INSERTligne      TO eshop_link;
GRANT EXECUTE ON eshop_site2.DELETEligne      TO eshop_link;
GRANT EXECUTE ON eshop_site2.updateligne      TO eshop_link;

CREATE OR REPLACE SYNONYM eshop_link.clients2        FOR eshop_site2.clients2;
CREATE OR REPLACE SYNONYM eshop_link.produits2       FOR eshop_site2.produits2;
CREATE OR REPLACE SYNONYM eshop_link.commandes2      FOR eshop_site2.commandes2;
CREATE OR REPLACE SYNONYM eshop_link.lignecommandes2 FOR eshop_site2.lignecommandes2;
CREATE OR REPLACE SYNONYM eshop_link.INSERTligne     FOR eshop_site2.INSERTligne;
CREATE OR REPLACE SYNONYM eshop_link.DELETEligne     FOR eshop_site2.DELETEligne;
CREATE OR REPLACE SYNONYM eshop_link.updateligne     FOR eshop_site2.updateligne;
