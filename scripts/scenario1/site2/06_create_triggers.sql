ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

-- =========================================================
-- TRIGGER INSERT (SITE 2)
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE_SITE2
FOR INSERT ON lignecommandes2
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes2.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
        v_categ NUMBER;
    BEGIN
        -- On enveloppe tout dans le IF
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN 

            -- Récupération de la catégorie
            BEGIN
                SELECT idcateg INTO v_categ FROM produits WHERE idproduit = :NEW.idproduit;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN v_categ := 0;
            END;

            -- 1. Envoi systématique au Master
            EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_central(:1, :2, :3, :4, :5); END;'
            USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;

            -- 2. Routage direct vers Site 1 (Cat 50, Qte > 100)
            IF v_categ = 50 AND :NEW.quantite > 100 THEN
                EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
            END IF;
                
            -- 3. Vérification de la règle locale (Garde les Cat 35, Qte > 50, sinon supprime)
            IF NOT (v_categ = 35 AND :NEW.quantite > 50) THEN
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :NEW.idlignecommande;
            END IF;

        END IF; -- Fin de la vérification is_replicating
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE; 
            
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes2 WHERE idlignecommande = v_ids_to_delete(i);
            END LOOP;
            
            pkg_synchro.is_replicating := FALSE;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            pkg_synchro.is_replicating := FALSE; 
            RAISE;
    END AFTER STATEMENT;

END SYC_INSERT_LIGNE_SITE2;
/
SHOW ERRORS TRIGGER SYC_INSERT_LIGNE_SITE2;

-- =========================================================
-- TRIGGER UPDATE (SITE 2)
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE_SITE2
FOR UPDATE ON lignecommandes2
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes2.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
        NCat NUMBER;
    BEGIN
        -- On enveloppe dans le IF
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN 

            BEGIN SELECT idcateg INTO NCat FROM produits WHERE idproduit = :NEW.idproduit; EXCEPTION WHEN NO_DATA_FOUND THEN NCat := 0; END;

            -- 1. MAJ systématique sur le Master
            EXECUTE IMMEDIATE 'BEGIN updateligne@link_central(:1, :2, :3, :4); END;'
            USING :NEW.idlignecommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;

            -- 2. Routage et nettoyage
            IF NOT (NCat = 35 AND :NEW.quantite > 50) THEN
                
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :OLD.idlignecommande;
                
                -- Routage vers Site 1 si ça correspond à sa règle
                IF (NCat = 50 AND :NEW.quantite > 100) THEN
                    EXECUTE IMMEDIATE 'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
                    USING :NEW.idlignecommande, :NEW.idcommande, :NEW.idproduit, :NEW.quantite, :NEW.remise;
                END IF;
            END IF;

        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE;
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes2 WHERE idlignecommande = v_ids_to_delete(i);
            END LOOP;
            pkg_synchro.is_replicating := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            pkg_synchro.is_replicating := FALSE; 
            RAISE;
    END AFTER STATEMENT;

END SYC_UPDATE_LIGNE_SITE2;
/
SHOW ERRORS TRIGGER SYC_UPDATE_LIGNE_SITE2;

-- =========================================================
-- TRIGGER DELETE (SITE 2)
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE_SITE2
AFTER DELETE ON lignecommandes2
FOR EACH ROW
BEGIN
    IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN
        -- Informe le Master de la suppression
        BEGIN
            EXECUTE IMMEDIATE 'BEGIN deleteligne@link_central(:1); END;' USING :OLD.idlignecommande;
        EXCEPTION
            -- On ne bloque pas la suppression locale, MAIS on trace l'échec
            -- (au lieu de l'avaler en silence) dans la table SYNC_ERRORS.
            WHEN OTHERS THEN
                log_sync_error('SYC_DELETE_LIGNE_SITE2', :OLD.idlignecommande, SQLERRM);
        END;
    END IF;
END;
/
SHOW ERRORS TRIGGER SYC_DELETE_LIGNE_SITE2;

-- =========================================================
-- TRIGGER BEFORE UPDATE (SITE 2) - Pull du nouveau produit
-- =========================================================
CREATE OR REPLACE TRIGGER TRG_PULL_PROD_BEFORE_UPD_SITE2
BEFORE UPDATE OF idproduit ON lignecommandes2
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_prod  produits%ROWTYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;
    IF :OLD.idproduit = :NEW.idproduit THEN RETURN; END IF;
    SELECT COUNT(*) INTO v_count FROM produits2 WHERE idproduit = :NEW.idproduit;
    IF v_count = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = :NEW.idproduit;
        INSERT INTO produits2 VALUES v_prod;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20011,
            'Produit ' || :NEW.idproduit || ' introuvable sur le master.');
END;
/
SHOW ERRORS TRIGGER TRG_PULL_PROD_BEFORE_UPD_SITE2;

-- =========================================================
-- TRIGGER BEFORE INSERT (SITE 2) - Pull des parents depuis master
-- =========================================================
CREATE OR REPLACE TRIGGER TRG_PULL_PARENTS_SITE2
BEFORE INSERT ON lignecommandes2
FOR EACH ROW
DECLARE
    v_count  NUMBER;
    v_cmd    commandes%ROWTYPE;
    v_prod   produits%ROWTYPE;
    v_cli    clients%ROWTYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    SELECT COUNT(*) INTO v_count FROM produits2 WHERE idproduit = :NEW.idproduit;
    IF v_count = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = :NEW.idproduit;
        INSERT INTO produits2 VALUES v_prod;
    END IF;

    SELECT COUNT(*) INTO v_count FROM commandes2 WHERE idcommande = :NEW.idcommande;
    IF v_count = 0 THEN
        SELECT * INTO v_cmd FROM commandes WHERE idcommande = :NEW.idcommande;
        SELECT COUNT(*) INTO v_count FROM clients2 WHERE idclient = v_cmd.idclient;
        IF v_count = 0 THEN
            SELECT * INTO v_cli FROM clients WHERE idclient = v_cmd.idclient;
            INSERT INTO clients2 VALUES v_cli;
        END IF;
        INSERT INTO commandes2 VALUES v_cmd;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010,
            'Erreur PULL : donnee parente introuvable sur le master.');
END;
/
SHOW ERRORS TRIGGER TRG_PULL_PARENTS_SITE2;