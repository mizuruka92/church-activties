# Mock documents: post-event report PDFs and public service guides

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
* **Each row names its file.** The column `LAPORAN_KEGIATAN.NAMA_BERKAS_SUMBER` holds the file name, without a folder (the folder
  differs between a repository and a stage). It is unique, always starts with the report number, and ends in `.pdf`. The part before the
  first underscore is the same report number, so a file can also be matched to its row from the name alone. The view
  `ANALISIS.KEGIATAN_DAN_LAPORAN` shows the name as `NAMA_BERKAS_LAPORAN`, and the dashboard's event list as "Berkas laporan".
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
| (the file itself) | `NAMA_BERKAS_SUMBER` | the file name, for example `LPK-0001_Pelatihan_Lektor_dan_Pemazmur_2021-02-14.pdf` |
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
budget, that every row's `NAMA_BERKAS_SUMBER` is the name of an existing file (and every file is named by exactly one row), that
watermarks, notes and signatures appear exactly for the statuses that should have them, and that no file carries a contact detail or an
identity number. The validation script (`sql/06_validate_data.sql`) checks the column itself: the name starts with the report number, is a
PDF, names no folder, and is not used twice. If `pypdf` is installed, the same files are also opened with that independent reader.

You can try the same on any file with a command-line tool such as `pdftotext -layout <file>`.

## Using the files with Snowflake later

The normal setup does not use these PDFs. The optional step 7 ([`sql/07_dokumen_pdf.sql`](../sql/07_dokumen_pdf.sql), described in the
[starter guide, part 8b](STARTER_GUIDE.md#8b-optional-open-the-pdf-files-from-the-dashboard)) creates the stage `ANALISIS.DOKUMEN_PAROKI` and a view with a pre-signed link
per file; with it, the dashboard opens the reports and guides from the stage (by the project owner's report this worked in a real Snowflake account). The PDFs also exist so that a later step can show how documents become rows. In outline:

1. Upload the PDFs to an internal stage (for example with the Snowsight file upload or `PUT`). Step 7 creates the stage `ANALISIS.DOKUMEN_PAROKI` for this.
2. Run a document-extraction feature on them (Snowflake offers several, such as Cortex functions and Document AI; names, availability and syntax
   change between releases, so check the current documentation) and compare the result with `LAPORAN_KEGIATAN`, which acts as the answer key.
3. Join on `NAMA_BERKAS_SUMBER` (or on the report number at the start of the file name). Only the file name is stored; on a stage the same
   name sits under the stage's own path.

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

## Public service guides (`app/public_documents/`)

A second set of PDFs has the opposite direction. The post-event reports are *source* documents from which table rows were extracted. The service guides are
*published* documents generated **from** table rows: `MASTER_DATA.LAYANAN_PAROKI`, `LANGKAH_LAYANAN` and `PERSYARATAN_LAYANAN`. They are public information, so they live next to
the dashboard in `app/public_documents/`, which is where the page **Layanan dan prosedur** offers them for download.

* **6 PDFs**, one per service, one to two pages each, named `<ID_LAYANAN>_<name>.pdf` (for example `LYN-04_Pernikahan.pdf`). Each service row names its file in `NAMA_BERKAS_PANDUAN`
  (the name only, never a folder, starting with the service id and ending in `.pdf`).
* The services are *Baptis Dewasa*, *Baptis Batuta (bayi dan anak di bawah 7 tahun)*, *Krisma*, *Pernikahan*, *Pendaftaran Lingkungan* and *Pelayanan Kematian (Tutup Usia)*.
* Layout: letterhead of the fictional parish, a boxed notice that the guide is an example, then **A. Untuk siapa**, **B. Persyaratan** (a checklist with a box for each item, marked *Wajib* or
  *Jika berlaku*), **C. Langkah-langkah** (numbered, with who does each step) and **D. Catatan penting**. Same fonts, footer and fixed creation date (the revision date) as the reports, so the files are byte-identical on every run.
* **Fictional and generic.** The steps and requirements are plausible examples, not the rules of any diocese or parish, and every guide says so. There is no telephone number, e-mail or
  other contact detail, and no personal data. "Baptis Batuta" is read as the baptism of babies and children under seven.
* `tests/test_layanan.py` reads every committed PDF back and finds each service's summary, notes, requirements and steps in the document, in the same order as the tables, with the
  right *Wajib* or *Jika berlaku* mark and the right actor; checks the footer on every page, that text never leaves the margin, and that no PDF holds a long number, e-mail or web address.
  `python scripts/generate_mock_data.py --check` also fails when a guide differs, is missing or is left over.
* The PDFs are not loaded into Snowflake by the normal setup. The dashboard page renders the same content from the three public views, so it works even where the PDF files are not available. With the optional step 7 the page also offers a link that opens the guide from the stage.
* **In the offline HTML dashboard** all 138 PDFs (132 reports and 6 guides) are inside the file, so "Buka laporan (PDF)" and "Buka panduan (PDF)" open them in the browser's own PDF viewer without any folder or internet ([HTML_DASHBOARD.md](HTML_DASHBOARD.md)).

## Limits

* One template, one font, one language. Real reports vary much more and arrive as photographs, scans and word-processor files.
* The texts are short and partly templated, because the table's text columns are.
* The signatures are generic curves, not images, and the stamps and attachments of real reports (attendance lists, receipts, photographs) are
  not modelled.
* The reviewer's note and the cost breakdown exist only in the documents. If you want them in the model, the cost breakdown is already derivable
  from `ALOKASI_ANGGARAN` and `REALISASI_PENGELUARAN`.
* The database cannot check that a named file exists. SQL has no access to the repository folder, so that check is a Python test
  (`tests/test_documents.py`). In Snowflake, once the PDFs are on a stage, a directory table could be compared with the column.
