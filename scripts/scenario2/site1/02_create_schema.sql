-- ============================================================
-- SCENARIO 2 | SITE 1 -- Creation du Fragment R1
-- ------------------------------------------------------------
-- R1 = sigma(quantite >= 100)(LigneCommandes) --> Site 1
--
-- Difference avec Scenario 1 :
--   - Pas de filtre sur idcateg (toutes categories incluses)
--   - Critere unique : quantite >= 100
--   - Toutes les categories de produits peuvent etre presentes
-- Sequences : voie 2 (mod 3 = 2 : 2, 5, 8, 11, ...)
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

CONNECT eshop_site1/EshopPassword123@//localhost:1521/XEPDB1
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
            'SITE1 SC2 : timeout, Master non peuple apres 5 min.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Master peuple (' || v_cnt || ' lignes). Lancement CTAS...');
END;
/

-- Nettoyage idempotent
BEGIN EXECUTE IMMEDIATE 'DROP TABLE lignecommandes1 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE commandes1 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE produits1 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE clients1 CASCADE CONSTRAINTS';
  EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- CTAS 1 : Fragment R1 = sigma(quantite >= 100)
--          Toutes les lignes avec quantite >= 100,
--          independamment de la categorie du produit.
-- ============================================================
CREATE TABLE lignecommandes1 AS
    SELECT lc.idlignecommande,
           lc.idcommande,
           lc.idproduit,
           lc.quantite,
           lc.remise
    FROM   lignecommandes@link_central lc
    WHERE  lc.quantite >= 100;

DBMS_OUTPUT.PUT_LINE('CTAS lignecommandes1 : ' || SQL%ROWCOUNT || ' lignes');

-- ============================================================
-- CTAS 2 : Produits derives
--          Tous les produits references par R1
--          (peut inclure toutes les categories)
-- ============================================================
CREATE TABLE produits1 AS
    SELECT p.idproduit,
           p.designation,
           p.prixunitaire,
           p.idcateg
    FROM   produits@link_central p
    WHERE  p.idproduit IN (SELECT idproduit FROM lignecommandes1);

DBMS_OUTPUT.PUT_LINE('CTAS produits1 OK');

-- ============================================================
-- CTAS 3 : Commandes derivees
-- ============================================================
CREATE TABLE commandes1 AS
    SELECT c.idcommande,
           c.idemploye,
           c.idclient,
           c.datecommande
    FROM   commandes@link_central c
    WHERE  c.idcommande IN (SELECT idcommande FROM lignecommandes1);

DBMS_OUTPUT.PUT_LINE('CTAS commandes1 OK');

-- ============================================================
-- CTAS 4 : Clients derives
-- ============================================================
CREATE TABLE clients1 AS
    SELECT cl.idclient,
           cl.codeclient,
           cl.societe
    FROM   clients@link_central cl
    WHERE  cl.idclient IN (SELECT idclient FROM commandes1);

DBMS_OUTPUT.PUT_LINE('CTAS clients1 OK');

-- ============================================================
-- Contraintes d'integrite (le CTAS ne les copie pas)
-- ============================================================
ALTER TABLE clients1        ADD CONSTRAINT pk_clients1        PRIMARY KEY (idclient);
ALTER TABLE produits1       ADD CONSTRAINT pk_produits1       PRIMARY KEY (idproduit);
ALTER TABLE commandes1      ADD CONSTRAINT pk_commandes1      PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes1 ADD CONSTRAINT pk_lignecommandes1 PRIMARY KEY (idlignecommande);

ALTER TABLE commandes1 ADD CONSTRAINT fk_cmd1_client
    FOREIGN KEY (idclient) REFERENCES clients1(idclient);

ALTER TABLE lignecommandes1 ADD CONSTRAINT fk_lc1_cmd
    FOREIGN KEY (idcommande) REFERENCES commandes1(idcommande);

ALTER TABLE lignecommandes1 ADD CONSTRAINT fk_lc1_prod
    FOREIGN KEY (idproduit)  REFERENCES produits1(idproduit);

ALTER TABLE commandes1      MODIFY idclient   NOT NULL;
ALTER TABLE lignecommandes1 MODIFY idcommande NOT NULL;
ALTER TABLE lignecommandes1 MODIFY idproduit  NOT NULL;

-- Index sur les colonnes FK
CREATE INDEX ix_lc1_cmd  ON lignecommandes1(idcommande);
CREATE INDEX ix_lc1_prod ON lignecommandes1(idproduit);
CREATE INDEX ix_cmd1_cli ON commandes1(idclient);

DBMS_OUTPUT.PUT_LINE('Contraintes et index OK');

-- ============================================================
-- Sequences voie 2 (mod 3 = 2 : 2, 5, 8, 11, ...)
-- La procedure make_seq calcule le point de depart dynamiquement
-- en tenant compte des ID deja importes par CTAS.
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
        WHILE MOD(v_start, 3) <> 2 LOOP
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
    make_seq('seq_clients1',        'idclient',        'clients1');
    make_seq('seq_produits1',       'idproduit',       'produits1');
    make_seq('seq_commandes1',      'idcommande',      'commandes1');
    make_seq('seq_lignecommandes1', 'idlignecommande', 'lignecommandes1');
END;
/

ALTER TABLE clients1        MODIFY idclient        DEFAULT seq_clients1.NEXTVAL;
ALTER TABLE produits1       MODIFY idproduit       DEFAULT seq_produits1.NEXTVAL;
ALTER TABLE commandes1      MODIFY idcommande      DEFAULT seq_commandes1.NEXTVAL;
ALTER TABLE lignecommandes1 MODIFY idlignecommande DEFAULT seq_lignecommandes1.NEXTVAL;

-- Statistiques pour l'optimiseur Oracle (CBO)
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTS1',        cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUITS1',       cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES1',      cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'LIGNECOMMANDES1', cascade => TRUE);
END;
/

DBMS_OUTPUT.PUT_LINE('=== SITE 1 SCENARIO 2 : initialisation terminee ===');
