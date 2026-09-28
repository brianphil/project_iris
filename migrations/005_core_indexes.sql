-- Spatial (GIST) and relational (btree) indexes supporting the two pilot
-- verticals: BESS siting (parcel <-> substation proximity/capacity) and
-- peatland inference (parcel <-> peatland overlap/proximity).

-- Spatial indexes: every geom column that participates in ST_* predicates.
CREATE INDEX ix_parcel_geom ON iris_core.parcel USING GIST (geom);
CREATE INDEX ix_substation_geom ON iris_core.substation USING GIST (geom);
CREATE INDEX ix_peatland_geom ON iris_core.peatland USING GIST (geom);
CREATE INDEX ix_screening_layer_geom ON iris_core.screening_layer USING GIST (geom) WHERE geom IS NOT NULL;
CREATE INDEX ix_evidence_geom ON iris_core.evidence USING GIST (geom) WHERE geom IS NOT NULL;

-- Geography expression indexes: the CRS policy (see README) casts geom::geography
-- at query time for metric ST_DWithin/ST_Distance predicates (BESS proximity,
-- peatland-proximity screening). A geometry GIST index does not accelerate a
-- geography-cast predicate -- it's a different operator class -- so the cast
-- needs its own functional index wherever a metric distance query runs.
CREATE INDEX ix_parcel_geom_geography ON iris_core.parcel USING GIST ((geom::geography));
CREATE INDEX ix_substation_geom_geography ON iris_core.substation USING GIST ((geom::geography));
CREATE INDEX ix_peatland_geom_geography ON iris_core.peatland USING GIST ((geom::geography));

-- Region-scoped lookups: the pilot's "one-region vertical slice" filters
-- every query by country_code (+ optionally region_code) before anything else.
CREATE INDEX ix_parcel_country_region ON iris_core.parcel (country_code, region_code);
CREATE INDEX ix_substation_country_region ON iris_core.substation (country_code, region_code);
CREATE INDEX ix_peatland_country_region ON iris_core.peatland (country_code, region_code);
CREATE INDEX ix_screening_layer_country_region ON iris_core.screening_layer (country_code, region_code);

-- Join/traversal indexes.
CREATE INDEX ix_screening_layer_parcel_id ON iris_core.screening_layer (parcel_id);
CREATE INDEX ix_evidence_entity ON iris_core.evidence (entity_type, entity_id);
