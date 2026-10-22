-- =============================================================================
-- Step 2: Create all tables (DDL)
--
-- Creates : every table of the schemas MASTER_DATA and DATA_OPERASIONAL.
-- Requires: step 1 (database and schemas).
-- Safe to re-run: yes (CREATE TABLE IF NOT EXISTS). Existing tables are NOT
--           altered: a changed definition needs a manual ALTER or a reset.
--
-- Conventions
--   * PRIMARY KEY / UNIQUE / FOREIGN KEY are declared for documentation and for
--     BI tools. Snowflake does NOT enforce them on standard tables (only NOT NULL
--     is enforced), so sql/06_validate_data.sql checks duplicates and orphans.
--   * Tables are ordered parents-first so that every FOREIGN KEY can resolve.
--   * Money is NUMBER(18,0) in Indonesian rupiah (no decimals). Never text.
--   * COMMENT texts are Bahasa Indonesia business metadata. The table COMMENT has
--     three parts separated by " | ": description, grain, data classification.
--     scripts/generate_mock_data.py turns these comments into
--     docs/DATA_DICTIONARY.md, so keep the format and avoid quotes/semicolons.
--   * One column per line: the generator parses this file.
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

-- =============================================================================
-- MASTER_DATA : reference and master data
-- =============================================================================

CREATE TABLE IF NOT EXISTS MASTER_DATA.INFO_DATASET (
    ID_DATASET VARCHAR(30) NOT NULL COMMENT 'Pengenal dataset (contoh: DS-01)',
    NAMA_DATASET VARCHAR(150) NOT NULL COMMENT 'Nama dataset demo',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Penjelasan singkat isi dataset',
    BERSIFAT_SIMULASI BOOLEAN NOT NULL COMMENT 'TRUE jika seluruh data adalah data simulasi (fiktif)',
    TANGGAL_MULAI_RIWAYAT DATE NOT NULL COMMENT 'Tanggal pertama yang dicakup oleh data riwayat',
    TANGGAL_SNAPSHOT DATE NOT NULL COMMENT 'Tanggal acuan data: catatan setelah tanggal ini adalah jadwal atau rencana, bukan kejadian',
    CONSTRAINT PK_INFO_DATASET PRIMARY KEY (ID_DATASET)
) COMMENT = 'Keterangan dataset demo, termasuk tanggal acuan yang dipakai view untuk membedakan tahun lengkap dari tahun berjalan | Granularitas: satu baris untuk seluruh dataset | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Pengenal tingkat klasifikasi data (contoh: KLS-01)',
    NAMA_KLASIFIKASI VARCHAR(50) NOT NULL COMMENT 'Nama tingkat klasifikasi: Publik, Internal, Terbatas, Sangat Terbatas',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Arti tingkat klasifikasi dan siapa yang boleh melihatnya',
    DAPAT_DITAMPILKAN_PUBLIK BOOLEAN NOT NULL COMMENT 'TRUE jika data dengan klasifikasi ini boleh tampil di dasbor publik',
    URUTAN_TINGKAT NUMBER(2,0) NOT NULL COMMENT 'Urutan tingkat kerahasiaan: 1 paling terbuka, 4 paling ketat',
    CONSTRAINT PK_REFERENSI_KLASIFIKASI_DATA PRIMARY KEY (ID_KLASIFIKASI_DATA)
) COMMENT = 'Daftar tingkat klasifikasi data untuk tata kelola akses | Granularitas: satu baris per tingkat klasifikasi | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.MASTER_SEKSI (
    ID_SEKSI VARCHAR(30) NOT NULL COMMENT 'Pengenal seksi paroki (contoh: SEK-01)',
    NAMA_SEKSI VARCHAR(100) NOT NULL COMMENT 'Nama seksi atau bidang pelayanan paroki',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Ringkasan tugas pelayanan seksi',
    STATUS_AKTIF BOOLEAN NOT NULL COMMENT 'TRUE jika seksi masih aktif',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal seksi mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal seksi berhenti berlaku, kosong jika masih berlaku',
    CONSTRAINT PK_MASTER_SEKSI PRIMARY KEY (ID_SEKSI)
) COMMENT = 'Daftar seksi (bidang pelayanan) paroki | Granularitas: satu baris per seksi | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_KATEGORI_INFORMASI (
    ID_KATEGORI_INFORMASI VARCHAR(30) NOT NULL COMMENT 'Pengenal kategori informasi (contoh: KIN-01)',
    NAMA_KATEGORI VARCHAR(100) NOT NULL COMMENT 'Nama kategori informasi, sejalan dengan sembilan domain data',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Isi kategori informasi',
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi bawaan untuk data dalam kategori ini',
    ID_SEKSI_PENGELOLA VARCHAR(30) NOT NULL COMMENT 'Seksi yang bertanggung jawab atas data dalam kategori ini',
    CONSTRAINT PK_REFERENSI_KATEGORI_INFORMASI PRIMARY KEY (ID_KATEGORI_INFORMASI),
    CONSTRAINT FK_KATEGORI_INFORMASI_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA),
    CONSTRAINT FK_KATEGORI_INFORMASI_SEKSI FOREIGN KEY (ID_SEKSI_PENGELOLA) REFERENCES MASTER_DATA.MASTER_SEKSI (ID_SEKSI)
) COMMENT = 'Kategori informasi paroki beserta klasifikasi bawaan dan seksi pengelola | Granularitas: satu baris per kategori informasi | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_DAFTAR_NILAI (
    KELOMPOK_NILAI VARCHAR(50) NOT NULL COMMENT 'Nama kelompok daftar nilai (contoh: STATUS_VALIDASI)',
    NILAI VARCHAR(100) NOT NULL COMMENT 'Nilai yang diizinkan dalam kelompok tersebut, persis seperti tersimpan di tabel data',
    URUTAN NUMBER(3,0) NOT NULL COMMENT 'Urutan tampil nilai dalam kelompok',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Arti nilai bagi pengguna bisnis',
    CONSTRAINT PK_REFERENSI_DAFTAR_NILAI PRIMARY KEY (KELOMPOK_NILAI, NILAI)
) COMMENT = 'Daftar nilai terkendali: status, jenis jawaban, peran, hari, dan sejenisnya | Granularitas: satu baris per kelompok dan nilai | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_JENIS_KOLEKTE (
    ID_JENIS_KOLEKTE VARCHAR(30) NOT NULL COMMENT 'Pengenal jenis kolekte (contoh: KOL-01)',
    NAMA_JENIS_KOLEKTE VARCHAR(100) NOT NULL COMMENT 'Nama jenis kolekte',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Peruntukan jenis kolekte',
    CONSTRAINT PK_REFERENSI_JENIS_KOLEKTE PRIMARY KEY (ID_JENIS_KOLEKTE)
) COMMENT = 'Jenis kolekte yang dicatat pada setiap Misa | Granularitas: satu baris per jenis kolekte | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS (
    ID_KESEMPATAN VARCHAR(30) NOT NULL COMMENT 'Pengenal kesempatan khusus (contoh: KSK-01)',
    NAMA_KESEMPATAN VARCHAR(150) NOT NULL COMMENT 'Nama kesempatan atau gerakan sumbangan, misalnya masa Prapaskah atau Adven',
    MUSIM_LITURGI VARCHAR(50) NOT NULL COMMENT 'Musim liturgi terkait: Prapaskah, Adven, atau Tidak Terkait Musim',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Tujuan gerakan sumbangan',
    CONSTRAINT PK_REFERENSI_KESEMPATAN_KHUSUS PRIMARY KEY (ID_KESEMPATAN)
) COMMENT = 'Jenis kesempatan khusus untuk gerakan sumbangan | Granularitas: satu baris per kesempatan khusus | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_KATEGORI_BIAYA (
    ID_KATEGORI_BIAYA VARCHAR(30) NOT NULL COMMENT 'Pengenal kategori biaya (contoh: KBY-01)',
    NAMA_KATEGORI_BIAYA VARCHAR(100) NOT NULL COMMENT 'Nama kategori biaya anggaran',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Contoh pengeluaran dalam kategori ini',
    CONSTRAINT PK_REFERENSI_KATEGORI_BIAYA PRIMARY KEY (ID_KATEGORI_BIAYA)
) COMMENT = 'Kategori biaya untuk alokasi anggaran dan realisasi pengeluaran | Granularitas: satu baris per kategori biaya | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_PERIODE_PELAPORAN (
    ID_PERIODE_PELAPORAN VARCHAR(30) NOT NULL COMMENT 'Pengenal periode pelaporan bulanan (contoh: PER-202604)',
    TAHUN NUMBER(4,0) NOT NULL COMMENT 'Tahun kalender periode',
    BULAN NUMBER(2,0) NOT NULL COMMENT 'Nomor bulan dalam tahun, 1 sampai 12',
    NAMA_PERIODE VARCHAR(50) NOT NULL COMMENT 'Nama periode untuk tampilan, misalnya April 2026',
    KUARTAL NUMBER(1,0) NOT NULL COMMENT 'Nomor kuartal kalender, 1 sampai 4',
    TANGGAL_MULAI DATE NOT NULL COMMENT 'Tanggal pertama periode',
    TANGGAL_SELESAI DATE NOT NULL COMMENT 'Tanggal terakhir periode',
    CONSTRAINT PK_REFERENSI_PERIODE_PELAPORAN PRIMARY KEY (ID_PERIODE_PELAPORAN)
) COMMENT = 'Kalender periode pelaporan bulanan | Granularitas: satu baris per bulan kalender | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.KEBIJAKAN_AKSES_DATA (
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi data yang diatur',
    KELOMPOK_PENGGUNA VARCHAR(100) NOT NULL COMMENT 'Kelompok pengguna yang diatur aksesnya',
    TINGKAT_AKSES VARCHAR(50) NOT NULL COMMENT 'Tingkat akses: Penuh, Agregat Saja, atau Tidak Ada',
    CATATAN VARCHAR(500) COMMENT 'Penjelasan atau syarat tambahan akses',
    CONSTRAINT PK_KEBIJAKAN_AKSES_DATA PRIMARY KEY (ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA),
    CONSTRAINT FK_KEBIJAKAN_AKSES_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA)
) COMMENT = 'Matriks contoh kebijakan akses data menurut klasifikasi dan kelompok pengguna (simulasi, bukan kebijakan resmi) | Granularitas: satu baris per klasifikasi dan kelompok pengguna | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.MASTER_WILAYAH (
    ID_WILAYAH VARCHAR(30) NOT NULL COMMENT 'Pengenal wilayah (contoh: WIL-01)',
    NAMA_WILAYAH VARCHAR(100) NOT NULL COMMENT 'Nama wilayah, kelompok beberapa lingkungan',
    STATUS_AKTIF BOOLEAN NOT NULL COMMENT 'TRUE jika wilayah masih aktif',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal wilayah mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal wilayah berhenti berlaku, kosong jika masih berlaku',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan',
    CONSTRAINT PK_MASTER_WILAYAH PRIMARY KEY (ID_WILAYAH)
) COMMENT = 'Daftar wilayah paroki (fiktif) | Granularitas: satu baris per wilayah | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.MASTER_LINGKUNGAN (
    ID_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Pengenal lingkungan (contoh: LNG-01)',
    ID_WILAYAH VARCHAR(30) NOT NULL COMMENT 'Wilayah tempat lingkungan bernaung',
    NAMA_LINGKUNGAN VARCHAR(100) NOT NULL COMMENT 'Nama lingkungan, komunitas basis umat',
    STATUS_AKTIF BOOLEAN NOT NULL COMMENT 'TRUE jika lingkungan masih aktif',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal lingkungan mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal lingkungan berhenti berlaku, kosong jika masih berlaku',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan, misalnya penggabungan lingkungan',
    CONSTRAINT PK_MASTER_LINGKUNGAN PRIMARY KEY (ID_LINGKUNGAN),
    CONSTRAINT FK_MASTER_LINGKUNGAN_WILAYAH FOREIGN KEY (ID_WILAYAH) REFERENCES MASTER_DATA.MASTER_WILAYAH (ID_WILAYAH)
) COMMENT = 'Daftar lingkungan (fiktif) beserta wilayah induknya | Granularitas: satu baris per lingkungan | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN (
    ID_PROFIL VARCHAR(30) NOT NULL COMMENT 'Pengenal profil ekonomi (contoh: PEK-01)',
    ID_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Lingkungan yang dinilai',
    TAHUN_PENILAIAN NUMBER(4,0) NOT NULL COMMENT 'Tahun penilaian profil',
    KATEGORI_EKONOMI VARCHAR(50) NOT NULL COMMENT 'Kapasitas ekonomi umum lingkungan: Rendah, Menengah Bawah, Menengah Atas, atau Tinggi',
    INDEKS_KAPASITAS_EKONOMI NUMBER(4,2) NOT NULL COMMENT 'Indeks kapasitas ekonomi relatif terhadap rata-rata paroki, 1.00 berarti rata-rata',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan penilaian',
    CONSTRAINT PK_PROFIL_EKONOMI_LINGKUNGAN PRIMARY KEY (ID_PROFIL),
    CONSTRAINT UQ_PROFIL_EKONOMI_LINGKUNGAN UNIQUE (ID_LINGKUNGAN),
    CONSTRAINT FK_PROFIL_EKONOMI_LINGKUNGAN FOREIGN KEY (ID_LINGKUNGAN) REFERENCES MASTER_DATA.MASTER_LINGKUNGAN (ID_LINGKUNGAN)
) COMMENT = 'Gambaran kapasitas ekonomi umum setiap lingkungan (simulasi, hanya tingkat lingkungan, tidak ada data ekonomi rumah tangga). Menjelaskan konteks, bukan menilai kemurahan hati atau iman | Granularitas: satu baris per lingkungan | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN (
    ID_GEOMETRI VARCHAR(30) NOT NULL COMMENT 'Pengenal geometri (contoh: GEO-01)',
    ID_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Lingkungan yang digambarkan',
    GEOJSON VARCHAR(4000) NOT NULL COMMENT 'Poligon berformat GeoJSON, bersifat ilustratif dan sintetis',
    JENIS_GEOMETRI VARCHAR(30) NOT NULL COMMENT 'Jenis geometri GeoJSON, saat ini hanya Polygon',
    BERSIFAT_SINTETIS BOOLEAN NOT NULL COMMENT 'TRUE jika geometri dibuat sintetis dan bukan batas resmi',
    CATATAN VARCHAR(500) NOT NULL COMMENT 'Peringatan penggunaan geometri',
    CONSTRAINT PK_GEOMETRI_ILUSTRATIF_LINGKUNGAN PRIMARY KEY (ID_GEOMETRI),
    CONSTRAINT UQ_GEOMETRI_LINGKUNGAN UNIQUE (ID_LINGKUNGAN),
    CONSTRAINT FK_GEOMETRI_LINGKUNGAN FOREIGN KEY (ID_LINGKUNGAN) REFERENCES MASTER_DATA.MASTER_LINGKUNGAN (ID_LINGKUNGAN)
) COMMENT = 'Poligon ilustratif sintetis untuk lingkungan, sengaja diletakkan di koordinat 0 derajat Lintang dan 0 derajat Bujur agar tidak dikira batas wilayah nyata | Granularitas: satu baris per lingkungan aktif | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.JADWAL_MISA (
    ID_JADWAL_MISA VARCHAR(30) NOT NULL COMMENT 'Pengenal aturan jadwal Misa berulang (contoh: JDW-01)',
    NAMA_MISA VARCHAR(100) NOT NULL COMMENT 'Nama sesi Misa yang dikenal umat, dipakai untuk pengelompokan laporan',
    HARI VARCHAR(20) NOT NULL COMMENT 'Hari pelaksanaan mingguan: Senin sampai Minggu',
    WAKTU_MULAI TIME NOT NULL COMMENT 'Jam mulai menurut jadwal (bukan waktu aktual)',
    WAKTU_SELESAI TIME NOT NULL COMMENT 'Jam selesai menurut jadwal (bukan waktu aktual)',
    LOKASI VARCHAR(150) NOT NULL COMMENT 'Tempat pelaksanaan Misa',
    BAHASA_MISA VARCHAR(50) NOT NULL COMMENT 'Bahasa pengantar Misa',
    STATUS_AKTIF BOOLEAN NOT NULL COMMENT 'TRUE jika aturan jadwal masih dipakai',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal aturan jadwal mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal aturan jadwal berhenti berlaku, kosong jika masih berlaku',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan, misalnya penggantian jadwal',
    CONSTRAINT PK_JADWAL_MISA PRIMARY KEY (ID_JADWAL_MISA)
) COMMENT = 'Aturan jadwal Misa berulang (mingguan) | Granularitas: satu baris per aturan jadwal, dengan masa berlaku | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.SURVEI (
    ID_SURVEI VARCHAR(30) NOT NULL COMMENT 'Pengenal survei (contoh: SRV-01)',
    JUDUL_SURVEI VARCHAR(200) NOT NULL COMMENT 'Judul survei',
    TUJUAN_SURVEI VARCHAR(500) NOT NULL COMMENT 'Tujuan survei dan keputusan yang ingin dibantu',
    TANGGAL_MULAI DATE NOT NULL COMMENT 'Tanggal survei mulai dibuka',
    TANGGAL_SELESAI DATE NOT NULL COMMENT 'Tanggal survei ditutup',
    STATUS_SURVEI VARCHAR(50) NOT NULL COMMENT 'Status survei: Direncanakan, Sedang Berjalan, atau Selesai',
    ID_SEKSI VARCHAR(30) NOT NULL COMMENT 'Seksi penanggung jawab survei',
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi data survei',
    CONSTRAINT PK_SURVEI PRIMARY KEY (ID_SURVEI),
    CONSTRAINT FK_SURVEI_SEKSI FOREIGN KEY (ID_SEKSI) REFERENCES MASTER_DATA.MASTER_SEKSI (ID_SEKSI),
    CONSTRAINT FK_SURVEI_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA)
) COMMENT = 'Definisi survei umat | Granularitas: satu baris per survei | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.PERTANYAAN_SURVEI (
    ID_PERTANYAAN VARCHAR(30) NOT NULL COMMENT 'Pengenal pertanyaan (contoh: PRT-0101)',
    ID_SURVEI VARCHAR(30) NOT NULL COMMENT 'Survei tempat pertanyaan berada',
    NOMOR_URUT NUMBER(3,0) NOT NULL COMMENT 'Nomor urut pertanyaan dalam survei',
    TEKS_PERTANYAAN VARCHAR(500) NOT NULL COMMENT 'Teks pertanyaan atau pernyataan yang ditampilkan kepada responden',
    JENIS_JAWABAN VARCHAR(50) NOT NULL COMMENT 'Jenis jawaban: Skala Likert atau Pilihan Tunggal',
    CONSTRAINT PK_PERTANYAAN_SURVEI PRIMARY KEY (ID_PERTANYAAN),
    CONSTRAINT UQ_PERTANYAAN_SURVEI_URUT UNIQUE (ID_SURVEI, NOMOR_URUT),
    CONSTRAINT FK_PERTANYAAN_SURVEI FOREIGN KEY (ID_SURVEI) REFERENCES MASTER_DATA.SURVEI (ID_SURVEI)
) COMMENT = 'Pertanyaan dalam survei | Granularitas: satu baris per pertanyaan | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.OPSI_JAWABAN_SURVEI (
    ID_OPSI VARCHAR(30) NOT NULL COMMENT 'Pengenal opsi jawaban (contoh: OPS-010101)',
    ID_PERTANYAAN VARCHAR(30) NOT NULL COMMENT 'Pertanyaan pemilik opsi',
    NOMOR_URUT NUMBER(3,0) NOT NULL COMMENT 'Nomor urut opsi dalam pertanyaan',
    KATEGORI_JAWABAN VARCHAR(150) NOT NULL COMMENT 'Teks kategori jawaban, misalnya Setuju atau Sabtu pagi',
    NILAI_SKOR NUMBER(2,0) COMMENT 'Skor 1 sampai 5 untuk skala Likert, kosong untuk pilihan tunggal',
    CONSTRAINT PK_OPSI_JAWABAN_SURVEI PRIMARY KEY (ID_OPSI),
    CONSTRAINT UQ_OPSI_JAWABAN_URUT UNIQUE (ID_PERTANYAAN, NOMOR_URUT),
    CONSTRAINT FK_OPSI_JAWABAN_PERTANYAAN FOREIGN KEY (ID_PERTANYAAN) REFERENCES MASTER_DATA.PERTANYAAN_SURVEI (ID_PERTANYAAN)
) COMMENT = 'Opsi jawaban yang tersedia untuk setiap pertanyaan | Granularitas: satu baris per opsi jawaban | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS MASTER_DATA.REFERENSI_MODEL_PERKIRAAN (
    ID_MODEL VARCHAR(30) NOT NULL COMMENT 'Pengenal model perkiraan (contoh: MDL-01)',
    NAMA_MODEL VARCHAR(150) NOT NULL COMMENT 'Nama model untuk tampilan',
    DESKRIPSI_METODE VARCHAR(1000) NOT NULL COMMENT 'Penjelasan metode dalam bahasa awam, termasuk apa yang diketahui dan tidak diketahui model',
    HORIZON_HARI NUMBER(3,0) NOT NULL COMMENT 'Berapa hari sebelum awal pekan sasaran perkiraan dibuat',
    MINIMAL_RIWAYAT_MINGGU NUMBER(3,0) NOT NULL COMMENT 'Jumlah pekan riwayat minimal sebelum model mulai membuat perkiraan',
    JENDELA_PELATIHAN_MINGGU NUMBER(3,0) NOT NULL COMMENT 'Jumlah pekan terakhir yang dipakai model untuk belajar',
    LEBAR_RENTANG_PERSEN NUMBER(3,0) NOT NULL COMMENT 'Peluang yang diharapkan agar kolekte sebenarnya jatuh di dalam rentang perkiraan, dalam persen',
    STATUS_AKTIF BOOLEAN NOT NULL COMMENT 'TRUE jika model masih dipakai membuat perkiraan baru',
    CONSTRAINT PK_REFERENSI_MODEL_PERKIRAAN PRIMARY KEY (ID_MODEL)
) COMMENT = 'Daftar model perkiraan kolekte beserta ketentuannya. Setiap perkiraan tersimpan menyebut model yang membuatnya | Granularitas: satu baris per model perkiraan | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.LAYANAN_PAROKI (
    ID_LAYANAN VARCHAR(30) NOT NULL COMMENT 'Pengenal layanan (contoh: LYN-01)',
    NAMA_LAYANAN VARCHAR(150) NOT NULL COMMENT 'Nama layanan untuk umat, misalnya Baptis Dewasa',
    KATEGORI_LAYANAN VARCHAR(100) NOT NULL COMMENT 'Kelompok layanan: Sakramen, Administrasi Umat, atau Pelayanan Duka',
    RINGKASAN VARCHAR(500) NOT NULL COMMENT 'Untuk siapa layanan ini, dalam satu atau dua kalimat',
    PERKIRAAN_WAKTU_PROSES VARCHAR(200) NOT NULL COMMENT 'Perkiraan lama proses dari pendaftaran sampai selesai',
    CATATAN_PENTING VARCHAR(1000) NOT NULL COMMENT 'Hal yang perlu diketahui pemohon, misalnya biaya dan waktu pendaftaran',
    ID_SEKSI_PENGELOLA VARCHAR(30) NOT NULL COMMENT 'Seksi yang bertanggung jawab atas layanan dan isi panduannya',
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi informasi. Hanya klasifikasi yang boleh tampil publik muncul di dasbor umum',
    NAMA_BERKAS_PANDUAN VARCHAR(200) NOT NULL COMMENT 'Nama berkas PDF panduan, tanpa folder dan diawali pengenal layanan',
    TANGGAL_REVISI DATE NOT NULL COMMENT 'Tanggal terakhir isi panduan ditinjau',
    CONSTRAINT PK_LAYANAN_PAROKI PRIMARY KEY (ID_LAYANAN),
    CONSTRAINT UQ_LAYANAN_PAROKI_BERKAS UNIQUE (NAMA_BERKAS_PANDUAN),
    CONSTRAINT FK_LAYANAN_PAROKI_SEKSI FOREIGN KEY (ID_SEKSI_PENGELOLA) REFERENCES MASTER_DATA.MASTER_SEKSI (ID_SEKSI),
    CONSTRAINT FK_LAYANAN_PAROKI_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA)
) COMMENT = 'Layanan paroki untuk umat beserta panduan PDF-nya. Isi panduan fiktif dan bukan ketentuan resmi | Granularitas: satu baris per layanan | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.LANGKAH_LAYANAN (
    ID_LANGKAH VARCHAR(30) NOT NULL COMMENT 'Pengenal langkah (contoh: LGK-0101)',
    ID_LAYANAN VARCHAR(30) NOT NULL COMMENT 'Layanan pemilik langkah',
    NOMOR_URUT NUMBER(2,0) NOT NULL COMMENT 'Urutan langkah dalam layanan, dimulai dari 1 tanpa lompatan',
    JUDUL_LANGKAH VARCHAR(150) NOT NULL COMMENT 'Judul singkat langkah',
    URAIAN VARCHAR(1000) NOT NULL COMMENT 'Penjelasan apa yang dilakukan pada langkah ini',
    PELAKU VARCHAR(100) NOT NULL COMMENT 'Siapa yang melakukan langkah ini: pemohon, sekretariat, pastor, seksi, atau ketua lingkungan',
    CONSTRAINT PK_LANGKAH_LAYANAN PRIMARY KEY (ID_LANGKAH),
    CONSTRAINT UQ_LANGKAH_LAYANAN_URUT UNIQUE (ID_LAYANAN, NOMOR_URUT),
    CONSTRAINT FK_LANGKAH_LAYANAN FOREIGN KEY (ID_LAYANAN) REFERENCES MASTER_DATA.LAYANAN_PAROKI (ID_LAYANAN)
) COMMENT = 'Langkah-langkah berurutan untuk setiap layanan | Granularitas: satu baris per langkah dalam satu layanan | Klasifikasi: Publik';

CREATE TABLE IF NOT EXISTS MASTER_DATA.PERSYARATAN_LAYANAN (
    ID_PERSYARATAN VARCHAR(30) NOT NULL COMMENT 'Pengenal persyaratan (contoh: PSY-0101)',
    ID_LAYANAN VARCHAR(30) NOT NULL COMMENT 'Layanan pemilik persyaratan',
    NOMOR_URUT NUMBER(2,0) NOT NULL COMMENT 'Urutan persyaratan dalam layanan, dimulai dari 1 tanpa lompatan',
    NAMA_PERSYARATAN VARCHAR(200) NOT NULL COMMENT 'Nama persyaratan, misalnya Fotokopi surat baptis',
    JENIS_PERSYARATAN VARCHAR(50) NOT NULL COMMENT 'Jenis: Dokumen, Pembinaan, atau Ketentuan Umum',
    WAJIB_DIPENUHI BOOLEAN NOT NULL COMMENT 'TRUE jika selalu wajib, FALSE jika hanya berlaku pada keadaan tertentu',
    KETERANGAN VARCHAR(500) COMMENT 'Penjelasan tambahan, kosong jika tidak ada',
    CONSTRAINT PK_PERSYARATAN_LAYANAN PRIMARY KEY (ID_PERSYARATAN),
    CONSTRAINT UQ_PERSYARATAN_LAYANAN_URUT UNIQUE (ID_LAYANAN, NOMOR_URUT),
    CONSTRAINT FK_PERSYARATAN_LAYANAN FOREIGN KEY (ID_LAYANAN) REFERENCES MASTER_DATA.LAYANAN_PAROKI (ID_LAYANAN)
) COMMENT = 'Persyaratan untuk setiap layanan | Granularitas: satu baris per persyaratan dalam satu layanan | Klasifikasi: Publik';

-- =============================================================================
-- DATA_OPERASIONAL : operational records and transactions
-- =============================================================================

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KEJADIAN_MISA (
    ID_KEJADIAN_MISA VARCHAR(30) NOT NULL COMMENT 'Pengenal kejadian Misa, dipakai bersama oleh kehadiran dan kolekte (contoh: MIS-000001)',
    ID_JADWAL_MISA VARCHAR(30) NOT NULL COMMENT 'Aturan jadwal yang melandasi kejadian ini',
    TANGGAL_MISA DATE NOT NULL COMMENT 'Tanggal Misa menurut kalender',
    WAKTU_MULAI_AKTUAL TIME COMMENT 'Jam mulai sebenarnya, kosong jika Misa belum atau tidak terlaksana',
    WAKTU_SELESAI_AKTUAL TIME COMMENT 'Jam selesai sebenarnya, kosong jika Misa belum atau tidak terlaksana',
    STATUS_PELAKSANAAN VARCHAR(50) NOT NULL COMMENT 'Status: Terjadwal, Terlaksana, atau Dibatalkan',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya hari raya atau alasan pembatalan',
    CONSTRAINT PK_KEJADIAN_MISA PRIMARY KEY (ID_KEJADIAN_MISA),
    CONSTRAINT UQ_KEJADIAN_MISA_JADWAL_TANGGAL UNIQUE (ID_JADWAL_MISA, TANGGAL_MISA),
    CONSTRAINT FK_KEJADIAN_MISA_JADWAL FOREIGN KEY (ID_JADWAL_MISA) REFERENCES MASTER_DATA.JADWAL_MISA (ID_JADWAL_MISA)
) COMMENT = 'Kejadian Misa yang sebenarnya, hasil penerapan aturan jadwal pada tanggal tertentu | Granularitas: satu baris per Misa pada satu tanggal | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA (
    ID_PERISTIWA VARCHAR(30) NOT NULL COMMENT 'Pengenal peristiwa (contoh: PRS-01)',
    JENIS_PERISTIWA VARCHAR(100) NOT NULL COMMENT 'Jenis peristiwa, misalnya Hujan Deras dan Banjir, Kabut Asap, atau Abu Vulkanik',
    NAMA_PERISTIWA VARCHAR(200) NOT NULL COMMENT 'Nama peristiwa untuk tampilan pada grafik riwayat',
    TANGGAL_MULAI DATE NOT NULL COMMENT 'Tanggal peristiwa mulai memengaruhi paroki',
    TANGGAL_SELESAI DATE NOT NULL COMMENT 'Tanggal peristiwa berakhir',
    TINGKAT_GANGGUAN VARCHAR(50) NOT NULL COMMENT 'Penilaian petugas atas gangguan: Ringan, Sedang, atau Berat',
    DESKRIPSI VARCHAR(500) NOT NULL COMMENT 'Penjelasan singkat peristiwa dan akibatnya bagi kegiatan paroki',
    CONSTRAINT PK_PERISTIWA_LUAR_BIASA PRIMARY KEY (ID_PERISTIWA)
) COMMENT = 'Catatan peristiwa luar biasa seperti hujan deras, kabut asap, atau abu vulkanik yang dapat menurunkan kehadiran dan kolekte. Besar dampak sengaja tidak disimpan agar dapat dianalisis dari data | Granularitas: satu baris per peristiwa | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KEHADIRAN_MISA (
    ID_KEHADIRAN VARCHAR(30) NOT NULL COMMENT 'Pengenal catatan kehadiran (contoh: KHD-000001)',
    ID_KEJADIAN_MISA VARCHAR(30) NOT NULL COMMENT 'Kejadian Misa yang dihitung kehadirannya',
    JUMLAH_UMAT NUMBER(6,0) NOT NULL COMMENT 'Jumlah umat yang hadir menurut penghitungan',
    METODE_PENGHITUNGAN VARCHAR(100) NOT NULL COMMENT 'Cara penghitungan jumlah umat',
    STATUS_VALIDASI VARCHAR(50) NOT NULL COMMENT 'Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang',
    WAKTU_PENCATATAN TIMESTAMP_NTZ NOT NULL COMMENT 'Waktu lokal pencatatan jumlah umat',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya kondisi cuaca atau alasan pengecekan ulang',
    ID_PERISTIWA VARCHAR(30) COMMENT 'Peristiwa luar biasa yang dicatat petugas sebagai penyebab kehadiran berbeda, kosong jika tidak ada',
    CONSTRAINT PK_KEHADIRAN_MISA PRIMARY KEY (ID_KEHADIRAN),
    CONSTRAINT UQ_KEHADIRAN_MISA_KEJADIAN UNIQUE (ID_KEJADIAN_MISA),
    CONSTRAINT FK_KEHADIRAN_MISA_KEJADIAN FOREIGN KEY (ID_KEJADIAN_MISA) REFERENCES DATA_OPERASIONAL.KEJADIAN_MISA (ID_KEJADIAN_MISA),
    CONSTRAINT FK_KEHADIRAN_MISA_PERISTIWA FOREIGN KEY (ID_PERISTIWA) REFERENCES DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA (ID_PERISTIWA)
) COMMENT = 'Total kehadiran umat pada setiap Misa yang terlaksana | Granularitas: satu baris per kejadian Misa | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.PENERIMAAN_KOLEKTE (
    ID_KOLEKTE VARCHAR(30) NOT NULL COMMENT 'Pengenal catatan kolekte (contoh: KLK-000001)',
    ID_KEJADIAN_MISA VARCHAR(30) NOT NULL COMMENT 'Kejadian Misa tempat kolekte dikumpulkan',
    ID_JENIS_KOLEKTE VARCHAR(30) NOT NULL COMMENT 'Jenis kolekte',
    JUMLAH_PENERIMAAN NUMBER(18,0) NOT NULL COMMENT 'Jumlah yang dicatat petugas saat Misa, dalam rupiah',
    JUMLAH_HASIL_PENGHITUNGAN NUMBER(18,0) COMMENT 'Jumlah hasil penghitungan tim penghitung, dalam rupiah, kosong jika belum dihitung',
    STATUS_REKONSILIASI VARCHAR(50) NOT NULL COMMENT 'Status: Sudah Cocok, Selisih Disetujui, Selisih Sedang Ditelusuri, atau Belum Dihitung',
    TANGGAL_PENCATATAN DATE NOT NULL COMMENT 'Tanggal hasil terakhir dicatat',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya penjelasan selisih',
    CONSTRAINT PK_PENERIMAAN_KOLEKTE PRIMARY KEY (ID_KOLEKTE),
    CONSTRAINT UQ_PENERIMAAN_KOLEKTE_KEJADIAN_JENIS UNIQUE (ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE),
    CONSTRAINT FK_PENERIMAAN_KOLEKTE_KEJADIAN FOREIGN KEY (ID_KEJADIAN_MISA) REFERENCES DATA_OPERASIONAL.KEJADIAN_MISA (ID_KEJADIAN_MISA),
    CONSTRAINT FK_PENERIMAAN_KOLEKTE_JENIS FOREIGN KEY (ID_JENIS_KOLEKTE) REFERENCES MASTER_DATA.REFERENSI_JENIS_KOLEKTE (ID_JENIS_KOLEKTE)
) COMMENT = 'Ringkasan kolekte per Misa dan jenis kolekte, membedakan jumlah tercatat, hasil penghitungan, dan status rekonsiliasi. Bukan ukuran iman atau komitmen rohani | Granularitas: satu baris per kejadian Misa dan jenis kolekte | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN (
    ID_PERKIRAAN VARCHAR(30) NOT NULL COMMENT 'Pengenal perkiraan (contoh: PKR-0001)',
    ID_MODEL VARCHAR(30) NOT NULL COMMENT 'Model yang membuat perkiraan',
    AWAL_PEKAN_SASARAN DATE NOT NULL COMMENT 'Hari Senin awal pekan yang diperkirakan (pekan berjalan dari Senin sampai Minggu)',
    TANGGAL_PERKIRAAN DATE NOT NULL COMMENT 'Tanggal perkiraan dibuat. Hanya data sebelum tanggal ini yang dipakai, sehingga peristiwa sesudahnya tidak diketahui',
    JUMLAH_PEKAN_PELATIHAN NUMBER(3,0) NOT NULL COMMENT 'Jumlah pekan riwayat yang dipakai model untuk belajar, tidak termasuk pekan hari raya dan pekan terganggu peristiwa',
    JUMLAH_PERKIRAAN NUMBER(18,0) NOT NULL COMMENT 'Perkiraan total kolekte pekan itu, dalam rupiah dan dibulatkan ke ribuan',
    BATAS_BAWAH NUMBER(18,0) NOT NULL COMMENT 'Batas bawah rentang perkiraan, dalam rupiah',
    BATAS_ATAS NUMBER(18,0) NOT NULL COMMENT 'Batas atas rentang perkiraan, dalam rupiah',
    PENYESUAIAN_KALENDER NUMBER(6,3) NOT NULL COMMENT 'Pengali kalender liturgi untuk pekan sasaran, 1.000 berarti tanpa penyesuaian',
    KETERANGAN VARCHAR(500) COMMENT 'Hari raya atau kolekte khusus yang dipertimbangkan, kosong jika tidak ada',
    CONSTRAINT PK_PERKIRAAN_KOLEKTE_MINGGUAN PRIMARY KEY (ID_PERKIRAAN),
    CONSTRAINT UQ_PERKIRAAN_KOLEKTE_MODEL_PEKAN UNIQUE (ID_MODEL, AWAL_PEKAN_SASARAN),
    CONSTRAINT FK_PERKIRAAN_KOLEKTE_MODEL FOREIGN KEY (ID_MODEL) REFERENCES MASTER_DATA.REFERENSI_MODEL_PERKIRAAN (ID_MODEL)
) COMMENT = 'Perkiraan bayangan kolekte mingguan, disimpan persis seperti dibuat empat pekan sebelumnya dan tidak pernah diperbarui sesudah kolekte sebenarnya diketahui. Dipakai untuk membandingkan perkiraan dengan kenyataan. Bukan ukuran iman atau komitmen rohani | Granularitas: satu baris per model dan pekan sasaran | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KELUARGA (
    ID_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Pengenal keluarga fiktif (contoh: KEL-0001)',
    NAMA_KELUARGA_FIKTIF VARCHAR(150) NOT NULL COMMENT 'Nama keluarga fiktif untuk simulasi',
    STATUS_KELUARGA VARCHAR(50) NOT NULL COMMENT 'Status keluarga: Aktif, Pindah Paroki, atau Tidak Aktif',
    TANGGAL_TERDAFTAR DATE NOT NULL COMMENT 'Tanggal keluarga pertama kali terdaftar',
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi data catatan keluarga',
    CONSTRAINT PK_KELUARGA PRIMARY KEY (ID_KELUARGA),
    CONSTRAINT FK_KELUARGA_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA)
) COMMENT = 'Rumah tangga fiktif pada simulasi basis data umat. Tidak memuat alamat atau nomor identitas | Granularitas: satu baris per keluarga | Klasifikasi: Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.UMAT (
    ID_UMAT VARCHAR(30) NOT NULL COMMENT 'Pengenal umat fiktif (contoh: UMT-00001)',
    NAMA_FIKTIF VARCHAR(150) NOT NULL COMMENT 'Nama fiktif untuk simulasi, bukan nama orang sebenarnya',
    JENIS_KELAMIN VARCHAR(20) NOT NULL COMMENT 'Laki-laki atau Perempuan',
    TAHUN_LAHIR NUMBER(4,0) NOT NULL COMMENT 'Tahun lahir saja, tanpa tanggal lengkap, untuk mengurangi risiko identifikasi',
    STATUS_KEANGGOTAAN VARCHAR(50) NOT NULL COMMENT 'Status: Aktif, Pindah Paroki, Tidak Aktif, atau Meninggal Dunia',
    TANGGAL_TERDAFTAR DATE NOT NULL COMMENT 'Tanggal umat pertama kali terdaftar',
    ID_KLASIFIKASI_DATA VARCHAR(30) NOT NULL COMMENT 'Klasifikasi data catatan umat, anak di bawah 17 tahun lebih ketat',
    CONSTRAINT PK_UMAT PRIMARY KEY (ID_UMAT),
    CONSTRAINT FK_UMAT_KLASIFIKASI FOREIGN KEY (ID_KLASIFIKASI_DATA) REFERENCES MASTER_DATA.REFERENSI_KLASIFIKASI_DATA (ID_KLASIFIKASI_DATA)
) COMMENT = 'Individu umat fiktif pada simulasi basis data umat. Tanpa nomor identitas, telepon, atau alamat. Dilarang tampil di dasbor publik | Granularitas: satu baris per umat | Klasifikasi: Terbatas (anak di bawah 17 tahun: Sangat Terbatas)';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.PENUGASAN_KELUARGA (
    ID_PENUGASAN_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Pengenal penugasan (contoh: PKL-00001)',
    ID_UMAT VARCHAR(30) NOT NULL COMMENT 'Umat yang ditugaskan',
    ID_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Keluarga tempat umat berada',
    PERAN_DALAM_KELUARGA VARCHAR(50) NOT NULL COMMENT 'Kepala Keluarga, Pasangan, Anak, atau Anggota Lain',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal penugasan mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal penugasan berakhir, kosong jika masih berlaku',
    CONSTRAINT PK_PENUGASAN_KELUARGA PRIMARY KEY (ID_PENUGASAN_KELUARGA),
    CONSTRAINT FK_PENUGASAN_KELUARGA_UMAT FOREIGN KEY (ID_UMAT) REFERENCES DATA_OPERASIONAL.UMAT (ID_UMAT),
    CONSTRAINT FK_PENUGASAN_KELUARGA_KELUARGA FOREIGN KEY (ID_KELUARGA) REFERENCES DATA_OPERASIONAL.KELUARGA (ID_KELUARGA)
) COMMENT = 'Riwayat keanggotaan umat dalam keluarga dengan masa berlaku | Granularitas: satu baris per umat, keluarga, dan masa berlaku | Klasifikasi: Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN (
    ID_PENUGASAN_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Pengenal penugasan (contoh: PLG-0001)',
    ID_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Keluarga yang ditugaskan ke lingkungan',
    ID_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Lingkungan tempat keluarga berada',
    TANGGAL_MULAI_BERLAKU DATE NOT NULL COMMENT 'Tanggal penugasan mulai berlaku',
    TANGGAL_AKHIR_BERLAKU DATE COMMENT 'Tanggal penugasan berakhir, kosong jika masih berlaku',
    CONSTRAINT PK_PENUGASAN_LINGKUNGAN PRIMARY KEY (ID_PENUGASAN_LINGKUNGAN),
    CONSTRAINT FK_PENUGASAN_LINGKUNGAN_KELUARGA FOREIGN KEY (ID_KELUARGA) REFERENCES DATA_OPERASIONAL.KELUARGA (ID_KELUARGA),
    CONSTRAINT FK_PENUGASAN_LINGKUNGAN_LINGKUNGAN FOREIGN KEY (ID_LINGKUNGAN) REFERENCES MASTER_DATA.MASTER_LINGKUNGAN (ID_LINGKUNGAN)
) COMMENT = 'Riwayat keanggotaan keluarga dalam lingkungan dengan masa berlaku. Wilayah diperoleh dari lingkungan | Granularitas: satu baris per keluarga, lingkungan, dan masa berlaku | Klasifikasi: Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.RESPONDEN_SURVEI (
    ID_RESPONDEN VARCHAR(30) NOT NULL COMMENT 'Kode responden anonim (contoh: RSP-0001), tidak terhubung ke ID_UMAT',
    ID_SURVEI VARCHAR(30) NOT NULL COMMENT 'Survei yang diisi',
    KELOMPOK_USIA VARCHAR(50) NOT NULL COMMENT 'Kelompok usia kasar responden',
    ID_WILAYAH VARCHAR(30) NOT NULL COMMENT 'Wilayah responden (tingkat wilayah saja, bukan lingkungan)',
    TANGGAL_PENGISIAN DATE NOT NULL COMMENT 'Tanggal survei diisi',
    CONSTRAINT PK_RESPONDEN_SURVEI PRIMARY KEY (ID_RESPONDEN),
    CONSTRAINT FK_RESPONDEN_SURVEI FOREIGN KEY (ID_SURVEI) REFERENCES MASTER_DATA.SURVEI (ID_SURVEI),
    CONSTRAINT FK_RESPONDEN_WILAYAH FOREIGN KEY (ID_WILAYAH) REFERENCES MASTER_DATA.MASTER_WILAYAH (ID_WILAYAH)
) COMMENT = 'Responden survei sintetis yang anonim | Granularitas: satu baris per responden per survei | Klasifikasi: Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.JAWABAN_SURVEI (
    ID_JAWABAN VARCHAR(30) NOT NULL COMMENT 'Pengenal jawaban (contoh: JWB-00001)',
    ID_RESPONDEN VARCHAR(30) NOT NULL COMMENT 'Responden yang menjawab',
    ID_PERTANYAAN VARCHAR(30) NOT NULL COMMENT 'Pertanyaan yang dijawab',
    ID_OPSI VARCHAR(30) NOT NULL COMMENT 'Opsi jawaban yang dipilih',
    CONSTRAINT PK_JAWABAN_SURVEI PRIMARY KEY (ID_JAWABAN),
    CONSTRAINT UQ_JAWABAN_RESPONDEN_PERTANYAAN UNIQUE (ID_RESPONDEN, ID_PERTANYAAN),
    CONSTRAINT FK_JAWABAN_RESPONDEN FOREIGN KEY (ID_RESPONDEN) REFERENCES DATA_OPERASIONAL.RESPONDEN_SURVEI (ID_RESPONDEN),
    CONSTRAINT FK_JAWABAN_PERTANYAAN FOREIGN KEY (ID_PERTANYAAN) REFERENCES MASTER_DATA.PERTANYAAN_SURVEI (ID_PERTANYAAN),
    CONSTRAINT FK_JAWABAN_OPSI FOREIGN KEY (ID_OPSI) REFERENCES MASTER_DATA.OPSI_JAWABAN_SURVEI (ID_OPSI)
) COMMENT = 'Jawaban sintetis responden. Pertanyaan yang dilewati tidak punya baris | Granularitas: satu baris per responden dan pertanyaan | Klasifikasi: Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT (
    ID_HASIL VARCHAR(30) NOT NULL COMMENT 'Pengenal hasil agregat (contoh: HSL-010101)',
    ID_SURVEI VARCHAR(30) NOT NULL COMMENT 'Survei yang dirangkum',
    ID_PERTANYAAN VARCHAR(30) NOT NULL COMMENT 'Pertanyaan yang dirangkum',
    ID_OPSI VARCHAR(30) NOT NULL COMMENT 'Opsi jawaban (kategori jawaban) yang dihitung',
    JUMLAH_RESPONDEN NUMBER(6,0) NOT NULL COMMENT 'Jumlah responden yang memilih opsi ini',
    TOTAL_RESPONDEN_PERTANYAAN NUMBER(6,0) NOT NULL COMMENT 'Jumlah responden yang menjawab pertanyaan ini (penyebut persentase)',
    PERSENTASE_JAWABAN NUMBER(5,2) NOT NULL COMMENT 'Persentase responden yang memilih opsi, dibulatkan dua desimal, 0 jika belum ada jawaban',
    TANGGAL_AGREGASI DATE NOT NULL COMMENT 'Tanggal ringkasan dihitung',
    CONSTRAINT PK_HASIL_SURVEI_AGREGAT PRIMARY KEY (ID_HASIL),
    CONSTRAINT UQ_HASIL_SURVEI_OPSI UNIQUE (ID_OPSI),
    CONSTRAINT FK_HASIL_SURVEI_SURVEI FOREIGN KEY (ID_SURVEI) REFERENCES MASTER_DATA.SURVEI (ID_SURVEI),
    CONSTRAINT FK_HASIL_SURVEI_PERTANYAAN FOREIGN KEY (ID_PERTANYAAN) REFERENCES MASTER_DATA.PERTANYAAN_SURVEI (ID_PERTANYAAN),
    CONSTRAINT FK_HASIL_SURVEI_OPSI FOREIGN KEY (ID_OPSI) REFERENCES MASTER_DATA.OPSI_JAWABAN_SURVEI (ID_OPSI)
) COMMENT = 'Hasil survei yang sudah dirangkum, aman untuk dasbor | Granularitas: satu baris per opsi jawaban pada survei yang sudah memiliki jawaban | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN (
    ID_RENCANA_KERJA VARCHAR(30) NOT NULL COMMENT 'Pengenal rencana kerja tahunan (contoh: RKT-2026-01)',
    ID_SEKSI VARCHAR(30) NOT NULL COMMENT 'Seksi pemilik rencana kerja',
    TAHUN_RENCANA NUMBER(4,0) NOT NULL COMMENT 'Tahun rencana kerja',
    TUJUAN_UMUM VARCHAR(500) NOT NULL COMMENT 'Tujuan umum seksi pada tahun tersebut',
    STATUS_PENGESAHAN VARCHAR(50) NOT NULL COMMENT 'Status pengesahan: Disahkan atau Dalam Revisi',
    TANGGAL_PENGESAHAN DATE NOT NULL COMMENT 'Tanggal rencana kerja disahkan',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan, misalnya alasan revisi',
    CONSTRAINT PK_RENCANA_KERJA_TAHUNAN PRIMARY KEY (ID_RENCANA_KERJA),
    CONSTRAINT UQ_RENCANA_KERJA_SEKSI_TAHUN UNIQUE (ID_SEKSI, TAHUN_RENCANA),
    CONSTRAINT FK_RENCANA_KERJA_SEKSI FOREIGN KEY (ID_SEKSI) REFERENCES MASTER_DATA.MASTER_SEKSI (ID_SEKSI)
) COMMENT = 'Rencana kerja tahunan setiap seksi | Granularitas: satu baris per seksi per tahun | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.RENCANA_KEGIATAN (
    ID_RENCANA VARCHAR(30) NOT NULL COMMENT 'Pengenal rencana kegiatan (contoh: RNC-0001)',
    ID_RENCANA_KERJA VARCHAR(30) NOT NULL COMMENT 'Rencana kerja tahunan induk, dari sini diperoleh seksi dan tahun',
    NAMA_PROGRAM VARCHAR(200) NOT NULL COMMENT 'Nama program atau kegiatan yang direncanakan',
    TUJUAN_PROGRAM VARCHAR(500) NOT NULL COMMENT 'Tujuan program',
    TANGGAL_RENCANA DATE NOT NULL COMMENT 'Tanggal pelaksanaan menurut rencana (tanggal mulai)',
    STATUS_PELAKSANAAN VARCHAR(50) NOT NULL COMMENT 'Status: Direncanakan, Terlaksana, Ditunda, atau Dibatalkan',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya alasan penundaan atau pembatalan',
    CONSTRAINT PK_RENCANA_KEGIATAN PRIMARY KEY (ID_RENCANA),
    CONSTRAINT FK_RENCANA_KEGIATAN_RENCANA_KERJA FOREIGN KEY (ID_RENCANA_KERJA) REFERENCES DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN (ID_RENCANA_KERJA)
) COMMENT = 'Kegiatan yang direncanakan dalam rencana kerja tahunan. Tidak semua rencana sudah terlaksana atau memiliki pengeluaran | Granularitas: satu baris per kegiatan yang direncanakan | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KAMPANYE_SUMBANGAN (
    ID_KAMPANYE VARCHAR(30) NOT NULL COMMENT 'Pengenal kampanye sumbangan (contoh: KMP-01)',
    ID_KESEMPATAN VARCHAR(30) NOT NULL COMMENT 'Kesempatan khusus yang melandasi kampanye',
    NAMA_KAMPANYE VARCHAR(200) NOT NULL COMMENT 'Nama kampanye beserta tahunnya, misalnya Aksi Puasa Pembangunan 2026',
    PERIODE_MULAI DATE NOT NULL COMMENT 'Tanggal awal pengumpulan',
    PERIODE_SELESAI DATE NOT NULL COMMENT 'Tanggal akhir pengumpulan',
    TARGET_DANA NUMBER(18,0) NOT NULL COMMENT 'Target dana kampanye, dalam rupiah',
    ID_RENCANA_PENGGUNAAN VARCHAR(30) COMMENT 'Rencana kegiatan yang akan dibiayai dana kampanye, misalnya perayaan Paskah atau Natal, kosong jika belum ditentukan',
    STATUS_KAMPANYE VARCHAR(50) NOT NULL COMMENT 'Status kampanye: Direncanakan, Berjalan, atau Selesai',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan',
    CONSTRAINT PK_KAMPANYE_SUMBANGAN PRIMARY KEY (ID_KAMPANYE),
    CONSTRAINT UQ_KAMPANYE_KESEMPATAN_PERIODE UNIQUE (ID_KESEMPATAN, PERIODE_MULAI),
    CONSTRAINT FK_KAMPANYE_KESEMPATAN FOREIGN KEY (ID_KESEMPATAN) REFERENCES MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS (ID_KESEMPATAN),
    CONSTRAINT FK_KAMPANYE_RENCANA FOREIGN KEY (ID_RENCANA_PENGGUNAAN) REFERENCES DATA_OPERASIONAL.RENCANA_KEGIATAN (ID_RENCANA)
) COMMENT = 'Satu kampanye sumbangan pada satu periode, dengan kegiatan besar yang didanainya. Dasar analisis titik impas | Granularitas: satu baris per kesempatan khusus dan periode | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS (
    ID_SUMBANGAN VARCHAR(30) NOT NULL COMMENT 'Pengenal catatan sumbangan wilayah (contoh: SMB-001)',
    ID_KAMPANYE VARCHAR(30) NOT NULL COMMENT 'Kampanye yang dilaporkan, dari sini diperoleh kesempatan khusus dan periode',
    ID_WILAYAH VARCHAR(30) NOT NULL COMMENT 'Wilayah pelapor sumbangan',
    JUMLAH_KELUARGA_PESERTA NUMBER(6,0) NOT NULL COMMENT 'Jumlah keluarga di wilayah yang ikut menyumbang',
    JUMLAH_SUMBANGAN NUMBER(18,0) NOT NULL COMMENT 'Total sumbangan wilayah pada kampanye tersebut, dalam rupiah',
    TANGGAL_PENCATATAN DATE NOT NULL COMMENT 'Tanggal laporan wilayah dicatat',
    STATUS_VALIDASI VARCHAR(50) NOT NULL COMMENT 'Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan',
    CONSTRAINT PK_SUMBANGAN_KESEMPATAN_KHUSUS PRIMARY KEY (ID_SUMBANGAN),
    CONSTRAINT UQ_SUMBANGAN_KAMPANYE_WILAYAH UNIQUE (ID_KAMPANYE, ID_WILAYAH),
    CONSTRAINT FK_SUMBANGAN_KAMPANYE FOREIGN KEY (ID_KAMPANYE) REFERENCES DATA_OPERASIONAL.KAMPANYE_SUMBANGAN (ID_KAMPANYE),
    CONSTRAINT FK_SUMBANGAN_WILAYAH FOREIGN KEY (ID_WILAYAH) REFERENCES MASTER_DATA.MASTER_WILAYAH (ID_WILAYAH)
) COMMENT = 'Ringkasan sumbangan kampanye per wilayah. Harus sama dengan jumlah sumbangan keluarga di wilayah itu. Tidak dipakai untuk memeringkat wilayah | Granularitas: satu baris per kampanye dan wilayah | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.SUMBANGAN_KELUARGA (
    ID_SUMBANGAN_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Pengenal sumbangan keluarga (contoh: SKL-00001)',
    ID_KAMPANYE VARCHAR(30) NOT NULL COMMENT 'Kampanye yang disumbang',
    ID_KELUARGA VARCHAR(30) NOT NULL COMMENT 'Keluarga fiktif penyumbang',
    ID_LINGKUNGAN VARCHAR(30) NOT NULL COMMENT 'Lingkungan keluarga pada tanggal sumbangan, dicatat agar riwayat pindah lingkungan tidak mengubah angka lama',
    JUMLAH_SUMBANGAN NUMBER(18,0) NOT NULL COMMENT 'Jumlah sumbangan keluarga pada kampanye ini, dalam rupiah',
    TANGGAL_SUMBANGAN DATE NOT NULL COMMENT 'Tanggal sumbangan diterima',
    CONSTRAINT PK_SUMBANGAN_KELUARGA PRIMARY KEY (ID_SUMBANGAN_KELUARGA),
    CONSTRAINT UQ_SUMBANGAN_KELUARGA_KAMPANYE UNIQUE (ID_KAMPANYE, ID_KELUARGA),
    CONSTRAINT FK_SUMBANGAN_KELUARGA_KAMPANYE FOREIGN KEY (ID_KAMPANYE) REFERENCES DATA_OPERASIONAL.KAMPANYE_SUMBANGAN (ID_KAMPANYE),
    CONSTRAINT FK_SUMBANGAN_KELUARGA_KELUARGA FOREIGN KEY (ID_KELUARGA) REFERENCES DATA_OPERASIONAL.KELUARGA (ID_KELUARGA),
    CONSTRAINT FK_SUMBANGAN_KELUARGA_LINGKUNGAN FOREIGN KEY (ID_LINGKUNGAN) REFERENCES MASTER_DATA.MASTER_LINGKUNGAN (ID_LINGKUNGAN)
) COMMENT = 'Sumbangan setiap keluarga fiktif pada satu kampanye. Data keuangan keluarga yang teridentifikasi, hanya boleh tampil sebagai angka agregat | Granularitas: satu baris per keluarga dan kampanye | Klasifikasi: Sangat Terbatas';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.ALOKASI_ANGGARAN (
    ID_ALOKASI VARCHAR(30) NOT NULL COMMENT 'Pengenal alokasi anggaran (contoh: ALK-0001)',
    ID_RENCANA VARCHAR(30) NOT NULL COMMENT 'Kegiatan yang dianggarkan',
    ID_KATEGORI_BIAYA VARCHAR(30) NOT NULL COMMENT 'Kategori biaya yang dianggarkan',
    JUMLAH_ANGGARAN NUMBER(18,0) NOT NULL COMMENT 'Jumlah anggaran yang disetujui, dalam rupiah',
    TANGGAL_PERSETUJUAN DATE NOT NULL COMMENT 'Tanggal anggaran disetujui',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan',
    CONSTRAINT PK_ALOKASI_ANGGARAN PRIMARY KEY (ID_ALOKASI),
    CONSTRAINT UQ_ALOKASI_RENCANA_KATEGORI UNIQUE (ID_RENCANA, ID_KATEGORI_BIAYA),
    CONSTRAINT FK_ALOKASI_RENCANA FOREIGN KEY (ID_RENCANA) REFERENCES DATA_OPERASIONAL.RENCANA_KEGIATAN (ID_RENCANA),
    CONSTRAINT FK_ALOKASI_KATEGORI_BIAYA FOREIGN KEY (ID_KATEGORI_BIAYA) REFERENCES MASTER_DATA.REFERENSI_KATEGORI_BIAYA (ID_KATEGORI_BIAYA)
) COMMENT = 'Anggaran yang direncanakan, terpisah dari realisasi pengeluaran | Granularitas: satu baris per kegiatan dan kategori biaya | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.REALISASI_PENGELUARAN (
    ID_PENGELUARAN VARCHAR(30) NOT NULL COMMENT 'Pengenal pengeluaran (contoh: PGL-00001)',
    ID_ALOKASI VARCHAR(30) NOT NULL COMMENT 'Alokasi anggaran yang digunakan',
    TANGGAL_PENGELUARAN DATE NOT NULL COMMENT 'Tanggal pengeluaran terjadi',
    JUMLAH_PENGELUARAN NUMBER(18,0) NOT NULL COMMENT 'Jumlah pengeluaran sebenarnya, dalam rupiah',
    KETERANGAN VARCHAR(500) COMMENT 'Uraian pengeluaran',
    CONSTRAINT PK_REALISASI_PENGELUARAN PRIMARY KEY (ID_PENGELUARAN),
    CONSTRAINT FK_REALISASI_ALOKASI FOREIGN KEY (ID_ALOKASI) REFERENCES DATA_OPERASIONAL.ALOKASI_ANGGARAN (ID_ALOKASI)
) COMMENT = 'Pengeluaran sebenarnya. Satu alokasi bisa memiliki banyak pengeluaran atau belum ada sama sekali | Granularitas: satu baris per transaksi pengeluaran | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KEGIATAN (
    ID_KEGIATAN VARCHAR(30) NOT NULL COMMENT 'Pengenal kegiatan (contoh: KGT-0001)',
    ID_RENCANA VARCHAR(30) COMMENT 'Rencana kegiatan asal, kosong untuk kegiatan yang tidak direncanakan',
    NAMA_KEGIATAN VARCHAR(200) NOT NULL COMMENT 'Nama kegiatan',
    ID_SEKSI VARCHAR(30) NOT NULL COMMENT 'Seksi penyelenggara',
    TANGGAL_MULAI DATE NOT NULL COMMENT 'Tanggal mulai kegiatan',
    TANGGAL_SELESAI DATE NOT NULL COMMENT 'Tanggal selesai kegiatan',
    LOKASI VARCHAR(150) NOT NULL COMMENT 'Tempat kegiatan',
    STATUS_KEGIATAN VARCHAR(50) NOT NULL COMMENT 'Status: Direncanakan, Terlaksana, Ditunda, atau Dibatalkan',
    TARGET_PESERTA NUMBER(6,0) NOT NULL COMMENT 'Target jumlah peserta',
    JUMLAH_PESERTA_AKTUAL NUMBER(6,0) COMMENT 'Jumlah peserta sebenarnya, kosong jika kegiatan belum atau tidak terlaksana',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya alasan penundaan',
    CONSTRAINT PK_KEGIATAN PRIMARY KEY (ID_KEGIATAN),
    CONSTRAINT UQ_KEGIATAN_RENCANA UNIQUE (ID_RENCANA),
    CONSTRAINT FK_KEGIATAN_RENCANA FOREIGN KEY (ID_RENCANA) REFERENCES DATA_OPERASIONAL.RENCANA_KEGIATAN (ID_RENCANA),
    CONSTRAINT FK_KEGIATAN_SEKSI FOREIGN KEY (ID_SEKSI) REFERENCES MASTER_DATA.MASTER_SEKSI (ID_SEKSI)
) COMMENT = 'Kegiatan yang benar-benar terdaftar atau terlaksana. Satu rencana memiliki paling banyak satu kegiatan | Granularitas: satu baris per kegiatan | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.LAPORAN_KEGIATAN (
    ID_LAPORAN VARCHAR(30) NOT NULL COMMENT 'Pengenal laporan (contoh: LPK-0001)',
    ID_KEGIATAN VARCHAR(30) NOT NULL COMMENT 'Kegiatan yang dilaporkan',
    TANGGAL_LAPORAN DATE NOT NULL COMMENT 'Tanggal laporan dibuat atau terakhir diubah',
    STATUS_LAPORAN VARCHAR(50) NOT NULL COMMENT 'Status laporan: Final, Draf, atau Perlu Revisi',
    RINGKASAN_PELAKSANAAN VARCHAR(2000) COMMENT 'Ringkasan pelaksanaan kegiatan',
    JUMLAH_PESERTA NUMBER(6,0) COMMENT 'Jumlah peserta menurut laporan, kosong jika belum diisi',
    REALISASI_BIAYA NUMBER(18,0) COMMENT 'Total biaya menurut laporan, dalam rupiah, kosong jika belum diisi',
    EVALUASI_LOGISTIK VARCHAR(2000) COMMENT 'Evaluasi perlengkapan, tempat, dan konsumsi',
    HASIL_KEGIATAN VARCHAR(2000) COMMENT 'Hasil atau capaian kegiatan',
    REKOMENDASI_TINDAK_LANJUT VARCHAR(2000) COMMENT 'Rekomendasi tindak lanjut, kosong jika belum diisi',
    NAMA_BERKAS_SUMBER VARCHAR(200) COMMENT 'Nama berkas PDF dokumen sumber laporan, tanpa folder dan diawali nomor laporan, kosong jika laporan tidak berasal dari dokumen',
    CONSTRAINT PK_LAPORAN_KEGIATAN PRIMARY KEY (ID_LAPORAN),
    CONSTRAINT UQ_LAPORAN_KEGIATAN UNIQUE (ID_KEGIATAN),
    CONSTRAINT UQ_LAPORAN_KEGIATAN_BERKAS UNIQUE (NAMA_BERKAS_SUMBER),
    CONSTRAINT FK_LAPORAN_KEGIATAN FOREIGN KEY (ID_KEGIATAN) REFERENCES DATA_OPERASIONAL.KEGIATAN (ID_KEGIATAN)
) COMMENT = 'Laporan pascakegiatan. Tidak semua kegiatan memiliki laporan, dan sebagian laporan belum lengkap | Granularitas: satu baris per kegiatan yang dilaporkan | Klasifikasi: Internal';
