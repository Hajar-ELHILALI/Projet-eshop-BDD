-- ============================================================
-- SCENARIO 2 | SITE 1 -- Journalisation des erreurs de sync
-- ------------------------------------------------------------
-- Toute erreur de propagation distante est tracee dans
-- SYNC_ERRORS sans bloquer l'operation locale (PRAGMA
-- AUTONOMOUS_TRANSACTION garantit la persistance du log meme
-- si la transaction principale est annulee).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site1;

CREATE SEQUENCE seq_sync_errors START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE TABLE sync_errors (
    id_err   NUMBER DEFAULT seq_sync_errors.NEXTVAL PRIMARY KEY,
    date_err TIMESTAMP DEFAULT SYSTIMESTAMP,
    contexte VARCHAR2(100),
    id_ligne NUMBER,
    message  VARCHAR2(4000)
);

CREATE OR REPLACE PROCEDURE log_sync_error(
    p_ctx IN VARCHAR2,
    p_idl IN NUMBER,
    p_msg IN VARCHAR2
) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO sync_errors (contexte, id_ligne, message)
    VALUES (p_ctx, p_idl, SUBSTR(p_msg, 1, 4000));
    COMMIT;
END log_sync_error;
/
