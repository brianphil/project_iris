"""Connection helper. Single source of truth for how IRIS connects to Postgres."""
from __future__ import annotations

import os

import psycopg

DEFAULT_DSN = "postgresql://iris:iris@localhost:55432/iris"


def dsn() -> str:
    return os.environ.get("DATABASE_URL", DEFAULT_DSN)


def connect(autocommit: bool = False) -> psycopg.Connection:
    return psycopg.connect(dsn(), autocommit=autocommit)
