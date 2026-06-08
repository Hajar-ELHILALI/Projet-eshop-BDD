-- ============================================================
-- Q6 - REQUETE DISTRIBUEE : chiffre d'affaires par categorie
--      en 2026, en sommant les contributions des deux sites.
-- ------------------------------------------------------------
-- CA d'une ligne = quantite * prixunitaire * (1 - remise)
--
-- UNION ALL (et non UNION) : les deux fragments sont DISJOINTS
-- par construction (Site 1 = cat 50, Site 2 = cat 35), donc
-- aucun dedoublonnage necessaire et on evite le tri de UNION.
--
-- Executer sur le master :
--   docker exec -it eshop-master sqlplus ^
--     eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 ^
--     "@/queries/Q6_distributed_query.sql"
-- ============================================================
SET LINESIZE 200
SET PAGESIZE 100
-- autorise les lignes vides a l'interieur d'une requete
SET SQLBLANKLINES ON
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

SELECT
    idcateg,
    ROUND(SUM(ca_ligne), 2) AS chiffre_affaires_2026
FROM (
    SELECT
        p.idcateg,
        lc.quantite * p.prixunitaire * (1 - NVL(lc.remise, 0)) AS ca_ligne
    FROM   lignecommandes1 lc
    JOIN   produits1  p ON p.idproduit  = lc.idproduit
    JOIN   commandes1 c ON c.idcommande = lc.idcommande
    WHERE  c.datecommande >= DATE '2026-01-01'
    AND    c.datecommande <  DATE '2027-01-01'
    UNION ALL
    SELECT
        p.idcateg,
        lc.quantite * p.prixunitaire * (1 - NVL(lc.remise, 0)) AS ca_ligne
    FROM   lignecommandes2 lc
    JOIN   produits2  p ON p.idproduit  = lc.idproduit
    JOIN   commandes2 c ON c.idcommande = lc.idcommande
    WHERE  c.datecommande >= DATE '2026-01-01'
    AND    c.datecommande <  DATE '2027-01-01'
)
GROUP BY idcateg
ORDER BY chiffre_affaires_2026 DESC;
