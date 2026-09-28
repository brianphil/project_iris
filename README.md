# Project IRIS — Canonical PostGIS Pilot Schema (IRIS-CAND-03)

Minimum reproducible PostgreSQL/PostGIS schema for the IRIS pilot: staging +
core schemas, country-aware keys, geometry contracts, source provenance, and
the indexes needed to support the BESS-siting and peatland-inference
verticals.

## Setup

Requires Docker (for a disposable Postgres 16 + PostGIS 3.4 instance) and
Python 3.12+.

```bash
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements.txt

make up          # starts postgis/postgis:16-3.4 on localhost:55432 (user/pass/db: iris)
make rebuild      # drop -> migrate -> seed, from empty DB
make verify       # runs verification/verify.sql against the rebuilt schema
make test         # pytest: rebuilds the schema itself, then asserts every acceptance criterion
```

`DATABASE_URL` defaults to `postgresql://iris:iris@localhost:55432/iris`
(`iris/db.py`); override it to point at any other Postgres 16+/PostGIS 3.4+
instance instead of the bundled `docker-compose.yml`. Port `55432` (not the
default `5432`) is used deliberately so the bundled container never collides
with a Postgres instance that might already be running locally on the
standard port.

`make` is a convenience wrapper, not a requirement — every target is a
one-line call to `python -m iris.migrate <command>` (see the table below), so
on a machine without GNU Make (e.g. plain Windows) run those directly instead:

```powershell
# PowerShell, venv activated (as above) — do not prefix these with `wsl`.
# WSL has its own separate Docker CLI and Python install, neither of which
# is set up for this project; running `wsl make ...` will fail with
# unrelated errors (missing compose plugin, missing python/pytest) even
# though the schema and container are working fine.
python -m iris.migrate rebuild
pytest -q
psql "postgresql://iris:iris@localhost:55432/iris" -f verification/verify.sql
```

## Commands

| Command | Effect |
|---|---|
| `make up` | Start the local Postgres/PostGIS container |
| `python -m iris.migrate rebuild` | Drop `iris_core`/`iris_staging`, re-run every migration, load seed fixtures — the reproducibility contract in acceptance criterion 1 |
| `python -m iris.migrate migrate` | Apply `migrations/*.sql` in filename order, no drop/seed |
| `python -m iris.migrate seed` | Load `seeds/seed.sql` only |
| `python -m iris.migrate reset` | Drop the two schemas, nothing else |
| `make verify` | Run `verification/verify.sql` (canonical columns, NOT NULL enforcement, spatial round trip, index usage, country-scoped uniqueness) |
| `make test` | `pytest`: same conditions as `verify.sql`, asserted automatically |

## Architecture

**Two schemas.** `iris_staging` holds one loosely-typed landing table per
spatial feature type (`stg_parcel`, `stg_substation`, `stg_peatland`,
`stg_screening_layer`) — permissive on uniqueness and geometry validity,
because raw loader output can be dirty or re-run. `iris_core` holds the six
required tables (`parcel`, `substation`, `peatland`, `screening_layer`,
`source_run`, `evidence`) with the full constraint set. `source_run` and
`evidence` are core-only: they are provenance/explainability bookkeeping, not
raw feature data, so there's nothing meaningful to stage for them.

**Canonical contract**, enforced identically across every `iris_core` table:
`geom` (never `geometry`), `country_code` (`NOT NULL` everywhere, staging
included — "every persisted business entity must carry a non-null
country_code"), `region_code`, `source_id`, `source_date`, `created_at`.

**Country-scoped keys.** Business keys (`parcel_ref`, `substation_ref`,
`peatland_ref`) are unique per `(country_code, ref)`, not globally — two
countries' cadastral systems can and do reuse reference numbers. `source_run`
is likewise keyed `(country_code, source_id)`, and every core table's FK back
to it is the composite pair, not `source_id` alone — a bare `source_id`
foreign key would let a Portuguese parcel silently reference an Irish
source_run row that happens to share an id.

**Geometry types.** `parcel`/`peatland` are `MultiPolygon` (area features,
constrained to avoid a stray `Polygon` producing type-mismatch errors at
insert time downstream), `substation` is `Point`. `screening_layer`/`evidence`
use a generic `geometry(Geometry, 4326)` because they carry derived output
(a buffer, an intersection, or nothing at all — see `screening_layer.geom`
comment in `migrations/004_core_business_tables.sql`), not a fixed feature
type. All core geometries are `CHECK (ST_IsValid(geom))`; staging is not, so
that repair/rejection happens explicitly at promotion time instead of
silently at insert time.

**CRS policy: store in EPSG:4326, transform at query time.** Source providers
typically deliver WGS84 lon/lat; storing in 4326 avoids a lossy reprojection
on every load. Metric operations (area, distance, buffers) cast to
`geography` or `ST_Transform` at query time — see `verification/verify.sql`
query 5, which uses `::geography` for a distance-in-metres `ST_DWithin`. A
second stored projected-CRS column per table was considered and rejected for
a one-region pilot slice: it doubles write cost for a transform that's cheap
enough to do at read time on this data volume. **Simplification to revisit
for production:** if the pilot expands to multiple regions/countries with
very different optimal projections, query-time `ST_Transform` cost may
justify a per-country projected geometry column (or a partitioned
materialized view) instead.

**Indexes** (`migrations/005_core_indexes.sql`): GIST on every `geom` column
(partial `WHERE geom IS NOT NULL` on the two nullable ones), btree on
`(country_code, region_code)` on every core table — the pilot's "one-region
vertical slice" filters by that pair before anything spatial — plus join
indexes for `screening_layer.parcel_id` and `evidence(entity_type,
entity_id)`.

## Deliberate simplifications (and how they'd evolve for production)

- **`evidence.entity_id` is a polymorphic reference** (paired with
  `entity_type`, `CHECK`-constrained to the four valid targets) rather than
  four separate nullable FK columns or four separate evidence tables. This
  keeps the pilot schema to the six required tables. In production this
  should become either per-entity evidence tables (loses the single
  explainability query surface but gets real FK integrity) or a `CHECK`
  enforced via trigger against each target table, since Postgres can't FK a
  column against "whichever table `entity_type` names."
- **No `promoted_at`/staging→core lineage table.** The pilot assumes
  promotion is done by a loader script that reads `iris_staging`, validates,
  and writes `iris_core` directly; there's no row-level link back from a core
  row to the staging row it came from beyond `source_id`. Production would
  want an explicit `stg_row_id` FK for full lineage and reprocessing.
  Out of scope here — no promotion loader is included at all, only the
  staging landing tables and the core schema it would write into (the
  assignment scope is the schema, not the ingestion adapters).
- **No soft-delete/versioning.** Core rows are hard-inserted; there's no
  `valid_from`/`valid_to` or superseded-row tracking. A production pilot
  re-running a source monthly would want that to avoid silently losing the
  prior screening result's audit trail.
- **`screening_layer.uncertainty` defaults to the project's fixed disclaimer
  text** rather than being computed per row. It's stored as a real column
  (not hardcoded in application code) so the pilot's mandated wording ships
  with the data it describes, but a production system would likely want a
  smaller `uncertainty_code` plus a separate disclaimer-text lookup table so
  the wording can change without touching every historical row.
- **Single seed fixture, single country.** `seeds/seed.sql` seeds `IE` only,
  by design (a "small deterministic fixture set" per the assignment) — the
  `PT` parcel used to prove country-scoped uniqueness lives in
  `verification/verify.sql` and `tests/test_schema.py`, not the seed file.

## Testing

`tests/test_schema.py` rebuilds the schema once per test session
(`tests/conftest.py`) and then, per test, opens its own connection wrapped in
a transaction that's rolled back afterward — so tests can insert
constraint-violating rows to prove a constraint fires without polluting state
for the next test. Covered: canonical columns present on every core table, no
column named `geometry`, `country_code NOT NULL` on every table (schema
inspection + a real rejected insert), country-scoped uniqueness (same
`parcel_ref` accepted in `IE` and `PT`, rejected twice within `IE`), FK
provenance (`source_id` must resolve to a real `source_run` in the same
country), geometry validity (`ST_IsValid` rejects a self-intersecting
polygon), a spatial round trip (`ST_AsText`/`ST_SRID`/`ST_X`/`ST_Y` match what
was inserted), GIST indexes exist on every `geom` column, and a forced
`enable_seqscan = off` `EXPLAIN` shows the planner using them.
