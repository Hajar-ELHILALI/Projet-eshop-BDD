-- ============================================================
-- SCENARIO 2 | SITE 2 -- Triggers de synchronisation
-- ------------------------------------------------------------
-- Regle locale de Site 2 : R2 = sigma(quantite < 100)
--
-- Logique symetrique a Site 1 (mais seuil inverse) :
--   - Si quantite < 100  : la ligne appartient a ce site
--   - Si quantite >= 100 : la ligne doit migrer vers Site 1
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

-- =========================================================
-- TRIGGER BEFORE INSERT : pull des parents depuis le master
-- =========================================================
CREATE OR REPLACE TRIGGER TRG_PULL_PARENTS_SITE2
BEFORE INSERT ON lignecommandes2
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_cmd   commandes%ROWTYPE;
    v_prod  produits%ROWTYPE;
    v_cli   clients%ROWTYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    -- Pull du produit
    SELECT COUNT(*) INTO v_count FROM produits2 WHERE idproduit = :NEW.idproduit;
    IF v_count = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = :NEW.idproduit;
        INSERT INTO produits2 VALUES v_prod;
    END IF;

    -- Pull de la commande (et du client parent)
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
            'SC2 SITE2 PULL : donnee parente introuvable sur le master.');
END TRG_PULL_PARENTS_SITE2;
/
SHOW ERRORS TRIGGER TRG_PULL_PARENTS_SITE2;

-- =========================================================
-- TRIGGER BEFORE UPDATE : pull du nouveau produit avant FK
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
            'SC2 SITE2 : Produit ' || :NEW.idproduit || ' introuvable sur le master.');
END TRG_PULL_PROD_BEFORE_UPD_SITE2;
/
SHOW ERRORS TRIGGER TRG_PULL_PROD_BEFORE_UPD_SITE2;

-- =========================================================
-- TRIGGER INSERT (SITE 2) — Compound
-- Apres chaque INSERT sur lignecommandes2 :
--   1. Propage toujours au Master
--   2. Si quantite >= 100 : la ligne ne respecte pas R2
--      → la router vers Site 1 ET la marquer pour suppression locale
--   3. Si quantite < 100 : conserver localement
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE_SITE2
FOR INSERT ON lignecommandes2
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes2.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
    BEGIN
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN

            -- 1. Propagation systematique vers le Master
            EXECUTE IMMEDIATE
                'BEGIN INSERTligne@link_central(:1, :2, :3, :4, :5); END;'
            USING :NEW.idlignecommande, :NEW.idcommande,
                  :NEW.idproduit, :NEW.quantite, :NEW.remise;

            -- 2. Routage croise si la ligne ne respecte pas R2
            IF :NEW.quantite >= 100 THEN
                -- Envoyer vers Site 1 (fragment R1)
                EXECUTE IMMEDIATE
                    'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande,
                      :NEW.idproduit, :NEW.quantite, :NEW.remise;
                -- Marquer pour suppression locale
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :NEW.idlignecommande;
            END IF;
            -- Si quantite < 100 : la ligne reste ici

        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE;
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes2
                WHERE idlignecommande = v_ids_to_delete(i);
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
-- TRIGGER UPDATE (SITE 2) — Compound
-- Apres chaque UPDATE sur lignecommandes2 :
--   1. Propage toujours l'UPDATE au Master
--   2. Si NEW.quantite >= 100 : la ligne quitte R2
--      → l'inserer sur Site 1 ET la supprimer localement
--   3. Si NEW.quantite < 100 : elle reste dans R2
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE_SITE2
FOR UPDATE ON lignecommandes2
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes2.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
    BEGIN
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN

            -- 1. Propagation de la MAJ au Master
            EXECUTE IMMEDIATE
                'BEGIN updateligne@link_central(:1, :2, :3, :4); END;'
            USING :NEW.idlignecommande, :NEW.idproduit,
                  :NEW.quantite, :NEW.remise;

            -- 2. Verifier si la ligne migre vers R1
            IF :NEW.quantite >= 100 THEN
                -- La ligne franchit le seuil vers le haut : migre vers Site 1
                EXECUTE IMMEDIATE
                    'BEGIN INSERTligne@link_site1(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande,
                      :NEW.idproduit, :NEW.quantite, :NEW.remise;
                -- Marquer pour suppression locale
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :OLD.idlignecommande;
            END IF;
            -- Si NEW.quantite < 100 : reste dans R2

        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE;
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes2
                WHERE idlignecommande = v_ids_to_delete(i);
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
-- Informe le Master de la suppression.
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE_SITE2
AFTER DELETE ON lignecommandes2
FOR EACH ROW
BEGIN
    IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN
        BEGIN
            EXECUTE IMMEDIATE
                'BEGIN DELETEligne@link_central(:1); END;'
            USING :OLD.idlignecommande;
        EXCEPTION
            WHEN OTHERS THEN
                log_sync_error('SYC_DELETE_LIGNE_SITE2',
                               :OLD.idlignecommande, SQLERRM);
        END;
    END IF;
END SYC_DELETE_LIGNE_SITE2;
/
SHOW ERRORS TRIGGER SYC_DELETE_LIGNE_SITE2;
