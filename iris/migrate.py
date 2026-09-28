"""Reproducible schema rebuild / migrate / seed CLI for Project IRIS.

Usage:
    python -m iris.migrate rebuild   # drop schemas, re-run all migrations, load seed fixtures
    python -m iris.migrate migrate   # run migrations only (no drop, no seed)
    python -m iris.migrate seed      # load seed fixtures only
    python -m iris.migrate reset     # drop iris_core / iris_staging schemas only
"""
from __future__ import annotations

import argparse
import pathlib
import sys

from iris.db import connect

ROOT = pathlib.Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = ROOT / "migrations"
SEEDS_DIR = ROOT / "seeds"


def _run_sql_file(cur, path: pathlib.Path) -> None:
    sql = path.read_text(encoding="utf-8")
    cur.execute(sql)


def reset() -> None:
    """Drop the IRIS schemas (and everything in them). Safe to call on an empty DB."""
    with connect(autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("DROP SCHEMA IF EXISTS iris_core CASCADE;")
            cur.execute("DROP SCHEMA IF EXISTS iris_staging CASCADE;")
    print("reset: dropped iris_core and iris_staging schemas (if present)")


def migrate() -> None:
    """Apply every migration in migrations/ in filename order."""
    migration_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not migration_files:
        raise SystemExit(f"no migration files found in {MIGRATIONS_DIR}")

    with connect(autocommit=False) as conn:
        with conn.cursor() as cur:
            for path in migration_files:
                _run_sql_file(cur, path)
                print(f"migrate: applied {path.name}")
        conn.commit()


def seed() -> None:
    """Load the deterministic seed fixture set."""
    seed_files = sorted(SEEDS_DIR.glob("*.sql"))
    if not seed_files:
        raise SystemExit(f"no seed files found in {SEEDS_DIR}")

    with connect(autocommit=False) as conn:
        with conn.cursor() as cur:
            for path in seed_files:
                _run_sql_file(cur, path)
                print(f"seed: applied {path.name}")
        conn.commit()


def rebuild() -> None:
    """Full reset -> migrate -> seed cycle. The command the acceptance criteria mean
    by "schema rebuilds from empty DB without manual intervention"."""
    reset()
    migrate()
    seed()
    print("rebuild: complete")


COMMANDS = {
    "rebuild": rebuild,
    "migrate": migrate,
    "seed": seed,
    "reset": reset,
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=sorted(COMMANDS))
    args = parser.parse_args(argv)
    COMMANDS[args.command]()
    return 0


if __name__ == "__main__":
    sys.exit(main())
