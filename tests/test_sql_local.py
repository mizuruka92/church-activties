"""Local SQL tests: run the real project SQL files against DuckDB.

This is NOT Snowflake. A pass here shows that the SQL is logically consistent and
that the validation script really detects problems. It does not prove that every
keyword is accepted by Snowflake. Execution in Snowflake must be verified by the
person running the setup (see README.md).

Needs the optional packages in tests/requirements.txt; the tests skip without them.
"""

import re
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

from mockdata import build, config, validation  # noqa: E402

if HAVE_DUCKDB:
    import duckdb_shim as shim

TABLES = build.load_tables(ROOT / "sql" / "02_create_tables.sql")
DATA = build.build_all()
FIRST_HELD_MASS = next(o["ID_KEJADIAN_MISA"] for o in DATA["DATA_OPERASIONAL.KEJADIAN_MISA"] if o["STATUS_PELAKSANAAN"] == "Terlaksana")
_FINAL_REPORT = next(r for r in DATA["DATA_OPERASIONAL.LAPORAN_KEGIATAN"] if r["STATUS_LAPORAN"] == "Final")
FIRST_FINAL_REPORT = _FINAL_REPORT["ID_LAPORAN"]
FIRST_PLANNED_HELD_EVENT = next(e["ID_KEGIATAN"] for e in DATA["DATA_OPERASIONAL.KEGIATAN"]
                                if e["ID_RENCANA"] and e["STATUS_KEGIATAN"] == "Terlaksana")
FIRST_EXPENDITURE = DATA["DATA_OPERASIONAL.REALISASI_PENGELUARAN"][0]["ID_PENGELUARAN"]
_EVENT_PLANS = {e["ID_RENCANA"] for e in DATA["DATA_OPERASIONAL.KEGIATAN"]}
FIRST_PLAN_ONLY = next(r["ID_RENCANA"] for r in DATA["DATA_OPERASIONAL.RENCANA_KEGIATAN"]
                       if r["STATUS_PELAKSANAAN"] == "Direncanakan" and r["ID_RENCANA"] not in _EVENT_PLANS)
FIRST_ATTENDANCE = next(a["ID_KEHADIRAN"] for a in DATA["DATA_OPERASIONAL.KEHADIRAN_MISA"] if a["ID_KEJADIAN_MISA"] == FIRST_HELD_MASS)
FIRST_OFFERTORY = next(c["ID_KOLEKTE"] for c in DATA["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"] if c["ID_KEJADIAN_MISA"] == FIRST_HELD_MASS)
VIEWS = validation.view_names((ROOT / "sql" / "05_create_views.sql").read_text(encoding="utf-8"))


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
        loads = [name for name in shim.load_files() if name.startswith(("03", "04"))]
        for name in ["01_create_schemas.sql", "02_create_tables.sql"] + loads:
            shim.run_file(connection, name, keep_constraints=False)
        after = {t.qualified: count(connection, t.qualified) for t in TABLES}
        self.assertEqual(before, after)

    def test_rerunning_the_load_repairs_changed_rows(self):
        connection = shim.build_database(keep_constraints=False)
        connection.execute(f"UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET JUMLAH_UMAT = 1 WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'")
        shim.run_file(connection, "04a_load_mass_history.sql", keep_constraints=False)
        value = connection.execute(
            f"SELECT JUMLAH_UMAT FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'").fetchone()[0]
        expected = next(r["JUMLAH_UMAT"] for r in DATA["DATA_OPERASIONAL.KEHADIRAN_MISA"] if r["ID_KEHADIRAN"] == FIRST_ATTENDANCE)
        self.assertEqual(value, expected)

    def test_each_step_runs_on_its_own_after_its_prerequisites(self):
        connection = duckdb.connect(":memory:")
        shim.run_file(connection, "01_create_schemas.sql")
        shim.run_file(connection, "02_create_tables.sql")
        shim.run_file(connection, "02_create_tables.sql")  # CREATE ... IF NOT EXISTS is repeatable
        shim.run_file(connection, "03_load_reference_data.sql")
        for name in sorted(path.name for path in (ROOT / "sql").glob("04*.sql")):
            shim.run_file(connection, name)  # each domain file runs on its own, in order
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
        views = VIEWS
        self.assertGreaterEqual(len(views), 20)
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

    def test_source_file_that_does_not_belong_to_its_report(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET NAMA_BERKAS_SUMBER = 'LPK-9999_salah.pdf' "
                            f"WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}'",
                            "PLANNING", "Source file name does not start with the report number")

    def test_source_file_that_is_not_a_pdf_or_names_a_folder(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET NAMA_BERKAS_SUMBER = ID_LAPORAN || '_laporan.docx' "
                            f"WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}'",
                            "PLANNING", "Source file is not a PDF or names a folder")
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET NAMA_BERKAS_SUMBER = 'data/documents/' || ID_LAPORAN || '_x.pdf' "
                            f"WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}'",
                            "PLANNING", "Source file name does not start with the report number")

    def test_two_reports_cannot_share_one_source_file(self):
        other = next(r["ID_LAPORAN"] for r in DATA["DATA_OPERASIONAL.LAPORAN_KEGIATAN"] if r["ID_LAPORAN"] != FIRST_FINAL_REPORT)
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET NAMA_BERKAS_SUMBER = "
                            f"(SELECT NAMA_BERKAS_SUMBER FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}') "
                            f"WHERE ID_LAPORAN = '{other}'",
                            "KEYS", "Duplicate unique key UQ_LAPORAN_KEGIATAN_BERKAS")

    def test_a_report_without_a_source_document_is_only_a_warning(self):
        failed, rows = self.failing(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET NAMA_BERKAS_SUMBER = NULL WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}'")
        self.assertEqual(failed, set())
        warned = [r for r in rows if r["CHECK_NAME"] == "Reports without a source document"]
        self.assertEqual([(r["RESULT"], r["FOUND_COUNT"]) for r in warned], [("WARN", 1)])

    def test_duplicate_unique_key(self):
        self.assertDetected(
            "INSERT INTO DATA_OPERASIONAL.KEHADIRAN_MISA SELECT 'KHD-999999', ID_KEJADIAN_MISA, JUMLAH_UMAT, METODE_PENGHITUNGAN, "
            f"STATUS_VALIDASI, WAKTU_PENCATATAN, KETERANGAN, ID_PERISTIWA FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'",
            "KEYS", "Duplicate unique key UQ_KEHADIRAN_MISA_KEJADIAN")

    def test_orphaned_reference(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET ID_KEJADIAN_MISA = 'MIS-999999' WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'",
                            "REFERENCES", "Orphaned reference")

    def test_negative_amount(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.PENERIMAAN_KOLEKTE SET JUMLAH_PENERIMAAN = -500 WHERE ID_KOLEKTE = '{FIRST_OFFERTORY}'",
                            "NUMBERS", "Negative numeric value")

    def test_unknown_status_label(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET STATUS_VALIDASI = 'Valid' WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'",
                            "VOCABULARY", "Value not in list STATUS_VALIDASI")

    def test_implausible_dates(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.UMAT SET TAHUN_LAHIR = 1850 WHERE ID_UMAT = 'UMT-00001'",
                            "DATES", "Birth year implausible or registration before birth")
        self.assertDetected("UPDATE DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN SET TANGGAL_MULAI_BERLAKU = DATE '1980-01-01' "
                            "WHERE ID_PENUGASAN_LINGKUNGAN = 'PLG-0001'", "DATES", "Date outside 2000-2030")
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.REALISASI_PENGELUARAN SET TANGGAL_PENGELUARAN = DATE '2026-12-01' "
                            f"WHERE ID_PENGELUARAN = '{FIRST_EXPENDITURE}'", "DATES", "Expenditure after the as-of date")

    def test_attendance_for_a_cancelled_mass(self):
        self.assertDetected(
            "UPDATE DATA_OPERASIONAL.KEJADIAN_MISA SET STATUS_PELAKSANAAN = 'Dibatalkan', WAKTU_MULAI_AKTUAL = NULL, "
            f"WAKTU_SELESAI_AKTUAL = NULL WHERE ID_KEJADIAN_MISA = '{FIRST_HELD_MASS}'",
            "MASS", "Attendance for a Mass that was not held")

    def test_mass_on_the_wrong_weekday(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.KEJADIAN_MISA SET TANGGAL_MISA = TANGGAL_MISA + 1 WHERE ID_KEJADIAN_MISA = '{FIRST_HELD_MASS}'",
                            "MASS", "Occurrence weekday differs from schedule")

    def test_held_mass_without_offertory(self):
        self.assertDetected(f"DELETE FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE ID_KEJADIAN_MISA = '{FIRST_HELD_MASS}'",
                            "MASS", "Held Mass without offertory")

    def test_reconciliation_status_contradicts_amounts(self):
        self.assertDetected(
            "UPDATE DATA_OPERASIONAL.PENERIMAAN_KOLEKTE SET STATUS_REKONSILIASI = 'Sudah Cocok', "
            f"JUMLAH_HASIL_PENGHITUNGAN = JUMLAH_PENERIMAAN + 1000 WHERE ID_KOLEKTE = '{FIRST_OFFERTORY}'",
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
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.KEGIATAN SET STATUS_KEGIATAN = 'Dibatalkan' WHERE ID_KEGIATAN = '{FIRST_PLANNED_HELD_EVENT}'",
                            "PLANNING", "Event status differs from its plan status")

    def test_open_plan_dated_before_the_snapshot_is_warned_not_failed(self):
        failed, rows = self.failing(f"UPDATE DATA_OPERASIONAL.RENCANA_KEGIATAN SET TANGGAL_RENCANA = DATE '2026-09-01' "
                                    f"WHERE ID_RENCANA = '{FIRST_PLAN_ONLY}'")
        self.assertEqual(failed, set())
        warned = [r for r in rows if r["CHECK_NAME"] == "Upcoming activity dated before the snapshot date"]
        self.assertEqual([(r["RESULT"], r["FOUND_COUNT"]) for r in warned], [("WARN", 1)])

    def test_completed_plan_loses_its_event(self):
        self.assertDetected([f"DELETE FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE ID_KEGIATAN = '{FIRST_PLANNED_HELD_EVENT}'",
                             f"DELETE FROM DATA_OPERASIONAL.KEGIATAN WHERE ID_KEGIATAN = '{FIRST_PLANNED_HELD_EVENT}'"],
                            "PLANNING", "Completed plan without an event")

    def test_final_report_with_gaps(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.LAPORAN_KEGIATAN SET HASIL_KEGIATAN = NULL WHERE ID_LAPORAN = '{FIRST_FINAL_REPORT}'",
                            "PLANNING", "Final report with empty required fields")

    def test_spending_after_the_snapshot_date(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.REALISASI_PENGELUARAN SET TANGGAL_PENGELUARAN = DATE '2026-11-15' WHERE ID_PENGELUARAN = '{FIRST_EXPENDITURE}'",
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

    def test_overlapping_event_windows(self):
        self.assertDetected("INSERT INTO DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA VALUES ('PRS-99', 'Kabut Asap', 'Uji', "
                            "DATE '2025-06-10', DATE '2025-06-12', 'Ringan', 'Uji tumpang tindih')", "EVENTS", "Event windows overlap")

    def test_attendance_linked_to_an_event_that_was_not_on_that_day(self):
        self.assertDetected(f"UPDATE DATA_OPERASIONAL.KEHADIRAN_MISA SET ID_PERISTIWA = 'PRS-08' WHERE ID_KEHADIRAN = '{FIRST_ATTENDANCE}'",
                            "EVENTS", "Attendance linked to an event that does not cover the Mass date")

    def test_gift_recorded_in_the_wrong_community(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.SUMBANGAN_KELUARGA SET ID_LINGKUNGAN = "
                            "CASE WHEN ID_LINGKUNGAN = 'LNG-01' THEN 'LNG-02' ELSE 'LNG-01' END WHERE ID_SUMBANGAN_KELUARGA = 'SKL-00001'",
                            "DONATIONS", "Gift community differs from the household assignment")

    def test_regional_summary_that_no_longer_matches_the_gifts(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS SET JUMLAH_SUMBANGAN = JUMLAH_SUMBANGAN + 5000 "
                            "WHERE ID_SUMBANGAN = 'SMB-001'", "DONATIONS", "Regional summary differs from the household gifts")

    def test_gifts_without_a_regional_summary(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE ID_SUMBANGAN = 'SMB-001'",
                            "DONATIONS", "Household gifts without a regional summary")

    def test_campaign_status_contradicting_its_dates(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.KAMPANYE_SUMBANGAN SET STATUS_KAMPANYE = 'Direncanakan' WHERE ID_KAMPANYE = 'KMP-01'",
                            "DONATIONS", "Campaign dates or status inconsistent")

    def test_community_without_an_economic_profile(self):
        self.assertDetected("DELETE FROM MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN WHERE ID_LINGKUNGAN = 'LNG-01'",
                            "DONATIONS", "Community without an economic profile")

    def test_snapshot_date_that_disagrees_with_the_validation(self):
        self.assertDetected("UPDATE MASTER_DATA.INFO_DATASET SET TANGGAL_SNAPSHOT = DATE '2026-10-31'",
                            "DATASET", "Snapshot date differs from this validation")

    def test_history_cut_below_five_years(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE TANGGAL_MISA < DATE '2023-01-01'",
                            "DATASET", "Mass history shorter than five years")

    def test_a_view_that_leaks_household_gift_identifiers(self):
        self.assertDetected("CREATE VIEW ANALISIS.BOCOR_SUMBANGAN AS SELECT ID_SUMBANGAN_KELUARGA, JUMLAH_SUMBANGAN "
                            "FROM DATA_OPERASIONAL.SUMBANGAN_KELUARGA", "GOVERNANCE", "Personal-data columns exposed in ANALISIS")

    def test_an_empty_table_fails_the_row_count(self):
        self.assertDetected("DELETE FROM DATA_OPERASIONAL.KELUARGA", "STRUCTURE", "Row count")

    # --- shadow forecast ---------------------------------------------------------------------------------------------
    def test_forecast_for_a_week_that_does_not_start_on_monday(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET AWAL_PEKAN_SASARAN = DATE '2022-03-02' "
                            "WHERE ID_PERKIRAAN = 'PKR-0001'", "FORECAST", "Target week does not start on a Monday")

    def test_forecast_issued_too_late_or_after_the_snapshot(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET TANGGAL_PERKIRAAN = TANGGAL_PERKIRAAN + 7 "
                            "WHERE ID_PERKIRAAN = 'PKR-0010'", "FORECAST", "Forecast not issued exactly one horizon before its week")
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET TANGGAL_PERKIRAAN = DATE '2026-10-05' "
                            "WHERE ID_PERKIRAAN = 'PKR-0274'", "FORECAST", "Forecast issued after the as-of date")

    def test_forecast_range_that_does_not_contain_the_forecast(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET BATAS_BAWAH = JUMLAH_PERKIRAAN + 1000 "
                            "WHERE ID_PERKIRAAN = 'PKR-0020'", "FORECAST", "Range does not contain the point forecast")

    def test_a_missing_forecast_week_is_a_gap_and_a_complete_week_without_forecast(self):
        failed, _ = self.failing("DELETE FROM DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN WHERE ID_PERKIRAAN = 'PKR-0100'")
        self.assertIn(("FORECAST", "Gap in the weekly forecast series"), failed)
        self.assertIn(("FORECAST", "Complete week without a forecast"), failed)

    def test_forecast_beyond_the_last_complete_week_is_not_a_missing_forecast(self):
        failed, _ = self.failing("DELETE FROM DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN WHERE ID_PERKIRAAN = 'PKR-0274'")
        self.assertNotIn(("FORECAST", "Gap in the weekly forecast series"), failed)

    def test_forecast_that_learned_from_too_few_weeks(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET JUMLAH_PEKAN_PELATIHAN = 3 WHERE ID_PERKIRAAN = 'PKR-0030'",
                            "FORECAST", "Too little history behind a forecast")

    def test_forecast_pointing_at_an_unknown_model(self):
        self.assertDetected("UPDATE DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN SET ID_MODEL = 'MDL-99' WHERE ID_PERKIRAAN = 'PKR-0030'",
                            "REFERENCES", "Orphaned reference")

    def test_new_actuals_change_the_comparison_but_never_the_stored_forecast(self):
        """The forecast is a record of what was said: a corrected collection moves the actual, not the forecast."""
        week = next(f["AWAL_PEKAN_SASARAN"] for f in DATA["DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN"] if f["AWAL_PEKAN_SASARAN"].year == 2024)
        mass = self.connection.execute(
            "SELECT c.ID_KOLEKTE FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE c JOIN DATA_OPERASIONAL.KEJADIAN_MISA k "
            "ON k.ID_KEJADIAN_MISA = c.ID_KEJADIAN_MISA WHERE k.TANGGAL_MISA BETWEEN ? AND CAST(? AS DATE) + 6 "
            "AND c.JUMLAH_HASIL_PENGHITUNGAN IS NOT NULL LIMIT 1", [week, week]).fetchone()[0]
        query = ("SELECT KOLEKTE_AKTUAL, JUMLAH_PERKIRAAN, TANGGAL_PERKIRAAN FROM ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN "
                 "WHERE AWAL_PEKAN = ?")
        before = self.connection.execute(query, [week]).fetchone()
        self.connection.execute("BEGIN TRANSACTION")
        try:
            self.connection.execute(f"UPDATE DATA_OPERASIONAL.PENERIMAAN_KOLEKTE SET JUMLAH_HASIL_PENGHITUNGAN = "
                                    f"JUMLAH_HASIL_PENGHITUNGAN + 1000000 WHERE ID_KOLEKTE = '{mass}'")
            after = self.connection.execute(query, [week]).fetchone()
        finally:
            self.connection.execute("ROLLBACK")
        self.assertEqual(after[0] - before[0], 1_000_000)
        self.assertEqual(after[1:], before[1:])


    # --- public service guides ---------------------------------------------------------------------------------------
    def test_a_service_without_steps(self):
        self.assertDetected("DELETE FROM MASTER_DATA.LANGKAH_LAYANAN WHERE ID_LAYANAN = 'LYN-05'",
                            "SERVICES", "Service without steps or without requirements")

    def test_a_gap_in_the_numbering_of_steps_or_requirements(self):
        self.assertDetected("DELETE FROM MASTER_DATA.LANGKAH_LAYANAN WHERE ID_LANGKAH = 'LGK-0203'",
                            "SERVICES", "Step numbers have gaps or do not start at 1")
        self.assertDetected("DELETE FROM MASTER_DATA.PERSYARATAN_LAYANAN WHERE ID_PERSYARATAN = 'PSY-0401'",
                            "SERVICES", "Requirement numbers have gaps or do not start at 1")

    def test_a_guide_file_that_does_not_belong_to_its_service(self):
        self.assertDetected("UPDATE MASTER_DATA.LAYANAN_PAROKI SET NAMA_BERKAS_PANDUAN = 'LYN-99_salah.pdf' WHERE ID_LAYANAN = 'LYN-01'",
                            "SERVICES", "Guide file name does not start with the service id or is not a PDF")
        self.assertDetected("UPDATE MASTER_DATA.LAYANAN_PAROKI SET NAMA_BERKAS_PANDUAN = 'app/' || NAMA_BERKAS_PANDUAN WHERE ID_LAYANAN = 'LYN-01'",
                            "SERVICES", "Guide file name does not start with the service id or is not a PDF")

    def test_a_guide_with_an_email_address_is_rejected(self):
        self.assertDetected("UPDATE MASTER_DATA.LANGKAH_LAYANAN SET URAIAN = URAIAN || ' Tulis ke seseorang@contoh.id' WHERE ID_LANGKAH = 'LGK-0101'",
                            "SERVICES", "Guide text containing an email address")

    def test_two_services_cannot_share_one_guide_file(self):
        self.assertDetected("UPDATE MASTER_DATA.LAYANAN_PAROKI SET NAMA_BERKAS_PANDUAN = "
                            "(SELECT NAMA_BERKAS_PANDUAN FROM MASTER_DATA.LAYANAN_PAROKI WHERE ID_LAYANAN = 'LYN-01') WHERE ID_LAYANAN = 'LYN-02'",
                            "KEYS", "Duplicate unique key UQ_LAYANAN_PAROKI_BERKAS")

    def test_hiding_a_service_by_classification_is_a_warning_not_a_failure(self):
        failed, rows = self.failing("UPDATE MASTER_DATA.LAYANAN_PAROKI SET ID_KLASIFIKASI_DATA = 'KLS-02' WHERE ID_LAYANAN = 'LYN-06'")
        self.assertEqual(failed, set())
        warned = [r for r in rows if r["CHECK_NAME"] == "Service guide with a classification that may not be public"]
        self.assertEqual([(r["RESULT"], r["FOUND_COUNT"]) for r in warned], [("WARN", 1)])

    def test_an_unknown_actor_or_category_is_rejected_by_the_vocabulary_check(self):
        self.assertDetected("UPDATE MASTER_DATA.LANGKAH_LAYANAN SET PELAKU = 'Siapa saja' WHERE ID_LANGKAH = 'LGK-0101'",
                            "VOCABULARY", "Value not in list PELAKU_LANGKAH")
        self.assertDetected("UPDATE MASTER_DATA.LAYANAN_PAROKI SET KATEGORI_LAYANAN = 'Lain-lain' WHERE ID_LAYANAN = 'LYN-01'",
                            "VOCABULARY", "Value not in list KATEGORI_LAYANAN")


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
            f"WHERE ID_KEJADIAN_MISA = '{FIRST_HELD_MASS}'").fetchone()
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

    def test_events_and_reports_view_names_the_source_document_of_every_report(self):
        rows = self.connection.execute(
            "SELECT ID_LAPORAN, NAMA_BERKAS_LAPORAN FROM ANALISIS.KEGIATAN_DAN_LAPORAN WHERE ID_LAPORAN IS NOT NULL").fetchall()
        self.assertEqual(len(rows), len(DATA["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]))
        for report_id, file in rows:
            self.assertTrue(file.startswith(report_id + "_") and file.endswith(".pdf"), file)
        unreported = self.value("SELECT COUNT(*) FROM ANALISIS.KEGIATAN_DAN_LAPORAN WHERE ID_LAPORAN IS NULL AND NAMA_BERKAS_LAPORAN IS NOT NULL")
        self.assertEqual(unreported, 0, "an event without a report has no document")

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
        self.assertEqual(sorted(views), sorted(VIEWS))
        for view in views:
            self.assertEqual(self.value(f"SELECT MIN(SUMBER_DATA) FROM ANALISIS.{view}"), "Data simulasi (fiktif)", view)


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class UseCaseViewTests(unittest.TestCase):
    """The business questions behind the demo, answered through the ANALISIS views."""

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)

    def rows(self, sql):
        cursor = self.connection.execute(sql)
        columns = [d[0] for d in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]

    def value(self, sql):
        return self.connection.execute(sql).fetchone()[0]

    # --- income versus outcome -------------------------------------------------------------------------------
    def test_monthly_series_adds_up_to_the_source_tables(self):
        self.assertEqual(self.value("SELECT SUM(PEMASUKAN_KOLEKTE) FROM ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN"),
                         self.value("SELECT SUM(COALESCE(JUMLAH_HASIL_PENGHITUNGAN, JUMLAH_PENERIMAAN)) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE "
                                    "c JOIN DATA_OPERASIONAL.KEJADIAN_MISA k ON k.ID_KEJADIAN_MISA = c.ID_KEJADIAN_MISA "
                                    "WHERE k.TANGGAL_MISA <= DATE '2026-09-30'"))
        self.assertEqual(self.value("SELECT SUM(PENGELUARAN_PROGRAM) FROM ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN"),
                         self.value("SELECT SUM(JUMLAH_PENGELUARAN) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN"))
        self.assertEqual(self.value("SELECT SUM(PEMASUKAN_SUMBANGAN_KHUSUS) FROM ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN"),
                         self.value("SELECT SUM(JUMLAH_SUMBANGAN) FROM DATA_OPERASIONAL.SUMBANGAN_KELUARGA"))
        self.assertEqual(self.value("SELECT COUNT(*) FROM ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN"), 69)  # Jan 2021 - Sep 2026
        self.assertEqual(self.value("SELECT MAX(STATUS_PERIODE) FROM ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN"), "Lengkap")

    def test_annual_view_marks_only_the_current_year_as_incomplete(self):
        years = {r["TAHUN"]: r for r in self.rows("SELECT * FROM ANALISIS.PEMASUKAN_PENGELUARAN_TAHUNAN")}
        self.assertEqual(sorted(years), [2021, 2022, 2023, 2024, 2025, 2026])
        self.assertTrue(all(years[y]["TAHUN_LENGKAP"] for y in range(2021, 2026)))
        self.assertFalse(years[2026]["TAHUN_LENGKAP"])
        self.assertIn("9 bulan", years[2026]["STATUS_TAHUN"])
        self.assertIsNone(years[2026]["PERTUMBUHAN_KOLEKTE_PERSEN"], "no growth figure for a partial year")
        for y in range(2021, 2027):
            self.assertGreater(years[y]["SELISIH_KOLEKTE_VS_PENGELUARAN"], 0, f"{y}: income is still bigger than outcome")

    def test_underlying_growth_slows_while_spending_growth_stays_high(self):
        years = {r["TAHUN"]: r for r in self.rows("SELECT * FROM ANALISIS.PEMASUKAN_PENGELUARAN_TAHUNAN")}
        calm = [years[y]["PERTUMBUHAN_KOLEKTE_PER_MISA_TANPA_PERISTIWA_PERSEN"] for y in range(2022, 2026)]
        self.assertGreater(calm[0], calm[-1] + 3)
        self.assertGreater((calm[0] + calm[1]) / 2, (calm[2] + calm[3]) / 2 + 2.5)
        for y in range(2022, 2026):
            self.assertGreater(years[y]["PERTUMBUHAN_PENGELUARAN_PERSEN"], 15)

    def test_the_projection_shows_spending_overtaking_the_offertory(self):
        rows = {r["TAHUN"]: r for r in self.rows("SELECT * FROM ANALISIS.PROYEKSI_PEMASUKAN_PENGELUARAN")}
        self.assertEqual(sorted(rows)[:6], [2021, 2022, 2023, 2024, 2025, 2026])
        self.assertGreaterEqual(max(rows), 2030)
        self.assertEqual(rows[2025]["JENIS_DATA"], "Aktual (tahun lengkap)")
        self.assertEqual(rows[2026]["JENIS_DATA"], "Tahun berjalan (sebagian) dan proyeksi")
        self.assertEqual(rows[2028]["JENIS_DATA"], "Proyeksi")
        crossing = rows[2021]["TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE"]
        self.assertIn(crossing, (2028, 2029, 2030))
        self.assertFalse(rows[crossing - 1]["TREN_PENGELUARAN_MELEBIHI_KOLEKTE"])
        self.assertTrue(rows[crossing]["TREN_PENGELUARAN_MELEBIHI_KOLEKTE"])
        self.assertGreater(rows[2021]["PERTAMBAHAN_PENGELUARAN_PER_TAHUN"], 3 * rows[2021]["PERTAMBAHAN_KOLEKTE_PER_TAHUN"])
        self.assertEqual(rows[2021]["JUMLAH_TAHUN_DASAR"], 5)
        self.assertIn("regresi linear", rows[2021]["CATATAN_METODE"])

    # --- offertory behaviour -----------------------------------------------------------------------------------------
    def test_offertory_per_attendee_is_highest_just_after_salary_day(self):
        for year in range(2021, 2026):
            groups = {r["KELOMPOK_TANGGAL"]: r["KOLEKTE_PER_UMAT"] for r in self.rows(
                f"SELECT KELOMPOK_TANGGAL, 1.0 * SUM(TOTAL_KOLEKTE) / SUM(TOTAL_UMAT) AS KOLEKTE_PER_UMAT "
                f"FROM ANALISIS.POLA_KOLEKTE_HARI_DALAM_BULAN WHERE TAHUN = {year} GROUP BY KELOMPOK_TANGGAL")}
            self.assertGreater(groups["Tanggal 1-7"], groups["Tanggal 8-14"], year)
            self.assertGreater(groups["Tanggal 8-14"], groups["Tanggal 15-21"], year)
            self.assertGreater(groups["Tanggal 15-21"], groups["Tanggal 22-31"], year)
            self.assertGreater(groups["Tanggal 1-7"] / groups["Tanggal 22-31"], 1.25, year)

    def test_offertory_correlates_with_attendance_and_declines_through_the_month(self):
        rows = self.rows("SELECT * FROM ANALISIS.KORELASI_KOLEKTE_KEHADIRAN WHERE NAMA_MISA LIKE 'Misa Minggu%' OR NAMA_MISA = 'Misa Sabtu Sore'")
        self.assertGreater(len(rows), 25)
        for r in rows:
            self.assertGreater(r["KORELASI_KOLEKTE_DENGAN_UMAT"], 0.3, (r["TAHUN"], r["NAMA_MISA"]))
            self.assertLess(r["KORELASI_TANGGAL_DENGAN_KOLEKTE_PER_UMAT"], -0.5, (r["TAHUN"], r["NAMA_MISA"]))
            self.assertGreater(r["TAMBAHAN_KOLEKTE_PER_UMAT"], 5000)

    # --- unforeseen events -----------------------------------------------------------------------------------------------
    def test_weekly_series_starts_on_mondays_and_names_the_events(self):
        self.assertEqual(self.value("SELECT COUNT(*) FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA "
                                    "WHERE MOD(DATEDIFF('day', DATE '1900-01-01', AWAL_PEKAN), 7) <> 0"), 0)
        self.assertEqual(self.value("SELECT SUM(TOTAL_UMAT) FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA"),
                         self.value("SELECT SUM(JUMLAH_UMAT) FROM DATA_OPERASIONAL.KEHADIRAN_MISA"))
        self.assertGreater(self.value("SELECT COUNT(*) FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA"), 280)
        labelled = {r[0] for r in self.connection.execute(
            "SELECT DISTINCT ID_PERISTIWA FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA WHERE ID_PERISTIWA IS NOT NULL").fetchall()}
        self.assertEqual(len(labelled), 10)
        ash = self.rows("SELECT PERSEN_UMAT_TERHADAP_8_PEKAN_SEBELUMNYA AS P, PERSEN_KOLEKTE_TERHADAP_8_PEKAN_SEBELUMNYA AS K "
                        "FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA WHERE ID_PERISTIWA = 'PRS-08'")
        self.assertGreater(len(ash), 3)
        self.assertLess(sum(r["P"] for r in ash) / len(ash), 80)
        normal = self.value("SELECT AVG(PERSEN_UMAT_TERHADAP_8_PEKAN_SEBELUMNYA) FROM ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA "
                            "WHERE ID_PERISTIWA IS NULL AND PERSEN_UMAT_TERHADAP_8_PEKAN_SEBELUMNYA IS NOT NULL")
        self.assertTrue(95 < normal < 108)

    def test_every_event_shows_a_dip_and_severity_orders_the_effect(self):
        rows = {r["ID_PERISTIWA"]: r for r in self.rows("SELECT * FROM ANALISIS.DAMPAK_PERISTIWA_LUAR_BIASA")}
        self.assertEqual(len(rows), 10)
        by_level = {"Ringan": [], "Sedang": [], "Berat": []}
        for r in rows.values():
            self.assertLess(r["PERSEN_KEHADIRAN_TERHADAP_HARAPAN"], 100, r["NAMA_PERISTIWA"])
            by_level[r["TINGKAT_GANGGUAN"]].append(r["PERSEN_KEHADIRAN_TERHADAP_HARAPAN"])
        mean = {k: sum(v) / len(v) for k, v in by_level.items()}
        self.assertLess(mean["Berat"], mean["Sedang"])
        self.assertLess(mean["Sedang"], mean["Ringan"])
        self.assertGreater(rows["PRS-08"]["JUMLAH_MISA_DIBATALKAN"], 0)
        self.assertGreater(rows["PRS-08"]["PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA"], 10_000_000)

    def test_a_dip_can_be_hidden_by_payday_and_that_is_why_forecasts_get_biased(self):
        """The March 2023 power cut fell in the first week of the month: attendance dipped, offertory did not."""
        r = self.rows("SELECT PERSEN_KEHADIRAN_TERHADAP_HARAPAN AS U, PERSEN_KOLEKTE_TERHADAP_HARAPAN AS K "
                      "FROM ANALISIS.DAMPAK_PERISTIWA_LUAR_BIASA WHERE ID_PERISTIWA = 'PRS-05'")[0]
        self.assertLess(r["U"], 100)
        self.assertGreater(r["K"], r["U"] + 5)

    # --- donations and break-even ----------------------------------------------------------------------------------------------
    def test_break_even_story_per_campaign(self):
        rows = {r["NAMA_KAMPANYE"]: r for r in self.rows("SELECT * FROM ANALISIS.TITIK_IMPAS_KAMPANYE")}
        for year in range(2021, 2027):
            easter = rows[f"Aksi Puasa Pembangunan {year}"]
            self.assertTrue(easter["STATUS_TITIK_IMPAS"].startswith("Surplus"), year)
            self.assertIsNotNone(easter["PEMASUKAN_BERSIH_UNTUK_GEREJA"])
            self.assertIsNone(easter["DANA_TAMBAHAN_DARI_GEREJA"])
        self.assertGreater(rows["Aksi Puasa Pembangunan 2021"]["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"],
                           3 * rows["Aksi Puasa Pembangunan 2026"]["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"])
        statuses = [rows[f"Aksi Adven Peduli Sesama {y}"]["STATUS_TITIK_IMPAS"][:7] for y in range(2021, 2026)]
        self.assertEqual(statuses, ["Surplus", "Surplus", "Defisit", "Defisit", "Defisit"])
        advent_2026 = rows["Aksi Adven Peduli Sesama 2026"]
        self.assertTrue(advent_2026["STATUS_TITIK_IMPAS"].startswith("Belum dapat dihitung"))
        self.assertLess(advent_2026["PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI"], 0, "the church must plan extra money for Christmas 2026")
        self.assertIsNotNone(advent_2026["ANGGARAN_RENCANA"])
        for r in rows.values():
            if r["PEMASUKAN_BERSIH_UNTUK_GEREJA"] is not None:
                self.assertEqual(r["PEMASUKAN_BERSIH_UNTUK_GEREJA"], r["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"])
            if r["DANA_TAMBAHAN_DARI_GEREJA"] is not None:
                self.assertEqual(r["DANA_TAMBAHAN_DARI_GEREJA"], -r["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"])

    def test_mean_median_and_per_household_numbers_differ_by_community(self):
        rows = self.rows("SELECT * FROM ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN WHERE NAMA_KAMPANYE = 'Aksi Puasa Pembangunan 2025'")
        by = {r["ID_LINGKUNGAN"]: r for r in rows}
        outliers = [by[c] for c in ("LNG-05", "LNG-07", "LNG-12", "LNG-14")]
        for r in outliers:
            self.assertEqual(r["KATEGORI_EKONOMI"], "Rendah")
            self.assertGreater(r["SELISIH_RATA_RATA_DARI_MEDIAN_PERSEN"], 35)
            self.assertGreater(r["PERSEN_TOTAL_DARI_SUMBANGAN_TERBESAR"], 40)
        calm = [by[c] for c in ("LNG-02", "LNG-10", "LNG-17", "LNG-09")]
        for r in calm:
            self.assertLess(abs(r["SELISIH_RATA_RATA_DARI_MEDIAN_PERSEN"]), 10)
        self.assertLess(max(r["MEDIAN_PER_KELUARGA_PENYUMBANG"] for r in outliers),
                        min(r["MEDIAN_PER_KELUARGA_PENYUMBANG"] for r in calm if r["KATEGORI_EKONOMI"] == "Tinggi"))
        by_total = [r["ID_LINGKUNGAN"] for r in sorted(rows, key=lambda r: r["TOTAL_SUMBANGAN"])]
        by_median = [r["ID_LINGKUNGAN"] for r in sorted(rows, key=lambda r: r["MEDIAN_PER_KELUARGA_PENYUMBANG"])]
        by_person = [r["ID_LINGKUNGAN"] for r in sorted(rows, key=lambda r: r["SUMBANGAN_PER_UMAT_TERDAFTAR"])]
        self.assertNotEqual(by_total, by_median)
        self.assertNotEqual(by_person, by_median)
        self.assertNotEqual(by_person, by_total)

    def test_community_donation_view_is_aggregate_only_and_never_ranks(self):
        columns = {r[0] for r in self.connection.execute("DESCRIBE ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN").fetchall()}
        self.assertTrue(columns.isdisjoint({"ID_KELUARGA", "NAMA_KELUARGA_FIKTIF", "ID_SUMBANGAN_KELUARGA", "ID_UMAT"}))
        for name in columns:
            self.assertNotIn("PERINGKAT", name)
            self.assertNotIn("RANK", name)
        note = self.value("SELECT MIN(CATATAN_PENGGUNAAN) FROM ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN")
        self.assertIn("bukan tingkat iman", note)
        self.assertIn("memeringkat", note)

    def test_registered_households_in_the_community_view_follow_the_assignments(self):
        total = self.value("SELECT SUM(JUMLAH_KELUARGA_TERDAFTAR) FROM ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN "
                           "WHERE NAMA_KAMPANYE = 'Aksi Puasa Pembangunan 2026'")
        expected = self.value("SELECT COUNT(DISTINCT p.ID_KELUARGA) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN p "
                              "WHERE p.TANGGAL_MULAI_BERLAKU <= DATE '2026-04-04' "
                              "AND (p.TANGGAL_AKHIR_BERLAKU IS NULL OR p.TANGGAL_AKHIR_BERLAKU >= DATE '2026-04-04')")
        self.assertLessEqual(total, expected)
        self.assertGreater(total, 0.9 * expected)


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class UpcomingViewTests(unittest.TestCase):
    """KEGIATAN_MENDATANG: the step between the annual plan and the post-event report."""

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)
        cursor = cls.connection.execute("SELECT * FROM ANALISIS.KEGIATAN_MENDATANG")
        names = [d[0] for d in cursor.description]
        cls.rows = [dict(zip(names, row)) for row in cursor.fetchall()]

    def stage(self, name):
        return [r for r in self.rows if r["TAHAP"] == name]

    def test_every_open_plan_appears_exactly_once(self):
        open_plans = sorted(r["ID_RENCANA"] for r in DATA["DATA_OPERASIONAL.RENCANA_KEGIATAN"] if r["STATUS_PELAKSANAAN"] == "Direncanakan")
        listed = sorted(r["ID_RENCANA"] for r in self.rows if r["STATUS_RENCANA"] == "Direncanakan")
        self.assertEqual(listed, open_plans)
        self.assertEqual(len({r["ID_RENCANA"] for r in self.rows}), len(self.rows))

    def test_the_demo_shows_all_three_stages(self):
        self.assertGreaterEqual(len(self.stage("Sudah dijadwalkan")), 1)
        self.assertGreaterEqual(len(self.stage("Masih rencana tahunan")), 1)
        self.assertGreaterEqual(len(self.stage("Ditunda, perlu jadwal baru")), 1)
        self.assertEqual({r["TAHAP"] for r in self.rows},
                         {"Sudah dijadwalkan", "Masih rencana tahunan", "Ditunda, perlu jadwal baru"})

    def test_scheduled_events_have_place_and_target_and_plan_only_items_do_not(self):
        for row in self.stage("Sudah dijadwalkan"):
            self.assertTrue(row["ID_KEGIATAN"] and row["LOKASI"] and row["TARGET_PESERTA"] > 0, row["NAMA_PROGRAM"])
        for row in self.stage("Masih rencana tahunan"):
            self.assertIsNone(row["ID_KEGIATAN"])
            self.assertIsNone(row["LOKASI"])
            self.assertIsNone(row["TARGET_PESERTA"])

    def test_postponed_items_are_this_years_and_explain_why(self):
        snapshot = self.rows[0]["TANGGAL_DATA"]
        for row in self.stage("Ditunda, perlu jadwal baru"):
            self.assertEqual(row["TAHUN_RENCANA"], snapshot.year)
            self.assertTrue(row["CATATAN_KEGIATAN"], row["NAMA_PROGRAM"])
            self.assertLess(row["HARI_DARI_TANGGAL_DATA"], 0, "the original date has passed")

    def test_days_are_counted_from_the_snapshot_date_not_the_clock(self):
        snapshot = self.rows[0]["TANGGAL_DATA"]
        self.assertEqual(snapshot, config.AS_OF)
        for row in self.rows:
            self.assertEqual(row["HARI_DARI_TANGGAL_DATA"], (row["TANGGAL_MULAI"] - snapshot).days)
        for row in self.stage("Sudah dijadwalkan") + self.stage("Masih rencana tahunan"):
            self.assertGreater(row["HARI_DARI_TANGGAL_DATA"], 0)

    def test_budget_matches_the_program_budget_view(self):
        view = {r[0]: r[1] for r in self.connection.execute(
            "SELECT ID_RENCANA, ANGGARAN_RENCANA FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM").fetchall()}
        for row in self.rows:
            self.assertEqual(row["ANGGARAN_RENCANA"], view[row["ID_RENCANA"]], row["ID_RENCANA"])
            self.assertGreater(row["ANGGARAN_RENCANA"], 0)

    def test_the_christmas_celebration_shows_a_funding_gap(self):
        funded = [r for r in self.rows if r["DIDANAI_KAMPANYE"]]
        self.assertEqual(len(funded), 1)
        row = funded[0]
        self.assertIn("Natal", row["NAMA_PROGRAM"])
        self.assertEqual(row["SELISIH_TARGET_DANA_VS_ANGGARAN"], row["TARGET_DANA_KAMPANYE"] - row["ANGGARAN_RENCANA"])
        self.assertLess(row["SELISIH_TARGET_DANA_VS_ANGGARAN"], 0)

    def test_no_row_names_a_person_or_a_household(self):
        for forbidden in ("ID_UMAT", "ID_KELUARGA", "NAMA_FIKTIF", "TAHUN_LAHIR"):
            self.assertNotIn(forbidden, self.rows[0])
        self.assertEqual({r["SUMBER_DATA"] for r in self.rows}, {"Data simulasi (fiktif)"})


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class ForecastViewTests(unittest.TestCase):
    """KOLEKTE_AKTUAL_VS_PERKIRAAN, BIAS_PERKIRAAN_PER_PERISTIWA and AKURASI_PERKIRAAN_TAHUNAN."""

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)
        cls.weeks = cls.load("SELECT * FROM ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN ORDER BY AWAL_PEKAN")
        cls.events = {r["ID_PERISTIWA"]: r for r in cls.load("SELECT * FROM ANALISIS.BIAS_PERKIRAAN_PER_PERISTIWA")}
        cls.accuracy = cls.load("SELECT * FROM ANALISIS.AKURASI_PERKIRAAN_TAHUNAN")

    @classmethod
    def load(cls, sql):
        cursor = cls.connection.execute(sql)
        names = [d[0] for d in cursor.description]
        return [dict(zip(names, row)) for row in cursor.fetchall()]

    def complete(self):
        return [r for r in self.weeks if r["STATUS_PEKAN"] == "Lengkap"]

    def test_one_row_per_stored_forecast_and_the_columns_are_copied_unchanged(self):
        stored = {f["AWAL_PEKAN_SASARAN"]: f for f in DATA["DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN"]}
        self.assertEqual(len(self.weeks), len(stored))
        for r in self.weeks:
            f = stored[r["AWAL_PEKAN"]]
            self.assertEqual((r["JUMLAH_PERKIRAAN"], r["BATAS_BAWAH"], r["BATAS_ATAS"]),
                             (f["JUMLAH_PERKIRAAN"], f["BATAS_BAWAH"], f["BATAS_ATAS"]))
            self.assertEqual(r["TANGGAL_PERKIRAAN"], f["TANGGAL_PERKIRAAN"])
            self.assertEqual(r["SUMBER_DATA"], "Data simulasi (fiktif)")

    def test_only_complete_weeks_are_compared_and_the_rest_is_labelled(self):
        from datetime import timedelta
        for r in self.weeks:
            ended = r["AWAL_PEKAN"] + timedelta(days=6) <= config.AS_OF
            started = r["AWAL_PEKAN"] <= config.AS_OF
            expected = "Lengkap" if ended else ("Sedang berjalan" if started else "Mendatang")
            self.assertEqual(r["STATUS_PEKAN"], expected, r["AWAL_PEKAN"])
            self.assertEqual(r["KOLEKTE_AKTUAL"] is None, expected != "Lengkap", r["AWAL_PEKAN"])
            self.assertEqual(r["SELISIH_PERSEN"] is None, expected != "Lengkap")
        self.assertEqual(sorted(r["STATUS_PEKAN"] for r in self.weeks if r["STATUS_PEKAN"] != "Lengkap"),
                         ["Mendatang"] * 4 + ["Sedang berjalan"])

    def test_actuals_equal_the_offertory_computed_in_python(self):
        from mockdata import forecast
        _, weekly, _, _, _ = forecast.inputs(DATA)
        for r in self.complete():
            self.assertEqual(r["KOLEKTE_AKTUAL"], weekly[r["AWAL_PEKAN"]], r["AWAL_PEKAN"])

    def test_gap_and_position_follow_the_range(self):
        for r in self.complete():
            self.assertEqual(r["SELISIH"], r["KOLEKTE_AKTUAL"] - r["JUMLAH_PERKIRAAN"])
            self.assertAlmostEqual(r["SELISIH_PERSEN"], 100.0 * float(r["SELISIH"]) / float(r["JUMLAH_PERKIRAAN"]), delta=0.051)
            if r["KOLEKTE_AKTUAL"] < r["BATAS_BAWAH"]:
                self.assertEqual(r["POSISI_TERHADAP_RENTANG"], "Di bawah rentang")
            elif r["KOLEKTE_AKTUAL"] > r["BATAS_ATAS"]:
                self.assertEqual(r["POSISI_TERHADAP_RENTANG"], "Di atas rentang")
            else:
                self.assertEqual(r["POSISI_TERHADAP_RENTANG"], "Dalam rentang")
                self.assertEqual(r["PENJELASAN_SELISIH"], "Dalam rentang perkiraan")

    def test_every_gap_outside_the_range_is_explained_by_an_event_or_honestly_left_unexplained(self):
        outside = [r for r in self.complete() if r["POSISI_TERHADAP_RENTANG"] != "Dalam rentang"]
        explained = [r for r in outside if r["ID_PERISTIWA"]]
        unexplained = [r for r in outside if not r["ID_PERISTIWA"]]
        self.assertGreaterEqual(len(explained), 18)
        self.assertGreater(len(unexplained), 0, "an 80% range misses one ordinary week in five, and the view must not hide that")
        for r in explained:
            self.assertEqual(r["PENJELASAN_SELISIH"], "Di luar rentang, dijelaskan peristiwa luar biasa")
            self.assertEqual(r["JENIS_PEKAN"], "Peristiwa luar biasa")
            self.assertLess(r["SELISIH"], 0, "events lower the offertory")
            self.assertTrue(r["NAMA_PERISTIWA"] and r["TINGKAT_GANGGUAN"])
        for r in unexplained:
            self.assertEqual(r["PENJELASAN_SELISIH"], "Di luar rentang, tanpa peristiwa tercatat")
            self.assertIsNone(r["NAMA_PERISTIWA"])

    def test_the_kind_of_week_comes_from_the_event_log_and_the_calendar(self):
        for r in self.weeks:
            if r["ID_PERISTIWA"]:
                self.assertEqual(r["JENIS_PEKAN"], "Peristiwa luar biasa")
            elif r["CATATAN_KALENDER"]:
                self.assertEqual(r["JENIS_PEKAN"], "Hari raya atau kolekte khusus")
                self.assertGreater(r["PENYESUAIAN_KALENDER"], 1)
            else:
                self.assertEqual(r["JENIS_PEKAN"], "Pekan biasa")
        self.assertEqual({r["JENIS_PEKAN"] for r in self.weeks},
                         {"Pekan biasa", "Hari raya atau kolekte khusus", "Peristiwa luar biasa"})

    def test_the_power_cut_hidden_by_payday_is_a_week_the_forecast_got_right(self):
        row = next(r for r in self.weeks if r["ID_PERISTIWA"] == "PRS-05")
        self.assertEqual(row["POSISI_TERHADAP_RENTANG"], "Dalam rentang")
        self.assertLess(abs(row["SELISIH_PERSEN"]), 3)

    def test_event_bias_view_has_the_nine_events_the_forecast_could_cover(self):
        self.assertEqual(sorted(self.events), [f"PRS-{n:02d}" for n in range(2, 11)])
        for event_id, r in self.events.items():
            weeks = [w for w in self.complete() if w["ID_PERISTIWA"] == event_id]
            self.assertEqual(r["JUMLAH_PEKAN_TERDAMPAK"], len(weeks), event_id)
            self.assertEqual(r["PERKIRAAN_TOTAL"], sum(w["JUMLAH_PERKIRAAN"] for w in weeks))
            self.assertEqual(r["KOLEKTE_AKTUAL_TOTAL"], sum(w["KOLEKTE_AKTUAL"] for w in weeks))
            self.assertEqual(r["SELISIH_TOTAL"], r["KOLEKTE_AKTUAL_TOTAL"] - r["PERKIRAAN_TOTAL"])
            self.assertEqual(r["JUMLAH_PEKAN_DI_LUAR_RENTANG"], sum(w["POSISI_TERHADAP_RENTANG"] != "Dalam rentang" for w in weeks))

    def test_the_big_events_explain_the_big_misses(self):
        ash, haze, power = self.events["PRS-08"], self.events["PRS-06"], self.events["PRS-05"]
        self.assertLess(ash["SELISIH_PERSEN"], -45)
        self.assertLess(haze["SELISIH_PERSEN"], -40)
        self.assertGreater(ash["KELIPATAN_GALAT_BIASA"], 5)
        self.assertGreater(haze["KELIPATAN_GALAT_BIASA"], 5)
        self.assertLess(power["KELIPATAN_GALAT_BIASA"], 1)
        self.assertEqual(ash["JUMLAH_PEKAN_DI_LUAR_RENTANG"], ash["JUMLAH_PEKAN_TERDAMPAK"])
        by_gap = sorted(self.events.values(), key=lambda r: r["SELISIH_PERSEN"])
        self.assertEqual({by_gap[0]["TINGKAT_GANGGUAN"], by_gap[1]["TINGKAT_GANGGUAN"]}, {"Berat"})
        self.assertTrue(all(r["SELISIH_PERSEN"] < 0 for r in self.events.values()))

    def test_typical_error_is_measured_on_ordinary_weeks_only(self):
        ordinary = [abs(r["SELISIH_PERSEN"]) for r in self.complete() if r["JENIS_PEKAN"] == "Pekan biasa"]
        typical = {r["GALAT_PEKAN_BIASA_PERSEN"] for r in self.events.values()}
        self.assertEqual(len(typical), 1)
        self.assertAlmostEqual(typical.pop(), sum(ordinary) / len(ordinary), delta=0.1)

    def test_accuracy_view_adds_up_to_the_compared_weeks(self):
        self.assertEqual(sum(r["JUMLAH_PEKAN"] for r in self.accuracy), len(self.complete()))
        self.assertEqual({r["JENIS_PEKAN"] for r in self.accuracy},
                         {"Pekan biasa", "Hari raya atau kolekte khusus", "Peristiwa luar biasa"})
        self.assertEqual({r["TAHUN"] for r in self.accuracy}, set(range(2021, 2027)))
        for r in self.accuracy:
            self.assertEqual(r["PERSEN_DALAM_RENTANG"], round(100.0 * r["JUMLAH_DALAM_RENTANG"] / r["JUMLAH_PEKAN"], 1))
            self.assertEqual(r["LEBAR_RENTANG_PERSEN"], 80)

    def test_accuracy_is_good_on_ordinary_weeks_and_poor_when_an_event_struck(self):
        def pooled(kind, column):
            rows = [r for r in self.accuracy if r["JENIS_PEKAN"] == kind]
            return sum(r[column] * r["JUMLAH_PEKAN"] for r in rows) / sum(r["JUMLAH_PEKAN"] for r in rows)

        self.assertLess(pooled("Pekan biasa", "GALAT_RATA_RATA_PERSEN"), 10)
        self.assertGreater(pooled("Pekan biasa", "PERSEN_DALAM_RENTANG"), 72)
        self.assertGreater(pooled("Peristiwa luar biasa", "GALAT_RATA_RATA_PERSEN"), 25)
        self.assertLess(pooled("Peristiwa luar biasa", "PERSEN_DALAM_RENTANG"), 35)
        self.assertLess(pooled("Peristiwa luar biasa", "SELISIH_RATA_RATA_PERSEN"), -20)

    def test_the_forecast_views_never_rank_anything_and_expose_no_personal_columns(self):
        for view in ("KOLEKTE_AKTUAL_VS_PERKIRAAN", "BIAS_PERKIRAAN_PER_PERISTIWA", "AKURASI_PERKIRAAN_TAHUNAN"):
            columns = {r[0] for r in self.connection.execute(f"DESCRIBE ANALISIS.{view}").fetchall()}
            self.assertIn("SUMBER_DATA", columns)
            for name in columns:
                self.assertNotIn("PERINGKAT", name)
                self.assertNotIn("RANK", name)
            self.assertTrue(columns.isdisjoint({"ID_UMAT", "ID_KELUARGA", "NAMA_FIKTIF", "TAHUN_LAHIR"}))


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class ServiceViewTests(unittest.TestCase):
    """LAYANAN_PUBLIK, LANGKAH_LAYANAN_PUBLIK and PERSYARATAN_LAYANAN_PUBLIK."""

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)

    def rows(self, sql):
        cursor = self.connection.execute(sql)
        names = [d[0] for d in cursor.description]
        return [dict(zip(names, row)) for row in cursor.fetchall()]

    def test_every_public_service_is_listed_with_its_counts_and_file(self):
        services = {r["ID_LAYANAN"]: r for r in self.rows("SELECT * FROM ANALISIS.LAYANAN_PUBLIK")}
        self.assertEqual(sorted(services), [r["ID_LAYANAN"] for r in DATA["MASTER_DATA.LAYANAN_PAROKI"]])
        for source in DATA["MASTER_DATA.LAYANAN_PAROKI"]:
            row = services[source["ID_LAYANAN"]]
            self.assertEqual(row["NAMA_BERKAS_PANDUAN"], source["NAMA_BERKAS_PANDUAN"])
            self.assertEqual(row["JUMLAH_LANGKAH"], sum(1 for s in DATA["MASTER_DATA.LANGKAH_LAYANAN"] if s["ID_LAYANAN"] == source["ID_LAYANAN"]))
            requirements = [r for r in DATA["MASTER_DATA.PERSYARATAN_LAYANAN"] if r["ID_LAYANAN"] == source["ID_LAYANAN"]]
            self.assertEqual(row["JUMLAH_PERSYARATAN"], len(requirements))
            self.assertEqual(row["JUMLAH_PERSYARATAN_WAJIB"], sum(1 for r in requirements if r["WAJIB_DIPENUHI"]))
            self.assertTrue(row["SEKSI_PENGELOLA"].startswith("Seksi "))
            self.assertIn("bukan ketentuan resmi", row["CATATAN_PENGGUNAAN"])
            self.assertEqual(row["SUMBER_DATA"], "Data simulasi (fiktif)")

    def test_steps_and_requirements_come_back_complete_and_in_order(self):
        steps = self.rows("SELECT * FROM ANALISIS.LANGKAH_LAYANAN_PUBLIK ORDER BY ID_LAYANAN, NOMOR_URUT")
        requirements = self.rows("SELECT * FROM ANALISIS.PERSYARATAN_LAYANAN_PUBLIK ORDER BY ID_LAYANAN, NOMOR_URUT")
        self.assertEqual(len(steps), len(DATA["MASTER_DATA.LANGKAH_LAYANAN"]))
        self.assertEqual(len(requirements), len(DATA["MASTER_DATA.PERSYARATAN_LAYANAN"]))
        for sid in {r["ID_LAYANAN"] for r in steps}:
            numbers = [r["NOMOR_URUT"] for r in steps if r["ID_LAYANAN"] == sid]
            self.assertEqual(numbers, list(range(1, len(numbers) + 1)))
        self.assertEqual({r["STATUS_PERSYARATAN"] for r in requirements}, {"Wajib", "Jika berlaku"})
        for r in requirements:
            source = next(x for x in DATA["MASTER_DATA.PERSYARATAN_LAYANAN"] if x["ID_PERSYARATAN"] == f"PSY-{r['ID_LAYANAN'][4:]}{int(r['NOMOR_URUT']):02d}")
            self.assertEqual(r["STATUS_PERSYARATAN"] == "Wajib", source["WAJIB_DIPENUHI"])

    def test_a_service_that_may_not_be_public_disappears_with_all_its_steps(self):
        self.connection.execute("BEGIN TRANSACTION")
        try:
            self.connection.execute("UPDATE MASTER_DATA.LAYANAN_PAROKI SET ID_KLASIFIKASI_DATA = 'KLS-03' WHERE ID_LAYANAN = 'LYN-04'")
            listed = {r[0] for r in self.connection.execute("SELECT ID_LAYANAN FROM ANALISIS.LAYANAN_PUBLIK").fetchall()}
            steps = {r[0] for r in self.connection.execute("SELECT DISTINCT ID_LAYANAN FROM ANALISIS.LANGKAH_LAYANAN_PUBLIK").fetchall()}
            requirements = {r[0] for r in self.connection.execute("SELECT DISTINCT ID_LAYANAN FROM ANALISIS.PERSYARATAN_LAYANAN_PUBLIK").fetchall()}
        finally:
            self.connection.execute("ROLLBACK")
        self.assertNotIn("LYN-04", listed | steps | requirements)
        self.assertEqual(len(listed), 5)
        self.assertEqual(steps, listed)
        self.assertEqual(requirements, listed)

    def test_the_service_views_hold_no_personal_data_columns(self):
        for view in ("LAYANAN_PUBLIK", "LANGKAH_LAYANAN_PUBLIK", "PERSYARATAN_LAYANAN_PUBLIK"):
            columns = {r[0] for r in self.connection.execute(f"DESCRIBE ANALISIS.{view}").fetchall()}
            self.assertIn("SUMBER_DATA", columns)
            self.assertTrue(columns.isdisjoint({"ID_UMAT", "ID_KELUARGA", "NAMA_FIKTIF", "TAHUN_LAHIR", "ID_RESPONDEN"}))


@unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed (pip install -r tests/requirements.txt)")
class DocumentedQueryTests(unittest.TestCase):
    """Every SQL example in the README, the use-case guide and the starter guide (SELECTs on the views) runs and returns rows."""

    DOCUMENTS = ("README.md", "docs/USE_CASES.md", "docs/STARTER_GUIDE.md")
    # Documents that also contain statements meant for Snowflake only (Git setup, grants):
    # only the SELECT statements on the ANALISIS views are executed from them.
    SELECT_ONLY = ("docs/STARTER_GUIDE.md",)

    @classmethod
    def setUpClass(cls):
        cls.connection = shim.build_database(keep_constraints=False)

    def examples(self):
        for name in self.DOCUMENTS:
            text = (ROOT / name).read_text(encoding="utf-8")
            for block in re.findall(r"```sql\n(.*?)```", text, re.DOTALL):
                lines = [line for line in block.splitlines() if not line.strip().startswith("--")]
                for statement in re.split(r";\s*(?:\n|$)", "\n".join(lines)):
                    if not statement.strip():
                        continue
                    if name in self.SELECT_ONLY and not (statement.strip().upper().startswith("SELECT") and ".ANALISIS." in statement):
                        continue
                    if "BERKAS_DOKUMEN" in statement:
                        continue  # the view of the optional step 7 needs a Snowflake stage (directory table, pre-signed URLs): DuckDB cannot run it
                    yield name, statement.strip()

    def test_there_are_examples_to_check(self):
        self.assertGreaterEqual(len(list(self.examples())), 12)

    def test_headline_figures_in_the_use_case_guide_match_the_data(self):
        """The guide quotes a few figures. If the data changes, the guide must be updated."""
        guide = (ROOT / "docs" / "USE_CASES.md").read_text(encoding="utf-8")
        crossing = self.connection.execute(
            "SELECT MIN(TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE) FROM ANALISIS.PROYEKSI_PEMASUKAN_PENGELUARAN").fetchone()[0]
        self.assertIn(f"the lines cross in **{crossing}**", guide)
        events = self.connection.execute("SELECT COUNT(*) FROM DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA").fetchone()[0]
        self.assertIn(f"{events} events", guide)
        deficits = [row[0] for row in self.connection.execute(
            "SELECT TAHUN FROM ANALISIS.TITIK_IMPAS_KAMPANYE WHERE NAMA_KESEMPATAN LIKE '%Adven%' "
            "AND DANA_TAMBAHAN_DARI_GEREJA > 0 ORDER BY TAHUN").fetchall()]
        self.assertIn(f"Christmas drops\n  below break-even from {deficits[0]}", guide)
        households, people = (self.connection.execute(f"SELECT COUNT(*) FROM DATA_OPERASIONAL.{t}").fetchone()[0]
                              for t in ("KELUARGA", "UMAT"))
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn(f"{households} households, {people} people", readme)

    def test_every_documented_query_returns_rows(self):
        for name, statement in self.examples():
            local = shim.rewrite_dateadd(statement.replace("PUSAT_INFORMASI_PAROKI.", ""))
            try:
                rows = self.connection.execute(local).fetchall()
            except Exception as error:  # noqa: BLE001 - report which example broke
                self.fail(f"{name}: query failed ({error}): {statement[:120]!r}")
            self.assertTrue(rows, f"{name}: query returned no rows: {statement[:120]!r}")


@unittest.skipUnless(HAVE_SQLGLOT, "sqlglot is not installed (pip install -r tests/requirements.txt)")
class SnowflakeSyntaxLintTests(unittest.TestCase):
    """A second opinion on syntax using sqlglot's Snowflake grammar. It is a lint,
    not Snowflake itself."""

    @staticmethod
    def parse(name):
        text = (ROOT / "sql" / name).read_text(encoding="utf-8")
        return [s for s in sqlglot.parse(text, read="snowflake", error_level=sqlglot.ErrorLevel.RAISE)
                if s is not None and type(s).__name__ != "Semicolon"]

    def test_all_sql_files_parse_as_snowflake_sql(self):
        names = sorted(path.name for path in (ROOT / "sql").glob("*.sql") if not path.name.startswith("99"))
        self.assertIn("full_setup.sql", names)
        for name in names:
            kinds = {type(statement).__name__ for statement in self.parse(name)}
            self.assertTrue(kinds <= {"Use", "Create", "Merge", "Select", "Command"}, f"{name}: {kinds}")

    def test_statement_counts_match_the_design(self):
        def count(name, kind):
            return sum(1 for statement in self.parse(name) if type(statement).__name__ == kind)
        tables = len(TABLES)
        self.assertEqual(count("02_create_tables.sql", "Create"), tables)
        merges = sum(count(path.name, "Merge") for path in (ROOT / "sql").glob("0[34]*.sql"))
        expected = sum(max(1, -(-len(rows) // 1000)) for rows in DATA.values())  # one MERGE per started block of 1000 rows
        self.assertEqual(merges, expected)
        self.assertEqual(count("05_create_views.sql", "Create"), len(VIEWS))
        self.assertEqual(count("06_validate_data.sql", "Select"), 1)

    def test_every_statement_stays_far_below_the_size_limit(self):
        for path in (ROOT / "sql").glob("0*.sql"):
            for statement in re.split(r";\s*\n", path.read_text(encoding="utf-8")):
                self.assertLess(len(statement.encode("utf-8")), 600_000, f"{path.name}: a statement is too large")

    def test_no_step_file_is_too_large_to_paste(self):
        for path in (ROOT / "sql").glob("0*.sql"):
            self.assertLess(path.stat().st_size, 600_000, f"{path.name} is larger than 600 KB")


if __name__ == "__main__":
    unittest.main()
