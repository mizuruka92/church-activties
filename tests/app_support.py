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


# The optional view of sql/07 (links to the PDF files on a stage) uses Snowflake-only features (directory tables, pre-signed URLs),
# so DuckDB cannot run the real definition. This stand-in has the same columns and invents the links, on a host that cannot exist
# (".invalid"). Two documents are "not on the stage", to exercise the page text for a missing file.
NOT_ON_STAGE = ("LPK-0002", "LYN-04")
STAND_IN_DOCUMENT_VIEW = f"""
CREATE OR REPLACE VIEW ANALISIS.BERKAS_DOKUMEN AS
WITH dokumen AS (
    SELECT 'Laporan kegiatan' AS JENIS_DOKUMEN, ID_LAPORAN AS ID_DOKUMEN, NAMA_BERKAS_LAPORAN AS NAMA_BERKAS
    FROM ANALISIS.KEGIATAN_DAN_LAPORAN WHERE NAMA_BERKAS_LAPORAN IS NOT NULL
    UNION ALL
    SELECT 'Panduan layanan', ID_LAYANAN, NAMA_BERKAS_PANDUAN FROM ANALISIS.LAYANAN_PUBLIK WHERE NAMA_BERKAS_PANDUAN IS NOT NULL
)
SELECT JENIS_DOKUMEN, ID_DOKUMEN, NAMA_BERKAS,
       ID_DOKUMEN NOT IN {NOT_ON_STAGE!r} AS ADA_DI_STAGE,
       CASE WHEN ID_DOKUMEN NOT IN {NOT_ON_STAGE!r}
            THEN 'https://stage.stand-in.invalid/DOKUMEN_PAROKI/' || NAMA_BERKAS || '?signature=stand-in' END AS TAUTAN_BERKAS,
       3600 AS LAMA_BERLAKU_TAUTAN_DETIK,
       'Data simulasi (fiktif)' AS SUMBER_DATA
FROM dokumen
"""
HIDDEN = set()  # names of views that the stand-in pretends do not exist, as Snowflake does before step 7 has been run


def connection():
    global _connection
    if _connection is None:
        _connection = shim.build_database(keep_constraints=False)
        _connection.execute(STAND_IN_DOCUMENT_VIEW)
    return _connection


def run_query(sql):
    QUERIES.append(sql)
    for name in HIDDEN:
        if re.search(rf"\.{name}\b", sql):
            raise RuntimeError(f"SQL compilation error: Object 'ANALISIS.{name}' does not exist or not authorized.")
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
