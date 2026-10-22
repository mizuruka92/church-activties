"""Reads sql/02_create_tables.sql so that the DDL stays the single source of
truth for table names, column order, types, nullability and conceptual keys.

The parser relies on the layout described at the top of the DDL file: one
column per line, constraints declared inline, one COMMENT per table.
"""

import re
from dataclasses import dataclass, field

_CREATE = re.compile(r"^CREATE TABLE IF NOT EXISTS (\w+)\.(\w+) \($")
_COLUMN = re.compile(
    r"^\s+(\w+) (VARCHAR\(\d+\)|NUMBER\(\d+,\d+\)|DATE|TIME|TIMESTAMP_NTZ|BOOLEAN)"
    r"( NOT NULL)?(?: COMMENT '(.*)')?,?\s*$"
)
_PRIMARY = re.compile(r"^\s+CONSTRAINT (\w+) PRIMARY KEY \(([^)]*)\),?\s*$")
_UNIQUE = re.compile(r"^\s+CONSTRAINT (\w+) UNIQUE \(([^)]*)\),?\s*$")
_FOREIGN = re.compile(
    r"^\s+CONSTRAINT (\w+) FOREIGN KEY \(([^)]*)\) REFERENCES (\w+)\.(\w+) \(([^)]*)\),?\s*$"
)
_END = re.compile(r"^\) COMMENT = '(.*)';$")
_TYPE = re.compile(r"^(VARCHAR|NUMBER)\((\d+)(?:,(\d+))?\)$")


def _names(text):
    return [part.strip() for part in text.split(",")]


@dataclass
class Column:
    name: str
    sql_type: str
    nullable: bool
    comment: str

    @property
    def base_type(self):
        match = _TYPE.match(self.sql_type)
        return match.group(1) if match else self.sql_type

    @property
    def length(self):
        """Length for VARCHAR, precision for NUMBER, otherwise None."""
        match = _TYPE.match(self.sql_type)
        return int(match.group(2)) if match else None

    @property
    def scale(self):
        match = _TYPE.match(self.sql_type)
        return int(match.group(3) or 0) if match and match.group(1) == "NUMBER" else None


@dataclass
class ForeignKey:
    name: str
    columns: list
    ref_schema: str
    ref_table: str
    ref_columns: list


@dataclass
class Table:
    schema: str
    name: str
    columns: list = field(default_factory=list)
    primary_key: list = field(default_factory=list)
    unique_keys: list = field(default_factory=list)  # list of (name, [columns])
    foreign_keys: list = field(default_factory=list)
    comment: str = ""

    @property
    def qualified(self):
        return f"{self.schema}.{self.name}"

    def column(self, name):
        for column in self.columns:
            if column.name == name:
                return column
        raise KeyError(f"{self.qualified} has no column {name}")

    @property
    def column_names(self):
        return [column.name for column in self.columns]

    @property
    def description(self):
        return self.comment.split(" | ")[0]

    def _part(self, label):
        for part in self.comment.split(" | ")[1:]:
            if part.startswith(label + ": "):
                return part[len(label) + 2:]
        return ""

    @property
    def grain(self):
        return self._part("Granularitas")

    @property
    def classification(self):
        return self._part("Klasifikasi")


def parse_ddl(text):
    """Return the list of Table objects in file order."""
    tables = []
    current = None
    for number, line in enumerate(text.splitlines(), start=1):
        if current is None:
            match = _CREATE.match(line)
            if match:
                current = Table(schema=match.group(1), name=match.group(2))
            continue
        end = _END.match(line)
        if end:
            current.comment = end.group(1)
            if not current.primary_key:
                raise ValueError(f"{current.qualified}: no PRIMARY KEY")
            tables.append(current)
            current = None
            continue
        if line.lstrip().startswith("CONSTRAINT"):
            if _PRIMARY.match(line):
                current.primary_key = _names(_PRIMARY.match(line).group(2))
            elif _UNIQUE.match(line):
                m = _UNIQUE.match(line)
                current.unique_keys.append((m.group(1), _names(m.group(2))))
            elif _FOREIGN.match(line):
                m = _FOREIGN.match(line)
                current.foreign_keys.append(
                    ForeignKey(m.group(1), _names(m.group(2)), m.group(3), m.group(4), _names(m.group(5)))
                )
            else:
                raise ValueError(f"line {number}: unrecognised constraint: {line.strip()}")
            continue
        column = _COLUMN.match(line)
        if not column:
            raise ValueError(f"line {number}: cannot parse column definition: {line.strip()}")
        current.columns.append(
            Column(column.group(1), column.group(2), column.group(3) is None, column.group(4) or "")
        )
    if current is not None:
        raise ValueError(f"{current.qualified}: table definition is not closed")
    return tables
