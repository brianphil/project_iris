# IRIS Pilot Schema

```mermaid
erDiagram
    SOURCE_RUN ||--o{ PARCEL : "provenance"
    SOURCE_RUN ||--o{ SUBSTATION : "provenance"
    SOURCE_RUN ||--o{ PEATLAND : "provenance"
    SOURCE_RUN ||--o{ SCREENING_LAYER : "provenance"
    SOURCE_RUN ||--o{ EVIDENCE : "provenance"
    PARCEL ||--o{ SCREENING_LAYER : "scores"
    PARCEL ||..o{ EVIDENCE : "entity_type='parcel'"
    SUBSTATION ||..o{ EVIDENCE : "entity_type='substation'"
    PEATLAND ||..o{ EVIDENCE : "entity_type='peatland'"

    SOURCE_RUN {
        bigserial id PK
        text source_id
        text country_code
        text source_name
        date source_date
        timestamptz run_started_at
        timestamptz run_completed_at
        jsonb params
        timestamptz created_at
    }

    PARCEL {
        bigserial id PK
        text country_code
        text region_code
        text parcel_ref
        geometry_MultiPolygon_4326 geom
        numeric area_m2
        text source_id FK
        date source_date
        timestamptz created_at
    }

    SUBSTATION {
        bigserial id PK
        text country_code
        text region_code
        text substation_ref
        text name
        numeric voltage_kv
        numeric capacity_mva
        geometry_Point_4326 geom
        text source_id FK
        date source_date
        timestamptz created_at
    }

    PEATLAND {
        bigserial id PK
        text country_code
        text region_code
        text peatland_ref
        text peat_depth_class
        geometry_MultiPolygon_4326 geom
        text source_id FK
        date source_date
        timestamptz created_at
    }

    SCREENING_LAYER {
        bigserial id PK
        text country_code
        text region_code
        bigint parcel_id FK
        text layer_type
        numeric score
        text uncertainty
        geometry_Geometry_4326 geom "nullable"
        jsonb attributes
        text source_id FK
        date source_date
        timestamptz created_at
    }

    EVIDENCE {
        bigserial id PK
        text country_code
        text entity_type
        bigint entity_id "polymorphic, see README"
        text note
        geometry_Geometry_4326 geom "nullable"
        text source_id FK
        date source_date
        timestamptz created_at
    }
```

`iris_staging` mirrors `stg_parcel` / `stg_substation` / `stg_peatland` /
`stg_screening_layer` as loosely-typed landing tables (no uniqueness, no FK,
generic `geometry(Geometry, 4326)`, `country_code` still `NOT NULL`) feeding
promotion into the `iris_core` tables shown above.

See [../README.md](../README.md) for the CRS policy, key design, and the
country-scoped uniqueness rationale.
