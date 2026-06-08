-- ============================================================
-- SCENARIO 2 | SITE 2 -- Compte connecteur 'eshop_link'
-- ------------------------------------------------------------
-- Utilisateur a moindre privilege utilise par les liens entrants
-- (Master, Site 1). Droits limites aux tables et procedures du
-- fragment Site 2.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

-- Creation idempotente du compte connecteur
BEGIN
    EXECUTE IMMEDIATE 'DROP USER eshop_link CASCADE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE USER eshop_link IDENTIFIED BY "LinkPwd123";
GRANT CREATE SESSION TO eshop_link;

-- Droits en lecture sur les tables du fragment R2
GRANT SELECT  ON eshop_site2.clients2         TO eshop_link;
GRANT SELECT  ON eshop_site2.produits2        TO eshop_link;
GRANT SELECT  ON eshop_site2.commandes2       TO eshop_link;
GRANT SELECT  ON eshop_site2.lignecommandes2  TO eshop_link;

-- Droits en execution sur les procedures de manipulation
GRANT EXECUTE ON eshop_site2.INSERTligne      TO eshop_link;
GRANT EXECUTE ON eshop_site2.DELETEligne      TO eshop_link;
GRANT EXECUTE ON eshop_site2.updateligne      TO eshop_link;

-- Synonymes prives pour l'utilisateur connecteur
CREATE OR REPLACE SYNONYM eshop_link.clients2        FOR eshop_site2.clients2;
CREATE OR REPLACE SYNONYM eshop_link.produits2       FOR eshop_site2.produits2;
CREATE OR REPLACE SYNONYM eshop_link.commandes2      FOR eshop_site2.commandes2;
CREATE OR REPLACE SYNONYM eshop_link.lignecommandes2 FOR eshop_site2.lignecommandes2;
CREATE OR REPLACE SYNONYM eshop_link.INSERTligne     FOR eshop_site2.INSERTligne;
CREATE OR REPLACE SYNONYM eshop_link.DELETEligne     FOR eshop_site2.DELETEligne;
CREATE OR REPLACE SYNONYM eshop_link.updateligne     FOR eshop_site2.updateligne;
