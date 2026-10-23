#!/usr/bin/env python3
"""Build the standalone HTML dashboard: one file that opens by double-click, with no installation and no network.

It reads the same ANALISIS views as the Streamlit dashboard (the VIEWS tuple of app/streamlit_app.py), but only the
ones the charts need, materialises them with the local DuckDB stand-in used by the tests (NOT Snowflake), and embeds the
rows as JSON next to the vendored Vega libraries and the dashboard code (app/html/js, dashboard.css, template.html).

    python scripts/build_html_dashboard.py            # write app/html/pusat_informasi_paroki.html
    python scripts/build_html_dashboard.py --check    # exit 1 when the committed file is out of date

The output depends only on the repository files, so the same inputs always give the same bytes.
"""

import argparse
import ast
import base64
import datetime
import decimal
import json
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HTML = ROOT / "app" / "html"
OUTPUT = HTML / "pusat_informasi_paroki.html"
GUIDE_FOLDER = ROOT / "app" / "public_documents"
VENDOR = (("VEGA", "vega.min.js"), ("VEGA_LITE", "vega-lite.min.js"), ("VEGA_EMBED", "vega-embed.min.js"))
# Mass rows that the pages need: the scheduled ones (upcoming list) and the first and last held Mass (the "Tentang data" dates).
# The other thousands of held Masses are not drawn individually, so they stay out of the file.
TRIMMED_VIEW = "PELAKSANAAN_MISA"


def dashboard_views():
    """The VIEWS tuple of the Streamlit app, read without importing Streamlit."""
    tree = ast.parse((ROOT / "app" / "streamlit_app.py").read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(getattr(t, "id", "") == "VIEWS" for t in node.targets):
            return tuple(ast.literal_eval(node.value))
    raise SystemExit("VIEWS was not found in app/streamlit_app.py")


def script_sources():
    return [(path.name, path.read_text(encoding="utf-8")) for path in sorted((HTML / "js").glob("*.js"))]


def needed_views(source, available):
    """Views the JavaScript asks for with V("NAME"). Each must be one the Streamlit dashboard reads."""
    asked = sorted(set(re.findall(r'\bV\("([A-Z_]+)"\)', source)))
    unknown = [name for name in asked if name not in available]
    if unknown:
        raise SystemExit(f"The JavaScript reads views that the Streamlit dashboard does not: {unknown}")
    return asked


def plain(value):
    """A JSON-friendly value. Money and counts arrive as Decimal; dates and times become text that the page parses."""
    if value is None or isinstance(value, (bool, str)):
        return value
    if isinstance(value, decimal.Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    if isinstance(value, float):
        return None if value != value or value in (float("inf"), float("-inf")) else value
    if isinstance(value, int):
        return value
    if isinstance(value, datetime.datetime):
        return value.isoformat(sep=" ")
    if isinstance(value, datetime.date):
        return value.isoformat()
    if isinstance(value, datetime.time):
        return value.strftime("%H:%M")
    return str(value)


def read_views(names, js_source):
    sys.path.insert(0, str(ROOT / "tests"))
    import duckdb_shim as shim  # local stand-in for Snowflake; imported late so --help works without DuckDB

    connection = shim.build_database(keep_constraints=False)
    words = set(re.findall(r"[A-Z][A-Z0-9_]{2,}", js_source))
    data = {}
    for name in names:
        cursor = connection.execute(f"SELECT * FROM ANALISIS.{name}")
        columns = [d[0] for d in cursor.description]
        keep = [i for i, c in enumerate(columns) if c in words]  # only columns that the JavaScript mentions
        rows = [[plain(row[i]) for i in keep] for row in cursor.fetchall()]
        # Views without ORDER BY come back in a run-dependent order; a total order keeps the file identical on every build.
        # The pages sort what they show, so none of them relies on the order of the rows.
        rows.sort(key=lambda row: json.dumps(row))
        if name == TRIMMED_VIEW:
            rows = trim_masses([columns[i] for i in keep], rows)
        data[name] = {"c": [columns[i] for i in keep], "r": rows}
    return data


def trim_masses(columns, rows):
    status, day = columns.index("STATUS_PELAKSANAAN"), columns.index("TANGGAL_MISA")
    held = sorted((r for r in rows if r[status] == "Terlaksana"), key=lambda r: r[day])
    scheduled = [r for r in rows if r[status] == "Terjadwal"]
    return scheduled + ([held[0], held[-1]] if held else [])


def guide_files(data):
    table = data["LAYANAN_PUBLIK"]
    index = table["c"].index("NAMA_BERKAS_PANDUAN")
    guides = {}
    for row in table["r"]:
        name = row[index]
        path = GUIDE_FOLDER / name
        if name and path.is_file() and path.name == name and name.lower().endswith(".pdf"):
            guides[name] = base64.b64encode(path.read_bytes()).decode("ascii")
    return guides


def as_script_json(value):
    text = json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
    return text.replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")


def build():
    scripts = script_sources()
    app_js = "\n".join(f"/* {name} */\n{text}" for name, text in scripts)
    names = needed_views(app_js, dashboard_views())
    data = read_views(names, app_js)
    guides = guide_files(data)

    parts = {
        "CSS": (HTML / "dashboard.css").read_text(encoding="utf-8"),
        "DATA": "var DATA = " + as_script_json(data) + ";\nvar GUIDES = " + as_script_json(guides) + ";",
        "APP": app_js,
    }
    for key, file_name in VENDOR:
        library = (HTML / "vendor" / file_name).read_text(encoding="utf-8")
        parts[key] = re.sub(r"\n?//# sourceMappingURL=\S+\s*$", "", library)  # no browser should look for a source map

    page = (HTML / "template.html").read_text(encoding="utf-8")
    for key, content in parts.items():
        marker = f"/*@@{key}@@*/"
        if page.count(marker) != 1:
            raise SystemExit(f"template.html must contain {marker} exactly once")
        if key != "CSS" and (re.search(r"</script", content, re.I) or "<!--" in content):
            raise SystemExit(f"{key} contains text that would end or confuse the inline <script> element")
        page = page.replace(marker, content.rstrip("\n"))
    return page


DATA_BLOCK = re.compile(r"var DATA = (.*?);\nvar GUIDES = (.*?);\n", re.S)


def close_enough(a, b):
    """Same structure and text, numbers equal up to the float noise that another DuckDB release may introduce."""
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
        return math.isclose(a, b, rel_tol=1e-9, abs_tol=1e-9)
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(close_enough(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(close_enough(x, y) for x, y in zip(a, b))
    return a == b


def up_to_date(current, fresh):
    """True when the committed page is the page the build makes now. The code, styles and libraries must be identical; the embedded
    data may differ in the last digits of a float, which a different DuckDB release can cause."""
    if current == fresh:
        return True
    old, new = DATA_BLOCK.search(current), DATA_BLOCK.search(fresh)
    if not old or not new or current[:old.start()] != fresh[:new.start()] or current[old.end():] != fresh[new.end():]:
        return False
    return all(close_enough(json.loads(old.group(i)), json.loads(new.group(i))) for i in (1, 2))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="do not write; exit 1 when the committed file differs from a fresh build")
    arguments = parser.parse_args()
    page = build()
    if arguments.check:
        current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else None
        if current is None or not up_to_date(current, page):
            print(f"{OUTPUT.relative_to(ROOT)} is out of date. Run: python scripts/build_html_dashboard.py")
            return 1
        print(f"{OUTPUT.relative_to(ROOT)} is up to date.")
        return 0
    OUTPUT.write_text(page, encoding="utf-8")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({len(page.encode('utf-8')) / 1024:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
