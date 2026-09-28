-- Project IRIS: extensions and top-level schemas
-- iris_staging: loosely-typed landing area for raw source loads (pre-promotion).
-- iris_core:    canonical, constrained schema used by pilot queries (BESS + peatland verticals).

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS iris_staging;
CREATE SCHEMA IF NOT EXISTS iris_core;
