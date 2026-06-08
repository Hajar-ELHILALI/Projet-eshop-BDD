-- ============================================================
-- ESHOP_ADMIN (Master) — Offset 1 : 1, 4, 7, 10 ...
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- SÉQUENCES
CREATE SEQUENCE seq_clients        START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_produits       START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_commandes      START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_lignecommandes START WITH 1 INCREMENT BY 3 NOCACHE NOCYCLE;

-- TABLES
CREATE TABLE clients (
    idclient   NUMBER DEFAULT seq_clients.NEXTVAL PRIMARY KEY,
    Codeclient VARCHAR2(50),
    Societe    VARCHAR2(100)
);

CREATE TABLE produits (
    idproduit    NUMBER DEFAULT seq_produits.NEXTVAL PRIMARY KEY,
    designation  VARCHAR2(100),
    prixunitaire NUMBER(10,2),
    idcateg      NUMBER
);

CREATE TABLE commandes (
    idcommande   NUMBER DEFAULT seq_commandes.NEXTVAL PRIMARY KEY,
    idemploye    NUMBER,
    idclient     NUMBER,
    datecommande DATE,
    CONSTRAINT fk_master_client FOREIGN KEY (idclient)
        REFERENCES clients(idclient) ON DELETE CASCADE
);

CREATE TABLE lignecommandes (
    idligneCommande NUMBER DEFAULT seq_lignecommandes.NEXTVAL PRIMARY KEY,
    idcommande      NUMBER,
    idproduit       NUMBER,
    Quantite        NUMBER,
    remise          NUMBER(5,2),
    CONSTRAINT fk_master_cmd  FOREIGN KEY (idcommande)
        REFERENCES commandes(idcommande) ON DELETE CASCADE,
    CONSTRAINT fk_master_prod FOREIGN KEY (idproduit)
        REFERENCES produits(idproduit)   ON DELETE CASCADE
);