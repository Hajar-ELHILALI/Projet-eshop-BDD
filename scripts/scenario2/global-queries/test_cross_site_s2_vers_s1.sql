-- ============================================================
-- SCENARIO 2 | Test : modification d'un element de Site 1
--              effectuee DEPUIS Site 2
-- ------------------------------------------------------------
-- Ce script se connecte en tant que eshop_site2 et met a jour
-- une ligne locale (lignecommandes2) en changeant sa quantite
-- de < 100 a >= 100.
--
-- Flux attendu :
--   UPDATE lignecommandes2 SET quantite = 150
--     → trigger SYC_UPDATE_LIGNE_SITE2 (compound) :
--         1. updateligne@link_central    (Master mis a jour)
--         2. INSERTligne@link_site1      (ligne migre vers Site 1)
--         3. DELETE local (AFTER STATEMENT) : ligne retiree de Site 2
--
-- Resultat final :
--   - Site 2 : ligne ABSENTE  (qte n'est plus < 100)
--   - Site 1 : ligne PRESENTE (qte >= 100, appartient a R1)
--   - Master : qte = 150
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
    -- Ligne cible sur Site 2 (doit avoir quantite < 100)
    v_idlc       NUMBER;
    v_idcmd      NUMBER;
    v_idprod     NUMBER;
    v_old_qte    NUMBER;
    v_old_rem    NUMBER;

    -- Nouvelle valeur (franchit le seuil vers le haut)
    v_new_qte    NUMBER := 150;

    -- Pour les verifications
    v_cnt_s2     NUMBER;
    v_cnt_s1     NUMBER;
    v_qte_master NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' TEST : migration Site 2 → Site 1 (Scenario 2)');
    DBMS_OUTPUT.PUT_LINE(' Modification depuis Site 2 : qte < 100 → 150');
    DBMS_OUTPUT.PUT_LINE('============================================');

    -- --------------------------------------------------------
    -- ETAPE 0 : Choisir une ligne existante sur Site 2
    --           (doit avoir quantite < 100, critere de R2)
    -- --------------------------------------------------------
    BEGIN
        SELECT idlignecommande, idcommande, idproduit, quantite, remise
        INTO   v_idlc, v_idcmd, v_idprod, v_old_qte, v_old_rem
        FROM   lignecommandes2
        WHERE  quantite < 100
        AND    ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20099,
                'Aucune ligne (quantite < 100) trouvee sur Site 2. '
                || 'Verifiez que les donnees initiales ont ete chargees.');
    END;

    DBMS_OUTPUT.PUT_LINE('Ligne cible    : idlignecommande = ' || v_idlc);
    DBMS_OUTPUT.PUT_LINE('Commande       : idcommande      = ' || v_idcmd);
    DBMS_OUTPUT.PUT_LINE('Produit        : idproduit       = ' || v_idprod);
    DBMS_OUTPUT.PUT_LINE('Quantite AVANT : ' || v_old_qte || ' (< 100 → appartient a R2/Site 2)');
    DBMS_OUTPUT.PUT_LINE('Quantite APRES : ' || v_new_qte || ' (>= 100 → devra migrer vers R1/Site 1)');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------');

    -- --------------------------------------------------------
    -- ETAPE 1 : Etat AVANT la modification
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO v_cnt_s2
    FROM   lignecommandes2 WHERE idlignecommande = v_idlc;

    SELECT COUNT(*) INTO v_cnt_s1
    FROM   eshop_site1.lignecommandes1@link_site1 WHERE idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Etat AVANT la modification ---');
    DBMS_OUTPUT.PUT_LINE('Site 2 (attendu 1) : ' || v_cnt_s2);
    DBMS_OUTPUT.PUT_LINE('Site 1 (attendu 0) : ' || v_cnt_s1);

    -- --------------------------------------------------------
    -- ETAPE 2 : Modification sur Site 2 (franchissement du seuil)
    --           Le trigger SYC_UPDATE_LIGNE_SITE2 va :
    --             - propager au Master
    --             - inserer sur Site 1
    --             - supprimer localement (AFTER STATEMENT)
    -- --------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('> UPDATE lignecommandes2 SET quantite = ' || v_new_qte
                         || ' WHERE idlignecommande = ' || v_idlc);

    UPDATE lignecommandes2
    SET    quantite = v_new_qte
    WHERE  idlignecommande = v_idlc;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('> COMMIT effectue');

    -- --------------------------------------------------------
    -- ETAPE 3 : Verification sur Site 2
    --           La ligne doit avoir disparu (migree vers Site 1)
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO v_cnt_s2
    FROM   lignecommandes2 WHERE idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Etat APRES la modification ---');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Site 2 (attendu 0 - ligne migree) : ' || v_cnt_s2);
    IF v_cnt_s2 = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[OK] La ligne a bien quitte Site 2');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ECHEC] La ligne est toujours sur Site 2 !');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 4 : Verification sur Site 1
    --           La ligne doit maintenant y etre (qte = 150)
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO v_cnt_s1
    FROM   eshop_site1.lignecommandes1@link_site1
    WHERE  idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Site 1 (attendu 1 - ligne arrivee) : ' || v_cnt_s1);
    IF v_cnt_s1 = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[OK] La ligne est bien arrivee sur Site 1');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ECHEC] La ligne n''est pas sur Site 1 !');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 5 : Verification sur le Master
    --           La quantite doit etre 150
    -- --------------------------------------------------------
    SELECT quantite INTO v_qte_master
    FROM   eshop_admin.lignecommandes@link_central
    WHERE  idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Master - quantite (attendu ' || v_new_qte || ') : ' || v_qte_master);
    IF v_qte_master = v_new_qte THEN
        DBMS_OUTPUT.PUT_LINE('[OK] Master synchronise');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[ECHEC] Valeur incorrecte sur le Master !');
    END IF;

    -- --------------------------------------------------------
    -- ETAPE 6 : Restauration (retour dans R2 : qte < 100)
    --           On remet la valeur originale depuis le Master
    --           Le trigger du Master renverra la ligne vers Site 2
    -- --------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Restauration (UPDATE sur le Master) ---');
    UPDATE eshop_admin.lignecommandes@link_central
    SET    quantite = v_old_qte, remise = v_old_rem
    WHERE  idlignecommande = v_idlc;
    COMMIT;

    -- Verification de la restauration
    SELECT COUNT(*) INTO v_cnt_s2
    FROM   lignecommandes2 WHERE idlignecommande = v_idlc;
    SELECT COUNT(*) INTO v_cnt_s1
    FROM   eshop_site1.lignecommandes1@link_site1 WHERE idlignecommande = v_idlc;

    DBMS_OUTPUT.PUT_LINE('[OK] Restauration : qte=' || v_old_qte
                         || ' | Site 2=' || v_cnt_s2
                         || ' | Site 1=' || v_cnt_s1);

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE(' FIN DU TEST SCENARIO 2');
    DBMS_OUTPUT.PUT_LINE('============================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('[ERREUR] ' || SQLERRM);
        RAISE;
END;
/
