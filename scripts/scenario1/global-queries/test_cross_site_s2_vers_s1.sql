-- ============================================================
-- SCENARIO 1 | Test : modification d'un element de Site 1
--              effectuee DEPUIS Site 2
-- ------------------------------------------------------------
-- Ce script se connecte en tant que eshop_site2 et appelle
-- directement la procedure updateligne@link_site1, simulant
-- une modification initiee par Site 2 sur un element stocke
-- dans le fragment de Site 1.
--
-- Flux attendu :
--   Site 2 → updateligne@link_site1(...)
--     → trigger SYC_UPDATE_LIGNE_SITE1 sur Site 1
--       → updateligne@link_central(...) propagation au Master
--
-- Comment executer (depuis le container Site 2) :
--   docker exec -it eshop-site2 sqlplus \
--     eshop_site2/EshopPassword123@//localhost:1521/XEPDB1 \
--     "@/queries/test_cross_site_s2_vers_s1.sql"
-- ============================================================
SET SERVEROUTPUT ON
SET LINESIZE 200
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

DECLARE
    -- Identifiants de la ligne cible (sur Site 1)
    v_idlc       NUMBER;
    v_idprod     NUMBER;
    v_old_qte    NUMBER;
    v_old_rem    NUMBER;
    v_new_qte    NUMBER;
    v_new_rem    NUMBER;

    -- Pour les verifications
    v_qte_site1  NUMBER;
    v_qte_master NUMBER;
    v_cnt        NUMBER;
BEGIN
    -- --------------------------------------------------------
    -- ETAPE 0 : Choisir une ligne existante sur Site 1
    --           (cat 50, quantite > 100)
    -- --------------------------------------------------------
    BEGIN
        SELECT idlignecommande, idproduit, quantite, remise
        INTO   v_idlc, v_idprod, v_old_qte, v_old_rem
        FROM   eshop_site1.lignecommandes1@link_site1
        WHERE  ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20099,
                'Aucune ligne disponible sur Site 1. '
                || 'Verifiez que les donnees initiales ont bien ete chargees.');
    END;

    v_new_qte := v_old_qte + 25;   -- on augmente la quantite (reste > 100)
    v_new_rem := 0.10;              -- on change aussi la remise

    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' TEST : modification Site 1 depuis Site 2');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('Ligne cible    : idlignecommande = ' || v_idlc);
    DBMS_OUTPUT.PUT_LINE('Produit        : idproduit       = ' || v_idprod);
    DBMS_OUTPUT.PUT_LINE('Quantite AVANT : ' || v_old_qte);
    DBMS_OUTPUT.PUT_LINE('Quantite APRES : ' || v_new_qte);
    DBMS_OUTPUT.PUT_LINE('Remise APRES   : ' || v_new_rem);
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

    -- --------------------------------------------------------
    -- ETAPE 1 : Appel de updateligne sur Site 1 DEPUIS Site 2
    -- --------------------------------------------------------
    EXECUTE IMMEDIATE
        'BEGIN eshop_site1.updateligne@link_site1(:1, :2, :3, :4); END;'
    USING v_idlc, v_idprod, v_new_qte, v_new_rem;

    DBMS_OUTPUT.PUT_LINE('> updateligne@link_site1 appele depuis Site 2 : OK');

    -- --------------------------------------------------------
    -- ETAPE 2 : Verification sur Site 1
    --           La ligne doit avoir la nouvelle quantite
    -- --------------------------------------------------------
    SELECT quantite INTO v_qte_site1
    FROM   eshop_site1.lignecommandes1@link_site1
    WHERE  idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Verification Site 1 ---');
    IF v_qte_site1 = v_new_qte THEN
        DBMS_OUTPUT.PUT_LINE('[OK] Quantite sur Site 1 = ' || v_qte_site1
                             || ' (attendu ' || v_new_qte || ')');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ECHEC] Quantite sur Site 1 = ' || v_qte_site1
                             || ' (attendu ' || v_new_qte || ')');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 3 : Verification sur le Master
    --           Le trigger de Site 1 doit avoir propage la MAJ
    -- --------------------------------------------------------
    SELECT quantite INTO v_qte_master
    FROM   eshop_admin.lignecommandes@link_central
    WHERE  idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Verification Master ---');
    IF v_qte_master = v_new_qte THEN
        DBMS_OUTPUT.PUT_LINE('[OK] Quantite sur Master = ' || v_qte_master
                             || ' (attendu ' || v_new_qte || ')');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ECHEC] Quantite sur Master = ' || v_qte_master
                             || ' (attendu ' || v_new_qte || ')');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 4 : Verification que la ligne n'est PAS sur Site 2
    --           (elle appartient a Site 1, pas a Site 2)
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO v_cnt
    FROM   lignecommandes2
    WHERE  idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Verification Site 2 ---');
    IF v_cnt = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[OK] Ligne absente de Site 2 (normal : elle appartient a R1)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ANOMALIE] Ligne presente sur Site 2 (ne devrait pas y etre)');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 5 : Restauration (optionnelle)
    -- --------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Restauration de la valeur initiale ---');
    EXECUTE IMMEDIATE
        'BEGIN eshop_site1.updateligne@link_site1(:1, :2, :3, :4); END;'
    USING v_idlc, v_idprod, v_old_qte, v_old_rem;
    DBMS_OUTPUT.PUT_LINE('[OK] Valeur restauree (qte=' || v_old_qte
                         || ', remise=' || v_old_rem || ')');

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' FIN DU TEST SCENARIO 1');
    DBMS_OUTPUT.PUT_LINE('============================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[ERREUR] ' || SQLERRM);
        RAISE;
END;
/
