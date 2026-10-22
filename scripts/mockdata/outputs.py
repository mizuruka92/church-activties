"""Turns generated data into the committed artifacts and keeps them in sync.

Generated files (never edit by hand):
    sql/03_load_reference_data.sql   MERGE statements for schema MASTER_DATA
    sql/04_load_mock_data.sql        MERGE statements for schema DATA_OPERASIONAL
    sql/06_validate_data.sql         one-statement validation
    sql/full_setup.sql               files 00-06 concatenated for a one-paste setup
    sql/99_reset_demo.sql            DESTRUCTIVE reset, every statement commented out
    docs/DATA_DICTIONARY.md          Bahasa Indonesia data dictionary
    data/documents/laporan_kegiatan/*.pdf   one mock PDF post-event report per report row (see render_documents)
"""

from pathlib import Path

from . import config, dictionary, documents, sqlwriter, validation
from .build import build_all, load_tables
from .checks import check_integrity, check_scenarios

# The operational data is loaded by domain, in dependency order, so that no single
# file gets too large to paste into a browser editor and every part can be re-run alone.
# (file name, title, tables, what it needs)
OPERATIONAL_LOADS = [
    ("04a_load_mass_history.sql", "Load Mass occurrences, attendance and the unforeseen-event log",
     ["PERISTIWA_LUAR_BIASA", "KEJADIAN_MISA", "KEHADIRAN_MISA"], "steps 2 and 3"),
    ("04b_load_offertory.sql", "Load the offertory collections of every Mass",
     ["PENERIMAAN_KOLEKTE"], "steps 2, 3 and 4a (Mass occurrences)"),
    ("04c_load_parishioners.sql", "Load fictional households, parishioners and their assignments",
     ["KELUARGA", "UMAT", "PENUGASAN_KELUARGA", "PENUGASAN_LINGKUNGAN"], "steps 2 and 3"),
    ("04d_load_surveys.sql", "Load anonymous survey respondents, answers and aggregated results",
     ["RESPONDEN_SURVEI", "JAWABAN_SURVEI", "HASIL_SURVEI_AGREGAT"], "steps 2 and 3"),
    ("04e_load_plans_and_events.sql", "Load annual plans, budgets, expenditure, events and reports",
     ["RENCANA_KERJA_TAHUNAN", "RENCANA_KEGIATAN", "ALOKASI_ANGGARAN", "REALISASI_PENGELUARAN", "KEGIATAN",
      "LAPORAN_KEGIATAN"], "steps 2 and 3"),
    ("04f_load_donations.sql", "Load donation campaigns, household gifts and regional summaries",
     ["KAMPANYE_SUMBANGAN", "SUMBANGAN_KESEMPATAN_KHUSUS", "SUMBANGAN_KELUARGA"], "steps 4c (households) and 4e (plans)"),
]

SQL_SOURCES = (
    ["00_setup.sql", "01_create_schemas.sql", "02_create_tables.sql", "03_load_reference_data.sql"]
    + [entry[0] for entry in OPERATIONAL_LOADS]
    + ["05_create_views.sql", "06_validate_data.sql"]
)

_RULE = "-- " + "=" * 77


def _load_header(step, title, schema, tables, data, requires):
    rows = sum(len(data[t.qualified]) for t in tables)
    return "\n".join([
        _RULE,
        f"-- Step {step}: {title}",
        "--",
        "-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py",
        f"-- Content  : {len(tables)} tables, {rows} rows in schema {schema}. All data is synthetic",
        f"--            (fictional) and reproducible (seed {config.SEED}, snapshot date {config.AS_OF.isoformat()}).",
        f"-- Requires : {requires}",
        "-- Safe to re-run: yes. Every table is loaded with MERGE on its primary key, so existing",
        "--            rows are updated and new rows are inserted. Nothing is deleted and nothing",
        "--            is duplicated. Statements are ordered parents first.",
        "-- Warehouse: any running warehouse is enough (the data volume is small).",
        _RULE,
        "",
        "USE DATABASE PUSAT_INFORMASI_PAROKI;",
        "",
        "",
    ])


def render_load_file(step, title, schema, selected, data, requires):
    statements = []
    for table in selected:
        statements += sqlwriter.merge_statements(table, data[table.qualified])
    return _load_header(step, title, schema, selected, data, requires) + "\n\n".join(statements) + "\n"


def render_reset(tables):
    """Destructive reset script. Every statement is commented out on purpose, so
    running the whole file changes nothing. It names only the demo objects."""
    lines = [
        _RULE,
        "-- !!!  DESTRUCTIVE  !!!  RESET OF THE DEMO DATABASE  !!!  DESTRUCTIVE  !!!",
        "--",
        "-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py",
        "--",
        "-- This file DELETES DATA OR OBJECTS. It is NOT part of the normal setup and is NOT",
        "-- included in sql/full_setup.sql. Use it only on the demo database named below,",
        "-- never on a database that holds anything you want to keep.",
        "--",
        "-- Safety: every statement below is commented out, so running the whole file does",
        "-- nothing. To reset, choose ONE option, remove the leading '-- ' from its",
        "-- statements only, read them once more, then run them.",
        "-- Snowflake Time Travel may allow UNDROP for a short time depending on the account",
        "-- edition, but do not rely on it. Recreate the demo with sql/full_setup.sql.",
        _RULE,
        "",
        "USE DATABASE PUSAT_INFORMASI_PAROKI;",
        "",
        "-- Option A: remove all rows but keep tables and views (children first).",
    ]
    for table in reversed(tables):
        lines.append(f"-- TRUNCATE TABLE IF EXISTS {table.qualified};")
    lines += [
        "",
        "-- Option B: drop the three demo schemas with everything in them (tables, views).",
        "-- DROP SCHEMA IF EXISTS PUSAT_INFORMASI_PAROKI.ANALISIS;",
        "-- DROP SCHEMA IF EXISTS PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL;",
        "-- DROP SCHEMA IF EXISTS PUSAT_INFORMASI_PAROKI.MASTER_DATA;",
        "",
        "-- Option C: drop the whole demo database.",
        "-- DROP DATABASE IF EXISTS PUSAT_INFORMASI_PAROKI;",
        "",
    ]
    return "\n".join(lines)


def render_full_setup(files):
    """files: list of (name, text) in execution order."""
    parts = [
        "\n".join([
            _RULE,
            "-- ALL-IN-ONE SETUP (steps 0-6) for a new demo database",
            "--",
            "-- GENERATED FILE. It is the concatenation of sql/00 ... sql/06 in order, built by",
            "-- python scripts/generate_mock_data.py. Edit the individual files instead.",
            "-- It never contains sql/99_reset_demo.sql and never drops anything.",
            "--",
            "-- How to run in Snowsight: open a SQL worksheet, choose a role that may create a",
            "-- database and a running warehouse, paste this whole file, and use Run All.",
            "-- The last result shown is the validation table: expect 0 FAIL and exactly 1 WARN.",
            _RULE,
            "",
        ])
    ]
    for name, text in files:
        parts.append(f"{_RULE}\n-- >>> sql/{name}\n{_RULE}\n\n{text.rstrip()}\n")
    return "\n".join(parts)


def render_documents(data):
    """{relative path: PDF bytes}: the mock source documents of the post-event reports. Deterministic."""
    return documents.build(data)


def generate(root):
    """Return ({relative path: text}, data, tables). Raises when the data is not sound."""
    root = Path(root)
    tables = load_tables(root / "sql" / "02_create_tables.sql")
    views_sql = (root / "sql" / "05_create_views.sql").read_text(encoding="utf-8")
    data = build_all()

    problems = check_integrity(tables, data)
    if problems:
        raise SystemExit("Generated data is not sound:\n  " + "\n  ".join(problems[:30]))
    gaps = check_scenarios(data)
    if gaps:
        raise SystemExit("Generated data lost demo scenarios:\n  " + "\n  ".join(gaps))

    by_name = {t.qualified: t for t in tables}
    files = {
        "sql/03_load_reference_data.sql": render_load_file(
            3, "Load reference and master data", "MASTER_DATA",
            [t for t in tables if t.schema == "MASTER_DATA"], data, "step 2 (tables)"),
        "sql/06_validate_data.sql": validation.render(tables, data, views_sql, config.SEED),
        "docs/DATA_DICTIONARY.md": dictionary.render(tables, data, views_sql),
        "sql/99_reset_demo.sql": render_reset(tables),
    }
    for name, title, names, requires in OPERATIONAL_LOADS:
        selected = [by_name[f"DATA_OPERASIONAL.{n}"] for n in names]
        step = name.split("_")[0].lstrip("0")  # "04a_..." -> "4a"
        files[f"sql/{name}"] = render_load_file(step, title, "DATA_OPERASIONAL", selected, data, requires)
    sources = []
    for name in SQL_SOURCES:
        key = f"sql/{name}"
        text = files[key] if key in files else (root / key).read_text(encoding="utf-8")
        sources.append((name, text))
    files["sql/full_setup.sql"] = render_full_setup(sources)
    return files, data, tables
