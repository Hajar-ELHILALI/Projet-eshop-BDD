-- ============================================================
-- SCENARIO 2 | Q5 - Analyse de requete sur la base globale
--      Nombre de commandes par client en 2026
--      + plan d'execution avant/apres index couvrant
-- ------------------------------------------------------------
-- La requete Q5 est identique au Scenario 1 : elle porte sur
-- les tables COMMANDES et CLIENTS du Master (non fragmentees).
-- La fragmentation de LIGNECOMMANDES ne change pas le plan
-- d'execution de cette requete.
--
-- Executer sur le master :
--   docker exec -it eshop-master sqlplus ^
--     eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 ^
--     "@/queries/Q5_query_analysis.sql"
-- ============================================================
SET LINESIZE 200
SET PAGESIZE 100
SET SERVEROUTPUT ON
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

PROMPT ============================================================
PROMPT  Resultat metier : nb de commandes par client (2026)
PROMPT ============================================================
SELECT
    cl.codeclient,
    cl.societe,
    COUNT(*) AS nb_commandes_2026
FROM   commandes c
JOIN   clients   cl ON cl.idclient = c.idclient
WHERE  c.datecommande >= DATE '2026-01-01'
AND    c.datecommande <  DATE '2027-01-01'
GROUP  BY cl.idclient, cl.codeclient, cl.societe
ORDER  BY nb_commandes_2026 DESC;

PROMPT ============================================================
PROMPT  AVANT INDEX : plan d'execution
PROMPT ============================================================
EXPLAIN PLAN FOR
SELECT
    cl.codeclient,
    cl.societe,
    COUNT(*) AS nb_commandes_2026
FROM   commandes c
JOIN   clients   cl ON cl.idclient = c.idclient
WHERE  c.datecommande >= DATE '2026-01-01'
AND    c.datecommande <  DATE '2027-01-01'
GROUP  BY cl.idclient, cl.codeclient, cl.societe;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

PROMPT ------------------------------------------------------------
PROMPT  Observations attendues sans index :
PROMPT  - TABLE ACCESS FULL COMMANDES (aucun filtre sur date)
PROMPT  - TABLE ACCESS FULL CLIENTS   (jointure sans index)
PROMPT  - HASH JOIN + HASH GROUP BY   (operations couteuses en RAM)
PROMPT  Solution : index couvrant (datecommande, idclient)
PROMPT    -> sert la plage de dates ET fournit idclient sans toucher
PROMPT       la table principale (index-only scan possible)
PROMPT ------------------------------------------------------------

BEGIN EXECUTE IMMEDIATE 'DROP INDEX ix_cmd_date_client'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE INDEX ix_cmd_date_client ON commandes(datecommande, idclient);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES', cascade => TRUE);
END;
/

PROMPT ============================================================
PROMPT  APRES INDEX : plan d'execution
PROMPT ============================================================
EXPLAIN PLAN FOR
SELECT
    cl.codeclient,
    cl.societe,
    COUNT(*) AS nb_commandes_2026
FROM   commandes c
JOIN   clients   cl ON cl.idclient = c.idclient
WHERE  c.datecommande >= DATE '2026-01-01'
AND    c.datecommande <  DATE '2027-01-01'
GROUP  BY cl.idclient, cl.codeclient, cl.societe;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(NULL, NULL, 'BASIC +COST +ROWS'));

PROMPT ------------------------------------------------------------
PROMPT  Attendu : INDEX RANGE SCAN sur IX_CMD_DATE_CLIENT
PROMPT  NB : sur petit volume l'optimiseur peut garder le FULL SCAN
PROMPT       Le gain est notable sur 100k+ lignes de commandes
PROMPT ------------------------------------------------------------
