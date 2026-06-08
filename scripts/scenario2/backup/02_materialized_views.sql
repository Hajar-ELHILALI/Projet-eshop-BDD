-- ============================================================
-- SCENARIO 2 | BASE DE SECOURS -- Vues materialisees
-- ------------------------------------------------------------
-- Identique au Scenario 1 : on replike l'integralite du Master.
-- Comme le Master contient toutes les donnees (fragments R1 et R2
-- y sont synchronises par les triggers), sauvegarder le Master
-- couvre la totalite de la base distribuee, quel que soit le
-- scenario de fragmentation.
--
-- REFRESH COMPLETE toutes les 5 minutes :
--   - Recopie totale (aucun MATERIALIZED VIEW LOG requis cote Master)
--   - Impact zero sur la production
--   - Le lien 'link_central' est prive (eshop_backup en est proprietaire)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

GRANT CREATE MATERIALIZED VIEW TO eshop_backup;
GRANT CREATE JOB               TO eshop_backup;

CONNECT eshop_backup/EshopPassword123@//localhost:1521/XEPDB1

-- Clients
CREATE MATERIALIZED VIEW mv_clients
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM clients@link_central;

-- Produits
CREATE MATERIALIZED VIEW mv_produits
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM produits@link_central;

-- Commandes
CREATE MATERIALIZED VIEW mv_commandes
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM commandes@link_central;

-- Lignes de commandes (contient R1 + R2 + lignes master-only)
CREATE MATERIALIZED VIEW mv_lignecommandes
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM lignecommandes@link_central;
