-- Manual verification queries for the IRIS pilot schema.
-- Run after `make rebuild` (or `python -m iris.migrate rebuild`):
--   make verify
-- or:
--   psql "$DATABASE_URL" -f verification/verify.sql

\echo '--- 1. Canonical columns exist on every core table with the required names ---'
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'iris_core'
  AND column_name IN ('geom', 'country_code', 'region_code', 'source_id', 'source_date', 'created_at')
ORDER BY table_name, column_name;

\echo '--- 2. No column in iris_core is literally named "geometry" ---'
SELECT count(*) AS should_be_zero
FROM information_schema.columns
WHERE table_schema = 'iris_core' AND column_name = 'geometry';

\echo '--- 3. country_code cannot be null (expect this INSERT to fail with a not-null violation) ---'
DO $$
BEGIN
    BEGIN
        INSERT INTO iris_core.parcel (country_code, region_code, parcel_ref, geom, source_id, source_date)
        VALUES (NULL, 'IE-KE', 'PARCEL-BAD', ST_GeomFromText('MULTIPOLYGON(((-6.9 52.9,-6.8 52.9,-6.8 52.8,-6.9 52.8,-6.9 52.9)))', 4326), 'seed_fixture_v1', '2026-01-15');
        RAISE EXCEPTION 'expected a not-null violation on country_code but insert succeeded';
    EXCEPTION WHEN not_null_violation THEN
        RAISE NOTICE 'OK: country_code NOT NULL constraint enforced (%).', SQLERRM;
    END;
END $$;

\echo '--- 4. Spatial round trip: write a point, read it back via WKT and via geography distance ---'
BEGIN;
    INSERT INTO iris_core.substation (country_code, region_code, substation_ref, name, voltage_kv, geom, source_id, source_date)
    VALUES ('IE', 'IE-KE', 'SUB-ROUNDTRIP', 'Verification Substation', 110,
            ST_GeomFromText('POINT(-6.9921 52.9921)', 4326), 'seed_fixture_v1', '2026-01-15');

    SELECT substation_ref, ST_AsText(geom) AS wkt, ST_SRID(geom) AS srid
    FROM iris_core.substation
    WHERE substation_ref = 'SUB-ROUNDTRIP';
ROLLBACK;

\echo '--- 5. Spatial predicate demonstrating the two pilot verticals: parcels within 1km of a substation, and parcels overlapping peatland ---'
SELECT p.parcel_ref, s.substation_ref,
       round(ST_Distance(p.geom::geography, s.geom::geography)) AS distance_m
FROM iris_core.parcel p
JOIN iris_core.substation s ON s.country_code = p.country_code
WHERE p.country_code = 'IE'
  AND ST_DWithin(p.geom::geography, s.geom::geography, 1000)
ORDER BY distance_m;

SELECT p.parcel_ref, pl.peatland_ref,
       round(ST_Area(ST_Intersection(p.geom, pl.geom)::geography)) AS overlap_m2
FROM iris_core.parcel p
JOIN iris_core.peatland pl ON pl.country_code = p.country_code
WHERE p.country_code = 'IE'
  AND ST_Intersects(p.geom, pl.geom);

\echo '--- 6. Index usage: force index-only planning and confirm the GIST index is chosen for a spatial predicate ---'
SET enable_seqscan = off;
EXPLAIN (COSTS OFF)
SELECT id FROM iris_core.parcel
WHERE ST_DWithin(geom::geography, ST_GeomFromText('POINT(-6.992 52.992)', 4326)::geography, 1000);
RESET enable_seqscan;

\echo '--- 7. Country-scoped unique key: the same parcel_ref is allowed in a different country ---'
BEGIN;
    INSERT INTO iris_core.source_run (source_id, country_code, source_name, source_date, run_completed_at)
    VALUES ('seed_fixture_v1', 'PT', 'iris_seed_fixture', '2026-01-15', now());

    INSERT INTO iris_core.parcel (country_code, region_code, parcel_ref, geom, source_id, source_date)
    VALUES ('PT', 'PT-11', 'PARCEL-001',
            ST_GeomFromText('MULTIPOLYGON(((-8.6 41.1,-8.5 41.1,-8.5 41.0,-8.6 41.0,-8.6 41.1)))', 4326),
            'seed_fixture_v1', '2026-01-15');

    SELECT country_code, parcel_ref FROM iris_core.parcel WHERE parcel_ref = 'PARCEL-001' ORDER BY country_code;
ROLLBACK;
