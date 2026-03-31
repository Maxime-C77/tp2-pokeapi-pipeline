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

-- Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_pokemon_main_type ON pokemon(main_type);
CREATE INDEX IF NOT EXISTS idx_pokemon_run_id ON pokemon(run_id);