"""Domains 4.7 and 4.8: annual plans, planned activities, budget allocations,
actual expenditure, events and post-event reports.

The activity table below is written by hand so that the demo tells a believable
story: finished programs, postponed and cancelled ones, future plans, partial or
missing spending, unplanned events, and reports that are final, draft, under
revision or missing. Everything else is derived from that table.
"""

from datetime import date, timedelta

from . import config, util
from .config import AS_OF, CHURCH_NAME, HALL_NAME, PLAN_YEAR
from .reference import SEKSI
from .rng import Rng

SCHEMA = "DATA_OPERASIONAL"

HALL = HALL_NAME
CHURCH = CHURCH_NAME
CATECHISM = "Ruang Katekese Paroki"
MEETING = "Ruang Rapat Paroki"
RETREAT = "Wisma Retret Damai Sejahtera"

T, R, D, B = "Terlaksana", "Direncanakan", "Ditunda", "Dibatalkan"

ANNUAL_GOALS = {
    "SEK-01": "Meningkatkan mutu perayaan liturgi dan keterlibatan petugas liturgi pada tahun 2026.",
    "SEK-02": "Memperkuat pembinaan iman anak, remaja, dan dewasa sepanjang tahun 2026.",
    "SEK-03": "Mendampingi calon pasangan dan keluarga agar semakin kuat dalam iman pada tahun 2026.",
    "SEK-04": "Mengembangkan iman, kepemimpinan, dan kepedulian orang muda pada tahun 2026.",
    "SEK-05": "Memperluas pelayanan sosial dan pemberdayaan ekonomi umat pada tahun 2026.",
    "SEK-06": "Memperbaiki komunikasi dan dokumentasi paroki melalui relawan yang terlatih pada tahun 2026.",
    "SEK-07": "Menumbuhkan kebiasaan membaca dan mendalami Kitab Suci pada tahun 2026.",
    "SEK-08": "Meningkatkan kesehatan umat dan masyarakat sekitar melalui penyuluhan dan layanan pada tahun 2026.",
    "SEK-09": "Menjaga tata kelola administrasi, data, dan keuangan paroki yang tertib pada tahun 2026.",
}


def act(section, name, purpose, start, status, target, place, budget, end=None, spend="normal", report=None,
        missing=(), result=None, note=None, attendance=None, event=None):
    """One planned activity. Budget amounts are in thousands of rupiah.
    spend: normal | over (every category slightly above budget) | deposit (advance only) | none.
    report: None | Final | Draf | Perlu Revisi. missing: report fields left empty.
    event: force (True) or suppress (False) an event row, default depends on status."""
    return {
        "section": section, "name": name, "purpose": purpose, "start": date(PLAN_YEAR, *start),
        "end": date(PLAN_YEAR, *end) if end else None, "status": status, "target": target, "place": place,
        "budget": budget, "spend": spend, "report": report, "missing": tuple(missing), "result": result,
        "note": note, "attendance": attendance, "event": event,
    }


ACTIVITIES = [
    # --- SEK-01 Liturgi -----------------------------------------------------------
    act("SEK-01", "Pelatihan Lektor dan Pemazmur",
        "Meningkatkan kemampuan membaca Kitab Suci dan melagukan mazmur dalam Misa.",
        (2, 14), T, 40, HALL, [("KBY-01", 800), ("KBY-04", 1500), ("KBY-02", 500)], report="Final",
        result="Peserta mengikuti latihan teknik membaca, pernapasan, dan melagukan mazmur, lalu menyelesaikan sesi praktik di depan kelompok."),
    act("SEK-01", "Rangkaian Perayaan Pekan Suci dan Paskah",
        "Menyiapkan dan melaksanakan perayaan Kamis Putih sampai Minggu Paskah dengan khidmat.",
        (4, 2), T, 600, CHURCH, [("KBY-02", 6000), ("KBY-01", 2000), ("KBY-05", 500), ("KBY-06", 1500)],
        end=(4, 5), report="Final", attendance=1.05,
        result="Seluruh liturgi Pekan Suci berjalan lancar, dekorasi dan petugas liturgi dinilai baik oleh umat."),
    act("SEK-01", "Pelatihan Putra-Putri Altar Baru",
        "Membekali anak-anak calon putra-putri altar dengan pengetahuan dan keterampilan melayani di altar.",
        (6, 20), T, 25, CHURCH, [("KBY-01", 500), ("KBY-02", 400)], report="Draf", missing=("REKOMENDASI_TINDAK_LANJUT",),
        result="Peserta mempelajari tugas dasar di altar dan berlatih dalam Misa percobaan."),
    act("SEK-01", "Pelatihan Operator Tata Suara dan Perangkat Baru",
        "Melatih petugas mengoperasikan tata suara dan memperbarui perangkat yang rusak.",
        (7, 18), D, 10, CHURCH, [("KBY-06", 12000), ("KBY-02", 1500)], spend="none",
        note="Ditunda menunggu penawaran harga dari penyedia perangkat."),
    act("SEK-01", "Latihan Koor Gabungan Persiapan Natal",
        "Menyiapkan koor gabungan lintas lingkungan untuk Misa Natal.",
        (11, 7), R, 80, HALL, [("KBY-01", 1500), ("KBY-02", 700)], spend="none"),
    act("SEK-01", "Misa Syukur Hari Ulang Tahun Paroki",
        "Merayakan ulang tahun paroki bersama seluruh umat dalam suasana syukur.",
        (10, 11), R, 350, CHURCH, [("KBY-01", 7000), ("KBY-05", 1200), ("KBY-02", 2500)], spend="none"),
    # --- SEK-02 Katekese ----------------------------------------------------------
    act("SEK-02", "Katekese Persiapan Komuni Pertama",
        "Mempersiapkan anak-anak menerima Komuni Pertama melalui pengajaran iman yang menyenangkan.",
        (2, 7), T, 35, CATECHISM, [("KBY-02", 2500), ("KBY-01", 1800), ("KBY-04", 1200)], end=(4, 25), report="Final",
        result="Anak-anak mengikuti seluruh rangkaian pertemuan dan siap menerima Komuni Pertama, orang tua terlibat aktif dalam pendampingan."),
    act("SEK-02", "Pendampingan Calon Baptis Dewasa",
        "Mendampingi katekumen dewasa menuju sakramen baptis.",
        (1, 24), T, 12, CATECHISM, [("KBY-02", 1500), ("KBY-01", 1000)], end=(4, 4), report="Final",
        result="Para katekumen menyelesaikan seluruh pertemuan pendampingan dan dipersiapkan menerima sakramen pada Malam Paskah."),
    act("SEK-02", "Katekese Persiapan Sakramen Krisma",
        "Membekali remaja dan orang muda untuk menerima sakramen krisma.",
        (7, 4), T, 40, CATECHISM, [("KBY-02", 2500), ("KBY-01", 2000), ("KBY-04", 1500)], end=(9, 26), report="Draf",
        missing=("EVALUASI_LOGISTIK", "REKOMENDASI_TINDAK_LANJUT"),
        result="Peserta menyelesaikan materi pengajaran dan retret singkat sebagai persiapan menerima sakramen."),
    act("SEK-02", "Pelatihan Katekis Lingkungan",
        "Membekali katekis lingkungan dengan metode pendampingan iman yang sederhana.",
        (5, 23), B, 30, HALL, [("KBY-04", 2500), ("KBY-01", 900)], spend="none",
        note="Dibatalkan karena jumlah pendaftar terlalu sedikit, akan diusulkan kembali pada rencana tahun berikutnya."),
    act("SEK-02", "Pekan Katekese Anak",
        "Mengenalkan kisah Kitab Suci kepada anak-anak melalui permainan dan cerita.",
        (11, 14), R, 90, HALL, [("KBY-02", 2000), ("KBY-01", 2500), ("KBY-05", 500)], end=(11, 15), spend="none"),
    # --- SEK-03 Kerasulan Keluarga ----------------------------------------------------
    act("SEK-03", "Kursus Persiapan Perkawinan Angkatan I",
        "Membekali calon pasangan dengan pemahaman tentang perkawinan Katolik dan kehidupan berkeluarga.",
        (3, 14), T, 20, RETREAT, [("KBY-06", 3000), ("KBY-01", 2200), ("KBY-04", 2000), ("KBY-02", 600)], end=(3, 15),
        report="Final", result="Para calon pasangan menyelesaikan seluruh materi dan menyatakan lebih siap membangun keluarga."),
    act("SEK-03", "Rekoleksi Pasangan Suami Istri",
        "Menguatkan relasi pasangan melalui doa, refleksi, dan berbagi pengalaman.",
        (6, 6), T, 60, HALL, [("KBY-01", 2500), ("KBY-04", 1500), ("KBY-02", 500)], report="Draf",
        missing=("REALISASI_BIAYA",),
        result="Pasangan peserta berbagi pengalaman dan menyusun komitmen sederhana untuk keluarga masing-masing."),
    act("SEK-03", "Seminar Pengasuhan Anak di Era Digital",
        "Membantu orang tua mendampingi anak dalam penggunaan gawai dan media sosial.",
        (9, 5), T, 80, HALL, [("KBY-04", 2000), ("KBY-01", 2500), ("KBY-05", 600)]),
    act("SEK-03", "Misa Syukur Ulang Tahun Perkawinan",
        "Mensyukuri perjalanan pasangan yang merayakan ulang tahun perkawinan pada tahun ini.",
        (10, 24), R, 70, CHURCH, [("KBY-01", 3000), ("KBY-02", 800)], spend="none"),
    # --- SEK-04 Kepemudaan ------------------------------------------------------------
    act("SEK-04", "Retret Orang Muda Katolik",
        "Memberi ruang bagi orang muda untuk berefleksi dan memperdalam relasi dengan Tuhan.",
        (4, 25), T, 45, RETREAT, [("KBY-06", 5000), ("KBY-01", 3200), ("KBY-04", 1800), ("KBY-03", 1500)], end=(4, 26),
        report="Final", result="Peserta mengikuti sesi refleksi, adorasi, dan berbagi kelompok dengan antusias."),
    act("SEK-04", "Turnamen Futsal Antarlingkungan",
        "Mempererat persaudaraan antarlingkungan melalui olahraga.",
        (6, 27), T, 120, "Lapangan Futsal Sewaan", [("KBY-06", 2500), ("KBY-01", 2500), ("KBY-02", 800), ("KBY-04", 600)],
        spend="over", report="Final", attendance=1.1,
        result="Turnamen berlangsung tertib dan sportif dengan keterlibatan banyak lingkungan."),
    act("SEK-04", "Pelatihan Kepemimpinan Orang Muda",
        "Melatih orang muda mengelola kegiatan dan memimpin tim pelayanan.",
        (8, 22), D, 35, HALL, [("KBY-04", 2500), ("KBY-01", 1500), ("KBY-02", 600)], spend="deposit",
        note="Ditunda karena bertepatan dengan ujian sekolah, jadwal baru ditetapkan setelah rapat seksi."),
    act("SEK-04", "Bakti Sosial Orang Muda di Panti Asuhan",
        "Menumbuhkan kepedulian orang muda melalui kunjungan dan kegiatan bersama anak-anak panti asuhan.",
        (9, 19), T, 30, "Panti Asuhan Kasih Sejahtera", [("KBY-07", 1500), ("KBY-03", 700), ("KBY-01", 600)],
        report="Perlu Revisi", result="Orang muda mengunjungi panti asuhan, bermain bersama anak-anak, dan menyerahkan bantuan perlengkapan sekolah."),
    act("SEK-04", "Perkemahan Orang Muda Akhir Tahun",
        "Membangun kebersamaan orang muda menjelang akhir tahun.",
        (12, 12), R, 60, "Lokasi Perkemahan Bukit Damai", [("KBY-06", 3000), ("KBY-01", 3500), ("KBY-03", 2000)],
        end=(12, 13), spend="none"),
    # --- SEK-05 Pengembangan Sosial Ekonomi -----------------------------------------------
    act("SEK-05", "Penyaluran Bantuan Aksi Puasa Pembangunan",
        "Menyalurkan hasil Aksi Puasa Pembangunan kepada keluarga dan lembaga yang membutuhkan.",
        (4, 11), T, 150, HALL, [("KBY-07", 12000), ("KBY-05", 500), ("KBY-01", 1500)], report="Final",
        result="Bantuan tersalurkan kepada keluarga penerima manfaat sesuai daftar yang telah diverifikasi."),
    act("SEK-05", "Pelatihan Kewirausahaan Usaha Mikro Umat",
        "Membekali umat dengan keterampilan merintis dan mengelola usaha kecil.",
        (5, 30), T, 35, HALL, [("KBY-04", 3000), ("KBY-02", 1500), ("KBY-01", 1800)], end=(5, 31), report="Final",
        result="Peserta menyusun rencana usaha sederhana dan berlatih menghitung modal serta harga jual."),
    act("SEK-05", "Kunjungan dan Santunan Lansia",
        "Mengunjungi dan menyantuni umat lanjut usia yang hidup sendiri atau kurang mampu.",
        (7, 11), T, 60, "Rumah Umat di Lingkungan", [("KBY-07", 4000), ("KBY-03", 800), ("KBY-01", 700)], report="Draf",
        missing=("HASIL_KEGIATAN", "REKOMENDASI_TINDAK_LANJUT")),
    act("SEK-05", "Penyaluran Bantuan Korban Banjir",
        "Menyalurkan dana solidaritas dan bantuan darurat kepada korban banjir.",
        (7, 26), T, 90, "Posko Bantuan Paroki", [("KBY-07", 10000), ("KBY-03", 1500), ("KBY-01", 1000)], report="Final",
        result="Bantuan darurat berupa kebutuhan pokok tersalurkan kepada keluarga yang terdampak."),
    act("SEK-05", "Pasar Murah Menjelang Natal",
        "Menyediakan kebutuhan pokok dengan harga terjangkau bagi keluarga yang membutuhkan.",
        (12, 5), R, 300, "Halaman Gereja", [("KBY-07", 6000), ("KBY-02", 1500), ("KBY-05", 600)], spend="none"),
    act("SEK-05", "Pelatihan Pengelolaan Keuangan Keluarga",
        "Membantu keluarga menyusun anggaran dan menabung secara sehat.",
        (9, 12), D, 50, HALL, [("KBY-04", 1500), ("KBY-01", 1500), ("KBY-02", 400)], spend="none",
        note="Ditunda ke bulan November karena narasumber berhalangan."),
    # --- SEK-06 Komunikasi Sosial ---------------------------------------------------------
    act("SEK-06", "Pelatihan Fotografi dan Videografi Liturgi",
        "Melatih relawan mendokumentasikan perayaan secara santun dan berkualitas.",
        (3, 21), T, 20, HALL, [("KBY-04", 1500), ("KBY-02", 600), ("KBY-01", 500)], report="Final",
        result="Relawan berlatih mengambil gambar dengan sikap menghormati perayaan dan menyepakati aturan dokumentasi."),
    act("SEK-06", "Lokakarya Penulisan Warta Paroki",
        "Meningkatkan keterampilan relawan menulis berita dan warta paroki.",
        (5, 9), T, 15, MEETING, [("KBY-04", 1000), ("KBY-01", 400)], report="Draf", missing=("REKOMENDASI_TINDAK_LANJUT",),
        result="Relawan menulis contoh warta dan menerima masukan penyuntingan."),
    act("SEK-06", "Pelatihan Siaran Langsung Misa",
        "Melatih relawan mengoperasikan perangkat siaran langsung Misa.",
        (8, 15), T, 12, CHURCH, [("KBY-06", 1500), ("KBY-04", 800)]),
    act("SEK-06", "Temu Relawan Media Paroki",
        "Menyatukan relawan media untuk merencanakan liputan perayaan Natal.",
        (11, 21), R, 25, MEETING, [("KBY-01", 500), ("KBY-02", 300)], spend="none"),
    # --- SEK-07 Kitab Suci ----------------------------------------------------------------
    act("SEK-07", "Kursus Dasar Kitab Suci Angkatan I",
        "Memperkenalkan struktur dan pesan pokok Kitab Suci kepada umat awam.",
        (1, 31), T, 30, CATECHISM, [("KBY-02", 1500), ("KBY-04", 2000), ("KBY-01", 1200)], end=(3, 14), report="Final",
        result="Peserta menyelesaikan kursus dan mampu menjelaskan struktur serta tema pokok Kitab Suci."),
    act("SEK-07", "Perayaan Bulan Kitab Suci Nasional",
        "Menghidupkan kebiasaan membaca Kitab Suci melalui ibadat dan sarasehan.",
        (9, 26), T, 200, CHURCH, [("KBY-01", 2500), ("KBY-05", 800), ("KBY-02", 1200)], report="Draf",
        missing=("REALISASI_BIAYA",), result="Ibadat Sabda dan sarasehan berlangsung khidmat, umat membawa Kitab Suci masing-masing."),
    act("SEK-07", "Lomba Cerdas Cermat Kitab Suci Antarlingkungan",
        "Mengajak lingkungan berlomba memahami Kitab Suci dengan gembira.",
        (9, 20), T, 150, HALL, [("KBY-02", 1500), ("KBY-01", 2000), ("KBY-04", 700)]),
    act("SEK-07", "Pendalaman Kitab Suci Masa Adven",
        "Mendampingi umat mempersiapkan Natal melalui pendalaman Kitab Suci.",
        (11, 29), R, 100, HALL, [("KBY-02", 800), ("KBY-01", 1200)], spend="none"),
    # --- SEK-08 Pelayanan Kesehatan ----------------------------------------------------------
    act("SEK-08", "Pemeriksaan Kesehatan Gratis untuk Lansia",
        "Memberi layanan pemeriksaan tekanan darah, gula darah, dan konsultasi bagi lansia.",
        (5, 16), T, 100, HALL, [("KBY-02", 3000), ("KBY-01", 2000), ("KBY-04", 1500)], report="Final",
        result="Para lansia menerima pemeriksaan dasar dan konsultasi, sebagian dirujuk ke fasilitas kesehatan untuk pemeriksaan lanjutan."),
    act("SEK-08", "Aksi Donor Darah Paroki",
        "Mengajak umat berdonor darah untuk membantu sesama yang membutuhkan.",
        (8, 29), T, 70, HALL, [("KBY-01", 1800), ("KBY-05", 500), ("KBY-02", 700)], report="Final",
        result="Kantong darah terkumpul dan diserahkan kepada unit donor darah mitra."),
    act("SEK-08", "Pelatihan Pertolongan Pertama",
        "Membekali relawan dengan keterampilan pertolongan pertama.",
        (6, 13), B, 30, HALL, [("KBY-04", 1500), ("KBY-02", 800)], spend="none", event=False,
        note="Dibatalkan karena instruktur tidak tersedia, dijadwalkan ulang pada tahun depan."),
    act("SEK-08", "Penyuluhan Gizi Keluarga",
        "Meningkatkan pengetahuan keluarga tentang gizi seimbang.",
        (10, 17), R, 60, HALL, [("KBY-04", 1200), ("KBY-01", 1200), ("KBY-05", 300)], spend="none"),
    # --- SEK-09 Sekretariat dan Keuangan -------------------------------------------------------
    act("SEK-09", "Rapat Kerja Pengurus Paroki",
        "Menyusun arah dan prioritas pelayanan paroki tahun berjalan.",
        (1, 17), T, 45, RETREAT, [("KBY-06", 3500), ("KBY-01", 3000), ("KBY-02", 600)], end=(1, 18), report="Final",
        result="Pengurus menyepakati prioritas pelayanan dan jadwal besar kegiatan tahun 2026."),
    act("SEK-09", "Pelatihan Pengelolaan Data Umat dan Pelindungan Privasi",
        "Membekali petugas agar mengelola data umat dengan aman dan menghormati privasi.",
        (7, 25), T, 18, MEETING, [("KBY-04", 1500), ("KBY-01", 700), ("KBY-02", 300)], report="Final",
        result="Petugas memahami klasifikasi data, batas akses, dan cara menjaga kerahasiaan data umat."),
    act("SEK-09", "Lokakarya Digitalisasi Arsip Paroki",
        "Memindai dan menata arsip paroki agar mudah dicari dan aman.",
        (8, 8), D, 12, "Ruang Arsip Paroki", [("KBY-02", 2500), ("KBY-06", 1500)], spend="deposit",
        note="Ditunda karena perangkat pemindai belum tersedia."),
    act("SEK-09", "Rapat Evaluasi Semester dan Penyusunan Anggaran 2027",
        "Mengevaluasi pelaksanaan program dan menyusun anggaran tahun berikutnya.",
        (11, 14), R, 40, MEETING, [("KBY-01", 1000), ("KBY-02", 300)], spend="none"),
]

# Events that were never part of the annual plan.
UNPLANNED = [
    {"section": "SEK-05", "name": "Doa Bersama dan Penggalangan Bantuan Korban Longsor", "start": date(2026, 3, 28),
     "place": CHURCH, "target": 60, "actual": 85, "cost": 3200000, "report": "Final",
     "result": "Doa bersama dan penggalangan bantuan berjalan lancar, bantuan diteruskan melalui jaringan pelayanan sosial.",
     "note": "Kegiatan spontan di luar rencana kerja tahunan."},
    {"section": "SEK-09", "name": "Pertemuan Darurat Panitia Pembangunan Kapel", "start": date(2026, 6, 2),
     "place": MEETING, "target": 15, "actual": 14, "cost": None, "report": None, "result": None,
     "note": "Kegiatan spontan di luar rencana kerja tahunan."},
]

LOGISTICS_NEUTRAL = [
    "Perlengkapan, tempat, dan konsumsi tersedia dengan baik dan tepat waktu.",
    "Tata suara dan proyektor berfungsi baik, konsumsi cukup untuk seluruh peserta.",
    "Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.",
]
LOGISTICS_FULL = "Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup."
LOGISTICS_LOW = "Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa."
RECOMMENDATIONS = [
    "Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.",
    "Pendaftaran perlu dibuka lebih awal agar persiapan konsumsi dan perlengkapan lebih akurat.",
    "Publikasi perlu melibatkan lebih banyak lingkungan agar jangkauan peserta lebih luas.",
    "Siapkan cadangan perlengkapan dan petugas untuk mengantisipasi kendala teknis.",
]
EXPENSE_TEXT = {
    "KBY-01": "konsumsi peserta",
    "KBY-02": "perlengkapan dan bahan",
    "KBY-03": "transportasi dan akomodasi",
    "KBY-04": "honorarium dan narasumber",
    "KBY-05": "publikasi dan dokumentasi",
    "KBY-06": "sewa sarana dan perawatan",
    "KBY-07": "bantuan dan santunan sosial",
}
# Planned events further away than this many days are not yet registered as events.
EVENT_REGISTRATION_HORIZON = 35


def _period_text(start, end):
    if end is None or end == start:
        return util.date_id(start)
    if (start.year, start.month) == (end.year, end.month):
        return f"{start.day} sampai {end.day} {util.MONTHS_ID[start.month - 1]} {start.year}"
    return f"{util.date_id(start)} sampai {util.date_id(end)}"


def _expenditure_for(rng, activity, allocations, counter):
    """Return expenditure rows for one activity (may be empty)."""
    mode, status = activity["spend"], activity["status"]
    start, end = activity["start"], activity["end"] or activity["start"]
    rows = []

    def add(allocation, when, amount, text):
        rows.append(
            {
                "ID_PENGELUARAN": f"PGL-{util.pad(counter + len(rows) + 1, 4)}",
                "ID_ALOKASI": allocation["ID_ALOKASI"],
                "TANGGAL_PENGELUARAN": when,
                "JUMLAH_PENGELUARAN": amount,
                "KETERANGAN": text,
            }
        )

    if mode == "none" or status in (R, B):
        return rows
    if mode == "deposit":
        allocation = allocations[0]
        advance = util.round_to(allocation["JUMLAH_ANGGARAN"] * 0.25, 5000)
        add(allocation, min(AS_OF, start - timedelta(days=10)), advance,
            f"Uang muka {EXPENSE_TEXT[allocation['ID_KATEGORI_BIAYA']]} yang sudah dibayarkan sebelum kegiatan ditunda.")
        return rows

    largest = max(allocations, key=lambda a: a["JUMLAH_ANGGARAN"])
    for allocation in allocations:
        budget = allocation["JUMLAH_ANGGARAN"]
        if mode == "over":
            ratio = 1.03 + rng.random() * 0.09  # every category slightly above budget
        elif len(allocations) > 2 and allocation is not largest and rng.chance(0.08):
            continue  # this category was not used
        else:
            ratio = min(1.0, max(0.6, rng.normal(0.93, 0.08)))
        total = max(5000, util.round_to(budget * ratio, 5000))
        label = EXPENSE_TEXT[allocation["ID_KATEGORI_BIAYA"]]
        if total >= 1000000:
            advance = util.round_to(total * 0.6, 5000)
            add(allocation, max(date(PLAN_YEAR, 1, 2), start - timedelta(days=rng.randint(2, 14))), advance,
                f"Uang muka {label}.")
            add(allocation, min(AS_OF, end + timedelta(days=rng.randint(1, 6))), total - advance,
                f"Pelunasan {label}.")
        else:
            add(allocation, max(date(PLAN_YEAR, 1, 2), start - timedelta(days=rng.randint(0, 7))), total,
                f"Pembayaran {label}.")
    return rows


def build():
    rng = Rng(config.SEED, "planning")
    headers, plans, allocations, expenditures, events, reports = [], [], [], [], [], []
    for index, (section_id, _, _) in enumerate(SEKSI, start=1):
        revising = section_id == "SEK-04"
        headers.append(
            {
                "ID_RENCANA_KERJA": f"RKT-{PLAN_YEAR}-{util.pad(index, 2)}",
                "ID_SEKSI": section_id,
                "TAHUN_RENCANA": PLAN_YEAR,
                "TUJUAN_UMUM": ANNUAL_GOALS[section_id],
                "STATUS_PENGESAHAN": "Dalam Revisi" if revising else "Disahkan",
                "TANGGAL_PENGESAHAN": date(2025, 12, 8) + timedelta(days=index),
                "KETERANGAN": "Direvisi karena penundaan pelatihan kepemimpinan dan perubahan jadwal semester."
                if revising else None,
            }
        )
    header_of = {h["ID_SEKSI"]: h for h in headers}

    for number, activity in enumerate(ACTIVITIES, start=1):
        header = header_of[activity["section"]]
        plan_id = f"RNC-{util.pad(number, 3)}"
        plans.append(
            {
                "ID_RENCANA": plan_id,
                "ID_RENCANA_KERJA": header["ID_RENCANA_KERJA"],
                "NAMA_PROGRAM": activity["name"],
                "TUJUAN_PROGRAM": activity["purpose"],
                "TANGGAL_RENCANA": activity["start"],
                "STATUS_PELAKSANAAN": activity["status"],
                "KETERANGAN": activity["note"],
            }
        )
        own_allocations = []
        for category, thousands in activity["budget"]:
            allocation = {
                "ID_ALOKASI": f"ALK-{util.pad(len(allocations) + 1, 3)}",
                "ID_RENCANA": plan_id,
                "ID_KATEGORI_BIAYA": category,
                "JUMLAH_ANGGARAN": thousands * 1000,
                "TANGGAL_PERSETUJUAN": header["TANGGAL_PENGESAHAN"],
                "KETERANGAN": None,
            }
            allocations.append(allocation)
            own_allocations.append(allocation)
        spent = _expenditure_for(rng, activity, own_allocations, len(expenditures))
        expenditures.extend(spent)
        activity["_plan_id"] = plan_id
        activity["_spent"] = sum(row["JUMLAH_PENGELUARAN"] for row in spent)

    # --- events and reports --------------------------------------------------------
    def make_report(event, spec, planned_cost):
        """spec: dict with report, result, missing."""
        status = spec["report"]
        end = event["TANGGAL_SELESAI"]
        actual = event["JUMLAH_PESERTA_AKTUAL"]
        target = event["TARGET_PESERTA"]
        if actual > target * 1.05:
            logistics = LOGISTICS_FULL
        elif actual < target * 0.85:
            logistics = LOGISTICS_LOW
        else:
            logistics = rng.choice(LOGISTICS_NEUTRAL)
        report = {
            "ID_LAPORAN": f"LPK-{util.pad(len(reports) + 1, 3)}",
            "ID_KEGIATAN": event["ID_KEGIATAN"],
            "TANGGAL_LAPORAN": min(AS_OF, end + timedelta(days=rng.randint(3, 12))),
            "STATUS_LAPORAN": status,
            "RINGKASAN_PELAKSANAAN": (
                f"{event['NAMA_KEGIATAN']} dilaksanakan pada {_period_text(event['TANGGAL_MULAI'], end)} "
                f"di {event['LOKASI']} dengan {actual} peserta dari target {target} peserta."
            ),
            "JUMLAH_PESERTA": actual + 4 if status == "Perlu Revisi" else actual,
            "REALISASI_BIAYA": planned_cost,
            "EVALUASI_LOGISTIK": logistics,
            "HASIL_KEGIATAN": spec["result"],
            "REKOMENDASI_TINDAK_LANJUT": rng.choice(RECOMMENDATIONS),
        }
        for column in spec["missing"]:
            report[column] = None
        reports.append(report)

    for activity in ACTIVITIES:
        status = activity["status"]
        start = activity["start"]
        if activity["event"] is not None:
            has_event = activity["event"]
        elif status == R:
            has_event = (start - AS_OF).days <= EVENT_REGISTRATION_HORIZON
        else:
            has_event = True
        if not has_event:
            continue
        end = activity["end"] or start
        held = status == T
        ratio = activity["attendance"] or (0.78 + rng.random() * 0.34)
        event = {
            "ID_KEGIATAN": f"KGT-{util.pad(len(events) + 1, 3)}",
            "ID_RENCANA": activity["_plan_id"],
            "NAMA_KEGIATAN": activity["name"],
            "ID_SEKSI": activity["section"],
            "TANGGAL_MULAI": start,
            "TANGGAL_SELESAI": end,
            "LOKASI": activity["place"],
            "STATUS_KEGIATAN": status,
            "TARGET_PESERTA": activity["target"],
            "JUMLAH_PESERTA_AKTUAL": max(1, int(activity["target"] * ratio + 0.5)) if held else None,
            "KETERANGAN": activity["note"],
        }
        events.append(event)
        if held and activity["report"]:
            make_report(event, {"report": activity["report"], "result": activity["result"], "missing": activity["missing"]},
                        activity["_spent"])

    for item in UNPLANNED:
        event = {
            "ID_KEGIATAN": f"KGT-{util.pad(len(events) + 1, 3)}",
            "ID_RENCANA": None,
            "NAMA_KEGIATAN": item["name"],
            "ID_SEKSI": item["section"],
            "TANGGAL_MULAI": item["start"],
            "TANGGAL_SELESAI": item["start"],
            "LOKASI": item["place"],
            "STATUS_KEGIATAN": T,
            "TARGET_PESERTA": item["target"],
            "JUMLAH_PESERTA_AKTUAL": item["actual"],
            "KETERANGAN": item["note"],
        }
        events.append(event)
        if item["report"]:
            make_report(event, {"report": item["report"], "result": item["result"], "missing": ()}, item["cost"])

    for activity in ACTIVITIES:  # drop helper keys so the module can be re-run safely
        activity.pop("_plan_id", None)
        activity.pop("_spent", None)

    return {
        f"{SCHEMA}.RENCANA_KERJA_TAHUNAN": headers,
        f"{SCHEMA}.RENCANA_KEGIATAN": plans,
        f"{SCHEMA}.ALOKASI_ANGGARAN": allocations,
        f"{SCHEMA}.REALISASI_PENGELUARAN": expenditures,
        f"{SCHEMA}.KEGIATAN": events,
        f"{SCHEMA}.LAPORAN_KEGIATAN": reports,
    }
