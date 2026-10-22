# Mock source documents: post-event report PDFs

For every row of `DATA_OPERASIONAL.LAPORAN_KEGIATAN` there is a PDF in
[`data/documents/laporan_kegiatan/`](../data/documents/laporan_kegiatan/). The story they tell: a parish section
writes its post-event report as a document, and the table row is what was **extracted** from that document. Every
value in a row can be found in its PDF, and a PDF never contradicts its row.

> **All of it is fictional.** The parish ("Paroki Santa Maria Contoh"), its address (marked "alamat fiktif"), the section officers
> who sign, and every figure are generated. Every page carries the footer *"Dokumen simulasi (fiktif), bukan dokumen paroki yang
> sebenarnya"*. Do not put real reports in that folder.

## What is in the folder

* **132 PDFs**, one per report row (123 *Final*, 8 *Draf*, 1 *Perlu Revisi*), about 1 MB in total. 116 are one page long, 16 are two
  pages (the large Easter and Christmas reports and the unsigned ones with a reviewer's note).
* File names are `<ID_LAPORAN>_<event name>_<start date>.pdf`, for example `LPK-0001_Pelatihan_Lektor_dan_Pemazmur_2021-02-14.pdf`.
  The part before the first underscore is the key that joins a file to its row. There is no index file and no column pointing at the
  file; the name is the link.
* Events without a report have no PDF, exactly as in the table (the data deliberately has completed events without a report).
* The PDFs are text PDFs, not scans, so any extraction tool can read them without OCR. They use the two standard Helvetica fonts, are not
  compressed, and carry a fixed creation date equal to the report date, so the files are byte-identical every time they are generated.

## What a report looks like

One template for all sections: a letterhead with the parish name, a title, then

| Part of the PDF | Column of `LAPORAN_KEGIATAN` it was "extracted" into | Notes |
|---|---|---|
| Nomor laporan | `ID_LAPORAN` | |
| Nomor kegiatan | `ID_KEGIATAN` | |
| Status laporan | `STATUS_LAPORAN` | *Final*, *Draf* or *Perlu Revisi* |
| Tanggal laporan | `TANGGAL_LAPORAN` | long Indonesian date, for example "26 Februari 2021" |
| B. Ringkasan pelaksanaan | `RINGKASAN_PELAKSANAAN` | |
| C. Jumlah peserta | `JUMLAH_PESERTA` | "29 orang" |
| D. Total realisasi biaya | `REALISASI_BIAYA` | "Rp 1.740.000", written with dots as thousands separators |
| E. Evaluasi logistik | `EVALUASI_LOGISTIK` | |
| F. Hasil kegiatan | `HASIL_KEGIATAN` | |
| G. Rekomendasi tindak lanjut | `REKOMENDASI_TINDAK_LANJUT` | |

A field that is empty in the table is written as **"(belum diisi)"** in the PDF, so a missing value is visible in the document and not
just absent.

The PDF also carries things that are **not** stored in the report table, which is what makes it a document and not a printout of a row:

* the letterhead, the event's name, section, place and dates, and the plan's purpose (section A), copied from the plan and the event;
* a **cost table** by category (section D) with the planned budget and the recorded spending per category, from the budget and
  expenditure tables. Its totals equal the reported total. Reports for events outside the annual plan say so and have no table;
* the target and the achievement against it (section C);
* the section's chair and secretary, as fictional names, and, for *Final* reports, a hand-drawn looking signature;
* for unfinished reports, a diagonal watermark (*DRAF* or *PERLU REVISI*) and a boxed note from the parish secretariat.

## Deliberate situations

They mirror the situations the data was built to contain.

| Situation | In the PDF |
|---|---|
| Final report | Complete, signed, no watermark |
| Draft with missing parts | Watermark *DRAF*, unsigned, empty sections shown as "(belum diisi)", note "masih berstatus draf" |
| The report under revision (`LPK-0130`) | Section C says 34 participants while its own summary (section B) says 30; a reviewer's note points out the difference. This is the one deliberate inconsistency of the dataset |
| Events without a report | No PDF |

## Extraction round trip

`tests/test_documents.py` reads the committed PDFs back with a small reader that needs only the standard library
(`mockdata/pdfdoc.py`) and checks, for all 132 files, that the identifiers, status, dates, event name, place, target, participants, cost, the
four narrative sections and the empty markers equal the database rows, that each cost table adds up to the reported total and to the plan's
budget, that watermarks, notes and signatures appear exactly for the statuses that should have them, and that no file carries a contact
detail or an identity number. If `pypdf` is installed, the same files are also opened with that independent reader.

You can try the same on any file with a command-line tool such as `pdftotext -layout <file>`.

## Using the files with Snowflake later

Nothing about these PDFs is part of the Snowflake setup: no SQL file mentions them and nothing was loaded or run in Snowflake. They exist so
that a later step can show how documents become rows. In outline:

1. Upload the PDFs to an internal stage (for example with the Snowsight file upload or `PUT`).
2. Run a document-extraction feature on them (Snowflake offers several, such as Cortex functions and Document AI; names, availability and syntax
   change between releases, so check the current documentation) and compare the result with `LAPORAN_KEGIATAN`, which acts as the answer key.
3. Join on the report number taken from the file name.

Things a real extraction will meet in these files, on purpose or by nature: the report number, status, and date sit in two columns on the same line;
unfinished reports have a watermark whose letters can appear in the extracted text; values are written in Indonesian formats ("Rp 1.740.000",
"26 Februari 2021") and need converting; empty sections contain the marker "(belum diisi)".

## How the files are made

* `scripts/mockdata/documents.py` builds one document per report from the same in-memory rows that produce the SQL, so the PDFs and the table
  cannot drift apart. `scripts/mockdata/pdfdoc.py` is a small PDF writer (text, lines, boxes and one curve) with Helvetica metrics for wrapping.
  Neither uses anything outside the standard library.
* `python scripts/generate_mock_data.py` writes them together with the SQL, and **removes PDFs that are no longer generated**.
  `python scripts/generate_mock_data.py --check` fails when any PDF differs, is missing, or is left over.
* The folder is marked binary in `.gitattributes`, so Git never converts line endings inside the PDFs.

## Limits

* One template, one font, one language. Real reports vary much more and arrive as photographs, scans and word-processor files.
* The texts are short and partly templated, because the table's text columns are.
* The signatures are generic curves, not images, and the stamps and attachments of real reports (attendance lists, receipts, photographs) are
  not modelled.
* The reviewer's note and the cost breakdown exist only in the documents. If you want them in the model, the cost breakdown is already derivable
  from `ALOKASI_ANGGARAN` and `REALISASI_PENGELUARAN`.
