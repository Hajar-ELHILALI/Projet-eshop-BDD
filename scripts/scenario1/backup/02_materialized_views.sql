-- ============================================================
-- BASE DE SECOURS — Réplication COMPLETE par vues matérialisées
-- ------------------------------------------------------------
-- On copie l'intégralité des 4 tables du Master. Comme le Master
-- contient déjà toutes les données (les sites n'en ont que des
-- fragments), répliquer le Master = sauvegarder tout le système.
--
-- REFRESH COMPLETE : recopie totale, aucune MATERIALIZED VIEW LOG
-- requise côté Master (réplication découplée, zéro impact prod).
-- Rafraîchissement automatique toutes les 5 minutes.
--
-- NB : le lien 'link_central' est désormais PRIVE (propriété de
-- eshop_backup). Il faut donc créer les MV EN TANT QUE eshop_backup
-- pour que '@link_central' se résolve (SYS ne voit pas un lien privé).
-- ============================================================
ALTER SESSION SET CONTAINER = XEPDB1;

-- Droits accordés par SYS au propriétaire des vues matérialisées
GRANT CREATE MATERIALIZED VIEW TO eshop_backup;  -- pas inclus dans RESOURCE
GRANT CREATE JOB              TO eshop_backup;    -- pour le refresh automatique

-- On devient eshop_backup (propriétaire du lien privé et des MV)
CONNECT eshop_backup/EshopPassword123@//localhost:1521/XEPDB1

-- ------------------------------------------------------------
-- 1. CLIENTS
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_clients
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM clients@link_central;

-- ------------------------------------------------------------
-- 2. PRODUITS
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_produits
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM produits@link_central;

-- ------------------------------------------------------------
-- 3. COMMANDES
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_commandes
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM commandes@link_central;

-- ------------------------------------------------------------
-- 4. LIGNECOMMANDES
-- ------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_lignecommandes
REFRESH COMPLETE
START WITH SYSDATE NEXT SYSDATE + 5/1440
AS SELECT * FROM lignecommandes@link_central;
