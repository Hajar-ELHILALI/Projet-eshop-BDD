-- ============================================================
-- SCENARIO 2 | Tests de propagation et de migration
-- ------------------------------------------------------------
-- Objectif : verifier que les triggers de distribution
-- respectent la regle R1/R2 basee sur la quantite seule.
--
-- Plan des tests :
--   T1 - INSERT qte >= 100  → doit aller sur Site 1
--   T2 - INSERT qte <  100  → doit aller sur Site 2
--   T3 - UPDATE qte : franchissement du seuil S1 → S2
--   T4 - UPDATE qte : franchissement du seuil S2 → S1
--   T5 - DELETE               → suppression propagee
--   T6 - Verification de la partition complete (0 doublon)
--
-- Executer sur le master :
--   docker exec -it eshop-master sqlplus ^
--     eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 ^
--     "@/queries/test_propagation.sql"
-- ============================================================
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;
SET SERVEROUTPUT ON
SET LINESIZE 200

-- ============================================================
-- Donnees de test : client, produit, commande bidon
-- ============================================================
DECLARE
    v_idcl   NUMBER := 99901;
    v_idprod NUMBER := 99901;
    v_idcmd  NUMBER := 99901;
    v_idlc_s1 NUMBER := 99901;  -- ligne qui ira sur Site 1 (qte = 150)
    v_idlc_s2 NUMBER := 99902;  -- ligne qui ira sur Site 2 (qte = 40)
    v_cnt    NUMBER;
BEGIN
    -- Prerequis : inserer un client, un produit, une commande de test
    INSERT INTO clients  VALUES (v_idcl,   'TEST-SC2', 'Client Test Scenario 2');
    INSERT INTO produits VALUES (v_idprod,  'Produit Test Sc2', 100, 50);
    INSERT INTO commandes VALUES (v_idcmd, 1, v_idcl, SYSDATE);
    COMMIT;

    -- ========================================================
    -- T1 : INSERT avec quantite = 150 → doit aller sur Site 1
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== T1 : INSERT qte=150 → Site 1 attendu ===');
    INSERT INTO lignecommandes VALUES (v_idlc_s1, v_idcmd, v_idprod, 150, 0.05);
    COMMIT;

    -- Verification sur Site 1 (doit exister)
    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site1.lignecommandes1@link_site1
    WHERE idlignecommande = v_idlc_s1;
    DBMS_OUTPUT.PUT_LINE('  Site 1 (attendu 1) : ' || v_cnt);

    -- Verification sur Site 2 (ne doit PAS exister)
    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site2.lignecommandes2@link_site2
    WHERE idlignecommande = v_idlc_s1;
    DBMS_OUTPUT.PUT_LINE('  Site 2 (attendu 0) : ' || v_cnt);

    -- ========================================================
    -- T2 : INSERT avec quantite = 40 → doit aller sur Site 2
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== T2 : INSERT qte=40 → Site 2 attendu ===');
    INSERT INTO lignecommandes VALUES (v_idlc_s2, v_idcmd, v_idprod, 40, 0);
    COMMIT;

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site2.lignecommandes2@link_site2
    WHERE idlignecommande = v_idlc_s2;
    DBMS_OUTPUT.PUT_LINE('  Site 2 (attendu 1) : ' || v_cnt);

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site1.lignecommandes1@link_site1
    WHERE idlignecommande = v_idlc_s2;
    DBMS_OUTPUT.PUT_LINE('  Site 1 (attendu 0) : ' || v_cnt);

    -- ========================================================
    -- T3 : UPDATE qte 150 → 30 : Site 1 doit perdre la ligne,
    --       Site 2 doit la recevoir (migration R1 → R2)
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== T3 : UPDATE qte 150 → 30 : migration S1 → S2 ===');
    UPDATE lignecommandes SET quantite = 30 WHERE idlignecommande = v_idlc_s1;
    COMMIT;

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site1.lignecommandes1@link_site1
    WHERE idlignecommande = v_idlc_s1;
    DBMS_OUTPUT.PUT_LINE('  Site 1 (attendu 0, ligne migree) : ' || v_cnt);

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site2.lignecommandes2@link_site2
    WHERE idlignecommande = v_idlc_s1;
    DBMS_OUTPUT.PUT_LINE('  Site 2 (attendu 1, ligne recue)  : ' || v_cnt);

    -- ========================================================
    -- T4 : UPDATE qte 40 → 200 : Site 2 doit perdre la ligne,
    --       Site 1 doit la recevoir (migration R2 → R1)
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== T4 : UPDATE qte 40 → 200 : migration S2 → S1 ===');
    UPDATE lignecommandes SET quantite = 200 WHERE idlignecommande = v_idlc_s2;
    COMMIT;

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site2.lignecommandes2@link_site2
    WHERE idlignecommande = v_idlc_s2;
    DBMS_OUTPUT.PUT_LINE('  Site 2 (attendu 0, ligne migree) : ' || v_cnt);

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site1.lignecommandes1@link_site1
    WHERE idlignecommande = v_idlc_s2;
    DBMS_OUTPUT.PUT_LINE('  Site 1 (attendu 1, ligne recue)  : ' || v_cnt);

    -- ========================================================
    -- T5 : DELETE → les deux lignes doivent disparaitre partout
    -- ========================================================
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '=== T5 : DELETE → propagation sur tous les sites ===');
    DELETE FROM lignecommandes WHERE idlignecommande IN (v_idlc_s1, v_idlc_s2);
    COMMIT;

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site1.lignecommandes1@link_site1
    WHERE idlignecommande IN (v_idlc_s1, v_idlc_s2);
    DBMS_OUTPUT.PUT_LINE('  Site 1 apres delete (attendu 0) : ' || v_cnt);

    SELECT COUNT(*) INTO v_cnt
    FROM eshop_site2.lignecommandes2@link_site2
    WHERE idlignecommande IN (v_idlc_s1, v_idlc_s2);
    DBMS_OUTPUT.PUT_LINE('  Site 2 apres delete (attendu 0) : ' || v_cnt);

    SELECT COUNT(*) INTO v_cnt
    FROM lignecommandes
    WHERE idlignecommande IN (v_idlc_s1, v_idlc_s2);
    DBMS_OUTPUT.PUT_LINE('  Master apres delete (attendu 0) : ' || v_cnt);

    -- ========================================================
    -- Nettoyage des donnees de test
    -- ========================================================
    DELETE FROM commandes WHERE idcommande = v_idcmd;
    DELETE FROM produits   WHERE idproduit  = v_idprod;
    DELETE FROM clients    WHERE idclient   = v_idcl;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '--- Donnees de test nettoyees ---');
END;
/

-- ============================================================
-- T6 : Verification de la partition complete
-- Aucune ligne de commande ne doit apparaitre dans les deux
-- fragments simultanement.
-- ============================================================
PROMPT
PROMPT === T6 : Partition complete - verification des doublons ===
SELECT COUNT(*) AS doublons_entre_fragments
FROM (
    SELECT idlignecommande FROM eshop_site1.lignecommandes1@link_site1
    INTERSECT
    SELECT idlignecommande FROM eshop_site2.lignecommandes2@link_site2
);

-- Verification de la couverture totale
-- (R1 + R2 doit couvrir toutes les lignes du master qui ont qte >=100 ou <100)
PROMPT === Verification de la couverture (R1 + R2 = Master) ===
SELECT
    'Master'   AS fragment, COUNT(*) AS nb_lignes FROM lignecommandes
UNION ALL
SELECT 'Site 1 (R1 : qte>=100)', COUNT(*) FROM eshop_site1.lignecommandes1@link_site1
UNION ALL
SELECT 'Site 2 (R2 : qte<100)', COUNT(*) FROM eshop_site2.lignecommandes2@link_site2;

-- Verification des erreurs de synchronisation (doivent etre vides)
PROMPT === Erreurs de synchronisation (attendu : 0 lignes) ===
PROMPT -- Site 1 --
SELECT * FROM eshop_site1.sync_errors@link_site1;
PROMPT -- Site 2 --
SELECT * FROM eshop_site2.sync_errors@link_site2;
