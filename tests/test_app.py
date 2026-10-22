"""Tests for the Streamlit dashboard (app/streamlit_app.py).

IMPORTANT: this is NOT Snowflake. The dashboard's only link to Snowflake is `streamlit_app.run_query`.
These tests replace it with a DuckDB-backed stand-in (tests/app_support.py) that answers the dashboard's
`SELECT * FROM <db>.ANALISIS.<view>` statements from the project's real SQL files, then drive the app
with Streamlit's AppTest. A pass shows that every page renders, reads only the allowed views and respects
the privacy and language rules. It does not prove the app runs inside Streamlit in Snowflake.

Needs the optional packages in tests/requirements.txt; the tests skip without them.
"""

import ast
import json
import re
import sys
import unittest
from datetime import date
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_FILE = ROOT / "app" / "streamlit_app.py"
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "app"))

try:
    import duckdb  # noqa: F401
    import pandas as pd
    import streamlit  # noqa: F401
    import altair  # noqa: F401
    from streamlit.testing.v1 import AppTest
    HAVE_APP_STACK = True
except ImportError:  # pragma: no cover
    HAVE_APP_STACK = False

if HAVE_APP_STACK:
    import app_support
    import streamlit_app as app

NEEDS = "streamlit, altair, pandas or duckdb is not installed (pip install -r tests/requirements.txt)"

PAGES = ["Ringkasan", "Kegiatan mendatang", "Pemasukan dan pengeluaran", "Kolekte dan kehadiran", "Peristiwa luar biasa", "Sumbangan khusus",
         "Rencana, anggaran, kegiatan", "Survei umat", "Tentang data"]
CHART_PAGES = [p for p in PAGES if p != "Tentang data"]
RANKING_WORDS = ("peringkat", "terbaik", "terburuk", "dermawan", "juara")


def charts(at):
    return list(at.get("vega_lite_chart")) + list(at.get("arrow_vega_lite_chart"))


def page_text(at):
    """Every piece of text a reader sees on the page (not the tables)."""
    parts = []
    for kind in ("title", "header", "subheader", "markdown", "caption", "info", "warning", "error", "success"):
        parts.extend(str(element.value) for element in getattr(at, kind))
    parts.extend(f"{m.label} {m.value}" for m in at.metric)
    return "\n".join(parts)


def open_page(label):
    at = AppTest.from_string(app_support.APP_SCRIPT, default_timeout=180)
    at.run()
    if label != PAGES[0]:
        at.sidebar.radio[0].set_value(label).run()
    return at


@unittest.skipUnless(HAVE_APP_STACK, NEEDS)
class SourceRuleTests(unittest.TestCase):
    """Rules that can be checked on the source file alone."""

    @classmethod
    def setUpClass(cls):
        cls.source = APP_FILE.read_text(encoding="utf-8")

    def test_file_is_valid_for_the_oldest_supported_python(self):
        ast.parse(self.source, feature_version=(3, 9))

    def test_dashboard_never_names_the_detail_schemas_or_personal_columns(self):
        for forbidden in ("MASTER_DATA", "DATA_OPERASIONAL", "ID_UMAT", "ID_KELUARGA", "NAMA_FIKTIF", "TAHUN_LAHIR",
                          "ID_SUMBANGAN_KELUARGA"):
            self.assertNotIn(forbidden, self.source, forbidden)

    def test_only_one_function_talks_to_snowflake(self):
        self.assertEqual(self.source.count("session.sql("), 1)
        self.assertEqual(self.source.count('st.connection("snowflake")'), 1)
        self.assertEqual(self.source.count('f"SELECT * FROM '), 1, "one generic SELECT * query only")

    def test_no_credentials_in_the_app_folder(self):
        for path in (ROOT / "app").rglob("*"):
            if path.is_file() and path.suffix in {".py", ".md", ".toml", ".yml", ".yaml", ".txt", ".example"}:
                text = path.read_text(encoding="utf-8")
                self.assertIsNone(re.search(r"(?i)\b(password|token|private_key)\s*[=:]\s*['\"]?\w", text), path.name)
                self.assertIsNone(re.search(r"-----BEGIN [A-Z ]*PRIVATE KEY", text), path.name)

    def test_the_views_listed_in_the_app_exist_in_the_sql(self):
        sql = (ROOT / "sql" / "05_create_views.sql").read_text(encoding="utf-8")
        created = set(re.findall(r"CREATE OR REPLACE VIEW ANALISIS\.(\w+)", sql))
        self.assertEqual(set(app.VIEWS) - created, set())
        self.assertEqual(len(app.VIEWS), len(set(app.VIEWS)), "no duplicates")

    def test_the_dashboard_never_reads_the_clock(self):
        """'Upcoming' is relative to the data date, so the demo gives the same answer on any day."""
        for call in ("date.today(", "datetime.now(", "datetime.today(", "Timestamp.now(", "Timestamp.today(", "time.time("):
            self.assertNotIn(call, self.source, call)

    def test_every_page_function_is_reachable_from_the_menu(self):
        tree = ast.parse(self.source)
        defined = {n.name for n in tree.body if isinstance(n, ast.FunctionDef) and n.name.startswith("page_")}
        self.assertEqual({f.__name__ for f in app.PAGES.values()}, defined)
        self.assertEqual(list(app.PAGES), PAGES)


@unittest.skipUnless(HAVE_APP_STACK, NEEDS)
class FormattingTests(unittest.TestCase):
    def test_indonesian_number_conventions(self):
        self.assertEqual(app.number(1234567.891, 1), "1.234.567,9")
        self.assertEqual(app.number(0.5, 2), "0,50")
        self.assertEqual(app.number(None), "-")
        self.assertEqual(app.number(float("nan")), "-")

    def test_rupiah_and_million_formats_handle_negative_values(self):
        self.assertEqual(app.rupiah(283267000), "Rp 283.267.000")
        self.assertEqual(app.rupiah(-2380000), "-Rp 2.380.000")
        self.assertEqual(app.juta(283267000), "Rp 283,3 jt")
        self.assertEqual(app.juta(-4051700), "-Rp 4,1 jt")

    def test_percent_formats(self):
        self.assertEqual(app.percent(69.44), "69,4%")
        self.assertEqual(app.signed_percent(5.9), "+5,9%")
        self.assertEqual(app.signed_percent(-4.5), "-4,5%")

    def test_long_dates_use_indonesian_month_names(self):
        self.assertEqual(app.long_date(pd.Timestamp(2026, 9, 30)), "30 September 2026")
        self.assertEqual(app.long_date(pd.Timestamp(2026, 5, 1)), "1 Mei 2026")

    def test_normalise_copes_with_what_snowflake_returns(self):
        """Snowpark returns decimals and plain dates as Python objects with upper-case names."""
        raw = pd.DataFrame({"tahun": [Decimal("2021"), Decimal("2022")], "tanggal": [date(2021, 1, 1), date(2021, 2, 1)],
                            "aktif": [True, False], "nama": ["a", "b"], "kosong": [None, Decimal("3")]})
        clean = app._normalise(raw)
        self.assertEqual(list(clean.columns), ["TAHUN", "TANGGAL", "AKTIF", "NAMA", "KOSONG"])
        self.assertTrue(pd.api.types.is_numeric_dtype(clean["TAHUN"]))
        self.assertTrue(pd.api.types.is_datetime64_any_dtype(clean["TANGGAL"]))
        self.assertEqual(clean["AKTIF"].tolist(), [True, False])
        self.assertEqual(clean["NAMA"].tolist(), ["a", "b"])
        self.assertTrue(pd.api.types.is_numeric_dtype(clean["KOSONG"]))

    def test_partial_first_and_last_weeks_are_dropped_but_a_quiet_middle_week_stays(self):
        starts = pd.date_range("2021-01-04", periods=9, freq="7D")
        weeks = pd.DataFrame({"AWAL_PEKAN": starts, "JUMLAH_MISA_TERLAKSANA": [2, 7, 7, 7, 3, 7, 7, 7, 2]})
        kept = app.complete_weeks(weeks)
        self.assertEqual(list(kept["JUMLAH_MISA_TERLAKSANA"]), [7, 7, 7, 3, 7, 7, 7])

    def test_a_week_that_straddles_new_year_counts_for_the_new_year(self):
        frame = pd.DataFrame({"AWAL_PEKAN": pd.to_datetime(["2020-12-28", "2021-12-27", "2021-12-20"])})
        self.assertEqual(app.week_year(frame).tolist(), [2021, 2022, 2021])

    def test_planned_campaigns_are_not_drawn_as_zero(self):
        frame = pd.DataFrame({"STATUS_KAMPANYE": ["Selesai", "Direncanakan", "Selesai"],
                              "BIAYA_AKTUAL": [10.0, 0.0, None], "TOTAL_SUMBANGAN": [12.0, 0.0, 5.0]})
        self.assertEqual(app.finished_campaigns(frame).index.tolist(), [0])

    def test_chart_text_colour_exists_for_both_themes(self):
        self.assertEqual(set(app.INK), set(app.PALETTES))
        self.assertNotEqual(app.INK["light"], app.INK["dark"])

    def test_palettes_are_complete_and_distinct(self):
        for mode, colours in app.PALETTES.items():
            self.assertEqual(len(colours), 3, mode)
            self.assertEqual(len(set(colours)), 3, mode)


@unittest.skipUnless(HAVE_APP_STACK, NEEDS)
class PageTests(unittest.TestCase):
    """Every page rendered by Streamlit's AppTest on the DuckDB stand-in."""

    @classmethod
    def setUpClass(cls):
        app_support.connection()  # build the database once, before the first timeout starts
        app.load_view.clear()  # other test classes may have filled the cache, which would hide queries
        cls.pages = {}
        mark = len(app_support.QUERIES)
        for label in PAGES:
            cls.pages[label] = open_page(label)
        cls.queries = app_support.QUERIES[mark:]

    def test_menu_lists_the_pages_in_order(self):
        self.assertEqual(list(self.pages["Ringkasan"].sidebar.radio[0].options), PAGES)

    def test_no_page_raises_an_exception_or_shows_an_error(self):
        for label, at in self.pages.items():
            self.assertEqual([str(e.value) for e in at.exception], [], label)
            self.assertEqual([str(e.value) for e in at.error], [], label)

    def test_every_page_carries_the_simulated_data_notice(self):
        for label, at in self.pages.items():
            self.assertTrue(any("DATA SIMULASI" in str(i.value) for i in at.info), label)

    def test_every_page_has_a_title_and_the_chart_pages_have_charts(self):
        for label, at in self.pages.items():
            self.assertTrue(at.title, label)
            if label in CHART_PAGES:
                self.assertGreaterEqual(len(charts(at)), 1, label)

    def test_only_allowed_views_are_queried_and_all_of_them_are_used(self):
        pattern = re.compile(rf"^SELECT \* FROM {app.DATABASE}\.ANALISIS\.([A-Z_]+)$")
        used = set()
        for sql in self.queries:
            match = pattern.match(sql)
            self.assertIsNotNone(match, sql)
            used.add(match.group(1))
        self.assertEqual(used, set(app.VIEWS))

    def test_no_page_ranks_communities_or_regions(self):
        for label, at in self.pages.items():
            text = page_text(at).lower()
            for word in RANKING_WORDS:
                self.assertNotIn(word, text, f"{label}: {word}")

    def test_summary_shows_the_crossing_year_the_use_case_describes(self):
        values = {m.label: str(m.value) for m in self.pages["Ringkasan"].metric}
        self.assertEqual(values["Pengeluaran melampaui kolekte"], "2029")
        self.assertTrue(values["Biaya Natal tertutup"].endswith("%"))
        self.assertLess(float(values["Biaya Natal tertutup"].rstrip("%").replace(",", ".")), 100)
        self.assertGreater(float(values["Biaya Paskah tertutup"].rstrip("%").replace(",", ".")), 100)

    def test_events_page_explains_why_payday_can_hide_a_dip(self):
        text = page_text(self.pages["Peristiwa luar biasa"])
        self.assertIn("Pemadaman listrik Maret 2023", text)
        self.assertIn("hari gajian", text)

    def test_no_week_with_a_partial_calendar_is_plotted_as_a_collapse(self):
        """The first and last weeks of the data hold only part of the Masses and are trimmed before charting."""
        weekly = app.complete_weeks(app._normalise(app_support.run_query(
            f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA")))
        self.assertGreater(weekly["TOTAL_UMAT"].min(), 50)
        self.assertGreaterEqual(int(app.week_year(weekly).min()), 2021)

    def test_community_charts_keep_a_fixed_non_value_order(self):
        """The dumbbell and the two bar charts list communities by region and name, never by amount."""
        at = self.pages["Sumbangan khusus"]
        chosen = at.selectbox(key="kampanye_lingkungan").value
        frame = app._normalise(app_support.run_query(
            f"SELECT * FROM {app.DATABASE}.ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN"))
        frame = frame[(frame["NAMA_KAMPANYE"] == chosen) & (frame["JUMLAH_KELUARGA_PENYUMBANG"] > 0)]
        expected = list(frame.sort_values(["NAMA_WILAYAH", "NAMA_LINGKUNGAN"])["NAMA_LINGKUNGAN"])
        by_amount = list(frame.sort_values("TOTAL_SUMBANGAN")["NAMA_LINGKUNGAN"])
        self.assertNotEqual(expected, by_amount, "the check is only meaningful if the two orders differ")
        found = 0
        for chart in charts(at):
            text = chart.proto.spec
            for sort in re.findall(r'"sort":\s*(\[[^\]]*\])', text):
                names = json.loads(sort)
                if names and names[0].startswith("Lingkungan"):
                    self.assertEqual(names, expected)
                    found += 1
        self.assertGreaterEqual(found, 3, "dumbbell and two bar charts")

    def test_break_even_table_shows_a_planned_campaign_as_not_yet_computable(self):
        at = self.pages["Sumbangan khusus"]
        table = next(d.value for d in at.dataframe if "Kampanye" in d.value.columns and "Biaya aktual" in d.value.columns)
        planned = table[table["Status"].str.contains("Belum dapat dihitung")]
        self.assertGreaterEqual(len(planned), 1)
        self.assertEqual(set(planned["Terkumpul"]), {"-"})
        self.assertEqual(set(planned["Biaya aktual"]), {"-"})
        self.assertTrue(table["Status"].str.contains("Defisit").any())
        self.assertTrue(table["Status"].str.contains("Surplus").any())

    def test_summary_lists_the_nearest_activities_in_date_order(self):
        at = self.pages["Ringkasan"]
        table = next(d.value for d in at.dataframe if "Dalam" in d.value.columns)
        self.assertEqual(len(table), 3)
        self.assertEqual(table["Tahap"].str.contains("Sudah dijadwalkan").all(), True)
        days = [int(v.split()[0]) for v in table["Tanggal"]]
        self.assertEqual(days, sorted(days))
        self.assertEqual(list(table["Kegiatan"]), ["Misa Syukur Hari Ulang Tahun Paroki", "Penyuluhan Gizi Keluarga",
                                                   "Misa Syukur Ulang Tahun Perkawinan"])
        self.assertIn("4", page_text(at))  # postponed count in "Perlu perhatian"

    def test_upcoming_page_shows_the_whole_pipeline_from_plan_to_scheduled_event(self):
        at = self.pages["Kegiatan mendatang"]
        values = {m.label: str(m.value) for m in at.metric}
        self.assertEqual(values["Kegiatan mendatang"], "11")
        self.assertEqual(values["Sudah dijadwalkan"], "3")
        self.assertEqual(values["Masih rencana tahunan"], "8")
        self.assertIn("30 September 2026", page_text(at))
        self.assertEqual(at.radio(key="jangka_waktu").value, "Semua yang akan datang")
        self.assertEqual(len(charts(at)), 1, "the timeline")

    def test_upcoming_page_flags_postponed_activities_with_their_reasons_and_the_christmas_funding_gap(self):
        text = page_text(self.pages["Kegiatan mendatang"])
        self.assertIn("4 kegiatan ditunda", text)
        self.assertIn("Ditunda karena bertepatan dengan ujian sekolah", text)
        self.assertNotIn("..", text.replace("...", ""))
        self.assertIn("Rangkaian Perayaan Natal", text)
        self.assertIn("masih kurang Rp 11,1 jt", text)
        self.assertIn("kurang dari 45 hari lagi", text)

    def test_upcoming_masses_are_listed_with_their_scheduled_times(self):
        at = self.pages["Kegiatan mendatang"]
        table = next(d.value for d in at.dataframe if "Jam mulai" in d.value.columns)
        self.assertEqual(len(table), 25)
        self.assertTrue(table["Jam mulai"].str.fullmatch(r"\d\d:\d\d").all())
        self.assertTrue(table["Tanggal"].str.contains("Oktober 2026").all())

    def test_event_list_shows_the_document_each_report_came_from(self):
        at = self.pages["Rencana, anggaran, kegiatan"]
        table = next(d.value for d in at.dataframe if "Berkas laporan" in d.value.columns)
        reported = table[table["Laporan"].isin(["Final", "Draf", "Perlu Revisi"])]
        self.assertGreater(len(reported), 100)
        self.assertTrue(reported["Berkas laporan"].str.fullmatch(r"LPK-\d{4}_.+\.pdf").all())
        unreported = table[table["Laporan"].isin(["Belum ada laporan", "Belum diperlukan"])]
        self.assertEqual(set(unreported["Berkas laporan"]), {"-"})

    def test_survey_page_shows_aggregates_only(self):
        text = page_text(self.pages["Survei umat"])
        self.assertIn("responden", text)
        self.assertIn("tidak ada jawaban individu", text)


@unittest.skipUnless(HAVE_APP_STACK, NEEDS)
class InteractionTests(unittest.TestCase):
    def test_year_range_filter_narrows_the_monthly_table(self):
        at = open_page("Kolekte dan kehadiran")
        slider = at.select_slider[0]
        years = list(slider.options)
        before = len(charts(at))
        slider.set_range(years[0], years[0]).run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertEqual(len(charts(at)), before)

    def test_the_30_day_horizon_and_a_section_filter_narrow_the_agenda(self):
        at = open_page("Kegiatan mendatang")
        at.radio(key="jangka_waktu").set_value("30 hari ke depan").run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertEqual({m.label: str(m.value) for m in at.metric}["Kegiatan mendatang"], "3")
        at.radio(key="jangka_waktu").set_value("Semua yang akan datang").run()
        at.selectbox(key="seksi_mendatang").select("Seksi Liturgi").run()
        values = {m.label: str(m.value) for m in at.metric}
        self.assertEqual(values["Kegiatan mendatang"], "3", "Misa Syukur HUT Paroki, Latihan Koor, Natal")
        self.assertEqual([str(e.value) for e in at.exception], [])

    def test_a_section_without_upcoming_activities_shows_a_plain_message(self):
        at = open_page("Kegiatan mendatang")
        at.radio(key="jangka_waktu").set_value("30 hari ke depan").run()
        at.selectbox(key="seksi_mendatang").select("Seksi Liturgi").run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        at.selectbox(key="seksi_mendatang").select("Seksi Kitab Suci").run()
        self.assertTrue(any("Tidak ada kegiatan pada pilihan ini" in str(i.value) for i in at.info))
        self.assertEqual([str(e.value) for e in at.exception], [])

    def test_a_single_mass_session_can_be_chosen_on_the_masses_tab(self):
        at = open_page("Kegiatan mendatang")
        sessions = list(at.selectbox(key="sesi_mendatang").options)
        self.assertEqual(sessions[0], "Semua sesi")
        at.selectbox(key="sesi_mendatang").select(sessions[1]).run()
        self.assertEqual([str(e.value) for e in at.exception], [])

    def test_choosing_a_single_mass_session_still_renders(self):
        at = open_page("Kolekte dan kehadiran")
        sessions = list(at.selectbox[0].options)
        self.assertEqual(sessions[0], "Semua sesi")
        at.selectbox[0].select(sessions[1]).run()
        self.assertEqual([str(e.value) for e in at.exception], [])

    def test_every_event_and_every_survey_question_can_be_opened(self):
        at = open_page("Peristiwa luar biasa")
        names = list(at.selectbox[0].options)
        self.assertGreaterEqual(len(names), 10)
        for name in names:
            at.selectbox[0].select(name).run()
            self.assertEqual([str(e.value) for e in at.exception], [], name)
        at = open_page("Survei umat")
        for title in list(at.selectbox[0].options):
            at.selectbox[0].select(title).run()
            for question in list(at.selectbox[1].options):
                at.selectbox[1].select(question).run()
                self.assertEqual([str(e.value) for e in at.exception], [], question)

    def test_every_campaign_can_be_opened_on_the_donation_page(self):
        at = open_page("Sumbangan khusus")
        for key in ("kampanye_lingkungan", "kampanye_wilayah"):
            for name in list(at.selectbox(key=key).options):
                at.selectbox(key=key).select(name).run()
                self.assertEqual([str(e.value) for e in at.exception], [], name)

    def test_reload_button_clears_the_cache_without_error(self):
        at = open_page("Ringkasan")
        at.sidebar.button[0].click().run()
        self.assertEqual([str(e.value) for e in at.exception], [])


@unittest.skipUnless(HAVE_APP_STACK, NEEDS)
class WithoutSnowflakeTests(unittest.TestCase):
    def test_running_the_file_without_a_connection_explains_instead_of_crashing(self):
        """No Snowflake session and no secrets: the user sees a plain message and a technical detail box."""
        at = AppTest.from_file(str(APP_FILE), default_timeout=120).run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertTrue(at.error)
        self.assertIn("Data belum dapat dimuat", str(at.error[0].value))
        self.assertTrue(any("Detail teknis" in e.label for e in at.expander))


if __name__ == "__main__":
    unittest.main()
