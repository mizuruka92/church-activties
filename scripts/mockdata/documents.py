"""Mock source documents: one PDF post-event report for every row of DATA_OPERASIONAL.LAPORAN_KEGIATAN.

The story these files tell: sections of the parish write their post-event reports as documents, and the
rows of LAPORAN_KEGIATAN are what an extraction step (a person, or later a document-AI service) reads
out of them. So every value in a row can be found in its PDF, and a PDF contains nothing that
contradicts its row. The reverse is not true on purpose: a PDF also carries context (letterhead,
the plan's purpose, the cost breakdown, signatures) and sometimes a reviewer's note, none of which is
stored in the table.

Deliberate situations, matching the data:
  * Final reports are complete and signed.
  * Draft reports leave sections empty ("(belum diisi)"), carry a DRAF watermark and are unsigned.
  * The report under revision states 34 participants in section C while its own summary says 30; a reviewer's
    note points this out. That is the one deliberate inconsistency of the dataset.

Everything is fictional: the parish, the address, the section officers, the figures.
"""

from . import config, pdfdoc, util
from .parish import FEMALE_BAPTISM, FEMALE_GIVEN, MALE_BAPTISM, MALE_GIVEN, SURNAMES
from .reference import SEKSI_NAMA
from .rng import Rng

FOLDER = "data/documents/laporan_kegiatan"
PARISH = "PAROKI SANTA MARIA CONTOH"
ADDRESS = "Jl. Contoh No. 1, Kota Contoh (alamat fiktif)"
SIMULATION_NOTE = "Dokumen simulasi (fiktif), bukan dokumen paroki yang sebenarnya"
EMPTY = "(belum diisi)"
NO_PLAN = "Kegiatan di luar rencana kerja tahunan"

LEFT, PDF_RIGHT = 57, 538
CONTENT_WIDTH = PDF_RIGHT - LEFT
LABEL_WIDTH = 150
VALUE_X = LEFT + LABEL_WIDTH + 12
BODY, LEADING = 9.5, 13.0
BOTTOM = 790  # lowest baseline for content, the footer sits below


# --------------------------------------------------------------------------------------------
# Formatting helpers (Indonesian conventions: dot for thousands)
# --------------------------------------------------------------------------------------------
def rupiah(value):
    return "Rp " + f"{value:,}".replace(",", ".")


def people(value):
    return f"{value} orang"


def period_text(start, end):
    if end is None or end == start:
        return util.date_id(start)
    if (start.year, start.month) == (end.year, end.month):
        return f"{start.day} sampai {end.day} {util.MONTHS_ID[start.month - 1]} {start.year}"
    return f"{util.date_id(start)} sampai {util.date_id(end)}"


def slug(text):
    cleaned = "".join(char if char.isalnum() else " " for char in text)
    return "_".join(cleaned.split())[:60]


def file_name(report, event):
    return f"{report['ID_LAPORAN']}_{slug(event['NAMA_KEGIATAN'])}_{event['TANGGAL_MULAI'].isoformat()}.pdf"


def attach_file_names(data):
    """Record on every report row the file its document is saved as: the row was 'extracted' from that file."""
    events = {e["ID_KEGIATAN"]: e for e in data["DATA_OPERASIONAL.KEGIATAN"]}
    for report in data["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]:
        report["NAMA_BERKAS_SUMBER"] = file_name(report, events[report["ID_KEGIATAN"]])


def officers():
    """A fictional chair and secretary per section, the same in every year."""
    rng = Rng(config.SEED, "documents")
    result = {}
    for section_id in sorted(SEKSI_NAMA):
        chair = f"{rng.choice(MALE_BAPTISM)} {rng.choice(MALE_GIVEN)} {rng.choice(SURNAMES)}"
        secretary = f"{rng.choice(FEMALE_BAPTISM)} {rng.choice(FEMALE_GIVEN)} {rng.choice(SURNAMES)}"
        result[section_id] = (chair, secretary)
    return result


# --------------------------------------------------------------------------------------------
# Layout: a cursor that flows content down the page and starts a new page when it runs out
# --------------------------------------------------------------------------------------------
class Flow:
    def __init__(self, pdf):
        self.pdf = pdf
        self.page = None
        self.y = 0.0
        self.new_page()

    def new_page(self):
        self.page = self.pdf.new_page()
        self.y = 56.0

    def need(self, height):
        if self.y + height > BOTTOM:
            self.new_page()

    def space(self, points):
        self.y += points

    def paragraph(self, text, x=LEFT, width=CONTENT_WIDTH, font="F1", size=BODY, gray=0.0, leading=LEADING):
        for line in pdfdoc.wrap(text, font, size, width):
            self.need(leading)
            self.page.text(x, self.y + size, line, font, size, gray)
            self.y += leading

    def heading(self, text):
        self.need(36)
        self.space(6)
        self.page.text(LEFT, self.y + 10, text, "F2", 11)
        self.page.line(LEFT, self.y + 14, PDF_RIGHT, self.y + 14, 0.6, 0.45)
        self.y += 21

    def pair(self, left, right):
        """Two 'label : value' pairs side by side, for short identifiers."""
        self.need(LEADING)
        for (label, value), x in ((left, LEFT), (right, 318)):
            self.page.text(x, self.y + BODY, label, "F1", BODY)
            self.page.text(x + 92, self.y + BODY, ":", "F1", BODY)
            self.page.text(x + 101, self.y + BODY, value, "F1", BODY)
        self.y += LEADING

    def field(self, label, value, bold=False, empty=False):
        """A 'label : value' row. The value may wrap onto several lines."""
        lines = pdfdoc.wrap(value, "F2" if bold else "F1", BODY, PDF_RIGHT - VALUE_X)
        self.need(LEADING * len(lines))
        self.page.text(LEFT, self.y + BODY, label, "F1", BODY)
        self.page.text(VALUE_X - 9, self.y + BODY, ":", "F1", BODY)
        for line in lines:
            self.page.text(VALUE_X, self.y + BODY, line, "F2" if bold else "F1", BODY, 0.45 if empty else 0.0)
            self.y += LEADING

    def section_text(self, value):
        if value:
            self.paragraph(value)
        else:
            self.paragraph(EMPTY, gray=0.45)


def _footer(pdf, report):
    total = len(pdf.pages)
    for number, page in enumerate(pdf.pages, start=1):
        page.line(LEFT, 806, PDF_RIGHT, 806, 0.4, 0.6)
        page.artifact_text(LEFT, 820, f"Laporan {report['ID_LAPORAN']}  |  Halaman {number} dari {total}")
        note_width = pdfdoc.text_width(SIMULATION_NOTE, "F1", 8)
        page.artifact_text(PDF_RIGHT - note_width, 820, SIMULATION_NOTE)


def _letterhead(flow):
    page = flow.page
    # a small Latin cross as the parish mark
    page.line(LEFT + 12, 52, LEFT + 12, 86, 3.0, 0.2)
    page.line(LEFT, 63, LEFT + 24, 63, 3.0, 0.2)
    center = (LEFT + PDF_RIGHT) / 2.0
    for text, font, size, top in ((PARISH, "F2", 15, 62), ("Sekretariat Paroki", "F1", 10.5, 77), (ADDRESS, "F1", 9, 90)):
        page.text(center - pdfdoc.text_width(text, font, size) / 2.0, top, text, font, size)
    page.line(LEFT, 98, PDF_RIGHT, 98, 1.6, 0.1)
    page.line(LEFT, 101, PDF_RIGHT, 101, 0.4, 0.1)
    flow.y = 112.0


def _title(flow, section_name):
    title = "LAPORAN PELAKSANAAN KEGIATAN"
    center = (LEFT + PDF_RIGHT) / 2.0
    flow.page.text(center - pdfdoc.text_width(title, "F2", 13) / 2.0, flow.y + 12, title, "F2", 13)
    sub = section_name.upper()
    flow.page.text(center - pdfdoc.text_width(sub, "F1", 10) / 2.0, flow.y + 28, sub, "F1", 10)
    flow.y += 40


def _cost_table(flow, plan_allocations, spent_by_allocation, category_names):
    columns = [(LEFT, 26, "No."), (LEFT + 26, 214, "Kategori biaya"), (LEFT + 240, 120, "Anggaran"), (LEFT + 360, 121, "Realisasi")]
    row_height = 15.0
    flow.need(row_height * (len(plan_allocations) + 3))
    top = flow.y
    flow.page.rect(LEFT, top, CONTENT_WIDTH, row_height, 0.5, 0.3, fill=0.92)
    for x, width, label in columns:
        right = label in ("Anggaran", "Realisasi")
        text = label + " (Rp)" if right else label
        position = x + width - 6 - pdfdoc.text_width(text, "F2", 9) if right else x + 6
        flow.page.text(position, top + 11, text, "F2", 9)
    rows = []
    for number, allocation in enumerate(plan_allocations, start=1):
        spent = spent_by_allocation.get(allocation["ID_ALOKASI"], 0)
        rows.append((str(number), category_names[allocation["ID_KATEGORI_BIAYA"]], allocation["JUMLAH_ANGGARAN"], spent))
    totals = (sum(r[2] for r in rows), sum(r[3] for r in rows))
    top += row_height
    for number, name, budget, spent in rows:
        flow.page.rect(LEFT, top, CONTENT_WIDTH, row_height, 0.3, 0.6)
        flow.page.text(columns[0][0] + 6, top + 11, number, "F1", 9)
        flow.page.text(columns[1][0] + 6, top + 11, name, "F1", 9)
        for (x, width, _), value in ((columns[2], budget), (columns[3], spent)):
            text = f"{value:,}".replace(",", ".")
            flow.page.text(x + width - 6 - pdfdoc.text_width(text, "F1", 9), top + 11, text, "F1", 9)
        top += row_height
    flow.page.rect(LEFT, top, CONTENT_WIDTH, row_height, 0.5, 0.3, fill=0.96)
    flow.page.text(columns[1][0] + 6, top + 11, "Jumlah", "F2", 9)
    for (x, width, _), value in ((columns[2], totals[0]), (columns[3], totals[1])):
        text = f"{value:,}".replace(",", ".")
        flow.page.text(x + width - 6 - pdfdoc.text_width(text, "F2", 9), top + 11, text, "F2", 9)
    flow.y = top + row_height + 8


def _signatures(flow, report, officer_pair, section_name, rng):
    final = report["STATUS_LAPORAN"] == "Final"
    flow.need(128 if final else 96)
    flow.space(8)
    place_date = f"Kota Contoh, {util.date_id(report['TANGGAL_LAPORAN'])}"
    flow.page.text(PDF_RIGHT - 190, flow.y + 10, place_date, "F1", BODY)
    flow.y += 18
    columns = ((LEFT, "Dibuat oleh,", f"Sekretaris {section_name}", officer_pair[1]),
               (PDF_RIGHT - 190, "Mengetahui,", f"Ketua {section_name}", officer_pair[0]))
    top = flow.y
    for x, caption, role, name in columns:
        flow.page.text(x, top + 10, caption, "F1", BODY)
        for index, line in enumerate(pdfdoc.wrap(role, "F1", BODY, 180)):
            flow.page.text(x, top + 24 + 12 * index, line, "F1", BODY)
        name_top = top + (80 if final else 62)
        if final:
            # a hand-drawn looking signature above the typed name
            points = [(x + 4, top + 56)]
            for step in range(1, 10):
                points.append((x + 4 + step * 11 + rng.randint(-3, 3), top + 56 + rng.randint(-14, 12)))
            flow.page.curve(points, 0.9, 0.25)
        else:
            flow.page.text(x, top + 50, "(belum ditandatangani)", "F1", 9, 0.45)
        flow.page.text(x, name_top, name, "F2", BODY)
        flow.page.line(x, name_top + 3, x + pdfdoc.text_width(name, "F2", BODY), name_top + 3, 0.5, 0.0)
    flow.y = top + (90 if final else 72)


def _reviewer_note(flow, lines):
    flow.need(20 + 14 * len(lines))
    top = flow.y + 4
    height = 22 + 14 * len(lines)
    flow.page.rect(LEFT, top, CONTENT_WIDTH, height, 0.8, 0.35, fill=0.95)
    flow.page.text(LEFT + 8, top + 14, "Catatan peninjau (Sekretariat Paroki)", "F2", BODY)
    for index, line in enumerate(lines):
        flow.page.text(LEFT + 8, top + 28 + 14 * index, line, "F1", BODY)
    flow.y = top + height + 4


# --------------------------------------------------------------------------------------------
# One document
# --------------------------------------------------------------------------------------------
def render(report, event, plan, allocations, spent_by_allocation, category_names, section_name, officer_pair):
    rng = Rng(config.SEED, f"signature:{report['ID_LAPORAN']}")
    pdf = pdfdoc.Pdf(
        title=f"Laporan Pelaksanaan Kegiatan {report['ID_LAPORAN']}: {event['NAMA_KEGIATAN']}",
        author=f"{section_name} (dokumen simulasi)",
        subject="Laporan pascakegiatan (data simulasi, fiktif)",
        created=report["TANGGAL_LAPORAN"])
    flow = Flow(pdf)
    _letterhead(flow)
    _title(flow, section_name)

    status = report["STATUS_LAPORAN"]
    flow.pair(("Nomor laporan", report["ID_LAPORAN"]), ("Status laporan", status))
    flow.pair(("Nomor kegiatan", event["ID_KEGIATAN"]), ("Tanggal laporan", util.date_id(report["TANGGAL_LAPORAN"])))

    flow.heading("A. Identitas kegiatan")
    flow.field("Nama kegiatan", event["NAMA_KEGIATAN"], bold=True)
    flow.field("Seksi penyelenggara", section_name)
    if plan is not None:
        flow.field("Rencana kerja", f"{plan['ID_RENCANA']}. {plan['TUJUAN_PROGRAM']}")
    else:
        flow.field("Rencana kerja", NO_PLAN)
    flow.field("Waktu pelaksanaan", period_text(event["TANGGAL_MULAI"], event["TANGGAL_SELESAI"]))
    flow.field("Tempat", event["LOKASI"])

    flow.heading("B. Ringkasan pelaksanaan")
    flow.section_text(report["RINGKASAN_PELAKSANAAN"])

    flow.heading("C. Peserta")
    flow.field("Target peserta", people(event["TARGET_PESERTA"]))
    count = report["JUMLAH_PESERTA"]
    flow.field("Jumlah peserta", people(count) if count is not None else EMPTY, bold=count is not None, empty=count is None)
    if count is not None:
        flow.field("Pencapaian terhadap target", f"{round(100.0 * count / event['TARGET_PESERTA'])}%")

    flow.heading("D. Realisasi biaya")
    cost = report["REALISASI_BIAYA"]
    if cost is None:
        flow.paragraph(EMPTY, gray=0.45)
    else:
        if allocations:
            _cost_table(flow, allocations, spent_by_allocation, category_names)
        flow.field("Total realisasi biaya", rupiah(cost), bold=True)

    flow.heading("E. Evaluasi logistik")
    flow.section_text(report["EVALUASI_LOGISTIK"])
    flow.heading("F. Hasil kegiatan")
    flow.section_text(report["HASIL_KEGIATAN"])
    flow.heading("G. Rekomendasi tindak lanjut")
    flow.section_text(report["REKOMENDASI_TINDAK_LANJUT"])

    registered = event["JUMLAH_PESERTA_AKTUAL"]
    if status == "Perlu Revisi" and count is not None and registered is not None and count != registered:
        _reviewer_note(flow, [
            f"Jumlah peserta pada bagian C ({count} orang) berbeda dengan jumlah peserta kegiatan",
            f"yang terdaftar ({registered} orang). Mohon diperiksa sebelum laporan disahkan."])
    elif status == "Draf":
        _reviewer_note(flow, ["Laporan ini masih berstatus draf dan belum disahkan.",
                              "Bagian yang kosong perlu dilengkapi oleh seksi penyelenggara."])

    _signatures(flow, report, officer_pair, section_name, rng)
    if status != "Final":
        watermark = "DRAF" if status == "Draf" else "PERLU REVISI"
        for page in pdf.pages:
            page.watermark(watermark, size=84 if status == "Draf" else 62)
    _footer(pdf, report)
    return pdf.render()


def build(data):
    """{relative path: PDF bytes} for every report in the dataset."""
    events = {e["ID_KEGIATAN"]: e for e in data["DATA_OPERASIONAL.KEGIATAN"]}
    plans = {p["ID_RENCANA"]: p for p in data["DATA_OPERASIONAL.RENCANA_KEGIATAN"]}
    allocations = {}
    for allocation in data["DATA_OPERASIONAL.ALOKASI_ANGGARAN"]:
        allocations.setdefault(allocation["ID_RENCANA"], []).append(allocation)
    spent = {}
    for row in data["DATA_OPERASIONAL.REALISASI_PENGELUARAN"]:
        spent[row["ID_ALOKASI"]] = spent.get(row["ID_ALOKASI"], 0) + row["JUMLAH_PENGELUARAN"]
    categories = {c["ID_KATEGORI_BIAYA"]: c["NAMA_KATEGORI_BIAYA"] for c in data["MASTER_DATA.REFERENSI_KATEGORI_BIAYA"]}
    staff = officers()

    files = {}
    for report in data["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]:
        event = events[report["ID_KEGIATAN"]]
        plan = plans.get(event["ID_RENCANA"])
        own = sorted(allocations.get(event["ID_RENCANA"], []), key=lambda a: a["ID_ALOKASI"])
        files[f"{FOLDER}/{report['NAMA_BERKAS_SUMBER']}"] = render(
            report, event, plan, own, spent, categories, SEKSI_NAMA[event["ID_SEKSI"]], staff[event["ID_SEKSI"]])
    return files
