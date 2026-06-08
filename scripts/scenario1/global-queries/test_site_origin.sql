-- ============================================================
-- TEST DE PROPAGATION — origine : SITE 1
-- Vérifie qu'une écriture FAITE sur Site 1 se propage :
--   - vers le Master (toujours)
--   - vers Site 2 (routage des lignes cat 35)
--   - et que Site 1 ne garde que ce qui respecte R1 (cat 50)
--
-- À lancer sur le Site 1 (depuis l'hôte, par redirection) :
--   Get-Content scripts\global-queries\test_site_origin.sql | `
--     docker exec -i eshop-site1 sqlplus eshop_site1/EshopPassword123@//localhost:1521/XEPDB1
-- ============================================================
SET SERVEROUTPUT ON
SET LINESIZE 200

PROMPT
PROMPT ====== TESTS DE PROPAGATION (origine SITE 1) ======

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
    DELETE FROM lignecommandes1 WHERE remise BETWEEN 90 AND 99;
    COMMIT;

    -- ---- TEST 1 : INSERT cat 50 / qté 150 -> reste sur Site 1 + va au Master ----
    BEGIN
        INSERT INTO lignecommandes1 (idcommande, idproduit, quantite, remise)
        VALUES (30001, 20001, 150, 93);
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM lignecommandes1 WHERE remise = 93;
        check_('site1 garde la cat50 localement', v_cnt, 1);
        SELECT COUNT(*) INTO v_cnt FROM lignecommandes@link_central WHERE remise = 93;
        check_('site1 -> master', v_cnt, 1);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test1 erreur: '||SQLERRM);
    END;

    -- ---- TEST 2 : INSERT cat 35 / qté 80 -> routé vers Site 2, retiré de Site 1 ----
    BEGIN
        INSERT INTO lignecommandes1 (idcommande, idproduit, quantite, remise)
        VALUES (30003, 20011, 80, 94);
        COMMIT;
        SELECT COUNT(*) INTO v_cnt FROM lignecommandes1 WHERE remise = 94;
        check_('site1 ne garde pas la cat35', v_cnt, 0);
        SELECT COUNT(*) INTO v_cnt FROM lignecommandes2@link_site2 WHERE remise = 94;
        check_('site1 -> site2 (routage cat35)', v_cnt, 1);
    EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('FAIL | test2 erreur: '||SQLERRM);
    END;

    -- Nettoyage (master + sites via la propagation du DELETE)
    DELETE FROM lignecommandes1 WHERE remise BETWEEN 90 AND 99;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('------ fin des tests (origine site1) ------');
    DBMS_OUTPUT.PUT_LINE('NB : si "site1 -> site2" echoue, c''est le bug connu de routage cross-site.');
END;
/
