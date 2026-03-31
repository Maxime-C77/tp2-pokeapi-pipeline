-- ============================================================
-- TP2 + TP Data Lake - Script d'initialisation complet
-- Crée les 4 tables nécessaires aux deux TPs
-- ============================================================

-- ==================== TABLES TP2 ====================

-- Table de suivi des exécutions d'ingestion
CREATE TABLE IF NOT EXISTS ingestion_runs (
    run_id          SERIAL PRIMARY KEY,
    source          VARCHAR(100) NOT NULL DEFAULT 'pokeapi',
    started_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    finished_at     TIMESTAMP,
    status          VARCHAR(20) NOT NULL DEFAULT 'running'
                    CHECK (status IN ('running', 'success', 'failed')),
    records_received INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0
);

-- Table des Pokémon
CREATE TABLE IF NOT EXISTS pokemon (
    pokemon_id              INTEGER PRIMARY KEY,
    pokemon_name            VARCHAR(100) NOT NULL,
    base_experience         INTEGER,
    height                  INTEGER,
    weight                  INTEGER,
    main_type               VARCHAR(50),
    has_official_artwork    BOOLEAN DEFAULT FALSE,
    has_front_sprite        BOOLEAN DEFAULT FALSE,
    source_last_updated_at  TIMESTAMP,
    ingested_at             TIMESTAMP NOT NULL DEFAULT NOW(),
    run_id                  INTEGER REFERENCES ingestion_runs(run_id)
);

-- ==================== TABLES DATA LAKE ====================

-- Table des fichiers stockés dans MinIO
CREATE TABLE IF NOT EXISTS pokemon_files (
    file_id             SERIAL PRIMARY KEY,
    pokemon_id          INTEGER REFERENCES pokemon(pokemon_id),
    bucket_name         VARCHAR(100) NOT NULL,
    object_key          VARCHAR(500) NOT NULL,
    file_name           VARCHAR(255) NOT NULL,
    file_type           VARCHAR(50) NOT NULL,
    file_size_bytes     INTEGER,
    mime_type           VARCHAR(100),
    internal_url        VARCHAR(500),
    created_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Table de log des ingestions de fichiers
CREATE TABLE IF NOT EXISTS file_ingestion_log (
    log_id              SERIAL PRIMARY KEY,
    file_name           VARCHAR(255) NOT NULL,
    bucket_name         VARCHAR(100) NOT NULL,
    object_key          VARCHAR(500) NOT NULL,
    processed_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    source              VARCHAR(100) NOT NULL DEFAULT 'pokeapi',
    status              VARCHAR(20) NOT NULL DEFAULT 'success'
                        CHECK (status IN ('success', 'failed', 'pending')),
    error_message       TEXT
);

-- ==================== INDEX ====================

CREATE INDEX IF NOT EXISTS idx_pokemon_main_type ON pokemon(main_type);
CREATE INDEX IF NOT EXISTS idx_pokemon_run_id ON pokemon(run_id);
CREATE INDEX IF NOT EXISTS idx_pokemon_files_pokemon_id ON pokemon_files(pokemon_id);
CREATE INDEX IF NOT EXISTS idx_file_ingestion_log_status ON file_ingestion_log(status);