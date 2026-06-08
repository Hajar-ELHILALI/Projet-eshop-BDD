-- ============================================================
-- SCENARIO 2 | SITE 1 -- Compte connecteur 'eshop_link'
-- ------------------------------------------------------------
-- Utilisateur a moindre privilege utilise par les liens entrants
-- (Master, Site 2). Droits limites aux tables et procedures du
-- fragment Site 1.
-- Identique au Scenario 1 : les noms de tables et procedures
-- locales sont les memes (lignecommandes1, INSERTligne, etc.).
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

-- Droits en lecture sur les tables du fragment R1
GRANT SELECT  ON eshop_site1.clients1         TO eshop_link;
GRANT SELECT  ON eshop_site1.produits1        TO eshop_link;
GRANT SELECT  ON eshop_site1.commandes1       TO eshop_link;
GRANT SELECT  ON eshop_site1.lignecommandes1  TO eshop_link;

-- Droits en execution sur les procedures de manipulation
GRANT EXECUTE ON eshop_site1.INSERTligne      TO eshop_link;
GRANT EXECUTE ON eshop_site1.DELETEligne      TO eshop_link;
GRANT EXECUTE ON eshop_site1.updateligne      TO eshop_link;

-- Synonymes prives pour l'utilisateur connecteur
CREATE OR REPLACE SYNONYM eshop_link.clients1        FOR eshop_site1.clients1;
CREATE OR REPLACE SYNONYM eshop_link.produits1       FOR eshop_site1.produits1;
CREATE OR REPLACE SYNONYM eshop_link.commandes1      FOR eshop_site1.commandes1;
CREATE OR REPLACE SYNONYM eshop_link.lignecommandes1 FOR eshop_site1.lignecommandes1;
CREATE OR REPLACE SYNONYM eshop_link.INSERTligne     FOR eshop_site1.INSERTligne;
CREATE OR REPLACE SYNONYM eshop_link.DELETEligne     FOR eshop_site1.DELETEligne;
CREATE OR REPLACE SYNONYM eshop_link.updateligne     FOR eshop_site1.updateligne;
