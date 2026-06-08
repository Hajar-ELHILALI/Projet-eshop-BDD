-- ============================================================
-- SITE 2 — Création du fragment R2 par CTAS
--   R2 = sigma[ idcateg = 35 AND quantite > 50 ] (LigneCommandes)
-- ------------------------------------------------------------
-- Approche (fragmentation horizontale DÉRIVÉE) :
--   1) On matérialise le fragment directement depuis la base globale
--      via le lien 'link_central' : CTAS = CREATE + chargement en un
--      seul passage (rapide, et ne déclenche aucun trigger).
--   2) Produits2 / Commandes2 / Clients2 sont DÉRIVÉS : on ne conserve
--      que les lignes effectivement référencées par ligneCommandes2.
--      => l'intégrité référentielle est garantie par construction.
--   3) CTAS ne copie NI clés NI index : on les ajoute après
--      (PK d'abord, puis FK, puis index sur les colonnes de jointure).
--
-- Le lien 'link_central' étant PRIVÉ (propriété de eshop_site2), on se
-- connecte en tant que eshop_site2 pour que '@link_central' se résolve.
-- ============================================================
CONNECT eshop_site2/EshopPassword123@//localhost:1521/XEPDB1
SET SERVEROUTPUT ON

-- ------------------------------------------------------------
-- Anti-race au démarrage : on attend que la base globale soit peuplée.
-- ------------------------------------------------------------
DECLARE
    v_cnt NUMBER := 0;
    v_try NUMBER := 0;
BEGIN
    LOOP
        BEGIN
            SELECT COUNT(*) INTO v_cnt FROM lignecommandes@link_central;
        EXCEPTION WHEN OTHERS THEN
            v_cnt := 0;
        END;
        EXIT WHEN v_cnt > 0 OR v_try >= 60;   -- max ~5 min
        v_try := v_try + 1;
        DBMS_SESSION.SLEEP(5);
    END LOOP;
END;
/

-- ------------------------------------------------------------
-- Idempotence : on repart propre (ordre enfant -> parent)
-- ------------------------------------------------------------
BEGIN EXECUTE IMMEDIATE 'DROP TABLE lignecommandes2 CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE commandes2 CASCADE CONSTRAINTS';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE produits2 CASCADE CONSTRAINTS';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE clients2 CASCADE CONSTRAINTS';        EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ------------------------------------------------------------
-- 1. Fragment principal : les lignes qui vérifient R2
-- ------------------------------------------------------------
CREATE TABLE lignecommandes2 AS
SELECT lc.idlignecommande, lc.idcommande, lc.idproduit, lc.quantite, lc.remise
FROM   lignecommandes@link_central lc
JOIN   produits@link_central p ON p.idproduit = lc.idproduit
WHERE  p.idcateg = 35 AND lc.quantite > 50;

-- ------------------------------------------------------------
-- 2. Produits dérivés (seulement ceux référencés par le fragment)
-- ------------------------------------------------------------
-- (Même ordre de colonnes que le master, pour que les procédures
--  'SELECT * INTO v_prod / INSERT VALUES v_prod' restent valides.)
CREATE TABLE produits2 AS
SELECT p.idproduit, p.designation, p.prixunitaire, p.idcateg
FROM   produits@link_central p
WHERE  p.idproduit IN (SELECT idproduit FROM lignecommandes2);

-- ------------------------------------------------------------
-- 3. Commandes dérivées
-- ------------------------------------------------------------
CREATE TABLE commandes2 AS
SELECT c.idcommande, c.idemploye, c.idclient, c.datecommande
FROM   commandes@link_central c
WHERE  c.idcommande IN (SELECT idcommande FROM lignecommandes2);

-- ------------------------------------------------------------
-- 4. Clients dérivés
-- ------------------------------------------------------------
CREATE TABLE clients2 AS
SELECT cl.idclient, cl.codeclient, cl.societe
FROM   clients@link_central cl
WHERE  cl.idclient IN (SELECT idclient FROM commandes2);

-- ------------------------------------------------------------
-- 5. Contraintes d'intégrité (CTAS ne les copie pas) : PK puis FK
-- ------------------------------------------------------------
ALTER TABLE clients2        ADD CONSTRAINT pk_clients2        PRIMARY KEY (idclient);
ALTER TABLE produits2       ADD CONSTRAINT pk_produits2       PRIMARY KEY (idproduit);
ALTER TABLE commandes2      ADD CONSTRAINT pk_commandes2      PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes2 ADD CONSTRAINT pk_lignecommandes2 PRIMARY KEY (idlignecommande);

ALTER TABLE commandes2 ADD CONSTRAINT fk_cmd2_client
    FOREIGN KEY (idclient) REFERENCES clients2(idclient);
ALTER TABLE lignecommandes2 ADD CONSTRAINT fk_lc2_cmd
    FOREIGN KEY (idcommande) REFERENCES commandes2(idcommande);
ALTER TABLE lignecommandes2 ADD CONSTRAINT fk_lc2_prod
    FOREIGN KEY (idproduit) REFERENCES produits2(idproduit);

-- Colonnes de relation obligatoires (les FK sont nullables par défaut)
ALTER TABLE commandes2      MODIFY idclient   NOT NULL;
ALTER TABLE lignecommandes2 MODIFY idcommande NOT NULL;
ALTER TABLE lignecommandes2 MODIFY idproduit  NOT NULL;
-- NB : pas de CHECK sur quantite -> en multi-maître, une ligne destinée
-- a un autre site TRANSITE par site2 (insert AFTER -> route -> delete),
-- donc on ne peut pas verrouiller le fragment par une contrainte dure.

-- ------------------------------------------------------------
-- 6. Index sur les colonnes de jointure / FK
-- ------------------------------------------------------------
CREATE INDEX ix_lc2_cmd  ON lignecommandes2(idcommande);
CREATE INDEX ix_lc2_prod ON lignecommandes2(idproduit);
CREATE INDEX ix_cmd2_cli ON commandes2(idclient);

-- ------------------------------------------------------------
-- 6b. Séquences pour les écritures ORIGINÉES sur le Site 2 (multi-maître)
--     Offset mod 3 -> Site 2 = voie 0 (3,6,9,...) : aucune collision
--     possible avec le Master (voie 1) ni le Site 1 (voie 2).
--     On positionne le START au-delà des IDs déjà chargés par le CTAS.
-- ------------------------------------------------------------
DECLARE
    PROCEDURE make_seq(p_seq VARCHAR2, p_col VARCHAR2, p_tab VARCHAR2) IS
        v_m NUMBER; v_s NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT NVL(MAX('||p_col||'),0) FROM '||p_tab INTO v_m;
        v_s := v_m + 1;
        WHILE MOD(v_s, 3) <> 0 LOOP v_s := v_s + 1; END LOOP;   -- voie 0
        BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE '||p_seq; EXCEPTION WHEN OTHERS THEN NULL; END;
        EXECUTE IMMEDIATE 'CREATE SEQUENCE '||p_seq||' START WITH '||v_s||' INCREMENT BY 3 NOCACHE NOCYCLE';
    END;
BEGIN
    make_seq('seq_clients2',        'idclient',        'clients2');
    make_seq('seq_produits2',       'idproduit',       'produits2');
    make_seq('seq_commandes2',      'idcommande',      'commandes2');
    make_seq('seq_lignecommandes2', 'idlignecommande', 'lignecommandes2');
END;
/

-- Valeur par défaut : un INSERT local sans ID prend automatiquement
-- le prochain ID de la voie du Site 2.
ALTER TABLE clients2        MODIFY idclient        DEFAULT seq_clients2.NEXTVAL;
ALTER TABLE produits2       MODIFY idproduit       DEFAULT seq_produits2.NEXTVAL;
ALTER TABLE commandes2      MODIFY idcommande      DEFAULT seq_commandes2.NEXTVAL;
ALTER TABLE lignecommandes2 MODIFY idlignecommande DEFAULT seq_lignecommandes2.NEXTVAL;

-- ------------------------------------------------------------
-- 7. Statistiques optimiseur (après chargement en masse) :
--    indispensable pour obtenir des plans d'exécution fiables (Q5/Q6).
-- ------------------------------------------------------------
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTS2',        cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUITS2',       cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES2',      cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'LIGNECOMMANDES2', cascade => TRUE);
END;
/

-- ------------------------------------------------------------
-- 8. Rapport de contrôle dans les logs du conteneur
-- ------------------------------------------------------------
DECLARE
    n_lc NUMBER; n_p NUMBER; n_c NUMBER; n_cl NUMBER;
BEGIN
    SELECT COUNT(*) INTO n_lc FROM lignecommandes2;
    SELECT COUNT(*) INTO n_p  FROM produits2;
    SELECT COUNT(*) INTO n_c  FROM commandes2;
    SELECT COUNT(*) INTO n_cl FROM clients2;
    DBMS_OUTPUT.PUT_LINE('[Site2] Fragment R2 charge : '
        || n_lc || ' lignes, ' || n_p || ' produits, '
        || n_c || ' commandes, ' || n_cl || ' clients.');
END;
/
