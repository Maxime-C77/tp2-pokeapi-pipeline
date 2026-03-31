# TP2 + TP Data Lake — PokeAPI, n8n, PostgreSQL, MinIO

## Architecture du projet

Ce projet regroupe les deux TPs : le pipeline ETL (TP2) et l'architecture Data Lake. Il utilise **n8n Community Edition** ([github.com/n8n-io/n8n](https://github.com/n8n-io/n8n)).

```
tp_pokemon_data/
├── docker-compose.yml                  # Docker : PostgreSQL + n8n + MinIO
├── .env.example                        # Variables d'environnement (modèle)
├── sql/
│   ├── init.sql                        # 4 tables (TP2 + Data Lake)
│   └── verification_queries.sql        # 14 requêtes de contrôle
├── n8n/
│   ├── workflow_tp2_pokeapi.json       # Workflow TP2 : PokeAPI → PostgreSQL
│   └── workflow_datalake.json          # Workflow Data Lake : PostgreSQL → MinIO
├── .gitignore
└── README.md
```

### Services Docker

| Service    | Image                        | Port         | Rôle                           |
|------------|------------------------------|--------------|--------------------------------|
| PostgreSQL | postgres:16                  | 5432         | Base relationnelle             |
| n8n        | docker.n8n.io/n8nio/n8n      | 5678         | Orchestration workflows        |
| MinIO      | minio/minio                  | 9000 / 9001  | Stockage objet (S3-compatible) |

### Démarrage

```bash
cp .env.example .env
docker compose up -d
```

### Accès

- **n8n** : http://localhost:5678
- **MinIO Console** : http://localhost:9001 (minioadmin / minioadmin123)
- **PostgreSQL** : localhost:5432 (test_user / test123 / pokemon_db)

---

## TP2 — Pipeline structuré avec PokeAPI, n8n et PostgreSQL

### Partie A — Environnement

L'environnement Docker démarre 3 services. PostgreSQL et n8n sont connectés via le réseau Docker interne. Le credential PostgreSQL dans n8n utilise le host `postgres` (nom du service Docker).

### Partie B — Tables

**Table `ingestion_runs`** : suivi des exécutions (source, dates, statut, compteurs).

**Table `pokemon`** : données structurées des Pokémon (id, nom, base_experience, height, weight, main_type, has_official_artwork, has_front_sprite, timestamps, run_id).

### Partie C — Workflow n8n

```
Manual Trigger → Create Run → Fetch List → Split URLs → Fetch Detail → Transform → Insert → Update Run
```

| # | Nœud                | Type         | Description                                  |
|---|---------------------|--------------|----------------------------------------------|
| 1 | Manual Trigger      | Trigger      | Déclenche le pipeline                        |
| 2 | Create Ingestion Run| PostgreSQL   | INSERT dans ingestion_runs                   |
| 3 | Fetch Pokemon List  | HTTP Request | GET pokeapi.co/api/v2/pokemon?limit=150      |
| 4 | Split Pokemon URLs  | Code (JS)    | Extrait les URLs individuelles               |
| 5 | Fetch Pokemon Detail| HTTP Request | Récupère le JSON complet par Pokémon         |
| 6 | Transform Data      | Code (JS)    | Renommage, nettoyage, indicateurs            |
| 7 | Insert into Pokemon | PostgreSQL   | INSERT dans la table pokemon                 |
| 8 | Update Ingestion Run| PostgreSQL   | UPDATE status, compteurs, date fin           |

**Transformations appliquées :**
- Renommage : id → pokemon_id, name → pokemon_name
- Valeurs manquantes : base_experience → null si absent, main_type → 'unknown'
- Indicateurs : has_official_artwork, has_front_sprite (booléens)
- Métadonnées : ingested_at, run_id

### Partie D — Chargement

L'insertion et la traçabilité sont intégrées au workflow via les nœuds PostgreSQL.

### Partie E — Requêtes de contrôle

1. Nombre total de Pokémon chargés
2. Pokémon sans artwork officiel
3. Pokémon sans sprite frontal
4. Répartition par type principal
5. Pokémon au nom vide ou manquant
6. Vérification de ingestion_runs
7. Top 10 par base_experience

### Partie F — Justification Data Warehouse

L'architecture relève d'une logique Data Warehouse car elle suit un **pipeline ETL** classique : les données sont extraites de la PokeAPI, transformées (renommage, nettoyage, création d'indicateurs) puis chargées dans PostgreSQL. La **source et la destination sont séparées**, les données brutes étant restructurées dans un schéma dénormalisé orienté analyse. Enfin, la table `ingestion_runs` assure la **traçabilité de chaque chargement**, rendant le pipeline reproductible et auditable — des principes fondamentaux du Data Warehouse.

---

## TP Data Lake — MinIO + PostgreSQL + n8n

### Partie A — Stockage objet MinIO

MinIO est ajouté au docker-compose comme service S3-compatible. Trois buckets sont créés :

| Bucket          | Contenu                                      |
|-----------------|----------------------------------------------|
| raw-pokemon     | Fichiers JSON bruts de la PokeAPI             |
| pokemon-images  | Images officielles et sprites des Pokémon     |
| reports         | Rapports CSV/JSON générés                     |

### Partie B — Tables enrichies

**Table `pokemon_files`** : référence les fichiers stockés dans MinIO (file_id, pokemon_id, bucket_name, object_key, file_name, file_type, file_size_bytes, mime_type, internal_url, created_at).

**Table `file_ingestion_log`** : trace chaque ingestion de fichier (file_name, bucket, object_key, date, source, statut, message d'erreur).

### Partie C — Workflow n8n Data Lake

```
Manual Trigger → Get Pokemon from DB → Fetch Pokemon JSON → Prepare Files → Upload to MinIO → Insert pokemon_files → Log Ingestion
```

| # | Nœud                | Type         | Description                                  |
|---|---------------------|--------------|----------------------------------------------|
| 1 | Manual Trigger      | Trigger      | Déclenche le pipeline                        |
| 2 | Get Pokemon from DB | PostgreSQL   | SELECT 10 Pokémon depuis la base             |
| 3 | Fetch Pokemon JSON  | HTTP Request | GET le JSON complet depuis PokeAPI           |
| 4 | Prepare Files       | Code (JS)    | Prépare les métadonnées pour upload          |
| 5 | Upload to MinIO     | S3           | Upload du JSON dans raw-pokemon              |
| 6 | Insert pokemon_files| PostgreSQL   | Enregistre les métadonnées en base           |
| 7 | Log Ingestion       | PostgreSQL   | Trace l'ingestion dans file_ingestion_log    |

### Partie D — Réponse rédigée : logique Data Lake / Lakehouse

L'architecture obtenue est plus proche d'une logique Data Lake / Lakehouse que celle du TP précédent car elle introduit MinIO comme couche de stockage objet complémentaire à la base relationnelle. MinIO permet de conserver les données brutes (fichiers JSON complets de la PokeAPI) dans leur format d'origine, sans transformation ni perte d'information. Cette conservation du brut est essentielle : elle permet de retraiter les données ultérieurement si les besoins analytiques évoluent, sans devoir réinterroger la source. La base PostgreSQL ne stocke pas les fichiers eux-mêmes mais uniquement leurs métadonnées (nom, bucket, clé objet, type, taille), ce qui sépare clairement le stockage lourd du catalogage structuré. Cette approche est plus riche qu'une simple base relationnelle car elle combine le meilleur des deux mondes : le stockage scalable et flexible de MinIO pour les données non structurées, et la puissance de requêtage de PostgreSQL pour les données structurées et les métadonnées. On retrouve ainsi le principe du Lakehouse, où une couche de gouvernance (tables `pokemon_files` et `file_ingestion_log`) se superpose à un stockage brut distribué.

---

## Références

- **n8n Community Edition** : https://github.com/n8n-io/n8n
- **n8n Hosting** : https://github.com/n8n-io/n8n-hosting
- **MinIO** : https://min.io/
- **PokeAPI** : https://pokeapi.co/
- **n8n Docker Docs** : https://docs.n8n.io/hosting/installation/docker/