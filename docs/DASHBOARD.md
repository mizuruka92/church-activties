# Dashboard design (Phase 2)

Technical description of the Streamlit dashboard in [`app/streamlit_app.py`](../app/streamlit_app.py): what each
page shows, which views it reads, and why it is built the way it is. To get it running, follow the
[starter guide](STARTER_GUIDE.md). To work on the code, see [`app/README.md`](../app/README.md).

All data is simulated. Every page shows a notice that says so.

## 1. Pages

The sidebar menu has eight pages. The text on screen is Bahasa Indonesia; this document is English.

| Page | Question it answers | Views it reads |
|---|---|---|
| Ringkasan | How are we doing, and what needs attention? Eight headline figures, the income-versus-outcome chart with its trend, and a short list of things to watch. | `PEMASUKAN_PENGELUARAN_TAHUNAN`, `PROYEKSI_PEMASUKAN_PENGELUARAN`, `KEHADIRAN_MISA_BULANAN`, `TITIK_IMPAS_KAMPANYE`, `DAMPAK_PERISTIWA_LUAR_BIASA`, `KELENGKAPAN_LAPORAN_PER_SEKSI` |
| Pemasukan dan pengeluaran | Is the offertory still larger than programme spending, and when might that change? Yearly chart with straight-line projection, growth rates (raw and without event weeks), monthly chart with a year filter. | `PEMASUKAN_PENGELUARAN_TAHUNAN`, `PROYEKSI_PEMASUKAN_PENGELUARAN`, `PEMASUKAN_PENGELUARAN_BULANAN` |
| Kolekte dan kehadiran | What moves the offertory? Filter by Mass session and years. Tabs: attendance per month, offertory by collection type with reconciliation status, offertory per attendee by day of the month (payday effect), weekly attendance versus offertory with a fitted line. | `KEHADIRAN_MISA_BULANAN`, `KOLEKTE_MISA_BULANAN`, `KOLEKTE_MINGGUAN_DAN_PERISTIWA`, `POLA_KOLEKTE_HARI_DALAM_BULAN`, `KORELASI_KOLEKTE_KEHADIRAN`, `TREN_KEHADIRAN_PERIODE` |
| Peristiwa luar biasa | What did rain, haze, ash or a power cut do, and why would a forecast be off? Weekly line chart with event weeks marked, attendance and offertory against expectation per event, a detail card per event. | `KOLEKTE_MINGGUAN_DAN_PERISTIWA`, `DAMPAK_PERISTIWA_LUAR_BIASA` |
| Sumbangan khusus | Do Lent and Advent gifts cover Easter and Christmas? How are gifts distributed over communities (mean versus median, total versus per person)? Which regions have reported? | `TITIK_IMPAS_KAMPANYE`, `SUMBANGAN_KELUARGA_PER_LINGKUNGAN`, `SUMBANGAN_KHUSUS_PER_WILAYAH` |
| Rencana, anggaran, kegiatan | How much of the budget was used, and how complete are the reports? Budget use per section and year, programme list with filters, report completeness, target versus actual participants. | `ANGGARAN_VS_REALISASI_SEKSI`, `ANGGARAN_VS_REALISASI_PROGRAM`, `KEGIATAN_DAN_LAPORAN`, `KELENGKAPAN_LAPORAN_PER_SEKSI` |
| Survei umat | What do the survey results say? One survey and question at a time, percentages with response counts, Likert summary. | `HASIL_SURVEI`, `RINGKASAN_SKOR_LIKERT` |
| Tentang data | What is this data and how far does it go? Purpose, privacy, how to read the projection, the list of views, the date of the latest held Mass. | `PELAKSANAAN_MISA` |

The use cases behind the first five pages, with the figures they show, are in [USE_CASES.md](USE_CASES.md).

Two `ANALISIS` views are deliberately not used: `STRUKTUR_WILAYAH` (no page needs the region tree) and
`RINGKASAN_UMAT_PER_LINGKUNGAN` (household and people counts per community; leaving it out keeps the
parishioner data out of the dashboard entirely).

## 2. Design decisions

1. **One file.** A single `streamlit_app.py` can be pasted straight into the Snowsight Streamlit editor, which is the
   least fragile way for a first-time user. It is also what a Git-based deployment points at. The price is a long file,
   organised in labelled sections (data access, formatting, charts, one function per page).
2. **Only the `ANALISIS` views.** The app has exactly one query shape, `SELECT * FROM <database>.ANALISIS.<view>`, for a
   fixed list of 20 views (`VIEWS`). Filtering and charting happen in pandas, because the views are small (the largest has
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
* No export, no login, no per-user access rules. Who may open the app is controlled in Snowflake (see the starter guide, part 9).
* No write-back. The app only reads.
* No forecasting beyond the straight line, and no operating costs. See [USE_CASES.md](USE_CASES.md).

## 5. Limits of this version

* The dashboard was tested against a DuckDB stand-in and in a headless browser, not against Snowflake or inside Streamlit in
  Snowflake. Things that can differ in a real account: the Streamlit version and runtime, how `st.set_page_config` and `st.context`
  behave in the container, and the time the first query takes while the warehouse starts.
* Layout was reviewed on desktop-width screens (about 1,400 px). Phone widths were not reviewed.
* Charts are drawn by Vega-Lite through Altair, so very old Streamlit releases that predate Altair 4 are not supported.
