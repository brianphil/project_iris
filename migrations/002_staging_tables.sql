-- iris_staging: landing tables for raw loader output.
--
-- Design intent: staging mirrors the shape of core business entities but stays
-- permissive on everything except the two contracts that must never be silently
-- invented (country_code) or silently coerced (geom SRID). Staging allows:
--   * duplicate rows across repeated/overlapping loader runs (no uniqueness)
--   * invalid/unclean geometries (validity is enforced on promotion to core)
--   * a generic geometry type per table (source data shape varies by provider)
--
-- Every staging row still carries source_id/source_date/created_at so promotion
-- to iris_core can trace provenance without re-deriving it.

CREATE TABLE iris_staging.stg_parcel (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    parcel_ref   text,
    geom         geometry(Geometry, 4326),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_id    text NOT NULL,
    source_date  date,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE iris_staging.stg_substation (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    substation_ref text,
    name         text,
    voltage_kv   numeric,
    capacity_mva numeric,
    geom         geometry(Geometry, 4326),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_id    text NOT NULL,
    source_date  date,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE iris_staging.stg_peatland (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    peatland_ref text,
    peat_depth_class text,
    geom         geometry(Geometry, 4326),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_id    text NOT NULL,
    source_date  date,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE iris_staging.stg_screening_layer (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    parcel_ref   text,
    layer_type   text,
    score        numeric,
    uncertainty  text,
    geom         geometry(Geometry, 4326),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_id    text NOT NULL,
    source_date  date,
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_stg_parcel_country ON iris_staging.stg_parcel (country_code);
CREATE INDEX ix_stg_substation_country ON iris_staging.stg_substation (country_code);
CREATE INDEX ix_stg_peatland_country ON iris_staging.stg_peatland (country_code);
CREATE INDEX ix_stg_screening_layer_country ON iris_staging.stg_screening_layer (country_code);
