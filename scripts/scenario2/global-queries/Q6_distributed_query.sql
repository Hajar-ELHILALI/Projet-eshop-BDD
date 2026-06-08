-- ============================================================
-- SCENARIO 2 | Q6 - Requete distribuee : CA par categorie 2026
-- ------------------------------------------------------------
-- Chiffre d'affaires d'une ligne = quantite * prixunitaire * (1 - remise)
--
-- Fragmentation Scenario 2 :
--   R1 (Site 1) = sigma(quantite >= 100) : toutes categories confondues
--   R2 (Site 2) = sigma(quantite <  100) : toutes categories confondues
--
-- UNION ALL (et non UNION) : les deux fragments sont DISJOINTS
-- par construction (un idlignecommande ne peut etre que dans R1
-- ou dans R2, jamais les deux). Pas de dedoublonnage necessaire,
-- pas de tri supplementaire.
--
-- Difference avec Scenario 1 :
--   - Les deux sites peuvent contenir n'importe quelle categorie
--   - La requete reste identique dans sa structure UNION ALL
--   - L'interpretation des resultats par categorie est differente
--     (une categorie peut apparaitre dans les deux fragments)
--
-- Executer sur le master :
--   docker exec -it eshop-master sqlplus ^
--     eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 ^
--     "@/queries/Q6_distributed_query.sql"
-- ============================================================
SET LINESIZE 200
SET PAGESIZE 100
-- autorise les lignes vides a l'interieur d'une requete (sinon UNION ALL casse)
SET SQLBLANKLINES ON
ALTER SESSION SET CURRENT_SCHEMA = eshop_admin;

-- ============================================================
-- Version distribuee : agregation des deux sites
-- ============================================================
SELECT
    idcateg,
    ROUND(SUM(ca_ligne), 2) AS chiffre_affaires_2026,
    COUNT(*)                AS nb_lignes
FROM (
    -- Fragment R1 : lignes avec quantite >= 100 (Site 1)
    SELECT
        p.idcateg,
        lc.quantite * p.prixunitaire * (1 - NVL(lc.remise, 0)) AS ca_ligne
    FROM   lignecommandes1 lc
    JOIN   produits1  p ON p.idproduit  = lc.idproduit
    JOIN   commandes1 c ON c.idcommande = lc.idcommande
    WHERE  c.datecommande >= DATE '2026-01-01'
    AND    c.datecommande <  DATE '2027-01-01'

    UNION ALL

    -- Fragment R2 : lignes avec quantite < 100 (Site 2)
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
