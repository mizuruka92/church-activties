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

PAGES = ["Ringkasan", "Kegiatan mendatang", "Pemasukan dan pengeluaran", "Kolekte dan kehadiran", "Perkiraan kolekte", "Peristiwa luar biasa",
         "Sumbangan khusus", "Rencana, anggaran, kegiatan", "Survei umat", "Layanan dan prosedur", "Tentang data"]
CHART_PAGES = [p for p in PAGES if p not in ("Tentang data", "Layanan dan prosedur")]
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

    def test_the_docs_state_the_real_number_of_views_and_pages(self):
        words = {9: "nine", 10: "ten", 11: "eleven", 12: "twelve", 13: "thirteen"}
        dashboard = (ROOT / "docs" / "DASHBOARD.md").read_text(encoding="utf-8")
        self.assertIn(f"The sidebar menu has {words[len(app.PAGES)]} pages", dashboard)
        self.assertIn(f"fixed list of {len(app.VIEWS)} views", dashboard)
        self.assertIn(f"only the {len(app.VIEWS)} views of the `ANALISIS` schema", (ROOT / "app" / "README.md").read_text(encoding="utf-8"))
        guide = (ROOT / "docs" / "STARTER_GUIDE.md").read_text(encoding="utf-8")
        self.assertIn(f"A menu on the left with {words[len(app.PAGES)]} pages", guide)
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn(f"{len(app.PAGES)} pages in Bahasa Indonesia", readme)

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

    # --- shadow forecast page -----------------------------------------------------------------------------------------
    def spec_datasets(self, chart):
        spec = json.loads(chart.proto.spec)
        return spec.get("datasets", {})

    def percent_value(self, text):
        return float(str(text).rstrip("%").replace(".", "").replace(",", "."))

    def test_forecast_page_tells_the_two_stories_in_its_four_tiles(self):
        at = self.pages["Perkiraan kolekte"]
        values = {m.label: self.percent_value(m.value) for m in at.metric if m.label.endswith(("biasa", "rentang", "berperistiwa"))
                  or "dalam rentang" in m.label}
        self.assertLess(values["Galat pekan biasa"], 10)
        self.assertGreater(values["Pekan biasa dalam rentang"], 72)
        self.assertGreater(values["Galat pekan berperistiwa"], 25)
        self.assertLess(values["Berperistiwa dalam rentang"], 35)

    def test_forecast_page_draws_the_main_chart_the_event_chart_the_close_up_and_two_accuracy_charts(self):
        at = self.pages["Perkiraan kolekte"]
        self.assertEqual(len(charts(at)), 5)
        text = page_text(at)
        self.assertIn("empat pekan sebelum", text)
        self.assertIn("Mengapa perkiraan meleset?", text)
        self.assertIn("Seberapa tepat perkiraan ini?", text)

    def test_forecast_chart_stops_the_actual_line_at_the_data_date_but_keeps_the_forecast_going(self):
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        data, long, struck = app.forecast_frames(frame)
        actual = long[long["Seri"] == app.SERIES_ACTUAL]
        forecast = long[long["Seri"] == app.SERIES_FORECAST]
        self.assertEqual(len(forecast) - len(actual), 5, "the week in progress and four weeks ahead have a forecast but no actual")
        self.assertLess(actual["AWAL_PEKAN"].max(), pd.Timestamp("2026-09-28"))
        self.assertGreaterEqual(forecast["AWAL_PEKAN"].max(), pd.Timestamp("2026-10-26"))
        self.assertTrue(data.loc[data["KOLEKTE_AKTUAL"].isna(), "Teks aktual"].eq("belum lengkap").all())
        self.assertEqual(set(struck["ID_PERISTIWA"]), {f"PRS-{n:02d}" for n in range(2, 11)})
        spec = charts(self.pages["Perkiraan kolekte"])[0].proto.spec
        self.assertIn('"type": "rule"', spec, "the marker where the forecast goes on alone")
        self.assertIn('"resolve"', spec)

    def chart_with_both_series(self, at):
        """Charts whose single specification holds the actual line AND the forecast line."""
        return [c for c in charts(at) if app.SERIES_ACTUAL in c.proto.spec and app.SERIES_FORECAST in c.proto.spec]

    def test_the_series_are_named_the_way_the_parish_says_them(self):
        self.assertEqual(app.SERIES_ACTUAL, "Kolekte aktual")
        self.assertEqual(app.SERIES_FORECAST, "Perkiraan kolekte")

    def test_the_offertory_tab_shows_the_forecast_in_the_same_chart_as_the_actual_offertory(self):
        at = self.pages["Kolekte dan kehadiran"]
        self.assertIn("Kolekte aktual dan perkiraan kolekte, per pekan", page_text(at))
        both = self.chart_with_both_series(at)
        self.assertEqual(len(both), 1)
        spec = both[0].proto.spec
        self.assertIn('"strokeDash"', spec)
        self.assertIn("Pekan terdampak peristiwa", spec)

    def test_the_events_page_compares_the_forecast_with_the_actual_offertory_in_one_chart(self):
        at = open_page("Peristiwa luar biasa")  # a fresh page: switching the radio must not disturb the shared ones
        self.assertEqual(self.chart_with_both_series(at), [], "the attendance view has no forecast")
        self.assertIn("kolekte aktual dengan perkiraan kolekte pada grafik yang sama", page_text(at))
        at.radio(key="ukuran_peristiwa").set_value("Kolekte per pekan").run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertEqual(len(self.chart_with_both_series(at)), 1)
        self.assertTrue(any("perkiraan belum mengetahui peristiwa itu" in str(c.value) for c in at.caption))

    def test_weeks_before_the_first_forecast_keep_their_actual_value_and_have_no_forecast(self):
        weekly = app.complete_weeks(app._normalise(app_support.run_query(
            f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA")))
        forecasts = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        merged = app.weekly_with_forecast(weekly, forecasts)
        self.assertEqual(len(merged), len(weekly))
        self.assertEqual(merged["KOLEKTE_AKTUAL"].tolist(), weekly["TOTAL_KOLEKTE"].tolist())
        first_forecast = forecasts["AWAL_PEKAN"].min()
        early = merged[merged["AWAL_PEKAN"] < first_forecast]
        self.assertGreater(len(early), 20)
        self.assertTrue(early["JUMLAH_PERKIRAAN"].isna().all())
        later = merged[merged["AWAL_PEKAN"] >= first_forecast].merge(forecasts, on="AWAL_PEKAN", suffixes=("", "_v"))
        self.assertTrue((later["JUMLAH_PERKIRAAN"] == later["JUMLAH_PERKIRAAN_v"]).all())
        data, long, struck = app.forecast_frames(merged)
        self.assertEqual(long[long["Seri"] == app.SERIES_ACTUAL]["AWAL_PEKAN"].min(), weekly["AWAL_PEKAN"].min())
        self.assertGreaterEqual(long[long["Seri"] == app.SERIES_FORECAST]["AWAL_PEKAN"].min(), first_forecast)

    def test_the_weekly_chart_opens_on_the_last_year_so_that_forecast_and_actual_can_be_read_week_by_week(self):
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        recent = app.recent_window(frame)
        self.assertEqual(len(recent[recent["STATUS_PEKAN"] == "Lengkap"]), app.RECENT_WEEKS)
        self.assertEqual(len(recent[recent["STATUS_PEKAN"] != "Lengkap"]), 5, "the weeks ahead stay in view")
        self.assertEqual(recent["AWAL_PEKAN"].min(), pd.Timestamp("2025-09-29"))
        earlier = frame[frame["AWAL_PEKAN"] < pd.Timestamp("2025-01-01")]
        self.assertEqual(app.recent_window(earlier)["AWAL_PEKAN"].max(), earlier["AWAL_PEKAN"].max(), "relative to the selected years")
        for label, key in (("Kolekte dan kehadiran", "jangka_grafik_kolekte"), ("Perkiraan kolekte", "jangka_grafik_perkiraan")):
            at = self.pages[label]
            self.assertEqual(at.radio(key=key).value, app.VIEW_RECENT, label)
            self.assertEqual(list(at.radio(key=key).options), [app.VIEW_RECENT, app.VIEW_ALL])

    def test_forecast_and_actual_are_also_offered_side_by_side_as_a_table_of_the_weeks_drawn(self):
        for label in ("Kolekte dan kehadiran", "Perkiraan kolekte"):
            at = self.pages[label]
            table = next(d.value for d in at.dataframe if "Perkiraan kolekte" in d.value.columns and "Kolekte aktual" in d.value.columns)
            self.assertEqual(len(table), app.RECENT_WEEKS + 5, f"{label}: the table lists the 52 weeks of the zoomed chart and the 5 ahead")
            self.assertIn("Selisih", table.columns)
            done = table[table["Kolekte aktual"] != "-"]
            self.assertEqual(len(done), app.RECENT_WEEKS)
            self.assertTrue(done["Perkiraan kolekte"].str.startswith("Rp ").all(), label)

    def test_every_shaded_week_can_be_traced_to_its_event(self):
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        data, long, struck = app.forecast_frames(frame)
        self.assertTrue((struck["Teks peristiwa"] != "-").all())
        self.assertTrue((struck["Teks jenis"] != "-").all() and (struck["Teks tingkat"] != "-").all())
        labels = app.event_labels(struck)
        self.assertEqual(list(labels["Kode"]), [f"PRS-{n:02d}" for n in range(2, 11)], "one label per event, in date order")
        for _, event in labels.iterrows():
            weeks = struck[struck["ID_PERISTIWA"] == event["Kode"]]
            self.assertTrue(weeks["AWAL_PEKAN"].min() <= event["Tengah"] <= weeks["Akhir"].max())
        self.assertTrue(app.event_labels(struck.iloc[0:0]).empty, "a chart without event weeks has nothing to label")

    def test_the_chart_writes_the_event_code_on_the_band_and_the_band_has_a_tooltip(self):
        spec = [c for c in charts(self.pages["Perkiraan kolekte"]) if app.SERIES_ACTUAL in c.proto.spec][0].proto.spec
        self.assertIn('"angle": 270', spec, "the event code is written on the band")
        for title in ("Peristiwa", "Kode", "Jenis", "Tingkat gangguan"):
            self.assertIn(f'"title": "{title}"', spec, title)

    def test_each_weekly_chart_lists_the_events_it_shades_by_name(self):
        for label in ("Kolekte dan kehadiran", "Perkiraan kolekte"):
            text = page_text(self.pages[label])
            self.assertIn("Peristiwa pada pekan berlatar abu-abu", text, label)
            self.assertIn("**PRS-10**: Banjir Juli 2026 (Hujan Deras dan Banjir, gangguan sedang), 4 Juli 2026 sampai 12 Juli 2026", text, label)
            self.assertIn("**PRS-09**: Hujan deras masa Adven 2025", text, label)
            self.assertNotIn("PRS-08", text.split("Peristiwa pada pekan berlatar abu-abu")[1][:600], f"{label}: only the events of the zoomed year")

    def test_the_whole_range_lists_all_nine_events_the_forecast_could_cover(self):
        at = open_page("Perkiraan kolekte")
        at.radio(key="jangka_grafik_perkiraan").set_value(app.VIEW_ALL).run()
        first_list = next(str(m.value) for m in at.markdown if str(m.value).startswith("**Peristiwa pada pekan berlatar abu-abu**"))
        for number in range(2, 11):
            self.assertIn(f"**PRS-{number:02d}**", first_list)
        self.assertIn("Hujan abu vulkanik tebal Juni 2025 (Abu Vulkanik, gangguan berat), 7 Juni 2025 sampai 6 Juli 2025", first_list)

    def test_the_events_page_names_the_shaded_weeks_and_includes_the_event_before_the_first_forecast(self):
        at = open_page("Peristiwa luar biasa")
        at.radio(key="ukuran_peristiwa").set_value("Kolekte per pekan").run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        listed = next(str(m.value) for m in at.markdown if str(m.value).startswith("**Peristiwa pada pekan berlatar abu-abu**"))
        self.assertIn("**PRS-01**: Banjir besar Februari 2021", listed, "weeks before the first forecast are shaded and named too")
        self.assertIn("**PRS-10**", listed)

    def test_the_table_follows_the_zoom_of_the_chart(self):
        at = open_page("Perkiraan kolekte")
        at.radio(key="jangka_grafik_perkiraan").set_value(app.VIEW_ALL).run()
        table = next(d.value for d in at.dataframe if "Perkiraan kolekte" in d.value.columns and "Kolekte aktual" in d.value.columns)
        self.assertEqual(len(table), 274)

    def test_accuracy_figures_describe_exactly_the_weeks_that_the_year_filter_selects(self):
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        for first, last in ((2021, 2026), (2022, 2022), (2025, 2026)):
            chosen = frame[(app.week_year(frame) >= first) & (app.week_year(frame) <= last)]
            table = app.accuracy_by_kind(chosen)
            compared = chosen[chosen["STATUS_PEKAN"] == "Lengkap"]
            self.assertEqual(int(table["Pekan"].sum()), len(compared), (first, last))
            ordinary = compared[compared["JENIS_PEKAN"] == app.KIND_ORDINARY]
            expected = (100 * (ordinary["KOLEKTE_AKTUAL"] - ordinary["JUMLAH_PERKIRAAN"]).abs() / ordinary["JUMLAH_PERKIRAAN"]).mean()
            self.assertAlmostEqual(float(table.loc[table["Jenis pekan"] == app.KIND_ORDINARY, "Galat"].iloc[0]), float(expected), places=6)
        full = app.accuracy_by_kind(frame).set_index("Jenis pekan")
        yearly = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.AKURASI_PERKIRAAN_TAHUNAN"))
        for kind in app.FORECAST_KINDS:
            rows = yearly[yearly["JENIS_PEKAN"] == kind]
            self.assertEqual(int(rows["JUMLAH_PEKAN"].sum()), int(full.loc[kind, "Pekan"]))
            weighted = float((rows["GALAT_RATA_RATA_PERSEN"] * rows["JUMLAH_PEKAN"]).sum() / rows["JUMLAH_PEKAN"].sum())
            self.assertAlmostEqual(weighted, float(full.loc[kind, "Galat"]), delta=0.1, msg="the page and the SQL view agree over all years")

    def test_the_tiles_of_the_forecast_page_follow_the_year_filter(self):
        at = open_page("Perkiraan kolekte")
        at.select_slider[0].set_range(2022, 2022).run()
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN"))
        chosen = frame[(app.week_year(frame) >= 2022) & (app.week_year(frame) <= 2022)]
        table = app.accuracy_by_kind(chosen).set_index("Jenis pekan")
        shown = {m.label: str(m.value) for m in at.metric}
        self.assertEqual(shown["Galat pekan biasa"], app.percent(table.loc[app.KIND_ORDINARY, "Galat"]))
        self.assertEqual(shown["Berperistiwa dalam rentang"], app.percent(table.loc[app.KIND_EVENT, "Dalam rentang"], 0))

    def test_the_events_page_never_calls_the_eight_week_average_a_forecast(self):
        text = page_text(self.pages["Peristiwa luar biasa"])
        for wrong in ("terhadap perkiraan", "dari perkiraan,", "% dari perkiraan"):
            self.assertNotIn(wrong, text)
        self.assertIn("rata-rata 8 pekan sebelumnya", text)

    def test_a_runtime_without_a_download_button_still_shows_the_guide_and_says_so(self):
        from unittest import mock
        with mock.patch.object(app.st, "download_button", side_effect=RuntimeError("not available")):
            at = open_page("Layanan dan prosedur")
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertEqual(len(at.get("download_button")), 0)
        text = page_text(at)
        self.assertIn("Tombol unduh tidak tersedia", text)
        self.assertIn("Berusia 17 tahun ke atas", text)

    def test_a_missing_guide_file_shows_a_different_message_than_a_missing_button(self):
        from unittest import mock
        with mock.patch.object(app, "read_guide", return_value=None):
            at = open_page("Layanan dan prosedur")
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertIn("tidak ditemukan di samping aplikasi ini", page_text(at))

    def test_event_chart_lists_events_by_date_not_by_size(self):
        at = self.pages["Perkiraan kolekte"]
        frame = app._normalise(app_support.run_query(f"SELECT * FROM {app.DATABASE}.ANALISIS.BIAS_PERKIRAAN_PER_PERISTIWA"))
        expected = list(frame.sort_values("TANGGAL_MULAI")["NAMA_PERISTIWA"])
        by_size = list(frame.sort_values("SELISIH_PERSEN")["NAMA_PERISTIWA"])
        self.assertNotEqual(expected, by_size, "the check is only meaningful if the two orders differ")
        found = [json.loads(sort) for chart in charts(at) for sort in re.findall(r'"sort":\s*(\[[^\]]*\])', chart.proto.spec)]
        self.assertIn(expected, found)

    def test_forecast_page_explains_the_gap_with_the_event_log_and_admits_unexplained_misses(self):
        text = page_text(self.pages["Perkiraan kolekte"])
        self.assertIn("kali** galat biasa", text)
        self.assertIn("tidak memiliki peristiwa tercatat", text)
        self.assertIn("Perkiraan ini belum mengetahui peristiwa yang mungkin terjadi", text)

    def test_forecast_page_says_that_the_offertory_is_not_a_measure_of_faith(self):
        self.assertIn("bukan ukuran iman", page_text(self.pages["Perkiraan kolekte"]))

    # --- public services page ---------------------------------------------------------------------------------------------
    def test_services_page_lists_the_six_services_in_a_fixed_order_with_the_disclaimer(self):
        at = self.pages["Layanan dan prosedur"]
        options = list(at.selectbox[0].options)
        self.assertEqual(options, ["Baptis Dewasa", "Baptis Batuta (Bayi dan Anak di Bawah 7 Tahun)", "Krisma", "Pernikahan",
                                   "Pendaftaran Lingkungan", "Pelayanan Kematian (Tutup Usia)"])
        self.assertTrue(any("bukan ketentuan resmi" in str(w.value) for w in at.warning))
        self.assertIn("Persyaratan (9)", [t.label for t in at.tabs])
        self.assertIn("Langkah-langkah (9)", [t.label for t in at.tabs])

    def test_services_page_shows_requirements_and_steps_of_the_first_service(self):
        text = page_text(self.pages["Layanan dan prosedur"])
        for needle in ("Berusia 17 tahun ke atas", "Fotokopi kartu identitas", "Berkonsultasi di sekretariat", "Pelaku: Pastor paroki",
                       "Catatan penting.", "Tidak ada tarif wajib"):
            self.assertIn(needle, text)

    def test_guide_reader_returns_the_committed_pdf_and_nothing_outside_the_guide_folder(self):
        folder = ROOT / "app" / app.GUIDE_FOLDER
        names = sorted(p.name for p in folder.glob("*.pdf"))
        self.assertEqual(len(names), 6)
        for name in names:
            self.assertEqual(app.read_guide(name), (folder / name).read_bytes())
        for bad in ("../streamlit_app.py", "../../README.md", "sub/LYN-01_Baptis_Dewasa.pdf", "LYN-99_tidak_ada.pdf", "README.md", "", None):
            self.assertIsNone(app.read_guide(bad), bad)

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

    def test_the_weekly_forecast_chart_can_show_the_whole_range_on_both_pages(self):
        for label, key in (("Kolekte dan kehadiran", "jangka_grafik_kolekte"), ("Perkiraan kolekte", "jangka_grafik_perkiraan")):
            at = open_page(label)
            def main_chart():
                return next(c for c in charts(at) if app.SERIES_ACTUAL in c.proto.spec and app.SERIES_FORECAST in c.proto.spec)
            self.assertIn('"type": "point"', main_chart().proto.spec, f"{label}: the zoomed chart marks every week")
            at.radio(key=key).set_value(app.VIEW_ALL).run()
            self.assertEqual([str(e.value) for e in at.exception], [], label)
            self.assertNotIn('"type": "point"', main_chart().proto.spec, f"{label}: 270 weeks are drawn as lines only")

    def test_every_event_can_be_opened_on_the_forecast_page_and_the_year_filter_changes_the_tiles(self):
        at = open_page("Perkiraan kolekte")
        events = list(at.selectbox[0].options)
        self.assertEqual(len(events), 9)
        for name in events:
            at.selectbox[0].select(name).run()
            self.assertEqual([str(e.value) for e in at.exception], [], name)
            self.assertEqual(len(charts(at)), 5, name)
        before = {m.label: str(m.value) for m in at.metric}
        at.select_slider[0].set_range(2025, 2025).run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertNotEqual({m.label: str(m.value) for m in at.metric}, before)
        self.assertEqual(len(list(at.selectbox[0].options)), 2, "PRS-08 and PRS-09 started in 2025")

    def test_a_year_without_events_shows_a_plain_message_on_the_forecast_page(self):
        at = open_page("Perkiraan kolekte")
        at.select_slider[0].set_range(2021, 2021).run()
        self.assertEqual([str(e.value) for e in at.exception], [])
        self.assertEqual(len(list(at.selectbox)), 1)

    def test_every_service_can_be_opened_and_shows_its_own_steps_and_requirements(self):
        at = open_page("Layanan dan prosedur")
        expected = {
            "Krisma": ("Sudah dibaptis Katolik dan menerima Komuni Pertama", "Menerima Sakramen Krisma"),
            "Pernikahan": ("Kursus persiapan perkawinan", "Penyelidikan kanonik"),
            "Pendaftaran Lingkungan": ("Fotokopi kartu keluarga", "Menyambut keluarga baru"),
            "Pelayanan Kematian (Tutup Usia)": ("Surat keterangan kematian", "Memanggil imam saat sakit parah"),
            "Baptis Batuta (Bayi dan Anak di Bawah 7 Tahun)": ("Wali baptis", "Merayakan Sakramen Baptis"),
        }
        for name in list(at.selectbox[0].options):
            at.selectbox[0].select(name).run()
            self.assertEqual([str(e.value) for e in at.exception], [], name)
            text = page_text(at)
            self.assertIn(name, text)
            for needle in expected.get(name, ()):
                self.assertIn(needle, text, name)
            self.assertEqual(len(at.get("download_button")), 1, name)

    def test_the_death_guide_starts_with_calling_the_priest_before_the_death(self):
        at = open_page("Layanan dan prosedur")
        at.selectbox[0].select("Pelayanan Kematian (Tutup Usia)").run()
        text = page_text(at)
        self.assertLess(text.index("Memanggil imam saat sakit parah"), text.index("Memberi kabar kepada ketua lingkungan"))
        self.assertIn("Misa peringatan", text)

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
