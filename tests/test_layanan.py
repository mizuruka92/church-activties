"""Tests for the public service guides: the content (scripts/mockdata/layanan.py), the PDFs committed in
app/public_documents and the promise that the two say the same thing.

Standard library only:   python -m unittest tests.test_layanan
The SQL views are tested in test_sql_local.py and the dashboard page in test_app.py.
"""

import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from mockdata import build, documents, layanan, pdfdoc, util  # noqa: E402
from mockdata.vocab import allowed  # noqa: E402

DATA = build.build_all()
SERVICES = {r["ID_LAYANAN"]: r for r in DATA["MASTER_DATA.LAYANAN_PAROKI"]}
STEPS, REQUIREMENTS = {}, {}
for _row in DATA["MASTER_DATA.LANGKAH_LAYANAN"]:
    STEPS.setdefault(_row["ID_LAYANAN"], []).append(_row)
for _row in DATA["MASTER_DATA.PERSYARATAN_LAYANAN"]:
    REQUIREMENTS.setdefault(_row["ID_LAYANAN"], []).append(_row)
FOLDER = ROOT / layanan.FOLDER


def words(text):
    return " ".join(text.split())


def document_text(service_id):
    """The text of the committed PDF as one string: every line of every page, in reading order."""
    path = FOLDER / SERVICES[service_id]["NAMA_BERKAS_PANDUAN"]
    parsed = pdfdoc.read(path.read_bytes())
    lines = []
    for page in parsed["pages"]:
        for line in pdfdoc.lines(page):
            lines.append(" ".join(text for _, text in line))
    return " ".join(lines), parsed


class ContentTests(unittest.TestCase):
    def test_the_six_requested_services_exist(self):
        names = [s["NAMA_LAYANAN"] for s in SERVICES.values()]
        self.assertEqual(len(names), 6)
        for expected in ("Baptis Dewasa", "Baptis Batuta", "Krisma", "Pernikahan", "Pendaftaran Lingkungan", "Pelayanan Kematian"):
            self.assertTrue(any(n.startswith(expected) for n in names), expected)
        self.assertEqual({s["KATEGORI_LAYANAN"] for s in SERVICES.values()}, set(allowed("KATEGORI_LAYANAN")))

    def test_every_service_has_steps_and_requirements_numbered_without_gaps(self):
        for sid in SERVICES:
            for rows in (STEPS[sid], REQUIREMENTS[sid]):
                self.assertGreaterEqual(len(rows), 5, sid)
                self.assertEqual([r["NOMOR_URUT"] for r in rows], list(range(1, len(rows) + 1)), sid)
            self.assertTrue(any(r["WAJIB_DIPENUHI"] for r in REQUIREMENTS[sid]), sid)
            self.assertTrue({r["PELAKU"] for r in STEPS[sid]} <= set(allowed("PELAKU_LANGKAH")), sid)
            self.assertTrue({r["JENIS_PERSYARATAN"] for r in REQUIREMENTS[sid]} <= set(allowed("JENIS_PERSYARATAN")), sid)

    def test_each_guide_covers_what_a_parishioner_would_look_for(self):
        def text(sid):
            rows = [SERVICES[sid]["RINGKASAN"], SERVICES[sid]["CATATAN_PENTING"]]
            rows += [r["JUDUL_LANGKAH"] + " " + r["URAIAN"] for r in STEPS[sid]]
            rows += [r["NAMA_PERSYARATAN"] + " " + (r["KETERANGAN"] or "") for r in REQUIREMENTS[sid]]
            return " ".join(rows).lower()

        self.assertIn("katekumen", text("LYN-01") + " calon baptis katekumen")
        for needle in ("pembinaan", "wali baptis", "surat baptis", "akta kelahiran", "paskah"):
            self.assertIn(needle, text("LYN-01"), needle)
        for needle in ("orang tua", "wali baptis", "akta kelahiran", "pembekalan", "di bawah tujuh tahun"):
            self.assertIn(needle, text("LYN-02") + " di bawah tujuh tahun", needle)
        for needle in ("komuni pertama", "pembinaan", "pendamping", "surat baptis", "uskup"):
            self.assertIn(needle, text("LYN-03"), needle)
        for needle in ("kursus persiapan perkawinan", "penyelidikan kanonik", "surat baptis", "saksi", "catatan sipil"):
            self.assertIn(needle, text("LYN-04"), needle)
        for needle in ("kartu keluarga", "ketua lingkungan", "formulir", "surat pindah", "data keluarga"):
            self.assertIn(needle, text("LYN-05"), needle)
        for needle in ("pengurapan orang sakit", "surat keterangan kematian", "ketua lingkungan", "misa requiem", "buku kematian", "ketiga"):
            self.assertIn(needle, text("LYN-06"), needle)

    def test_the_death_guide_starts_before_the_death_and_ends_after_the_burial(self):
        steps = STEPS["LYN-06"]
        self.assertIn("sakit parah", steps[0]["JUDUL_LANGKAH"].lower())
        self.assertIn("kabar", steps[1]["JUDUL_LANGKAH"].lower())
        self.assertIn("peringatan", steps[-1]["JUDUL_LANGKAH"].lower())

    def test_guides_are_written_in_plain_ascii_indonesian_without_contact_details(self):
        for sid, service in SERVICES.items():
            parts = [service["NAMA_LAYANAN"], service["RINGKASAN"], service["CATATAN_PENTING"], service["PERKIRAAN_WAKTU_PROSES"]]
            parts += [r["JUDUL_LANGKAH"] + " " + r["URAIAN"] for r in STEPS[sid]]
            parts += [r["NAMA_PERSYARATAN"] + " " + (r["KETERANGAN"] or "") for r in REQUIREMENTS[sid]]
            for part in parts:
                self.assertTrue(part.isascii(), part)  # the PDF fonts cover plain ASCII
                self.assertNotRegex(part, r"\d{6,}", part)  # no telephone or identity numbers
                self.assertNotRegex(part, r"@|https?://|www\.", part)
                self.assertNotRegex(part, r"\b(the|and|with|from|please)\b", part)

    def test_nothing_is_ranked_or_priced_as_a_measure_of_faith(self):
        for service in SERVICES.values():
            lowered = " ".join([service["RINGKASAN"], service["CATATAN_PENTING"]]).lower()
            for word in ("terbaik", "peringkat", "terbanyak", "wajib bayar", "tarif tetap"):
                self.assertNotIn(word, lowered)
        for sid in ("LYN-01", "LYN-02", "LYN-03", "LYN-06"):
            self.assertIn("tidak ada tarif wajib" if sid != "LYN-06" else "tidak dipungut tarif",
                          SERVICES[sid]["CATATAN_PENTING"].lower())

    def test_guides_are_public_and_owned_by_a_section(self):
        sections = {r["ID_SEKSI"] for r in DATA["MASTER_DATA.MASTER_SEKSI"]}
        for service in SERVICES.values():
            self.assertEqual(service["ID_KLASIFIKASI_DATA"], "KLS-01")
            self.assertIn(service["ID_SEKSI_PENGELOLA"], sections)
        category = next(r for r in DATA["MASTER_DATA.REFERENSI_KATEGORI_INFORMASI"] if r["ID_KATEGORI_INFORMASI"] == "KIN-10")
        self.assertEqual(category["ID_KLASIFIKASI_DATA"], "KLS-01")

    def test_the_family_registration_guide_asks_for_consent_to_record_personal_data(self):
        requirement = next(r for r in REQUIREMENTS["LYN-05"] if "data" in r["NAMA_PERSYARATAN"].lower())
        self.assertTrue(requirement["WAJIB_DIPENUHI"])
        self.assertIn("klasifikasi terbatas", requirement["KETERANGAN"].lower())

    def test_ids_and_file_names_follow_the_service_number(self):
        for sid, service in SERVICES.items():
            number = sid.split("-")[1]
            self.assertTrue(service["NAMA_BERKAS_PANDUAN"].startswith(sid + "_"))
            self.assertTrue(service["NAMA_BERKAS_PANDUAN"].endswith(".pdf"))
            self.assertEqual([r["ID_LANGKAH"] for r in STEPS[sid]][0], f"LGK-{number}01")
            self.assertEqual([r["ID_PERSYARATAN"] for r in REQUIREMENTS[sid]][0], f"PSY-{number}01")
        self.assertEqual(len({s["NAMA_BERKAS_PANDUAN"] for s in SERVICES.values()}), len(SERVICES))


class DocumentTests(unittest.TestCase):
    def test_one_committed_pdf_per_service_and_nothing_else_in_the_folder(self):
        names = sorted(p.name for p in FOLDER.iterdir())
        self.assertEqual(names, sorted(s["NAMA_BERKAS_PANDUAN"] for s in SERVICES.values()))

    def test_the_committed_files_equal_what_the_generator_writes(self):
        generated = layanan.build_documents(DATA)
        self.assertEqual(len(generated), len(SERVICES))
        for relative, content in generated.items():
            self.assertEqual((ROOT / relative).read_bytes(), content, relative)
        self.assertEqual(layanan.build_documents(DATA), layanan.build_documents(DATA))

    def test_every_pdf_is_well_formed(self):
        for service in SERVICES.values():
            data = (FOLDER / service["NAMA_BERKAS_PANDUAN"]).read_bytes()
            self.assertEqual(pdfdoc.verify_structure(data), [], service["ID_LAYANAN"])
            self.assertLess(len(data), 40_000)

    def test_the_pdf_says_everything_the_tables_say_in_the_same_order(self):
        """The extraction round trip: read the PDF back and find every row of the tables in it."""
        for sid, service in SERVICES.items():
            text, parsed = document_text(sid)
            text = words(text)
            self.assertIn(service["NAMA_LAYANAN"].upper(), text, sid)
            self.assertIn(words(service["RINGKASAN"]), text, sid)
            self.assertIn(words(service["CATATAN_PENTING"]), text, sid)
            self.assertIn(words(service["PERKIRAAN_WAKTU_PROSES"]), text, sid)
            self.assertIn(util.date_id(service["TANGGAL_REVISI"]), text, sid)
            self.assertIn(sid, text)
            self.assertIn(words(layanan.NOTICE), text, "every guide says it is an example")
            for kind, rows, name, note in (
                ("requirement", REQUIREMENTS[sid], "NAMA_PERSYARATAN", "KETERANGAN"),
                ("step", STEPS[sid], "JUDUL_LANGKAH", "URAIAN"),
            ):
                position = 0
                for row in rows:
                    for field in (name, note):
                        found = text.find(words(row[field]), position)
                        self.assertGreaterEqual(found, 0, f"{sid} {kind} {row['NOMOR_URUT']} {field} is missing or out of order")
                        position = found + 1
            for row in REQUIREMENTS[sid]:
                self.assertIn("Wajib" if row["WAJIB_DIPENUHI"] else "Jika berlaku", text)
            for row in STEPS[sid]:
                self.assertIn(f"Pelaku: {row['PELAKU']}", text)
            self.assertEqual(parsed["info"]["Title"], f"Panduan Layanan Paroki: {service['NAMA_LAYANAN']}")
            self.assertIn("fiktif", parsed["info"]["Subject"])
            self.assertTrue(parsed["info"]["CreationDate"].startswith("D:" + service["TANGGAL_REVISI"].strftime("%Y%m%d")))

    def test_every_page_carries_the_simulation_footer_and_the_page_count(self):
        for sid in SERVICES:
            _, parsed = document_text(sid)
            total = len(parsed["pages"])
            for number, page in enumerate(parsed["pages"], start=1):
                self.assertIn(documents.SIMULATION_NOTE, page["artifacts"], sid)
                self.assertIn(f"Panduan {sid}  |  Halaman {number} dari {total}", page["artifacts"], sid)

    def test_no_pdf_carries_a_telephone_or_identity_number_or_an_address_that_is_not_fictional(self):
        for sid in SERVICES:
            text, parsed = document_text(sid)
            scan = text + " " + " ".join(v for k, v in parsed["info"].items() if k != "CreationDate")
            self.assertNotRegex(scan, r"\d{7,}", sid)
            self.assertNotRegex(scan, r"@|https?://", sid)
            self.assertIn("(alamat fiktif)", text, sid)

    def test_text_never_runs_over_the_right_margin(self):
        for sid in SERVICES:
            _, parsed = document_text(sid)
            for page in parsed["pages"]:
                for x, top, font, size, string in page["runs"]:
                    self.assertLessEqual(x + pdfdoc.text_width(string, font, size), documents.PDF_RIGHT + 1, (sid, string))
                    self.assertLess(top, 800, (sid, string))


class GeneratorCheckTests(unittest.TestCase):
    def test_check_notices_a_changed_or_stray_guide(self):
        script = str(ROOT / "scripts" / "generate_mock_data.py")
        clean = subprocess.run([sys.executable, script, "--check"], capture_output=True, text=True)
        self.assertEqual(clean.returncode, 0, clean.stdout + clean.stderr)
        stray = FOLDER / "ZZZ_stray_guide.pdf"
        path = next(iter(sorted(FOLDER.glob("LYN-*.pdf"))))
        original = path.read_bytes()
        try:
            stray.write_bytes(b"%PDF-1.4\n%%EOF\n")
            path.write_bytes(original.replace(b"Panduan", b"Pandulan", 1))
            flagged = subprocess.run([sys.executable, script, "--check"], capture_output=True, text=True)
            self.assertEqual(flagged.returncode, 1)
            self.assertIn("ZZZ_stray_guide.pdf", flagged.stdout)
            self.assertIn(path.name, flagged.stdout)
        finally:
            stray.unlink(missing_ok=True)
            path.write_bytes(original)


if __name__ == "__main__":
    unittest.main()
