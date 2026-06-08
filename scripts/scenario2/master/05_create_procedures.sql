-- ============================================================
-- SCENARIO 2 | MASTER -- Procedures stockees
-- ------------------------------------------------------------
-- Identiques au Scenario 1 : les procedures du Master ne font que
-- verrouiller le drapeau anti-boucle et executer l'operation.
-- Le routage vers les sites est gere par les TRIGGERS (fichier 06).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- =========================================================
-- INSERTligne (Master)
-- =========================================================
CREATE OR REPLACE PROCEDURE INSERTligne(
    p_idl IN lignecommandes.idlignecommande%TYPE,
    p_idc IN lignecommandes.idcommande%TYPE,
    p_idp IN lignecommandes.idproduit%TYPE,
    p_qte IN lignecommandes.quantite%TYPE,
    p_rem IN lignecommandes.remise%TYPE
) AS
BEGIN
    pkg_synchro.is_replicating := TRUE;
    INSERT INTO lignecommandes (idlignecommande, idcommande, idproduit, quantite, remise)
    VALUES (p_idl, p_idc, p_idp, p_qte, p_rem);
    pkg_synchro.is_replicating := FALSE;
EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE;
END INSERTligne;
/

-- =========================================================
-- DELETEligne (Master)
-- =========================================================
CREATE OR REPLACE PROCEDURE DELETEligne(
    p_idl IN lignecommandes.idlignecommande%TYPE
) AS
BEGIN
    pkg_synchro.is_replicating := TRUE;
    DELETE FROM lignecommandes WHERE idlignecommande = p_idl;
    pkg_synchro.is_replicating := FALSE;
EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE;
END DELETEligne;
/

-- =========================================================
-- updateligne (Master)
-- =========================================================
CREATE OR REPLACE PROCEDURE updateligne(
    p_idl IN lignecommandes.idlignecommande%TYPE,
    p_idp IN lignecommandes.idproduit%TYPE,
    p_qte IN lignecommandes.quantite%TYPE,
    p_rem IN lignecommandes.remise%TYPE
) AS
BEGIN
    pkg_synchro.is_replicating := TRUE;
    UPDATE lignecommandes
        SET idproduit = p_idp, quantite = p_qte, remise = p_rem
    WHERE idlignecommande = p_idl;
    pkg_synchro.is_replicating := FALSE;
EXCEPTION WHEN OTHERS THEN
    pkg_synchro.is_replicating := FALSE;
    RAISE;
END updateligne;
/
