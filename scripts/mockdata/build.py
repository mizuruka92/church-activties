"""Assembles every domain into one {qualified table: rows} dictionary."""

from . import donations, liturgy, parish, planning, reference, surveys
from .ddl import parse_ddl


def load_tables(ddl_path):
    with open(ddl_path, encoding="utf-8") as handle:
        return parse_ddl(handle.read())


def build_all():
    """Generate all rows. Order matters only for derived values: donations use
    the parishioner assignments."""
    data = {}
    data.update(reference.build())
    data.update(liturgy.build())
    data.update(parish.build())
    data.update(donations.build(data))
    data.update(surveys.build())
    data.update(planning.build())
    return data
