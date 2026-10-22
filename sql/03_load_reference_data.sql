-- =============================================================================
-- Step 3: Load reference and master data
--
-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py
-- Content  : 16 tables, 303 rows in schema MASTER_DATA. All data is synthetic
--            (fictional) and reproducible (seed 20260930, snapshot date 2026-09-30).
-- Requires : step 2 (tables)
-- Safe to re-run: yes. Every table is loaded with MERGE on its primary key, so existing
--            rows are updated and new rows are inserted. Nothing is deleted and nothing
--            is duplicated. Statements are ordered parents first.
-- Warehouse: any running warehouse is enough (the data volume is small).
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

-- MASTER_DATA.REFERENSI_KLASIFIKASI_DATA: 4 rows
MERGE INTO MASTER_DATA.REFERENSI_KLASIFIKASI_DATA AS t
USING (
    SELECT
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA,
        v.NAMA_KLASIFIKASI AS NAMA_KLASIFIKASI,
        v.DESKRIPSI AS DESKRIPSI,
        CAST(v.DAPAT_DITAMPILKAN_PUBLIK AS BOOLEAN) AS DAPAT_DITAMPILKAN_PUBLIK,
        CAST(v.URUTAN_TINGKAT AS NUMBER(2,0)) AS URUTAN_TINGKAT
    FROM (VALUES
            ('KLS-01', 'Publik', 'Informasi yang aman dibagikan kepada umum, misalnya jadwal Misa dan daftar wilayah.', TRUE, 1),
            ('KLS-02', 'Internal', 'Informasi untuk pengurus dan seksi paroki, tidak untuk dasbor publik.', FALSE, 2),
            ('KLS-03', 'Terbatas', 'Data pribadi atau sensitif yang hanya boleh diakses petugas berwenang.', FALSE, 3),
            ('KLS-04', 'Sangat Terbatas', 'Data pribadi kelompok rentan, misalnya anak di bawah umur, dengan akses paling ketat.', FALSE, 4)
    ) AS v (ID_KLASIFIKASI_DATA, NAMA_KLASIFIKASI, DESKRIPSI, DAPAT_DITAMPILKAN_PUBLIK, URUTAN_TINGKAT)
) AS s
ON t.ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA
WHEN MATCHED THEN UPDATE SET
    NAMA_KLASIFIKASI = s.NAMA_KLASIFIKASI,
    DESKRIPSI = s.DESKRIPSI,
    DAPAT_DITAMPILKAN_PUBLIK = s.DAPAT_DITAMPILKAN_PUBLIK,
    URUTAN_TINGKAT = s.URUTAN_TINGKAT
WHEN NOT MATCHED THEN INSERT (ID_KLASIFIKASI_DATA, NAMA_KLASIFIKASI, DESKRIPSI, DAPAT_DITAMPILKAN_PUBLIK, URUTAN_TINGKAT)
    VALUES (s.ID_KLASIFIKASI_DATA, s.NAMA_KLASIFIKASI, s.DESKRIPSI, s.DAPAT_DITAMPILKAN_PUBLIK, s.URUTAN_TINGKAT);

-- MASTER_DATA.MASTER_SEKSI: 9 rows
MERGE INTO MASTER_DATA.MASTER_SEKSI AS t
USING (
    SELECT
        v.ID_SEKSI AS ID_SEKSI,
        v.NAMA_SEKSI AS NAMA_SEKSI,
        v.DESKRIPSI AS DESKRIPSI,
        CAST(v.STATUS_AKTIF AS BOOLEAN) AS STATUS_AKTIF,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU
    FROM (VALUES
            ('SEK-01', 'Seksi Liturgi', 'Mengatur perayaan liturgi, petugas liturgi, dan jadwal Misa.', TRUE, '2020-01-01', NULL),
            ('SEK-02', 'Seksi Katekese', 'Menyelenggarakan pembinaan iman bagi anak, remaja, dan dewasa.', TRUE, '2020-01-01', NULL),
            ('SEK-03', 'Seksi Kerasulan Keluarga', 'Mendampingi keluarga, calon pasangan, dan pasangan suami istri.', TRUE, '2020-01-01', NULL),
            ('SEK-04', 'Seksi Kepemudaan', 'Membina orang muda Katolik melalui kegiatan iman, kepemimpinan, dan pelayanan.', TRUE, '2020-01-01', NULL),
            ('SEK-05', 'Seksi Pengembangan Sosial Ekonomi', 'Menjalankan pelayanan sosial dan membantu pemberdayaan ekonomi umat.', TRUE, '2020-01-01', NULL),
            ('SEK-06', 'Seksi Komunikasi Sosial', 'Mengelola informasi, dokumentasi, dan media komunikasi paroki.', TRUE, '2020-01-01', NULL),
            ('SEK-07', 'Seksi Kitab Suci', 'Mengajak umat membaca dan mendalami Kitab Suci.', TRUE, '2020-01-01', NULL),
            ('SEK-08', 'Seksi Pelayanan Kesehatan', 'Menyelenggarakan penyuluhan dan layanan kesehatan bagi umat dan masyarakat sekitar.', TRUE, '2020-01-01', NULL),
            ('SEK-09', 'Seksi Sekretariat dan Keuangan', 'Mengelola administrasi, arsip, data umat, dan pembukuan keuangan paroki.', TRUE, '2020-01-01', NULL)
    ) AS v (ID_SEKSI, NAMA_SEKSI, DESKRIPSI, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
) AS s
ON t.ID_SEKSI = s.ID_SEKSI
WHEN MATCHED THEN UPDATE SET
    NAMA_SEKSI = s.NAMA_SEKSI,
    DESKRIPSI = s.DESKRIPSI,
    STATUS_AKTIF = s.STATUS_AKTIF,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU
WHEN NOT MATCHED THEN INSERT (ID_SEKSI, NAMA_SEKSI, DESKRIPSI, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
    VALUES (s.ID_SEKSI, s.NAMA_SEKSI, s.DESKRIPSI, s.STATUS_AKTIF, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU);

-- MASTER_DATA.REFERENSI_KATEGORI_INFORMASI: 9 rows
MERGE INTO MASTER_DATA.REFERENSI_KATEGORI_INFORMASI AS t
USING (
    SELECT
        v.ID_KATEGORI_INFORMASI AS ID_KATEGORI_INFORMASI,
        v.NAMA_KATEGORI AS NAMA_KATEGORI,
        v.DESKRIPSI AS DESKRIPSI,
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA,
        v.ID_SEKSI_PENGELOLA AS ID_SEKSI_PENGELOLA
    FROM (VALUES
            ('KIN-01', 'Kolekte', 'Ringkasan kolekte per Misa dan jenis kolekte.', 'KLS-02', 'SEK-09'),
            ('KIN-02', 'Kehadiran Misa', 'Jumlah umat yang hadir pada setiap Misa.', 'KLS-02', 'SEK-01'),
            ('KIN-03', 'Data Umat', 'Data umat dan keluarga, termasuk penugasan ke lingkungan.', 'KLS-03', 'SEK-09'),
            ('KIN-04', 'Sumbangan Kesempatan Khusus', 'Sumbangan wilayah pada masa Prapaskah, Adven, dan kesempatan khusus lain.', 'KLS-02', 'SEK-05'),
            ('KIN-05', 'Jadwal Misa', 'Aturan jadwal Misa dan kejadian Misa yang sebenarnya.', 'KLS-01', 'SEK-01'),
            ('KIN-06', 'Survei', 'Definisi survei, pertanyaan, jawaban, dan hasil agregat.', 'KLS-02', 'SEK-06'),
            ('KIN-07', 'Rencana dan Anggaran', 'Rencana kerja tahunan, anggaran, dan realisasi pengeluaran.', 'KLS-02', 'SEK-09'),
            ('KIN-08', 'Kegiatan dan Laporan', 'Kegiatan seksi dan laporan pascakegiatan.', 'KLS-02', 'SEK-09'),
            ('KIN-09', 'Wilayah dan Peta', 'Struktur wilayah dan lingkungan serta geometri ilustratif.', 'KLS-01', 'SEK-09')
    ) AS v (ID_KATEGORI_INFORMASI, NAMA_KATEGORI, DESKRIPSI, ID_KLASIFIKASI_DATA, ID_SEKSI_PENGELOLA)
) AS s
ON t.ID_KATEGORI_INFORMASI = s.ID_KATEGORI_INFORMASI
WHEN MATCHED THEN UPDATE SET
    NAMA_KATEGORI = s.NAMA_KATEGORI,
    DESKRIPSI = s.DESKRIPSI,
    ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA,
    ID_SEKSI_PENGELOLA = s.ID_SEKSI_PENGELOLA
WHEN NOT MATCHED THEN INSERT (ID_KATEGORI_INFORMASI, NAMA_KATEGORI, DESKRIPSI, ID_KLASIFIKASI_DATA, ID_SEKSI_PENGELOLA)
    VALUES (s.ID_KATEGORI_INFORMASI, s.NAMA_KATEGORI, s.DESKRIPSI, s.ID_KLASIFIKASI_DATA, s.ID_SEKSI_PENGELOLA);

-- MASTER_DATA.REFERENSI_DAFTAR_NILAI: 68 rows
MERGE INTO MASTER_DATA.REFERENSI_DAFTAR_NILAI AS t
USING (
    SELECT
        v.KELOMPOK_NILAI AS KELOMPOK_NILAI,
        v.NILAI AS NILAI,
        CAST(v.URUTAN AS NUMBER(3,0)) AS URUTAN,
        v.DESKRIPSI AS DESKRIPSI
    FROM (VALUES
            ('STATUS_VALIDASI', 'Sudah Divalidasi', 1, 'Angka telah diperiksa dan disetujui petugas.'),
            ('STATUS_VALIDASI', 'Menunggu Validasi', 2, 'Angka sudah dicatat tetapi belum diperiksa.'),
            ('STATUS_VALIDASI', 'Perlu Dicek Ulang', 3, 'Angka tampak janggal dan harus diperiksa kembali.'),
            ('STATUS_REKONSILIASI', 'Sudah Cocok', 1, 'Jumlah tercatat sama dengan hasil penghitungan.'),
            ('STATUS_REKONSILIASI', 'Selisih Disetujui', 2, 'Ada selisih kecil yang sudah dijelaskan dan disetujui bendahara.'),
            ('STATUS_REKONSILIASI', 'Selisih Sedang Ditelusuri', 3, 'Ada selisih yang masih ditelusuri bersama petugas.'),
            ('STATUS_REKONSILIASI', 'Belum Dihitung', 4, 'Hasil penghitungan belum tersedia.'),
            ('METODE_PENGHITUNGAN', 'Hitung Manual oleh Petugas', 1, 'Petugas menghitung umat satu per satu.'),
            ('METODE_PENGHITUNGAN', 'Penghitung Klik', 2, 'Petugas memakai alat penghitung klik di pintu masuk.'),
            ('METODE_PENGHITUNGAN', 'Perkiraan Petugas Tata Tertib', 3, 'Perkiraan petugas berdasarkan jumlah baris tempat duduk.'),
            ('STATUS_PELAKSANAAN_MISA', 'Terjadwal', 1, 'Misa belum berlangsung.'),
            ('STATUS_PELAKSANAAN_MISA', 'Terlaksana', 2, 'Misa sudah berlangsung.'),
            ('STATUS_PELAKSANAAN_MISA', 'Dibatalkan', 3, 'Misa dibatalkan dan tidak berlangsung.'),
            ('STATUS_PELAKSANAAN_RENCANA', 'Direncanakan', 1, 'Kegiatan belum dilaksanakan dan masih sesuai rencana.'),
            ('STATUS_PELAKSANAAN_RENCANA', 'Terlaksana', 2, 'Kegiatan sudah dilaksanakan.'),
            ('STATUS_PELAKSANAAN_RENCANA', 'Ditunda', 3, 'Kegiatan ditunda dan belum dilaksanakan.'),
            ('STATUS_PELAKSANAAN_RENCANA', 'Dibatalkan', 4, 'Kegiatan dibatalkan dan tidak akan dilaksanakan.'),
            ('STATUS_KEGIATAN', 'Direncanakan', 1, 'Kegiatan sudah terdaftar tetapi belum berlangsung.'),
            ('STATUS_KEGIATAN', 'Terlaksana', 2, 'Kegiatan sudah berlangsung.'),
            ('STATUS_KEGIATAN', 'Ditunda', 3, 'Kegiatan ditunda dan belum berlangsung.'),
            ('STATUS_KEGIATAN', 'Dibatalkan', 4, 'Kegiatan dibatalkan.'),
            ('STATUS_LAPORAN', 'Final', 1, 'Laporan sudah lengkap dan diserahkan.'),
            ('STATUS_LAPORAN', 'Draf', 2, 'Laporan masih disusun dan belum lengkap.'),
            ('STATUS_LAPORAN', 'Perlu Revisi', 3, 'Laporan dikembalikan untuk diperbaiki.'),
            ('STATUS_PENGESAHAN', 'Disahkan', 1, 'Rencana kerja sudah disahkan pengurus paroki.'),
            ('STATUS_PENGESAHAN', 'Dalam Revisi', 2, 'Rencana kerja sedang direvisi.'),
            ('STATUS_KEANGGOTAAN', 'Aktif', 1, 'Terdaftar dan aktif di paroki.'),
            ('STATUS_KEANGGOTAAN', 'Pindah Paroki', 2, 'Sudah pindah ke paroki lain.'),
            ('STATUS_KEANGGOTAAN', 'Tidak Aktif', 3, 'Terdaftar tetapi sudah lama tidak aktif.'),
            ('STATUS_KEANGGOTAAN', 'Meninggal Dunia', 4, 'Sudah meninggal dunia.'),
            ('STATUS_KELUARGA', 'Aktif', 1, 'Keluarga terdaftar dan aktif di paroki.'),
            ('STATUS_KELUARGA', 'Pindah Paroki', 2, 'Seluruh keluarga sudah pindah ke paroki lain.'),
            ('STATUS_KELUARGA', 'Tidak Aktif', 3, 'Keluarga terdaftar tetapi tidak aktif.'),
            ('STATUS_SURVEI', 'Direncanakan', 1, 'Survei belum dibuka.'),
            ('STATUS_SURVEI', 'Sedang Berjalan', 2, 'Survei sedang dibuka dan menerima jawaban.'),
            ('STATUS_SURVEI', 'Selesai', 3, 'Survei sudah ditutup.'),
            ('JENIS_JAWABAN', 'Skala Likert', 1, 'Responden memilih tingkat kesetujuan dari Sangat Tidak Setuju sampai Sangat Setuju.'),
            ('JENIS_JAWABAN', 'Pilihan Tunggal', 2, 'Responden memilih satu dari beberapa opsi.'),
            ('KELOMPOK_USIA', 'Di bawah 17 tahun', 1, 'Responden berusia di bawah 17 tahun.'),
            ('KELOMPOK_USIA', '17-34 tahun', 2, 'Responden berusia 17 sampai 34 tahun.'),
            ('KELOMPOK_USIA', '35-65 tahun', 3, 'Responden berusia 35 sampai 65 tahun.'),
            ('KELOMPOK_USIA', 'Di atas 65 tahun', 4, 'Responden berusia di atas 65 tahun.'),
            ('JENIS_KELAMIN', 'Laki-laki', 1, 'Jenis kelamin laki-laki.'),
            ('JENIS_KELAMIN', 'Perempuan', 2, 'Jenis kelamin perempuan.'),
            ('PERAN_DALAM_KELUARGA', 'Kepala Keluarga', 1, 'Penanggung jawab keluarga.'),
            ('PERAN_DALAM_KELUARGA', 'Pasangan', 2, 'Suami atau istri kepala keluarga.'),
            ('PERAN_DALAM_KELUARGA', 'Anak', 3, 'Anak dalam keluarga.'),
            ('PERAN_DALAM_KELUARGA', 'Anggota Lain', 4, 'Anggota keluarga lain, misalnya orang tua atau saudara.'),
            ('HARI', 'Senin', 1, 'Hari Senin.'),
            ('HARI', 'Selasa', 2, 'Hari Selasa.'),
            ('HARI', 'Rabu', 3, 'Hari Rabu.'),
            ('HARI', 'Kamis', 4, 'Hari Kamis.'),
            ('HARI', 'Jumat', 5, 'Hari Jumat.'),
            ('HARI', 'Sabtu', 6, 'Hari Sabtu.'),
            ('HARI', 'Minggu', 7, 'Hari Minggu.'),
            ('BAHASA_MISA', 'Bahasa Indonesia', 1, 'Misa dengan bahasa pengantar Bahasa Indonesia.'),
            ('BAHASA_MISA', 'Bahasa Inggris', 2, 'Misa dengan bahasa pengantar Bahasa Inggris.'),
            ('MUSIM_LITURGI', 'Prapaskah', 1, 'Masa persiapan menjelang Paskah.'),
            ('MUSIM_LITURGI', 'Adven', 2, 'Masa persiapan menjelang Natal.'),
            ('MUSIM_LITURGI', 'Tidak Terkait Musim', 3, 'Tidak terkait musim liturgi tertentu.'),
            ('KELOMPOK_PENGGUNA', 'Pastor Paroki dan Pengurus Harian', 1, 'Pimpinan paroki.'),
            ('KELOMPOK_PENGGUNA', 'Ketua Seksi', 2, 'Ketua seksi pelayanan.'),
            ('KELOMPOK_PENGGUNA', 'Ketua Wilayah dan Lingkungan', 3, 'Pengurus wilayah dan lingkungan.'),
            ('KELOMPOK_PENGGUNA', 'Sekretariat dan Keuangan', 4, 'Petugas administrasi, data, dan pembukuan.'),
            ('KELOMPOK_PENGGUNA', 'Dasbor Umum', 5, 'Pengunjung dasbor yang terbuka untuk umum.'),
            ('TINGKAT_AKSES', 'Penuh', 1, 'Boleh melihat rincian data.'),
            ('TINGKAT_AKSES', 'Agregat Saja', 2, 'Hanya boleh melihat ringkasan tanpa rincian pribadi.'),
            ('TINGKAT_AKSES', 'Tidak Ada', 3, 'Tidak boleh mengakses data.')
    ) AS v (KELOMPOK_NILAI, NILAI, URUTAN, DESKRIPSI)
) AS s
ON t.KELOMPOK_NILAI = s.KELOMPOK_NILAI AND t.NILAI = s.NILAI
WHEN MATCHED THEN UPDATE SET
    URUTAN = s.URUTAN,
    DESKRIPSI = s.DESKRIPSI
WHEN NOT MATCHED THEN INSERT (KELOMPOK_NILAI, NILAI, URUTAN, DESKRIPSI)
    VALUES (s.KELOMPOK_NILAI, s.NILAI, s.URUTAN, s.DESKRIPSI);

-- MASTER_DATA.REFERENSI_JENIS_KOLEKTE: 3 rows
MERGE INTO MASTER_DATA.REFERENSI_JENIS_KOLEKTE AS t
USING (
    SELECT
        v.ID_JENIS_KOLEKTE AS ID_JENIS_KOLEKTE,
        v.NAMA_JENIS_KOLEKTE AS NAMA_JENIS_KOLEKTE,
        v.DESKRIPSI AS DESKRIPSI
    FROM (VALUES
            ('KOL-01', 'Kolekte Pertama', 'Kolekte rutin untuk kebutuhan operasional paroki.'),
            ('KOL-02', 'Kolekte Kedua', 'Kolekte rutin untuk pelayanan sosial dan pemeliharaan fasilitas.'),
            ('KOL-03', 'Kolekte Khusus', 'Kolekte untuk tujuan khusus pada hari tertentu, misalnya Hari Minggu Panggilan.')
    ) AS v (ID_JENIS_KOLEKTE, NAMA_JENIS_KOLEKTE, DESKRIPSI)
) AS s
ON t.ID_JENIS_KOLEKTE = s.ID_JENIS_KOLEKTE
WHEN MATCHED THEN UPDATE SET
    NAMA_JENIS_KOLEKTE = s.NAMA_JENIS_KOLEKTE,
    DESKRIPSI = s.DESKRIPSI
WHEN NOT MATCHED THEN INSERT (ID_JENIS_KOLEKTE, NAMA_JENIS_KOLEKTE, DESKRIPSI)
    VALUES (s.ID_JENIS_KOLEKTE, s.NAMA_JENIS_KOLEKTE, s.DESKRIPSI);

-- MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS: 3 rows
MERGE INTO MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS AS t
USING (
    SELECT
        v.ID_KESEMPATAN AS ID_KESEMPATAN,
        v.NAMA_KESEMPATAN AS NAMA_KESEMPATAN,
        v.MUSIM_LITURGI AS MUSIM_LITURGI,
        v.DESKRIPSI AS DESKRIPSI
    FROM (VALUES
            ('KSK-01', 'Aksi Puasa Pembangunan', 'Prapaskah', 'Gerakan sumbangan selama masa Prapaskah untuk pelayanan sosial.'),
            ('KSK-02', 'Aksi Adven Peduli Sesama', 'Adven', 'Gerakan sumbangan selama masa Adven untuk keluarga yang membutuhkan.'),
            ('KSK-03', 'Dana Solidaritas Kemanusiaan', 'Tidak Terkait Musim', 'Penggalangan dana tanggap darurat untuk korban bencana.')
    ) AS v (ID_KESEMPATAN, NAMA_KESEMPATAN, MUSIM_LITURGI, DESKRIPSI)
) AS s
ON t.ID_KESEMPATAN = s.ID_KESEMPATAN
WHEN MATCHED THEN UPDATE SET
    NAMA_KESEMPATAN = s.NAMA_KESEMPATAN,
    MUSIM_LITURGI = s.MUSIM_LITURGI,
    DESKRIPSI = s.DESKRIPSI
WHEN NOT MATCHED THEN INSERT (ID_KESEMPATAN, NAMA_KESEMPATAN, MUSIM_LITURGI, DESKRIPSI)
    VALUES (s.ID_KESEMPATAN, s.NAMA_KESEMPATAN, s.MUSIM_LITURGI, s.DESKRIPSI);

-- MASTER_DATA.REFERENSI_KATEGORI_BIAYA: 7 rows
MERGE INTO MASTER_DATA.REFERENSI_KATEGORI_BIAYA AS t
USING (
    SELECT
        v.ID_KATEGORI_BIAYA AS ID_KATEGORI_BIAYA,
        v.NAMA_KATEGORI_BIAYA AS NAMA_KATEGORI_BIAYA,
        v.DESKRIPSI AS DESKRIPSI
    FROM (VALUES
            ('KBY-01', 'Konsumsi', 'Makanan dan minuman peserta atau panitia.'),
            ('KBY-02', 'Perlengkapan dan Bahan', 'Alat tulis, bahan latihan, dekorasi, dan perlengkapan kegiatan.'),
            ('KBY-03', 'Transportasi dan Akomodasi', 'Biaya perjalanan, penginapan, dan sewa kendaraan.'),
            ('KBY-04', 'Honorarium dan Narasumber', 'Uang saku narasumber, pembimbing, dan petugas.'),
            ('KBY-05', 'Publikasi dan Dokumentasi', 'Cetak pengumuman, spanduk, foto, dan video.'),
            ('KBY-06', 'Sewa Sarana dan Perawatan', 'Sewa tempat dan alat, serta perawatan perlengkapan.'),
            ('KBY-07', 'Bantuan dan Santunan Sosial', 'Bantuan berupa uang atau barang kepada penerima manfaat.')
    ) AS v (ID_KATEGORI_BIAYA, NAMA_KATEGORI_BIAYA, DESKRIPSI)
) AS s
ON t.ID_KATEGORI_BIAYA = s.ID_KATEGORI_BIAYA
WHEN MATCHED THEN UPDATE SET
    NAMA_KATEGORI_BIAYA = s.NAMA_KATEGORI_BIAYA,
    DESKRIPSI = s.DESKRIPSI
WHEN NOT MATCHED THEN INSERT (ID_KATEGORI_BIAYA, NAMA_KATEGORI_BIAYA, DESKRIPSI)
    VALUES (s.ID_KATEGORI_BIAYA, s.NAMA_KATEGORI_BIAYA, s.DESKRIPSI);

-- MASTER_DATA.REFERENSI_PERIODE_PELAPORAN: 24 rows
MERGE INTO MASTER_DATA.REFERENSI_PERIODE_PELAPORAN AS t
USING (
    SELECT
        v.ID_PERIODE_PELAPORAN AS ID_PERIODE_PELAPORAN,
        CAST(v.TAHUN AS NUMBER(4,0)) AS TAHUN,
        CAST(v.BULAN AS NUMBER(2,0)) AS BULAN,
        v.NAMA_PERIODE AS NAMA_PERIODE,
        CAST(v.KUARTAL AS NUMBER(1,0)) AS KUARTAL,
        CAST(v.TANGGAL_MULAI AS DATE) AS TANGGAL_MULAI,
        CAST(v.TANGGAL_SELESAI AS DATE) AS TANGGAL_SELESAI
    FROM (VALUES
            ('PER-202501', 2025, 1, 'Januari 2025', 1, '2025-01-01', '2025-01-31'),
            ('PER-202502', 2025, 2, 'Februari 2025', 1, '2025-02-01', '2025-02-28'),
            ('PER-202503', 2025, 3, 'Maret 2025', 1, '2025-03-01', '2025-03-31'),
            ('PER-202504', 2025, 4, 'April 2025', 2, '2025-04-01', '2025-04-30'),
            ('PER-202505', 2025, 5, 'Mei 2025', 2, '2025-05-01', '2025-05-31'),
            ('PER-202506', 2025, 6, 'Juni 2025', 2, '2025-06-01', '2025-06-30'),
            ('PER-202507', 2025, 7, 'Juli 2025', 3, '2025-07-01', '2025-07-31'),
            ('PER-202508', 2025, 8, 'Agustus 2025', 3, '2025-08-01', '2025-08-31'),
            ('PER-202509', 2025, 9, 'September 2025', 3, '2025-09-01', '2025-09-30'),
            ('PER-202510', 2025, 10, 'Oktober 2025', 4, '2025-10-01', '2025-10-31'),
            ('PER-202511', 2025, 11, 'November 2025', 4, '2025-11-01', '2025-11-30'),
            ('PER-202512', 2025, 12, 'Desember 2025', 4, '2025-12-01', '2025-12-31'),
            ('PER-202601', 2026, 1, 'Januari 2026', 1, '2026-01-01', '2026-01-31'),
            ('PER-202602', 2026, 2, 'Februari 2026', 1, '2026-02-01', '2026-02-28'),
            ('PER-202603', 2026, 3, 'Maret 2026', 1, '2026-03-01', '2026-03-31'),
            ('PER-202604', 2026, 4, 'April 2026', 2, '2026-04-01', '2026-04-30'),
            ('PER-202605', 2026, 5, 'Mei 2026', 2, '2026-05-01', '2026-05-31'),
            ('PER-202606', 2026, 6, 'Juni 2026', 2, '2026-06-01', '2026-06-30'),
            ('PER-202607', 2026, 7, 'Juli 2026', 3, '2026-07-01', '2026-07-31'),
            ('PER-202608', 2026, 8, 'Agustus 2026', 3, '2026-08-01', '2026-08-31'),
            ('PER-202609', 2026, 9, 'September 2026', 3, '2026-09-01', '2026-09-30'),
            ('PER-202610', 2026, 10, 'Oktober 2026', 4, '2026-10-01', '2026-10-31'),
            ('PER-202611', 2026, 11, 'November 2026', 4, '2026-11-01', '2026-11-30'),
            ('PER-202612', 2026, 12, 'Desember 2026', 4, '2026-12-01', '2026-12-31')
    ) AS v (ID_PERIODE_PELAPORAN, TAHUN, BULAN, NAMA_PERIODE, KUARTAL, TANGGAL_MULAI, TANGGAL_SELESAI)
) AS s
ON t.ID_PERIODE_PELAPORAN = s.ID_PERIODE_PELAPORAN
WHEN MATCHED THEN UPDATE SET
    TAHUN = s.TAHUN,
    BULAN = s.BULAN,
    NAMA_PERIODE = s.NAMA_PERIODE,
    KUARTAL = s.KUARTAL,
    TANGGAL_MULAI = s.TANGGAL_MULAI,
    TANGGAL_SELESAI = s.TANGGAL_SELESAI
WHEN NOT MATCHED THEN INSERT (ID_PERIODE_PELAPORAN, TAHUN, BULAN, NAMA_PERIODE, KUARTAL, TANGGAL_MULAI, TANGGAL_SELESAI)
    VALUES (s.ID_PERIODE_PELAPORAN, s.TAHUN, s.BULAN, s.NAMA_PERIODE, s.KUARTAL, s.TANGGAL_MULAI, s.TANGGAL_SELESAI);

-- MASTER_DATA.KEBIJAKAN_AKSES_DATA: 20 rows
MERGE INTO MASTER_DATA.KEBIJAKAN_AKSES_DATA AS t
USING (
    SELECT
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA,
        v.KELOMPOK_PENGGUNA AS KELOMPOK_PENGGUNA,
        v.TINGKAT_AKSES AS TINGKAT_AKSES,
        v.CATATAN AS CATATAN
    FROM (VALUES
            ('KLS-01', 'Pastor Paroki dan Pengurus Harian', 'Penuh', NULL),
            ('KLS-01', 'Ketua Seksi', 'Penuh', NULL),
            ('KLS-01', 'Ketua Wilayah dan Lingkungan', 'Penuh', NULL),
            ('KLS-01', 'Sekretariat dan Keuangan', 'Penuh', NULL),
            ('KLS-01', 'Dasbor Umum', 'Penuh', NULL),
            ('KLS-02', 'Pastor Paroki dan Pengurus Harian', 'Penuh', NULL),
            ('KLS-02', 'Ketua Seksi', 'Penuh', NULL),
            ('KLS-02', 'Ketua Wilayah dan Lingkungan', 'Agregat Saja', 'Hanya ringkasan untuk wilayah yang dipimpin.'),
            ('KLS-02', 'Sekretariat dan Keuangan', 'Penuh', NULL),
            ('KLS-02', 'Dasbor Umum', 'Tidak Ada', NULL),
            ('KLS-03', 'Pastor Paroki dan Pengurus Harian', 'Penuh', NULL),
            ('KLS-03', 'Ketua Seksi', 'Agregat Saja', NULL),
            ('KLS-03', 'Ketua Wilayah dan Lingkungan', 'Penuh', 'Hanya untuk lingkungan dan wilayah yang dipimpin.'),
            ('KLS-03', 'Sekretariat dan Keuangan', 'Penuh', 'Hanya sesuai tugas pengelolaan data.'),
            ('KLS-03', 'Dasbor Umum', 'Tidak Ada', NULL),
            ('KLS-04', 'Pastor Paroki dan Pengurus Harian', 'Penuh', NULL),
            ('KLS-04', 'Ketua Seksi', 'Tidak Ada', NULL),
            ('KLS-04', 'Ketua Wilayah dan Lingkungan', 'Agregat Saja', NULL),
            ('KLS-04', 'Sekretariat dan Keuangan', 'Penuh', 'Hanya sesuai tugas pengelolaan data dan dengan pencatatan akses.'),
            ('KLS-04', 'Dasbor Umum', 'Tidak Ada', NULL)
    ) AS v (ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA, TINGKAT_AKSES, CATATAN)
) AS s
ON t.ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA AND t.KELOMPOK_PENGGUNA = s.KELOMPOK_PENGGUNA
WHEN MATCHED THEN UPDATE SET
    TINGKAT_AKSES = s.TINGKAT_AKSES,
    CATATAN = s.CATATAN
WHEN NOT MATCHED THEN INSERT (ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA, TINGKAT_AKSES, CATATAN)
    VALUES (s.ID_KLASIFIKASI_DATA, s.KELOMPOK_PENGGUNA, s.TINGKAT_AKSES, s.CATATAN);

-- MASTER_DATA.MASTER_WILAYAH: 6 rows
MERGE INTO MASTER_DATA.MASTER_WILAYAH AS t
USING (
    SELECT
        v.ID_WILAYAH AS ID_WILAYAH,
        v.NAMA_WILAYAH AS NAMA_WILAYAH,
        CAST(v.STATUS_AKTIF AS BOOLEAN) AS STATUS_AKTIF,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('WIL-01', 'Wilayah Santo Yosef', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.'),
            ('WIL-02', 'Wilayah Santa Maria', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.'),
            ('WIL-03', 'Wilayah Santo Petrus', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.'),
            ('WIL-04', 'Wilayah Santo Paulus', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.'),
            ('WIL-05', 'Wilayah Santa Theresia', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.'),
            ('WIL-06', 'Wilayah Santo Fransiskus', TRUE, '2020-01-01', NULL, 'Wilayah fiktif untuk simulasi.')
    ) AS v (ID_WILAYAH, NAMA_WILAYAH, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
) AS s
ON t.ID_WILAYAH = s.ID_WILAYAH
WHEN MATCHED THEN UPDATE SET
    NAMA_WILAYAH = s.NAMA_WILAYAH,
    STATUS_AKTIF = s.STATUS_AKTIF,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_WILAYAH, NAMA_WILAYAH, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
    VALUES (s.ID_WILAYAH, s.NAMA_WILAYAH, s.STATUS_AKTIF, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU, s.KETERANGAN);

-- MASTER_DATA.MASTER_LINGKUNGAN: 19 rows
MERGE INTO MASTER_DATA.MASTER_LINGKUNGAN AS t
USING (
    SELECT
        v.ID_LINGKUNGAN AS ID_LINGKUNGAN,
        v.ID_WILAYAH AS ID_WILAYAH,
        v.NAMA_LINGKUNGAN AS NAMA_LINGKUNGAN,
        CAST(v.STATUS_AKTIF AS BOOLEAN) AS STATUS_AKTIF,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('LNG-01', 'WIL-01', 'Lingkungan Santo Antonius', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-02', 'WIL-01', 'Lingkungan Santa Agnes', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-03', 'WIL-01', 'Lingkungan Santo Benediktus', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-04', 'WIL-02', 'Lingkungan Santa Cecilia', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-05', 'WIL-02', 'Lingkungan Santo Dominikus', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-06', 'WIL-02', 'Lingkungan Santa Elisabet', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-07', 'WIL-03', 'Lingkungan Santo Gregorius', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-08', 'WIL-03', 'Lingkungan Santa Helena', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-09', 'WIL-03', 'Lingkungan Santo Ignasius', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-10', 'WIL-04', 'Lingkungan Santa Katarina', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-11', 'WIL-04', 'Lingkungan Santo Lukas', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-12', 'WIL-04', 'Lingkungan Santa Margareta', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-13', 'WIL-05', 'Lingkungan Santo Nikolas', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-14', 'WIL-05', 'Lingkungan Santa Monika', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-15', 'WIL-05', 'Lingkungan Santo Stefanus', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-16', 'WIL-06', 'Lingkungan Santa Veronika', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-17', 'WIL-06', 'Lingkungan Santo Markus', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-18', 'WIL-06', 'Lingkungan Santa Klara', TRUE, '2020-01-01', NULL, 'Lingkungan fiktif untuk simulasi.'),
            ('LNG-19', 'WIL-01', 'Lingkungan Santo Yudas', FALSE, '2020-01-01', '2024-12-31', 'Digabungkan ke Lingkungan Santo Benediktus pada akhir tahun 2024.')
    ) AS v (ID_LINGKUNGAN, ID_WILAYAH, NAMA_LINGKUNGAN, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
) AS s
ON t.ID_LINGKUNGAN = s.ID_LINGKUNGAN
WHEN MATCHED THEN UPDATE SET
    ID_WILAYAH = s.ID_WILAYAH,
    NAMA_LINGKUNGAN = s.NAMA_LINGKUNGAN,
    STATUS_AKTIF = s.STATUS_AKTIF,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_LINGKUNGAN, ID_WILAYAH, NAMA_LINGKUNGAN, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
    VALUES (s.ID_LINGKUNGAN, s.ID_WILAYAH, s.NAMA_LINGKUNGAN, s.STATUS_AKTIF, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU, s.KETERANGAN);

-- MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN: 18 rows
MERGE INTO MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN AS t
USING (
    SELECT
        v.ID_GEOMETRI AS ID_GEOMETRI,
        v.ID_LINGKUNGAN AS ID_LINGKUNGAN,
        v.GEOJSON AS GEOJSON,
        v.JENIS_GEOMETRI AS JENIS_GEOMETRI,
        CAST(v.BERSIFAT_SINTETIS AS BOOLEAN) AS BERSIFAT_SINTETIS,
        v.CATATAN AS CATATAN
    FROM (VALUES
            ('GEO-01', 'LNG-01', '{"type":"Polygon","coordinates":[[[0.000,0.000],[0.010,0.000],[0.010,0.030],[0.000,0.030],[0.000,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-02', 'LNG-02', '{"type":"Polygon","coordinates":[[[0.010,0.000],[0.020,0.000],[0.020,0.030],[0.010,0.030],[0.010,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-03', 'LNG-03', '{"type":"Polygon","coordinates":[[[0.020,0.000],[0.030,0.000],[0.030,0.030],[0.020,0.030],[0.020,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-04', 'LNG-04', '{"type":"Polygon","coordinates":[[[0.030,0.000],[0.040,0.000],[0.040,0.030],[0.030,0.030],[0.030,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-05', 'LNG-05', '{"type":"Polygon","coordinates":[[[0.040,0.000],[0.050,0.000],[0.050,0.030],[0.040,0.030],[0.040,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-06', 'LNG-06', '{"type":"Polygon","coordinates":[[[0.050,0.000],[0.060,0.000],[0.060,0.030],[0.050,0.030],[0.050,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-07', 'LNG-07', '{"type":"Polygon","coordinates":[[[0.060,0.000],[0.070,0.000],[0.070,0.030],[0.060,0.030],[0.060,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-08', 'LNG-08', '{"type":"Polygon","coordinates":[[[0.070,0.000],[0.080,0.000],[0.080,0.030],[0.070,0.030],[0.070,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-09', 'LNG-09', '{"type":"Polygon","coordinates":[[[0.080,0.000],[0.090,0.000],[0.090,0.030],[0.080,0.030],[0.080,0.000]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-10', 'LNG-10', '{"type":"Polygon","coordinates":[[[0.000,0.030],[0.010,0.030],[0.010,0.060],[0.000,0.060],[0.000,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-11', 'LNG-11', '{"type":"Polygon","coordinates":[[[0.010,0.030],[0.020,0.030],[0.020,0.060],[0.010,0.060],[0.010,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-12', 'LNG-12', '{"type":"Polygon","coordinates":[[[0.020,0.030],[0.030,0.030],[0.030,0.060],[0.020,0.060],[0.020,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-13', 'LNG-13', '{"type":"Polygon","coordinates":[[[0.030,0.030],[0.040,0.030],[0.040,0.060],[0.030,0.060],[0.030,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-14', 'LNG-14', '{"type":"Polygon","coordinates":[[[0.040,0.030],[0.050,0.030],[0.050,0.060],[0.040,0.060],[0.040,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-15', 'LNG-15', '{"type":"Polygon","coordinates":[[[0.050,0.030],[0.060,0.030],[0.060,0.060],[0.050,0.060],[0.050,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-16', 'LNG-16', '{"type":"Polygon","coordinates":[[[0.060,0.030],[0.070,0.030],[0.070,0.060],[0.060,0.060],[0.060,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-17', 'LNG-17', '{"type":"Polygon","coordinates":[[[0.070,0.030],[0.080,0.030],[0.080,0.060],[0.070,0.060],[0.070,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.'),
            ('GEO-18', 'LNG-18', '{"type":"Polygon","coordinates":[[[0.080,0.030],[0.090,0.030],[0.090,0.060],[0.080,0.060],[0.080,0.030]]]}', 'Polygon', TRUE, 'Geometri sintetis untuk ilustrasi, bukan batas wilayah resmi paroki.')
    ) AS v (ID_GEOMETRI, ID_LINGKUNGAN, GEOJSON, JENIS_GEOMETRI, BERSIFAT_SINTETIS, CATATAN)
) AS s
ON t.ID_GEOMETRI = s.ID_GEOMETRI
WHEN MATCHED THEN UPDATE SET
    ID_LINGKUNGAN = s.ID_LINGKUNGAN,
    GEOJSON = s.GEOJSON,
    JENIS_GEOMETRI = s.JENIS_GEOMETRI,
    BERSIFAT_SINTETIS = s.BERSIFAT_SINTETIS,
    CATATAN = s.CATATAN
WHEN NOT MATCHED THEN INSERT (ID_GEOMETRI, ID_LINGKUNGAN, GEOJSON, JENIS_GEOMETRI, BERSIFAT_SINTETIS, CATATAN)
    VALUES (s.ID_GEOMETRI, s.ID_LINGKUNGAN, s.GEOJSON, s.JENIS_GEOMETRI, s.BERSIFAT_SINTETIS, s.CATATAN);

-- MASTER_DATA.JADWAL_MISA: 7 rows
MERGE INTO MASTER_DATA.JADWAL_MISA AS t
USING (
    SELECT
        v.ID_JADWAL_MISA AS ID_JADWAL_MISA,
        v.NAMA_MISA AS NAMA_MISA,
        v.HARI AS HARI,
        CAST(v.WAKTU_MULAI AS TIME) AS WAKTU_MULAI,
        CAST(v.WAKTU_SELESAI AS TIME) AS WAKTU_SELESAI,
        v.LOKASI AS LOKASI,
        v.BAHASA_MISA AS BAHASA_MISA,
        CAST(v.STATUS_AKTIF AS BOOLEAN) AS STATUS_AKTIF,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('JDW-01', 'Misa Sabtu Sore', 'Sabtu', '17:00:00', '18:15:00', 'Gereja Santa Maria Contoh', 'Bahasa Indonesia', FALSE, '2018-01-01', '2026-06-30', 'Digantikan oleh jadwal pukul 17.30 mulai 1 Juli 2026.'),
            ('JDW-02', 'Misa Sabtu Sore', 'Sabtu', '17:30:00', '18:45:00', 'Gereja Santa Maria Contoh', 'Bahasa Indonesia', TRUE, '2026-07-01', NULL, 'Menggantikan jadwal pukul 17.00.'),
            ('JDW-03', 'Misa Minggu Pagi I', 'Minggu', '06:00:00', '07:15:00', 'Gereja Santa Maria Contoh', 'Bahasa Indonesia', TRUE, '2018-01-01', NULL, NULL),
            ('JDW-04', 'Misa Minggu Pagi II', 'Minggu', '08:00:00', '09:15:00', 'Gereja Santa Maria Contoh', 'Bahasa Indonesia', TRUE, '2018-01-01', NULL, 'Misa keluarga dengan petugas anak-anak.'),
            ('JDW-05', 'Misa Minggu Bahasa Inggris', 'Minggu', '10:30:00', '11:30:00', 'Gereja Santa Maria Contoh', 'Bahasa Inggris', TRUE, '2022-03-06', NULL, NULL),
            ('JDW-06', 'Misa Minggu Sore', 'Minggu', '17:30:00', '18:45:00', 'Gereja Santa Maria Contoh', 'Bahasa Indonesia', TRUE, '2018-01-01', NULL, NULL),
            ('JDW-07', 'Misa Harian Rabu', 'Rabu', '05:30:00', '06:15:00', 'Kapel Santo Petrus Contoh', 'Bahasa Indonesia', TRUE, '2018-01-01', NULL, NULL)
    ) AS v (ID_JADWAL_MISA, NAMA_MISA, HARI, WAKTU_MULAI, WAKTU_SELESAI, LOKASI, BAHASA_MISA, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
) AS s
ON t.ID_JADWAL_MISA = s.ID_JADWAL_MISA
WHEN MATCHED THEN UPDATE SET
    NAMA_MISA = s.NAMA_MISA,
    HARI = s.HARI,
    WAKTU_MULAI = s.WAKTU_MULAI,
    WAKTU_SELESAI = s.WAKTU_SELESAI,
    LOKASI = s.LOKASI,
    BAHASA_MISA = s.BAHASA_MISA,
    STATUS_AKTIF = s.STATUS_AKTIF,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_JADWAL_MISA, NAMA_MISA, HARI, WAKTU_MULAI, WAKTU_SELESAI, LOKASI, BAHASA_MISA, STATUS_AKTIF, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU, KETERANGAN)
    VALUES (s.ID_JADWAL_MISA, s.NAMA_MISA, s.HARI, s.WAKTU_MULAI, s.WAKTU_SELESAI, s.LOKASI, s.BAHASA_MISA, s.STATUS_AKTIF, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU, s.KETERANGAN);

-- MASTER_DATA.SURVEI: 4 rows
MERGE INTO MASTER_DATA.SURVEI AS t
USING (
    SELECT
        v.ID_SURVEI AS ID_SURVEI,
        v.JUDUL_SURVEI AS JUDUL_SURVEI,
        v.TUJUAN_SURVEI AS TUJUAN_SURVEI,
        CAST(v.TANGGAL_MULAI AS DATE) AS TANGGAL_MULAI,
        CAST(v.TANGGAL_SELESAI AS DATE) AS TANGGAL_SELESAI,
        v.STATUS_SURVEI AS STATUS_SURVEI,
        v.ID_SEKSI AS ID_SEKSI,
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA
    FROM (VALUES
            ('SRV-01', 'Survei Kepuasan Pelayanan Liturgi 2026', 'Mengetahui kepuasan umat terhadap pelayanan liturgi agar seksi dapat memperbaiki tata suara, jadwal, dan pelayanan petugas.', '2026-05-01', '2026-05-31', 'Selesai', 'SEK-01', 'KLS-02'),
            ('SRV-02', 'Survei Kebutuhan Pembinaan Iman 2026', 'Mengetahui bentuk, waktu, dan topik pembinaan iman yang paling dibutuhkan umat sebagai dasar rencana katekese tahun berikutnya.', '2026-06-15', '2026-07-15', 'Selesai', 'SEK-02', 'KLS-02'),
            ('SRV-03', 'Survei Kepedulian Sosial dan Kebutuhan Lingkungan 2026', 'Memetakan kebutuhan bantuan sosial di lingkungan dan kesediaan umat terlibat sebagai dasar program pelayanan sosial.', '2026-08-17', '2026-10-15', 'Sedang Berjalan', 'SEK-05', 'KLS-02'),
            ('SRV-04', 'Survei Minat Kegiatan Orang Muda 2027', 'Menjajaki minat orang muda terhadap jenis dan waktu kegiatan untuk rencana kerja tahun 2027.', '2026-11-01', '2026-11-30', 'Direncanakan', 'SEK-04', 'KLS-02')
    ) AS v (ID_SURVEI, JUDUL_SURVEI, TUJUAN_SURVEI, TANGGAL_MULAI, TANGGAL_SELESAI, STATUS_SURVEI, ID_SEKSI, ID_KLASIFIKASI_DATA)
) AS s
ON t.ID_SURVEI = s.ID_SURVEI
WHEN MATCHED THEN UPDATE SET
    JUDUL_SURVEI = s.JUDUL_SURVEI,
    TUJUAN_SURVEI = s.TUJUAN_SURVEI,
    TANGGAL_MULAI = s.TANGGAL_MULAI,
    TANGGAL_SELESAI = s.TANGGAL_SELESAI,
    STATUS_SURVEI = s.STATUS_SURVEI,
    ID_SEKSI = s.ID_SEKSI,
    ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA
WHEN NOT MATCHED THEN INSERT (ID_SURVEI, JUDUL_SURVEI, TUJUAN_SURVEI, TANGGAL_MULAI, TANGGAL_SELESAI, STATUS_SURVEI, ID_SEKSI, ID_KLASIFIKASI_DATA)
    VALUES (s.ID_SURVEI, s.JUDUL_SURVEI, s.TUJUAN_SURVEI, s.TANGGAL_MULAI, s.TANGGAL_SELESAI, s.STATUS_SURVEI, s.ID_SEKSI, s.ID_KLASIFIKASI_DATA);

-- MASTER_DATA.PERTANYAAN_SURVEI: 17 rows
MERGE INTO MASTER_DATA.PERTANYAAN_SURVEI AS t
USING (
    SELECT
        v.ID_PERTANYAAN AS ID_PERTANYAAN,
        v.ID_SURVEI AS ID_SURVEI,
        CAST(v.NOMOR_URUT AS NUMBER(3,0)) AS NOMOR_URUT,
        v.TEKS_PERTANYAAN AS TEKS_PERTANYAAN,
        v.JENIS_JAWABAN AS JENIS_JAWABAN
    FROM (VALUES
            ('PRT-0101', 'SRV-01', 1, 'Tata suara di gereja membuat bacaan dan homili terdengar jelas.', 'Skala Likert'),
            ('PRT-0102', 'SRV-01', 2, 'Homili mudah dipahami dan berkaitan dengan kehidupan sehari-hari.', 'Skala Likert'),
            ('PRT-0103', 'SRV-01', 3, 'Nyanyian dan musik membantu saya berdoa dengan khusyuk.', 'Skala Likert'),
            ('PRT-0104', 'SRV-01', 4, 'Jadwal Misa mingguan sesuai dengan kebutuhan keluarga saya.', 'Skala Likert'),
            ('PRT-0105', 'SRV-01', 5, 'Petugas tata tertib dan penyambut umat bersikap ramah dan membantu.', 'Skala Likert'),
            ('PRT-0106', 'SRV-01', 6, 'Jadwal Misa mana yang paling sering Anda ikuti?', 'Pilihan Tunggal'),
            ('PRT-0201', 'SRV-02', 1, 'Bentuk pembinaan iman apa yang paling Anda butuhkan saat ini?', 'Pilihan Tunggal'),
            ('PRT-0202', 'SRV-02', 2, 'Kapan waktu yang paling memungkinkan bagi Anda?', 'Pilihan Tunggal'),
            ('PRT-0203', 'SRV-02', 3, 'Topik apa yang paling ingin Anda dalami?', 'Pilihan Tunggal'),
            ('PRT-0204', 'SRV-02', 4, 'Saya merasa terbantu oleh kegiatan pembinaan iman yang sudah ada di paroki.', 'Skala Likert'),
            ('PRT-0205', 'SRV-02', 5, 'Informasi tentang kegiatan pembinaan iman mudah saya temukan.', 'Skala Likert'),
            ('PRT-0301', 'SRV-03', 1, 'Saya mengetahui program bantuan sosial yang dikelola paroki.', 'Skala Likert'),
            ('PRT-0302', 'SRV-03', 2, 'Bentuk bantuan sosial apa yang paling dibutuhkan di lingkungan Anda?', 'Pilihan Tunggal'),
            ('PRT-0303', 'SRV-03', 3, 'Saya bersedia terlibat sebagai relawan dalam kegiatan sosial paroki.', 'Skala Likert'),
            ('PRT-0304', 'SRV-03', 4, 'Cara berpartisipasi apa yang paling sesuai bagi Anda?', 'Pilihan Tunggal'),
            ('PRT-0401', 'SRV-04', 1, 'Jenis kegiatan orang muda apa yang paling Anda minati?', 'Pilihan Tunggal'),
            ('PRT-0402', 'SRV-04', 2, 'Kapan waktu kegiatan yang paling cocok bagi Anda?', 'Pilihan Tunggal')
    ) AS v (ID_PERTANYAAN, ID_SURVEI, NOMOR_URUT, TEKS_PERTANYAAN, JENIS_JAWABAN)
) AS s
ON t.ID_PERTANYAAN = s.ID_PERTANYAAN
WHEN MATCHED THEN UPDATE SET
    ID_SURVEI = s.ID_SURVEI,
    NOMOR_URUT = s.NOMOR_URUT,
    TEKS_PERTANYAAN = s.TEKS_PERTANYAAN,
    JENIS_JAWABAN = s.JENIS_JAWABAN
WHEN NOT MATCHED THEN INSERT (ID_PERTANYAAN, ID_SURVEI, NOMOR_URUT, TEKS_PERTANYAAN, JENIS_JAWABAN)
    VALUES (s.ID_PERTANYAAN, s.ID_SURVEI, s.NOMOR_URUT, s.TEKS_PERTANYAAN, s.JENIS_JAWABAN);

-- MASTER_DATA.OPSI_JAWABAN_SURVEI: 85 rows
MERGE INTO MASTER_DATA.OPSI_JAWABAN_SURVEI AS t
USING (
    SELECT
        v.ID_OPSI AS ID_OPSI,
        v.ID_PERTANYAAN AS ID_PERTANYAAN,
        CAST(v.NOMOR_URUT AS NUMBER(3,0)) AS NOMOR_URUT,
        v.KATEGORI_JAWABAN AS KATEGORI_JAWABAN,
        CAST(v.NILAI_SKOR AS NUMBER(2,0)) AS NILAI_SKOR
    FROM (VALUES
            ('OPS-010101', 'PRT-0101', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-010102', 'PRT-0101', 2, 'Tidak Setuju', 2),
            ('OPS-010103', 'PRT-0101', 3, 'Netral', 3),
            ('OPS-010104', 'PRT-0101', 4, 'Setuju', 4),
            ('OPS-010105', 'PRT-0101', 5, 'Sangat Setuju', 5),
            ('OPS-010201', 'PRT-0102', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-010202', 'PRT-0102', 2, 'Tidak Setuju', 2),
            ('OPS-010203', 'PRT-0102', 3, 'Netral', 3),
            ('OPS-010204', 'PRT-0102', 4, 'Setuju', 4),
            ('OPS-010205', 'PRT-0102', 5, 'Sangat Setuju', 5),
            ('OPS-010301', 'PRT-0103', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-010302', 'PRT-0103', 2, 'Tidak Setuju', 2),
            ('OPS-010303', 'PRT-0103', 3, 'Netral', 3),
            ('OPS-010304', 'PRT-0103', 4, 'Setuju', 4),
            ('OPS-010305', 'PRT-0103', 5, 'Sangat Setuju', 5),
            ('OPS-010401', 'PRT-0104', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-010402', 'PRT-0104', 2, 'Tidak Setuju', 2),
            ('OPS-010403', 'PRT-0104', 3, 'Netral', 3),
            ('OPS-010404', 'PRT-0104', 4, 'Setuju', 4),
            ('OPS-010405', 'PRT-0104', 5, 'Sangat Setuju', 5),
            ('OPS-010501', 'PRT-0105', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-010502', 'PRT-0105', 2, 'Tidak Setuju', 2),
            ('OPS-010503', 'PRT-0105', 3, 'Netral', 3),
            ('OPS-010504', 'PRT-0105', 4, 'Setuju', 4),
            ('OPS-010505', 'PRT-0105', 5, 'Sangat Setuju', 5),
            ('OPS-010601', 'PRT-0106', 1, 'Misa Sabtu Sore', NULL),
            ('OPS-010602', 'PRT-0106', 2, 'Misa Minggu Pagi I', NULL),
            ('OPS-010603', 'PRT-0106', 3, 'Misa Minggu Pagi II', NULL),
            ('OPS-010604', 'PRT-0106', 4, 'Misa Minggu Bahasa Inggris', NULL),
            ('OPS-010605', 'PRT-0106', 5, 'Misa Minggu Sore', NULL),
            ('OPS-010606', 'PRT-0106', 6, 'Misa Harian', NULL),
            ('OPS-020101', 'PRT-0201', 1, 'Katekese tatap muka di paroki', NULL),
            ('OPS-020102', 'PRT-0201', 2, 'Pendalaman iman di lingkungan', NULL),
            ('OPS-020103', 'PRT-0201', 3, 'Kelas daring', NULL),
            ('OPS-020104', 'PRT-0201', 4, 'Retret dan rekoleksi', NULL),
            ('OPS-020105', 'PRT-0201', 5, 'Belum membutuhkan', NULL),
            ('OPS-020201', 'PRT-0202', 1, 'Hari kerja malam', NULL),
            ('OPS-020202', 'PRT-0202', 2, 'Sabtu pagi', NULL),
            ('OPS-020203', 'PRT-0202', 3, 'Sabtu sore', NULL),
            ('OPS-020204', 'PRT-0202', 4, 'Minggu setelah Misa', NULL),
            ('OPS-020205', 'PRT-0202', 5, 'Tidak ada waktu tertentu', NULL),
            ('OPS-020301', 'PRT-0203', 1, 'Kitab Suci', NULL),
            ('OPS-020302', 'PRT-0203', 2, 'Liturgi dan sakramen', NULL),
            ('OPS-020303', 'PRT-0203', 3, 'Hidup berkeluarga', NULL),
            ('OPS-020304', 'PRT-0203', 4, 'Pendampingan anak dan remaja', NULL),
            ('OPS-020305', 'PRT-0203', 5, 'Iman dan dunia kerja', NULL),
            ('OPS-020401', 'PRT-0204', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-020402', 'PRT-0204', 2, 'Tidak Setuju', 2),
            ('OPS-020403', 'PRT-0204', 3, 'Netral', 3),
            ('OPS-020404', 'PRT-0204', 4, 'Setuju', 4),
            ('OPS-020405', 'PRT-0204', 5, 'Sangat Setuju', 5),
            ('OPS-020501', 'PRT-0205', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-020502', 'PRT-0205', 2, 'Tidak Setuju', 2),
            ('OPS-020503', 'PRT-0205', 3, 'Netral', 3),
            ('OPS-020504', 'PRT-0205', 4, 'Setuju', 4),
            ('OPS-020505', 'PRT-0205', 5, 'Sangat Setuju', 5),
            ('OPS-030101', 'PRT-0301', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-030102', 'PRT-0301', 2, 'Tidak Setuju', 2),
            ('OPS-030103', 'PRT-0301', 3, 'Netral', 3),
            ('OPS-030104', 'PRT-0301', 4, 'Setuju', 4),
            ('OPS-030105', 'PRT-0301', 5, 'Sangat Setuju', 5),
            ('OPS-030201', 'PRT-0302', 1, 'Bantuan pendidikan anak', NULL),
            ('OPS-030202', 'PRT-0302', 2, 'Bantuan kesehatan dan pengobatan', NULL),
            ('OPS-030203', 'PRT-0302', 3, 'Pelatihan keterampilan dan usaha', NULL),
            ('OPS-030204', 'PRT-0302', 4, 'Kunjungan dan pendampingan lansia', NULL),
            ('OPS-030205', 'PRT-0302', 5, 'Bantuan darurat bencana', NULL),
            ('OPS-030301', 'PRT-0303', 1, 'Sangat Tidak Setuju', 1),
            ('OPS-030302', 'PRT-0303', 2, 'Tidak Setuju', 2),
            ('OPS-030303', 'PRT-0303', 3, 'Netral', 3),
            ('OPS-030304', 'PRT-0303', 4, 'Setuju', 4),
            ('OPS-030305', 'PRT-0303', 5, 'Sangat Setuju', 5),
            ('OPS-030401', 'PRT-0304', 1, 'Donasi dana', NULL),
            ('OPS-030402', 'PRT-0304', 2, 'Donasi barang', NULL),
            ('OPS-030403', 'PRT-0304', 3, 'Tenaga sebagai relawan', NULL),
            ('OPS-030404', 'PRT-0304', 4, 'Keahlian profesional', NULL),
            ('OPS-030405', 'PRT-0304', 5, 'Doa dan dukungan moral', NULL),
            ('OPS-040101', 'PRT-0401', 1, 'Retret dan rekoleksi', NULL),
            ('OPS-040102', 'PRT-0401', 2, 'Olahraga dan turnamen', NULL),
            ('OPS-040103', 'PRT-0401', 3, 'Musik dan paduan suara', NULL),
            ('OPS-040104', 'PRT-0401', 4, 'Pelayanan sosial', NULL),
            ('OPS-040105', 'PRT-0401', 5, 'Pelatihan keterampilan', NULL),
            ('OPS-040201', 'PRT-0402', 1, 'Sabtu sore', NULL),
            ('OPS-040202', 'PRT-0402', 2, 'Sabtu malam', NULL),
            ('OPS-040203', 'PRT-0402', 3, 'Minggu sore', NULL),
            ('OPS-040204', 'PRT-0402', 4, 'Hari libur nasional', NULL)
    ) AS v (ID_OPSI, ID_PERTANYAAN, NOMOR_URUT, KATEGORI_JAWABAN, NILAI_SKOR)
) AS s
ON t.ID_OPSI = s.ID_OPSI
WHEN MATCHED THEN UPDATE SET
    ID_PERTANYAAN = s.ID_PERTANYAAN,
    NOMOR_URUT = s.NOMOR_URUT,
    KATEGORI_JAWABAN = s.KATEGORI_JAWABAN,
    NILAI_SKOR = s.NILAI_SKOR
WHEN NOT MATCHED THEN INSERT (ID_OPSI, ID_PERTANYAAN, NOMOR_URUT, KATEGORI_JAWABAN, NILAI_SKOR)
    VALUES (s.ID_OPSI, s.ID_PERTANYAAN, s.NOMOR_URUT, s.KATEGORI_JAWABAN, s.NILAI_SKOR);
