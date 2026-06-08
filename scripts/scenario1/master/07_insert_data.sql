ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- Desactiver les variables de substitution SQL*Plus (evite que & dans les
-- commentaires soit interprete comme une variable et interrompe le script).
SET DEFINE OFF
SET SERVEROUTPUT ON

-- ============================================================
-- Chargement initial (mode PULL) : les sites tireront leur fragment
-- par CTAS. On DÉSACTIVE les triggers de distribution pendant le seed
-- (les sites ne sont pas encore démarrés). On les réactive à la fin.
-- ============================================================
ALTER TRIGGER SYC_INSERT_LIGNE DISABLE;
ALTER TRIGGER SYC_DELETE_LIGNE DISABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE DISABLE;

-- ============================================================
-- DONNÉES RÉELLES — EShop B2B Maroc
-- Contexte : plateforme e-commerce B2B marocaine.
--   Cat 50 = Electronique et High-Tech  (gros volumes - Site 1)
--   Cat 35 = Mobilier et Amenagement   (volumes moyens - Site 2)
--   Cat 10 = Fournitures de bureau     (petits volumes → Master seul)
-- ============================================================

BEGIN

    -- =========================================================
    -- 1. CLIENTS (50 entreprises marocaines réalistes)
    -- =========================================================

    -- Grandes entreprises (10)
    INSERT INTO clients VALUES (10001, 'CLI-MAR-001', 'Marjane Holding');
    INSERT INTO clients VALUES (10002, 'CLI-MAR-002', 'Label Vie S.A.');
    INSERT INTO clients VALUES (10003, 'CLI-MAR-003', 'OCP Group');
    INSERT INTO clients VALUES (10004, 'CLI-MAR-004', 'Attijariwafa Bank');
    INSERT INTO clients VALUES (10005, 'CLI-MAR-005', 'Banque Populaire du Maroc');
    INSERT INTO clients VALUES (10006, 'CLI-MAR-006', 'Maroc Telecom');
    INSERT INTO clients VALUES (10007, 'CLI-MAR-007', 'Centrale Danone Maroc');
    INSERT INTO clients VALUES (10008, 'CLI-MAR-008', 'Sonasid');
    INSERT INTO clients VALUES (10009, 'CLI-MAR-009', 'Lafarge Holcim Maroc');
    INSERT INTO clients VALUES (10010, 'CLI-MAR-010', 'Cosumar');

    -- PME industrielles (15)
    INSERT INTO clients VALUES (10011, 'CLI-PME-011', 'Maghreb Steel');
    INSERT INTO clients VALUES (10012, 'CLI-PME-012', 'Promopharm S.A.');
    INSERT INTO clients VALUES (10013, 'CLI-PME-013', 'Cartier Saada');
    INSERT INTO clients VALUES (10014, 'CLI-PME-014', 'Douja Prom Addoha');
    INSERT INTO clients VALUES (10015, 'CLI-PME-015', 'Alliances Développement');
    INSERT INTO clients VALUES (10016, 'CLI-PME-016', 'BTP Maroc');
    INSERT INTO clients VALUES (10017, 'CLI-PME-017', 'Société Chérifienne des Engrais');
    INSERT INTO clients VALUES (10018, 'CLI-PME-018', 'Managem Group');
    INSERT INTO clients VALUES (10019, 'CLI-PME-019', 'Auto Nejma');
    INSERT INTO clients VALUES (10020, 'CLI-PME-020', 'Ménara Prefa');
    INSERT INTO clients VALUES (10021, 'CLI-PME-021', 'Lesieur Cristal');
    INSERT INTO clients VALUES (10022, 'CLI-PME-022', 'SAMIR Raffinage');
    INSERT INTO clients VALUES (10023, 'CLI-PME-023', 'Colorado Maroc');
    INSERT INTO clients VALUES (10024, 'CLI-PME-024', 'Akwa Group');
    INSERT INTO clients VALUES (10025, 'CLI-PME-025', 'Palmeraie Développement');

    -- TPE / Services (15)
    INSERT INTO clients VALUES (10026, 'CLI-TPE-026', 'Agence Digital Casablanca');
    INSERT INTO clients VALUES (10027, 'CLI-TPE-027', 'Cabinet Comptable Alami');
    INSERT INTO clients VALUES (10028, 'CLI-TPE-028', 'Clinique Al Amal Rabat');
    INSERT INTO clients VALUES (10029, 'CLI-TPE-029', 'Ecole Privée Al Khawarizmi');
    INSERT INTO clients VALUES (10030, 'CLI-TPE-030', 'Restaurant Dar Zitoun');
    INSERT INTO clients VALUES (10031, 'CLI-TPE-031', 'Hôtel Riad Fès');
    INSERT INTO clients VALUES (10032, 'CLI-TPE-032', 'Transport Soufiane Sarl');
    INSERT INTO clients VALUES (10033, 'CLI-TPE-033', 'Imprimerie Atlas');
    INSERT INTO clients VALUES (10034, 'CLI-TPE-034', 'Librairie Kalila wa Dimna');
    INSERT INTO clients VALUES (10035, 'CLI-TPE-035', 'Pharmacie Ibn Sina');
    INSERT INTO clients VALUES (10036, 'CLI-TPE-036', 'Menuiserie El Fath');
    INSERT INTO clients VALUES (10037, 'CLI-TPE-037', 'Boulangerie Andalous');
    INSERT INTO clients VALUES (10038, 'CLI-TPE-038', 'Studio Photo Lumière');
    INSERT INTO clients VALUES (10039, 'CLI-TPE-039', 'Auto-École Sécurité Plus');
    INSERT INTO clients VALUES (10040, 'CLI-TPE-040', 'Pressing Propre Net');

    -- Collectivites et administrations (10)
    INSERT INTO clients VALUES (10041, 'CLI-ADM-041', 'Commune Urbaine de Casablanca');
    INSERT INTO clients VALUES (10042, 'CLI-ADM-042', 'Académie Régionale Rabat-Salé');
    INSERT INTO clients VALUES (10043, 'CLI-ADM-043', 'CHU Ibn Rochd');
    INSERT INTO clients VALUES (10044, 'CLI-ADM-044', 'Office National des Chemins de Fer');
    INSERT INTO clients VALUES (10045, 'CLI-ADM-045', 'Agence Urbaine de Marrakech');
    INSERT INTO clients VALUES (10046, 'CLI-ADM-046', 'Ministère de l''Education Nationale');
    INSERT INTO clients VALUES (10047, 'CLI-ADM-047', 'RAM Royal Air Maroc');
    INSERT INTO clients VALUES (10048, 'CLI-ADM-048', 'Marsa Maroc');
    INSERT INTO clients VALUES (10049, 'CLI-ADM-049', 'Office National de l''Electricité');
    INSERT INTO clients VALUES (10050, 'CLI-ADM-050', 'Lydec Casablanca');

    -- =========================================================
    -- 2. PRODUITS (30 produits réalistes)
    -- =========================================================

    -- === CAT 50 : Electronique et High-Tech (Site 1) - 10 produits ===
    INSERT INTO produits VALUES (20001, 'Serveur Dell PowerEdge R750',         18500.00, 50);
    INSERT INTO produits VALUES (20002, 'Switch HP Aruba 48 ports 10G',         8900.00, 50);
    INSERT INTO produits VALUES (20003, 'Station de travail Lenovo ThinkStation',6200.00, 50);
    INSERT INTO produits VALUES (20004, 'Onduleur APC Smart-UPS 10kVA',         12400.00, 50);
    INSERT INTO produits VALUES (20005, 'Firewall Fortinet FortiGate 200E',      22000.00, 50);
    INSERT INTO produits VALUES (20006, 'NAS Synology RS3621xs+ (12 baies)',     15800.00, 50);
    INSERT INTO produits VALUES (20007, 'Climatiseur salle serveur Daikin 36kW', 34000.00, 50);
    INSERT INTO produits VALUES (20008, 'Rack armoire 42U APC NetShelter',        4600.00, 50);
    INSERT INTO produits VALUES (20009, 'Imprimante industrielle Xerox C9070',    7800.00, 50);
    INSERT INTO produits VALUES (20010, 'Vidéoprojecteur Epson EB-L1755U',        9200.00, 50);

    -- === CAT 35 : Mobilier et Amenagement (Site 2) - 10 produits ===
    INSERT INTO produits VALUES (20011, 'Bureau direction en chêne massif',       3200.00, 35);
    INSERT INTO produits VALUES (20012, 'Chaise ergonomique Herman Miller Aeron',  980.00, 35);
    INSERT INTO produits VALUES (20013, 'Armoire métallique sécurisée 4 tiroirs',  650.00, 35);
    INSERT INTO produits VALUES (20014, 'Table de conférence 12 places',           4800.00, 35);
    INSERT INTO produits VALUES (20015, 'Bibliothèque modulable open-space',       1200.00, 35);
    INSERT INTO produits VALUES (20016, 'Cloison acoustique 200x140 cm',            890.00, 35);
    INSERT INTO produits VALUES (20017, 'Casier sécurisé 12 compartiments',         760.00, 35);
    INSERT INTO produits VALUES (20018, 'Fauteuil visiteur cuir Havane',            420.00, 35);
    INSERT INTO produits VALUES (20019, 'Tableau blanc interactif 86 pouces',      2400.00, 35);
    INSERT INTO produits VALUES (20020, 'Poste de travail height-adjustable',      1850.00, 35);

    -- === CAT 10 : Fournitures de bureau (Master seul) - 10 produits ===
    INSERT INTO produits VALUES (20021, 'Ramette papier A4 80g (carton 5x500)',     85.00, 10);
    INSERT INTO produits VALUES (20022, 'Stylos bille Bic Cristal (boîte 100)',     45.00, 10);
    INSERT INTO produits VALUES (20023, 'Classeur à levier A4 (lot 20)',            120.00, 10);
    INSERT INTO produits VALUES (20024, 'Cartouche toner HP LaserJet (lot 4)',      680.00, 10);
    INSERT INTO produits VALUES (20025, 'Ruban adhésif Scotch (lot 50)',             95.00, 10);
    INSERT INTO produits VALUES (20026, 'Post-it 76x76mm (lot 12 blocs)',            55.00, 10);
    INSERT INTO produits VALUES (20027, 'Agrafeuse Rapid 73 + 5000 agrafes',         38.00, 10);
    INSERT INTO produits VALUES (20028, 'Corbeille courrier métallique (lot 5)',      75.00, 10);
    INSERT INTO produits VALUES (20029, 'Cahier 200p grands carreaux Clairefontaine', 28.00, 10);
    INSERT INTO produits VALUES (20030, 'Destructeur de documents Rexel Auto+',     420.00, 10);

    -- =========================================================
    -- 3. COMMANDES (100 commandes réparties sur 2026)
    --    Employés : 3 commerciaux (IDs 1, 2, 3)
    -- =========================================================

    -- Janvier 2026 (15 commandes)
    INSERT INTO commandes VALUES (30001, 1, 10003, DATE '2026-01-05'); -- OCP
    INSERT INTO commandes VALUES (30002, 2, 10006, DATE '2026-01-08'); -- Maroc Telecom
    INSERT INTO commandes VALUES (30003, 1, 10001, DATE '2026-01-10'); -- Marjane
    INSERT INTO commandes VALUES (30004, 3, 10044, DATE '2026-01-12'); -- ONCF
    INSERT INTO commandes VALUES (30005, 2, 10011, DATE '2026-01-15'); -- Maghreb Steel
    INSERT INTO commandes VALUES (30006, 1, 10047, DATE '2026-01-18'); -- RAM
    INSERT INTO commandes VALUES (30007, 3, 10004, DATE '2026-01-20'); -- Attijariwafa
    INSERT INTO commandes VALUES (30008, 2, 10008, DATE '2026-01-22'); -- Sonasid
    INSERT INTO commandes VALUES (30009, 1, 10041, DATE '2026-01-25'); -- Commune Casablanca
    INSERT INTO commandes VALUES (30010, 3, 10049, DATE '2026-01-27'); -- ONE
    INSERT INTO commandes VALUES (30011, 2, 10012, DATE '2026-01-28'); -- Promopharm
    INSERT INTO commandes VALUES (30012, 1, 10022, DATE '2026-01-29'); -- SAMIR
    INSERT INTO commandes VALUES (30013, 3, 10033, DATE '2026-01-30'); -- Imprimerie Atlas
    INSERT INTO commandes VALUES (30014, 2, 10043, DATE '2026-01-31'); -- CHU Ibn Rochd
    INSERT INTO commandes VALUES (30015, 1, 10050, DATE '2026-01-31'); -- Lydec

    -- Février 2026 (10 commandes)
    INSERT INTO commandes VALUES (30016, 2, 10009, DATE '2026-02-03'); -- Lafarge
    INSERT INTO commandes VALUES (30017, 3, 10014, DATE '2026-02-06'); -- Addoha
    INSERT INTO commandes VALUES (30018, 1, 10024, DATE '2026-02-10'); -- Akwa
    INSERT INTO commandes VALUES (30019, 2, 10031, DATE '2026-02-13'); -- Riad Fès
    INSERT INTO commandes VALUES (30020, 3, 10042, DATE '2026-02-17'); -- Académie
    INSERT INTO commandes VALUES (30021, 1, 10005, DATE '2026-02-19'); -- BP Maroc
    INSERT INTO commandes VALUES (30022, 2, 10016, DATE '2026-02-21'); -- BTP Maroc
    INSERT INTO commandes VALUES (30023, 3, 10027, DATE '2026-02-24'); -- Cabinet Alami
    INSERT INTO commandes VALUES (30024, 1, 10038, DATE '2026-02-25'); -- Studio Photo
    INSERT INTO commandes VALUES (30025, 2, 10046, DATE '2026-02-28'); -- Min. Education

    -- Mars 2026 (10 commandes)
    INSERT INTO commandes VALUES (30026, 3, 10002, DATE '2026-03-02'); -- Label Vie
    INSERT INTO commandes VALUES (30027, 1, 10007, DATE '2026-03-05'); -- Danone
    INSERT INTO commandes VALUES (30028, 2, 10013, DATE '2026-03-09'); -- Cartier Saada
    INSERT INTO commandes VALUES (30029, 3, 10019, DATE '2026-03-12'); -- Auto Nejma
    INSERT INTO commandes VALUES (30030, 1, 10025, DATE '2026-03-16'); -- Palmeraie
    INSERT INTO commandes VALUES (30031, 2, 10032, DATE '2026-03-18'); -- Transport Soufiane
    INSERT INTO commandes VALUES (30032, 3, 10039, DATE '2026-03-20'); -- Auto-École
    INSERT INTO commandes VALUES (30033, 1, 10045, DATE '2026-03-23'); -- Agence Marrakech
    INSERT INTO commandes VALUES (30034, 2, 10048, DATE '2026-03-25'); -- Marsa Maroc
    INSERT INTO commandes VALUES (30035, 3, 10010, DATE '2026-03-28'); -- Cosumar

    -- Avril 2026 (10 commandes)
    INSERT INTO commandes VALUES (30036, 1, 10015, DATE '2026-04-02'); -- Alliances
    INSERT INTO commandes VALUES (30037, 2, 10020, DATE '2026-04-07'); -- Ménara Prefa
    INSERT INTO commandes VALUES (30038, 3, 10026, DATE '2026-04-09'); -- Agence Digital
    INSERT INTO commandes VALUES (30039, 1, 10034, DATE '2026-04-14'); -- Librairie
    INSERT INTO commandes VALUES (30040, 2, 10040, DATE '2026-04-16'); -- Pressing
    INSERT INTO commandes VALUES (30041, 3, 10003, DATE '2026-04-18'); -- OCP (2e cmd)
    INSERT INTO commandes VALUES (30042, 1, 10006, DATE '2026-04-21'); -- Maroc Telecom (2e)
    INSERT INTO commandes VALUES (30043, 2, 10018, DATE '2026-04-23'); -- Managem
    INSERT INTO commandes VALUES (30044, 3, 10028, DATE '2026-04-25'); -- Clinique
    INSERT INTO commandes VALUES (30045, 1, 10049, DATE '2026-04-28'); -- ONE (2e)

    -- Mai 2026 (10 commandes)
    INSERT INTO commandes VALUES (30046, 2, 10001, DATE '2026-05-04'); -- Marjane (2e)
    INSERT INTO commandes VALUES (30047, 3, 10017, DATE '2026-05-06'); -- SCE
    INSERT INTO commandes VALUES (30048, 1, 10023, DATE '2026-05-09'); -- Colorado
    INSERT INTO commandes VALUES (30049, 2, 10029, DATE '2026-05-12'); -- Ecole Khawarizmi
    INSERT INTO commandes VALUES (30050, 3, 10035, DATE '2026-05-15'); -- Pharmacie
    INSERT INTO commandes VALUES (30051, 1, 10004, DATE '2026-05-19'); -- Attijariwafa (2e)
    INSERT INTO commandes VALUES (30052, 2, 10011, DATE '2026-05-21'); -- Maghreb Steel (2e)
    INSERT INTO commandes VALUES (30053, 3, 10036, DATE '2026-05-23'); -- Menuiserie
    INSERT INTO commandes VALUES (30054, 1, 10041, DATE '2026-05-26'); -- Commune Casa (2e)
    INSERT INTO commandes VALUES (30055, 2, 10044, DATE '2026-05-28'); -- ONCF (2e)

    -- Juin 2026 (10 commandes)
    INSERT INTO commandes VALUES (30056, 3, 10008, DATE '2026-06-02'); -- Sonasid (2e)
    INSERT INTO commandes VALUES (30057, 1, 10021, DATE '2026-06-04'); -- Lesieur
    INSERT INTO commandes VALUES (30058, 2, 10030, DATE '2026-06-06'); -- Dar Zitoun
    INSERT INTO commandes VALUES (30059, 3, 10037, DATE '2026-06-09'); -- Boulangerie
    INSERT INTO commandes VALUES (30060, 1, 10047, DATE '2026-06-11'); -- RAM (2e)
    INSERT INTO commandes VALUES (30061, 2, 10005, DATE '2026-06-13'); -- BP Maroc (2e)
    INSERT INTO commandes VALUES (30062, 3, 10009, DATE '2026-06-16'); -- Lafarge (2e)
    INSERT INTO commandes VALUES (30063, 1, 10016, DATE '2026-06-18'); -- BTP Maroc (2e)
    INSERT INTO commandes VALUES (30064, 2, 10043, DATE '2026-06-20'); -- CHU (2e)
    INSERT INTO commandes VALUES (30065, 3, 10050, DATE '2026-06-23'); -- Lydec (2e)

    -- Juillet 2026 (5 commandes)
    INSERT INTO commandes VALUES (30066, 1, 10002, DATE '2026-07-01'); -- Label Vie (2e)
    INSERT INTO commandes VALUES (30067, 2, 10024, DATE '2026-07-05'); -- Akwa (2e)
    INSERT INTO commandes VALUES (30068, 3, 10031, DATE '2026-07-09'); -- Riad Fès (2e)
    INSERT INTO commandes VALUES (30069, 1, 10042, DATE '2026-07-14'); -- Académie (2e)
    INSERT INTO commandes VALUES (30070, 2, 10046, DATE '2026-07-18'); -- Min. Education (2e)

    -- Août 2026 (5 commandes)
    INSERT INTO commandes VALUES (30071, 3, 10003, DATE '2026-08-03'); -- OCP (3e)
    INSERT INTO commandes VALUES (30072, 1, 10006, DATE '2026-08-07'); -- Maroc Telecom (3e)
    INSERT INTO commandes VALUES (30073, 2, 10014, DATE '2026-08-12'); -- Addoha (2e)
    INSERT INTO commandes VALUES (30074, 3, 10020, DATE '2026-08-18'); -- Ménara (2e)
    INSERT INTO commandes VALUES (30075, 1, 10048, DATE '2026-08-25'); -- Marsa Maroc (2e)

    -- Septembre 2026 (5 commandes)
    INSERT INTO commandes VALUES (30076, 2, 10001, DATE '2026-09-02'); -- Marjane (3e)
    INSERT INTO commandes VALUES (30077, 3, 10010, DATE '2026-09-08'); -- Cosumar (2e)
    INSERT INTO commandes VALUES (30078, 1, 10025, DATE '2026-09-15'); -- Palmeraie (2e)
    INSERT INTO commandes VALUES (30079, 2, 10038, DATE '2026-09-19'); -- Studio Photo (2e)
    INSERT INTO commandes VALUES (30080, 3, 10045, DATE '2026-09-25'); -- Agence Marrakech (2e)

    -- Octobre 2026 (5 commandes)
    INSERT INTO commandes VALUES (30081, 1, 10004, DATE '2026-10-03'); -- Attijariwafa (3e)
    INSERT INTO commandes VALUES (30082, 2, 10007, DATE '2026-10-09'); -- Danone (2e)
    INSERT INTO commandes VALUES (30083, 3, 10015, DATE '2026-10-14'); -- Alliances (2e)
    INSERT INTO commandes VALUES (30084, 1, 10022, DATE '2026-10-20'); -- SAMIR (2e)
    INSERT INTO commandes VALUES (30085, 2, 10047, DATE '2026-10-27'); -- RAM (3e)

    -- Novembre 2026 (5 commandes)
    INSERT INTO commandes VALUES (30086, 3, 10011, DATE '2026-11-04'); -- Maghreb Steel (3e)
    INSERT INTO commandes VALUES (30087, 1, 10017, DATE '2026-11-10'); -- SCE (2e)
    INSERT INTO commandes VALUES (30088, 2, 10032, DATE '2026-11-17'); -- Transport (2e)
    INSERT INTO commandes VALUES (30089, 3, 10041, DATE '2026-11-21'); -- Commune Casa (3e)
    INSERT INTO commandes VALUES (30090, 1, 10049, DATE '2026-11-28'); -- ONE (3e)

    -- Décembre 2026 (10 commandes)
    INSERT INTO commandes VALUES (30091, 2, 10003, DATE '2026-12-02'); -- OCP (4e)
    INSERT INTO commandes VALUES (30092, 3, 10008, DATE '2026-12-05'); -- Sonasid (3e)
    INSERT INTO commandes VALUES (30093, 1, 10013, DATE '2026-12-09'); -- Cartier Saada (2e)
    INSERT INTO commandes VALUES (30094, 2, 10019, DATE '2026-12-11'); -- Auto Nejma (2e)
    INSERT INTO commandes VALUES (30095, 3, 10026, DATE '2026-12-15'); -- Agence Digital (2e)
    INSERT INTO commandes VALUES (30096, 1, 10034, DATE '2026-12-17'); -- Librairie (2e)
    INSERT INTO commandes VALUES (30097, 2, 10043, DATE '2026-12-19'); -- CHU (3e)
    INSERT INTO commandes VALUES (30098, 3, 10044, DATE '2026-12-22'); -- ONCF (3e)
    INSERT INTO commandes VALUES (30099, 1, 10050, DATE '2026-12-27'); -- Lydec (3e)
    INSERT INTO commandes VALUES (30100, 2, 10046, DATE '2026-12-30'); -- Min. Education (3e)

    -- Commit intermédiaire : les sites DOIVENT voir clients/commandes
    -- via les database links AVANT le CTAS sur lignecommandes.
    COMMIT;

    -- =========================================================
    -- 4. LIGNES DE COMMANDES (300 lignes)
    --    3 lignes par commande :
    --    - Ligne A : cat 50 / qté 120-200  → Site 1
    --    - Ligne B : cat 35 / qté 60-150   → Site 2
    --    - Ligne C : cat 10 / qté 200-1000 → Master seul
    -- =========================================================
    FOR i IN 1..100 LOOP
        DECLARE
            v_cmd   NUMBER := 30000 + i;
            v_idlc  NUMBER;
            v_prod50 NUMBER := 20001 + MOD(i-1, 10);  -- rotation sur les 10 produits cat50
            v_prod35 NUMBER := 20011 + MOD(i-1, 10);  -- rotation sur les 10 produits cat35
            v_prod10 NUMBER := 20021 + MOD(i-1, 10);  -- rotation sur les 10 produits cat10
            -- Quantités variées mais toujours dans les règles de fragment
            v_qte50  NUMBER := 120 + MOD(i * 7, 81);  -- entre 120 et 200
            v_qte35  NUMBER :=  60 + MOD(i * 5, 91);  -- entre  60 et 150
            v_qte10  NUMBER := 200 + MOD(i * 3, 801); -- entre 200 et 1000
            -- Remises réalistes (0 = pas de remise, sinon 2-15%)
            v_rem50  NUMBER := ROUND(MOD(i * 3, 16) / 100, 2);
            v_rem35  NUMBER := ROUND(MOD(i * 7, 16) / 100, 2);
        BEGIN
            -- Ligne A → Site 1 (cat 50, qté > 100)
            v_idlc := 40000 + (i * 3) - 2;
            INSERT INTO lignecommandes VALUES (v_idlc, v_cmd, v_prod50, v_qte50, v_rem50);

            -- Ligne B → Site 2 (cat 35, qté > 50)
            v_idlc := 40000 + (i * 3) - 1;
            INSERT INTO lignecommandes VALUES (v_idlc, v_cmd, v_prod35, v_qte35, v_rem35);

            -- Ligne C → Master seul (cat 10)
            v_idlc := 40000 + (i * 3);
            INSERT INTO lignecommandes VALUES (v_idlc, v_cmd, v_prod10, v_qte10, 0);
        END;
    END LOOP;

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('Seed EShop B2B Maroc :');
    DBMS_OUTPUT.PUT_LINE('  50 clients (entreprises marocaines reelles)');
    DBMS_OUTPUT.PUT_LINE('  30 produits (10 cat50, 10 cat35, 10 cat10)');
    DBMS_OUTPUT.PUT_LINE(' 100 commandes (jan-dec 2026)');
    DBMS_OUTPUT.PUT_LINE(' 300 lignes de commandes');
    DBMS_OUTPUT.PUT_LINE('=================================================');
END;
/

-- ============================================================
-- Repositionnement des séquences au-delà des IDs du seed
-- (voie 1 = master, mod 3 = 1)
-- ============================================================
DECLARE
    PROCEDURE bump_seq(p_seq VARCHAR2, p_col VARCHAR2, p_tab VARCHAR2) IS
        v_m NUMBER; v_s NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'SELECT NVL(MAX('||p_col||'),0) FROM '||p_tab INTO v_m;
        v_s := v_m + 1;
        WHILE MOD(v_s, 3) <> 1 LOOP v_s := v_s + 1; END LOOP;
        EXECUTE IMMEDIATE 'ALTER SEQUENCE '||p_seq||' RESTART START WITH '||v_s;
    END;
BEGIN
    bump_seq('seq_clients',        'idclient',        'clients');
    bump_seq('seq_produits',       'idproduit',       'produits');
    bump_seq('seq_commandes',      'idcommande',      'commandes');
    bump_seq('seq_lignecommandes', 'idlignecommande', 'lignecommandes');
    DBMS_OUTPUT.PUT_LINE('Sequences repositionnees (voie 1 = master).');
END;
/

-- Réactivation des triggers de distribution pour les écritures FUTURES
ALTER TRIGGER SYC_INSERT_LIGNE ENABLE;
ALTER TRIGGER SYC_DELETE_LIGNE ENABLE;
ALTER TRIGGER SYC_UPDATE_LIGNE ENABLE;
