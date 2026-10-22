"""Tests for the synthetic data generator and the committed generated files.

Run with the standard library only:   python -m unittest discover -s tests -v
"""

import copy
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from mockdata import build, checks, dictionary, sqlwriter  # noqa: E402
from mockdata.ddl import parse_ddl  # noqa: E402
from mockdata.outputs import SQL_SOURCES, generate  # noqa: E402
from mockdata.vocab import DAFTAR_NILAI, NILAI_TERKENDALI  # noqa: E402

DDL_PATH = ROOT / "sql" / "02_create_tables.sql"


class GeneratorTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables = build.load_tables(DDL_PATH)
        cls.data = build.build_all()
        cls.by_name = {t.qualified: t for t in cls.tables}


class DdlTests(GeneratorTestCase):
    def test_all_expected_tables_exist(self):
        self.assertEqual(len(self.tables), 33)
        schemas = {t.schema for t in self.tables}
        self.assertEqual(schemas, {"MASTER_DATA", "DATA_OPERASIONAL"})

    def test_every_table_is_documented_and_keyed(self):
        for t in self.tables:
            with self.subTest(table=t.qualified):
                self.assertTrue(t.primary_key)
                self.assertTrue(t.grain, "table comment needs 'Granularitas:'")
                self.assertTrue(t.classification, "table comment needs 'Klasifikasi:'")
                for c in t.columns:
                    self.assertTrue(c.comment, f"{c.name} needs a COMMENT")

    def test_parents_are_created_before_children(self):
        seen = set()
        for t in self.tables:
            for fk in t.foreign_keys:
                self.assertIn(f"{fk.ref_schema}.{fk.ref_table}", seen, f"{t.qualified} references a later table")
            seen.add(t.qualified)

    def test_foreign_keys_point_at_declared_keys(self):
        for t in self.tables:
            for fk in t.foreign_keys:
                parent = self.by_name[f"{fk.ref_schema}.{fk.ref_table}"]
                declared = [parent.primary_key] + [cols for _, cols in parent.unique_keys]
                self.assertIn(fk.ref_columns, declared, f"{fk.name} must reference a PK or UNIQUE key")

    def test_names_follow_the_naming_convention(self):
        for t in self.tables:
            for name in [t.name] + t.column_names:
                self.assertRegex(name, r"^[A-Z][A-Z0-9_]*$")

    def test_constraint_names_are_unique_across_the_model(self):
        declared = re.findall(r"CONSTRAINT (\w+) ", DDL_PATH.read_text(encoding="utf-8"))
        self.assertEqual(len(declared), len(set(declared)), "constraint names must be unique")
        expected = sum(1 + len(t.unique_keys) + len(t.foreign_keys) for t in self.tables)  # one PK per table
        self.assertEqual(len(declared), expected, "the parser must see every constraint")

    def test_money_is_never_text(self):
        for t in self.tables:
            for c in t.columns:
                if any(word in c.name for word in ("ANGGARAN", "PENGELUARAN", "PENERIMAAN", "SUMBANGAN", "BIAYA", "PENGHITUNGAN")):
                    if c.name.startswith("JUMLAH") or c.name == "REALISASI_BIAYA":
                        self.assertEqual(c.sql_type, "NUMBER(18,0)", f"{t.qualified}.{c.name}")

    def test_status_columns_are_controlled(self):
        controlled = {(table, column) for table, column, _ in NILAI_TERKENDALI}
        for t in self.tables:
            for c in t.columns:
                if c.name.startswith("STATUS_") and c.name != "STATUS_AKTIF":
                    self.assertIn((t.qualified, c.name), controlled, f"{t.qualified}.{c.name} has no vocabulary")

    def test_vocabulary_mapping_points_at_real_columns(self):
        for table, column, group in NILAI_TERKENDALI:
            self.assertIn(table, self.by_name)
            self.by_name[table].column(column)
            self.assertIn(group, DAFTAR_NILAI)


class DataTests(GeneratorTestCase):
    def test_every_table_has_data_and_nothing_extra(self):
        self.assertEqual(set(self.data), set(self.by_name))

    def test_data_is_sound(self):
        self.assertEqual(checks.check_integrity(self.tables, self.data), [])

    def test_demo_scenarios_are_present(self):
        self.assertEqual(checks.check_scenarios(self.data), [])

    def test_volumes_stay_small(self):
        total = sum(len(rows) for rows in self.data.values())
        self.assertLess(total, 8000)
        self.assertGreaterEqual(len(self.data["MASTER_DATA.MASTER_WILAYAH"]), 5)
        self.assertLessEqual(len(self.data["MASTER_DATA.MASTER_WILAYAH"]), 10)
        self.assertGreaterEqual(len(self.data["MASTER_DATA.MASTER_LINGKUNGAN"]), 15)
        self.assertLessEqual(len(self.data["MASTER_DATA.MASTER_LINGKUNGAN"]), 30)
        self.assertGreaterEqual(len(self.data["MASTER_DATA.MASTER_SEKSI"]), 5)
        self.assertLessEqual(len(self.data["MASTER_DATA.MASTER_SEKSI"]), 10)

    def test_generation_is_reproducible(self):
        again = build.build_all()
        self.assertEqual(self.data, again)

    def test_no_identity_numbers_emails_or_phone_numbers(self):
        pattern = re.compile(r"\d{9,}|@|\+62|\b08\d{8,}")
        for qualified, rows in self.data.items():
            for row in rows:
                for column, value in row.items():
                    if isinstance(value, str) and column != "GEOJSON":
                        self.assertIsNone(pattern.search(value), f"{qualified}.{column}: {value}")

    def test_personal_tables_have_no_contact_or_identity_columns(self):
        forbidden = ("NIK", "TELEPON", "TELP", "HP", "ALAMAT", "EMAIL", "KTP", "TANGGAL_LAHIR", "NOMOR_IDENTITAS")
        for t in self.tables:
            for name in t.column_names:
                for word in forbidden:
                    self.assertNotIn(word, name.split("_"), f"{t.qualified}.{name}")

    def test_names_look_fictional_and_are_unique(self):
        names = [p["NAMA_FIKTIF"] for p in self.data["DATA_OPERASIONAL.UMAT"]]
        self.assertEqual(len(names), len(set(names)))

    def test_minors_have_the_strictest_classification(self):
        for p in self.data["DATA_OPERASIONAL.UMAT"]:
            if 2026 - p["TAHUN_LAHIR"] < 17:
                self.assertEqual(p["ID_KLASIFIKASI_DATA"], "KLS-04")

    def test_geometry_is_synthetic_and_far_from_any_parish(self):
        import json
        for g in self.data["MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN"]:
            self.assertTrue(g["BERSIFAT_SINTETIS"])
            shape = json.loads(g["GEOJSON"])
            self.assertEqual(shape["type"], "Polygon")
            ring = shape["coordinates"][0]
            self.assertEqual(ring[0], ring[-1], "polygon ring must be closed")
            for lon, lat in ring:
                self.assertTrue(-1 <= lon <= 1 and -1 <= lat <= 1, "coordinates must stay near 0N 0E")

    def test_survey_percentages_are_consistent(self):
        per_question = {}
        for h in self.data["DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT"]:
            per_question.setdefault(h["ID_PERTANYAAN"], []).append(h)
        for question, rows in per_question.items():
            self.assertEqual(sum(r["JUMLAH_RESPONDEN"] for r in rows), rows[0]["TOTAL_RESPONDEN_PERTANYAAN"])
            self.assertAlmostEqual(float(sum(r["PERSENTASE_JAWABAN"] for r in rows)), 100.0, delta=0.1)


class DefectDetectionTests(GeneratorTestCase):
    """The checks must be able to fail. Each mutation breaks one rule."""

    def problems_after(self, mutate):
        data = copy.deepcopy(self.data)
        mutate(data)
        return checks.check_integrity(self.tables, data)

    def test_detects_duplicate_key(self):
        self.assertTrue(self.problems_after(lambda d: d["MASTER_DATA.MASTER_WILAYAH"].append(dict(d["MASTER_DATA.MASTER_WILAYAH"][0]))))

    def test_detects_orphan(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.KEHADIRAN_MISA"][0].update(ID_KEJADIAN_MISA="MIS-999999")))

    def test_detects_negative_amount(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"][0].update(JUMLAH_PENERIMAAN=-1)))

    def test_detects_unknown_status(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.KEHADIRAN_MISA"][0].update(STATUS_VALIDASI="Valid")))

    def test_detects_phone_number(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.UMAT"][0].update(NAMA_FIKTIF="Budi 081234567890")))

    def test_detects_english_text(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.KEHADIRAN_MISA"][0].update(KETERANGAN="This is the note")))

    def test_detects_aggregate_tampering(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT"][0].update(JUMLAH_RESPONDEN=999)))

    def test_detects_plan_event_mismatch(self):
        self.assertTrue(self.problems_after(lambda d: d["DATA_OPERASIONAL.KEGIATAN"][0].update(STATUS_KEGIATAN="Dibatalkan")))

    def test_scenario_check_notices_missing_cancelled_mass(self):
        data = copy.deepcopy(self.data)
        data["DATA_OPERASIONAL.KEJADIAN_MISA"] = [
            o for o in data["DATA_OPERASIONAL.KEJADIAN_MISA"] if o["STATUS_PELAKSANAAN"] != "Dibatalkan"]
        self.assertTrue(checks.check_scenarios(data))


class WriterTests(GeneratorTestCase):
    table = None

    def setUp(self):
        self.table = self.by_name["MASTER_DATA.MASTER_WILAYAH"]

    def row(self, **changes):
        row = dict(copy.deepcopy(self.data["MASTER_DATA.MASTER_WILAYAH"][0]))
        row.update(changes)
        return row

    def test_rejects_characters_that_break_script_execution(self):
        for bad in ("a;b", "a\\b", "a--b", "a\nb", "a/*b"):
            with self.subTest(bad=bad), self.assertRaises(sqlwriter.DataError):
                sqlwriter.validate_rows(self.table, [self.row(KETERANGAN=bad)])

    def test_rejects_wrong_types_lengths_and_nulls(self):
        with self.assertRaises(sqlwriter.DataError):
            sqlwriter.validate_rows(self.table, [self.row(NAMA_WILAYAH="x" * 101)])
        with self.assertRaises(sqlwriter.DataError):
            sqlwriter.validate_rows(self.table, [self.row(NAMA_WILAYAH=None)])
        with self.assertRaises(sqlwriter.DataError):
            sqlwriter.validate_rows(self.table, [self.row(STATUS_AKTIF="TRUE")])
        with self.assertRaises(sqlwriter.DataError):
            sqlwriter.validate_rows(self.table, [self.row(EXTRA="x")])

    def test_quotes_are_escaped(self):
        sql = sqlwriter.merge_statement(self.table, [self.row(KETERANGAN="Pak Budi's kelompok")])
        self.assertIn("'Pak Budi''s kelompok'", sql)

    def test_merge_is_idempotent_by_construction(self):
        sql = sqlwriter.merge_statement(self.table, self.data["MASTER_DATA.MASTER_WILAYAH"])
        self.assertIn("MERGE INTO MASTER_DATA.MASTER_WILAYAH AS t", sql)
        self.assertIn("WHEN MATCHED THEN UPDATE SET", sql)
        self.assertIn("WHEN NOT MATCHED THEN INSERT", sql)
        self.assertNotIn("INSERT INTO", sql)


class CommittedFilesTests(GeneratorTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.files, _, _ = generate(ROOT)

    def test_generated_files_are_up_to_date(self):
        for relative, text in self.files.items():
            with self.subTest(file=relative):
                current = (ROOT / relative).read_bytes().decode("utf-8")
                self.assertEqual(current, text, f"{relative} is stale: run python scripts/generate_mock_data.py")

    def test_dictionary_covers_every_table_and_column(self):
        text = self.files["docs/DATA_DICTIONARY.md"]
        for t in self.tables:
            self.assertIn(f"### {t.qualified}", text)
            for c in t.columns:
                self.assertIn(f"`{c.name}`", text)
        mapped = {name for _, _, tables in dictionary.DOMAINS for name in tables}
        self.assertEqual(mapped, set(self.by_name), "every table must belong to exactly one dictionary domain")

    def test_dictionary_is_in_bahasa_indonesia(self):
        text = self.files["docs/DATA_DICTIONARY.md"]
        for phrase in ("Kamus Data", "Granularitas", "Kunci utama", "DATA SIMULASI", "Daftar nilai terkendali"):
            self.assertIn(phrase, text)

    def test_full_setup_is_the_ordered_concatenation_without_reset(self):
        full = (ROOT / "sql" / "full_setup.sql").read_text(encoding="utf-8")
        position = 0
        for name in SQL_SOURCES:
            body = (ROOT / "sql" / name).read_text(encoding="utf-8").rstrip()
            found = full.find(body, position)
            self.assertGreaterEqual(found, 0, f"{name} missing or out of order in full_setup.sql")
            position = found + len(body)
        self.assertNotIn("99_reset", full.replace("never contains sql/99_reset_demo.sql", ""))
        self.assertNotIn("TRUNCATE", full)

    def test_normal_setup_contains_nothing_destructive(self):
        banned = re.compile(r"^\s*(DROP|TRUNCATE|DELETE|CREATE OR REPLACE (TABLE|DATABASE|SCHEMA)|ALTER .* DROP)\b",
                            re.IGNORECASE | re.MULTILINE)
        for name in SQL_SOURCES + ["full_setup.sql"]:
            text = (ROOT / "sql" / name).read_text(encoding="utf-8")
            code = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
            self.assertIsNone(banned.search(code), f"{name} contains a destructive statement")

    def test_reset_script_does_nothing_until_edited(self):
        text = (ROOT / "sql" / "99_reset_demo.sql").read_text(encoding="utf-8")
        live = [l.strip() for l in text.splitlines() if l.strip() and not l.strip().startswith("--")]
        self.assertEqual(live, ["USE DATABASE PUSAT_INFORMASI_PAROKI;"])
        self.assertIn("DESTRUCTIVE", text)
        for t in self.tables:
            self.assertIn(f"TRUNCATE TABLE IF EXISTS {t.qualified};", text)

    def test_every_step_is_independently_runnable(self):
        for name in SQL_SOURCES[1:] + ["99_reset_demo.sql"]:
            text = (ROOT / "sql" / name).read_text(encoding="utf-8")
            code = [l for l in text.splitlines() if l.strip() and not l.strip().startswith("--")]
            self.assertTrue(
                code[0].startswith(("USE DATABASE PUSAT_INFORMASI_PAROKI", "CREATE DATABASE")),
                f"{name} must start by selecting the database")

    def test_sql_files_are_plain_ascii(self):
        """Pasting into a browser editor must not mangle anything."""
        for path in (ROOT / "sql").glob("*.sql"):
            data = path.read_bytes()
            self.assertEqual(data.decode("ascii", errors="replace").count("\ufffd"), 0, f"{path.name} contains non-ASCII bytes")
            self.assertNotIn(b"\r", data, f"{path.name} contains carriage returns")

    def test_no_warehouse_or_role_is_assumed(self):
        for path in (ROOT / "sql").glob("*.sql"):
            code = "\n".join(l for l in path.read_text(encoding="utf-8").splitlines() if not l.strip().startswith("--"))
            self.assertNotRegex(code, r"USE\s+(WAREHOUSE|ROLE)", path.name)

    def test_no_secrets_or_account_details_in_the_repository(self):
        patterns = [r"-----BEGIN [A-Z ]*PRIVATE KEY", r"(?i)\bpassword\s*[=:]\s*['\"]?\w", r"(?i)\btoken\s*[=:]\s*['\"]?\w{12,}",
                    r"[a-z0-9-]+\.snowflakecomputing\.com", r"(?i)api[_-]?key\s*[=:]\s*['\"]?\w{12,}"]
        for path in ROOT.rglob("*"):
            relative = path.relative_to(ROOT)
            if not path.is_file() or relative.parts[0] in (".git", "archive", "__pycache__") or "__pycache__" in relative.parts:
                continue
            if path.suffix.lower() not in (".sql", ".py", ".md", ".txt", ".toml", ".yml", ".yaml", ".json", ".gitignore", ""):
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for pattern in patterns:
                self.assertIsNone(re.search(pattern, text), f"{relative} matches secret pattern {pattern}")

    def test_statements_split_cleanly(self):
        """No semicolon may hide inside a comment or string, or naive splitters break.
        00_setup.sql is exempt: it holds a commented-out example statement on purpose."""
        for name in SQL_SOURCES[1:]:
            text = (ROOT / "sql" / name).read_text(encoding="utf-8")
            for line in text.splitlines():
                if line.strip().startswith("--"):
                    self.assertNotIn(";", line, f"{name}: semicolon inside a comment: {line}")
            code = "\n".join(l for l in text.splitlines() if not l.strip().startswith("--"))
            self.assertEqual(len(re.findall(r";\s*$", code, re.MULTILINE)), code.count(";"), f"{name}: stray semicolon")

    def test_views_are_labelled_and_expose_no_personal_columns(self):
        views = (ROOT / "sql" / "05_create_views.sql").read_text(encoding="utf-8")
        names = re.findall(r"CREATE OR REPLACE VIEW ANALISIS\.(\w+)", views)
        self.assertGreaterEqual(len(names), 7)
        self.assertEqual(len(re.findall(r"CREATE OR REPLACE VIEW ANALISIS\.\w+\s+COMMENT = '", views)), len(names))
        self.assertEqual(views.count("AS SUMBER_DATA"), len(names))
        selects = re.sub(r"COUNT\(DISTINCT [^)]*\)", "", views)
        for forbidden in ("NAMA_FIKTIF", "NAMA_KELUARGA_FIKTIF", "TAHUN_LAHIR"):
            self.assertNotIn(forbidden, selects)


class DocumentationTests(GeneratorTestCase):
    def test_er_diagrams_match_the_declared_foreign_keys(self):
        """Every foreign key is drawn, and every solid line is a real foreign key."""
        text = (ROOT / "docs" / "DATA_MODEL.md").read_text(encoding="utf-8")
        blocks = re.findall(r"```mermaid\n(.*?)```", text, re.DOTALL)
        self.assertGreaterEqual(len(blocks), 5)
        drawn = set()
        for block in blocks:
            for parent, child in re.findall(r"^\s*(\w+)\s+\S+--\S+\s+(\w+)\s*:", block, re.MULTILINE):
                drawn.add((parent, child))
        declared = {(fk.ref_table, t.name) for t in self.tables for fk in t.foreign_keys}
        self.assertEqual(declared - drawn, set(), "foreign keys missing from the diagrams")
        self.assertEqual(drawn - declared, set(), "diagram lines that are not foreign keys")

    def test_every_table_is_named_in_the_data_model_document(self):
        text = (ROOT / "docs" / "DATA_MODEL.md").read_text(encoding="utf-8")
        for t in self.tables:
            self.assertIn(f"`{t.name}`", text, t.name)

    def test_readme_links_point_at_existing_files(self):
        for document in (ROOT / "README.md", ROOT / "docs" / "SETUP_SNOWFLAKE.md", ROOT / "docs" / "DATA_MODEL.md"):
            text = document.read_text(encoding="utf-8")
            for target in re.findall(r"\]\(([^)#]+?)(?:#[^)]*)?\)", text):
                if target.startswith(("http://", "https://", "mailto:")):
                    continue
                self.assertTrue((document.parent / target).exists(), f"{document.name}: broken link {target}")


class CsvExportTests(GeneratorTestCase):
    def test_csv_export_matches_the_ddl(self):
        for t in self.tables:
            text = sqlwriter.csv_text(t, self.data[t.qualified])
            lines = text.splitlines()
            self.assertEqual(lines[0].split(","), t.column_names)
            self.assertGreaterEqual(len(lines), 2)

    def test_command_line_check_passes(self):
        import subprocess
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_mock_data.py"), "--check"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_command_line_csv_export(self):
        import subprocess
        with tempfile.TemporaryDirectory() as folder:
            before = (ROOT / "sql" / "04_load_mock_data.sql").read_bytes()
            result = subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_mock_data.py"), "--csv-dir", folder],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(list(Path(folder).glob("*.csv"))), 33)
            self.assertEqual(before, (ROOT / "sql" / "04_load_mock_data.sql").read_bytes(), "regeneration must be stable")


if __name__ == "__main__":
    unittest.main()
