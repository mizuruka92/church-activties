"""Tests for the synthetic data generator and the committed generated files.

Run with the standard library only:   python -m unittest discover -s tests -v
"""

import copy
import re
import sys
import tempfile
import unittest
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from mockdata import build, checks, config, dictionary, sqlwriter  # noqa: E402
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
        self.assertEqual(len(self.tables), 38)
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
        self.assertLess(total, 20000)
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


def _linear_fit(xs, ys):
    mean_x, mean_y = sum(xs) / len(xs), sum(ys) / len(ys)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / sum((x - mean_x) ** 2 for x in xs)
    return slope, mean_y - slope * mean_x


def _median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


class UseCaseStoryTests(GeneratorTestCase):
    """The demo is built to tell specific stories. These tests keep them true when the
    generator is retuned: a failure here means the story broke, not that data is invalid."""

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        d = cls.data
        cls.occurrence = {o["ID_KEJADIAN_MISA"]: o for o in d["DATA_OPERASIONAL.KEJADIAN_MISA"]}
        cls.attendance = {a["ID_KEJADIAN_MISA"]: a for a in d["DATA_OPERASIONAL.KEHADIRAN_MISA"]}
        best = {}
        for c in d["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"]:
            amount = c["JUMLAH_HASIL_PENGHITUNGAN"] if c["JUMLAH_HASIL_PENGHITUNGAN"] is not None else c["JUMLAH_PENERIMAAN"]
            best[c["ID_KEJADIAN_MISA"]] = best.get(c["ID_KEJADIAN_MISA"], 0) + amount
        cls.offertory_per_mass = best
        cls.years = range(2021, 2026)

        plan_year = {p["ID_RENCANA"]: p["TANGGAL_RENCANA"].year for p in d["DATA_OPERASIONAL.RENCANA_KEGIATAN"]}
        allocation_plan = {a["ID_ALOKASI"]: a["ID_RENCANA"] for a in d["DATA_OPERASIONAL.ALOKASI_ANGGARAN"]}
        cls.spent_by_year, cls.spent_by_plan = {}, {}
        for x in d["DATA_OPERASIONAL.REALISASI_PENGELUARAN"]:
            year = x["TANGGAL_PENGELUARAN"].year
            cls.spent_by_year[year] = cls.spent_by_year.get(year, 0) + x["JUMLAH_PENGELUARAN"]
            plan = allocation_plan[x["ID_ALOKASI"]]
            cls.spent_by_plan[plan] = cls.spent_by_plan.get(plan, 0) + x["JUMLAH_PENGELUARAN"]
        cls.plan_year = plan_year
        cls.offertory_by_year = {}
        for occ_id, amount in best.items():
            year = cls.occurrence[occ_id]["TANGGAL_MISA"].year
            cls.offertory_by_year[year] = cls.offertory_by_year.get(year, 0) + amount

    def test_history_covers_at_least_five_years(self):
        first = min(o["TANGGAL_MISA"] for o in self.occurrence.values())
        self.assertLessEqual(first, date(2021, 1, 8))
        self.assertGreaterEqual((config.AS_OF - first).days, 5 * 365)
        self.assertEqual(min(h["TAHUN_RENCANA"] for h in self.data["DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN"]), 2021)

    def test_underlying_offertory_growth_keeps_slowing(self):
        """Per held Mass, outside event windows, the year-on-year growth shrinks every year."""
        average = {}
        for occ_id, amount in self.offertory_per_mass.items():
            if self.attendance[occ_id]["ID_PERISTIWA"] is None:
                year = self.occurrence[occ_id]["TANGGAL_MISA"].year
                average.setdefault(year, []).append(amount)
        means = {y: sum(v) / len(v) for y, v in average.items()}
        growth = [means[y] / means[y - 1] - 1 for y in range(2022, 2026)]
        early, late = (growth[0] + growth[1]) / 2, (growth[2] + growth[3]) / 2
        self.assertGreater(early, late + 0.025, f"growth must clearly slow down: {growth}")
        self.assertGreater(growth[0], 0.04)
        self.assertLess(growth[-1], 0.02)
        self.assertGreater(growth[0], growth[-1] + 0.03)

    def test_offertory_is_highest_right_after_salary_day(self):
        totals = {}
        for occ_id, amount in self.offertory_per_mass.items():
            day = self.occurrence[occ_id]["TANGGAL_MISA"]
            if day.year in self.years:
                bucket = 0 if day.day <= 7 else (2 if day.day >= 22 else 1)
                num, den = totals.get((day.year, bucket), (0, 0))
                totals[(day.year, bucket)] = (num + amount, den + self.attendance[occ_id]["JUMLAH_UMAT"])
        for year in self.years:
            first = totals[(year, 0)][0] / totals[(year, 0)][1]
            last = totals[(year, 2)][0] / totals[(year, 2)][1]
            self.assertGreater(first / last, 1.25, f"{year}: first week should pay clearly more per attendee than the last")

    def test_offertory_follows_attendance_linearly(self):
        xs, ys = [], []
        for c in self.data["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"]:
            occurrence = self.occurrence[c["ID_KEJADIAN_MISA"]]
            if occurrence["ID_JADWAL_MISA"] == "JDW-04" and c["ID_JENIS_KOLEKTE"] == "KOL-01":
                xs.append(self.attendance[c["ID_KEJADIAN_MISA"]]["JUMLAH_UMAT"])
                ys.append(c["JUMLAH_PENERIMAAN"])
        mean_x, mean_y = sum(xs) / len(xs), sum(ys) / len(ys)
        r = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / (
            sum((x - mean_x) ** 2 for x in xs) * sum((y - mean_y) ** 2 for y in ys)) ** 0.5
        self.assertGreater(r, 0.75)

    def test_unforeseen_events_lower_attendance_and_the_log_explains_them(self):
        severity_effect = {"Ringan": [], "Sedang": [], "Berat": []}
        for event in self.data["DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA"]:
            inside, before = [], []
            for occ_id, a in self.attendance.items():
                occurrence = self.occurrence[occ_id]
                if occurrence["ID_JADWAL_MISA"] == "JDW-07":
                    continue
                day = occurrence["TANGGAL_MISA"]
                if event["TANGGAL_MULAI"] <= day <= event["TANGGAL_SELESAI"]:
                    inside.append(a["JUMLAH_UMAT"])
                elif event["TANGGAL_MULAI"] - timedelta(days=56) <= day < event["TANGGAL_MULAI"]:
                    before.append(a["JUMLAH_UMAT"])
            ratio = (sum(inside) / len(inside)) / (sum(before) / len(before))
            self.assertLess(ratio, 0.93, f"{event['ID_PERISTIWA']} should visibly lower attendance")
            severity_effect[event["TINGKAT_GANGGUAN"]].append(ratio)
        mean = {k: sum(v) / len(v) for k, v in severity_effect.items()}
        self.assertLess(mean["Berat"], mean["Sedang"])
        self.assertLess(mean["Sedang"], mean["Ringan"])

    def test_the_log_does_not_reveal_the_size_of_the_effect(self):
        columns = self.by_name["DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA"].column_names
        for word in ("PERSEN", "FAKTOR", "DAMPAK", "PENGARUH"):
            self.assertFalse([c for c in columns if word in c], "the effect must be discovered, not stored")

    def test_spending_rises_every_year_and_so_does_the_cost_per_activity(self):
        spent = [self.spent_by_year[y] for y in self.years]
        self.assertTrue(all(a < b for a, b in zip(spent, spent[1:])), spent)
        count = {}
        for plan, year in self.plan_year.items():
            if year in self.years:
                count[year] = count.get(year, 0) + 1
        per_plan = [spent[i] / count[y] for i, y in enumerate(self.years)]
        self.assertTrue(all(a < b for a, b in zip(per_plan, per_plan[1:])), per_plan)
        self.assertTrue(all(count[a] < count[b] for a, b in zip(list(self.years), list(self.years)[1:])))

    def test_income_is_bigger_than_outcome_today_but_the_trendlines_cross_within_about_three_years(self):
        for year in self.years:
            self.assertGreater(self.offertory_by_year[year], self.spent_by_year[year], year)
        year_to_date = sum(a for o, a in self.offertory_per_mass.items() if self.occurrence[o]["TANGGAL_MISA"].year == 2026)
        self.assertGreater(year_to_date, self.spent_by_year[2026])
        years = list(self.years)
        slope_o, icpt_o = _linear_fit(years, [self.offertory_by_year[y] for y in years])
        slope_s, icpt_s = _linear_fit(years, [self.spent_by_year[y] for y in years])
        self.assertGreater(slope_s, 3 * slope_o, "spending must grow much faster than the offertory")
        cross = next(y for y in range(2026, 2040) if slope_s * y + icpt_s > slope_o * y + icpt_o)
        self.assertIn(cross, (2028, 2029, 2030), f"trendlines cross in {cross}")

    def test_poorer_communities_give_less_but_one_regular_large_donor_lifts_their_mean(self):
        gifts = self.data["DATA_OPERASIONAL.SUMBANGAN_KELUARGA"]
        profile = {r["ID_LINGKUNGAN"]: r for r in self.data["MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN"]}
        campaign = next(c["ID_KAMPANYE"] for c in self.data["DATA_OPERASIONAL.KAMPANYE_SUMBANGAN"]
                        if c["NAMA_KAMPANYE"] == "Aksi Puasa Pembangunan 2025")
        by_community = {}
        for g in gifts:
            if g["ID_KAMPANYE"] == campaign:
                by_community.setdefault(g["ID_LINGKUNGAN"], []).append(g["JUMLAH_SUMBANGAN"])
        median = {c: _median(v) for c, v in by_community.items()}
        mean = {c: sum(v) / len(v) for c, v in by_community.items()}
        share = {c: max(v) / sum(v) for c, v in by_community.items()}
        category = {c: profile[c]["KATEGORI_EKONOMI"] for c in by_community}
        low = [c for c in by_community if category[c] == "Rendah"]
        high = [c for c in by_community if category[c] == "Tinggi"]
        self.assertTrue(low and high)
        self.assertLess(max(median[c] for c in low), min(median[c] for c in high), "medians must show the gap")
        outliers = [c for c in low if mean[c] / median[c] >= 1.4 and share[c] >= 0.4]
        self.assertGreaterEqual(len(outliers), 3, "most poorer communities should have a dominant regular donor")
        mid_low = [c for c in by_community if category[c] == "Menengah Bawah" and mean[c] / median[c] < 1.2]
        self.assertTrue(any(mean[o] >= mean[m] for o in outliers for m in mid_low),
                        "the outlier must lift a poor community mean up to the level of better-off ones")
        top_high = [c for c in high if share[c] < 0.3]
        self.assertTrue(all(mean[c] / median[c] < 1.2 for c in top_high), "no outlier in the richer communities")

    def test_total_per_household_and_median_tell_different_stories(self):
        gifts = self.data["DATA_OPERASIONAL.SUMBANGAN_KELUARGA"]
        campaign = next(c["ID_KAMPANYE"] for c in self.data["DATA_OPERASIONAL.KAMPANYE_SUMBANGAN"]
                        if c["NAMA_KAMPANYE"] == "Aksi Puasa Pembangunan 2025")
        by_community = {}
        for g in gifts:
            if g["ID_KAMPANYE"] == campaign:
                by_community.setdefault(g["ID_LINGKUNGAN"], []).append(g["JUMLAH_SUMBANGAN"])
        by_total = sorted(by_community, key=lambda c: sum(by_community[c]))
        by_median = sorted(by_community, key=lambda c: _median(by_community[c]))
        by_mean = sorted(by_community, key=lambda c: sum(by_community[c]) / len(by_community[c]))
        self.assertNotEqual(by_total, by_median)
        self.assertNotEqual(by_mean, by_median)

    def test_easter_stays_close_to_break_even_and_christmas_turns_into_a_deficit(self):
        campaigns = {c["ID_KAMPANYE"]: c for c in self.data["DATA_OPERASIONAL.KAMPANYE_SUMBANGAN"]}
        collected = {}
        for g in self.data["DATA_OPERASIONAL.SUMBANGAN_KELUARGA"]:
            collected[g["ID_KAMPANYE"]] = collected.get(g["ID_KAMPANYE"], 0) + g["JUMLAH_SUMBANGAN"]
        net = {"KSK-01": {}, "KSK-02": {}}
        for cid, campaign in campaigns.items():
            plan = campaign["ID_RENCANA_PENGGUNAAN"]
            if campaign["ID_KESEMPATAN"] in net and cid in collected:
                net[campaign["ID_KESEMPATAN"]][campaign["PERIODE_MULAI"].year] = collected[cid] - self.spent_by_plan[plan]
        easter, christmas = net["KSK-01"], net["KSK-02"]
        self.assertTrue(all(v > 0 for v in easter.values()), easter)
        self.assertGreater(easter[2021], easter[2026], "the Easter surplus shrinks")
        self.assertLess(easter[2026], 0.15 * collected[next(c for c, x in campaigns.items() if x["NAMA_KAMPANYE"] == "Aksi Puasa Pembangunan 2026")])
        self.assertGreater(christmas[2021], 0, "Christmas starts with a surplus")
        deficit_years = [y for y in sorted(christmas) if christmas[y] < 0]
        self.assertTrue(deficit_years and deficit_years[0] in (2023, 2024), deficit_years)
        self.assertEqual(deficit_years, list(range(deficit_years[0], 2026)), "once in deficit, it stays in deficit")
        self.assertTrue(all(christmas[a] > christmas[b] for a, b in zip(range(2021, 2025), range(2022, 2026))))


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
            before = (ROOT / "sql" / "04b_load_offertory.sql").read_bytes()
            result = subprocess.run([sys.executable, str(ROOT / "scripts" / "generate_mock_data.py"), "--csv-dir", folder],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(list(Path(folder).glob("*.csv"))), len(build.load_tables(DDL_PATH)))
            self.assertEqual(before, (ROOT / "sql" / "04b_load_offertory.sql").read_bytes(), "regeneration must be stable")


if __name__ == "__main__":
    unittest.main()
