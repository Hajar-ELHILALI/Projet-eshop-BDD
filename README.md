# Projet EShop — Base de données distribuée (Oracle)

Projet de module *Bases de données réparties* : **fragmentation horizontale**, **procédures stockées PL/SQL**, **réplication multi-maître par triggers**, **optimisation de requêtes** et **requête distribuée**, le tout sur Oracle XE 21c en Docker.

---

## 1. Architecture

```
                 ┌──────────────────────────────────────────┐
                 │                eshop-net                   │
                 │                                            │
   1524 ───►  ┌──┴───────────┐   push (triggers SYC_*)   ┌────┴──────┐
              │  db-master    │ ────────────────────────► │ db-site1  │ ◄── 1522
              │  eshop_admin  │ ◄──────────────────────── │ eshop_…1  │
              │  (jeu COMPLET)│   push retour + CTAS pull  └────┬──────┘
              │               │                                │ route
              │               │ ────────────────────────► ┌────┴──────┐
              │               │ ◄──────────────────────── │ db-site2  │ ◄── 1523
              └──┬────────────┘                            │ eshop_…2  │
                 │  pull (vues matérialisées)              └───────────┘
   1525 ───►  ┌──┴───────────┐
              │  db-backup    │  copie complète du master (REFRESH /5min)
              └──────────────┘
```

| Nœud | Conteneur | Port hôte | Schéma | Rôle |
|---|---|---|---|---|
| Master (global) | `eshop-master` | **1524** | `eshop_admin` | Jeu de données complet + distribution |
| Site 1 | `eshop-site1` | **1522** | `eshop_site1` | Fragment **R1** (cat 50, qté > 100) |
| Site 2 | `eshop-site2` | **1523** | `eshop_site2` | Fragment **R2** (cat 35, qté > 50) |
| Backup | `eshop-backup` | **1525** | `eshop_backup` | Sauvegarde (vues matérialisées) |

Service Oracle : `XEPDB1` · Mot de passe applicatif : `EshopPassword123` · Compte connecteur : `eshop_link` / `LinkPwd123`.

---

## 2. Fragmentation (scénario 1)

| Fragment | Site | Règle |
|---|---|---|
| R1 | Site 1 | `idcateg = 50 AND quantite > 100` |
| R2 | Site 2 | `idcateg = 35 AND quantite > 50` |

Chaque site contient **uniquement** les lignes de commande de sa règle, plus les `produits/commandes/clients` **dérivés** (ceux référencés par ces lignes) → intégrité référentielle garantie par construction.

---

## 3. Flux de données

- **Chargement initial = PULL (CTAS)** : chaque site démarre *après* le master (`depends_on`) et tire son fragment via `CREATE TABLE … AS SELECT … @link_central`. Les triggers de distribution du master sont **désactivés pendant le seed** pour ne pas pousser vers des sites pas encore prêts.
- **Écritures courantes = PUSH (triggers, multi-maître)** : un `INSERT/UPDATE/DELETE` sur **n'importe quel nœud** est propagé :
  - Master → site concerné (`SYC_INSERT/DELETE/UPDATE_LIGNE`).
  - Site → Master, et routage Site ↔ Site (`SYC_*_LIGNE_SITEx`).
  - Anti-boucle via le paquet `pkg_synchro.is_replicating`.
  - Rapatriement automatique des parents manquants via `TRG_PULL_PARENTS_SITEx`.

> Le point d'entrée utilisateur est un **INSERT direct** sur la table du fragment (c'est lui qui déclenche les triggers). Les procédures `insertligne/deleteligne/updateligne` sont les **cibles de réplication** appelées entre nœuds (elles posent `is_replicating=TRUE` pour ne pas reboucler).

---

## 4. Schéma d'identifiants (anti-collision multi-maître)

Chaque nœud génère ses IDs dans une **voie distincte** (offset modulo 3) :

| Nœud | Voie (mod 3) | Suite |
|---|---|---|
| Master | 1 | 1, 4, 7, … |
| Site 1 | 2 | 2, 5, 8, … |
| Site 2 | 0 | 3, 6, 9, … |

Les séquences sont positionnées **au-delà des IDs déjà chargés** (CTAS / seed) tout en restant dans leur voie → deux nœuds ne peuvent jamais produire le même ID.

---

## 5. Sécurité

- **Liens privés** (propriété du schéma), pas `PUBLIC` → un autre compte ne peut pas les emprunter.
- **Compte connecteur `eshop_link`** à *moindre privilège* : uniquement `SELECT` sur les 4 tables et `EXECUTE` sur les 3 procédures, via des synonymes. Si le mot de passe d'un lien fuit, l'impact est limité à ces opérations.

---

## 6. Démarrer

### Configuration — variables d'environnement (`.env`)

Les identifiants, schémas et ports sont externalisés dans un fichier **`.env`** à la racine, lu automatiquement par Docker Compose. Ce fichier **n'est pas versionné** (voir `.gitignore`) ; un modèle **`.env.example`** est fourni dans le dépôt.

```bash
cp .env.example .env     # puis ajustez les valeurs si besoin
```

| Variable | Description | Valeur par défaut |
|---|---|---|
| `ORACLE_PASSWORD` | Mot de passe SYS (admin du conteneur) | `SysPassword123` |
| `APP_USER_PASSWORD` | Mot de passe des comptes applicatifs | `EshopPassword123` |
| `LINK_PASSWORD` | Mot de passe du connecteur `eshop_link` | `LinkPwd123` |
| `MASTER_USER` / `SITE1_USER` / `SITE2_USER` / `BACKUP_USER` | Schéma de chaque nœud | `eshop_admin`, `eshop_site1`, … |
| `MASTER_PORT` / `SITE1_PORT` / `SITE2_PORT` / `BACKUP_PORT` | Ports exposés sur l'hôte | `1524` / `1522` / `1523` / `1525` |
| `TNS_ADMIN` | Répertoire TNS dans les conteneurs | `/opt/oracle/network/admin` |

> ⚠️ Si vous changez `APP_USER_PASSWORD` ou `LINK_PASSWORD`, gardez la **même valeur** que celle attendue par les scripts SQL d'initialisation (`CONNECT …`, `CREATE DATABASE LINK …`, `CREATE USER eshop_link …`), sinon le seed échoue.

### Lancement

```powershell
docker compose down -v          # repart de zéro (volumes inclus)
docker compose up --build -d
docker compose ps               # attendre les 4 conteneurs "healthy" (5-10 min)
```

Connexion type :
```powershell
docker exec -it eshop-master sqlplus eshop_admin/EshopPassword123@//localhost:1521/XEPDB1
docker exec -it eshop-site1  sqlplus eshop_site1/EshopPassword123@//localhost:1521/XEPDB1
```

---

## 7. Tester

**Propagation depuis le master** :
```powershell
docker exec -it eshop-master sqlplus eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 @/queries/test_propagation.sql
```

**Propagation depuis un site** :
```powershell
Get-Content scripts\global-queries\test_site_origin.sql | `
  docker exec -i eshop-site1 sqlplus eshop_site1/EshopPassword123@//localhost:1521/XEPDB1
```

Sortie attendue : des lignes `OK | …`. Un `FAIL | …` indique un chemin de propagation cassé.

**Consulter les erreurs de synchronisation tracées** (sur un site) :
```sql
SELECT date_err, contexte, id_ligne, message FROM sync_errors ORDER BY date_err DESC;
```

---

## 8. Livrables d'analyse (BDD globale)

```powershell
# Q5 : nb de commandes par client en 2026 + EXPLAIN PLAN avant/après index
docker exec -it eshop-master sqlplus eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 @/queries/Q5_query_analysis.sql

# Q6 : chiffre d'affaires par catégorie en 2026 (somme des 2 sites via DB links)
docker exec -it eshop-master sqlplus eshop_admin/EshopPassword123@//localhost:1521/XEPDB1 @/queries/Q6_distributed_query.sql
```

---

## 9. Inventaire des scripts

| Dossier | Fichier | Rôle |
|---|---|---|
| `scripts/master` | `01` liens privés · `02` schéma+seq · `03` synonymes · `04` package · `05` procédures · `06` triggers SYC · `06b` connecteur · `07` seed (+ repositionnement séquences) | Base globale |
| `scripts/site1` `scripts/site2` | `01` liens · `02` **CTAS fragment** + séquences · `03` synonymes · `04` package · `04b` log erreurs · `05` procédures · `06` triggers · `07` connecteur | Fragments |
| `scripts/backup` | `01` lien · `02` vues matérialisées | Sauvegarde |
| `scripts/global-queries` | `Q5`, `Q6`, `test_propagation`, `test_site_origin` | Analyse + tests |

---

