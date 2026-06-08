-- ============================================================
-- SCENARIO 2 | MASTER -- Schema de la base globale
-- ------------------------------------------------------------
-- Identique au Scenario 1 : les tables globales ne changent pas.
-- La fragmentation n'affecte pas le schema du Master.
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- Sequences (voie 1 : 1, 4, 7, 10, ...)
CREATE SEQUENCE seq_clients        START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_produits       START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_commandes      START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_lignecommandes START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;

-- Table CLIENTS
CREATE TABLE clients (
    idclient   NUMBER DEFAULT seq_clients.NEXTVAL PRIMARY KEY,
    Codeclient VARCHAR2(50)  NOT NULL,
    Societe    VARCHAR2(100) NOT NULL
);

-- Table PRODUITS
CREATE TABLE produits (
    idproduit    NUMBER DEFAULT seq_produits.NEXTVAL PRIMARY KEY,
    designation  VARCHAR2(100) NOT NULL,
    prixunitaire NUMBER(10,2)  NOT NULL,
    idcateg      NUMBER        NOT NULL
);

-- Table COMMANDES
CREATE TABLE commandes (
    idcommande   NUMBER DEFAULT seq_commandes.NEXTVAL PRIMARY KEY,
    idemploye    NUMBER,
    idclient     NUMBER NOT NULL,
    datecommande DATE   NOT NULL,
    CONSTRAINT fk_master_client FOREIGN KEY (idclient)
        REFERENCES clients(idclient) ON DELETE CASCADE
);

-- Table LIGNECOMMANDES (table a fragmenter selon le Scenario 2)
CREATE TABLE lignecommandes (
    idligneCommande NUMBER DEFAULT seq_lignecommandes.NEXTVAL PRIMARY KEY,
    idcommande      NUMBER NOT NULL,
    idproduit       NUMBER NOT NULL,
    Quantite        NUMBER NOT NULL,
    remise          NUMBER(5,2),
    CONSTRAINT fk_master_cmd  FOREIGN KEY (idcommande)
        REFERENCES commandes(idcommande) ON DELETE CASCADE,
    CONSTRAINT fk_master_prod FOREIGN KEY (idproduit)
        REFERENCES produits(idproduit) ON DELETE CASCADE
);
