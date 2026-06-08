-- ============================================================
-- SCENARIO 2 | SITE 1 -- Package anti-boucle (identique Scenario 1)
-- ------------------------------------------------------------
-- Le drapeau is_replicating est positionne a TRUE avant toute
-- ecriture declenchee par un trigger de synchronisation, afin
-- d'eviter les boucles de replication infinies.
-- Sa portee est la session Oracle (variable de package).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site1;

CREATE OR REPLACE PACKAGE pkg_synchro AS
    is_replicating BOOLEAN := FALSE;
END pkg_synchro;
/
