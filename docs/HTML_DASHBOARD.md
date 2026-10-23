# Offline HTML dashboard

A copy of the dashboard that needs **nothing**: no Snowflake, no Streamlit, no Python, no internet, no account. It is one file,
[`app/html/pusat_informasi_paroki.html`](../app/html/pusat_informasi_paroki.html) (about 1.3 MB). Double-click it, or copy it to a USB
stick, an email or a shared folder, and it opens in any recent browser (Chrome, Edge, Firefox, Safari), on a computer, tablet or phone.

It exists so that the demo can still be shown when the Snowflake trial has ended or its credit is used up.

## What it is, and what it is not

| | Streamlit dashboard | HTML dashboard |
|---|---|---|
| Where it runs | Inside Snowflake (Streamlit in Snowflake) | In the browser, from the file |
| Data | Read live from the 27 `ANALISIS` views | A snapshot, embedded in the file when it was built |
| Pages | 11 | The same 11, in the same order, with the same names |
| Charts | Altair (Vega-Lite) | The same Vega-Lite charts, drawn by the Vega libraries stored in the file |
| Dropdowns, radio buttons, tabs | Yes | Yes. A year range is two dropdowns ("Dari" and "Sampai") instead of a slider |
| Data tables | Yes | **No.** Only charts, tiles, short lists and the dropdowns that steer them |
| PDF service guides | Download button | Download button (the six PDFs are inside the file) |
| Dark mode | Follows the theme | Follows the system; the button "Tema" cycles automatic, light, dark |
| Refreshes itself | Yes, every 10 minutes | **No.** It shows the data of the moment it was built |

Three things to keep in mind:

* **It is a snapshot, not a connection.** It never contacts Snowflake and cannot show new data. To refresh it, rebuild it (below).
* **The data is simulated**, like everything else in this repository. Every page says so.
* **It was built from the DuckDB stand-in, not from Snowflake.** The views were run on a local database built from the same SQL files
  (see [SETUP_SNOWFLAKE.md](SETUP_SNOWFLAKE.md) and the verification status in the README). Nothing has been executed in Snowflake, so the
  numbers in this file are the numbers the SQL produces on DuckDB. If Snowflake gives different results for the same SQL, the Streamlit
  dashboard will show them and this file will not, until it is rebuilt from those results.

Left out on purpose: the tables, because the request was for charts and dropdowns; and the program-level budget list, the list of events and reports,
the per-session correlation figures and the yearly accuracy table, which exist on the Streamlit pages only as tables. Where a page would otherwise lose
information that is not a chart, a short list stands in for the table: the agenda on "Kegiatan mendatang", the nearest activities on "Ringkasan", the
forecast for the coming weeks, the requirements and steps of each service, and the event list under each forecast chart.

## Using it

1. Open the file. The menu on the left (above the page on a phone) lists the eleven pages.
2. Use the dropdowns, radio buttons and tabs on each page. A page keeps its choices while you stay on it and starts again from its defaults when you
   return to it.
3. Hover or tap a point or bar for its details.
4. The link in the address bar (`#Perkiraan%20kolekte`) opens that page directly, so a page can be bookmarked.

Nothing is stored except the theme choice (in the browser's local storage, if the browser allows it).

## Rebuilding it

The file is generated; do not edit it by hand. The sources are in `app/html/`:

```
app/html/
  template.html          Page skeleton with placeholders
  dashboard.css          Layout and light/dark colours
  js/00_core.js          Formatting (Indonesian conventions), data access, small helpers, controls
  js/10_charts.js        The Vega-Lite chart builders (ports of the Altair charts)
  js/20_pages_overview.js, 30_pages_offertory.js, 40_pages_other.js   The eleven pages
  js/90_main.js          Menu, routing, theme, drawing the charts
  vendor/                The Vega libraries and their licences (see vendor/README.md)
  pusat_informasi_paroki.html   The generated file
```

```bash
pip install duckdb                              # the local stand-in for Snowflake
python scripts/build_html_dashboard.py          # rewrites app/html/pusat_informasi_paroki.html
python scripts/build_html_dashboard.py --check  # exits 1 when the committed file is out of date
```

The build script reads the views that the JavaScript asks for (`V("NAME")`), takes only the columns the JavaScript uses, runs them on the DuckDB
stand-in, and writes the rows as JSON into the page. The output depends only on the files in the repository, so building twice gives the same bytes and
`--check` can be used in a test; it ignores float noise in the last digits of the embedded numbers, which another DuckDB release can cause, and nothing else. A test also fails when the JavaScript reads a view that the Streamlit dashboard does not.

**To make it from real Snowflake data**, replace `read_views` in `scripts/build_html_dashboard.py` with a function that runs
`SELECT * FROM PUSAT_INFORMASI_PAROKI.ANALISIS.<VIEW>` for each name with a connection that you provide yourself, and returns the same
`{"c": [columns], "r": [[values]]}` structure. This has not been done or tried: it needs a Snowflake connection and credentials, which must never be committed.

## Tests

`tests/test_html_dashboard.py` opens the file in headless Chromium directly from disk (`file://`, no server) and checks:

* the committed file is what the build script produces now, and nothing in it is loaded from the network (a request to any other address fails the test);
* all eleven pages draw all their charts, with no JavaScript error or console warning, and no horizontal scrolling on a 390 px wide phone screen;
* **every option of every dropdown and radio button, on every tab of every page**, draws without error (about 200 combinations), plus every survey with every question;
* each service shows its requirements and steps, and its PDF downloads and starts with `%PDF-`;
* the forecast chart names the event behind every grey week (`PRS-09`, `PRS-10`, ...);
* dark mode draws every chart, and the dates are identical in the Asia/Jakarta, Pacific/Kiritimati (UTC+14) and America/Los_Angeles time zones;
* the figures on the tiles (32 of them across six pages) are the same, character for character, as those of the Streamlit dashboard on the same data;
* every caption, warning, heading and bullet point that carries text or figures (about 140) is also on the Streamlit page, except a short list of sentences that exist only here on purpose;
* the number formatters (thousands dots, decimal commas, rounding of ties such as 0,125 and of values like 29,05) give the same text as the Python ones for about 13,000 values;
* every number that a chart draws is also a number in a chart (or, for the one chart that replaces a table, in a table) of the same Streamlit page, so a wrong sum, average or share in the JavaScript is caught. A deliberately broken division in a page function was detected this way.

These tests need `playwright` with a Chromium browser, and the comparison with Streamlit also needs the packages of `tests/requirements.txt`; they skip
themselves without them. They show that the file works and tells the same story as the Streamlit dashboard. They say nothing about Snowflake.

## Known limits

* Only checked in headless Chromium. Firefox, Safari and Edge use the same standards, but have not been tried.
* The charts are drawn as SVG by libraries stored in the file, so opening the file needs a browser that runs JavaScript. A screen reader sees the
  tiles and text, and the charts as graphics with tooltips.
* On a phone the menu sits above the page and the legends are stacked; the charts were checked for fit, not for comfortable use with a thumb.
* The tooltips of the charts follow the light or dark theme only through the library's two built-in looks.
