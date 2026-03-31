# TP2 — Pipeline structuré avec PokeAPI, n8n et PostgreSQL

## Architecture du projet

Ce projet utilise **n8n Community Edition** (open source, [github.com/n8n-io/n8n](https://github.com/n8n-io/n8n)) avec la configuration Docker officielle inspirée du repo [n8n-io/n8n-hosting](https://github.com/n8n-io/n8n-hosting/tree/main/docker-compose/withPostgres).

```
tp2-pokeapi-pipeline/
├── docker-compose.yml              # Orchestration Docker (PostgreSQL + n8n Community)
├── .env                            # Variables d'environnement (credentials, timezone)
├── init-data.sh                    # Script init PostgreSQL (création user non-root)
├── sql/
│   ├── init.sql                    # Création des tables (ingestion_runs + pokemon)
│   └── verification_queries.sql    # 7 requêtes SQL de contrôle
├── n8n/
│   └── workflow_pokeapi_pipeline.json  # Export du workflow n8n
├── .gitignore
└── README.md
```

---

## Partie A — Mise en place de l'environnement

### Prérequis
- Docker & Docker Compose installés ([docs Docker](https://docs.docker.com/get-docker/))

### Configuration

1. Cloner ce repo :
```bash
git clone https://github.com/<VOTRE_USERNAME>/tp2-pokeapi-pipeline.git
cd tp2-pokeapi-pipeline
```

2. Modifier les mots de passe dans `.env` :
```bash
# Éditer le fichier .env AVANT le premier démarrage
nano .env
```

### Démarrage

```bash
docker compose up -d
```

> **Note :** Le `docker-compose.yml` utilise l'image officielle `docker.n8n.io/n8nio/n8n` (Community Edition). Sans clé de licence, n8n fonctionne automatiquement en édition communautaire gratuite.

### Vérification

```bash
# Vérifier que les conteneurs tournent
docker ps

# Tester la connexion PostgreSQL
docker exec -it tp2_postgres psql -U pokemon_user -d pokemon_db -c "SELECT 1;"

# Vérifier que les tables sont créées
docker exec -it tp2_postgres psql -U pokemon_user -d pokemon_db -c "\dt"
```

**Accès aux services :**
- **n8n** : http://localhost:5678 (créer un compte au premier accès)
- **PostgreSQL** : localhost:5432 (pokemon_user / pokemon_pass / pokemon_db)

---

## Partie B — Préparation de la base

Les tables sont créées automatiquement via `sql/init.sql` au premier démarrage de PostgreSQL (monté dans `docker-entrypoint-initdb.d`).

### Table `ingestion_runs`

| Colonne           | Type         | Description                        |
|-------------------|--------------|------------------------------------|
| run_id            | SERIAL PK    | Identifiant unique de l'exécution  |
| source            | VARCHAR(100) | Source des données (pokeapi)       |
| started_at        | TIMESTAMP    | Date/heure de début                |
| finished_at       | TIMESTAMP    | Date/heure de fin                  |
| status            | VARCHAR(20)  | running / success / failed         |
| records_received  | INTEGER      | Nombre d'enregistrements reçus     |
| records_inserted  | INTEGER      | Nombre d'enregistrements insérés   |

### Table `pokemon`

| Colonne                 | Type         | Description                           |
|-------------------------|--------------|---------------------------------------|
| pokemon_id              | INTEGER PK   | ID du Pokémon (depuis l'API)          |
| pokemon_name            | VARCHAR(100) | Nom du Pokémon                        |
| base_experience         | INTEGER      | Expérience de base                    |
| height                  | INTEGER      | Taille (en décimètres)                |
| weight                  | INTEGER      | Poids (en hectogrammes)               |
| main_type               | VARCHAR(50)  | Type principal (1er type)             |
| has_official_artwork    | BOOLEAN      | Artwork officiel disponible ?         |
| has_front_sprite        | BOOLEAN      | Sprite frontal disponible ?           |
| source_last_updated_at  | TIMESTAMP    | Date de dernière mise à jour source   |
| ingested_at             | TIMESTAMP    | Date d'ingestion en base              |
| run_id                  | INTEGER FK   | Référence vers ingestion_runs         |

---

## Partie C — Workflow n8n

### Import du workflow

1. Ouvrir n8n à http://localhost:5678
2. Créer un compte au premier accès
3. Aller dans **Workflows** → **Import from file**
4. Sélectionner `n8n/workflow_pokeapi_pipeline.json`
5. Configurer le credential PostgreSQL :
   - Host: `postgres` (nom du service Docker, pas `localhost`)
   - Port: `5432`
   - Database: `pokemon_db`
   - User: `pokemon_user`
   - Password: `pokemon_pass`
6. Exécuter le workflow

### Description des nœuds

Le workflow se compose de **8 nœuds** exécutés séquentiellement :

| # | Nœud | Type | Description |
|---|------|------|-------------|
| 1 | Manual Trigger | Trigger | Déclenche le pipeline manuellement |
| 2 | Create Ingestion Run | PostgreSQL | INSERT dans ingestion_runs, retourne run_id |
| 3 | Fetch Pokemon List | HTTP Request | GET pokeapi.co/api/v2/pokemon?limit=150 |
| 4 | Split Pokemon URLs | Code (JS) | Extrait les URLs individuelles |
| 5 | Fetch Pokemon Detail | HTTP Request | Récupère le JSON complet par Pokémon |
| 6 | Transform Data | Code (JS) | Renommage, nettoyage, indicateurs |
| 7 | Insert into Pokemon | PostgreSQL | INSERT dans la table pokemon |
| 8 | Update Ingestion Run | PostgreSQL | UPDATE status, compteurs, date fin |

### Transformations appliquées (nœud 6)

- **Renommage** : `id` → `pokemon_id`, `name` → `pokemon_name`
- **Valeurs manquantes** : `base_experience` → `null` si absent, `main_type` → `'unknown'` si aucun type
- **Indicateur `has_official_artwork`** : vérifie `sprites.other.official-artwork.front_default`
- **Indicateur `has_front_sprite`** : vérifie `sprites.front_default`
- **Métadonnées** : ajout de `ingested_at` (NOW) et `run_id`

---

## Partie D — Chargement en base

Le chargement est intégré au workflow n8n :
- Le nœud **Insert into Pokemon** insère les 150 enregistrements transformés.
- Le nœud **Update Ingestion Run** met à jour `ingestion_runs` avec le bilan.

### Vérification rapide

```sql
SELECT COUNT(*) FROM pokemon;  -- Doit retourner 150
SELECT * FROM ingestion_runs ORDER BY run_id DESC LIMIT 1;
```

---

## Partie E — Requêtes SQL de contrôle

Les 5 requêtes obligatoires (+ 2 bonus) sont dans `sql/verification_queries.sql` :

1. **Nombre total de Pokémon chargés** → `SELECT COUNT(*) FROM pokemon;`
2. **Pokémon sans artwork officiel** → filtre sur `has_official_artwork = FALSE`
3. **Pokémon sans sprite frontal** → filtre sur `has_front_sprite = FALSE`
4. **Répartition par type principal** → `GROUP BY main_type` avec pourcentage
5. **Pokémon au nom vide ou manquant** → `WHERE pokemon_name IS NULL OR TRIM(...) = ''`

---

## Partie F — Justification : logique Data Warehouse

Cette architecture relève d'une logique **Data Warehouse** pour les raisons suivantes :

1. **Pipeline ETL structuré** : le workflow suit le schéma classique Extract-Transform-Load. Les données brutes sont extraites d'une source externe (PokeAPI), transformées, puis chargées dans PostgreSQL.

2. **Séparation source / destination** : les données de la PokeAPI ne sont pas consommées directement. Elles sont copiées et restructurées dans une base dédiée, qui joue le rôle d'entrepôt analytique.

3. **Traçabilité des chargements** : la table `ingestion_runs` implémente un mécanisme d'audit (date, statut, volumes) propre aux architectures DWH.

4. **Schéma orienté analyse** : la table `pokemon` est dénormalisée (type principal directement inclus, indicateurs booléens précalculés) pour faciliter les requêtes analytiques sans jointures complexes.

5. **Reproductibilité** : le pipeline peut être rejoué à tout moment. La structure est conçue pour accueillir des exécutions successives traçables, principe fondamental des architectures DWH modernes.

---

## Références

- **n8n Community Edition** : https://github.com/n8n-io/n8n
- **n8n Hosting (Docker configs)** : https://github.com/n8n-io/n8n-hosting
- **PokeAPI** : https://pokeapi.co/
- **n8n Docker Docs** : https://docs.n8n.io/hosting/installation/docker/