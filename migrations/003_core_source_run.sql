-- iris_core.source_run: provenance/bookkeeping for every ingestion run that
-- populates core business tables. Created before the business tables so they
-- can carry a country-scoped FK into it (source_id alone is not globally
-- unique across countries/providers, so the key is composite).

CREATE TABLE iris_core.source_run (
    id                bigserial PRIMARY KEY,
    source_id         text NOT NULL,
    country_code      text NOT NULL,
    source_name       text NOT NULL,
    source_date       date NOT NULL,
    run_started_at    timestamptz NOT NULL DEFAULT now(),
    run_completed_at  timestamptz,
    params            jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at        timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT uq_source_run_country_source UNIQUE (country_code, source_id)
);

CREATE INDEX ix_source_run_country ON iris_core.source_run (country_code);
