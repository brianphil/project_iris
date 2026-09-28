-- Deterministic fixture set: one country (IE), one region, small enough to
-- eyeball. Coordinates are approximate points/polygons around Athy, Co.
-- Kildare, IE -- chosen because it sits near both midlands peatland and grid
-- infrastructure, which is representative of the BESS + peatland pilot.

BEGIN;

INSERT INTO iris_core.source_run (source_id, country_code, source_name, source_date, run_completed_at, params)
VALUES ('seed_fixture_v1', 'IE', 'iris_seed_fixture', '2026-01-15', now(), '{"loader": "seed.sql"}'::jsonb);

INSERT INTO iris_core.parcel (country_code, region_code, parcel_ref, geom, area_m2, source_id, source_date)
VALUES
    ('IE', 'IE-KE', 'PARCEL-001',
     ST_GeomFromText('MULTIPOLYGON(((-6.995 52.995, -6.990 52.995, -6.990 52.990, -6.995 52.990, -6.995 52.995)))', 4326),
     198000,
     'seed_fixture_v1', '2026-01-15'),
    ('IE', 'IE-KE', 'PARCEL-002',
     ST_GeomFromText('MULTIPOLYGON(((-6.985 52.988, -6.980 52.988, -6.980 52.983, -6.985 52.983, -6.985 52.988)))', 4326),
     176000,
     'seed_fixture_v1', '2026-01-15');

INSERT INTO iris_core.substation (country_code, region_code, substation_ref, name, voltage_kv, capacity_mva, geom, source_id, source_date)
VALUES
    ('IE', 'IE-KE', 'SUB-001', 'Athy 110kV', 110, 40,
     ST_GeomFromText('POINT(-6.992 52.992)', 4326),
     'seed_fixture_v1', '2026-01-15');

INSERT INTO iris_core.peatland (country_code, region_code, peatland_ref, peat_depth_class, geom, source_id, source_date)
VALUES
    ('IE', 'IE-KE', 'PEAT-001', 'deep',
     ST_GeomFromText('MULTIPOLYGON(((-6.998 53.000, -6.988 53.000, -6.988 52.993, -6.998 52.993, -6.998 53.000)))', 4326),
     'seed_fixture_v1', '2026-01-15');

INSERT INTO iris_core.screening_layer (country_code, region_code, parcel_id, layer_type, score, geom, attributes, source_id, source_date)
SELECT 'IE', 'IE-KE', p.id, 'bess_suitability', 0.82, NULL,
       jsonb_build_object('nearest_substation_ref', 'SUB-001', 'distance_m', 550),
       'seed_fixture_v1', '2026-01-15'
FROM iris_core.parcel p WHERE p.parcel_ref = 'PARCEL-001';

INSERT INTO iris_core.screening_layer (country_code, region_code, parcel_id, layer_type, score, geom, attributes, source_id, source_date)
SELECT 'IE', 'IE-KE', p.id, 'peatland_proximity', 0.61,
       ST_Intersection(p.geom, pl.geom),
       jsonb_build_object('overlapping_peatland_ref', 'PEAT-001'),
       'seed_fixture_v1', '2026-01-15'
FROM iris_core.parcel p, iris_core.peatland pl
WHERE p.parcel_ref = 'PARCEL-001' AND pl.peatland_ref = 'PEAT-001';

INSERT INTO iris_core.evidence (country_code, entity_type, entity_id, note, geom, source_id, source_date)
SELECT 'IE', 'parcel', p.id, 'Cadastral boundary digitised from seed fixture geometry.', NULL,
       'seed_fixture_v1', '2026-01-15'
FROM iris_core.parcel p WHERE p.parcel_ref = 'PARCEL-001';

COMMIT;
