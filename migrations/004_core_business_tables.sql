-- iris_core business entities: parcel, substation, peatland, screening_layer, evidence.
--
-- Canonical contract enforced on every table below:
--   geom          - canonical geometry column name (never "geometry"), SRID 4326
--   country_code  - NOT NULL, every business entity is country-scoped
--   region_code   - nullable sub-country key used by the one-region pilot slice
--   source_id     - NOT NULL, FK-scoped to iris_core.source_run(country_code, source_id)
--   source_date   - NOT NULL, the source snapshot date (distinct from created_at)
--   created_at    - NOT NULL, row insertion timestamp (system time, not source time)
--
-- CRS policy: all geometries are stored in EPSG:4326 (WGS84 lon/lat), matching
-- how source providers typically deliver data and avoiding lossy reprojection
-- on load. Metric operations (area, distance, buffers) that need a projected
-- CRS transform on the fly via ST_Transform at query time -- see
-- verification/verify.sql for an example. Storing a second projected geometry
-- column was considered and rejected for the pilot: it doubles write/storage
-- cost for a one-region slice where query-time ST_Transform is cheap enough.
--
-- Validity: ST_IsValid is enforced here (core), not in iris_staging, since raw
-- source geometries are allowed to be invalid until the promotion step repairs
-- them (e.g. ST_MakeValid) or rejects them.

CREATE TABLE iris_core.parcel (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    parcel_ref   text NOT NULL,
    geom         geometry(MultiPolygon, 4326) NOT NULL,
    area_m2      numeric,
    source_id    text NOT NULL,
    source_date  date NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_parcel_country_ref UNIQUE (country_code, parcel_ref),
    CONSTRAINT chk_parcel_geom_valid CHECK (ST_IsValid(geom)),
    CONSTRAINT fk_parcel_source FOREIGN KEY (country_code, source_id)
        REFERENCES iris_core.source_run (country_code, source_id)
);

CREATE TABLE iris_core.substation (
    id             bigserial PRIMARY KEY,
    country_code   text NOT NULL,
    region_code    text,
    substation_ref text NOT NULL,
    name           text,
    voltage_kv     numeric,
    capacity_mva   numeric,
    geom           geometry(Point, 4326) NOT NULL,
    source_id      text NOT NULL,
    source_date    date NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_substation_country_ref UNIQUE (country_code, substation_ref),
    CONSTRAINT chk_substation_geom_valid CHECK (ST_IsValid(geom)),
    CONSTRAINT fk_substation_source FOREIGN KEY (country_code, source_id)
        REFERENCES iris_core.source_run (country_code, source_id)
);

CREATE TABLE iris_core.peatland (
    id               bigserial PRIMARY KEY,
    country_code     text NOT NULL,
    region_code      text,
    peatland_ref     text NOT NULL,
    peat_depth_class text,
    geom             geometry(MultiPolygon, 4326) NOT NULL,
    source_id        text NOT NULL,
    source_date      date NOT NULL,
    created_at       timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_peatland_country_ref UNIQUE (country_code, peatland_ref),
    CONSTRAINT chk_peatland_geom_valid CHECK (ST_IsValid(geom)),
    CONSTRAINT fk_peatland_source FOREIGN KEY (country_code, source_id)
        REFERENCES iris_core.source_run (country_code, source_id)
);

-- screening_layer: output of a screening/inference run (e.g. BESS suitability,
-- peatland-proximity eco-point overlay) scoped to a single parcel. geom is
-- nullable because some screening outputs are attribute-only (score/uncertainty
-- derived from the parcel's own geometry, not a distinct derived shape); when a
-- screening step does produce its own derived geometry (buffer, intersection),
-- it is stored here rather than re-deriving it from parcel + peatland at read time.
CREATE TABLE iris_core.screening_layer (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    region_code  text,
    parcel_id    bigint NOT NULL REFERENCES iris_core.parcel (id),
    layer_type   text NOT NULL CHECK (layer_type IN ('bess_suitability', 'peatland_proximity', 'eco_point_estimate')),
    score        numeric,
    uncertainty  text NOT NULL DEFAULT
        'Preliminary prospecting material. Figures, eco-point estimates and site suitability are indicative and based on available source data and commercial screening assumptions. The 8 eco-points/m2 factor is the current commercial baseline, not certified compensation. Ownership, planning, grid capacity, environmental eligibility and transferability remain subject to project-specific verification. No permit, reservation or construction readiness is represented.',
    geom         geometry(Geometry, 4326),
    attributes   jsonb NOT NULL DEFAULT '{}'::jsonb,
    source_id    text NOT NULL,
    source_date  date NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_screening_layer_country_parcel_type_source
        UNIQUE (country_code, parcel_id, layer_type, source_id),
    CONSTRAINT chk_screening_layer_geom_valid CHECK (geom IS NULL OR ST_IsValid(geom)),
    CONSTRAINT fk_screening_layer_source FOREIGN KEY (country_code, source_id)
        REFERENCES iris_core.source_run (country_code, source_id)
);

-- evidence: explainability trail linking any core entity back to the specific
-- source material that supports it (a document, extract, or sub-geometry).
-- entity_type/entity_id form a polymorphic reference deliberately -- see
-- README "Deliberate simplifications" for why a real FK per entity type was
-- not used in the pilot.
CREATE TABLE iris_core.evidence (
    id           bigserial PRIMARY KEY,
    country_code text NOT NULL,
    entity_type  text NOT NULL CHECK (entity_type IN ('parcel', 'substation', 'peatland', 'screening_layer')),
    entity_id    bigint NOT NULL,
    note         text,
    geom         geometry(Geometry, 4326),
    source_id    text NOT NULL,
    source_date  date NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_evidence_country_entity_source
        UNIQUE (country_code, entity_type, entity_id, source_id),
    CONSTRAINT chk_evidence_geom_valid CHECK (geom IS NULL OR ST_IsValid(geom)),
    CONSTRAINT fk_evidence_source FOREIGN KEY (country_code, source_id)
        REFERENCES iris_core.source_run (country_code, source_id)
);
