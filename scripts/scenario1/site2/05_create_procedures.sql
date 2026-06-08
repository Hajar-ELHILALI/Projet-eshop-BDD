ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

-- =========================================================
-- PROCÉDURE INSERT (SITE 2)
-- =========================================================
CREATE OR REPLACE PROCEDURE INSERTligne(
    p_idl NUMBER, 
    p_idc NUMBER, 
    p_idp NUMBER, 
    p_qte NUMBER, 
    p_rem NUMBER
) AS
    v_nc INTEGER;
    v_np INTEGER;
    v_cmd commandes2%ROWTYPE;
    v_prod produits2%ROWTYPE;
    v_cli clients2%ROWTYPE;
BEGIN
    -- Verrouillage des triggers locaux
    pkg_synchro.is_replicating := TRUE;
    
    -- Vérifier si commande existe
    SELECT COUNT(*) INTO v_nc FROM commandes2 WHERE idcommande = p_idc;
    IF v_nc = 0 THEN
        -- Récupérer du MASTER
        SELECT * INTO v_cmd FROM commandes WHERE idcommande = p_idc;
        
        -- Vérifier client
        SELECT COUNT(*) INTO v_nc FROM clients2 WHERE idclient = v_cmd.idclient;
        IF v_nc = 0 THEN
            SELECT * INTO v_cli FROM clients WHERE idclient = v_cmd.idclient;
            INSERT INTO clients2 VALUES v_cli;
        END IF;
        
        INSERT INTO commandes2 VALUES v_cmd;
    END IF;
    
    -- Vérifier si produit existe
    SELECT COUNT(*) INTO v_np FROM produits2 WHERE idproduit = p_idp;
    IF v_np = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = p_idp;
        INSERT INTO produits2 VALUES v_prod;
    END IF;
    
    -- Insertion finale de la ligne
    INSERT INTO lignecommandes2 (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (p_idl, p_idc, p_idp, p_qte, p_rem);
    
    -- Déverrouillage
    pkg_synchro.is_replicating := FALSE;

EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE_APPLICATION_ERROR(-20001, 'INSERTligne SITE 2 ERROR: ' || SQLERRM);
END INSERTligne;
/

-- =========================================================
-- PROCÉDURE DELETE (SITE 2)
-- =========================================================
CREATE OR REPLACE PROCEDURE DELETEligne(
    p_idl NUMBER
) AS
    v_idc commandes2.idcommande%TYPE;
    v_idp produits2.idproduit%TYPE;
    v_idcl clients2.idclient%TYPE;
    v_nc INTEGER;
    v_ncl INTEGER;
    v_nprod INTEGER;
BEGIN
    pkg_synchro.is_replicating := TRUE;
    
    -- Récupérer les infos
    SELECT idcommande, idproduit INTO v_idc, v_idp 
    FROM lignecommandes2 WHERE idlignecommande = p_idl;
    
    DELETE FROM lignecommandes2 WHERE idlignecommande = p_idl;
    
    -- Cascade de nettoyage : Commande
    SELECT COUNT(*) INTO v_nc FROM lignecommandes2 WHERE idcommande = v_idc;
    IF v_nc = 0 THEN
        SELECT idclient INTO v_idcl FROM commandes2 WHERE idcommande = v_idc;
        DELETE FROM commandes2 WHERE idcommande = v_idc;
        
        -- Cascade de nettoyage : Client
        SELECT COUNT(*) INTO v_ncl FROM commandes2 WHERE idclient = v_idcl;
        IF v_ncl = 0 THEN
            DELETE FROM clients2 WHERE idclient = v_idcl;
        END IF;
    END IF;
    
    -- Cascade de nettoyage : Produit
    SELECT COUNT(*) INTO v_nprod FROM lignecommandes2 WHERE idproduit = v_idp;
    IF v_nprod = 0 THEN
        DELETE FROM produits2 WHERE idproduit = v_idp;
    END IF;
    
    pkg_synchro.is_replicating := FALSE;

EXCEPTION 
    WHEN NO_DATA_FOUND THEN
        pkg_synchro.is_replicating := FALSE;
    WHEN OTHERS THEN
        pkg_synchro.is_replicating := FALSE;
        RAISE_APPLICATION_ERROR(-20002, 'DELETEligne SITE 2 ERROR: ' || SQLERRM);
END DELETEligne;
/

-- =========================================================
-- PROCÉDURE UPDATE (SITE 2)
-- =========================================================
CREATE OR REPLACE PROCEDURE updateligne(
    p_idl NUMBER, 
    p_idp NUMBER, 
    p_qte NUMBER, 
    p_rem NUMBER
) AS
    v_old_idp produits2.idproduit%TYPE;
    v_nc INTEGER;
    v_prod produits2%ROWTYPE;
BEGIN
    pkg_synchro.is_replicating := TRUE;
    
    -- Récupérer ancien produit
    SELECT idproduit INTO v_old_idp FROM lignecommandes2 WHERE idlignecommande = p_idl;
    
    -- Vérifier nouveau produit
    SELECT COUNT(*) INTO v_nc FROM produits2 WHERE idproduit = p_idp;
    IF v_nc = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = p_idp;
        INSERT INTO produits2 VALUES v_prod;
    END IF;
    
    UPDATE lignecommandes2 
    SET idproduit = p_idp, quantite = p_qte, remise = p_rem 
    WHERE idlignecommande = p_idl;
    
    -- Nettoyer ancien produit si inutilisé
    SELECT COUNT(*) INTO v_nc FROM lignecommandes2 WHERE idproduit = v_old_idp;
    IF v_nc = 0 THEN
        DELETE FROM produits2 WHERE idproduit = v_old_idp;
    END IF;
    
    pkg_synchro.is_replicating := FALSE;

EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE_APPLICATION_ERROR(-20003, 'updateligne SITE 2 ERROR: ' || SQLERRM);
END updateligne;
/