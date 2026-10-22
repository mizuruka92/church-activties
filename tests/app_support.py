"""Test support for the Streamlit dashboard: a DuckDB-backed stand-in for the Snowflake query function.

IMPORTANT: this is NOT Snowflake. The dashboard's only link to Snowflake is `streamlit_app.run_query`;
the tests replace it with `run_query` below, which answers the same `SELECT * FROM <db>.ANALISIS.<view>`
statements from a local DuckDB database built from the project's SQL files.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))

import duckdb_shim as shim  # noqa: E402

_connection = None
QUERIES = []  # every statement the dashboard sent, for assertions


def connection():
    global _connection
    if _connection is None:
        _connection = shim.build_database(keep_constraints=False)
    return _connection


def run_query(sql):
    QUERIES.append(sql)
    local = re.sub(r"\b[A-Z_]+\.ANALISIS\.", "ANALISIS.", sql)
    return connection().execute(local).df()


APP_SCRIPT = f"""
import sys
sys.path.insert(0, {str(ROOT / 'app')!r})
sys.path.insert(0, {str(ROOT / 'tests')!r})
import streamlit_app as app
import app_support
app.run_query = app_support.run_query
app.main()
"""
