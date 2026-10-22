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


def _split_arguments(text):
    """Split 'a, f(b, c), d' on top-level commas."""
    parts, depth, current = [], 0, ""
    for char in text:
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += char
    parts.append(current.strip())
    return parts


def rewrite_dateadd(sql):
    """DuckDB has no DATEADD. Rewrite DATEADD('day', n, d) as (d + CAST(n AS INTEGER)), with
    balanced-parenthesis parsing so nested calls are handled. Other parts are not supported."""
    while True:
        start = sql.find("DATEADD(")
        if start < 0:
            return sql
        depth, i = 0, start + len("DATEADD")
        for i in range(start + len("DATEADD"), len(sql)):
            if sql[i] == "(":
                depth += 1
            elif sql[i] == ")":
                depth -= 1
                if depth == 0:
                    break
        unit, amount, base = _split_arguments(sql[start + len("DATEADD("):i])
        if unit.strip("'").lower() != "day":
            raise ValueError(f"the shim only supports DATEADD('day', ...): {unit}")
        sql = sql[:start] + f"({base} + CAST({amount} AS INTEGER))" + sql[i + 1:]


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
    s = rewrite_dateadd(s)
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


def load_files():
    """Setup steps that create objects and load data, in execution order (not 00, 06 or 99)."""
    return (["01_create_schemas.sql", "02_create_tables.sql", "03_load_reference_data.sql"]
            + sorted(path.name for path in SQL.glob("04*.sql")) + ["05_create_views.sql"])


def build_database(keep_constraints=True, through="05_create_views.sql"):
    import duckdb

    connection = duckdb.connect(":memory:")
    for name in load_files():
        run_file(connection, name, keep_constraints)
        if name == through:
            break
    return connection
