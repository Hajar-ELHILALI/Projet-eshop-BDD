-- ============================================================
-- SCENARIO 2 | SITE 2 -- Creation du Fragment R2
-- ------------------------------------------------------------
-- R2 = sigma(quantite < 100)(LigneCommandes) --> Site 2
--
-- Difference avec Scenario 1 :
--   - Pas de filtre sur idcateg (toutes categories incluses)
--   - Critere unique : quantite < 100
-- Sequences : voie 0 (mod 3 = 0 : 3, 6, 9, 12, ...)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

CONNECT eshop_site2/EshopPassword123@//localhost:1521/XEPDB1
SET SERVEROUTPUT ON

-- Anti-race : attendre que le Master soit peuple (max 5 min)
DECLARE
    v_cnt NUMBER := 0;
    v_try NUMBER := 0;
BEGIN
    LOOP
        BEGIN
            SELECT COUNT(*) INTO v_cnt FROM lignecommandes@link_central;
        EXCEPTION WHEN OTHERS THEN v_cnt := 0;
        END;
        EXIT WHEN v_cnt > 0 OR v_try >= 60;
        v_try := v_try + 1;
        DBMS_SESSION.SLEEP(5);
        DBMS_OUTPUT.PUT_LINE('Attente Master... tentative ' || v_try);
    END LOOP;
    IF v_cnt = 0 THEN
        RAISE_APPLICATION_ERROR(-20099,
            'SITE2 SC2 : timeout, Master non peuple apres 5 min.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Master peuple (' || v_cnt || ' lignes). Lancement CTAS...');
END;
/

-- Nettoyage idempotent
BEGIN EXECUTE IMMEDIATE 'DROP TABLE lignecommandes2 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE commandes2 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE produits2 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE clients2 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- CTAS 1 : Fragment R2 = sigma(quantite < 100)
--          Toutes les lignes avec quantite < 100,
--          independamment de la categorie du produit.
-- ============================================================
CREATE TABLE lignecommandes2 AS
    SELECT lc.idlignecommande,
           lc.idcommande,
           lc.idproduit,
           lc.quantite,
           lc.remise
    FROM   lignecommandes@link_central lc
    WHERE  lc.quantite < 100;

DBMS_OUTPUT.PUT_LINE('CTAS lignecommandes2 : ' || SQL%ROWCOUNT || ' lignes');

-- ============================================================
-- CTAS 2 : Produits derives
--          Tous les produits references par R2
-- ============================================================
CREATE TABLE produits2 AS
    SELECT p.idproduit,
           p.designation,
           p.prixunitaire,
           p.idcateg
    FROM   produits@link_central p
    WHERE  p.idproduit IN (SELECT idproduit FROM lignecommandes2);

DBMS_OUTPUT.PUT_LINE('CTAS produits2 OK');

-- ============================================================
-- CTAS 3 : Commandes derivees
-- ============================================================
CREATE TABLE commandes2 AS
    SELECT c.idcommande,
           c.idemploye,
           c.idclient,
           c.datecommande
    FROM   commandes@link_central c
    WHERE  c.idcommande IN (SELECT idcommande FROM lignecommandes2);

DBMS_OUTPUT.PUT_LINE('CTAS commandes2 OK');

-- ============================================================
-- CTAS 4 : Clients derives
-- ============================================================
CREATE TABLE clients2 AS
    SELECT cl.idclient,
           cl.codeclient,
           cl.societe
    FROM   clients@link_central cl
    WHERE  cl.idclient IN (SELECT idclient FROM commandes2);

DBMS_OUTPUT.PUT_LINE('CTAS clients2 OK');

-- ============================================================
-- Contraintes d'integrite
-- ============================================================
ALTER TABLE clients2        ADD CONSTRAINT pk_clients2        PRIMARY KEY (idclient);
ALTER TABLE produits2       ADD CONSTRAINT pk_produits2       PRIMARY KEY (idproduit);
ALTER TABLE commandes2      ADD CONSTRAINT pk_commandes2      PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes2 ADD CONSTRAINT pk_lignecommandes2 PRIMARY KEY (idlignecommande);

ALTER TABLE commandes2 ADD CONSTRAINT fk_cmd2_client
    FOREIGN KEY (idclient) REFERENCES clients2(idclient);

ALTER TABLE lignecommandes2 ADD CONSTRAINT fk_lc2_cmd
    FOREIGN KEY (idcommande) REFERENCES commandes2(idcommande);

ALTER TABLE lignecommandes2 ADD CONSTRAINT fk_lc2_prod
    FOREIGN KEY (idproduit)  REFERENCES produits2(idproduit);

ALTER TABLE commandes2      MODIFY idclient   NOT NULL;
ALTER TABLE lignecommandes2 MODIFY idcommande NOT NULL;
ALTER TABLE lignecommandes2 MODIFY idproduit  NOT NULL;

-- Index sur les colonnes FK
CREATE INDEX ix_lc2_cmd  ON lignecommandes2(idcommande);
CREATE INDEX ix_lc2_prod ON lignecommandes2(idproduit);
CREATE INDEX ix_cmd2_cli ON commandes2(idclient);

DBMS_OUTPUT.PUT_LINE('Contraintes et index OK');

-- ============================================================
-- Sequences voie 0 (mod 3 = 0 : 3, 6, 9, 12, ...)
-- ============================================================
DECLARE
    PROCEDURE make_seq(p_seq VARCHAR2, p_col VARCHAR2, p_tab VARCHAR2) IS
        v_max   NUMBER;
        v_start NUMBER;
    BEGIN
        EXECUTE IMMEDIATE
            'SELECT NVL(MAX(' || p_col || '), 0) FROM ' || p_tab
            INTO v_max;
        v_start := v_max + 1;
        WHILE MOD(v_start, 3) <> 0 LOOP
            v_start := v_start + 1;
        END LOOP;
        BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE ' || p_seq;
          EXCEPTION WHEN OTHERS THEN NULL; END;
        EXECUTE IMMEDIATE
            'CREATE SEQUENCE ' || p_seq
            || ' START WITH ' || v_start
            || ' INCREMENT BY 3 NOCACHE NOCYCLE';
        DBMS_OUTPUT.PUT_LINE('Sequence ' || p_seq || ' : START WITH ' || v_start);
    END make_seq;
BEGIN
    make_seq('seq_clients2',        'idclient',        'clients2');
    make_seq('seq_produits2',       'idproduit',       'produits2');
    make_seq('seq_commandes2',      'idcommande',      'commandes2');
    make_seq('seq_lignecommandes2', 'idlignecommande', 'lignecommandes2');
END;
/

ALTER TABLE clients2        MODIFY idclient        DEFAULT seq_clients2.NEXTVAL;
ALTER TABLE produits2       MODIFY idproduit       DEFAULT seq_produits2.NEXTVAL;
ALTER TABLE commandes2      MODIFY idcommande      DEFAULT seq_commandes2.NEXTVAL;
ALTER TABLE lignecommandes2 MODIFY idlignecommande DEFAULT seq_lignecommandes2.NEXTVAL;

-- Statistiques pour l'optimiseur Oracle (CBO)
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTS2',        cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUITS2',       cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES2',      cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'LIGNECOMMANDES2', cascade => TRUE);
END;
/

DBMS_OUTPUT.PUT_LINE('=== SITE 2 SCENARIO 2 : initialisation terminee ===');
