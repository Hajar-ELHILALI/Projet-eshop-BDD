-- ============================================================
-- SCENARIO 2 | MASTER -- Triggers de distribution
-- ------------------------------------------------------------
-- Regle de fragmentation :
--   R1 = sigma(quantite >= 100)  --> Site 1
--   R2 = sigma(quantite <  100)  --> Site 2
--
-- Difference cle avec Scenario 1 :
--   Le routage se base UNIQUEMENT sur la quantite (pas de categorie).
--   La partition est COMPLETE : toute ligne appartient a exactement
--   un des deux fragments.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- =========================================================
-- 1. TRIGGER INSERT
--    Route vers Site 1 si quantite >= 100,
--    vers Site 2 si quantite < 100.
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON lignecommandes
FOR EACH ROW
DECLARE
    NQ lignecommandes.quantite%TYPE := :NEW.quantite;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    IF NQ >= 100 THEN
        -- R1 : quantite >= 100 --> Site 1
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1,:2,:3,:4,:5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit,
              :NEW.quantite, :NEW.remise;
    ELSE
        -- R2 : quantite < 100 --> Site 2
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site2(:1,:2,:3,:4,:5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit,
              :NEW.quantite, :NEW.remise;
    END IF;
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SYC_INSERT_LIGNE SC2 ERROR: ' || SQLERRM);
END;
/

-- =========================================================
-- 2. TRIGGER DELETE
--    Supprime sur le site ou se trouve la ligne
--    (determine par l'ancienne valeur de quantite).
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON lignecommandes
FOR EACH ROW
DECLARE
    OQ lignecommandes.quantite%TYPE := :OLD.quantite;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    IF OQ >= 100 THEN
        -- La ligne etait sur Site 1
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site1(:1); END;'
        USING :OLD.idlignecommande;
    ELSE
        -- La ligne etait sur Site 2
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site2(:1); END;'
        USING :OLD.idlignecommande;
    END IF;
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SYC_DELETE_LIGNE SC2 ERROR: ' || SQLERRM);
END;
/

-- =========================================================
-- 3. TRIGGER UPDATE
--    4 scenarios selon le franchissement du seuil 100 :
--      A : OQ >= 100 ET NQ >= 100  --> reste sur Site 1 (update)
--      B : OQ >= 100 ET NQ <  100  --> quitte Site 1, entre Site 2
--      C : OQ <  100 ET NQ >= 100  --> quitte Site 2, entre Site 1
--      D : OQ <  100 ET NQ <  100  --> reste sur Site 2 (update)
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON lignecommandes
FOR EACH ROW
DECLARE
    OQ lignecommandes.quantite%TYPE := :OLD.quantite;
    NQ lignecommandes.quantite%TYPE := :NEW.quantite;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    -- Scenario A : reste sur Site 1
    IF OQ >= 100 AND NQ >= 100 THEN
        EXECUTE IMMEDIATE 'BEGIN updateligne@link_site1(:1,:2,:3,:4); END;'
        USING :NEW.idlignecommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;

    -- Scenario B : quitte Site 1, entre sur Site 2
    ELSIF OQ >= 100 AND NQ < 100 THEN
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site1(:1); END;'
        USING :OLD.idlignecommande;
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site2(:1,:2,:3,:4,:5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande,
              :NEW.idproduit, :NEW.quantite, :NEW.remise;

    -- Scenario C : quitte Site 2, entre sur Site 1
    ELSIF OQ < 100 AND NQ >= 100 THEN
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site2(:1); END;'
        USING :OLD.idlignecommande;
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1,:2,:3,:4,:5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande,
              :NEW.idproduit, :NEW.quantite, :NEW.remise;

    -- Scenario D : reste sur Site 2
    ELSE
        EXECUTE IMMEDIATE 'BEGIN updateligne@link_site2(:1,:2,:3,:4); END;'
        USING :NEW.idlignecommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
    END IF;
EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SYC_UPDATE_LIGNE SC2 ERROR: ' || SQLERRM);
END;
/
