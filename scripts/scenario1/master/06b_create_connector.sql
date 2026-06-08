-- ============================================================
-- MASTER : Compte connecteur 'eshop_link' (moindre privilege)
-- Utilise par les liens entrants (Site 1, Site 2, Backup) :
-- SELECT sur les 4 tables + EXECUTE sur les 3 procedures uniquement.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER eshop_link IDENTIFIED BY "LinkPwd123";
GRANT CREATE SESSION TO eshop_link;

-- Droits minimaux sur les objets de eshop_admin
GRANT SELECT  ON eshop_admin.clients         TO eshop_link;
GRANT SELECT  ON eshop_admin.produits        TO eshop_link;
GRANT SELECT  ON eshop_admin.commandes       TO eshop_link;
GRANT SELECT  ON eshop_admin.lignecommandes  TO eshop_link;
GRANT EXECUTE ON eshop_admin.INSERTligne     TO eshop_link;
GRANT EXECUTE ON eshop_admin.DELETEligne     TO eshop_link;
GRANT EXECUTE ON eshop_admin.updateligne     TO eshop_link;

-- Synonymes de resolution (appels distants non qualifies -> eshop_admin.*)
CREATE OR REPLACE SYNONYM eshop_link.clients        FOR eshop_admin.clients;
CREATE OR REPLACE SYNONYM eshop_link.produits       FOR eshop_admin.produits;
CREATE OR REPLACE SYNONYM eshop_link.commandes      FOR eshop_admin.commandes;
CREATE OR REPLACE SYNONYM eshop_link.lignecommandes FOR eshop_admin.lignecommandes;
CREATE OR REPLACE SYNONYM eshop_link.INSERTligne    FOR eshop_admin.INSERTligne;
CREATE OR REPLACE SYNONYM eshop_link.DELETEligne    FOR eshop_admin.DELETEligne;
CREATE OR REPLACE SYNONYM eshop_link.updateligne    FOR eshop_admin.updateligne;
