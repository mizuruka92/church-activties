"""Tests for the standalone HTML dashboard (app/html/pusat_informasi_paroki.html).

IMPORTANT: this is NOT Snowflake. The HTML file is a static snapshot of the ANALISIS views, made from the local DuckDB
stand-in by scripts/build_html_dashboard.py. These tests open it in headless Chromium (file://, no server, no network),
visit every page, try every option of every control, and compare the figures on the tiles with the Streamlit dashboard
running on the same stand-in. A pass shows that the file works offline and tells the same story as the Streamlit
dashboard. It says nothing about Snowflake.

Needs duckdb and playwright with a Chromium; the browser tests skip without them (the comparison with Streamlit
also needs the packages of tests/requirements.txt).
"""

import re
import subprocess
import sys
import unittest
from glob import glob
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HTML_DIR = ROOT / "app" / "html"
OUTPUT = HTML_DIR / "pusat_informasi_paroki.html"
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "app"))
sys.path.insert(0, str(ROOT / "scripts"))

try:
    import duckdb  # noqa: F401
    HAVE_DUCKDB = True
except ImportError:  # pragma: no cover
    HAVE_DUCKDB = False

CHROMIUM = None
try:
    from playwright.sync_api import sync_playwright
    candidates = sorted(glob("/opt/pw-browsers/chromium-*/chrome-linux/chrome"))
    CHROMIUM = candidates[-1] if candidates else ""
    HAVE_BROWSER = True
except ImportError:  # pragma: no cover
    HAVE_BROWSER = False

try:
    from streamlit.testing.v1 import AppTest  # noqa: F401
    import app_support
    HAVE_STREAMLIT = HAVE_DUCKDB
except ImportError:  # pragma: no cover
    HAVE_STREAMLIT = False

PAGES = ["Ringkasan", "Kegiatan mendatang", "Pemasukan dan pengeluaran", "Kolekte dan kehadiran", "Perkiraan kolekte", "Peristiwa luar biasa",
         "Sumbangan khusus", "Rencana, anggaran, kegiatan", "Survei umat", "Demografi umat", "Layanan dan prosedur", "Tentang data"]
NO_CHARTS = ("Layanan dan prosedur", "Tentang data")
NEEDS_BROWSER = "playwright with a Chromium browser is not installed"

METRICS_JS = """() => Array.from(document.querySelectorAll('.metric')).map(m => [
    m.querySelector('.m-label').childNodes[0].textContent.trim(), m.querySelector('.m-value').textContent,
    (m.querySelector('.m-delta') || {}).textContent || null])"""
CONTROLS_JS = """() => {
  const found = {};
  document.querySelectorAll('select[data-key]').forEach(e => { found[e.dataset.key] = {kind: 'select', options: Array.from(e.options).map(o => o.value)}; });
  document.querySelectorAll('input[type=radio][data-key]').forEach(e => {
    (found[e.dataset.key] = found[e.dataset.key] || {kind: 'radio', options: []}).options.push(e.value); });
  return found;
}"""


_shared = {}


def shared_browser():
    """One Chromium for the whole module (Playwright's sync API can be started only once per thread)."""
    if "browser" not in _shared:
        _shared["playwright"] = sync_playwright().start()
        _shared["browser"] = _shared["playwright"].chromium.launch(executable_path=CHROMIUM) if CHROMIUM else _shared["playwright"].chromium.launch()
    return _shared["browser"]


def tearDownModule():
    if "browser" in _shared:
        _shared.pop("browser").close()
        _shared.pop("playwright").stop()


class Browser:
    """A fresh browser context that opens the file. Opening the file is the test: there is no server."""

    def __init__(self, **context):
        self.context = shared_browser().new_context(viewport={"width": 1400, "height": 900}, accept_downloads=True, **context)
        self.problems = []
        self.page = self.context.new_page()
        self.page.on("pageerror", lambda e: self.problems.append(f"pageerror: {e}"))
        self.page.on("console", lambda m: self.problems.append(f"console.{m.type}: {m.text}") if m.type in ("error", "warning") else None)
        self.page.on("request", lambda r: self.problems.append(f"network request: {r.url}") if not r.url.startswith(("file:", "data:", "blob:")) else None)
        self.page.goto(OUTPUT.as_uri())
        self.settle()

    def settle(self):
        self.page.wait_for_function("() => document.body.hasAttribute('data-ready')", timeout=60000)

    def show(self, name):
        self.page.evaluate("n => window.__dashboard.show(n)", name)
        self.settle()

    def counts(self):
        return self.page.locator(".chart").count(), self.page.locator(".chart[data-drawn]").count()

    def errors(self):
        return self.page.evaluate("window.__dashboard.errors") + self.problems

    def close(self):
        self.context.close()


@unittest.skipUnless(OUTPUT.exists(), "the HTML dashboard has not been built")
class StaticFileTests(unittest.TestCase):
    """Checks on the text of the file; no browser needed."""

    @classmethod
    def setUpClass(cls):
        cls.page = OUTPUT.read_text(encoding="utf-8")
        cls.own_code = "\n".join(path.read_text(encoding="utf-8") for path in sorted((HTML_DIR / "js").glob("*.js")))
        cls.template = (HTML_DIR / "template.html").read_text(encoding="utf-8")

    @unittest.skipUnless(HAVE_DUCKDB, "duckdb is not installed")
    def test_committed_file_is_up_to_date(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "build_html_dashboard.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_nothing_is_loaded_from_the_network(self):
        self.assertNotRegex(self.template, r"<script[^>]*\ssrc=")
        self.assertNotRegex(self.template, r"<link[^>]*href=")
        self.assertNotRegex(self.page, r"<script[^>]*\ssrc=")
        self.assertNotRegex(self.page, r"<link\b")
        for forbidden in ("fetch(", "XMLHttpRequest", "import(", "WebSocket", "sendBeacon", "http://", "https://"):
            self.assertNotIn(forbidden, self.own_code, f"the dashboard code must not use {forbidden}")

    def test_no_credentials_or_personal_data_in_the_file(self):
        # the minified libraries are full of long digit strings, so only the dashboard's own code and data are scanned
        mine = self.own_code + re.search(r"var DATA = .*?;\nvar PDFS", self.page, re.S).group(0)
        for pattern in (r"password\s*[:=]", r"BEGIN (RSA |PRIVATE )", r"api[_-]?key", r"\b\d{16}\b", r"\+62\d{8,}", r"\b08\d{9,12}\b"):
            self.assertIsNone(re.search(pattern, mine, re.I), pattern)
        self.assertNotIn("sourceMappingURL", self.page)

    def test_every_page_is_labelled_as_simulated(self):
        self.assertIn("DATA SIMULASI", self.own_code)
        self.assertIn("Data simulasi (fiktif)", self.own_code)
        self.assertIn("<title>Pusat Informasi Paroki (simulasi)</title>", self.page)

    def test_only_views_of_the_streamlit_dashboard_are_embedded(self):
        import build_html_dashboard as builder
        names = set(re.findall(r'\bV\("([A-Z_]+)"\)', self.own_code))
        self.assertTrue(names)
        self.assertLessEqual(names, set(builder.dashboard_views()))

    def test_every_pdf_named_in_the_data_is_inside_the_file_unchanged(self):
        import base64
        import json
        block = re.search(r"var DATA = (.*?);\nvar PDFS = (.*?);\n", self.page, re.S)
        data, pdfs = json.loads(block.group(1)), json.loads(block.group(2))
        names = set()
        for view, column, folder in (("KEGIATAN_DAN_LAPORAN", "NAMA_BERKAS_LAPORAN", ROOT / "data" / "documents" / "laporan_kegiatan"),
                                     ("LAYANAN_PUBLIK", "NAMA_BERKAS_PANDUAN", ROOT / "app" / "public_documents")):
            index = data[view]["c"].index(column)
            for row in data[view]["r"]:
                if row[index]:
                    names.add(row[index])
                    self.assertEqual(base64.b64decode(pdfs[row[index]]), (folder / row[index]).read_bytes(), row[index])
        self.assertEqual(names, set(pdfs), "the file holds exactly the PDFs that the tables name")
        self.assertEqual(len(names), 132 + 6)

    def test_no_data_tables_are_drawn(self):
        self.assertNotIn("<table", self.own_code.lower())

    def test_theme_colours_have_a_dark_variant(self):
        css = (HTML_DIR / "dashboard.css").read_text(encoding="utf-8")
        self.assertIn("prefers-color-scheme: dark", css)
        self.assertIn(':root[data-theme="dark"]', css)

    def test_vendored_libraries_keep_their_licences(self):
        vendor = HTML_DIR / "vendor"
        for name in ("vega", "vega-lite", "vega-embed"):
            self.assertTrue((vendor / f"{name}.min.js").is_file())
            self.assertIn("Copyright", (vendor / f"LICENSE-{name}.txt").read_text(encoding="utf-8"))


@unittest.skipUnless(HAVE_BROWSER and OUTPUT.exists(), NEEDS_BROWSER)
class BrowserTests(unittest.TestCase):
    """The file opened in headless Chromium."""

    @classmethod
    def setUpClass(cls):
        cls.web = Browser(color_scheme="light")

    @classmethod
    def tearDownClass(cls):
        cls.web.close()

    def test_menu_lists_the_same_pages_as_streamlit(self):
        self.assertEqual(self.web.page.evaluate("window.__dashboard.pages"), PAGES)

    def test_every_page_renders_and_draws_every_chart(self):
        for name in PAGES:
            with self.subTest(page=name):
                self.web.show(name)
                charts, drawn = self.web.counts()
                self.assertEqual(charts, drawn)
                if name not in NO_CHARTS:
                    self.assertGreater(charts, 0)
                self.assertGreater(self.web.page.locator("svg.marks").count() if charts else 1, 0)
                self.assertIn("DATA SIMULASI", self.web.page.inner_text("main"))
                self.assertEqual(self.web.page.locator("main h1").inner_text(), name.replace("Rencana, anggaran, kegiatan", "Rencana, anggaran, dan kegiatan"))
        self.assertEqual(self.web.errors(), [])

    def open_state(self, name, tab):
        """The page in its default state with one tab opened. Returns the label of the tab."""
        self.web.show(name)
        if tab is None:
            return None
        label = self.web.page.locator(".tab").nth(tab).inner_text()
        self.web.page.locator(".tab").nth(tab).click()
        self.web.settle()
        return label

    def test_every_option_of_every_control_works(self):
        done = 0
        for name in PAGES:
            self.web.show(name)
            tab_count = self.web.page.locator(".tab").count()
            for tab in (range(tab_count) if tab_count else [None]):
                label = self.open_state(name, tab)
                controls = self.web.page.evaluate(CONTROLS_JS)
                for key, control in controls.items():
                    # Every control starts from the default page: choosing one option can change the options of another
                    # control (for example the events that fall inside the chosen years).
                    self.open_state(name, tab)
                    for option in control["options"]:
                        with self.subTest(page=name, tab=label, control=key, option=option):
                            if control["kind"] == "select":
                                self.web.page.select_option(f'select[data-key="{key}"]', option, timeout=5000)
                            else:
                                self.web.page.locator(f'input[data-key="{key}"]').and_(self.web.page.locator(f'[value="{option}"]')).check(timeout=5000)
                            self.web.settle()
                            charts, drawn = self.web.counts()
                            self.assertEqual(charts, drawn)
                            self.assertEqual(self.web.errors(), [])
                            done += 1
        self.assertGreater(done, 100)

    def test_every_survey_and_question_can_be_chosen(self):
        self.web.show("Survei umat")
        surveys = self.web.page.evaluate(CONTROLS_JS)["survei"]["options"]
        self.assertGreaterEqual(len(surveys), 2)
        for survey in surveys:
            self.web.page.select_option('select[data-key="survei"]', survey)
            self.web.settle()
            key = [k for k in self.web.page.evaluate(CONTROLS_JS) if k.startswith("pertanyaan.")][0]
            for question in self.web.page.evaluate(CONTROLS_JS)[key]["options"]:
                with self.subTest(survey=survey, question=question):
                    self.web.page.select_option(f'select[data-key="{key}"]', question)
                    self.web.settle()
                    charts, drawn = self.web.counts()
                    self.assertGreaterEqual(charts, 1)
                    self.assertEqual(charts, drawn)
        self.assertEqual(self.web.errors(), [])

    def test_every_service_shows_its_requirements_steps_and_a_pdf(self):
        self.web.show("Layanan dan prosedur")
        services = self.web.page.evaluate(CONTROLS_JS)["layanan"]["options"]
        self.assertEqual(len(services), 6)
        for service in services:
            with self.subTest(service=service):
                self.web.page.select_option('select[data-key="layanan"]', service)
                self.web.settle()
                self.assertGreater(self.web.page.locator("ul.checklist li").count(), 2)
                self.web.page.locator(".tab").nth(1).click()
                self.web.settle()
                self.assertGreater(self.web.page.locator("ol.steps li").count(), 2)
                with self.web.page.expect_download() as download:
                    self.web.page.locator("[data-download]").click()
                saved = Path(download.value.path())
                self.assertEqual(saved.read_bytes()[:5], b"%PDF-")
                self.assertTrue(download.value.suggested_filename.endswith(".pdf"))
                self.web.page.locator(".tab").nth(0).click()
                self.web.settle()

    def test_a_report_opens_in_a_new_tab_and_downloads_for_every_report_in_the_picker(self):
        import base64
        self.web.show("Rencana, anggaran, kegiatan")
        self.web.page.locator(".tab").nth(1).click()
        self.web.settle()
        options = self.web.page.evaluate(CONTROLS_JS)["laporan_kegiatan"]["options"]
        self.assertEqual(len(options), 132)
        for position in sorted({0, 1, 40, 80, 130, 131}):
            event_id = options[position].split(" | ")[0]
            with self.subTest(report=options[position]):
                self.web.page.select_option('select[data-key="laporan_kegiatan"]', options[position])
                self.web.settle()
                self.assertIn("Buka laporan (PDF)", self.web.page.inner_text("main"))
                file_name = self.web.page.locator("[data-download]").get_attribute("data-download")
                self.assertTrue(file_name.endswith(".pdf"))
                raw = base64.b64decode(self.web.page.evaluate("f => PDFS[f]", file_name))
                self.assertEqual(raw[:5], b"%PDF-")
                self.assertIn(b"LPK-", raw)
                with self.web.page.expect_popup() as popup:
                    self.web.page.locator("[data-open]").click()
                tab = popup.value
                tab.wait_for_load_state()
                self.assertTrue(tab.url.startswith("blob:"), tab.url)
                self.assertEqual(tab.evaluate("document.contentType"), "application/pdf")
                tab.close()
                with self.web.page.expect_download() as download:
                    self.web.page.locator("[data-download]").click()
                self.assertEqual(download.value.suggested_filename, file_name)
                self.assertEqual(Path(download.value.path()).read_bytes(), raw)
                self.assertTrue(file_name.startswith("LPK-"), "the file is a report")
        self.assertEqual(self.web.errors(), [])

    def test_the_report_picker_follows_the_section_and_describes_the_event(self):
        self.web.show("Rencana, anggaran, kegiatan")
        self.web.page.locator(".tab").nth(1).click()
        self.web.settle()
        self.web.page.select_option('select[data-key="seksi_kegiatan"]', "Seksi Katekese")
        self.web.settle()
        options = self.web.page.evaluate(CONTROLS_JS)["laporan_kegiatan"]["options"]
        self.assertTrue(0 < len(options) < 132)
        text = self.web.page.inner_text("main")
        self.assertIn("(Seksi Katekese)", text)
        self.assertRegex(text, r"Laporan LPK-\d{4}, tanggal \d+ \w+ \d{4}\.")
        self.assertIn("Peserta aktual / target", text)

    def test_the_forecast_chart_names_the_events_behind_the_grey_weeks_in_the_close_up_too(self):
        self.web.show("Perkiraan kolekte")
        self.web.page.locator('select[data-key="pilih_peristiwa_perkiraan"]').select_option(index=0)
        self.web.settle()
        self.assertRegex(self.web.page.locator("#chart3").inner_html(), r"PRS-\d\d")

    def test_forecast_chart_names_the_events_behind_the_grey_weeks(self):
        self.web.show("Perkiraan kolekte")
        self.web.page.locator('input[data-key="jangka_grafik_perkiraan"]').nth(1).check()
        self.web.settle()
        svg = self.web.page.locator("#chart1").inner_html()
        self.assertRegex(svg, r"PRS-\d\d")
        self.assertIn("Pekan terdampak peristiwa", svg)
        listing = self.web.page.locator(".event-list").first.inner_text()
        self.assertRegex(listing, r"PRS-\d\d: .+ \(.+, gangguan .+\), \d+ \w+ \d{4} sampai \d+ \w+ \d{4}")

    def test_forecast_and_actual_share_one_chart(self):
        self.web.show("Perkiraan kolekte")
        legend = self.web.page.locator("#chart1").inner_text()
        for label in ("Kolekte aktual", "Perkiraan kolekte"):
            self.assertIn(label, legend)

    def test_a_page_opens_from_its_link_and_an_unknown_link_opens_the_first_page(self):
        other = Browser(color_scheme="light")
        try:
            other.page.goto(OUTPUT.as_uri() + "#Perkiraan%20kolekte")
            other.settle()
            self.assertEqual(other.page.locator("main h1").inner_text(), "Perkiraan kolekte")
            other.page.goto(OUTPUT.as_uri() + "#tidak-ada")
            other.settle()
            self.assertEqual(other.page.locator("main h1").inner_text(), "Ringkasan")
            self.assertEqual(other.errors(), [])
        finally:
            other.close()

    def test_pages_do_not_overflow_a_phone_screen(self):
        phone = Browser(color_scheme="light")
        try:
            phone.page.set_viewport_size({"width": 390, "height": 800})
            for name in PAGES:
                phone.show(name)
                phone.page.wait_for_timeout(100)
                width = phone.page.evaluate("document.documentElement.scrollWidth")
                self.assertLessEqual(width, 392, f"{name} is {width}px wide on a 390px screen")
            self.assertEqual(phone.errors(), [])
        finally:
            phone.close()


@unittest.skipUnless(HAVE_BROWSER and OUTPUT.exists(), NEEDS_BROWSER)
class ThemeAndTimeZoneTests(unittest.TestCase):

    def test_dark_scheme_follows_the_system_and_draws_every_chart(self):
        web = Browser(color_scheme="dark")
        try:
            self.assertEqual(web.page.evaluate("getComputedStyle(document.body).backgroundColor"), "rgb(20, 20, 19)")
            for name in PAGES:
                web.show(name)
                charts, drawn = web.counts()
                self.assertEqual(charts, drawn)
            self.assertEqual(web.errors(), [])
        finally:
            web.close()

    def test_theme_button_cycles_and_remembers(self):
        web = Browser(color_scheme="light")
        try:
            self.assertEqual(web.page.inner_text("#theme-toggle"), "Tema: otomatis")
            web.page.click("#theme-toggle")
            web.settle()
            self.assertEqual(web.page.inner_text("#theme-toggle"), "Tema: terang")
            web.page.click("#theme-toggle")
            web.settle()
            self.assertEqual(web.page.inner_text("#theme-toggle"), "Tema: gelap")
            self.assertEqual(web.page.evaluate("getComputedStyle(document.body).backgroundColor"), "rgb(20, 20, 19)")
            self.assertEqual(web.errors(), [])
        finally:
            web.close()

    def test_dates_do_not_shift_in_other_time_zones(self):
        seen = {}
        for zone in ("Asia/Jakarta", "Pacific/Kiritimati", "America/Los_Angeles"):
            web = Browser(timezone_id=zone)
            try:
                text = {}
                for name in ("Ringkasan", "Kegiatan mendatang", "Peristiwa luar biasa", "Perkiraan kolekte"):
                    web.show(name)
                    text[name] = web.page.inner_text("main")
                seen[zone] = text
                self.assertEqual(web.errors(), [])
            finally:
                web.close()
        zones = list(seen)
        for other in zones[1:]:
            self.assertEqual(seen[zones[0]], seen[other], f"{other} shows other text than {zones[0]}")


@unittest.skipUnless(HAVE_BROWSER and HAVE_STREAMLIT and OUTPUT.exists(), "playwright or the Streamlit test packages are missing")
class ParityWithStreamlitTests(unittest.TestCase):
    """The tiles of the HTML file must show the same figures as the Streamlit dashboard on the same data."""

    PARITY_PAGES = ["Ringkasan", "Kegiatan mendatang", "Kolekte dan kehadiran", "Perkiraan kolekte", "Peristiwa luar biasa", "Demografi umat",
                    "Rencana, anggaran, kegiatan"]

    @classmethod
    def setUpClass(cls):
        cls.web = Browser(color_scheme="light")

    @classmethod
    def tearDownClass(cls):
        cls.web.close()

    def streamlit_tiles(self, name):
        from test_app import open_page
        at = open_page(name)
        self.assertFalse(at.exception)
        found = {}
        for metric in at.metric:
            found.setdefault(metric.label, []).append((metric.value, (metric.delta or "").strip() or None))
        return found

    def test_number_formats_match_the_python_formats_exactly(self):
        """The JavaScript formatters must give the very same text as the Python ones, ties and tiny negatives included."""
        import random
        import streamlit_app as app
        rng = random.Random(20261023)
        values = [0, 0.5, 1.5, 2.5, 0.125, 0.375, 29.05, 11.05, 0.05, 1234.5, -0.04, -2.5, 999999.5]
        values += [rng.randrange(0, 5_000_000_000) for _ in range(300)]
        values += [rng.randrange(0, 10**9, 10**4) for _ in range(300)]          # whole tens of thousands: juta() meets .05 and .005
        values += [round(rng.uniform(-1000, 1000), rng.randint(1, 4)) for _ in range(300)]
        values += [rng.randrange(-4000, 4000) / 2 ** rng.randint(1, 6) for _ in range(300)]  # exactly representable ties
        values += [round(rng.uniform(-150, 150), 2) for _ in range(200)]
        cases, expected = [], []
        for value in values:
            for name, js_name, call in (
                    ("number", "number", lambda v, d: app.number(v, d)), ("juta", "juta", lambda v, d: app.juta(v, d)),
                    ("percent", "percent", lambda v, d: app.percent(v, d)), ("signed", "signedPercent", lambda v, d: app.signed_percent(v, d))):
                for digits in (0, 1, 2, 3):
                    cases.append([js_name, value, digits])
                    expected.append(call(value, digits))
            cases.append(["rupiah", value, 0])
            expected.append(app.rupiah(value))
        got = self.web.page.evaluate("cases => cases.map(([fn, v, d]) => window[fn](v, d))", cases)
        wrong = [(c, e, g) for c, e, g in zip(cases, expected, got) if e != g]
        self.assertEqual(wrong[:10], [], f"{len(wrong)} of {len(cases)} formatted values differ from Python")

    # Sentences that exist only on the HTML page on purpose: they replace a table, or say what the file is.
    HTML_ONLY = ("Jumlah tercatat adalah angka", "Dari ", "Penyumbang sedikit", "Buka ", "Unduh ", "Tentang berkas ini",
                 "Ini adalah salinan statis", "Grafik dibuat dari")
    TEXT_JS = """() => {
      const out = [];
      document.querySelectorAll('main .caption, main .callout, main > p, main .cols p, main li, main h2, main h3').forEach(e => {
        if (!e.closest('.agenda, .checklist, .steps, .event-list, .metric, details')) { out.push(e.innerText); }
      });
      document.querySelectorAll('main details').forEach(d => d.querySelectorAll('li').forEach(e => out.push(e.innerText)));
      return out;
    }"""

    @staticmethod
    def squeeze(text):
        text = text.replace("**", "").replace("*", "").replace("`", "").replace("\u00a0", " ")
        return re.sub(r"\s+", " ", re.sub(r"^[-\u2022]\s+", "", text, flags=re.M)).strip().lower()

    def test_every_sentence_is_the_same_as_on_the_streamlit_page(self):
        """Captions, warnings, headings and bullet points (with their figures) are copied text: each must also be on the Streamlit page."""
        from test_app import open_page, page_text
        checked = 0
        for name in PAGES:
            with self.subTest(page=name):
                reference = self.squeeze(page_text(open_page(name)))
                self.web.show(name)
                tab_count = self.web.page.locator(".tab").count()
                for tab in (range(tab_count) if tab_count else [None]):
                    self.web.show(name)
                    if tab is not None:
                        self.web.page.locator(".tab").nth(tab).click()
                        self.web.settle()
                    for sentence in self.web.page.evaluate(self.TEXT_JS):
                        if not sentence.strip() or sentence.startswith(self.HTML_ONLY):
                            continue
                        checked += 1
                        self.assertIn(self.squeeze(sentence), reference, f"{name}: not on the Streamlit page: {sentence[:200]!r}")
        self.assertGreater(checked, 100)

    @staticmethod
    def streamlit_numbers(chart, found):
        """The numbers in the data of a Streamlit chart: inline datasets of the spec (older Streamlit) and the Arrow tables of the
        message (current Streamlit)."""
        import json
        import pyarrow as pa
        ParityWithStreamlitTests.numbers_in(json.loads(chart.proto.spec).get("datasets", {}), found)
        for dataset in chart.proto.datasets:
            for row in pa.ipc.open_stream(dataset.data.data).read_all().to_pylist():
                ParityWithStreamlitTests.numbers_in(list(row.values()), found)

    @staticmethod
    def numbers_in(node, found):
        """Every number in the data of a chart spec (Streamlit: its datasets; HTML: the inline data values). Timestamps are skipped."""
        import decimal
        if isinstance(node, bool):
            return
        if isinstance(node, decimal.Decimal):
            node = float(node)
        if isinstance(node, (int, float)):
            if abs(node) < 1e11 and node == node:
                found.append(float(node))
        elif isinstance(node, dict):
            for key, value in node.items():
                ParityWithStreamlitTests.numbers_in(value, found)
        elif isinstance(node, list):
            for value in node:
                ParityWithStreamlitTests.numbers_in(value, found)

    TABLE_CHARTS = ("% setuju atau sangat setuju",)

    @staticmethod
    def table_numbers(at):
        """The numbers written in the tables of a Streamlit page (they are formatted text such as '53,6%')."""
        found = []
        for frame in at.dataframe:
            for cell in frame.value.astype(str).to_numpy().ravel():
                for token in re.findall(r"-?\d[\d.]*(?:,\d+)?", cell):
                    found.append(float(token.replace(".", "").replace(",", ".")))
        return found

    @staticmethod
    def inline_numbers(spec, found):
        """The numbers of the rows in the `data.values` of a Vega-Lite spec and its layers (not axis settings, sizes or domains)."""
        if isinstance(spec, dict):
            data = spec.get("data")
            if isinstance(data, dict) and isinstance(data.get("values"), list):
                ParityWithStreamlitTests.numbers_in(data["values"], found)
            for layer in spec.get("layer", []):
                ParityWithStreamlitTests.inline_numbers(layer, found)

    def test_every_figure_drawn_in_a_chart_is_a_figure_of_the_streamlit_chart(self):
        """The HTML charts compute some of their data again in JavaScript (sums, averages, shares). Each number they draw must also be
        in the data of one of the charts of the same Streamlit page, so a wrong aggregation shows up here."""
        import bisect
        import json
        from test_app import charts, open_page
        checked = 0
        for name in PAGES:
            if name in NO_CHARTS:
                continue
            with self.subTest(page=name):
                at = open_page(name)
                reference = []
                for chart in charts(at):
                    self.streamlit_numbers(chart, reference)
                reference = sorted(set(reference))
                self.web.show(name)
                tab_count = self.web.page.locator(".tab").count()
                for tab in (range(tab_count) if tab_count else [None]):
                    self.web.show(name)
                    if tab is not None:
                        self.web.page.locator(".tab").nth(tab).click()
                        self.web.settle()
                    drawn, from_table = [], []
                    for spec in self.web.page.evaluate("window.__dashboard.charts()"):
                        # a chart that stands in for a table of the Streamlit page can only be compared with the figures in that table
                        marker = any(label in json.dumps(spec) for label in self.TABLE_CHARTS)
                        self.inline_numbers(spec, from_table if marker else drawn)
                    if from_table:
                        shown = self.table_numbers(at)
                        for value in sorted(set(from_table)):
                            self.assertTrue(any(abs(value - other) <= 0.06 for other in shown),
                                            f"{name}: the chart draws {value}, which is in no table of the Streamlit page")
                            checked += 1
                    for value in sorted(set(drawn)):
                        at_index = bisect.bisect_left(reference, value - 1e-6 * max(1.0, abs(value)))
                        near = at_index < len(reference) and reference[at_index] <= value + 1e-6 * max(1.0, abs(value))
                        self.assertTrue(near, f"{name}: the HTML chart draws {value}, which is in no chart of the Streamlit page")
                        checked += 1
        self.assertGreater(checked, 500)

    def test_tiles_show_the_same_figures(self):
        compared = 0
        for name in self.PARITY_PAGES:
            with self.subTest(page=name):
                reference = self.streamlit_tiles(name)  # Streamlit draws every tab, so it holds the tiles of all of them
                self.web.show(name)
                tab_count = self.web.page.locator(".tab").count()
                for tab in (range(tab_count) if tab_count else [None]):
                    self.web.show(name)
                    if tab is not None:
                        self.web.page.locator(".tab").nth(tab).click()
                        self.web.settle()
                    for label, value, delta in self.web.page.evaluate(METRICS_JS):
                        self.assertIn(label, reference, f"{label} is not a tile of the Streamlit page")
                        values = [v for v, _ in reference[label]]
                        self.assertIn(value, values, f"{name} / {label}: HTML shows {value}, Streamlit shows {values}")
                        if delta:
                            deltas = [d for _, d in reference[label]]
                            self.assertIn(delta.strip(), deltas, f"{name} / {label}: HTML delta {delta}, Streamlit {deltas}")
                        compared += 1
        self.assertGreater(compared, 30)


if __name__ == "__main__":
    unittest.main()
