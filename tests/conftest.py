import pytest

from iris.db import connect
from iris.migrate import rebuild


@pytest.fixture(scope="session", autouse=True)
def rebuilt_schema():
    """Rebuild the schema once per test session from an empty DB, matching
    acceptance criterion 1 (schema rebuilds from empty DB without manual
    intervention). Individual tests wrap their own mutations in rolled-back
    transactions so they don't need a rebuild each."""
    rebuild()
    yield


@pytest.fixture()
def conn():
    with connect(autocommit=False) as c:
        yield c
        c.rollback()
