-- ============================================================
-- SCENARIO 2 | SITE 2 -- Journalisation des erreurs de sync
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_site2;

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
