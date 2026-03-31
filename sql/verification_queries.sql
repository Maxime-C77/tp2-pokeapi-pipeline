-- ============================================================
-- TP2 - Requêtes SQL de contrôle
-- ============================================================

-- 1. Nombre total de Pokémon chargés
SELECT COUNT(*) AS total_pokemon_charges FROM pokemon;

-- 2. Nombre de Pokémon sans image officielle
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

-- 6. Vérification de la table ingestion_runs
SELECT run_id, source, started_at, finished_at, status,
       records_received, records_inserted
FROM ingestion_runs
ORDER BY run_id DESC
LIMIT 5;

-- 7. Top 10 Pokémon par base_experience
SELECT pokemon_id, pokemon_name, base_experience, main_type
FROM pokemon
WHERE base_experience IS NOT NULL
ORDER BY base_experience DESC
LIMIT 10;


-- ============================================================
-- TP Data Lake - Requêtes SQL de vérification
-- ============================================================

-- 8. Nombre de fichiers stockés dans MinIO (référencés en base)
SELECT COUNT(*) AS total_fichiers FROM pokemon_files;

-- 9. Répartition par type de fichier
SELECT file_type, COUNT(*) AS nombre
FROM pokemon_files
GROUP BY file_type
ORDER BY nombre DESC;

-- 10. Répartition par bucket
SELECT bucket_name, COUNT(*) AS nombre
FROM pokemon_files
GROUP BY bucket_name
ORDER BY nombre DESC;

-- 11. Pokémon avec leurs fichiers associés
SELECT p.pokemon_name, pf.file_name, pf.bucket_name, pf.file_type
FROM pokemon p
JOIN pokemon_files pf ON p.pokemon_id = pf.pokemon_id
LIMIT 10;

-- 12. Log des ingestions de fichiers
SELECT log_id, file_name, bucket_name, source, status, processed_at
FROM file_ingestion_log
ORDER BY processed_at DESC
LIMIT 10;

-- 13. Pokémon sans fichier associé
SELECT p.pokemon_id, p.pokemon_name
FROM pokemon p
LEFT JOIN pokemon_files pf ON p.pokemon_id = pf.pokemon_id
WHERE pf.file_id IS NULL
LIMIT 10;

-- 14. Taille totale des fichiers par bucket
SELECT bucket_name,
       COUNT(*) AS nb_fichiers,
       SUM(file_size_bytes) AS taille_totale_bytes,
       ROUND(SUM(file_size_bytes) / 1024.0, 2) AS taille_totale_kb
FROM pokemon_files
GROUP BY bucket_name;