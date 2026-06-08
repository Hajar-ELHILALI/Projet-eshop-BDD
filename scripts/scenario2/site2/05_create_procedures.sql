-- ============================================================
-- SCENARIO 2 | SITE 2 -- Procedures stockees
-- ------------------------------------------------------------
-- Logique symetrique a Site 1, adaptee aux tables locales
-- (suffixe 2 : lignecommandes2, produits2, commandes2, clients2).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

-- =========================================================
-- INSERTligne (Site 2)
-- Appele depuis le Master via link_site2 quand la ligne
-- doit etre stockee sur ce site (quantite < 100).
-- =========================================================
CREATE OR REPLACE PROCEDURE INSERTligne(
    p_idl NUMBER,
    p_idc NUMBER,
    p_idp NUMBER,
    p_qte NUMBER,
    p_rem NUMBER
) AS
    v_nc   INTEGER;
    v_np   INTEGER;
    v_cmd  commandes2%ROWTYPE;
    v_prod produits2%ROWTYPE;
    v_cli  clients2%ROWTYPE;
BEGIN
    pkg_synchro.is_replicating := TRUE;

    -- Pull de la commande parente si absente
    SELECT COUNT(*) INTO v_nc FROM commandes2 WHERE idcommande = p_idc;
    IF v_nc = 0 THEN
        SELECT * INTO v_cmd FROM commandes WHERE idcommande = p_idc;
        SELECT COUNT(*) INTO v_nc FROM clients2 WHERE idclient = v_cmd.idclient;
        IF v_nc = 0 THEN
            SELECT * INTO v_cli FROM clients WHERE idclient = v_cmd.idclient;
            INSERT INTO clients2 VALUES v_cli;
        END IF;
        INSERT INTO commandes2 VALUES v_cmd;
    END IF;

    -- Pull du produit parent si absent
    SELECT COUNT(*) INTO v_np FROM produits2 WHERE idproduit = p_idp;
    IF v_np = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = p_idp;
        INSERT INTO produits2 VALUES v_prod;
    END IF;

    -- Insertion de la ligne de commande
    INSERT INTO lignecommandes2 (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (p_idl, p_idc, p_idp, p_qte, p_rem);

    pkg_synchro.is_replicating := FALSE;
EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE_APPLICATION_ERROR(-20001, 'INSERTligne SITE2 SC2 ERROR: ' || SQLERRM);
END INSERTligne;
/

-- =========================================================
-- DELETEligne (Site 2)
-- =========================================================
CREATE OR REPLACE PROCEDURE DELETEligne(
    p_idl NUMBER
) AS
    v_idc   commandes2.idcommande%TYPE;
    v_idp   produits2.idproduit%TYPE;
    v_idcl  clients2.idclient%TYPE;
    v_nc    INTEGER;
    v_ncl   INTEGER;
    v_nprod INTEGER;
BEGIN
    pkg_synchro.is_replicating := TRUE;

    SELECT idcommande, idproduit INTO v_idc, v_idp
    FROM lignecommandes2 WHERE idlignecommande = p_idl;

    DELETE FROM lignecommandes2 WHERE idlignecommande = p_idl;

    -- Nettoyage de la commande si orpheline
    SELECT COUNT(*) INTO v_nc FROM lignecommandes2 WHERE idcommande = v_idc;
    IF v_nc = 0 THEN
        SELECT idclient INTO v_idcl FROM commandes2 WHERE idcommande = v_idc;
        DELETE FROM commandes2 WHERE idcommande = v_idc;
        SELECT COUNT(*) INTO v_ncl FROM commandes2 WHERE idclient = v_idcl;
        IF v_ncl = 0 THEN
            DELETE FROM clients2 WHERE idclient = v_idcl;
        END IF;
    END IF;

    -- Nettoyage du produit si plus reference
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
        RAISE_APPLICATION_ERROR(-20002, 'DELETEligne SITE2 SC2 ERROR: ' || SQLERRM);
END DELETEligne;
/

-- =========================================================
-- updateligne (Site 2)
-- =========================================================
CREATE OR REPLACE PROCEDURE updateligne(
    p_idl NUMBER,
    p_idp NUMBER,
    p_qte NUMBER,
    p_rem NUMBER
) AS
    v_old_idp produits2.idproduit%TYPE;
    v_nc      INTEGER;
    v_prod    produits2%ROWTYPE;
BEGIN
    pkg_synchro.is_replicating := TRUE;

    SELECT idproduit INTO v_old_idp
    FROM lignecommandes2 WHERE idlignecommande = p_idl;

    -- Pull du nouveau produit si necessaire
    SELECT COUNT(*) INTO v_nc FROM produits2 WHERE idproduit = p_idp;
    IF v_nc = 0 THEN
        SELECT * INTO v_prod FROM produits WHERE idproduit = p_idp;
        INSERT INTO produits2 VALUES v_prod;
    END IF;

    UPDATE lignecommandes2
    SET idproduit = p_idp, quantite = p_qte, remise = p_rem
    WHERE idlignecommande = p_idl;

    -- Nettoyage de l'ancien produit si plus reference
    SELECT COUNT(*) INTO v_nc FROM lignecommandes2 WHERE idproduit = v_old_idp;
    IF v_nc = 0 THEN
        DELETE FROM produits2 WHERE idproduit = v_old_idp;
    END IF;

    pkg_synchro.is_replicating := FALSE;
EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE_APPLICATION_ERROR(-20003, 'updateligne SITE2 SC2 ERROR: ' || SQLERRM);
END updateligne;
/
