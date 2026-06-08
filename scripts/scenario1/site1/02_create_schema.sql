-- ============================================================
-- SITE 1 — Création du fragment R1 par CTAS
--   R1 = sigma[ idcateg = 50 AND quantite > 100 ] (LigneCommandes)
-- ------------------------------------------------------------
-- Approche (fragmentation horizontale DÉRIVÉE) :
--   1) On matérialise le fragment directement depuis la base globale
--      via le lien 'link_central' : CTAS = CREATE + chargement en un
--      seul passage (rapide, et ne déclenche aucun trigger).
--   2) Produits1 / Commandes1 / Clients1 sont DÉRIVÉS : on ne conserve
--      que les lignes effectivement référencées par ligneCommandes1.
--      => l'intégrité référentielle est garantie par construction.
--   3) CTAS ne copie NI clés NI index : on les ajoute après
--      (PK d'abord, puis FK, puis index sur les colonnes de jointure).
--
-- Le lien 'link_central' étant PRIVÉ (propriété de eshop_site1), on se
-- connecte en tant que eshop_site1 pour que '@link_central' se résolve.
-- ============================================================
CONNECT eshop_site1/EshopPassword123@//localhost:1521/XEPDB1
SET SERVEROUTPUT ON

-- ------------------------------------------------------------
-- Anti-race au démarrage : on attend que la base globale soit peuplée
-- (le conteneur site peut être prêt avant la fin du seed du master).
-- ------------------------------------------------------------
DECLARE
    v_cnt NUMBER := 0;
    v_try NUMBER := 0;
BEGIN
    LOOP
        BEGIN
            SELECT COUNT(*) INTO v_cnt FROM lignecommandes@link_central;
        EXCEPTION WHEN OTHERS THEN
            v_cnt := 0;   -- master pas encore joignable / pas prêt
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
BEGIN EXECUTE IMMEDIATE 'DROP TABLE lignecommandes1 CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE commandes1 CASCADE CONSTRAINTS';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE produits1 CASCADE CONSTRAINTS';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE clients1 CASCADE CONSTRAINTS';        EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ------------------------------------------------------------
-- 1. Fragment principal : les lignes qui vérifient R1
-- ------------------------------------------------------------
CREATE TABLE lignecommandes1 AS
SELECT lc.idlignecommande, lc.idcommande, lc.idproduit, lc.quantite, lc.remise
FROM   lignecommandes@link_central lc
JOIN   produits@link_central p ON p.idproduit = lc.idproduit
WHERE  p.idcateg = 50 AND lc.quantite > 100;

-- ------------------------------------------------------------
-- 2. Produits dérivés (seulement ceux référencés par le fragment)
-- ------------------------------------------------------------
-- (Même ordre de colonnes que le master, pour que les procédures
--  'SELECT * INTO v_prod / INSERT VALUES v_prod' restent valides.)
CREATE TABLE produits1 AS
SELECT p.idproduit, p.designation, p.prixunitaire, p.idcateg
FROM   produits@link_central p
WHERE  p.idproduit IN (SELECT idproduit FROM lignecommandes1);

-- ------------------------------------------------------------
-- 3. Commandes dérivées
-- ------------------------------------------------------------
CREATE TABLE commandes1 AS
SELECT c.idcommande, c.idemploye, c.idclient, c.datecommande
FROM   commandes@link_central c
WHERE  c.idcommande IN (SELECT idcommande FROM lignecommandes1);

-- ------------------------------------------------------------
-- 4. Clients dérivés
-- ------------------------------------------------------------
CREATE TABLE clients1 AS
SELECT cl.idclient, cl.codeclient, cl.societe
FROM   clients@link_central cl
WHERE  cl.idclient IN (SELECT idclient FROM commandes1);

-- ------------------------------------------------------------
-- 5. Contraintes d'intégrité (CTAS ne les copie pas) : PK puis FK
-- ------------------------------------------------------------
ALTER TABLE clients1        ADD CONSTRAINT pk_clients1        PRIMARY KEY (idclient);
ALTER TABLE produits1       ADD CONSTRAINT pk_produits1       PRIMARY KEY (idproduit);
ALTER TABLE commandes1      ADD CONSTRAINT pk_commandes1      PRIMARY KEY (idcommande);
ALTER TABLE lignecommandes1 ADD CONSTRAINT pk_lignecommandes1 PRIMARY KEY (idlignecommande);

ALTER TABLE commandes1 ADD CONSTRAINT fk_cmd1_client
    FOREIGN KEY (idclient) REFERENCES clients1(idclient);
ALTER TABLE lignecommandes1 ADD CONSTRAINT fk_lc1_cmd
    FOREIGN KEY (idcommande) REFERENCES commandes1(idcommande);
ALTER TABLE lignecommandes1 ADD CONSTRAINT fk_lc1_prod
    FOREIGN KEY (idproduit) REFERENCES produits1(idproduit);

-- Colonnes de relation obligatoires (les FK sont nullables par défaut)
ALTER TABLE commandes1      MODIFY idclient   NOT NULL;
ALTER TABLE lignecommandes1 MODIFY idcommande NOT NULL;
ALTER TABLE lignecommandes1 MODIFY idproduit  NOT NULL;
-- NB : pas de CHECK sur quantite -> en multi-maître, une ligne destinée
-- a un autre site TRANSITE par site1 (insert AFTER -> route -> delete),
-- donc on ne peut pas verrouiller le fragment par une contrainte dure.

-- ------------------------------------------------------------
-- 6. Index sur les colonnes de jointure / FK
--    (Oracle n'indexe pas les FK automatiquement : utile pour les
--     jointures, et évite les verrous de table sur les parents.)
-- ------------------------------------------------------------
CREATE INDEX ix_lc1_cmd  ON lignecommandes1(idcommande);
CREATE INDEX ix_lc1_prod ON lignecommandes1(idproduit);
CREATE INDEX ix_cmd1_cli ON commandes1(idclient);

-- ------------------------------------------------------------
-- 6b. Séquences pour les écritures ORIGINÉES sur le Site 1 (multi-maître)
--     Offset mod 3 -> Site 1 = voie 2 (2,5,8,...) : aucune collision
--     possible avec le Master (voie 1) ni le Site 2 (voie 0).
--     On positionne le START au-delà des IDs déjà chargés par le CTAS.
-- ------------------------------------------------------------
DECLARE
    PROCEDURE make_seq(p_seq VARCHAR2, p_col VARCHAR2, p_tab VARCHAR2) IS
        v_m NUMBER; v_s NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT NVL(MAX('||p_col||'),0) FROM '||p_tab INTO v_m;
        v_s := v_m + 1;
        WHILE MOD(v_s, 3) <> 2 LOOP v_s := v_s + 1; END LOOP;   -- voie 2
        BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE '||p_seq; EXCEPTION WHEN OTHERS THEN NULL; END;
        EXECUTE IMMEDIATE 'CREATE SEQUENCE '||p_seq||' START WITH '||v_s||' INCREMENT BY 3 NOCACHE NOCYCLE';
    END;
BEGIN
    make_seq('seq_clients1',        'idclient',        'clients1');
    make_seq('seq_produits1',       'idproduit',       'produits1');
    make_seq('seq_commandes1',      'idcommande',      'commandes1');
    make_seq('seq_lignecommandes1', 'idlignecommande', 'lignecommandes1');
END;
/

-- Valeur par défaut : un INSERT local sans ID prend automatiquement
-- le prochain ID de la voie du Site 1.
ALTER TABLE clients1        MODIFY idclient        DEFAULT seq_clients1.NEXTVAL;
ALTER TABLE produits1       MODIFY idproduit       DEFAULT seq_produits1.NEXTVAL;
ALTER TABLE commandes1      MODIFY idcommande      DEFAULT seq_commandes1.NEXTVAL;
ALTER TABLE lignecommandes1 MODIFY idlignecommande DEFAULT seq_lignecommandes1.NEXTVAL;

-- ------------------------------------------------------------
-- 7. Statistiques optimiseur (après chargement en masse) :
--    indispensable pour obtenir des plans d'exécution fiables (Q5/Q6).
-- ------------------------------------------------------------
BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'CLIENTS1',        cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'PRODUITS1',       cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'COMMANDES1',      cascade => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'LIGNECOMMANDES1', cascade => TRUE);
END;
/

-- ------------------------------------------------------------
-- 8. Rapport de contrôle dans les logs du conteneur
-- ------------------------------------------------------------
DECLARE
    n_lc NUMBER; n_p NUMBER; n_c NUMBER; n_cl NUMBER;
BEGIN
    SELECT COUNT(*) INTO n_lc FROM lignecommandes1;
    SELECT COUNT(*) INTO n_p  FROM produits1;
    SELECT COUNT(*) INTO n_c  FROM commandes1;
    SELECT COUNT(*) INTO n_cl FROM clients1;
    DBMS_OUTPUT.PUT_LINE('[Site1] Fragment R1 charge : '
        || n_lc || ' lignes, ' || n_p || ' produits, '
        || n_c || ' commandes, ' || n_cl || ' clients.');
END;
/
