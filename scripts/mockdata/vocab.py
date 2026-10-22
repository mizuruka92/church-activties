"""Controlled vocabularies stored in MASTER_DATA.REFERENSI_DAFTAR_NILAI.

Tables store the Indonesian label itself (for example 'Sudah Divalidasi'), so
dashboards need no join. The vocabulary table lists every allowed label, and the
validation script checks that each table only uses allowed labels.
"""

# group -> list of (value, description)
DAFTAR_NILAI = {
    "STATUS_VALIDASI": [
        ("Sudah Divalidasi", "Angka telah diperiksa dan disetujui petugas."),
        ("Menunggu Validasi", "Angka sudah dicatat tetapi belum diperiksa."),
        ("Perlu Dicek Ulang", "Angka tampak janggal dan harus diperiksa kembali."),
    ],
    "STATUS_REKONSILIASI": [
        ("Sudah Cocok", "Jumlah tercatat sama dengan hasil penghitungan."),
        ("Selisih Disetujui", "Ada selisih kecil yang sudah dijelaskan dan disetujui bendahara."),
        ("Selisih Sedang Ditelusuri", "Ada selisih yang masih ditelusuri bersama petugas."),
        ("Belum Dihitung", "Hasil penghitungan belum tersedia."),
    ],
    "METODE_PENGHITUNGAN": [
        ("Hitung Manual oleh Petugas", "Petugas menghitung umat satu per satu."),
        ("Penghitung Klik", "Petugas memakai alat penghitung klik di pintu masuk."),
        ("Perkiraan Petugas Tata Tertib", "Perkiraan petugas berdasarkan jumlah baris tempat duduk."),
    ],
    "STATUS_PELAKSANAAN_MISA": [
        ("Terjadwal", "Misa belum berlangsung."),
        ("Terlaksana", "Misa sudah berlangsung."),
        ("Dibatalkan", "Misa dibatalkan dan tidak berlangsung."),
    ],
    "STATUS_PELAKSANAAN_RENCANA": [
        ("Direncanakan", "Kegiatan belum dilaksanakan dan masih sesuai rencana."),
        ("Terlaksana", "Kegiatan sudah dilaksanakan."),
        ("Ditunda", "Kegiatan ditunda dan belum dilaksanakan."),
        ("Dibatalkan", "Kegiatan dibatalkan dan tidak akan dilaksanakan."),
    ],
    "STATUS_KEGIATAN": [
        ("Direncanakan", "Kegiatan sudah terdaftar tetapi belum berlangsung."),
        ("Terlaksana", "Kegiatan sudah berlangsung."),
        ("Ditunda", "Kegiatan ditunda dan belum berlangsung."),
        ("Dibatalkan", "Kegiatan dibatalkan."),
    ],
    "STATUS_LAPORAN": [
        ("Final", "Laporan sudah lengkap dan diserahkan."),
        ("Draf", "Laporan masih disusun dan belum lengkap."),
        ("Perlu Revisi", "Laporan dikembalikan untuk diperbaiki."),
    ],
    "STATUS_PENGESAHAN": [
        ("Disahkan", "Rencana kerja sudah disahkan pengurus paroki."),
        ("Dalam Revisi", "Rencana kerja sedang direvisi."),
    ],
    "STATUS_KEANGGOTAAN": [
        ("Aktif", "Terdaftar dan aktif di paroki."),
        ("Pindah Paroki", "Sudah pindah ke paroki lain."),
        ("Tidak Aktif", "Terdaftar tetapi sudah lama tidak aktif."),
        ("Meninggal Dunia", "Sudah meninggal dunia."),
    ],
    "STATUS_KELUARGA": [
        ("Aktif", "Keluarga terdaftar dan aktif di paroki."),
        ("Pindah Paroki", "Seluruh keluarga sudah pindah ke paroki lain."),
        ("Tidak Aktif", "Keluarga terdaftar tetapi tidak aktif."),
    ],
    "STATUS_SURVEI": [
        ("Direncanakan", "Survei belum dibuka."),
        ("Sedang Berjalan", "Survei sedang dibuka dan menerima jawaban."),
        ("Selesai", "Survei sudah ditutup."),
    ],
    "JENIS_JAWABAN": [
        ("Skala Likert", "Responden memilih tingkat kesetujuan dari Sangat Tidak Setuju sampai Sangat Setuju."),
        ("Pilihan Tunggal", "Responden memilih satu dari beberapa opsi."),
    ],
    "KELOMPOK_USIA": [
        ("Di bawah 17 tahun", "Responden berusia di bawah 17 tahun."),
        ("17-34 tahun", "Responden berusia 17 sampai 34 tahun."),
        ("35-65 tahun", "Responden berusia 35 sampai 65 tahun."),
        ("Di atas 65 tahun", "Responden berusia di atas 65 tahun."),
    ],
    "JENIS_KELAMIN": [
        ("Laki-laki", "Jenis kelamin laki-laki."),
        ("Perempuan", "Jenis kelamin perempuan."),
    ],
    "PERAN_DALAM_KELUARGA": [
        ("Kepala Keluarga", "Penanggung jawab keluarga."),
        ("Pasangan", "Suami atau istri kepala keluarga."),
        ("Anak", "Anak dalam keluarga."),
        ("Anggota Lain", "Anggota keluarga lain, misalnya orang tua atau saudara."),
    ],
    "HARI": [
        ("Senin", "Hari Senin."),
        ("Selasa", "Hari Selasa."),
        ("Rabu", "Hari Rabu."),
        ("Kamis", "Hari Kamis."),
        ("Jumat", "Hari Jumat."),
        ("Sabtu", "Hari Sabtu."),
        ("Minggu", "Hari Minggu."),
    ],
    "BAHASA_MISA": [
        ("Bahasa Indonesia", "Misa dengan bahasa pengantar Bahasa Indonesia."),
        ("Bahasa Inggris", "Misa dengan bahasa pengantar Bahasa Inggris."),
    ],
    "MUSIM_LITURGI": [
        ("Prapaskah", "Masa persiapan menjelang Paskah."),
        ("Adven", "Masa persiapan menjelang Natal."),
        ("Tidak Terkait Musim", "Tidak terkait musim liturgi tertentu."),
    ],
    "KELOMPOK_PENGGUNA": [
        ("Pastor Paroki dan Pengurus Harian", "Pimpinan paroki."),
        ("Ketua Seksi", "Ketua seksi pelayanan."),
        ("Ketua Wilayah dan Lingkungan", "Pengurus wilayah dan lingkungan."),
        ("Sekretariat dan Keuangan", "Petugas administrasi, data, dan pembukuan."),
        ("Dasbor Umum", "Pengunjung dasbor yang terbuka untuk umum."),
    ],
    "TINGKAT_AKSES": [
        ("Penuh", "Boleh melihat rincian data."),
        ("Agregat Saja", "Hanya boleh melihat ringkasan tanpa rincian pribadi."),
        ("Tidak Ada", "Tidak boleh mengakses data."),
    ],
}

# (table, column, vocabulary group). Used by the validation script and the
# data dictionary.
NILAI_TERKENDALI = [
    ("MASTER_DATA.JADWAL_MISA", "HARI", "HARI"),
    ("MASTER_DATA.JADWAL_MISA", "BAHASA_MISA", "BAHASA_MISA"),
    ("MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS", "MUSIM_LITURGI", "MUSIM_LITURGI"),
    ("MASTER_DATA.KEBIJAKAN_AKSES_DATA", "KELOMPOK_PENGGUNA", "KELOMPOK_PENGGUNA"),
    ("MASTER_DATA.KEBIJAKAN_AKSES_DATA", "TINGKAT_AKSES", "TINGKAT_AKSES"),
    ("MASTER_DATA.SURVEI", "STATUS_SURVEI", "STATUS_SURVEI"),
    ("MASTER_DATA.PERTANYAAN_SURVEI", "JENIS_JAWABAN", "JENIS_JAWABAN"),
    ("DATA_OPERASIONAL.KEJADIAN_MISA", "STATUS_PELAKSANAAN", "STATUS_PELAKSANAAN_MISA"),
    ("DATA_OPERASIONAL.KEHADIRAN_MISA", "METODE_PENGHITUNGAN", "METODE_PENGHITUNGAN"),
    ("DATA_OPERASIONAL.KEHADIRAN_MISA", "STATUS_VALIDASI", "STATUS_VALIDASI"),
    ("DATA_OPERASIONAL.PENERIMAAN_KOLEKTE", "STATUS_REKONSILIASI", "STATUS_REKONSILIASI"),
    ("DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS", "STATUS_VALIDASI", "STATUS_VALIDASI"),
    ("DATA_OPERASIONAL.KELUARGA", "STATUS_KELUARGA", "STATUS_KELUARGA"),
    ("DATA_OPERASIONAL.UMAT", "JENIS_KELAMIN", "JENIS_KELAMIN"),
    ("DATA_OPERASIONAL.UMAT", "STATUS_KEANGGOTAAN", "STATUS_KEANGGOTAAN"),
    ("DATA_OPERASIONAL.PENUGASAN_KELUARGA", "PERAN_DALAM_KELUARGA", "PERAN_DALAM_KELUARGA"),
    ("DATA_OPERASIONAL.RESPONDEN_SURVEI", "KELOMPOK_USIA", "KELOMPOK_USIA"),
    ("DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN", "STATUS_PENGESAHAN", "STATUS_PENGESAHAN"),
    ("DATA_OPERASIONAL.RENCANA_KEGIATAN", "STATUS_PELAKSANAAN", "STATUS_PELAKSANAAN_RENCANA"),
    ("DATA_OPERASIONAL.KEGIATAN", "STATUS_KEGIATAN", "STATUS_KEGIATAN"),
    ("DATA_OPERASIONAL.LAPORAN_KEGIATAN", "STATUS_LAPORAN", "STATUS_LAPORAN"),
]


def allowed(group):
    """Plain list of allowed labels of a group."""
    return [value for value, _ in DAFTAR_NILAI[group]]
