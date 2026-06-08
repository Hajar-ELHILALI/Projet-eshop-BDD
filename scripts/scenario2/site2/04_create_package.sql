-- ============================================================
-- SCENARIO 2 | SITE 2 -- Package anti-boucle
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

CREATE OR REPLACE PACKAGE pkg_synchro AS
    is_replicating BOOLEAN := FALSE;
END pkg_synchro;
/
