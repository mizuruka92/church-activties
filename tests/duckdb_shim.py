"""Runs the project's Snowflake SQL files against DuckDB for local testing.

IMPORTANT: this is NOT Snowflake. DuckDB is a different engine, so a pass here
proves the SQL is logically sound and internally consistent, not that Snowflake
accepts every keyword. The shim only rewrites Snowflake-only syntax that DuckDB
does not know: COMMENT clauses, TIMESTAMP_NTZ, NUMBER(p,s), USE/CREATE DATABASE.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "sql"

_COLUMN_COMMENT = re.compile(r" COMMENT '[^']*'(?=,?\s*$)", re.MULTILINE)
_TABLE_COMMENT = re.compile(r"^\) COMMENT = '[^']*';$", re.MULTILINE)
_OBJECT_COMMENT = re.compile(r"^\s*COMMENT = '[^']*'\s*$", re.MULTILINE)
_SCHEMA_COMMENT = re.compile(r"\s+COMMENT = '[^']*';$")
_CONSTRAINT_LINE = re.compile(r"^\s+CONSTRAINT .*$", re.MULTILINE)


def split_statements(text):
    """Split a Snowflake script on statement-ending semicolons. Safe for the
    generated files because the writer forbids ';' and '--' inside string data."""
    lines = [line for line in text.splitlines() if not line.strip().startswith("--")]
    body = "\n".join(lines)
    return [s.strip() for s in re.split(r";\s*(?:\n|$)", body) if s.strip()]


def translate(statement, keep_constraints=True):
    head = statement.lstrip().upper()
    if head.startswith(("USE DATABASE", "CREATE DATABASE")):
        return None
    if "CURRENT_ACCOUNT()" in statement:
        return None
    s = statement
    s = _TABLE_COMMENT.sub(");", s + ";")[:-1] if _TABLE_COMMENT.search(s + ";") else s
    s = _COLUMN_COMMENT.sub("", s)
    s = _OBJECT_COMMENT.sub("", s)
    if head.startswith("CREATE SCHEMA"):
        s = re.sub(r"\s+COMMENT = '[^']*'\s*$", "", s)
    s = s.replace("TIMESTAMP_NTZ", "TIMESTAMP")
    s = re.sub(r"\bNUMBER\(", "DECIMAL(", s)
    if head.startswith("CREATE TABLE"):
        schema = re.match(r"CREATE TABLE IF NOT EXISTS (\w+)\.", statement.lstrip()).group(1)
        if keep_constraints:
            # DuckDB cannot create foreign keys across schemas: drop only those.
            def drop_cross_schema(match):
                line = match.group(0)
                reference = re.search(r"REFERENCES (\w+)\.", line)
                return "" if reference and reference.group(1) != schema else line
            s = _CONSTRAINT_LINE.sub(drop_cross_schema, s)
        else:
            s = _CONSTRAINT_LINE.sub("", s)
        s = re.sub(r",\s*\n\s*\)", "\n)", s)
        s = re.sub(r"\n\s*\n", "\n", s)
    return s


def run_file(connection, filename, keep_constraints=True):
    """Execute one project SQL file. Returns the rows of the last SELECT, if any."""
    last = None
    for statement in split_statements((SQL / filename).read_text(encoding="utf-8")):
        translated = translate(statement, keep_constraints)
        if translated is None:
            continue
        cursor = connection.execute(translated)
        if translated.lstrip().upper().startswith(("SELECT", "WITH")):
            columns = [d[0] for d in cursor.description]
            last = [dict(zip(columns, row)) for row in cursor.fetchall()]
    return last


def build_database(keep_constraints=True, through="05_create_views.sql"):
    import duckdb

    connection = duckdb.connect(":memory:")
    for name in ["01_create_schemas.sql", "02_create_tables.sql", "03_load_reference_data.sql",
                 "04_load_mock_data.sql", "05_create_views.sql"]:
        run_file(connection, name, keep_constraints)
        if name == through:
            break
    return connection
