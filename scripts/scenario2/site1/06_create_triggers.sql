-- ============================================================
-- SCENARIO 2 | SITE 1 -- Triggers de synchronisation
-- ------------------------------------------------------------
-- Regle locale de Site 1 : R1 = sigma(quantite >= 100)
--
-- Difference CLE avec Scenario 1 :
--   - Routage base UNIQUEMENT sur quantite (pas de categorie)
--   - Si quantite >= 100 : la ligne appartient a ce site
--   - Si quantite <  100 : la ligne doit migrer vers Site 2
--
-- Triggers compound (FOR ... COMPOUND TRIGGER) pour eviter
-- ORA-04091 (table en mutation) lors des deletions en cascade.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site1;

-- =========================================================
-- TRIGGER BEFORE INSERT : pull des parents depuis le master
-- Garantit que les FK (commande, produit, client) existent
-- AVANT la verification de contrainte par Oracle.
-- =========================================================
CREATE OR REPLACE TRIGGER TRG_PULL_PARENTS_SITE1
BEFORE INSERT ON lignecommandes1
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_cmd   commandes%ROWTYPE;
    v_prod  produits%ROWTYPE;
    v_cli   clients%ROWTYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;

    -- Pull du produit
    SELECT COUNT(*) INTO v_count FROM produits1 WHERE idproduit = :NEW.idproduit;
    IF v_count = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = :NEW.idproduit;
        INSERT INTO produits1 VALUES v_prod;
    END IF;

    -- Pull de la commande (et du client parent)
    SELECT COUNT(*) INTO v_count FROM commandes1 WHERE idcommande = :NEW.idcommande;
    IF v_count = 0 THEN
        SELECT * INTO v_cmd FROM commandes WHERE idcommande = :NEW.idcommande;
        SELECT COUNT(*) INTO v_count FROM clients1 WHERE idclient = v_cmd.idclient;
        IF v_count = 0 THEN
            SELECT * INTO v_cli FROM clients WHERE idclient = v_cmd.idclient;
            INSERT INTO clients1 VALUES v_cli;
        END IF;
        INSERT INTO commandes1 VALUES v_cmd;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20010,
            'SC2 SITE1 PULL : donnee parente introuvable sur le master.');
END TRG_PULL_PARENTS_SITE1;
/
SHOW ERRORS TRIGGER TRG_PULL_PARENTS_SITE1;

-- =========================================================
-- TRIGGER BEFORE UPDATE : pull du nouveau produit avant FK
-- =========================================================
CREATE OR REPLACE TRIGGER TRG_PULL_PROD_BEFORE_UPD_SITE1
BEFORE UPDATE OF idproduit ON lignecommandes1
FOR EACH ROW
DECLARE
    v_count NUMBER;
    v_prod  produits%ROWTYPE;
BEGIN
    IF pkg_synchro.is_replicating = TRUE THEN RETURN; END IF;
    IF :OLD.idproduit = :NEW.idproduit THEN RETURN; END IF;
    SELECT COUNT(*) INTO v_count FROM produits1 WHERE idproduit = :NEW.idproduit;
    IF v_count = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = :NEW.idproduit;
        INSERT INTO produits1 VALUES v_prod;
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20011,
            'SC2 SITE1 : Produit ' || :NEW.idproduit || ' introuvable sur le master.');
END TRG_PULL_PROD_BEFORE_UPD_SITE1;
/
SHOW ERRORS TRIGGER TRG_PULL_PROD_BEFORE_UPD_SITE1;

-- =========================================================
-- TRIGGER INSERT (SITE 1) — Compound
-- Apres chaque INSERT sur lignecommandes1 :
--   1. Propage toujours au Master (base globale)
--   2. Si quantite < 100 : la ligne ne respecte pas R1
--      → la router vers Site 2 ET la marquer pour suppression locale
--   3. Si quantite >= 100 : conserver localement (rien a faire)
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_INSERT_LIGNE_SITE1
FOR INSERT ON lignecommandes1
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes1.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
    BEGIN
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN

            -- 1. Propagation systematique vers le Master
            EXECUTE IMMEDIATE
                'BEGIN INSERTligne@link_central(:1, :2, :3, :4, :5); END;'
            USING :NEW.idlignecommande, :NEW.idcommande,
                  :NEW.idproduit, :NEW.quantite, :NEW.remise;

            -- 2. Routage croise si la ligne ne respecte pas R1
            IF :NEW.quantite < 100 THEN
                -- Envoyer vers Site 2 (fragment R2)
                EXECUTE IMMEDIATE
                    'BEGIN INSERTligne@link_site2(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande,
                      :NEW.idproduit, :NEW.quantite, :NEW.remise;
                -- Marquer pour suppression locale (nettoyage apres statement)
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :NEW.idlignecommande;
            END IF;
            -- Si quantite >= 100 : la ligne reste ici, rien a faire

        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        -- Suppression locale des lignes qui ne respectent pas R1
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE;
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes1
                WHERE idlignecommande = v_ids_to_delete(i);
            END LOOP;
            pkg_synchro.is_replicating := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            pkg_synchro.is_replicating := FALSE;
            RAISE;
    END AFTER STATEMENT;

END SYC_INSERT_LIGNE_SITE1;
/
SHOW ERRORS TRIGGER SYC_INSERT_LIGNE_SITE1;

-- =========================================================
-- TRIGGER UPDATE (SITE 1) — Compound
-- Apres chaque UPDATE sur lignecommandes1 :
--   1. Propage toujours l'UPDATE au Master
--   2. Si NEW.quantite < 100 : la ligne quitte R1
--      → l'inserer sur Site 2 ET la supprimer localement
--   3. Si NEW.quantite >= 100 : elle reste dans R1, conserver
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_UPDATE_LIGNE_SITE1
FOR UPDATE ON lignecommandes1
COMPOUND TRIGGER

    TYPE t_id_list IS TABLE OF lignecommandes1.idlignecommande%TYPE;
    v_ids_to_delete t_id_list := t_id_list();

    AFTER EACH ROW IS
    BEGIN
        IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN

            -- 1. Propagation de la MAJ au Master
            EXECUTE IMMEDIATE
                'BEGIN updateligne@link_central(:1, :2, :3, :4); END;'
            USING :NEW.idlignecommande, :NEW.idproduit,
                  :NEW.quantite, :NEW.remise;

            -- 2. Verifier si la ligne migre hors de R1
            IF :NEW.quantite < 100 THEN
                -- La ligne franchit le seuil vers le bas : migre vers Site 2
                EXECUTE IMMEDIATE
                    'BEGIN INSERTligne@link_site2(:1, :2, :3, :4, :5); END;'
                USING :NEW.idlignecommande, :NEW.idcommande,
                      :NEW.idproduit, :NEW.quantite, :NEW.remise;
                -- Marquer pour suppression locale
                v_ids_to_delete.EXTEND;
                v_ids_to_delete(v_ids_to_delete.LAST) := :OLD.idlignecommande;
            END IF;
            -- Si NEW.quantite >= 100 : reste dans R1, rien a migrer

        END IF;
    END AFTER EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF v_ids_to_delete.COUNT > 0 THEN
            pkg_synchro.is_replicating := TRUE;
            FOR i IN 1 .. v_ids_to_delete.COUNT LOOP
                DELETE FROM lignecommandes1
                WHERE idlignecommande = v_ids_to_delete(i);
            END LOOP;
            pkg_synchro.is_replicating := FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            pkg_synchro.is_replicating := FALSE;
            RAISE;
    END AFTER STATEMENT;

END SYC_UPDATE_LIGNE_SITE1;
/
SHOW ERRORS TRIGGER SYC_UPDATE_LIGNE_SITE1;

-- =========================================================
-- TRIGGER DELETE (SITE 1)
-- Informe le Master de la suppression. Erreurs tracees
-- dans sync_errors sans bloquer l'operation locale.
-- =========================================================
CREATE OR REPLACE TRIGGER SYC_DELETE_LIGNE_SITE1
AFTER DELETE ON lignecommandes1
FOR EACH ROW
BEGIN
    IF pkg_synchro.is_replicating = FALSE OR pkg_synchro.is_replicating IS NULL THEN
        BEGIN
            EXECUTE IMMEDIATE
                'BEGIN DELETEligne@link_central(:1); END;'
            USING :OLD.idlignecommande;
        EXCEPTION
            WHEN OTHERS THEN
                log_sync_error('SYC_DELETE_LIGNE_SITE1',
                               :OLD.idlignecommande, SQLERRM);
        END;
    END IF;
END SYC_DELETE_LIGNE_SITE1;
/
SHOW ERRORS TRIGGER SYC_DELETE_LIGNE_SITE1;
