"""Reference and master data: classification, sections, regions, communities,
controlled vocabularies, reporting calendar and illustrative geometry.

All names are fictional. Region and community names follow the usual naming by
saints, but the combination here is generic and does not describe a real parish.
"""

from datetime import date

from . import config, util
from .vocab import DAFTAR_NILAI

SCHEMA = "MASTER_DATA"
ORGANISATION_START = date(2020, 1, 1)

# --- classification levels -------------------------------------------------

KLS_PUBLIK, KLS_INTERNAL, KLS_TERBATAS, KLS_SANGAT_TERBATAS = "KLS-01", "KLS-02", "KLS-03", "KLS-04"

KLASIFIKASI = [
    (KLS_PUBLIK, "Publik", "Informasi yang aman dibagikan kepada umum, misalnya jadwal Misa dan daftar wilayah.", True, 1),
    (KLS_INTERNAL, "Internal", "Informasi untuk pengurus dan seksi paroki, tidak untuk dasbor publik.", False, 2),
    (KLS_TERBATAS, "Terbatas", "Data pribadi atau sensitif yang hanya boleh diakses petugas berwenang.", False, 3),
    (KLS_SANGAT_TERBATAS, "Sangat Terbatas", "Data pribadi kelompok rentan, misalnya anak di bawah umur, dengan akses paling ketat.", False, 4),
]

# --- sections ---------------------------------------------------------------

SEKSI = [
    ("SEK-01", "Seksi Liturgi", "Mengatur perayaan liturgi, petugas liturgi, dan jadwal Misa."),
    ("SEK-02", "Seksi Katekese", "Menyelenggarakan pembinaan iman bagi anak, remaja, dan dewasa."),
    ("SEK-03", "Seksi Kerasulan Keluarga", "Mendampingi keluarga, calon pasangan, dan pasangan suami istri."),
    ("SEK-04", "Seksi Kepemudaan", "Membina orang muda Katolik melalui kegiatan iman, kepemimpinan, dan pelayanan."),
    ("SEK-05", "Seksi Pengembangan Sosial Ekonomi", "Menjalankan pelayanan sosial dan membantu pemberdayaan ekonomi umat."),
    ("SEK-06", "Seksi Komunikasi Sosial", "Mengelola informasi, dokumentasi, dan media komunikasi paroki."),
    ("SEK-07", "Seksi Kitab Suci", "Mengajak umat membaca dan mendalami Kitab Suci."),
    ("SEK-08", "Seksi Pelayanan Kesehatan", "Menyelenggarakan penyuluhan dan layanan kesehatan bagi umat dan masyarakat sekitar."),
    ("SEK-09", "Seksi Sekretariat dan Keuangan", "Mengelola administrasi, arsip, data umat, dan pembukuan keuangan paroki."),
]
SEKSI_NAMA = {row[0]: row[1] for row in SEKSI}

# --- information categories (one per data domain) --------------------------

KATEGORI_INFORMASI = [
    ("KIN-01", "Kolekte", "Ringkasan kolekte per Misa dan jenis kolekte.", KLS_INTERNAL, "SEK-09"),
    ("KIN-02", "Kehadiran Misa", "Jumlah umat yang hadir pada setiap Misa.", KLS_INTERNAL, "SEK-01"),
    ("KIN-03", "Data Umat", "Data umat dan keluarga, termasuk penugasan ke lingkungan.", KLS_TERBATAS, "SEK-09"),
    ("KIN-04", "Sumbangan Kesempatan Khusus", "Sumbangan wilayah pada masa Prapaskah, Adven, dan kesempatan khusus lain.", KLS_INTERNAL, "SEK-05"),
    ("KIN-05", "Jadwal Misa", "Aturan jadwal Misa dan kejadian Misa yang sebenarnya.", KLS_PUBLIK, "SEK-01"),
    ("KIN-06", "Survei", "Definisi survei, pertanyaan, jawaban, dan hasil agregat.", KLS_INTERNAL, "SEK-06"),
    ("KIN-07", "Rencana dan Anggaran", "Rencana kerja tahunan, anggaran, dan realisasi pengeluaran.", KLS_INTERNAL, "SEK-09"),
    ("KIN-08", "Kegiatan dan Laporan", "Kegiatan seksi dan laporan pascakegiatan.", KLS_INTERNAL, "SEK-09"),
    ("KIN-09", "Wilayah dan Peta", "Struktur wilayah dan lingkungan serta geometri ilustratif.", KLS_PUBLIK, "SEK-09"),
]

JENIS_KOLEKTE = [
    ("KOL-01", "Kolekte Pertama", "Kolekte rutin untuk kebutuhan operasional paroki."),
    ("KOL-02", "Kolekte Kedua", "Kolekte rutin untuk pelayanan sosial dan pemeliharaan fasilitas."),
    ("KOL-03", "Kolekte Khusus", "Kolekte untuk tujuan khusus pada hari tertentu, misalnya Hari Minggu Panggilan."),
]

KESEMPATAN_KHUSUS = [
    ("KSK-01", "Aksi Puasa Pembangunan", "Prapaskah", "Gerakan sumbangan selama masa Prapaskah untuk pelayanan sosial."),
    ("KSK-02", "Aksi Adven Peduli Sesama", "Adven", "Gerakan sumbangan selama masa Adven untuk keluarga yang membutuhkan."),
    ("KSK-03", "Dana Solidaritas Kemanusiaan", "Tidak Terkait Musim", "Penggalangan dana tanggap darurat untuk korban bencana."),
]

KATEGORI_BIAYA = [
    ("KBY-01", "Konsumsi", "Makanan dan minuman peserta atau panitia."),
    ("KBY-02", "Perlengkapan dan Bahan", "Alat tulis, bahan latihan, dekorasi, dan perlengkapan kegiatan."),
    ("KBY-03", "Transportasi dan Akomodasi", "Biaya perjalanan, penginapan, dan sewa kendaraan."),
    ("KBY-04", "Honorarium dan Narasumber", "Uang saku narasumber, pembimbing, dan petugas."),
    ("KBY-05", "Publikasi dan Dokumentasi", "Cetak pengumuman, spanduk, foto, dan video."),
    ("KBY-06", "Sewa Sarana dan Perawatan", "Sewa tempat dan alat, serta perawatan perlengkapan."),
    ("KBY-07", "Bantuan dan Santunan Sosial", "Bantuan berupa uang atau barang kepada penerima manfaat."),
]

# --- access policy (illustrative) -------------------------------------------

_GROUPS = [row[0] for row in DAFTAR_NILAI["KELOMPOK_PENGGUNA"]]
_PASTOR, _SEKSI, _WILAYAH, _SEKRETARIAT, _DASBOR = _GROUPS

_ACCESS = {
    KLS_PUBLIK: {_PASTOR: "Penuh", _SEKSI: "Penuh", _WILAYAH: "Penuh", _SEKRETARIAT: "Penuh", _DASBOR: "Penuh"},
    KLS_INTERNAL: {_PASTOR: "Penuh", _SEKSI: "Penuh", _WILAYAH: "Agregat Saja", _SEKRETARIAT: "Penuh", _DASBOR: "Tidak Ada"},
    KLS_TERBATAS: {_PASTOR: "Penuh", _SEKSI: "Agregat Saja", _WILAYAH: "Penuh", _SEKRETARIAT: "Penuh", _DASBOR: "Tidak Ada"},
    KLS_SANGAT_TERBATAS: {_PASTOR: "Penuh", _SEKSI: "Tidak Ada", _WILAYAH: "Agregat Saja", _SEKRETARIAT: "Penuh", _DASBOR: "Tidak Ada"},
}
_ACCESS_NOTES = {
    (KLS_TERBATAS, _WILAYAH): "Hanya untuk lingkungan dan wilayah yang dipimpin.",
    (KLS_TERBATAS, _SEKRETARIAT): "Hanya sesuai tugas pengelolaan data.",
    (KLS_SANGAT_TERBATAS, _SEKRETARIAT): "Hanya sesuai tugas pengelolaan data dan dengan pencatatan akses.",
    (KLS_INTERNAL, _WILAYAH): "Hanya ringkasan untuk wilayah yang dipimpin.",
}

# --- regions and communities -------------------------------------------------

WILAYAH = [
    ("WIL-01", "Wilayah Santo Yosef"),
    ("WIL-02", "Wilayah Santa Maria"),
    ("WIL-03", "Wilayah Santo Petrus"),
    ("WIL-04", "Wilayah Santo Paulus"),
    ("WIL-05", "Wilayah Santa Theresia"),
    ("WIL-06", "Wilayah Santo Fransiskus"),
]

# (id, region id, name, active). LNG-19 was merged into LNG-03 at the end of 2024
# and demonstrates effective-dated assignments.
LINGKUNGAN = [
    ("LNG-01", "WIL-01", "Lingkungan Santo Antonius", True),
    ("LNG-02", "WIL-01", "Lingkungan Santa Agnes", True),
    ("LNG-03", "WIL-01", "Lingkungan Santo Benediktus", True),
    ("LNG-04", "WIL-02", "Lingkungan Santa Cecilia", True),
    ("LNG-05", "WIL-02", "Lingkungan Santo Dominikus", True),
    ("LNG-06", "WIL-02", "Lingkungan Santa Elisabet", True),
    ("LNG-07", "WIL-03", "Lingkungan Santo Gregorius", True),
    ("LNG-08", "WIL-03", "Lingkungan Santa Helena", True),
    ("LNG-09", "WIL-03", "Lingkungan Santo Ignasius", True),
    ("LNG-10", "WIL-04", "Lingkungan Santa Katarina", True),
    ("LNG-11", "WIL-04", "Lingkungan Santo Lukas", True),
    ("LNG-12", "WIL-04", "Lingkungan Santa Margareta", True),
    ("LNG-13", "WIL-05", "Lingkungan Santo Nikolas", True),
    ("LNG-14", "WIL-05", "Lingkungan Santa Monika", True),
    ("LNG-15", "WIL-05", "Lingkungan Santo Stefanus", True),
    ("LNG-16", "WIL-06", "Lingkungan Santa Veronika", True),
    ("LNG-17", "WIL-06", "Lingkungan Santo Markus", True),
    ("LNG-18", "WIL-06", "Lingkungan Santa Klara", True),
    ("LNG-19", "WIL-01", "Lingkungan Santo Yudas", False),
]
MERGED_LINGKUNGAN = "LNG-19"
MERGED_INTO = "LNG-03"
MERGE_END = date(2024, 12, 31)

ACTIVE_LINGKUNGAN = [row[0] for row in LINGKUNGAN if row[3]]
LINGKUNGAN_TO_WILAYAH = {row[0]: row[1] for row in LINGKUNGAN}

GEO_NOTE = "Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki."


def _geometry():
    """Rectangular illustrative polygons near 0N 0E: three strips per region,
    regions arranged on a 3 x 2 grid. Deliberately placed where no parish exists."""
    rows = []
    region_ids = [row[0] for row in WILAYAH]
    counter = 0
    for region_index, region_id in enumerate(region_ids):
        base_lon = (region_index % 3) * 0.030
        base_lat = (region_index // 3) * 0.030
        members = [row[0] for row in LINGKUNGAN if row[1] == region_id and row[3]]
        for strip, lingkungan_id in enumerate(members):
            west = base_lon + strip * 0.010
            east = west + 0.010
            south, north = base_lat, base_lat + 0.030
            ring = [(west, south), (east, south), (east, north), (west, north), (west, south)]
            coords = ",".join(f"[{lon:.3f},{lat:.3f}]" for lon, lat in ring)
            counter += 1
            rows.append(
                {
                    "ID_GEOMETRI": f"GEO-{util.pad(counter, 2)}",
                    "ID_LINGKUNGAN": lingkungan_id,
                    "GEOJSON": '{"type":"Polygon","coordinates":[[' + coords + "]]}",
                    "JENIS_GEOMETRI": "Polygon",
                    "BERSIFAT_SINTETIS": True,
                    "CATATAN": GEO_NOTE,
                }
            )
    return rows


def build():
    """Return {qualified table name: [row dict, ...]} for the reference domain."""
    data = {}

    data[f"{SCHEMA}.REFERENSI_KLASIFIKASI_DATA"] = [
        {
            "ID_KLASIFIKASI_DATA": i,
            "NAMA_KLASIFIKASI": name,
            "DESKRIPSI": desc,
            "DAPAT_DITAMPILKAN_PUBLIK": public,
            "URUTAN_TINGKAT": level,
        }
        for i, name, desc, public, level in KLASIFIKASI
    ]

    data[f"{SCHEMA}.MASTER_SEKSI"] = [
        {
            "ID_SEKSI": i,
            "NAMA_SEKSI": name,
            "DESKRIPSI": desc,
            "STATUS_AKTIF": True,
            "TANGGAL_MULAI_BERLAKU": ORGANISATION_START,
            "TANGGAL_AKHIR_BERLAKU": None,
        }
        for i, name, desc in SEKSI
    ]

    data[f"{SCHEMA}.REFERENSI_KATEGORI_INFORMASI"] = [
        {
            "ID_KATEGORI_INFORMASI": i,
            "NAMA_KATEGORI": name,
            "DESKRIPSI": desc,
            "ID_KLASIFIKASI_DATA": klasifikasi,
            "ID_SEKSI_PENGELOLA": seksi,
        }
        for i, name, desc, klasifikasi, seksi in KATEGORI_INFORMASI
    ]

    daftar = []
    for group, items in DAFTAR_NILAI.items():
        for order, (value, desc) in enumerate(items, start=1):
            daftar.append({"KELOMPOK_NILAI": group, "NILAI": value, "URUTAN": order, "DESKRIPSI": desc})
    data[f"{SCHEMA}.REFERENSI_DAFTAR_NILAI"] = daftar

    data[f"{SCHEMA}.REFERENSI_JENIS_KOLEKTE"] = [
        {"ID_JENIS_KOLEKTE": i, "NAMA_JENIS_KOLEKTE": name, "DESKRIPSI": desc} for i, name, desc in JENIS_KOLEKTE
    ]

    data[f"{SCHEMA}.REFERENSI_KESEMPATAN_KHUSUS"] = [
        {"ID_KESEMPATAN": i, "NAMA_KESEMPATAN": name, "MUSIM_LITURGI": season, "DESKRIPSI": desc}
        for i, name, season, desc in KESEMPATAN_KHUSUS
    ]

    data[f"{SCHEMA}.REFERENSI_KATEGORI_BIAYA"] = [
        {"ID_KATEGORI_BIAYA": i, "NAMA_KATEGORI_BIAYA": name, "DESKRIPSI": desc} for i, name, desc in KATEGORI_BIAYA
    ]

    periods = []
    for year in range(config.PERIOD_START_YEAR, config.PERIOD_END_YEAR + 1):
        for month in range(1, 13):
            periods.append(
                {
                    "ID_PERIODE_PELAPORAN": f"PER-{year}{util.pad(month, 2)}",
                    "TAHUN": year,
                    "BULAN": month,
                    "NAMA_PERIODE": f"{util.MONTHS_ID[month - 1]} {year}",
                    "KUARTAL": (month - 1) // 3 + 1,
                    "TANGGAL_MULAI": date(year, month, 1),
                    "TANGGAL_SELESAI": util.month_end(year, month),
                }
            )
    data[f"{SCHEMA}.REFERENSI_PERIODE_PELAPORAN"] = periods

    policy = []
    for klasifikasi_id, by_group in _ACCESS.items():
        for group in _GROUPS:
            policy.append(
                {
                    "ID_KLASIFIKASI_DATA": klasifikasi_id,
                    "KELOMPOK_PENGGUNA": group,
                    "TINGKAT_AKSES": by_group[group],
                    "CATATAN": _ACCESS_NOTES.get((klasifikasi_id, group)),
                }
            )
    data[f"{SCHEMA}.KEBIJAKAN_AKSES_DATA"] = policy

    data[f"{SCHEMA}.MASTER_WILAYAH"] = [
        {
            "ID_WILAYAH": i,
            "NAMA_WILAYAH": name,
            "STATUS_AKTIF": True,
            "TANGGAL_MULAI_BERLAKU": ORGANISATION_START,
            "TANGGAL_AKHIR_BERLAKU": None,
            "KETERANGAN": "Wilayah fiktif untuk simulasi.",
        }
        for i, name in WILAYAH
    ]

    lingkungan = []
    for i, region_id, name, active in LINGKUNGAN:
        if active:
            end, note = None, "Lingkungan fiktif untuk simulasi."
        else:
            end = MERGE_END
            note = f"Digabungkan ke {dict((r[0], r[2]) for r in LINGKUNGAN)[MERGED_INTO]} pada akhir tahun 2024."
        lingkungan.append(
            {
                "ID_LINGKUNGAN": i,
                "ID_WILAYAH": region_id,
                "NAMA_LINGKUNGAN": name,
                "STATUS_AKTIF": active,
                "TANGGAL_MULAI_BERLAKU": ORGANISATION_START,
                "TANGGAL_AKHIR_BERLAKU": end,
                "KETERANGAN": note,
            }
        )
    data[f"{SCHEMA}.MASTER_LINGKUNGAN"] = lingkungan

    data[f"{SCHEMA}.GEOMETRI_ILUSTRATIF_LINGKUNGAN"] = _geometry()
    return data
