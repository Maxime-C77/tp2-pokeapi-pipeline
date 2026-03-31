-- 1. Nombre total de Pokémon chargés
SELECT COUNT(*) AS total_pokemon_charges
FROM pokemon;

-- 2. Nombre de Pokémon sans image officielle (artwork)
SELECT COUNT(*) AS pokemon_sans_artwork
FROM pokemon
WHERE has_official_artwork = FALSE;

-- 3. Nombre de Pokémon sans sprite frontal
SELECT COUNT(*) AS pokemon_sans_sprite
FROM pokemon
WHERE has_front_sprite = FALSE;

-- 4. Répartition par type principal
SELECT main_type,
       COUNT(*) AS nombre,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pourcentage
FROM pokemon
GROUP BY main_type
ORDER BY nombre DESC;

-- 5. Pokémon dont le nom est vide ou manquant
SELECT pokemon_id, pokemon_name
FROM pokemon
WHERE pokemon_name IS NULL
   OR TRIM(pokemon_name) = '';

-- 6. (Bonus) Vérification de la table ingestion_runs
SELECT run_id, source, started_at, finished_at, status,
       records_received, records_inserted
FROM ingestion_runs
ORDER BY run_id DESC
LIMIT 5;

-- 7. (Bonus) Top 10 Pokémon par base_experience
SELECT pokemon_id, pokemon_name, base_experience, main_type
FROM pokemon
WHERE base_experience IS NOT NULL
ORDER BY base_experience DESC
LIMIT 10;