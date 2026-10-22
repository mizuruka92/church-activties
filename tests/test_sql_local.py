"""Local SQL tests: run the real project SQL files against DuckDB.

This is NOT Snowflake. A pass here shows that the SQL is logically consistent and
that the validation script really detects problems. It does not prove that every
keyword is accepted by Snowflake. Execution in Snowflake must be verified by the
person running the setup (see README.md).

Needs the optional packages in tests/requirements.txt; the tests skip without them.
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(ROOT / "tests"))

try:
    import duckdb  # noqa: F401
    HAVE_DUCKDB = True
except ImportError:  # pragma: no cover
    HAVE_DUCKDB = False

try:
    import sqlglot
    HAVE_SQLGLOT = True
except ImportError:  # pragma: no cover
    HAVE_SQLGLOT = False

from mockdata import build, validation  # noqa: E402

if HAVE_DUCKDB:
    import duckdb_shim as shim

TABLES = build.load_tables(ROOT / "sql" / "02_create_tables.sql")
DATA = build.build_all()
LOAD_FILES = ["01_create_schemas.sql", "02_create_tables.sql", "03_load_reference_data.sql",
              "04_load_mock_data.sql", "05_create_views.sql"]


def count(connection, table):
    return connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]


def validate(connection):
    """Run sql/06 and return {(group, name, object): row}."""
    rows = shim.run_file(connection, "06_validate_data.sql")
    return rows, {(r["CHECK_GROUP"], r["CHECK_NAME"], r["OBJECT_NAME"]): r for r in rows}


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class LoadTests(unittest.TestCase):
    def test_load_order_and_keys_hold_when_the_engine_enforces_them(self):
        """DuckDB enforces PK, UNIQUE and same-schema FK, which proves the load order."""
        connection = shim.build_database(keep_constraints=True)
        for table in TABLES:
            self.assertEqual(count(connection, table.qualified), len(DATA[table.qualified]), table.qualified)

    def test_rerunning_the_load_does_not_duplicate_rows(self):
        connection = shim.build_database(keep_constraints=False)
        before = {t.qualified: count(connection, t.qualified) for t in TABLES}
        for name in ["01_create_schemas.sql", "02_create_tables.sql", "03_load_reference_data.sql", "04_load_mock_data.sql",
                     "03_load_reference_data.sql", "04_load_mock_data.sql"]:
            shim.run_file(connection, name, keep_constraints=False)
        after = {t.qualified: count(connection, t.qualified) for t in TABLES}
        self.assertEqual(before, after)

    def test_rerunning_the_load_repairs_changed_rows(self):
        connection = shim.build_database(keep_constraints=False)
        connection.execute("UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET JUMLAH_UMAT = 1 WHERE ID_KEHADIRAN = 'KHD-000001'")
        shim.run_file(connection, "04_load_mock_data.sql", keep_constraints=False)
        value = connection.execute(
            "SELECT JUMLAH_UMAT FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEHADIRAN = 'KHD-000001'").fetchone()[0]
        expected = next(r["JUMLAH_UMAT"] for r in DATA["DATA_OPERASIONAL.KEHADIRAN_MISA"] if r["ID_KEHADIRAN"] == "KHD-000001")
        self.assertEqual(value, expected)

    def test_each_step_runs_on_its_own_after_its_prerequisites(self):
        connection = duckdb.connect(":memory:")
        shim.run_file(connection, "01_create_schemas.sql")
        shim.run_file(connection, "02_create_tables.sql")
        shim.run_file(connection, "02_create_tables.sql")  # CREATE ... IF NOT EXISTS is repeatable
        shim.run_file(connection, "03_load_reference_data.sql")
        shim.run_file(connection, "04_load_mock_data.sql")
        shim.run_file(connection, "05_create_views.sql")
        shim.run_file(connection, "05_create_views.sql")  # CREATE OR REPLACE VIEW is repeatable
        rows, _ = validate(connection)
        self.assertEqual(sum(1 for r in rows if r["RESULT"] == "FAIL"), 0)

    def test_full_setup_script_gives_the_same_result_as_the_separate_steps(self):
        connection = duckdb.connect(":memory:")
        text = (ROOT / "sql" / "full_setup.sql").read_text(encoding="utf-8")
        last = None
        for statement in shim.split_statements(text):
            translated = shim.translate(statement)
            if translated is None:
                continue
            cursor = connection.execute(translated)
            if translated.lstrip().upper().startswith(("SELECT", "WITH")):
                columns = [d[0] for d in cursor.description]
                last = [dict(zip(columns, row)) for row in cursor.fetchall()]
        self.assertIsNotNone(last)
        results = [r["RESULT"] for r in last]
        self.assertEqual(results.count("FAIL"), 0)
        self.assertEqual(results.count("WARN"), 1)
        for table in TABLES:
            self.assertEqual(count(connection, table.qualified), len(DATA[table.qualified]))


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class ValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)
        cls.rows, cls.by_key = validate(cls.connection)

    def test_baseline_has_no_failures_and_exactly_the_expected_warning(self):
        failures = [r for r in self.rows if r["RESULT"] == "FAIL"]
        self.assertEqual(failures, [])
        warnings = [r for r in self.rows if r["RESULT"] == "WARN" and r["CHECK_GROUP"] != "SUMMARY"]
        self.assertEqual([w["CHECK_NAME"] for w in warnings], ["Report participants differ from the event"])

    def test_summary_rows_come_first(self):
        self.assertEqual([r["CHECK_GROUP"] for r in self.rows[:2]], ["SUMMARY", "SUMMARY"])
        self.assertEqual(self.rows[0]["FOUND_COUNT"], 0)

    def test_row_counts_match_the_generated_data(self):
        for table in TABLES:
            row = self.by_key[("STRUCTURE", "Row count", table.qualified)]
            self.assertEqual(row["FOUND_COUNT"], len(DATA[table.qualified]))
            self.assertEqual(row["RESULT"], "PASS")

    def test_every_table_key_reference_and_vocabulary_is_checked(self):
        keys = set(self.by_key)
        for table in TABLES:
            self.assertIn(("KEYS", "Duplicate primary key", table.qualified), keys)
            for name, _ in table.unique_keys:
                self.assertIn(("KEYS", f"Duplicate unique key {name}", table.qualified), keys)
            for fk in table.foreign_keys:
                self.assertIn(("REFERENCES", "Orphaned reference",
                               f"{table.qualified}.{'+'.join(fk.columns)} -> {fk.ref_table}"), keys)
        from mockdata.vocab import NILAI_TERKENDALI
        for table, column, group in NILAI_TERKENDALI:
            self.assertIn(("VOCABULARY", f"Value not in list {group}", f"{table}.{column}"), keys)

    def test_every_view_is_checked(self):
        views = validation.view_names((ROOT / "sql" / "05_create_views.sql").read_text(encoding="utf-8"))
        self.assertEqual(len(views), 13)
        for view in views:
            self.assertEqual(self.by_key[("VIEWS", "View returns rows", f"ANALISIS.{view}")]["RESULT"], "PASS")

    def test_deliberate_scenarios_are_reported_as_info(self):
        info = {r["CHECK_NAME"] for r in self.rows if r["RESULT"] == "INFO"}
        for expected in ("Offertory with open reconciliation", "Attendance waiting for validation or recheck",
                         "Completed events without a report", "Allocations partly used", "Allocations spent above budget",
                         "Surveys without responses", "Postponed or cancelled plans", "Cancelled Mass occurrences",
                         "Households with a community history"):
            self.assertIn(expected, info)
            self.assertGreater(next(r["FOUND_COUNT"] for r in self.rows if r["CHECK_NAME"] == expected), 0)


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class MutationTests(unittest.TestCase):
    """Corrupt the loaded data inside a transaction and check that the validation
    script raises exactly the intended alarm. Each test is rolled back."""

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)

    def failing(self, statements):
        connection = self.connection
        connection.execute("BEGIN TRANSACTION")
        try:
            for statement in ([statements] if isinstance(statements, str) else statements):
                connection.execute(statement)
            rows, _ = validate(connection)
        finally:
            connection.execute("ROLLBACK")
        return {(r["CHECK_GROUP"], r["CHECK_NAME"]) for r in rows if r["RESULT"] == "FAIL" and r["CHECK_GROUP"] != "SUMMARY"}, rows

    def assertDetected(self, statements, group, name):
        failed, rows = self.failing(statements)
        self.assertIn((group, name), failed, f"{name} was not detected. Failed checks: {sorted(failed)}")
        summary = next(r for r in rows if r["CHECK_GROUP"] == "SUMMARY")
        self.assertEqual(summary["RESULT"], "FAIL")

    def test_baseline_is_clean_after_rollback(self):
        failed, _ = self.failing("SELECT 1")
        self.assertEqual(failed, set())

    def test_duplicate_primary_key(self):
        self.assertDetected("INSERT INTO MASTER_DATA.MASTER_WILAYAH SELECT * FROM MASTER_DATA.MASTER_WILAYAH WHERE ID_WILAYAH = 'WIL-01'",
                            "KEYS", "Duplicate primary key")

    def test_duplicate_unique_key(self):
        self.assertDetected(
            "INSERT INTO DATA_OPERASIONAL.KEHADIRAN_MISA SELECT 'KHD-999999', ID_KEJADIAN_MISA, JUMLAH_UMAT, METODE_PENGHITUNGAN, "
            "STATUS_VALIDASI, WAKTU_PENCATATAN, KETERANGAN FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEHADIRAN = 'KHD-000001'",
            "KEYS", "Duplicate unique key UQ_KEHADIRAN_MISA_KEJADIAN")

    def test_orphaned_reference(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET ID_KEJADIAN_MISA = 'MIS-999999' WHERE ID_KEHADIRAN = 'KHD-000001'",
                            "REFERENCES", "Orphaned reference")

    def test_negative_amount(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PENERIMAAN_KOLEKTE SET JUMLAH_PENERIMAAN = -500 WHERE ID_KOLEKTE = 'KLK-000001'",
                            "NUMBERS", "Negative numeric value")

    def test_unknown_status_label(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET STATUS_VALIDASI = 'Valid' WHERE ID_KEHADIRAN = 'KHD-000001'",
                            "VOCABULARY", "Value not in list STATUS_VALIDASI")

    def test_implausible_dates(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.UMAT SET TAHUN_LAHIR = 1850 WHERE ID_UMAT = 'UMT-00001'",
                            "DATES", "Birth year implausible or registration before birth")
        self.assertDetected("UPDATE DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN SET TANGGAL_MULAI_BERLAKU = DATE '1980-01-01' "
                            "WHERE ID_PENUGASAN_LINGKUNGAN = 'PLG-0001'", "DATES", "Date outside 2000-2027")
        self.assertDetected("UPDATE DATA_OPERASIONAL.REALISASI_PENGELUARAN SET TANGGAL_PENGELUARAN = DATE '2026-12-01' "
                            "WHERE ID_PENGELUARAN = 'PGL-0001'", "DATES", "Expenditure after the as-of date")

    def test_attendance_for_a_cancelled_mass(self):
        self.assertDetected(
            "UPDATE DATA_OPERASIONAL.KEJADIAN_MISA SET STATUS_PELAKSANAAN = 'Dibatalkan', WAKTU_MULAI_AKTUAL = NULL, "
            "WAKTU_SELESAI_AKTUAL = NULL WHERE ID_KEJADIAN_MISA = 'MIS-000001'",
            "MASS", "Attendance for a Mass that was not held")

    def test_mass_on_the_wrong_weekday(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.KEJADIAN_MISA SET TANGGAL_MISA = TANGGAL_MISA + 1 WHERE ID_KEJADIAN_MISA = 'MIS-000002'",
                            "MASS", "Occurrence weekday differs from schedule")

    def test_held_mass_without_offertory(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE ID_KEJADIAN_MISA = 'MIS-000002'",
                            "MASS", "Held Mass without offertory")

    def test_reconciliation_status_contradicts_amounts(self):
        self.assertDetected(
            "UPDATE DATA_OPERASIONAL.PENERIMAAN_KOLEKTE SET STATUS_REKONSILIASI = 'Sudah Cocok', "
            "JUMLAH_HASIL_PENGHITUNGAN = JUMLAH_PENERIMAAN + 1000 WHERE ID_KOLEKTE = 'KLK-000001'",
            "MASS", "Sudah Cocok but recorded and counted differ")

    def test_household_assigned_to_two_communities_at_once(self):
        self.assertDetected(
            "INSERT INTO DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN VALUES ('PLG-9999', 'KEL-0001', 'LNG-02', DATE '2020-01-01', NULL)",
            "PARISHIONERS", "Overlapping community assignments of one household")

    def test_person_in_two_households_at_once(self):
        self.assertDetected(
            "INSERT INTO DATA_OPERASIONAL.PENUGASAN_KELUARGA VALUES ('PKL-99999', 'UMT-00001', 'KEL-0002', 'Anak', DATE '2020-01-01', NULL)",
            "PARISHIONERS", "Overlapping household assignments of one person")

    def test_personal_data_must_not_be_public(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.UMAT SET ID_KLASIFIKASI_DATA = 'KLS-01' WHERE ID_UMAT = 'UMT-00001'",
                            "GOVERNANCE", "Personal data not classified Terbatas or stricter")

    def test_a_view_that_leaks_names_is_caught(self):
        self.assertDetected("CREATE VIEW ANALISIS.BOCOR AS SELECT NAMA_FIKTIF FROM DATA_OPERASIONAL.UMAT",
                            "GOVERNANCE", "Personal-data columns exposed in ANALISIS")

    def test_event_and_plan_disagree(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.KEGIATAN SET STATUS_KEGIATAN = 'Dibatalkan' WHERE ID_KEGIATAN = 'KGT-001'",
                            "PLANNING", "Event status differs from its plan status")

    def test_completed_plan_loses_its_event(self):
        self.assertDetected(["DELETE FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE ID_KEGIATAN = 'KGT-001'",
                             "DELETE FROM DATA_OPERASIONAL.KEGIATAN WHERE ID_KEGIATAN = 'KGT-001'"],
                            "PLANNING", "Completed plan without an event")

    def test_final_report_with_gaps(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET HASIL_KEGIATAN = NULL WHERE ID_LAPORAN = 'LPK-001'",
                            "PLANNING", "Final report with empty required fields")

    def test_spending_after_the_snapshot_date(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.REALISASI_PENGELUARAN SET TANGGAL_PENGELUARAN = DATE '2026-11-15' WHERE ID_PENGELUARAN = 'PGL-0001'",
                            "DATES", "Expenditure after the as-of date")

    def test_survey_counts_tampered(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT SET JUMLAH_RESPONDEN = JUMLAH_RESPONDEN + 5 WHERE ID_HASIL = 'HSL-010101'",
                            "SURVEYS", "Aggregate count differs from the answers")

    def test_survey_percentage_tampered(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT SET PERSENTASE_JAWABAN = 99.99 WHERE ID_HASIL = 'HSL-010101'",
                            "SURVEYS", "Percentage differs from count divided by total")

    def test_answer_for_an_option_of_another_question(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.JAWABAN_SURVEI SET ID_OPSI = 'OPS-020101' WHERE ID_JAWABAN = 'JWB-00001'",
                            "SURVEYS", "Answer option does not belong to the question")

    def test_new_answers_without_a_summary_are_caught(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE ID_PERTANYAAN = 'PRT-0101'",
                            "SURVEYS", "Answered question without aggregate rows")

    def test_an_empty_table_fails_the_row_count(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.KELUARGA", "STRUCTURE", "Row count")


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class ViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)

    def value(self, sql):
        return self.connection.execute(sql).fetchone()[0]

    def test_monthly_attendance_adds_up_to_the_attendance_table(self):
        total = self.value("SELECT SUM(a.JUMLAH_UMAT) FROM DATA_OPERASIONAL.KEHADIRAN_MISA a")
        self.assertEqual(self.value("SELECT SUM(TOTAL_UMAT) FROM ANALISIS.KEHADIRAN_MISA_BULANAN"), total)
        self.assertEqual(self.value("SELECT SUM(TOTAL_UMAT) FROM ANALISIS.TREN_KEHADIRAN_PERIODE"), total)

    def test_monthly_offertory_adds_up_to_the_offertory_table(self):
        recorded = self.value("SELECT SUM(JUMLAH_PENERIMAAN) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE")
        counted = self.value("SELECT SUM(JUMLAH_HASIL_PENGHITUNGAN) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE")
        self.assertEqual(self.value("SELECT SUM(TOTAL_TERCATAT) FROM ANALISIS.KOLEKTE_MISA_BULANAN"), recorded)
        self.assertEqual(self.value("SELECT SUM(TOTAL_HASIL_PENGHITUNGAN) FROM ANALISIS.KOLEKTE_MISA_BULANAN"), counted)

    def test_the_two_saturday_schedules_form_one_session(self):
        rows = self.connection.execute(
            "SELECT DISTINCT NAMA_MISA FROM ANALISIS.KEHADIRAN_MISA_BULANAN ORDER BY NAMA_MISA").fetchall()
        self.assertEqual([r[0] for r in rows].count("Misa Sabtu Sore"), 1)

    def test_trend_compares_with_the_previous_month(self):
        rows = self.connection.execute(
            "SELECT NAMA_PERIODE, RATA_RATA_BULAN_SEBELUMNYA, PERUBAHAN_PERSEN_RATA_RATA FROM ANALISIS.TREN_KEHADIRAN_PERIODE "
            "ORDER BY TAHUN, BULAN").fetchall()
        self.assertEqual(rows[0][1:], (None, None))
        self.assertTrue(all(r[1] is not None for r in rows[1:]))

    def test_scheduled_and_actual_times_are_distinct(self):
        row = self.connection.execute(
            "SELECT WAKTU_MULAI_JADWAL, WAKTU_MULAI_AKTUAL, SELISIH_MULAI_MENIT, DURASI_AKTUAL_MENIT FROM ANALISIS.PELAKSANAAN_MISA "
            "WHERE ID_KEJADIAN_MISA = 'MIS-000001'").fetchone()
        self.assertIsNotNone(row[1])
        self.assertGreaterEqual(row[2], 0)
        self.assertGreater(row[3], 30)
        self.assertEqual(self.value("SELECT COUNT(*) FROM ANALISIS.PELAKSANAAN_MISA WHERE STATUS_PELAKSANAAN <> 'Terlaksana' "
                                    "AND WAKTU_MULAI_AKTUAL IS NOT NULL"), 0)

    def test_budget_views_match_the_underlying_tables(self):
        budget = self.value("SELECT SUM(JUMLAH_ANGGARAN) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN")
        spent = self.value("SELECT SUM(JUMLAH_PENGELUARAN) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN")
        self.assertEqual(self.value("SELECT SUM(ANGGARAN_RENCANA) FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM"), budget)
        self.assertEqual(self.value("SELECT SUM(ANGGARAN_TERPAKAI) FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM"), spent)
        self.assertEqual(self.value("SELECT SUM(ANGGARAN_SEMUA_PROGRAM) FROM ANALISIS.ANGGARAN_VS_REALISASI_SEKSI"), budget)
        self.assertEqual(self.value("SELECT SUM(ANGGARAN_TERPAKAI_SEMUA_PROGRAM) FROM ANALISIS.ANGGARAN_VS_REALISASI_SEKSI"), spent)
        states = {r[0] for r in self.connection.execute("SELECT DISTINCT STATUS_PENYERAPAN FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM").fetchall()}
        self.assertTrue({"Belum ada pengeluaran", "Terpakai sebagian", "Melebihi anggaran"} <= states)

    def test_events_and_reports_view_covers_every_event(self):
        self.assertEqual(self.value("SELECT COUNT(*) FROM ANALISIS.KEGIATAN_DAN_LAPORAN"), len(DATA["DATA_OPERASIONAL.KEGIATAN"]))
        states = {r[0] for r in self.connection.execute("SELECT DISTINCT STATUS_PELAPORAN FROM ANALISIS.KEGIATAN_DAN_LAPORAN").fetchall()}
        self.assertTrue({"Final", "Draf", "Perlu Revisi", "Belum ada laporan", "Belum diperlukan"} <= states)
        self.assertEqual(self.value("SELECT SUM(JUMLAH_KEGIATAN) FROM ANALISIS.KELENGKAPAN_LAPORAN_PER_SEKSI"),
                         len(DATA["DATA_OPERASIONAL.KEGIATAN"]))

    def test_donation_view_never_ranks_regions(self):
        columns = [r[0] for r in self.connection.execute("DESCRIBE ANALISIS.SUMBANGAN_KHUSUS_PER_WILAYAH").fetchall()]
        for column in columns:
            self.assertNotIn("PERINGKAT", column)
            self.assertNotIn("RANK", column)
        self.assertIn("CATATAN_PENGGUNAAN", columns)

    def test_survey_views(self):
        rows = self.connection.execute(
            "SELECT ID_PERTANYAAN, SUM(PERSENTASE_JAWABAN) FROM ANALISIS.HASIL_SURVEI GROUP BY ID_PERTANYAAN").fetchall()
        self.assertGreater(len(rows), 10)
        for _, total in rows:
            self.assertAlmostEqual(float(total), 100.0, delta=0.1)
        scores = [r[0] for r in self.connection.execute("SELECT SKOR_RATA_RATA FROM ANALISIS.RINGKASAN_SKOR_LIKERT").fetchall()]
        self.assertTrue(scores and all(1 <= float(s) <= 5 for s in scores))
        self.assertEqual(self.value("SELECT COUNT(*) FROM ANALISIS.HASIL_SURVEI WHERE ID_SURVEI = 'SRV-04'"), 0)

    def test_parishioner_summary_is_only_aggregate(self):
        columns = {r[0] for r in self.connection.execute("DESCRIBE ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN").fetchall()}
        self.assertTrue(columns.isdisjoint({"ID_UMAT", "NAMA_FIKTIF", "ID_KELUARGA", "TAHUN_LAHIR"}))
        active = sum(1 for p in DATA["DATA_OPERASIONAL.UMAT"] if p["STATUS_KEANGGOTAAN"] == "Aktif")
        in_view = self.value("SELECT SUM(JUMLAH_UMAT_AKTIF) FROM ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN")
        self.assertLessEqual(in_view, active)
        self.assertGreater(in_view, 0.9 * active)

    def test_no_analisis_view_exposes_personal_columns(self):
        rows = self.connection.execute(
            "SELECT column_name FROM information_schema.columns WHERE UPPER(table_schema) = 'ANALISIS'").fetchall()
        names = {r[0].upper() for r in rows}
        self.assertTrue(names.isdisjoint({"NAMA_FIKTIF", "NAMA_KELUARGA_FIKTIF", "ID_UMAT", "ID_KELUARGA", "TAHUN_LAHIR", "ID_RESPONDEN"}))

    def test_every_view_is_labelled_as_simulated(self):
        views = [r[0] for r in self.connection.execute(
            "SELECT table_name FROM information_schema.tables WHERE UPPER(table_schema) = 'ANALISIS'").fetchall()]
        self.assertEqual(len(views), 13)
        for view in views:
            self.assertEqual(self.value(f"SELECT MIN(SUMBER_DATA) FROM ANALISIS.{view}"), "Data simulasi (fiktif)", view)


@unittest.skipUnless(HAVE_SQLGLOT, "sqlglot is not installed (pip install -r tests/requirements.txt)")
class SnowflakeSyntaxLintTests(unittest.TestCase):
    """A second opinion on syntax using sqlglot's Snowflake grammar. It is a lint,
    not Snowflake itself."""

    def test_all_sql_files_parse_as_snowflake_sql(self):
        expected = {"00_setup.sql": 1, "01_create_schemas.sql": 5, "02_create_tables.sql": 34,
                    "03_load_reference_data.sql": 17, "04_load_mock_data.sql": 18, "05_create_views.sql": 14,
                    "06_validate_data.sql": 2, "full_setup.sql": 1 + 5 + 34 + 17 + 18 + 14 + 2 + 1}
        for name in expected:
            text = (ROOT / "sql" / name).read_text(encoding="utf-8")
            statements = [s for s in sqlglot.parse(text, read="snowflake", error_level=sqlglot.ErrorLevel.RAISE)
                          if s is not None and type(s).__name__ != "Semicolon"]
            self.assertGreaterEqual(len(statements), 1, name)
            kinds = {type(s).__name__ for s in statements}
            self.assertTrue(kinds <= {"Use", "Create", "Merge", "Select", "Command"}, f"{name}: {kinds}")

    def test_statement_counts_match_the_design(self):
        def kinds(name):
            text = (ROOT / "sql" / name).read_text(encoding="utf-8")
            result = {}
            for s in sqlglot.parse(text, read="snowflake"):
                if s is not None:
                    result[type(s).__name__] = result.get(type(s).__name__, 0) + 1
            return result
        self.assertEqual(kinds("02_create_tables.sql")["Create"], 33)
        self.assertEqual(kinds("03_load_reference_data.sql")["Merge"], 16)
        self.assertEqual(kinds("04_load_mock_data.sql")["Merge"], 17)
        self.assertEqual(kinds("05_create_views.sql")["Create"], 13)


if __name__ == "__main__":
    unittest.main()
