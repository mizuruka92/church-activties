#!/usr/bin/env python3
"""Generate the synthetic Parish Information Hub dataset and every derived file.

    python scripts/generate_mock_data.py              write the generated files (SQL, dictionary, report PDFs)
    python scripts/generate_mock_data.py --check      fail if any committed generated file is stale
    python scripts/generate_mock_data.py --csv-dir data/generated   also export CSV files

The script needs only the Python standard library. It never connects to Snowflake
and never reads credentials. All output is fictional and reproducible: the random
seed and the snapshot date are fixed in scripts/mockdata/config.py.
"""

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from mockdata import documents, sqlwriter  # noqa: E402
from mockdata.outputs import generate, render_documents  # noqa: E402


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="do not write, exit 1 when a committed file differs")
    parser.add_argument("--csv-dir", help="also write one CSV file per table into this directory (optional)")
    args = parser.parse_args(argv)

    files, data, tables = generate(ROOT)
    pdfs = render_documents(data)
    pdf_folder = ROOT / documents.FOLDER
    extra = sorted(str(path.relative_to(ROOT)).replace("\\", "/") for path in pdf_folder.glob("*.pdf")
                   if str(path.relative_to(ROOT)).replace("\\", "/") not in pdfs) if pdf_folder.exists() else []

    if args.check:
        stale = []
        for relative, text in files.items():
            path = ROOT / relative
            current = path.read_bytes().decode("utf-8") if path.exists() else None
            if current != text:
                stale.append(relative)
        for relative, content in pdfs.items():
            path = ROOT / relative
            if not path.exists() or path.read_bytes() != content:
                stale.append(relative)
        stale += [f"{relative} (no longer generated, remove it)" for relative in extra]
        if stale:
            print("Out of date (run: python scripts/generate_mock_data.py):")
            for relative in stale:
                print(f"  {relative}")
            return 1
        print(f"OK: {len(files)} generated files and {len(pdfs)} report PDFs are up to date.")
        return 0

    for relative, text in files.items():
        path = ROOT / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        print(f"wrote {relative}")

    pdf_folder.mkdir(parents=True, exist_ok=True)
    for relative, content in pdfs.items():
        (ROOT / relative).write_bytes(content)
    for relative in extra:
        (ROOT / relative).unlink()
    print(f"wrote {len(pdfs)} report PDFs to {documents.FOLDER}" + (f" and removed {len(extra)} stale ones" if extra else ""))

    if args.csv_dir:
        target = Path(args.csv_dir)
        target.mkdir(parents=True, exist_ok=True)
        for table in tables:
            with open(target / f"{table.schema}.{table.name}.csv", "w", encoding="utf-8", newline="\n") as handle:
                handle.write(sqlwriter.csv_text(table, data[table.qualified]))
        print(f"wrote {len(tables)} CSV files to {target}")

    total = sum(len(rows) for rows in data.values())
    print(f"{len(tables)} tables, {total} rows")
    return 0


if __name__ == "__main__":
    sys.exit(main())
