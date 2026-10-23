# Dashboard design (Phase 2)

Technical description of the Streamlit dashboard in [`app/streamlit_app.py`](../app/streamlit_app.py): what each
page shows, which views it reads, and why it is built the way it is. To get it running, follow the
[starter guide](STARTER_GUIDE.md). To work on the code, see [`app/README.md`](../app/README.md).

All data is simulated. Every page shows a notice that says so.

## 1. Pages

The sidebar menu has eleven pages. The text on screen is Bahasa Indonesia; this document is English.

| Page | Question it answers | Views it reads |
|---|---|---|
| Ringkasan | How are we doing, and what needs attention? Eight headline figures, the income-versus-outcome chart with its trend, the three nearest upcoming activities, and a short list of things to watch. | `PEMASUKAN_PENGELUARAN_TAHUNAN`, `PROYEKSI_PEMASUKAN_PENGELUARAN`, `KEGIATAN_MENDATANG`, `KEHADIRAN_MISA_BULANAN`, `TITIK_IMPAS_KAMPANYE`, `DAMPAK_PERISTIWA_LUAR_BIASA`, `KELENGKAPAN_LAPORAN_PER_SEKSI` |
| Kegiatan mendatang | What is coming up, and what needs a decision? Tab 1: filter by horizon (30 days, 60 days, all) and section; four tiles; an agenda grouped by month; a timeline by section; an attention list (postponed activities with their reasons, the Christmas funding gap, activities close to their date that are still only a plan). Tab 2: the Masses scheduled after the data date, with their scheduled start times. | `KEGIATAN_MENDATANG`, `PELAKSANAAN_MISA` |
| Pemasukan dan pengeluaran | Is the offertory still larger than programme spending, and when might that change? Yearly chart with straight-line projection, growth rates (raw and without event weeks), monthly chart with a year filter. | `PEMASUKAN_PENGELUARAN_TAHUNAN`, `PROYEKSI_PEMASUKAN_PENGELUARAN`, `PEMASUKAN_PENGELUARAN_BULANAN` |
| Kolekte dan kehadiran | What moves the offertory? Filter by Mass session and years. Tabs: attendance per month, **the weekly actual offertory with the stored forecast in the same chart** (opens on the last 12 months with a point per week, or the whole range) followed by offertory by collection type with reconciliation status, offertory per attendee by day of the month (payday effect), weekly attendance versus offertory with a fitted line. | `KEHADIRAN_MISA_BULANAN`, `KOLEKTE_MISA_BULANAN`, `KOLEKTE_MINGGUAN_DAN_PERISTIWA`, `KOLEKTE_AKTUAL_VS_PERKIRAAN`, `POLA_KOLEKTE_HARI_DALAM_BULAN`, `KORELASI_KOLEKTE_KEHADIRAN`, `TREN_KEHADIRAN_PERIODE` |
| Perkiraan kolekte | How good is the stored forecast of the weekly offertory, and which events explain the misses? Four tiles (error and share inside the 80% range, for ordinary weeks and for event weeks), a line chart of actual versus forecast with the range and the event weeks shaded, a table of weeks outside the range (explained by an event, or honestly unexplained), one bar per event showing its gap against the usual error, a close-up of a chosen event, accuracy by kind of week, and the forecast for the weeks ahead. | `KOLEKTE_AKTUAL_VS_PERKIRAAN`, `BIAS_PERKIRAAN_PER_PERISTIWA`, `AKURASI_PERKIRAAN_TAHUNAN` |
| Peristiwa luar biasa | What did rain, haze, ash or a power cut do, and why would a forecast be off? Weekly line chart with event weeks marked (for attendance against the 8-week average, for the offertory against the stored forecast in one chart), attendance and offertory against expectation per event, a detail card per event. | `KOLEKTE_MINGGUAN_DAN_PERISTIWA`, `KOLEKTE_AKTUAL_VS_PERKIRAAN`, `DAMPAK_PERISTIWA_LUAR_BIASA` |
| Sumbangan khusus | Do Lent and Advent gifts cover Easter and Christmas? How are gifts distributed over communities (mean versus median, total versus per person)? Which regions have reported? | `TITIK_IMPAS_KAMPANYE`, `SUMBANGAN_KELUARGA_PER_LINGKUNGAN`, `SUMBANGAN_KHUSUS_PER_WILAYAH` |
| Rencana, anggaran, kegiatan | How much of the budget was used, and how complete are the reports? Budget use per section and year, programme list with filters, report completeness, target versus actual participants, and an event list that names the source document of each report ("Berkas laporan"). | `ANGGARAN_VS_REALISASI_SEKSI`, `ANGGARAN_VS_REALISASI_PROGRAM`, `KEGIATAN_DAN_LAPORAN`, `KELENGKAPAN_LAPORAN_PER_SEKSI` |
| Survei umat | What do the survey results say? One survey and question at a time, percentages with response counts, Likert summary. | `HASIL_SURVEI`, `RINGKASAN_SKOR_LIKERT` |
| Layanan dan prosedur | What do I need, and what are the steps, to be baptised, confirmed or married, to join a community, or when someone dies? A disclaimer, a list of the six services, a selector, two tabs (requirements as a checklist, numbered steps with who does each), the important notes and a download button for the PDF guide. Public information: it never shows personal data. | `LAYANAN_PUBLIK`, `LANGKAH_LAYANAN_PUBLIK`, `PERSYARATAN_LAYANAN_PUBLIK` |
| Tentang data | What is this data and how far does it go? Purpose, privacy, how to read the projection, the list of views, the date of the latest held Mass. | `PELAKSANAAN_MISA` |

The use cases behind the first five pages, with the figures they show, are in [USE_CASES.md](USE_CASES.md).

**About "upcoming".** Everything on the page is relative to the data date (30 September 2026 in the demo), which the page states at the
top, and never to the clock, so the demo shows the same thing whenever it is opened. A test fails if the app reads the current date.
The three stages (*Sudah dijadwalkan*, *Masih rencana tahunan*, *Ditunda*) mirror the life of an activity: annual plan with budget, then a
registered event with date, place and participant target, then the post-event report on the "Rencana, anggaran, kegiatan" page.
The 45-day threshold for "close to its date but still only a plan" is the constant `PREPARATION_DAYS` in the app.

Two `ANALISIS` views are deliberately not used: `STRUKTUR_WILAYAH` (no page needs the region tree) and
`RINGKASAN_UMAT_PER_LINGKUNGAN` (household and people counts per community; leaving it out keeps the
parishioner data out of the dashboard entirely).

## 2. Design decisions

1. **One file.** A single `streamlit_app.py` can be pasted straight into the Snowsight Streamlit editor, which is the
   least fragile way for a first-time user. It is also what a Git-based deployment points at. The price is a long file,
   organised in labelled sections (data access, formatting, charts, one function per page).
2. **Only the `ANALISIS` views.** The app has exactly one query shape, `SELECT * FROM <database>.ANALISIS.<view>`, for a
   fixed list of 27 views (`VIEWS`). Filtering and charting happen in pandas, because the views are small (the largest has
   about 1,800 rows). This keeps SQL out of the app and means the app cannot read a detail table even by mistake.
   Tests check the query shape, that every listed view exists in `sql/05_create_views.sql`, and that each is used.
3. **One function talks to Snowflake.** `run_query` uses the active Snowpark session when running inside Streamlit in
   Snowflake, and `st.connection("snowflake")` elsewhere. The tests replace it. Results are normalised (upper-case names,
   decimals to numbers, dates to timestamps) because Snowflake and DuckDB return slightly different Python types.
4. **Cached, with a reload button.** Each view is cached for ten minutes to keep warehouse use low. "Muat ulang data" clears the cache.
5. **Plain failure.** If Snowflake cannot be reached or a view is missing, the page shows a short Bahasa Indonesia explanation and an
   expandable technical detail instead of a stack trace.
6. **Old and new Streamlit.** The Streamlit version in a Snowflake account is not known in advance. The app avoids new-only
   features, parses under the Python 3.9 grammar, and was run on Streamlit 1.35 with Altair 4.2 as well as on 1.66 with Altair 6.
7. **Simulated-data notice on every page**, and again on the page "Tentang data".
8. **No ranking.** No chart or table is sorted by amount. Communities and regions appear in a fixed order (region, then name),
   categories keep their natural order, and events keep chronological order. A test scans the visible text for ranking
   words. The donation page opens with a notice that the numbers describe economic capacity and the shape of gifts, not faith or
   generosity. Communities with fewer than five donors are flagged as unstable.
9. **Privacy by construction.** The dashboard never names the detail schemas or any personal column (a test enforces it), shows
   aggregates only, and offers no way to open a single household or gift.
10. **Honest forecasting.** The projection chart labels the dashed line "Garis tren dan proyeksi", marks the crossing year, states
    the method (a straight line through complete years), and leaves the partial current year out of the actual points.
    Events are shown next to the forecast so that deviations can be explained.
11. **A forecast is shown as it was issued.** The page "Perkiraan kolekte" reads the stored shadow forecast and never recomputes it. Wherever the weekly offertory is charted, the forecast is **in the same chart** as the actual (series "Kolekte aktual" and "Perkiraan kolekte"), with a table of the same figures beside it. Over five years the two weekly lines overlap, so the chart opens on the last 12 months with a point per week and months on the axis; "Seluruh rentang tahun" shows everything. Every shaded week can be traced to its event in three ways: hovering the grey band shows the event (name, code, kind, severity, week), the code (for example PRS-08) is written on the band, and a list under the chart names each event drawn with its kind, severity and exact dates. The actual line stops at the data date, the forecast goes on, and a dashed marker says "Perkiraan ke depan". The 80% range is drawn as a pale band, and the weeks outside it are listed with the event that explains them or the plain words "tanpa peristiwa tercatat", because about one ordinary week in six is expected to miss. Events are shown in date order with their gap next to the usual error, not sorted by size.
12. **Public pages carry no personal data and tolerate a missing file.** "Layanan dan prosedur" reads three public views and renders the guide as text, so it works even where the PDFs are not available. The download button appears only when `app/public_documents/<file>` exists next to the app, and the reader accepts a plain `.pdf` file name only, never a path (a test tries `../` and sub-folders). A visible warning on the page says the guides are examples and not official rules.

## 3. Charts

The charts follow a small set of rules: thin marks (2 px lines, bars at most 24 px thick with rounded ends), a quiet grid, a legend
whenever there are two or more series, one axis per chart (no dual axes), fixed series colours, and values on the end of bars
rather than on every point. Hover shows a tooltip with a formatted value, and a table is offered for the data behind the charts.

Colours are the first three slots of a validated categorical palette, in order (blue, orange, green), with separate steps for
light and dark themes. The app picks the set from the active theme (`st.context.theme` or the configured base theme, light if
unknown). Text drawn inside charts follows the theme too.

| Mode | Colours | Worst neighbouring colour-blind separation (OKLab x 100, target 8) | Contrast against the surface |
|---|---|---:|---|
| Light | `#2a78d6`, `#eb6834`, `#1baf7a` | 9.2 | green is 2.7:1 |
| Dark | `#3987e5`, `#d95926`, `#199e70` | 9.4 | all at least 3:1 |

Green is below 3:1 on a light background, so every chart that uses it (growth lines, offertory by collection type, report completeness)
is followed by a table with the same values. Charts with at most two series never use green.

Dates on chart axes show only the year because the axis library formats month names in English. Months are written in Indonesian in
tooltips, tables and captions. Number formatting in tables, tiles and tooltips uses Indonesian conventions (dot for thousands,
comma for decimals); the numeric tick labels on axes follow the browser locale.

## 4. What is not in the dashboard

* No map. The illustrative geometry lives in `MASTER_DATA` and is not exposed through any view. A map would risk looking like the real
  parish boundaries, so it is left for a later phase.
* No data export (the only downloads are the public PDF service guides), no login, no per-user access rules. Who may open the app is controlled in Snowflake (see the starter guide, part 9).
* No write-back. The app only reads.
* The only forecasts are the straight-line projection of income versus outcome and the stored weekly shadow forecast. No operating costs. See [USE_CASES.md](USE_CASES.md).

## 5. Limits of this version

* The dashboard was tested against a DuckDB stand-in and in a headless browser, not against Snowflake or inside Streamlit in
  Snowflake. Things that can differ in a real account: the Streamlit version and runtime, how `st.set_page_config` and `st.context`
  behave in the container, and the time the first query takes while the warehouse starts.
* Layout was reviewed on desktop-width screens (about 1,400 px). Phone widths were not reviewed.
* The PDF download on "Layanan dan prosedur" needs the files next to the app and a runtime that offers `st.download_button`. Snowflake's documentation for Native Apps lists that button as unsupported on the warehouse runtime and the general limitations page does not mention it, so it is unverified for an ordinary Streamlit in Snowflake app. The page works either way: it shows the whole guide as text, and says in a caption when the file or the button is missing.
* The close-up chart on the forecast page labels its date axis with a small Vega expression (Indonesian month abbreviations, because the axis library would otherwise print English months). It rendered correctly on Streamlit 1.35 and 1.66 in a headless browser, but not in Streamlit in Snowflake.
* Charts are drawn by Vega-Lite through Altair, so very old Streamlit releases that predate Altair 4 are not supported.

## 6. The offline HTML copy

[HTML_DASHBOARD.md](HTML_DASHBOARD.md) describes a single-file copy of this dashboard (charts and dropdowns, no tables, a snapshot of the data) that opens
without Snowflake, Streamlit or internet. It ports the pages and charts of `streamlit_app.py` to JavaScript, so a change to a page here needs the same change
there. `tests/test_html_dashboard.py` compares the figures on the tiles of both dashboards and fails when they differ.
