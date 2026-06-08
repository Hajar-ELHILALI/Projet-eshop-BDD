ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- =========================================================
-- TRIGGER INSERT (MASTER) : route la ligne vers le bon site
--   cat 50 & qte > 100 -> Site 1   |   cat 35 & qte > 50 -> Site 2
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE
AFTER INSERT ON lignecommandes
FOR EACH ROW
DECLARE
    v_cat produits.idcateg%TYPE;
    NQ lignecommandes.quantite%TYPE := :NEW.quantite;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    BEGIN
        SELECT idcateg INTO v_cat FROM produits WHERE idproduit = :NEW.idproduit;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_cat := 0;
    END;

    IF (v_cat = 50 AND NQ > 100) THEN
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
    ELSIF (v_cat = 35 AND NQ > 50) THEN
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site2(:1, :2, :3, :4, :5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
    END IF;
END;
/

-- =========================================================
-- TRIGGER DELETE (MASTER) : propage la suppression au site concerne
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE
AFTER DELETE ON lignecommandes
FOR EACH ROW
DECLARE
    v_cat produits.idcateg%TYPE;
    OQ lignecommandes.quantite%TYPE := :OLD.quantite;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    BEGIN
        SELECT idcateg INTO v_cat FROM produits WHERE idproduit = :OLD.idproduit;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN v_cat := 0;
    END;

    IF (v_cat = 50 AND OQ > 100) THEN
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site1(:1); END;'
        USING :OLD.idlignecommande;
    ELSIF (v_cat = 35 AND OQ > 50) THEN
        EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site2(:1); END;'
        USING :OLD.idlignecommande;
    END IF;
END;
/

-- =========================================================
-- TRIGGER UPDATE (MASTER) : gere la migration entre sites
--   A) etait sur Site 1   B) etait sur Site 2   C) entre sur un site
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE
AFTER UPDATE ON lignecommandes
FOR EACH ROW
DECLARE
    OP produits.idproduit%TYPE := :OLD.idproduit;
    NP produits.idproduit%TYPE := :NEW.idproduit;
    OQ lignecommandes.quantite%TYPE := :OLD.quantite;
    NQ lignecommandes.quantite%TYPE := :NEW.quantite;
    OCat produits.idcateg%TYPE;
    NCat produits.idcateg%TYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    BEGIN SELECT idcateg INTO OCat FROM produits WHERE idproduit = OP; EXCEPTION WHEN NO_DATA_FOUND THEN OCat := 0; END;
    BEGIN SELECT idcateg INTO NCat FROM produits WHERE idproduit = NP; EXCEPTION WHEN NO_DATA_FOUND THEN NCat := 0; END;

    -- A) la ligne etait sur Site 1
    IF (OCat = 50 AND OQ > 100) THEN
        IF (NCat = 50 AND NQ > 100) THEN
            EXECUTE IMMEDIATE 'BEGIN updateligne@link_site1(:1, :2, :3, :4); END;'
            USING :NEW.idlignecommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
        ELSE
            EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site1(:1); END;'
            USING :OLD.idlignecommande;
            IF (NCat = 35 AND NQ > 50) THEN
                EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site2(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
            END IF;
        END IF;

    -- B) la ligne etait sur Site 2
    ELSIF (OCat = 35 AND OQ > 50) THEN
        IF (NCat = 35 AND NQ > 50) THEN
            EXECUTE IMMEDIATE 'BEGIN updateligne@link_site2(:1, :2, :3, :4); END;'
            USING :NEW.idlignecommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
        ELSE
            EXECUTE IMMEDIATE 'BEGIN DELETEligne@link_site2(:1); END;'
            USING :OLD.idlignecommande;
            IF (NCat = 50 AND NQ > 100) THEN
                EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
            END IF;
        END IF;

    -- C) la ligne entre sur un site suite a la MAJ
    ELSIF (NCat = 50 AND NQ > 100) THEN
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
    ELSIF (NCat = 35 AND NQ > 50) THEN
        EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site2(:1, :2, :3, :4, :5); END;'
        USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
    END IF;
END;
/
