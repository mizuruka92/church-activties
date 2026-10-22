"""Renders generated rows as idempotent Snowflake MERGE statements.

Each table becomes one statement:

    MERGE INTO <table> AS t
    USING (SELECT ... FROM (VALUES (...), ...) AS v (<columns>)) AS s
    ON <primary key>
    WHEN MATCHED THEN UPDATE SET ...
    WHEN NOT MATCHED THEN INSERT ...

Re-running the file therefore never duplicates rows: existing keys are updated,
new keys are inserted. Every cell is validated against the DDL type first.
"""

import csv
import io
from datetime import date, datetime, time
from decimal import Decimal

# Characters that would break statement splitting or string quoting in
# Snowsight, SnowSQL or the Snowflake CLI. The generated text never needs them.
_FORBIDDEN_IN_TEXT = ("\\", ";", "--", "\n", "\r", "\t", "/*", "*/")


class DataError(ValueError):
    pass


def _check_text(table, column, value):
    for token in _FORBIDDEN_IN_TEXT:
        if token in value:
            raise DataError(f"{table.qualified}.{column.name}: text contains forbidden sequence {token!r}: {value[:60]!r}")
    if column.length is not None and len(value) > column.length:
        raise DataError(f"{table.qualified}.{column.name}: {len(value)} characters exceed VARCHAR({column.length})")


def validate_cell(table, column, value):
    """Raise DataError when a Python value does not fit the DDL column."""
    name = f"{table.qualified}.{column.name}"
    if value is None:
        if not column.nullable:
            raise DataError(f"{name}: NULL in a NOT NULL column")
        return
    kind = column.base_type
    if kind == "VARCHAR":
        if not isinstance(value, str):
            raise DataError(f"{name}: expected str, got {type(value).__name__}")
        _check_text(table, column, value)
    elif kind == "NUMBER":
        if isinstance(value, bool) or not isinstance(value, (int, Decimal)):
            raise DataError(f"{name}: expected int or Decimal, got {type(value).__name__}")
        if column.scale == 0 and value != int(value):
            raise DataError(f"{name}: {value} is not a whole number")
        integer_digits = len(str(abs(int(value))))
        if integer_digits > column.length - column.scale:
            raise DataError(f"{name}: {value} exceeds {column.sql_type}")
    elif kind == "DATE":
        if not isinstance(value, date) or isinstance(value, datetime):
            raise DataError(f"{name}: expected date, got {type(value).__name__}")
    elif kind == "TIME":
        if not isinstance(value, time):
            raise DataError(f"{name}: expected time, got {type(value).__name__}")
    elif kind == "TIMESTAMP_NTZ":
        if not isinstance(value, datetime):
            raise DataError(f"{name}: expected datetime, got {type(value).__name__}")
    elif kind == "BOOLEAN":
        if not isinstance(value, bool):
            raise DataError(f"{name}: expected bool, got {type(value).__name__}")
    else:
        raise DataError(f"{name}: unsupported type {column.sql_type}")


def validate_rows(table, rows):
    expected = set(table.column_names)
    for index, row in enumerate(rows):
        if set(row) != expected:
            missing = sorted(expected - set(row))
            extra = sorted(set(row) - expected)
            raise DataError(f"{table.qualified} row {index}: missing {missing}, unexpected {extra}")
        for column in table.columns:
            validate_cell(table, column, row[column.name])


def literal(value, column):
    """SQL literal for a validated value."""
    if value is None:
        return "NULL"
    kind = column.base_type
    if kind == "VARCHAR":
        return "'" + value.replace("'", "''") + "'"
    if kind == "NUMBER":
        if column.scale:
            return f"{Decimal(value):.{column.scale}f}"
        return str(int(value))
    if kind == "DATE":
        return f"'{value.isoformat()}'"
    if kind == "TIME":
        return f"'{value.strftime('%H:%M:%S')}'"
    if kind == "TIMESTAMP_NTZ":
        return f"'{value.strftime('%Y-%m-%d %H:%M:%S')}'"
    if kind == "BOOLEAN":
        return "TRUE" if value else "FALSE"
    raise DataError(f"unsupported type {column.sql_type}")


MAX_ROWS_PER_STATEMENT = 1000


def merge_statements(table, rows, max_rows=MAX_ROWS_PER_STATEMENT):
    """One MERGE statement per chunk of rows. Chunks keep every statement small enough
    for browser editors and well below Snowflake's statement size limit."""
    validate_rows(table, rows)
    chunks = [rows[i:i + max_rows] for i in range(0, len(rows), max_rows)] or [rows]
    statements = []
    for number, chunk in enumerate(chunks, start=1):
        statement = merge_statement(table, chunk)
        if len(chunks) > 1:
            first, remainder = statement.split("\n", 1)
            statement = f"{first} (part {number} of {len(chunks)})\n{remainder}"
        statements.append(statement)
    return statements


def merge_statement(table, rows):
    """One idempotent MERGE statement for all given rows."""
    validate_rows(table, rows)
    names = table.column_names
    key = set(table.primary_key)

    select_items = []
    for column in table.columns:
        if column.base_type == "VARCHAR":
            select_items.append(f"        v.{column.name} AS {column.name}")
        else:
            select_items.append(f"        CAST(v.{column.name} AS {column.sql_type}) AS {column.name}")

    value_lines = []
    for row in rows:
        value_lines.append("            (" + ", ".join(literal(row[c.name], c) for c in table.columns) + ")")

    update_items = [f"    {c} = s.{c}" for c in names if c not in key]
    if not update_items:
        raise DataError(f"{table.qualified}: every column is part of the key, nothing to update")
    join = " AND ".join(f"t.{c} = s.{c}" for c in table.primary_key)

    lines = [
        f"-- {table.qualified}: {len(rows)} rows",
        f"MERGE INTO {table.qualified} AS t",
        "USING (",
        "    SELECT",
        ",\n".join(select_items),
        "    FROM (VALUES",
        ",\n".join(value_lines),
        f"    ) AS v ({', '.join(names)})",
        ") AS s",
        f"ON {join}",
        "WHEN MATCHED THEN UPDATE SET",
        ",\n".join(update_items),
        f"WHEN NOT MATCHED THEN INSERT ({', '.join(names)})",
        f"    VALUES ({', '.join('s.' + c for c in names)});",
    ]
    return "\n".join(lines)


def csv_text(table, rows):
    """CSV rendering used by the optional --csv-dir export."""
    validate_rows(table, rows)
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(table.column_names)
    for row in rows:
        cells = []
        for column in table.columns:
            value = row[column.name]
            if value is None:
                cells.append("")
            elif isinstance(value, bool):
                cells.append("TRUE" if value else "FALSE")
            elif isinstance(value, datetime):
                cells.append(value.strftime("%Y-%m-%d %H:%M:%S"))
            elif isinstance(value, time):
                cells.append(value.strftime("%H:%M:%S"))
            elif isinstance(value, date):
                cells.append(value.isoformat())
            else:
                cells.append(str(value))
        writer.writerow(cells)
    return buffer.getvalue()
