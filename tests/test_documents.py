"""Tests for the mock post-event report PDFs (data/documents/laporan_kegiatan).

The idea under test: the PDFs are the source documents, the rows of LAPORAN_KEGIATAN are what was
extracted from them. The round-trip tests therefore read the COMMITTED PDFs back (with the small reader
in mockdata/pdfdoc.py, standard library only) and compare every field with the database row.

Needs nothing beyond the standard library. One test also opens the files with pypdf when it is installed.
"""

import re
import subprocess
import sys
import unittest
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from mockdata import build, documents, pdfdoc, util  # noqa: E402

try:
    import pypdf
except ImportError:  # pragma: no cover
    pypdf = None

DATA = build.build_all()
REPORTS = {r["ID_LAPORAN"]: r for r in DATA["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]}
EVENTS = {e["ID_KEGIATAN"]: e for e in DATA["DATA_OPERASIONAL.KEGIATAN"]}
FOLDER = ROOT / documents.FOLDER
FILES = {path.name.split("_")[0]: path for path in sorted(FOLDER.glob("*.pdf"))}
MONTHS = {name: number for number, name in enumerate(util.MONTHS_ID, start=1)}
HEADING = re.compile(r"^[A-G]\. ")


def parse_date(text):
    day, month, year = text.split()
    return date(int(year), MONTHS[month], int(day))


def number(text):
    """'1.740.000' -> 1740000, 'Rp 1.740.000' -> 1740000, '29 orang' -> 29, '(belum diisi)' -> None."""
    if text == documents.EMPTY:
        return None
    return int(re.sub(r"[^\d]", "", text))


def extract(path):
    """Read the fields of a report PDF the way an extraction step would."""
    parsed = pdfdoc.read(path.read_bytes())
    sections, fields, order, prose = {}, {}, [], {}
    current = None
    last_label = None
    for page_number, page in enumerate(parsed["pages"]):
        for line in pdfdoc.lines(page):
            runs = [(round(x), text) for x, text in line]
            first_x, first_text = runs[0]
            run_meta = next(r for r in page["runs"] if r[4] == first_text and round(r[0]) == first_x)
            if run_meta[2] == "F2" and run_meta[3] == 11.0 and HEADING.match(first_text):
                current = first_text[0]
                sections[current] = []
                prose[current] = []
                order.append(current)
                last_label = None
                continue
            if first_text.startswith("Kota Contoh,"):
                current = None  # the signature block starts here; it is not part of any section
                continue
            if ":" in [t for _, t in runs]:
                # one or two "label : value" pairs on this line
                texts = [t for _, t in runs]
                index = 0
                while index < len(texts):
                    if texts[index] == ":":
                        last_label = texts[index - 1]
                        fields[last_label] = texts[index + 1]
                        index += 2
                    else:
                        index += 1
                continue
            if current is None:
                continue
            if last_label and runs[0][0] == documents.VALUE_X and len(runs) == 1 and current in "AC":
                fields[last_label] += " " + first_text  # a wrapped value continues on the next line
                continue
            sections[current].append([t for _, t in runs])
            if len(runs) == 1 and first_x == documents.LEFT:
                prose[current].append(first_text)  # body text starts at the left margin (notes and tables are indented)
    paragraphs = {key: " ".join(lines) for key, lines in prose.items()}
    return {"fields": fields, "sections": sections, "paragraphs": paragraphs, "parsed": parsed}


class FileSetTests(unittest.TestCase):
    def test_there_is_exactly_one_pdf_for_every_report_and_nothing_else(self):
        self.assertEqual(set(FILES), set(REPORTS))
        self.assertEqual(len(list(FOLDER.iterdir())), len(REPORTS), "only the PDFs live in the folder")

    def test_file_names_carry_the_report_number_event_and_date(self):
        for report_id, path in FILES.items():
            event = EVENTS[REPORTS[report_id]["ID_KEGIATAN"]]
            self.assertEqual(path.name, documents.file_name(REPORTS[report_id], event))
            self.assertRegex(path.name, r"^LPK-\d{4}_[A-Za-z0-9_]+_\d{4}-\d{2}-\d{2}\.pdf$")

    def test_every_report_row_names_its_own_file_and_the_file_exists(self):
        """The column NAMA_BERKAS_SUMBER is the link from a row to its document."""
        names = [row["NAMA_BERKAS_SUMBER"] for row in REPORTS.values()]
        self.assertEqual(len(set(names)), len(names), "one file per report")
        for report_id, row in REPORTS.items():
            self.assertEqual(row["NAMA_BERKAS_SUMBER"], FILES[report_id].name, report_id)
            self.assertTrue(row["NAMA_BERKAS_SUMBER"].startswith(report_id + "_"))
            self.assertNotIn("/", row["NAMA_BERKAS_SUMBER"], "the folder differs between a repository and a stage")
        self.assertEqual(set(names), {p.name for p in FOLDER.glob("*.pdf")})

    def test_the_column_is_declared_in_the_table_definition_with_a_unique_key(self):
        ddl = (ROOT / "sql" / "02_create_tables.sql").read_text(encoding="utf-8")
        self.assertIn("NAMA_BERKAS_SUMBER VARCHAR(200) COMMENT", ddl)
        self.assertIn("CONSTRAINT UQ_LAPORAN_KEGIATAN_BERKAS UNIQUE (NAMA_BERKAS_SUMBER)", ddl)
        loads = (ROOT / "sql" / "04e_load_plans_and_events.sql").read_text(encoding="utf-8")
        self.assertIn("NAMA_BERKAS_SUMBER", loads)
        self.assertIn(next(iter(FILES.values())).name, loads, "the load file carries the file names")

    def test_not_every_event_has_a_report_and_so_not_every_event_has_a_pdf(self):
        held = [e for e in EVENTS.values() if e["STATUS_KEGIATAN"] == "Terlaksana"]
        self.assertGreater(len(held), len(FILES))

    def test_files_are_well_formed_small_and_at_most_two_pages(self):
        for path in FILES.values():
            data = path.read_bytes()
            self.assertEqual(pdfdoc.verify_structure(data), [], path.name)
            self.assertLess(len(data), 40_000, path.name)
            self.assertIn(len(pdfdoc.read(data)["pages"]), (1, 2), path.name)

    def test_the_committed_files_are_what_the_generator_produces(self):
        generated = documents.build(DATA)
        self.assertEqual({Path(k).name for k in generated}, {p.name for p in FILES.values()})
        for relative, content in generated.items():
            self.assertEqual((ROOT / relative).read_bytes(), content, relative)

    def test_generation_does_not_depend_on_the_clock_or_on_earlier_runs(self):
        self.assertEqual(documents.build(DATA), documents.build(DATA))
        for report_id, path in FILES.items():
            info = pdfdoc.read(path.read_bytes())["info"]
            self.assertEqual(info["CreationDate"], f"D:{REPORTS[report_id]['TANGGAL_LAPORAN'].strftime('%Y%m%d')}090000+07'00'")


class RoundTripTests(unittest.TestCase):
    """What an extraction step can read out of each PDF equals the database row."""

    @classmethod
    def setUpClass(cls):
        cls.extracted = {report_id: extract(path) for report_id, path in FILES.items()}

    def test_identifiers_status_and_dates(self):
        for report_id, got in self.extracted.items():
            row, event = REPORTS[report_id], EVENTS[REPORTS[report_id]["ID_KEGIATAN"]]
            fields = got["fields"]
            self.assertEqual(fields["Nomor laporan"], row["ID_LAPORAN"])
            self.assertEqual(fields["Nomor kegiatan"], row["ID_KEGIATAN"])
            self.assertEqual(fields["Status laporan"], row["STATUS_LAPORAN"])
            self.assertEqual(parse_date(fields["Tanggal laporan"]), row["TANGGAL_LAPORAN"])
            self.assertEqual(fields["Nama kegiatan"], event["NAMA_KEGIATAN"])
            self.assertEqual(fields["Tempat"], event["LOKASI"])
            self.assertEqual(fields["Waktu pelaksanaan"], documents.period_text(event["TANGGAL_MULAI"], event["TANGGAL_SELESAI"]))
            self.assertEqual(number(fields["Target peserta"]), event["TARGET_PESERTA"])

    def test_participants_and_cost(self):
        for report_id, got in self.extracted.items():
            row = REPORTS[report_id]
            self.assertEqual(number(got["fields"]["Jumlah peserta"]), row["JUMLAH_PESERTA"], report_id)
            cost = got["fields"].get("Total realisasi biaya")
            if row["REALISASI_BIAYA"] is None:
                self.assertIsNone(cost, report_id)
                self.assertEqual(got["paragraphs"]["D"], documents.EMPTY, report_id)
            else:
                self.assertEqual(number(cost), row["REALISASI_BIAYA"], report_id)

    def test_the_four_narrative_sections_equal_the_text_columns_and_empty_markers_match_the_nulls(self):
        columns = {"B": "RINGKASAN_PELAKSANAAN", "E": "EVALUASI_LOGISTIK", "F": "HASIL_KEGIATAN", "G": "REKOMENDASI_TINDAK_LANJUT"}
        for report_id, got in self.extracted.items():
            for section, column in columns.items():
                text = got["paragraphs"][section]
                expected = REPORTS[report_id][column]
                self.assertEqual(None if text == documents.EMPTY else text, expected, f"{report_id} section {section}")

    def test_sections_appear_in_the_fixed_order(self):
        for report_id, got in self.extracted.items():
            self.assertEqual(list(got["sections"]), list("ABCDEFG"), report_id)

    def test_the_cost_table_adds_up_and_agrees_with_the_budget_and_the_reported_total(self):
        allocations = {}
        for allocation in DATA["DATA_OPERASIONAL.ALOKASI_ANGGARAN"]:
            allocations[allocation["ID_RENCANA"]] = allocations.get(allocation["ID_RENCANA"], 0) + allocation["JUMLAH_ANGGARAN"]
        checked = 0
        for report_id, got in self.extracted.items():
            row = REPORTS[report_id]
            event = EVENTS[row["ID_KEGIATAN"]]
            totals = [r for r in got["sections"]["D"] if r and r[0] == "Jumlah"]
            if not totals:
                continue  # empty section, or an event outside the annual plan
            budget, spent = number(totals[0][1]), number(totals[0][2])
            self.assertEqual(budget, allocations[event["ID_RENCANA"]], report_id)
            self.assertEqual(spent, row["REALISASI_BIAYA"], report_id)
            checked += 1
        self.assertGreater(checked, 100)

    def test_reports_outside_the_annual_plan_say_so_and_have_no_cost_table(self):
        unplanned = [r for r in REPORTS.values() if EVENTS[r["ID_KEGIATAN"]]["ID_RENCANA"] is None]
        self.assertGreaterEqual(len(unplanned), 1)
        for row in unplanned:
            got = self.extracted[row["ID_LAPORAN"]]
            self.assertEqual(got["fields"]["Rencana kerja"], documents.NO_PLAN)
            self.assertFalse([r for r in got["sections"]["D"] if r and r[0] == "Jumlah"])

    def test_achievement_against_target_is_computed_from_the_extracted_numbers(self):
        for report_id, got in self.extracted.items():
            count = number(got["fields"]["Jumlah peserta"])
            target = number(got["fields"]["Target peserta"])
            self.assertEqual(number(got["fields"]["Pencapaian terhadap target"]), round(100.0 * count / target), report_id)


class SituationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.parsed = {report_id: pdfdoc.read(path.read_bytes()) for report_id, path in FILES.items()}

    def by_status(self, status):
        return [rid for rid, row in REPORTS.items() if row["STATUS_LAPORAN"] == status]

    def test_the_mix_of_statuses_matches_the_data(self):
        self.assertGreaterEqual(len(self.by_status("Final")), 100)
        self.assertGreaterEqual(len(self.by_status("Draf")), 5)
        self.assertEqual(len(self.by_status("Perlu Revisi")), 1)

    def test_only_unfinished_reports_carry_a_watermark_and_a_note(self):
        expected = {"Draf": "DRAF", "Perlu Revisi": "PERLU REVISI"}
        for report_id, parsed in self.parsed.items():
            status = REPORTS[report_id]["STATUS_LAPORAN"]
            for page in parsed["pages"]:
                marks = [a for a in page["artifacts"] if a in ("DRAF", "PERLU REVISI")]
                self.assertEqual(marks, [expected[status]] if status in expected else [], report_id)
            text = " ".join(t for page in parsed["pages"] for *_, t in page["runs"])
            self.assertEqual("Catatan peninjau" in text, status != "Final", report_id)
            self.assertEqual("(belum ditandatangani)" in text, status != "Final", report_id)

    def test_final_reports_are_signed_with_a_drawn_signature(self):
        for report_id in self.by_status("Final"):
            data = FILES[report_id].read_bytes()
            self.assertEqual(data.count(b" c\n") + data.count(b" c "), 6, f"{report_id}: three curve segments per signature, two signatures")
        for report_id in self.by_status("Draf") + self.by_status("Perlu Revisi"):
            self.assertNotIn(b" c ", FILES[report_id].read_bytes(), report_id)

    def test_the_one_deliberate_inconsistency_is_visible_in_the_document_and_flagged_by_the_reviewer(self):
        (report_id,) = self.by_status("Perlu Revisi")
        got = extract(FILES[report_id])
        summary = re.search(r"dengan (\d+) peserta", got["paragraphs"]["B"])
        self.assertIsNotNone(summary)
        self.assertNotEqual(int(summary.group(1)), number(got["fields"]["Jumlah peserta"]))
        note = " ".join(t for page in self.parsed[report_id]["pages"] for *_, t in page["runs"])
        self.assertIn("berbeda dengan jumlah peserta kegiatan", note)

    def test_every_other_report_agrees_with_itself(self):
        for report_id in self.by_status("Final") + self.by_status("Draf"):
            got = extract(FILES[report_id])
            summary = re.search(r"dengan (\d+) peserta", got["paragraphs"]["B"])
            self.assertEqual(int(summary.group(1)), number(got["fields"]["Jumlah peserta"]), report_id)

    def test_drafts_leave_exactly_the_empty_sections_of_their_row_blank(self):
        for report_id in self.by_status("Draf"):
            row = REPORTS[report_id]
            empty = {key for key, column in (("D", "REALISASI_BIAYA"), ("E", "EVALUASI_LOGISTIK"), ("F", "HASIL_KEGIATAN"),
                                             ("G", "REKOMENDASI_TINDAK_LANJUT")) if row[column] is None}
            got = extract(FILES[report_id])
            blank = {key for key, text in got["paragraphs"].items() if text == documents.EMPTY}
            self.assertEqual(blank & set("DEFG"), empty, report_id)
        self.assertTrue(any(REPORTS[r][c] is None for r in self.by_status("Draf") for c in ("EVALUASI_LOGISTIK", "HASIL_KEGIATAN")))


class SafetyTests(unittest.TestCase):
    def test_every_page_says_it_is_a_simulated_document(self):
        for report_id, path in FILES.items():
            parsed = pdfdoc.read(path.read_bytes())
            self.assertIn("simulasi", parsed["info"]["Subject"].lower(), report_id)
            for page in parsed["pages"]:
                self.assertIn(documents.SIMULATION_NOTE, page["artifacts"], report_id)
            text = " ".join(t for page in parsed["pages"] for *_, t in page["runs"])
            self.assertIn("(alamat fiktif)", text)

    def test_no_contact_details_identity_numbers_or_real_looking_ids(self):
        for report_id, path in FILES.items():
            parsed = pdfdoc.read(path.read_bytes())
            text = " ".join(t for page in parsed["pages"] for *_, t in page["runs"])
            text += " " + " ".join(v for k, v in parsed["info"].items() if k != "CreationDate")
            self.assertNotIn("@", text, report_id)
            self.assertIsNone(re.search(r"(\+62|\b08\d{8,}|\b\d{12,}\b|www\.|https?://)", text), report_id)

    def test_officers_are_fictional_and_stable(self):
        first, second = documents.officers(), documents.officers()
        self.assertEqual(first, second)
        self.assertEqual(len(first), 9)
        for chair, secretary in first.values():
            self.assertNotEqual(chair, secretary)
            self.assertGreaterEqual(len(chair.split()), 3)

    def test_wrapping_never_exceeds_the_line_width(self):
        text = "Peserta mengikuti latihan teknik membaca, pernapasan, dan melagukan mazmur, lalu menyelesaikan sesi praktik " * 3
        for line in pdfdoc.wrap(text, "F1", 9.5, 400):
            self.assertLessEqual(pdfdoc.text_width(line, "F1", 9.5), 400)
        self.assertEqual(" ".join(pdfdoc.wrap(text, "F1", 9.5, 400)), " ".join(text.split()))
        very_long = "x" * 200
        for line in pdfdoc.wrap(very_long, "F1", 9.5, 100):
            self.assertLessEqual(pdfdoc.text_width(line, "F1", 9.5), 100)

    def test_special_characters_survive_in_pdf_strings(self):
        pdf = pdfdoc.Pdf("T", "A", "S", date(2026, 1, 1))
        pdf.new_page().text(10, 50, r"a (b) \ c", "F1", 10)
        parsed = pdfdoc.read(pdf.render())
        self.assertEqual(parsed["pages"][0]["runs"][0][4], r"a (b) \ c")


@unittest.skipUnless(pypdf, "pypdf is not installed (pip install pypdf) - optional check with an independent PDF reader")
class IndependentReaderTests(unittest.TestCase):
    def test_pypdf_opens_every_file_and_finds_the_key_values(self):
        for report_id, path in FILES.items():
            reader = pypdf.PdfReader(str(path))
            text = " ".join((page.extract_text() or "") for page in reader.pages)
            row = REPORTS[report_id]
            self.assertIn(report_id, text)
            self.assertIn(row["STATUS_LAPORAN"], text)
            if row["REALISASI_BIAYA"] is not None:
                self.assertIn(documents.rupiah(row["REALISASI_BIAYA"]), text, report_id)
            self.assertEqual(len(reader.pages), len(pdfdoc.read(path.read_bytes())["pages"]))
            self.assertEqual(reader.metadata.title.split(":")[0], f"Laporan Pelaksanaan Kegiatan {report_id}")


class DocumentationTests(unittest.TestCase):
    def test_the_guide_states_the_real_numbers(self):
        text = (ROOT / "docs" / "DOCUMENTS.md").read_text(encoding="utf-8")
        statuses = {s: sum(1 for r in REPORTS.values() if r["STATUS_LAPORAN"] == s) for s in ("Final", "Draf", "Perlu Revisi")}
        pages = [len(pdfdoc.read(p.read_bytes())["pages"]) for p in FILES.values()]
        self.assertIn(f"**{len(FILES)} PDFs**", text)
        self.assertIn(f"{statuses['Final']} *Final*, {statuses['Draf']} *Draf*, {statuses['Perlu Revisi']} *Perlu Revisi*", text)
        self.assertIn(f"{pages.count(1)} are one page long, {pages.count(2)} are two", text)
        total_kb = sum(p.stat().st_size for p in FILES.values()) / 1024
        self.assertIn("about 1 MB", text)
        self.assertTrue(0.7 < total_kb / 1024 < 1.5)
        (revision,) = [r for r in REPORTS if REPORTS[r]["STATUS_LAPORAN"] == "Perlu Revisi"]
        self.assertIn(f"`{revision}`", text)

    def test_the_readmes_mention_the_documents_and_the_folder_is_marked_binary(self):
        self.assertIn("132", (ROOT / "README.md").read_text(encoding="utf-8").split("Mock source documents")[1][:60])
        self.assertIn(f"{len(FILES)} mock PDF", (ROOT / "data" / "README.md").read_text(encoding="utf-8"))
        attributes = (ROOT / ".gitattributes").read_text(encoding="utf-8")
        self.assertRegex(attributes, r"(?m)^\*\.pdf\s+binary")


class GeneratorCheckTests(unittest.TestCase):
    def test_check_passes_and_flags_a_stray_pdf(self):
        script = str(ROOT / "scripts" / "generate_mock_data.py")
        clean = subprocess.run([sys.executable, script, "--check"], capture_output=True, text=True)
        self.assertEqual(clean.returncode, 0, clean.stdout + clean.stderr)
        self.assertIn("132 report PDFs", clean.stdout)
        stray = FOLDER / "ZZZ_stray_report.pdf"
        try:
            stray.write_bytes(b"%PDF-1.4\n%%EOF\n")
            flagged = subprocess.run([sys.executable, script, "--check"], capture_output=True, text=True)
            self.assertEqual(flagged.returncode, 1)
            self.assertIn("ZZZ_stray_report.pdf", flagged.stdout)
        finally:
            stray.unlink(missing_ok=True)

    def test_a_changed_pdf_is_detected(self):
        script = str(ROOT / "scripts" / "generate_mock_data.py")
        path = next(iter(FILES.values()))
        original = path.read_bytes()
        try:
            path.write_bytes(original.replace(b"Laporan", b"Lapuran", 1))
            result = subprocess.run([sys.executable, script, "--check"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn(path.name, result.stdout)
        finally:
            path.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
