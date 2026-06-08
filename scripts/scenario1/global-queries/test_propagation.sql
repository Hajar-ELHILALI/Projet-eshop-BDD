-- ============================================================
-- TEST DE PROPAGATION — origine : MASTER (base globale)
-- Vérifie que les triggers SYC_* distribuent correctement les
-- INSERT / UPDATE / DELETE vers les sites, via les database links.
--
-- À lancer sur le master :
--   docker exec -it eshop-master sqlplus eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 @/queries/test_propagation.sql
--
-- Marqueurs de test : colonne remise dans 90..99 (nettoyée à la fin).
-- ============================================================
SET SERVEROUTPUT ON
SET LINESIZE 200
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

PROMPT
PROMPT ====== TESTS DE PROPAGATION (origine MASTER) ======

DECLARE
    v_cnt NUMBER;

    PROCEDURE check_(p_label VARCHAR2, p_actual NUMBER, p_expected NUMBER) IS
    BEGIN
        IF p_actual = p_expected THEN
            DBMS_OUTPUT.PUT_LINE('OK   | ' || RPAD(p_label, 42) || ' = ' || p_actual);
        ELSE
            DBMS_OUTPUT.PUT_LINE('FAIL | ' || RPAD(p_label, 42) ||
                                 ' attendu ' || p_expected || ', obtenu ' || p_actual);
        END IF;
    END;
BEGIN
    -- Nettoyage des marqueurs de test précédents
    DELETE FROM lignecommandes WHERE remise BETWEEN 90 AND 99;
    COMMIT;

    -- ---- TEST 1 : INSERT cat 50 / qté 150 -> doit aller sur Site 1 ----
    BEGIN
        INSERT INTO lignecommandes (idcommande, idproduit, quantite, remise)
        VALUES (30001, 20001, 150, 91);
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM eshop_site1.lignecommandes1@link_site1 WHERE remise = 91;
        check_('master -> site1 (insert cat50)', v_cnt, 1);
        SELECT COUNT(*) INTO v_cnt FROM eshop_site2.lignecommandes2@link_site2 WHERE remise = 91;
        check_('  pas de fuite vers site2', v_cnt, 0);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test1 erreur: '||SQLERRM);
    END;

    -- ---- TEST 2 : INSERT cat 35 / qté 80 -> doit aller sur Site 2 ----
    BEGIN
        INSERT INTO lignecommandes (idcommande, idproduit, quantite, remise)
        VALUES (30002, 20011, 80, 92);
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM eshop_site2.lignecommandes2@link_site2 WHERE remise = 92;
        check_('master -> site2 (insert cat35)', v_cnt, 1);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test2 erreur: '||SQLERRM);
    END;

    -- ---- TEST 3 : UPDATE qui sort la ligne du fragment Site 2 ----
    BEGIN
        UPDATE lignecommandes SET quantite = 10 WHERE remise = 92;   -- 10 <= 50 => hors R2
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM eshop_site2.lignecommandes2@link_site2 WHERE remise = 92;
        check_('master -> site2 (update sort du fragment)', v_cnt, 0);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test3 erreur: '||SQLERRM);
    END;

    -- ---- TEST 4 : DELETE -> doit disparaître du Site 1 ----
    BEGIN
        DELETE FROM lignecommandes WHERE remise = 91;
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM eshop_site1.lignecommandes1@link_site1 WHERE remise = 91;
        check_('master -> site1 (delete)', v_cnt, 0);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test4 erreur: '||SQLERRM);
    END;

    -- Nettoyage final
    DELETE FROM lignecommandes WHERE remise BETWEEN 90 AND 99;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('------ fin des tests (origine master) ------');
END;
/
