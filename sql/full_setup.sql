-- =============================================================================
-- ALL-IN-ONE SETUP (steps 0-6) for a new demo database
--
-- GENERATED FILE. It is the concatenation of sql/00 ... sql/06 in order, built by
-- python scripts/generate_mock_data.py. Edit the individual files instead.
-- It never contains sql/99_reset_demo.sql and never drops anything.
--
-- How to run in Snowsight: open a SQL worksheet, choose a role that may create a
-- database and a running warehouse, paste this whole file, and use Run All.
-- The last result shown is the validation table: expect 0 FAIL and exactly 1 WARN.
-- =============================================================================

-- =============================================================================
-- >>> sql/00_setup.sql
-- =============================================================================

-- =============================================================================
-- Step 0: Session check (optional, read-only)
--
-- Purpose : Show which role and warehouse the current session uses, before any
--           object is created. This file does not create or change anything.
-- Warehouse: The project deliberately does NOT assume a warehouse name or role.
--           Pick a warehouse in the Snowsight UI (a trial account normally has
--           one already), or use the optional example at the bottom.
-- Safe to re-run: yes.
-- =============================================================================

-- ACTIVE_WAREHOUSE is NULL when no warehouse has been selected yet.
SELECT
    CURRENT_ACCOUNT()   AS ACCOUNT_NAME,
    CURRENT_USER()      AS USER_NAME,
    CURRENT_ROLE()      AS ACTIVE_ROLE,
    CURRENT_WAREHOUSE() AS ACTIVE_WAREHOUSE;

-- -----------------------------------------------------------------------------
-- OPTIONAL: create a small dedicated warehouse. Commented out on purpose.
-- Uncomment only if your account has no usable warehouse and your role may
-- create one. The name PIP_DEMO_WH is just an example.
-- -----------------------------------------------------------------------------
-- CREATE WAREHOUSE IF NOT EXISTS PIP_DEMO_WH
--     WITH WAREHOUSE_SIZE = 'XSMALL'
--     AUTO_SUSPEND = 60
--     AUTO_RESUME = TRUE
--     INITIALLY_SUSPENDED = TRUE;
-- USE WAREHOUSE PIP_DEMO_WH;

-- =============================================================================
-- >>> sql/01_create_schemas.sql
-- =============================================================================

-- =============================================================================
-- Step 1: Create the demo database and its three schemas
--
-- Creates : database PUSAT_INFORMASI_PAROKI and the schemas
--           MASTER_DATA, DATA_OPERASIONAL, ANALISIS.
-- Requires: a role that may create databases (in a trial account, ACCOUNTADMIN
--           or SYSADMIN) and no particular warehouse.
-- Safe to re-run: yes (CREATE ... IF NOT EXISTS, nothing is dropped).
-- Different database name: replace PUSAT_INFORMASI_PAROKI in the CREATE DATABASE
--           and USE DATABASE statements below, and in the USE DATABASE line of every
--           other file you run. Everything else uses schema names only.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS PUSAT_INFORMASI_PAROKI
    COMMENT = 'Demo Pusat Informasi Paroki. Seluruh isi adalah DATA SIMULASI (fiktif), bukan data paroki yang sebenarnya.';

USE DATABASE PUSAT_INFORMASI_PAROKI;

CREATE SCHEMA IF NOT EXISTS MASTER_DATA
    COMMENT = 'Data referensi dan data induk (wilayah, seksi, jadwal Misa, definisi survei, daftar nilai). Data simulasi.';

CREATE SCHEMA IF NOT EXISTS DATA_OPERASIONAL
    COMMENT = 'Catatan operasional dan transaksi (Misa, kolekte, umat, survei, rencana, anggaran, kegiatan). Berisi data pribadi fiktif yang berklasifikasi terbatas. Data simulasi.';

CREATE SCHEMA IF NOT EXISTS ANALISIS
    COMMENT = 'View ringkasan untuk laporan dan dasbor. Hanya data agregat, tanpa rincian pribadi umat. Data simulasi.';

-- =============================================================================
-- >>> sql/02_create_tables.sql
-- =============================================================================

-- =============================================================================
-- Step 2: Create all tables (DDL)
--
-- Creates : 16 tables in MASTER_DATA and 17 tables in DATA_OPERASIONAL.
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

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KEHADIRAN_MISA (
    ID_KEHADIRAN VARCHAR(30) NOT NULL COMMENT 'Pengenal catatan kehadiran (contoh: KHD-000001)',
    ID_KEJADIAN_MISA VARCHAR(30) NOT NULL COMMENT 'Kejadian Misa yang dihitung kehadirannya',
    JUMLAH_UMAT NUMBER(6,0) NOT NULL COMMENT 'Jumlah umat yang hadir menurut penghitungan',
    METODE_PENGHITUNGAN VARCHAR(100) NOT NULL COMMENT 'Cara penghitungan jumlah umat',
    STATUS_VALIDASI VARCHAR(50) NOT NULL COMMENT 'Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang',
    WAKTU_PENCATATAN TIMESTAMP_NTZ NOT NULL COMMENT 'Waktu lokal pencatatan jumlah umat',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya kondisi cuaca atau alasan pengecekan ulang',
    CONSTRAINT PK_KEHADIRAN_MISA PRIMARY KEY (ID_KEHADIRAN),
    CONSTRAINT UQ_KEHADIRAN_MISA_KEJADIAN UNIQUE (ID_KEJADIAN_MISA),
    CONSTRAINT FK_KEHADIRAN_MISA_KEJADIAN FOREIGN KEY (ID_KEJADIAN_MISA) REFERENCES DATA_OPERASIONAL.KEJADIAN_MISA (ID_KEJADIAN_MISA)
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

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS (
    ID_SUMBANGAN VARCHAR(30) NOT NULL COMMENT 'Pengenal catatan sumbangan (contoh: SMB-001)',
    ID_WILAYAH VARCHAR(30) NOT NULL COMMENT 'Wilayah pelapor sumbangan',
    ID_KESEMPATAN VARCHAR(30) NOT NULL COMMENT 'Kesempatan khusus, misalnya Prapaskah atau Adven',
    PERIODE_MULAI DATE NOT NULL COMMENT 'Tanggal awal periode pengumpulan',
    PERIODE_SELESAI DATE NOT NULL COMMENT 'Tanggal akhir periode pengumpulan',
    JUMLAH_KELUARGA_PESERTA NUMBER(6,0) NOT NULL COMMENT 'Jumlah keluarga di wilayah yang ikut menyumbang',
    JUMLAH_SUMBANGAN NUMBER(18,0) NOT NULL COMMENT 'Total sumbangan wilayah pada periode tersebut, dalam rupiah',
    TANGGAL_PENCATATAN DATE NOT NULL COMMENT 'Tanggal laporan wilayah dicatat',
    STATUS_VALIDASI VARCHAR(50) NOT NULL COMMENT 'Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan tambahan',
    CONSTRAINT PK_SUMBANGAN_KESEMPATAN_KHUSUS PRIMARY KEY (ID_SUMBANGAN),
    CONSTRAINT UQ_SUMBANGAN_WILAYAH_KESEMPATAN_PERIODE UNIQUE (ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI),
    CONSTRAINT FK_SUMBANGAN_WILAYAH FOREIGN KEY (ID_WILAYAH) REFERENCES MASTER_DATA.MASTER_WILAYAH (ID_WILAYAH),
    CONSTRAINT FK_SUMBANGAN_KESEMPATAN FOREIGN KEY (ID_KESEMPATAN) REFERENCES MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS (ID_KESEMPATAN)
) COMMENT = 'Ringkasan sumbangan kesempatan khusus per wilayah. Tidak dipakai untuk memeringkat wilayah | Granularitas: satu baris per wilayah, kesempatan khusus, dan periode | Klasifikasi: Internal';

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
    ID_RENCANA VARCHAR(30) NOT NULL COMMENT 'Pengenal rencana kegiatan (contoh: RNC-001)',
    ID_RENCANA_KERJA VARCHAR(30) NOT NULL COMMENT 'Rencana kerja tahunan induk, dari sini diperoleh seksi dan tahun',
    NAMA_PROGRAM VARCHAR(200) NOT NULL COMMENT 'Nama program atau kegiatan yang direncanakan',
    TUJUAN_PROGRAM VARCHAR(500) NOT NULL COMMENT 'Tujuan program',
    TANGGAL_RENCANA DATE NOT NULL COMMENT 'Tanggal pelaksanaan menurut rencana (tanggal mulai)',
    STATUS_PELAKSANAAN VARCHAR(50) NOT NULL COMMENT 'Status: Direncanakan, Terlaksana, Ditunda, atau Dibatalkan',
    KETERANGAN VARCHAR(500) COMMENT 'Catatan, misalnya alasan penundaan atau pembatalan',
    CONSTRAINT PK_RENCANA_KEGIATAN PRIMARY KEY (ID_RENCANA),
    CONSTRAINT FK_RENCANA_KEGIATAN_RENCANA_KERJA FOREIGN KEY (ID_RENCANA_KERJA) REFERENCES DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN (ID_RENCANA_KERJA)
) COMMENT = 'Kegiatan yang direncanakan dalam rencana kerja tahunan. Tidak semua rencana sudah terlaksana atau memiliki pengeluaran | Granularitas: satu baris per kegiatan yang direncanakan | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.ALOKASI_ANGGARAN (
    ID_ALOKASI VARCHAR(30) NOT NULL COMMENT 'Pengenal alokasi anggaran (contoh: ALK-001)',
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
    ID_PENGELUARAN VARCHAR(30) NOT NULL COMMENT 'Pengenal pengeluaran (contoh: PGL-0001)',
    ID_ALOKASI VARCHAR(30) NOT NULL COMMENT 'Alokasi anggaran yang digunakan',
    TANGGAL_PENGELUARAN DATE NOT NULL COMMENT 'Tanggal pengeluaran terjadi',
    JUMLAH_PENGELUARAN NUMBER(18,0) NOT NULL COMMENT 'Jumlah pengeluaran sebenarnya, dalam rupiah',
    KETERANGAN VARCHAR(500) COMMENT 'Uraian pengeluaran',
    CONSTRAINT PK_REALISASI_PENGELUARAN PRIMARY KEY (ID_PENGELUARAN),
    CONSTRAINT FK_REALISASI_ALOKASI FOREIGN KEY (ID_ALOKASI) REFERENCES DATA_OPERASIONAL.ALOKASI_ANGGARAN (ID_ALOKASI)
) COMMENT = 'Pengeluaran sebenarnya. Satu alokasi bisa memiliki banyak pengeluaran atau belum ada sama sekali | Granularitas: satu baris per transaksi pengeluaran | Klasifikasi: Internal';

CREATE TABLE IF NOT EXISTS DATA_OPERASIONAL.KEGIATAN (
    ID_KEGIATAN VARCHAR(30) NOT NULL COMMENT 'Pengenal kegiatan (contoh: KGT-001)',
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
    ID_LAPORAN VARCHAR(30) NOT NULL COMMENT 'Pengenal laporan (contoh: LPK-001)',
    ID_KEGIATAN VARCHAR(30) NOT NULL COMMENT 'Kegiatan yang dilaporkan',
    TANGGAL_LAPORAN DATE NOT NULL COMMENT 'Tanggal laporan dibuat atau terakhir diubah',
    STATUS_LAPORAN VARCHAR(50) NOT NULL COMMENT 'Status laporan: Final, Draf, atau Perlu Revisi',
    RINGKASAN_PELAKSANAAN VARCHAR(2000) COMMENT 'Ringkasan pelaksanaan kegiatan',
    JUMLAH_PESERTA NUMBER(6,0) COMMENT 'Jumlah peserta menurut laporan, kosong jika belum diisi',
    REALISASI_BIAYA NUMBER(18,0) COMMENT 'Total biaya menurut laporan, dalam rupiah, kosong jika belum diisi',
    EVALUASI_LOGISTIK VARCHAR(2000) COMMENT 'Evaluasi perlengkapan, tempat, dan konsumsi',
    HASIL_KEGIATAN VARCHAR(2000) COMMENT 'Hasil atau capaian kegiatan',
    REKOMENDASI_TINDAK_LANJUT VARCHAR(2000) COMMENT 'Rekomendasi tindak lanjut, kosong jika belum diisi',
    CONSTRAINT PK_LAPORAN_KEGIATAN PRIMARY KEY (ID_LAPORAN),
    CONSTRAINT UQ_LAPORAN_KEGIATAN UNIQUE (ID_KEGIATAN),
    CONSTRAINT FK_LAPORAN_KEGIATAN FOREIGN KEY (ID_KEGIATAN) REFERENCES DATA_OPERASIONAL.KEGIATAN (ID_KEGIATAN)
) COMMENT = 'Laporan pascakegiatan. Tidak semua kegiatan memiliki laporan, dan sebagian laporan belum lengkap | Granularitas: satu baris per kegiatan yang dilaporkan | Klasifikasi: Internal';

-- =============================================================================
-- >>> sql/03_load_reference_data.sql
-- =============================================================================

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

-- =============================================================================
-- >>> sql/04_load_mock_data.sql
-- =============================================================================

-- =============================================================================
-- Step 4: Load synthetic operational data
--
-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py
-- Content  : 17 tables, 4111 rows in schema DATA_OPERASIONAL. All data is synthetic
--            (fictional) and reproducible (seed 20260930, snapshot date 2026-09-30).
-- Requires : steps 2 and 3 (tables and master data)
-- Safe to re-run: yes. Every table is loaded with MERGE on its primary key, so existing
--            rows are updated and new rows are inserted. Nothing is deleted and nothing
--            is duplicated. Statements are ordered parents first.
-- Warehouse: any running warehouse is enough (the data volume is small).
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

-- DATA_OPERASIONAL.KEJADIAN_MISA: 182 rows
MERGE INTO DATA_OPERASIONAL.KEJADIAN_MISA AS t
USING (
    SELECT
        v.ID_KEJADIAN_MISA AS ID_KEJADIAN_MISA,
        v.ID_JADWAL_MISA AS ID_JADWAL_MISA,
        CAST(v.TANGGAL_MISA AS DATE) AS TANGGAL_MISA,
        CAST(v.WAKTU_MULAI_AKTUAL AS TIME) AS WAKTU_MULAI_AKTUAL,
        CAST(v.WAKTU_SELESAI_AKTUAL AS TIME) AS WAKTU_SELESAI_AKTUAL,
        v.STATUS_PELAKSANAAN AS STATUS_PELAKSANAAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('MIS-000001', 'JDW-07', '2026-04-01', '05:32:00', '06:17:00', 'Terlaksana', NULL),
            ('MIS-000002', 'JDW-01', '2026-04-04', '17:02:00', '18:22:00', 'Terlaksana', 'Malam Paskah (Sabtu Suci).'),
            ('MIS-000003', 'JDW-03', '2026-04-05', '06:00:00', '07:18:00', 'Terlaksana', 'Hari Raya Paskah.'),
            ('MIS-000004', 'JDW-04', '2026-04-05', '08:00:00', '09:23:00', 'Terlaksana', 'Hari Raya Paskah.'),
            ('MIS-000005', 'JDW-05', '2026-04-05', '10:30:00', '11:41:00', 'Terlaksana', 'Hari Raya Paskah.'),
            ('MIS-000006', 'JDW-06', '2026-04-05', '17:30:00', '18:45:00', 'Terlaksana', 'Hari Raya Paskah.'),
            ('MIS-000007', 'JDW-07', '2026-04-08', '05:30:00', '06:12:00', 'Terlaksana', NULL),
            ('MIS-000008', 'JDW-01', '2026-04-11', '17:00:00', '18:12:00', 'Terlaksana', NULL),
            ('MIS-000009', 'JDW-03', '2026-04-12', '06:10:00', '07:20:00', 'Terlaksana', NULL),
            ('MIS-000010', 'JDW-04', '2026-04-12', '08:08:00', '09:27:00', 'Terlaksana', NULL),
            ('MIS-000011', 'JDW-05', '2026-04-12', '10:31:00', '11:34:00', 'Terlaksana', NULL),
            ('MIS-000012', 'JDW-06', '2026-04-12', '17:33:00', '19:00:00', 'Terlaksana', NULL),
            ('MIS-000013', 'JDW-07', '2026-04-15', '05:33:00', '06:13:00', 'Terlaksana', NULL),
            ('MIS-000014', 'JDW-01', '2026-04-18', '17:01:00', '18:14:00', 'Terlaksana', NULL),
            ('MIS-000015', 'JDW-03', '2026-04-19', '06:05:00', '07:29:00', 'Terlaksana', NULL),
            ('MIS-000016', 'JDW-04', '2026-04-19', '08:00:00', '09:22:00', 'Terlaksana', NULL),
            ('MIS-000017', 'JDW-05', '2026-04-19', '10:35:00', '11:32:00', 'Terlaksana', NULL),
            ('MIS-000018', 'JDW-06', '2026-04-19', '17:32:00', '18:49:00', 'Terlaksana', NULL),
            ('MIS-000019', 'JDW-07', '2026-04-22', '05:35:00', '06:21:00', 'Terlaksana', NULL),
            ('MIS-000020', 'JDW-01', '2026-04-25', '17:08:00', '18:30:00', 'Terlaksana', NULL),
            ('MIS-000021', 'JDW-03', '2026-04-26', '06:03:00', '07:19:00', 'Terlaksana', NULL),
            ('MIS-000022', 'JDW-04', '2026-04-26', '08:00:00', '09:20:00', 'Terlaksana', NULL),
            ('MIS-000023', 'JDW-05', '2026-04-26', '10:38:00', '11:35:00', 'Terlaksana', NULL),
            ('MIS-000024', 'JDW-06', '2026-04-26', '17:31:00', '18:44:00', 'Terlaksana', NULL),
            ('MIS-000025', 'JDW-07', '2026-04-29', '05:32:00', '06:16:00', 'Terlaksana', NULL),
            ('MIS-000026', 'JDW-01', '2026-05-02', '17:00:00', '18:26:00', 'Terlaksana', NULL),
            ('MIS-000027', 'JDW-03', '2026-05-03', '06:03:00', '07:29:00', 'Terlaksana', NULL),
            ('MIS-000028', 'JDW-04', '2026-05-03', '08:01:00', '09:27:00', 'Terlaksana', NULL),
            ('MIS-000029', 'JDW-05', '2026-05-03', '10:32:00', '11:28:00', 'Terlaksana', NULL),
            ('MIS-000030', 'JDW-06', '2026-05-03', '17:32:00', '18:55:00', 'Terlaksana', NULL),
            ('MIS-000031', 'JDW-07', '2026-05-06', '05:30:00', '06:13:00', 'Terlaksana', NULL),
            ('MIS-000032', 'JDW-01', '2026-05-09', '17:00:00', '18:16:00', 'Terlaksana', NULL),
            ('MIS-000033', 'JDW-03', '2026-05-10', '06:00:00', '07:21:00', 'Terlaksana', NULL),
            ('MIS-000034', 'JDW-04', '2026-05-10', '08:01:00', '09:15:00', 'Terlaksana', NULL),
            ('MIS-000035', 'JDW-05', '2026-05-10', '10:30:00', '11:29:00', 'Terlaksana', NULL),
            ('MIS-000036', 'JDW-06', '2026-05-10', '17:32:00', '18:43:00', 'Terlaksana', NULL),
            ('MIS-000037', 'JDW-07', '2026-05-13', '05:33:00', '06:22:00', 'Terlaksana', NULL),
            ('MIS-000038', 'JDW-01', '2026-05-16', '17:01:00', '18:21:00', 'Terlaksana', NULL),
            ('MIS-000039', 'JDW-03', '2026-05-17', '06:01:00', '07:18:00', 'Terlaksana', NULL),
            ('MIS-000040', 'JDW-04', '2026-05-17', '08:00:00', '09:12:00', 'Terlaksana', NULL),
            ('MIS-000041', 'JDW-05', '2026-05-17', '10:30:00', '11:35:00', 'Terlaksana', NULL),
            ('MIS-000042', 'JDW-06', '2026-05-17', '17:30:00', '18:45:00', 'Terlaksana', NULL),
            ('MIS-000043', 'JDW-07', '2026-05-20', '05:31:00', '06:17:00', 'Terlaksana', NULL),
            ('MIS-000044', 'JDW-01', '2026-05-23', '17:03:00', '18:20:00', 'Terlaksana', NULL),
            ('MIS-000045', 'JDW-03', '2026-05-24', '06:00:00', '07:12:00', 'Terlaksana', 'Hari Raya Pentakosta.'),
            ('MIS-000046', 'JDW-04', '2026-05-24', '08:00:00', '09:18:00', 'Terlaksana', 'Hari Raya Pentakosta.'),
            ('MIS-000047', 'JDW-05', '2026-05-24', '10:38:00', '11:38:00', 'Terlaksana', 'Hari Raya Pentakosta.'),
            ('MIS-000048', 'JDW-06', '2026-05-24', '17:40:00', '19:05:00', 'Terlaksana', 'Hari Raya Pentakosta.'),
            ('MIS-000049', 'JDW-07', '2026-05-27', '05:32:00', '06:14:00', 'Terlaksana', NULL),
            ('MIS-000050', 'JDW-01', '2026-05-30', '17:00:00', '18:21:00', 'Terlaksana', NULL),
            ('MIS-000051', 'JDW-03', '2026-05-31', '06:05:00', '07:26:00', 'Terlaksana', NULL),
            ('MIS-000052', 'JDW-04', '2026-05-31', '08:01:00', '09:18:00', 'Terlaksana', NULL),
            ('MIS-000053', 'JDW-05', '2026-05-31', '10:30:00', '11:26:00', 'Terlaksana', NULL),
            ('MIS-000054', 'JDW-06', '2026-05-31', '17:30:00', '18:42:00', 'Terlaksana', NULL),
            ('MIS-000055', 'JDW-07', '2026-06-03', '05:32:00', '06:26:00', 'Terlaksana', NULL),
            ('MIS-000056', 'JDW-01', '2026-06-06', '17:05:00', '18:19:00', 'Terlaksana', NULL),
            ('MIS-000057', 'JDW-03', '2026-06-07', '06:00:00', '07:21:00', 'Terlaksana', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('MIS-000058', 'JDW-04', '2026-06-07', '08:00:00', '09:17:00', 'Terlaksana', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('MIS-000059', 'JDW-05', '2026-06-07', '10:30:00', '11:25:00', 'Terlaksana', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('MIS-000060', 'JDW-06', '2026-06-07', '17:30:00', '18:56:00', 'Terlaksana', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('MIS-000061', 'JDW-07', '2026-06-10', '05:32:00', '06:23:00', 'Terlaksana', NULL),
            ('MIS-000062', 'JDW-01', '2026-06-13', '17:08:00', '18:23:00', 'Terlaksana', NULL),
            ('MIS-000063', 'JDW-03', '2026-06-14', '06:03:00', '07:28:00', 'Terlaksana', NULL),
            ('MIS-000064', 'JDW-04', '2026-06-14', '08:01:00', '09:24:00', 'Terlaksana', NULL),
            ('MIS-000065', 'JDW-05', '2026-06-14', '10:35:00', '11:46:00', 'Terlaksana', NULL),
            ('MIS-000066', 'JDW-06', '2026-06-14', '17:35:00', '19:01:00', 'Terlaksana', NULL),
            ('MIS-000067', 'JDW-07', '2026-06-17', '05:30:00', '06:24:00', 'Terlaksana', NULL),
            ('MIS-000068', 'JDW-01', '2026-06-20', '17:00:00', '18:10:00', 'Terlaksana', NULL),
            ('MIS-000069', 'JDW-03', '2026-06-21', '06:00:00', '07:20:00', 'Terlaksana', NULL),
            ('MIS-000070', 'JDW-04', '2026-06-21', '08:05:00', '09:26:00', 'Terlaksana', NULL),
            ('MIS-000071', 'JDW-05', '2026-06-21', '10:30:00', '11:42:00', 'Terlaksana', NULL),
            ('MIS-000072', 'JDW-06', '2026-06-21', '17:31:00', '18:41:00', 'Terlaksana', NULL),
            ('MIS-000073', 'JDW-07', '2026-06-24', '05:31:00', '06:13:00', 'Terlaksana', NULL),
            ('MIS-000074', 'JDW-01', '2026-06-27', '17:03:00', '18:24:00', 'Terlaksana', NULL),
            ('MIS-000075', 'JDW-03', '2026-06-28', '06:00:00', '07:21:00', 'Terlaksana', NULL),
            ('MIS-000076', 'JDW-04', '2026-06-28', '08:02:00', '09:15:00', 'Terlaksana', NULL),
            ('MIS-000077', 'JDW-05', '2026-06-28', '10:35:00', '11:43:00', 'Terlaksana', NULL),
            ('MIS-000078', 'JDW-06', '2026-06-28', '17:32:00', '18:42:00', 'Terlaksana', NULL),
            ('MIS-000079', 'JDW-07', '2026-07-01', NULL, NULL, 'Dibatalkan', 'Dibatalkan karena imam bertugas di luar paroki.'),
            ('MIS-000080', 'JDW-02', '2026-07-04', '17:32:00', '18:47:00', 'Terlaksana', NULL),
            ('MIS-000081', 'JDW-03', '2026-07-05', '06:00:00', '07:21:00', 'Terlaksana', NULL),
            ('MIS-000082', 'JDW-04', '2026-07-05', '08:05:00', '09:15:00', 'Terlaksana', NULL),
            ('MIS-000083', 'JDW-05', '2026-07-05', '10:33:00', '11:40:00', 'Terlaksana', NULL),
            ('MIS-000084', 'JDW-06', '2026-07-05', '17:35:00', '18:50:00', 'Terlaksana', NULL),
            ('MIS-000085', 'JDW-07', '2026-07-08', '05:33:00', '06:13:00', 'Terlaksana', NULL),
            ('MIS-000086', 'JDW-02', '2026-07-11', '17:31:00', '18:48:00', 'Terlaksana', NULL),
            ('MIS-000087', 'JDW-03', '2026-07-12', '06:01:00', '07:11:00', 'Terlaksana', NULL),
            ('MIS-000088', 'JDW-04', '2026-07-12', '08:03:00', '09:20:00', 'Terlaksana', NULL),
            ('MIS-000089', 'JDW-05', '2026-07-12', '10:30:00', '11:29:00', 'Terlaksana', NULL),
            ('MIS-000090', 'JDW-06', '2026-07-12', '17:32:00', '18:56:00', 'Terlaksana', NULL),
            ('MIS-000091', 'JDW-07', '2026-07-15', '05:30:00', '06:24:00', 'Terlaksana', NULL),
            ('MIS-000092', 'JDW-02', '2026-07-18', '17:30:00', '18:47:00', 'Terlaksana', NULL),
            ('MIS-000093', 'JDW-03', '2026-07-19', '06:08:00', '07:33:00', 'Terlaksana', NULL),
            ('MIS-000094', 'JDW-04', '2026-07-19', '08:00:00', '09:23:00', 'Terlaksana', NULL),
            ('MIS-000095', 'JDW-05', '2026-07-19', '10:31:00', '11:33:00', 'Terlaksana', NULL),
            ('MIS-000096', 'JDW-06', '2026-07-19', NULL, NULL, 'Dibatalkan', 'Dibatalkan karena hujan deras dan genangan air di halaman gereja.'),
            ('MIS-000097', 'JDW-07', '2026-07-22', '05:31:00', '06:23:00', 'Terlaksana', NULL),
            ('MIS-000098', 'JDW-02', '2026-07-25', '17:33:00', '18:57:00', 'Terlaksana', NULL),
            ('MIS-000099', 'JDW-03', '2026-07-26', '06:00:00', '07:12:00', 'Terlaksana', NULL),
            ('MIS-000100', 'JDW-04', '2026-07-26', '08:02:00', '09:28:00', 'Terlaksana', NULL),
            ('MIS-000101', 'JDW-05', '2026-07-26', '10:30:00', '11:27:00', 'Terlaksana', NULL),
            ('MIS-000102', 'JDW-06', '2026-07-26', '17:30:00', '18:53:00', 'Terlaksana', NULL),
            ('MIS-000103', 'JDW-07', '2026-07-29', '05:40:00', '06:30:00', 'Terlaksana', NULL),
            ('MIS-000104', 'JDW-02', '2026-08-01', '17:35:00', '18:55:00', 'Terlaksana', NULL),
            ('MIS-000105', 'JDW-03', '2026-08-02', '06:01:00', '07:20:00', 'Terlaksana', NULL),
            ('MIS-000106', 'JDW-04', '2026-08-02', '08:02:00', '09:18:00', 'Terlaksana', NULL),
            ('MIS-000107', 'JDW-05', '2026-08-02', '10:30:00', '11:30:00', 'Terlaksana', NULL),
            ('MIS-000108', 'JDW-06', '2026-08-02', '17:33:00', '18:50:00', 'Terlaksana', NULL),
            ('MIS-000109', 'JDW-07', '2026-08-05', '05:32:00', '06:18:00', 'Terlaksana', NULL),
            ('MIS-000110', 'JDW-02', '2026-08-08', '17:32:00', '18:43:00', 'Terlaksana', NULL),
            ('MIS-000111', 'JDW-03', '2026-08-09', '06:00:00', '07:25:00', 'Terlaksana', NULL),
            ('MIS-000112', 'JDW-04', '2026-08-09', '08:02:00', '09:25:00', 'Terlaksana', NULL),
            ('MIS-000113', 'JDW-05', '2026-08-09', '10:32:00', '11:41:00', 'Terlaksana', NULL),
            ('MIS-000114', 'JDW-06', '2026-08-09', '17:35:00', '19:01:00', 'Terlaksana', NULL),
            ('MIS-000115', 'JDW-07', '2026-08-12', '05:32:00', '06:23:00', 'Terlaksana', NULL),
            ('MIS-000116', 'JDW-02', '2026-08-15', '17:35:00', '18:48:00', 'Terlaksana', 'Hari Raya Santa Perawan Maria Diangkat ke Surga.'),
            ('MIS-000117', 'JDW-03', '2026-08-16', '06:00:00', '07:10:00', 'Terlaksana', NULL),
            ('MIS-000118', 'JDW-04', '2026-08-16', '08:00:00', '09:25:00', 'Terlaksana', NULL),
            ('MIS-000119', 'JDW-05', '2026-08-16', '10:31:00', '11:34:00', 'Terlaksana', NULL),
            ('MIS-000120', 'JDW-06', '2026-08-16', '17:30:00', '18:50:00', 'Terlaksana', NULL),
            ('MIS-000121', 'JDW-07', '2026-08-19', '05:38:00', '06:18:00', 'Terlaksana', NULL),
            ('MIS-000122', 'JDW-02', '2026-08-22', '17:30:00', '18:41:00', 'Terlaksana', NULL),
            ('MIS-000123', 'JDW-03', '2026-08-23', '06:03:00', '07:24:00', 'Terlaksana', NULL),
            ('MIS-000124', 'JDW-04', '2026-08-23', '08:10:00', '09:31:00', 'Terlaksana', NULL),
            ('MIS-000125', 'JDW-05', '2026-08-23', '10:30:00', '11:27:00', 'Terlaksana', NULL),
            ('MIS-000126', 'JDW-06', '2026-08-23', '17:33:00', '18:52:00', 'Terlaksana', NULL),
            ('MIS-000127', 'JDW-07', '2026-08-26', '05:30:00', '06:11:00', 'Terlaksana', NULL),
            ('MIS-000128', 'JDW-02', '2026-08-29', '17:30:00', '18:55:00', 'Terlaksana', NULL),
            ('MIS-000129', 'JDW-03', '2026-08-30', '06:00:00', '07:20:00', 'Terlaksana', NULL),
            ('MIS-000130', 'JDW-04', '2026-08-30', '08:00:00', '09:20:00', 'Terlaksana', NULL),
            ('MIS-000131', 'JDW-05', '2026-08-30', '10:30:00', '11:37:00', 'Terlaksana', NULL),
            ('MIS-000132', 'JDW-06', '2026-08-30', '17:30:00', '18:52:00', 'Terlaksana', NULL),
            ('MIS-000133', 'JDW-07', '2026-09-02', '05:30:00', '06:23:00', 'Terlaksana', NULL),
            ('MIS-000134', 'JDW-02', '2026-09-05', '17:30:00', '18:47:00', 'Terlaksana', NULL),
            ('MIS-000135', 'JDW-03', '2026-09-06', '06:08:00', '07:22:00', 'Terlaksana', NULL),
            ('MIS-000136', 'JDW-04', '2026-09-06', '08:00:00', '09:18:00', 'Terlaksana', NULL),
            ('MIS-000137', 'JDW-05', '2026-09-06', '10:30:00', '11:29:00', 'Terlaksana', NULL),
            ('MIS-000138', 'JDW-06', '2026-09-06', '17:31:00', '18:41:00', 'Terlaksana', NULL),
            ('MIS-000139', 'JDW-07', '2026-09-09', '05:30:00', '06:23:00', 'Terlaksana', NULL),
            ('MIS-000140', 'JDW-02', '2026-09-12', '17:32:00', '18:44:00', 'Terlaksana', NULL),
            ('MIS-000141', 'JDW-03', '2026-09-13', '06:05:00', '07:31:00', 'Terlaksana', NULL),
            ('MIS-000142', 'JDW-04', '2026-09-13', '08:01:00', '09:28:00', 'Terlaksana', NULL),
            ('MIS-000143', 'JDW-05', '2026-09-13', '10:31:00', '11:32:00', 'Terlaksana', NULL),
            ('MIS-000144', 'JDW-06', '2026-09-13', '17:30:00', '18:41:00', 'Terlaksana', NULL),
            ('MIS-000145', 'JDW-07', '2026-09-16', '05:30:00', '06:26:00', 'Terlaksana', NULL),
            ('MIS-000146', 'JDW-02', '2026-09-19', '17:32:00', '18:48:00', 'Terlaksana', NULL),
            ('MIS-000147', 'JDW-03', '2026-09-20', '06:08:00', '07:19:00', 'Terlaksana', NULL),
            ('MIS-000148', 'JDW-04', '2026-09-20', '08:02:00', '09:22:00', 'Terlaksana', NULL),
            ('MIS-000149', 'JDW-05', '2026-09-20', '10:32:00', '11:43:00', 'Terlaksana', NULL),
            ('MIS-000150', 'JDW-06', '2026-09-20', '17:31:00', '18:47:00', 'Terlaksana', NULL),
            ('MIS-000151', 'JDW-07', '2026-09-23', '05:32:00', '06:17:00', 'Terlaksana', NULL),
            ('MIS-000152', 'JDW-02', '2026-09-26', '17:33:00', '18:52:00', 'Terlaksana', NULL),
            ('MIS-000153', 'JDW-03', '2026-09-27', '06:01:00', '07:23:00', 'Terlaksana', NULL),
            ('MIS-000154', 'JDW-04', '2026-09-27', '08:03:00', '09:25:00', 'Terlaksana', NULL),
            ('MIS-000155', 'JDW-05', '2026-09-27', '10:30:00', '11:40:00', 'Terlaksana', NULL),
            ('MIS-000156', 'JDW-06', '2026-09-27', '17:32:00', '18:54:00', 'Terlaksana', NULL),
            ('MIS-000157', 'JDW-07', '2026-09-30', '05:33:00', '06:21:00', 'Terlaksana', NULL),
            ('MIS-000158', 'JDW-02', '2026-10-03', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000159', 'JDW-03', '2026-10-04', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000160', 'JDW-04', '2026-10-04', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000161', 'JDW-05', '2026-10-04', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000162', 'JDW-06', '2026-10-04', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000163', 'JDW-07', '2026-10-07', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000164', 'JDW-02', '2026-10-10', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000165', 'JDW-03', '2026-10-11', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000166', 'JDW-04', '2026-10-11', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000167', 'JDW-05', '2026-10-11', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000168', 'JDW-06', '2026-10-11', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000169', 'JDW-07', '2026-10-14', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000170', 'JDW-02', '2026-10-17', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000171', 'JDW-03', '2026-10-18', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000172', 'JDW-04', '2026-10-18', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000173', 'JDW-05', '2026-10-18', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000174', 'JDW-06', '2026-10-18', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000175', 'JDW-07', '2026-10-21', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000176', 'JDW-02', '2026-10-24', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000177', 'JDW-03', '2026-10-25', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000178', 'JDW-04', '2026-10-25', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000179', 'JDW-05', '2026-10-25', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000180', 'JDW-06', '2026-10-25', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000181', 'JDW-07', '2026-10-28', NULL, NULL, 'Terjadwal', NULL),
            ('MIS-000182', 'JDW-02', '2026-10-31', NULL, NULL, 'Terjadwal', NULL)
    ) AS v (ID_KEJADIAN_MISA, ID_JADWAL_MISA, TANGGAL_MISA, WAKTU_MULAI_AKTUAL, WAKTU_SELESAI_AKTUAL, STATUS_PELAKSANAAN, KETERANGAN)
) AS s
ON t.ID_KEJADIAN_MISA = s.ID_KEJADIAN_MISA
WHEN MATCHED THEN UPDATE SET
    ID_JADWAL_MISA = s.ID_JADWAL_MISA,
    TANGGAL_MISA = s.TANGGAL_MISA,
    WAKTU_MULAI_AKTUAL = s.WAKTU_MULAI_AKTUAL,
    WAKTU_SELESAI_AKTUAL = s.WAKTU_SELESAI_AKTUAL,
    STATUS_PELAKSANAAN = s.STATUS_PELAKSANAAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_KEJADIAN_MISA, ID_JADWAL_MISA, TANGGAL_MISA, WAKTU_MULAI_AKTUAL, WAKTU_SELESAI_AKTUAL, STATUS_PELAKSANAAN, KETERANGAN)
    VALUES (s.ID_KEJADIAN_MISA, s.ID_JADWAL_MISA, s.TANGGAL_MISA, s.WAKTU_MULAI_AKTUAL, s.WAKTU_SELESAI_AKTUAL, s.STATUS_PELAKSANAAN, s.KETERANGAN);

-- DATA_OPERASIONAL.KEHADIRAN_MISA: 155 rows
MERGE INTO DATA_OPERASIONAL.KEHADIRAN_MISA AS t
USING (
    SELECT
        v.ID_KEHADIRAN AS ID_KEHADIRAN,
        v.ID_KEJADIAN_MISA AS ID_KEJADIAN_MISA,
        CAST(v.JUMLAH_UMAT AS NUMBER(6,0)) AS JUMLAH_UMAT,
        v.METODE_PENGHITUNGAN AS METODE_PENGHITUNGAN,
        v.STATUS_VALIDASI AS STATUS_VALIDASI,
        CAST(v.WAKTU_PENCATATAN AS TIMESTAMP_NTZ) AS WAKTU_PENCATATAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('KHD-000001', 'MIS-000001', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-01 06:56:00', NULL),
            ('KHD-000002', 'MIS-000002', 98, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-04 18:38:00', 'Malam Paskah (Sabtu Suci).'),
            ('KHD-000003', 'MIS-000003', 112, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-05 07:27:00', 'Hari Raya Paskah.'),
            ('KHD-000004', 'MIS-000004', 169, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-05 09:37:00', 'Hari Raya Paskah.'),
            ('KHD-000005', 'MIS-000005', 53, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-05 12:28:00', 'Hari Raya Paskah.'),
            ('KHD-000006', 'MIS-000006', 129, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-05 19:03:00', 'Hari Raya Paskah.'),
            ('KHD-000007', 'MIS-000007', 15, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-08 06:53:00', NULL),
            ('KHD-000008', 'MIS-000008', 57, 'Hitung Manual oleh Petugas', 'Perlu Dicek Ulang', '2026-04-11 19:00:00', 'Angka berbeda jauh dari pekan sebelumnya dan perlu dicek ulang petugas.'),
            ('KHD-000009', 'MIS-000009', 64, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-04-12 07:45:00', NULL),
            ('KHD-000010', 'MIS-000010', 95, 'Penghitung Klik', 'Menunggu Validasi', '2026-04-12 09:53:00', NULL),
            ('KHD-000011', 'MIS-000011', 31, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-12 12:06:00', NULL),
            ('KHD-000012', 'MIS-000012', 64, 'Perkiraan Petugas Tata Tertib', 'Menunggu Validasi', '2026-04-12 19:38:00', NULL),
            ('KHD-000013', 'MIS-000013', 13, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-15 06:56:00', NULL),
            ('KHD-000014', 'MIS-000014', 54, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-18 19:05:00', NULL),
            ('KHD-000015', 'MIS-000015', 61, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-19 07:56:00', NULL),
            ('KHD-000016', 'MIS-000016', 86, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-19 10:08:00', NULL),
            ('KHD-000017', 'MIS-000017', 27, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-19 12:20:00', NULL),
            ('KHD-000018', 'MIS-000018', 56, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-19 19:33:00', NULL),
            ('KHD-000019', 'MIS-000019', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-22 06:52:00', NULL),
            ('KHD-000020', 'MIS-000020', 52, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-25 18:51:00', NULL),
            ('KHD-000021', 'MIS-000021', 56, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-26 07:43:00', NULL),
            ('KHD-000022', 'MIS-000022', 85, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-26 09:59:00', 'Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000023', 'MIS-000023', 30, 'Penghitung Klik', 'Sudah Divalidasi', '2026-04-26 11:52:00', NULL),
            ('KHD-000024', 'MIS-000024', 65, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-26 19:17:00', NULL),
            ('KHD-000025', 'MIS-000025', 15, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-04-29 06:40:00', NULL),
            ('KHD-000026', 'MIS-000026', 53, 'Penghitung Klik', 'Sudah Divalidasi', '2026-05-02 19:04:00', NULL),
            ('KHD-000027', 'MIS-000027', 67, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-03 07:38:00', NULL),
            ('KHD-000028', 'MIS-000028', 92, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-03 10:00:00', NULL),
            ('KHD-000029', 'MIS-000029', 30, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-03 12:06:00', NULL),
            ('KHD-000030', 'MIS-000030', 63, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-05-03 19:51:00', NULL),
            ('KHD-000031', 'MIS-000031', 15, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-06 06:42:00', NULL),
            ('KHD-000032', 'MIS-000032', 52, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-09 19:15:00', NULL),
            ('KHD-000033', 'MIS-000033', 70, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-10 07:41:00', NULL),
            ('KHD-000034', 'MIS-000034', 97, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-10 09:22:00', NULL),
            ('KHD-000035', 'MIS-000035', 27, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-10 12:17:00', NULL),
            ('KHD-000036', 'MIS-000036', 57, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-10 18:58:00', NULL),
            ('KHD-000037', 'MIS-000037', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-13 07:18:00', NULL),
            ('KHD-000038', 'MIS-000038', 51, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-16 18:41:00', NULL),
            ('KHD-000039', 'MIS-000039', 48, 'Penghitung Klik', 'Menunggu Validasi', '2026-05-17 07:23:00', 'Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000040', 'MIS-000040', 102, 'Penghitung Klik', 'Menunggu Validasi', '2026-05-17 10:04:00', NULL),
            ('KHD-000041', 'MIS-000041', 30, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-17 11:49:00', NULL),
            ('KHD-000042', 'MIS-000042', 68, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-05-17 19:36:00', NULL),
            ('KHD-000043', 'MIS-000043', 13, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-20 06:49:00', NULL),
            ('KHD-000044', 'MIS-000044', 62, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-23 19:02:00', NULL),
            ('KHD-000045', 'MIS-000045', 68, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-05-24 07:34:00', 'Hari Raya Pentakosta.'),
            ('KHD-000046', 'MIS-000046', 120, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-05-24 09:37:00', 'Hari Raya Pentakosta.'),
            ('KHD-000047', 'MIS-000047', 42, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-05-24 12:11:00', 'Hari Raya Pentakosta.'),
            ('KHD-000048', 'MIS-000048', 60, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-24 19:41:00', 'Hari Raya Pentakosta.'),
            ('KHD-000049', 'MIS-000049', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-27 07:11:00', NULL),
            ('KHD-000050', 'MIS-000050', 46, 'Penghitung Klik', 'Sudah Divalidasi', '2026-05-30 19:06:00', 'Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000051', 'MIS-000051', 65, 'Penghitung Klik', 'Sudah Divalidasi', '2026-05-31 07:47:00', NULL),
            ('KHD-000052', 'MIS-000052', 108, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-05-31 09:26:00', NULL),
            ('KHD-000053', 'MIS-000053', 29, 'Penghitung Klik', 'Sudah Divalidasi', '2026-05-31 11:53:00', NULL),
            ('KHD-000054', 'MIS-000054', 63, 'Penghitung Klik', 'Sudah Divalidasi', '2026-05-31 19:13:00', NULL),
            ('KHD-000055', 'MIS-000055', 14, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-06-03 06:46:00', NULL),
            ('KHD-000056', 'MIS-000056', 52, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-06 18:47:00', NULL),
            ('KHD-000057', 'MIS-000057', 72, 'Penghitung Klik', 'Sudah Divalidasi', '2026-06-07 07:38:00', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('KHD-000058', 'MIS-000058', 102, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-07 09:53:00', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('KHD-000059', 'MIS-000059', 38, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-07 12:11:00', 'Hari Raya Tubuh dan Darah Kristus.'),
            ('KHD-000060', 'MIS-000060', 53, 'Penghitung Klik', 'Sudah Divalidasi', '2026-06-07 19:24:00', 'Hari Raya Tubuh dan Darah Kristus. Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000061', 'MIS-000061', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-10 06:30:00', NULL),
            ('KHD-000062', 'MIS-000062', 52, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-13 18:40:00', NULL),
            ('KHD-000063', 'MIS-000063', 62, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-14 08:03:00', NULL),
            ('KHD-000064', 'MIS-000064', 103, 'Penghitung Klik', 'Sudah Divalidasi', '2026-06-14 09:52:00', NULL),
            ('KHD-000065', 'MIS-000065', 23, 'Penghitung Klik', 'Sudah Divalidasi', '2026-06-14 12:31:00', 'Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000066', 'MIS-000066', 57, 'Penghitung Klik', 'Sudah Divalidasi', '2026-06-14 19:22:00', NULL),
            ('KHD-000067', 'MIS-000067', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-17 07:13:00', NULL),
            ('KHD-000068', 'MIS-000068', 53, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-20 19:10:00', NULL),
            ('KHD-000069', 'MIS-000069', 49, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-21 08:17:00', NULL),
            ('KHD-000070', 'MIS-000070', 86, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-21 10:14:00', NULL),
            ('KHD-000071', 'MIS-000071', 28, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-21 12:03:00', NULL),
            ('KHD-000072', 'MIS-000072', 46, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-21 19:26:00', NULL),
            ('KHD-000073', 'MIS-000073', 13, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-24 06:22:00', NULL),
            ('KHD-000074', 'MIS-000074', 45, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-27 18:56:00', NULL),
            ('KHD-000075', 'MIS-000075', 54, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-28 07:52:00', NULL),
            ('KHD-000076', 'MIS-000076', 80, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-06-28 09:46:00', NULL),
            ('KHD-000077', 'MIS-000077', 24, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-28 12:18:00', NULL),
            ('KHD-000078', 'MIS-000078', 51, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-06-28 19:34:00', NULL),
            ('KHD-000079', 'MIS-000080', 48, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-04 18:58:00', NULL),
            ('KHD-000080', 'MIS-000081', 57, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-05 07:36:00', NULL),
            ('KHD-000081', 'MIS-000082', 83, 'Hitung Manual oleh Petugas', 'Perlu Dicek Ulang', '2026-07-05 09:50:00', 'Angka berbeda jauh dari pekan sebelumnya dan perlu dicek ulang petugas.'),
            ('KHD-000082', 'MIS-000083', 26, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-07-05 11:46:00', NULL),
            ('KHD-000083', 'MIS-000084', 56, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-05 19:02:00', NULL),
            ('KHD-000084', 'MIS-000085', 11, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-08 06:33:00', NULL),
            ('KHD-000085', 'MIS-000086', 46, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-11 19:01:00', NULL),
            ('KHD-000086', 'MIS-000087', 53, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-12 07:21:00', NULL),
            ('KHD-000087', 'MIS-000088', 65, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-12 09:55:00', 'Hujan deras sejak pagi, jumlah umat berkurang.'),
            ('KHD-000088', 'MIS-000089', 29, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-12 12:23:00', NULL),
            ('KHD-000089', 'MIS-000090', 53, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-12 19:20:00', NULL),
            ('KHD-000090', 'MIS-000091', 13, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-15 06:37:00', NULL),
            ('KHD-000091', 'MIS-000092', 54, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-07-18 19:23:00', NULL),
            ('KHD-000092', 'MIS-000093', 56, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-19 07:40:00', NULL),
            ('KHD-000093', 'MIS-000094', 92, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-19 09:45:00', NULL),
            ('KHD-000094', 'MIS-000095', 28, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-19 12:04:00', NULL),
            ('KHD-000095', 'MIS-000097', 15, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-22 06:38:00', NULL),
            ('KHD-000096', 'MIS-000098', 53, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-07-25 19:11:00', NULL),
            ('KHD-000097', 'MIS-000099', 67, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-26 08:06:00', NULL),
            ('KHD-000098', 'MIS-000100', 93, 'Penghitung Klik', 'Sudah Divalidasi', '2026-07-26 09:57:00', NULL),
            ('KHD-000099', 'MIS-000101', 31, 'Penghitung Klik', 'Menunggu Validasi', '2026-07-26 12:17:00', NULL),
            ('KHD-000100', 'MIS-000102', 59, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-26 19:09:00', NULL),
            ('KHD-000101', 'MIS-000103', 16, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-07-29 07:00:00', NULL),
            ('KHD-000102', 'MIS-000104', 57, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-01 19:49:00', NULL),
            ('KHD-000103', 'MIS-000105', 54, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-02 07:45:00', NULL),
            ('KHD-000104', 'MIS-000106', 86, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-02 09:32:00', NULL),
            ('KHD-000105', 'MIS-000107', 28, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-02 11:55:00', NULL),
            ('KHD-000106', 'MIS-000108', 67, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-02 19:39:00', NULL),
            ('KHD-000107', 'MIS-000109', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-05 07:17:00', NULL),
            ('KHD-000108', 'MIS-000110', 55, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-08 19:41:00', NULL),
            ('KHD-000109', 'MIS-000111', 74, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-09 07:37:00', NULL),
            ('KHD-000110', 'MIS-000112', 97, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-09 10:24:00', NULL),
            ('KHD-000111', 'MIS-000113', 30, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-09 12:23:00', NULL),
            ('KHD-000112', 'MIS-000114', 60, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-09 19:38:00', NULL),
            ('KHD-000113', 'MIS-000115', 16, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-12 07:13:00', NULL),
            ('KHD-000114', 'MIS-000116', 63, 'Penghitung Klik', 'Perlu Dicek Ulang', '2026-08-15 19:41:00', 'Hari Raya Santa Perawan Maria Diangkat ke Surga. Angka berbeda jauh dari pekan sebelumnya dan perlu dicek ulang petugas.'),
            ('KHD-000115', 'MIS-000117', 60, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-16 08:01:00', NULL),
            ('KHD-000116', 'MIS-000118', 96, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-16 09:52:00', NULL),
            ('KHD-000117', 'MIS-000119', 30, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-16 12:15:00', NULL),
            ('KHD-000118', 'MIS-000120', 61, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-16 19:05:00', NULL),
            ('KHD-000119', 'MIS-000121', 15, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-19 06:53:00', NULL),
            ('KHD-000120', 'MIS-000122', 52, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-22 19:15:00', NULL),
            ('KHD-000121', 'MIS-000123', 59, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-23 08:20:00', NULL),
            ('KHD-000122', 'MIS-000124', 91, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-23 10:02:00', NULL),
            ('KHD-000123', 'MIS-000125', 29, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-08-23 12:27:00', NULL),
            ('KHD-000124', 'MIS-000126', 65, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-23 19:14:00', NULL),
            ('KHD-000125', 'MIS-000127', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-26 06:41:00', NULL),
            ('KHD-000126', 'MIS-000128', 56, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-29 19:31:00', NULL),
            ('KHD-000127', 'MIS-000129', 64, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-08-30 07:33:00', NULL),
            ('KHD-000128', 'MIS-000130', 90, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-30 09:54:00', NULL),
            ('KHD-000129', 'MIS-000131', 26, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-08-30 11:47:00', NULL),
            ('KHD-000130', 'MIS-000132', 56, 'Penghitung Klik', 'Sudah Divalidasi', '2026-08-30 19:27:00', NULL),
            ('KHD-000131', 'MIS-000133', 15, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-09-02 07:16:00', NULL),
            ('KHD-000132', 'MIS-000134', 56, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-05 19:16:00', NULL),
            ('KHD-000133', 'MIS-000135', 62, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-09-06 07:30:00', NULL),
            ('KHD-000134', 'MIS-000136', 98, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-06 10:13:00', NULL),
            ('KHD-000135', 'MIS-000137', 31, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-06 11:57:00', NULL),
            ('KHD-000136', 'MIS-000138', 60, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-06 19:14:00', NULL),
            ('KHD-000137', 'MIS-000139', 14, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-09 07:12:00', NULL),
            ('KHD-000138', 'MIS-000140', 56, 'Penghitung Klik', 'Menunggu Validasi', '2026-09-12 18:58:00', NULL),
            ('KHD-000139', 'MIS-000141', 63, 'Penghitung Klik', 'Menunggu Validasi', '2026-09-13 08:24:00', NULL),
            ('KHD-000140', 'MIS-000142', 96, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-13 10:00:00', NULL),
            ('KHD-000141', 'MIS-000143', 31, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-13 12:18:00', NULL),
            ('KHD-000142', 'MIS-000144', 64, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-13 18:57:00', NULL),
            ('KHD-000143', 'MIS-000145', 16, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-09-16 07:01:00', NULL),
            ('KHD-000144', 'MIS-000146', 54, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-19 19:40:00', NULL),
            ('KHD-000145', 'MIS-000147', 57, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-09-20 08:01:00', NULL),
            ('KHD-000146', 'MIS-000148', 88, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-20 09:38:00', NULL),
            ('KHD-000147', 'MIS-000149', 29, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-09-20 12:28:00', NULL),
            ('KHD-000148', 'MIS-000150', 63, 'Hitung Manual oleh Petugas', 'Menunggu Validasi', '2026-09-20 19:23:00', NULL),
            ('KHD-000149', 'MIS-000151', 13, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-23 06:52:00', NULL),
            ('KHD-000150', 'MIS-000152', 52, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-26 19:28:00', NULL),
            ('KHD-000151', 'MIS-000153', 68, 'Perkiraan Petugas Tata Tertib', 'Sudah Divalidasi', '2026-09-27 07:43:00', NULL),
            ('KHD-000152', 'MIS-000154', 99, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-27 10:05:00', NULL),
            ('KHD-000153', 'MIS-000155', 33, 'Penghitung Klik', 'Sudah Divalidasi', '2026-09-27 11:49:00', NULL),
            ('KHD-000154', 'MIS-000156', 64, 'Penghitung Klik', 'Menunggu Validasi', '2026-09-27 19:33:00', NULL),
            ('KHD-000155', 'MIS-000157', 17, 'Hitung Manual oleh Petugas', 'Sudah Divalidasi', '2026-09-30 06:26:00', NULL)
    ) AS v (ID_KEHADIRAN, ID_KEJADIAN_MISA, JUMLAH_UMAT, METODE_PENGHITUNGAN, STATUS_VALIDASI, WAKTU_PENCATATAN, KETERANGAN)
) AS s
ON t.ID_KEHADIRAN = s.ID_KEHADIRAN
WHEN MATCHED THEN UPDATE SET
    ID_KEJADIAN_MISA = s.ID_KEJADIAN_MISA,
    JUMLAH_UMAT = s.JUMLAH_UMAT,
    METODE_PENGHITUNGAN = s.METODE_PENGHITUNGAN,
    STATUS_VALIDASI = s.STATUS_VALIDASI,
    WAKTU_PENCATATAN = s.WAKTU_PENCATATAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_KEHADIRAN, ID_KEJADIAN_MISA, JUMLAH_UMAT, METODE_PENGHITUNGAN, STATUS_VALIDASI, WAKTU_PENCATATAN, KETERANGAN)
    VALUES (s.ID_KEHADIRAN, s.ID_KEJADIAN_MISA, s.JUMLAH_UMAT, s.METODE_PENGHITUNGAN, s.STATUS_VALIDASI, s.WAKTU_PENCATATAN, s.KETERANGAN);

-- DATA_OPERASIONAL.PENERIMAAN_KOLEKTE: 292 rows
MERGE INTO DATA_OPERASIONAL.PENERIMAAN_KOLEKTE AS t
USING (
    SELECT
        v.ID_KOLEKTE AS ID_KOLEKTE,
        v.ID_KEJADIAN_MISA AS ID_KEJADIAN_MISA,
        v.ID_JENIS_KOLEKTE AS ID_JENIS_KOLEKTE,
        CAST(v.JUMLAH_PENERIMAAN AS NUMBER(18,0)) AS JUMLAH_PENERIMAAN,
        CAST(v.JUMLAH_HASIL_PENGHITUNGAN AS NUMBER(18,0)) AS JUMLAH_HASIL_PENGHITUNGAN,
        v.STATUS_REKONSILIASI AS STATUS_REKONSILIASI,
        CAST(v.TANGGAL_PENCATATAN AS DATE) AS TANGGAL_PENCATATAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('KLK-000001', 'MIS-000001', 'KOL-01', 236000, 236000, 'Sudah Cocok', '2026-04-02', NULL),
            ('KLK-000002', 'MIS-000002', 'KOL-01', 1393500, 1393500, 'Sudah Cocok', '2026-04-05', NULL),
            ('KLK-000003', 'MIS-000002', 'KOL-02', 618500, 618500, 'Sudah Cocok', '2026-04-05', NULL),
            ('KLK-000004', 'MIS-000003', 'KOL-01', 1932000, 1835500, 'Selisih Sedang Ditelusuri', '2026-04-06', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000005', 'MIS-000003', 'KOL-02', 746500, 746500, 'Sudah Cocok', '2026-04-06', NULL),
            ('KLK-000006', 'MIS-000004', 'KOL-01', 2238000, 2238000, 'Sudah Cocok', '2026-04-07', NULL),
            ('KLK-000007', 'MIS-000004', 'KOL-02', 1142000, 1142000, 'Sudah Cocok', '2026-04-07', NULL),
            ('KLK-000008', 'MIS-000005', 'KOL-01', 692000, 692000, 'Sudah Cocok', '2026-04-06', NULL),
            ('KLK-000009', 'MIS-000005', 'KOL-02', 275000, 275000, 'Sudah Cocok', '2026-04-06', NULL),
            ('KLK-000010', 'MIS-000006', 'KOL-01', 2177000, 2270500, 'Selisih Sedang Ditelusuri', '2026-04-07', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000011', 'MIS-000006', 'KOL-02', 865500, 865500, 'Sudah Cocok', '2026-04-07', NULL),
            ('KLK-000012', 'MIS-000007', 'KOL-01', 240500, 240500, 'Sudah Cocok', '2026-04-10', NULL),
            ('KLK-000013', 'MIS-000008', 'KOL-01', 956000, 956000, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000014', 'MIS-000008', 'KOL-02', 408000, 408000, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000015', 'MIS-000009', 'KOL-01', 947500, 947500, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000016', 'MIS-000009', 'KOL-02', 311000, 311000, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000017', 'MIS-000010', 'KOL-01', 1535500, 1597500, 'Selisih Sedang Ditelusuri', '2026-04-13', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000018', 'MIS-000010', 'KOL-02', 568500, 568500, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000019', 'MIS-000011', 'KOL-01', 426000, 426000, 'Sudah Cocok', '2026-04-14', NULL),
            ('KLK-000020', 'MIS-000011', 'KOL-02', 141500, 141500, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000021', 'MIS-000012', 'KOL-01', 891000, 891000, 'Sudah Cocok', '2026-04-14', NULL),
            ('KLK-000022', 'MIS-000012', 'KOL-02', 398000, 398000, 'Sudah Cocok', '2026-04-13', NULL),
            ('KLK-000023', 'MIS-000013', 'KOL-01', 206500, 206500, 'Sudah Cocok', '2026-04-16', NULL),
            ('KLK-000024', 'MIS-000014', 'KOL-01', 745500, 745500, 'Sudah Cocok', '2026-04-19', NULL),
            ('KLK-000025', 'MIS-000014', 'KOL-02', 318000, 318000, 'Sudah Cocok', '2026-04-20', NULL),
            ('KLK-000026', 'MIS-000015', 'KOL-01', 877500, 877500, 'Sudah Cocok', '2026-04-21', NULL),
            ('KLK-000027', 'MIS-000015', 'KOL-02', 335000, 335000, 'Sudah Cocok', '2026-04-20', NULL),
            ('KLK-000028', 'MIS-000016', 'KOL-01', 1002500, 945000, 'Selisih Sedang Ditelusuri', '2026-04-21', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000029', 'MIS-000016', 'KOL-02', 531500, 531000, 'Selisih Disetujui', '2026-04-20', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000030', 'MIS-000017', 'KOL-01', 369500, 369500, 'Sudah Cocok', '2026-04-21', NULL),
            ('KLK-000031', 'MIS-000017', 'KOL-02', 148000, 148000, 'Sudah Cocok', '2026-04-20', NULL),
            ('KLK-000032', 'MIS-000018', 'KOL-01', 781500, 781500, 'Sudah Cocok', '2026-04-21', NULL),
            ('KLK-000033', 'MIS-000018', 'KOL-02', 389500, 389500, 'Sudah Cocok', '2026-04-21', NULL),
            ('KLK-000034', 'MIS-000019', 'KOL-01', 229000, 229000, 'Sudah Cocok', '2026-04-24', NULL),
            ('KLK-000035', 'MIS-000020', 'KOL-01', 778000, 778000, 'Sudah Cocok', '2026-04-27', NULL),
            ('KLK-000036', 'MIS-000020', 'KOL-02', 338500, 338500, 'Sudah Cocok', '2026-04-26', NULL),
            ('KLK-000037', 'MIS-000021', 'KOL-01', 860000, 860000, 'Sudah Cocok', '2026-04-28', NULL),
            ('KLK-000038', 'MIS-000021', 'KOL-02', 427000, 427000, 'Sudah Cocok', '2026-04-28', NULL),
            ('KLK-000039', 'MIS-000021', 'KOL-03', 442000, 442000, 'Sudah Cocok', '2026-04-28', 'Kolekte khusus Hari Minggu Panggilan.'),
            ('KLK-000040', 'MIS-000022', 'KOL-01', 1009500, NULL, 'Belum Dihitung', '2026-04-26', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000041', 'MIS-000022', 'KOL-02', 591500, 592000, 'Selisih Disetujui', '2026-04-27', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000042', 'MIS-000022', 'KOL-03', 688000, 688000, 'Sudah Cocok', '2026-04-27', 'Kolekte khusus Hari Minggu Panggilan.'),
            ('KLK-000043', 'MIS-000023', 'KOL-01', 483000, 483000, 'Sudah Cocok', '2026-04-28', NULL),
            ('KLK-000044', 'MIS-000023', 'KOL-02', 233500, 221000, 'Selisih Sedang Ditelusuri', '2026-04-28', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000045', 'MIS-000023', 'KOL-03', 304000, 304000, 'Sudah Cocok', '2026-04-27', 'Kolekte khusus Hari Minggu Panggilan.'),
            ('KLK-000046', 'MIS-000024', 'KOL-01', 823000, NULL, 'Belum Dihitung', '2026-04-26', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000047', 'MIS-000024', 'KOL-02', 437500, NULL, 'Belum Dihitung', '2026-04-26', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000048', 'MIS-000024', 'KOL-03', 589000, 589000, 'Sudah Cocok', '2026-04-27', 'Kolekte khusus Hari Minggu Panggilan.'),
            ('KLK-000049', 'MIS-000025', 'KOL-01', 259000, 259000, 'Sudah Cocok', '2026-05-01', NULL),
            ('KLK-000050', 'MIS-000026', 'KOL-01', 713000, 713000, 'Sudah Cocok', '2026-05-03', NULL),
            ('KLK-000051', 'MIS-000026', 'KOL-02', 397000, 397000, 'Sudah Cocok', '2026-05-03', NULL),
            ('KLK-000052', 'MIS-000027', 'KOL-01', 997000, 997000, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000053', 'MIS-000027', 'KOL-02', 415500, 415500, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000054', 'MIS-000028', 'KOL-01', 1310500, 1310500, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000055', 'MIS-000028', 'KOL-02', 628000, 628000, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000056', 'MIS-000029', 'KOL-01', 407000, 407000, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000057', 'MIS-000029', 'KOL-02', 204000, 204000, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000058', 'MIS-000030', 'KOL-01', 622000, 622000, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000059', 'MIS-000030', 'KOL-02', 434500, 434500, 'Sudah Cocok', '2026-05-05', NULL),
            ('KLK-000060', 'MIS-000031', 'KOL-01', 227500, 227500, 'Sudah Cocok', '2026-05-08', NULL),
            ('KLK-000061', 'MIS-000032', 'KOL-01', 747500, 722500, 'Selisih Sedang Ditelusuri', '2026-05-10', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000062', 'MIS-000032', 'KOL-02', 331000, 329000, 'Selisih Disetujui', '2026-05-10', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000063', 'MIS-000033', 'KOL-01', 617500, 617500, 'Sudah Cocok', '2026-05-11', NULL),
            ('KLK-000064', 'MIS-000033', 'KOL-02', 422000, 422000, 'Sudah Cocok', '2026-05-12', NULL),
            ('KLK-000065', 'MIS-000034', 'KOL-01', 1182000, 1182000, 'Sudah Cocok', '2026-05-11', NULL),
            ('KLK-000066', 'MIS-000034', 'KOL-02', 538500, 538500, 'Sudah Cocok', '2026-05-11', NULL),
            ('KLK-000067', 'MIS-000035', 'KOL-01', 322500, 322500, 'Sudah Cocok', '2026-05-11', NULL),
            ('KLK-000068', 'MIS-000035', 'KOL-02', 166000, 166500, 'Selisih Disetujui', '2026-05-12', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000069', 'MIS-000036', 'KOL-01', 877500, 877500, 'Sudah Cocok', '2026-05-12', NULL),
            ('KLK-000070', 'MIS-000036', 'KOL-02', 403000, 403000, 'Sudah Cocok', '2026-05-12', NULL),
            ('KLK-000071', 'MIS-000037', 'KOL-01', 199000, 199000, 'Sudah Cocok', '2026-05-15', NULL),
            ('KLK-000072', 'MIS-000038', 'KOL-01', 736000, 736000, 'Sudah Cocok', '2026-05-18', NULL),
            ('KLK-000073', 'MIS-000038', 'KOL-02', 320500, 320500, 'Sudah Cocok', '2026-05-18', NULL),
            ('KLK-000074', 'MIS-000039', 'KOL-01', 652000, 652000, 'Sudah Cocok', '2026-05-19', NULL),
            ('KLK-000075', 'MIS-000039', 'KOL-02', 282000, 271500, 'Selisih Sedang Ditelusuri', '2026-05-19', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000076', 'MIS-000039', 'KOL-03', 378500, 378500, 'Sudah Cocok', '2026-05-18', 'Kolekte khusus Hari Komunikasi Sosial Sedunia.'),
            ('KLK-000077', 'MIS-000040', 'KOL-01', 1498000, 1502000, 'Selisih Disetujui', '2026-05-18', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000078', 'MIS-000040', 'KOL-02', 699500, 699500, 'Sudah Cocok', '2026-05-19', NULL),
            ('KLK-000079', 'MIS-000040', 'KOL-03', 735500, NULL, 'Belum Dihitung', '2026-05-17', 'Kolekte khusus Hari Komunikasi Sosial Sedunia. Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000080', 'MIS-000041', 'KOL-01', 413000, 413000, 'Sudah Cocok', '2026-05-19', NULL),
            ('KLK-000081', 'MIS-000041', 'KOL-02', 195500, 195500, 'Sudah Cocok', '2026-05-18', NULL),
            ('KLK-000082', 'MIS-000041', 'KOL-03', 251500, 251500, 'Sudah Cocok', '2026-05-19', 'Kolekte khusus Hari Komunikasi Sosial Sedunia.'),
            ('KLK-000083', 'MIS-000042', 'KOL-01', 1049500, 1049500, 'Sudah Cocok', '2026-05-19', NULL),
            ('KLK-000084', 'MIS-000042', 'KOL-02', 363500, 363500, 'Sudah Cocok', '2026-05-18', NULL),
            ('KLK-000085', 'MIS-000042', 'KOL-03', 749500, 749500, 'Sudah Cocok', '2026-05-19', 'Kolekte khusus Hari Komunikasi Sosial Sedunia.'),
            ('KLK-000086', 'MIS-000043', 'KOL-01', 173000, 173000, 'Sudah Cocok', '2026-05-22', NULL),
            ('KLK-000087', 'MIS-000044', 'KOL-01', 881500, 881500, 'Sudah Cocok', '2026-05-25', NULL),
            ('KLK-000088', 'MIS-000044', 'KOL-02', 341000, 341000, 'Sudah Cocok', '2026-05-24', NULL),
            ('KLK-000089', 'MIS-000045', 'KOL-01', 1200500, 1200500, 'Sudah Cocok', '2026-05-26', NULL),
            ('KLK-000090', 'MIS-000045', 'KOL-02', 455500, 455500, 'Sudah Cocok', '2026-05-25', NULL),
            ('KLK-000091', 'MIS-000046', 'KOL-01', 1893500, 1893500, 'Sudah Cocok', '2026-05-25', NULL),
            ('KLK-000092', 'MIS-000046', 'KOL-02', 580000, 580000, 'Sudah Cocok', '2026-05-26', NULL),
            ('KLK-000093', 'MIS-000047', 'KOL-01', 598000, 598000, 'Sudah Cocok', '2026-05-26', NULL),
            ('KLK-000094', 'MIS-000047', 'KOL-02', 252000, 239000, 'Selisih Sedang Ditelusuri', '2026-05-26', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000095', 'MIS-000048', 'KOL-01', 900000, 900000, 'Sudah Cocok', '2026-05-25', NULL),
            ('KLK-000096', 'MIS-000048', 'KOL-02', 524000, 524000, 'Sudah Cocok', '2026-05-25', NULL),
            ('KLK-000097', 'MIS-000049', 'KOL-01', 195500, 195500, 'Sudah Cocok', '2026-05-28', NULL),
            ('KLK-000098', 'MIS-000050', 'KOL-01', 737000, 737000, 'Sudah Cocok', '2026-06-01', NULL),
            ('KLK-000099', 'MIS-000050', 'KOL-02', 235000, 235000, 'Sudah Cocok', '2026-05-31', NULL),
            ('KLK-000100', 'MIS-000051', 'KOL-01', 903000, 903000, 'Sudah Cocok', '2026-06-02', NULL),
            ('KLK-000101', 'MIS-000051', 'KOL-02', 341000, NULL, 'Belum Dihitung', '2026-05-31', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000102', 'MIS-000052', 'KOL-01', 1816000, 1816000, 'Sudah Cocok', '2026-06-01', NULL),
            ('KLK-000103', 'MIS-000052', 'KOL-02', 596000, 596000, 'Sudah Cocok', '2026-06-02', NULL),
            ('KLK-000104', 'MIS-000053', 'KOL-01', 368500, 368500, 'Sudah Cocok', '2026-06-02', NULL),
            ('KLK-000105', 'MIS-000053', 'KOL-02', 188000, 188000, 'Sudah Cocok', '2026-06-02', NULL),
            ('KLK-000106', 'MIS-000054', 'KOL-01', 1009500, 1009500, 'Sudah Cocok', '2026-06-01', NULL),
            ('KLK-000107', 'MIS-000054', 'KOL-02', 347000, 347000, 'Sudah Cocok', '2026-06-01', NULL),
            ('KLK-000108', 'MIS-000055', 'KOL-01', 250000, 251500, 'Selisih Disetujui', '2026-06-04', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000109', 'MIS-000056', 'KOL-01', 823500, 823500, 'Sudah Cocok', '2026-06-07', NULL),
            ('KLK-000110', 'MIS-000056', 'KOL-02', 327500, 327500, 'Sudah Cocok', '2026-06-08', NULL),
            ('KLK-000111', 'MIS-000057', 'KOL-01', 973500, 973500, 'Sudah Cocok', '2026-06-08', NULL),
            ('KLK-000112', 'MIS-000057', 'KOL-02', 485000, 484500, 'Selisih Disetujui', '2026-06-09', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000113', 'MIS-000058', 'KOL-01', 1550000, 1550000, 'Sudah Cocok', '2026-06-08', NULL),
            ('KLK-000114', 'MIS-000058', 'KOL-02', 672500, 672500, 'Sudah Cocok', '2026-06-09', NULL),
            ('KLK-000115', 'MIS-000059', 'KOL-01', 595000, 595000, 'Sudah Cocok', '2026-06-08', NULL),
            ('KLK-000116', 'MIS-000059', 'KOL-02', 274000, 274000, 'Sudah Cocok', '2026-06-09', NULL),
            ('KLK-000117', 'MIS-000060', 'KOL-01', 810500, 810500, 'Sudah Cocok', '2026-06-09', NULL),
            ('KLK-000118', 'MIS-000060', 'KOL-02', 286000, 286000, 'Sudah Cocok', '2026-06-09', NULL),
            ('KLK-000119', 'MIS-000061', 'KOL-01', 225500, 225500, 'Sudah Cocok', '2026-06-11', NULL),
            ('KLK-000120', 'MIS-000062', 'KOL-01', 887000, 887000, 'Sudah Cocok', '2026-06-14', NULL),
            ('KLK-000121', 'MIS-000062', 'KOL-02', 370000, 370000, 'Sudah Cocok', '2026-06-14', NULL),
            ('KLK-000122', 'MIS-000063', 'KOL-01', 772000, 799000, 'Selisih Sedang Ditelusuri', '2026-06-16', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000123', 'MIS-000063', 'KOL-02', 384000, 384000, 'Sudah Cocok', '2026-06-16', NULL),
            ('KLK-000124', 'MIS-000064', 'KOL-01', 1451500, 1451500, 'Sudah Cocok', '2026-06-15', NULL),
            ('KLK-000125', 'MIS-000064', 'KOL-02', 673500, 673500, 'Sudah Cocok', '2026-06-15', NULL),
            ('KLK-000126', 'MIS-000065', 'KOL-01', 311500, 311500, 'Sudah Cocok', '2026-06-15', NULL),
            ('KLK-000127', 'MIS-000065', 'KOL-02', 130500, 130500, 'Sudah Cocok', '2026-06-15', NULL),
            ('KLK-000128', 'MIS-000066', 'KOL-01', 685500, 680500, 'Selisih Disetujui', '2026-06-15', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000129', 'MIS-000066', 'KOL-02', 372000, NULL, 'Belum Dihitung', '2026-06-14', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000130', 'MIS-000067', 'KOL-01', 199500, 199500, 'Sudah Cocok', '2026-06-19', NULL),
            ('KLK-000131', 'MIS-000068', 'KOL-01', 576500, 576500, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000132', 'MIS-000068', 'KOL-02', 327500, 327500, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000133', 'MIS-000069', 'KOL-01', 594500, 594500, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000134', 'MIS-000069', 'KOL-02', 333000, 333000, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000135', 'MIS-000070', 'KOL-01', 1099500, NULL, 'Belum Dihitung', '2026-06-21', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000136', 'MIS-000070', 'KOL-02', 507000, 507000, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000137', 'MIS-000071', 'KOL-01', 441000, 441000, 'Sudah Cocok', '2026-06-23', NULL),
            ('KLK-000138', 'MIS-000071', 'KOL-02', 157000, 157000, 'Sudah Cocok', '2026-06-22', NULL),
            ('KLK-000139', 'MIS-000072', 'KOL-01', 712500, 712500, 'Sudah Cocok', '2026-06-23', NULL),
            ('KLK-000140', 'MIS-000072', 'KOL-02', 249000, 249000, 'Sudah Cocok', '2026-06-23', NULL),
            ('KLK-000141', 'MIS-000073', 'KOL-01', 140000, 140000, 'Sudah Cocok', '2026-06-25', NULL),
            ('KLK-000142', 'MIS-000074', 'KOL-01', 694000, NULL, 'Belum Dihitung', '2026-06-27', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000143', 'MIS-000074', 'KOL-02', 313000, 313000, 'Sudah Cocok', '2026-06-28', NULL),
            ('KLK-000144', 'MIS-000075', 'KOL-01', 844500, 844500, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000145', 'MIS-000075', 'KOL-02', 375000, 375000, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000146', 'MIS-000076', 'KOL-01', 1251000, 1316000, 'Selisih Sedang Ditelusuri', '2026-06-30', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000147', 'MIS-000076', 'KOL-02', 465500, 465500, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000148', 'MIS-000077', 'KOL-01', 358000, 358000, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000149', 'MIS-000077', 'KOL-02', 155000, 155000, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000150', 'MIS-000078', 'KOL-01', 732000, 732000, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000151', 'MIS-000078', 'KOL-02', 268500, 268500, 'Sudah Cocok', '2026-06-30', NULL),
            ('KLK-000152', 'MIS-000080', 'KOL-01', 666000, 666000, 'Sudah Cocok', '2026-07-05', NULL),
            ('KLK-000153', 'MIS-000080', 'KOL-02', 299500, 299500, 'Sudah Cocok', '2026-07-05', NULL),
            ('KLK-000154', 'MIS-000081', 'KOL-01', 708500, 708500, 'Sudah Cocok', '2026-07-07', NULL),
            ('KLK-000155', 'MIS-000081', 'KOL-02', 410500, 410500, 'Sudah Cocok', '2026-07-06', NULL),
            ('KLK-000156', 'MIS-000082', 'KOL-01', 907500, 907500, 'Sudah Cocok', '2026-07-07', NULL),
            ('KLK-000157', 'MIS-000082', 'KOL-02', 673500, 673500, 'Sudah Cocok', '2026-07-06', NULL),
            ('KLK-000158', 'MIS-000083', 'KOL-01', 313000, 313000, 'Sudah Cocok', '2026-07-06', NULL),
            ('KLK-000159', 'MIS-000083', 'KOL-02', 165000, 164500, 'Selisih Disetujui', '2026-07-06', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000160', 'MIS-000084', 'KOL-01', 700500, 700500, 'Sudah Cocok', '2026-07-06', NULL),
            ('KLK-000161', 'MIS-000084', 'KOL-02', 364500, NULL, 'Belum Dihitung', '2026-07-05', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000162', 'MIS-000085', 'KOL-01', 113000, 113000, 'Sudah Cocok', '2026-07-10', NULL),
            ('KLK-000163', 'MIS-000086', 'KOL-01', 559000, 559000, 'Sudah Cocok', '2026-07-12', NULL),
            ('KLK-000164', 'MIS-000086', 'KOL-02', 231000, 231000, 'Sudah Cocok', '2026-07-13', NULL),
            ('KLK-000165', 'MIS-000087', 'KOL-01', 808500, 808500, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000166', 'MIS-000087', 'KOL-02', 282500, 282500, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000167', 'MIS-000088', 'KOL-01', 879000, 879000, 'Sudah Cocok', '2026-07-13', NULL),
            ('KLK-000168', 'MIS-000088', 'KOL-02', 444500, 444500, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000169', 'MIS-000089', 'KOL-01', 482000, 482000, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000170', 'MIS-000089', 'KOL-02', 178000, 178000, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000171', 'MIS-000090', 'KOL-01', 749500, 749500, 'Sudah Cocok', '2026-07-13', NULL),
            ('KLK-000172', 'MIS-000090', 'KOL-02', 357500, 357500, 'Sudah Cocok', '2026-07-14', NULL),
            ('KLK-000173', 'MIS-000091', 'KOL-01', 212000, NULL, 'Belum Dihitung', '2026-07-15', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000174', 'MIS-000092', 'KOL-01', 751500, 751500, 'Sudah Cocok', '2026-07-19', NULL),
            ('KLK-000175', 'MIS-000092', 'KOL-02', 311000, 311000, 'Sudah Cocok', '2026-07-20', NULL),
            ('KLK-000176', 'MIS-000093', 'KOL-01', 785000, 785000, 'Sudah Cocok', '2026-07-20', NULL),
            ('KLK-000177', 'MIS-000093', 'KOL-02', 335500, 335500, 'Sudah Cocok', '2026-07-20', NULL),
            ('KLK-000178', 'MIS-000094', 'KOL-01', 1338000, 1338000, 'Sudah Cocok', '2026-07-20', NULL),
            ('KLK-000179', 'MIS-000094', 'KOL-02', 550000, 550000, 'Sudah Cocok', '2026-07-21', NULL),
            ('KLK-000180', 'MIS-000095', 'KOL-01', 499500, 499500, 'Sudah Cocok', '2026-07-21', NULL),
            ('KLK-000181', 'MIS-000095', 'KOL-02', 142500, 142500, 'Sudah Cocok', '2026-07-21', NULL),
            ('KLK-000182', 'MIS-000097', 'KOL-01', 249000, 249000, 'Sudah Cocok', '2026-07-24', NULL),
            ('KLK-000183', 'MIS-000098', 'KOL-01', 853500, 853500, 'Sudah Cocok', '2026-07-26', NULL),
            ('KLK-000184', 'MIS-000098', 'KOL-02', 291500, 291500, 'Sudah Cocok', '2026-07-26', NULL),
            ('KLK-000185', 'MIS-000099', 'KOL-01', 1180000, 1180000, 'Sudah Cocok', '2026-07-27', NULL),
            ('KLK-000186', 'MIS-000099', 'KOL-02', 420500, 420500, 'Sudah Cocok', '2026-07-28', NULL),
            ('KLK-000187', 'MIS-000100', 'KOL-01', 1433000, 1433000, 'Sudah Cocok', '2026-07-28', NULL),
            ('KLK-000188', 'MIS-000100', 'KOL-02', 535500, 535500, 'Sudah Cocok', '2026-07-27', NULL),
            ('KLK-000189', 'MIS-000101', 'KOL-01', 506000, 506000, 'Sudah Cocok', '2026-07-27', NULL),
            ('KLK-000190', 'MIS-000101', 'KOL-02', 222000, 222000, 'Sudah Cocok', '2026-07-27', NULL),
            ('KLK-000191', 'MIS-000102', 'KOL-01', 737500, 737500, 'Sudah Cocok', '2026-07-28', NULL),
            ('KLK-000192', 'MIS-000102', 'KOL-02', 355000, 355000, 'Sudah Cocok', '2026-07-28', NULL),
            ('KLK-000193', 'MIS-000103', 'KOL-01', 256500, 256500, 'Sudah Cocok', '2026-07-31', NULL),
            ('KLK-000194', 'MIS-000104', 'KOL-01', 1072500, 1072500, 'Sudah Cocok', '2026-08-03', NULL),
            ('KLK-000195', 'MIS-000104', 'KOL-02', 406000, 406000, 'Sudah Cocok', '2026-08-02', NULL),
            ('KLK-000196', 'MIS-000105', 'KOL-01', 851500, 851500, 'Sudah Cocok', '2026-08-03', NULL),
            ('KLK-000197', 'MIS-000105', 'KOL-02', 311000, 311000, 'Sudah Cocok', '2026-08-04', NULL),
            ('KLK-000198', 'MIS-000106', 'KOL-01', 1353500, 1353500, 'Sudah Cocok', '2026-08-03', NULL),
            ('KLK-000199', 'MIS-000106', 'KOL-02', 605500, 605500, 'Sudah Cocok', '2026-08-03', NULL),
            ('KLK-000200', 'MIS-000107', 'KOL-01', 437000, 420500, 'Selisih Sedang Ditelusuri', '2026-08-03', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000201', 'MIS-000107', 'KOL-02', 185000, 185000, 'Sudah Cocok', '2026-08-04', NULL),
            ('KLK-000202', 'MIS-000108', 'KOL-01', 943000, 943000, 'Sudah Cocok', '2026-08-03', NULL),
            ('KLK-000203', 'MIS-000108', 'KOL-02', 378000, 378000, 'Sudah Cocok', '2026-08-04', NULL),
            ('KLK-000204', 'MIS-000109', 'KOL-01', 152500, 152500, 'Sudah Cocok', '2026-08-07', NULL),
            ('KLK-000205', 'MIS-000110', 'KOL-01', 685000, 685000, 'Sudah Cocok', '2026-08-10', NULL),
            ('KLK-000206', 'MIS-000110', 'KOL-02', 362500, 362500, 'Sudah Cocok', '2026-08-10', NULL),
            ('KLK-000207', 'MIS-000111', 'KOL-01', 984000, 984000, 'Sudah Cocok', '2026-08-11', NULL),
            ('KLK-000208', 'MIS-000111', 'KOL-02', 501500, 501500, 'Sudah Cocok', '2026-08-11', NULL),
            ('KLK-000209', 'MIS-000112', 'KOL-01', 1456000, 1456000, 'Sudah Cocok', '2026-08-10', NULL),
            ('KLK-000210', 'MIS-000112', 'KOL-02', 670500, 670500, 'Sudah Cocok', '2026-08-10', NULL),
            ('KLK-000211', 'MIS-000113', 'KOL-01', 407000, 407000, 'Sudah Cocok', '2026-08-11', NULL),
            ('KLK-000212', 'MIS-000113', 'KOL-02', 195500, 195500, 'Sudah Cocok', '2026-08-11', NULL),
            ('KLK-000213', 'MIS-000114', 'KOL-01', 789000, NULL, 'Belum Dihitung', '2026-08-09', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000214', 'MIS-000114', 'KOL-02', 408000, 408000, 'Sudah Cocok', '2026-08-11', NULL),
            ('KLK-000215', 'MIS-000115', 'KOL-01', 242500, NULL, 'Belum Dihitung', '2026-08-12', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000216', 'MIS-000116', 'KOL-01', 993500, 998500, 'Selisih Disetujui', '2026-08-16', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000217', 'MIS-000116', 'KOL-02', 427500, 427500, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000218', 'MIS-000117', 'KOL-01', 737500, 737500, 'Sudah Cocok', '2026-08-18', NULL),
            ('KLK-000219', 'MIS-000117', 'KOL-02', 353000, 353000, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000220', 'MIS-000118', 'KOL-01', 1429000, 1429000, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000221', 'MIS-000118', 'KOL-02', 615500, 615500, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000222', 'MIS-000119', 'KOL-01', 482500, 507000, 'Selisih Sedang Ditelusuri', '2026-08-18', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000223', 'MIS-000119', 'KOL-02', 222500, NULL, 'Belum Dihitung', '2026-08-16', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000224', 'MIS-000120', 'KOL-01', 1109500, 1109500, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000225', 'MIS-000120', 'KOL-02', 456000, 456000, 'Sudah Cocok', '2026-08-17', NULL),
            ('KLK-000226', 'MIS-000121', 'KOL-01', 227000, 227000, 'Sudah Cocok', '2026-08-20', NULL),
            ('KLK-000227', 'MIS-000122', 'KOL-01', 909500, 909500, 'Sudah Cocok', '2026-08-24', NULL),
            ('KLK-000228', 'MIS-000122', 'KOL-02', 381500, 365500, 'Selisih Sedang Ditelusuri', '2026-08-23', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000229', 'MIS-000123', 'KOL-01', 785000, 781500, 'Selisih Disetujui', '2026-08-24', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000230', 'MIS-000123', 'KOL-02', 367500, 367500, 'Sudah Cocok', '2026-08-24', NULL),
            ('KLK-000231', 'MIS-000124', 'KOL-01', 1544000, 1544000, 'Sudah Cocok', '2026-08-25', NULL),
            ('KLK-000232', 'MIS-000124', 'KOL-02', 550000, 550000, 'Sudah Cocok', '2026-08-25', NULL),
            ('KLK-000233', 'MIS-000125', 'KOL-01', 408000, 408000, 'Sudah Cocok', '2026-08-25', NULL),
            ('KLK-000234', 'MIS-000125', 'KOL-02', 181500, NULL, 'Belum Dihitung', '2026-08-23', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000235', 'MIS-000126', 'KOL-01', 991000, 991000, 'Sudah Cocok', '2026-08-25', NULL),
            ('KLK-000236', 'MIS-000126', 'KOL-02', 451000, 454000, 'Selisih Disetujui', '2026-08-24', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000237', 'MIS-000127', 'KOL-01', 260500, 260500, 'Sudah Cocok', '2026-08-28', NULL),
            ('KLK-000238', 'MIS-000128', 'KOL-01', 794000, 798000, 'Selisih Disetujui', '2026-08-31', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000239', 'MIS-000128', 'KOL-02', 380000, 380000, 'Sudah Cocok', '2026-08-30', NULL),
            ('KLK-000240', 'MIS-000129', 'KOL-01', 1065000, 1066500, 'Selisih Disetujui', '2026-09-01', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000241', 'MIS-000129', 'KOL-02', 409500, 410500, 'Selisih Disetujui', '2026-08-31', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000242', 'MIS-000130', 'KOL-01', 1310500, 1310500, 'Sudah Cocok', '2026-09-01', NULL),
            ('KLK-000243', 'MIS-000130', 'KOL-02', 533000, 533000, 'Sudah Cocok', '2026-09-01', NULL),
            ('KLK-000244', 'MIS-000131', 'KOL-01', 437500, 437500, 'Sudah Cocok', '2026-08-31', NULL),
            ('KLK-000245', 'MIS-000131', 'KOL-02', 123500, 123500, 'Sudah Cocok', '2026-08-31', NULL),
            ('KLK-000246', 'MIS-000132', 'KOL-01', 727500, 727500, 'Sudah Cocok', '2026-09-01', NULL),
            ('KLK-000247', 'MIS-000132', 'KOL-02', 398500, 398500, 'Sudah Cocok', '2026-08-31', NULL),
            ('KLK-000248', 'MIS-000133', 'KOL-01', 230500, 221000, 'Selisih Sedang Ditelusuri', '2026-09-04', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000249', 'MIS-000134', 'KOL-01', 768000, 768000, 'Sudah Cocok', '2026-09-06', NULL),
            ('KLK-000250', 'MIS-000134', 'KOL-02', 325000, NULL, 'Belum Dihitung', '2026-09-05', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000251', 'MIS-000135', 'KOL-01', 990500, 990500, 'Sudah Cocok', '2026-09-07', NULL),
            ('KLK-000252', 'MIS-000135', 'KOL-02', 383000, 383000, 'Sudah Cocok', '2026-09-07', NULL),
            ('KLK-000253', 'MIS-000136', 'KOL-01', 1489500, NULL, 'Belum Dihitung', '2026-09-06', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000254', 'MIS-000136', 'KOL-02', 535500, 535500, 'Sudah Cocok', '2026-09-07', NULL),
            ('KLK-000255', 'MIS-000137', 'KOL-01', 402000, 402000, 'Sudah Cocok', '2026-09-08', NULL),
            ('KLK-000256', 'MIS-000137', 'KOL-02', 217500, 217500, 'Sudah Cocok', '2026-09-07', NULL),
            ('KLK-000257', 'MIS-000138', 'KOL-01', 934000, NULL, 'Belum Dihitung', '2026-09-06', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000258', 'MIS-000138', 'KOL-02', 373500, 373500, 'Sudah Cocok', '2026-09-08', NULL),
            ('KLK-000259', 'MIS-000139', 'KOL-01', 233500, 233500, 'Sudah Cocok', '2026-09-11', NULL),
            ('KLK-000260', 'MIS-000140', 'KOL-01', 716500, 682500, 'Selisih Sedang Ditelusuri', '2026-09-14', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000261', 'MIS-000140', 'KOL-02', 321000, 321000, 'Sudah Cocok', '2026-09-14', NULL),
            ('KLK-000262', 'MIS-000141', 'KOL-01', 839000, 839000, 'Sudah Cocok', '2026-09-15', NULL),
            ('KLK-000263', 'MIS-000141', 'KOL-02', 457000, 454000, 'Selisih Disetujui', '2026-09-15', 'Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara.'),
            ('KLK-000264', 'MIS-000142', 'KOL-01', 1563500, 1563500, 'Sudah Cocok', '2026-09-15', NULL),
            ('KLK-000265', 'MIS-000142', 'KOL-02', 526500, 526500, 'Sudah Cocok', '2026-09-15', NULL),
            ('KLK-000266', 'MIS-000143', 'KOL-01', 505000, 505000, 'Sudah Cocok', '2026-09-14', NULL),
            ('KLK-000267', 'MIS-000143', 'KOL-02', 160500, 160500, 'Sudah Cocok', '2026-09-14', NULL),
            ('KLK-000268', 'MIS-000144', 'KOL-01', 1034000, 1034000, 'Sudah Cocok', '2026-09-15', NULL),
            ('KLK-000269', 'MIS-000144', 'KOL-02', 475000, NULL, 'Belum Dihitung', '2026-09-13', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000270', 'MIS-000145', 'KOL-01', 236000, NULL, 'Belum Dihitung', '2026-09-16', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000271', 'MIS-000146', 'KOL-01', 844500, 844500, 'Sudah Cocok', '2026-09-21', NULL),
            ('KLK-000272', 'MIS-000146', 'KOL-02', 313500, 313500, 'Sudah Cocok', '2026-09-20', NULL),
            ('KLK-000273', 'MIS-000147', 'KOL-01', 946000, NULL, 'Belum Dihitung', '2026-09-20', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000274', 'MIS-000147', 'KOL-02', 322000, 322000, 'Sudah Cocok', '2026-09-21', NULL),
            ('KLK-000275', 'MIS-000148', 'KOL-01', 1638000, 1638000, 'Sudah Cocok', '2026-09-22', NULL),
            ('KLK-000276', 'MIS-000148', 'KOL-02', 431500, 431500, 'Sudah Cocok', '2026-09-22', NULL),
            ('KLK-000277', 'MIS-000149', 'KOL-01', 474500, 474500, 'Sudah Cocok', '2026-09-21', NULL),
            ('KLK-000278', 'MIS-000149', 'KOL-02', 148000, NULL, 'Belum Dihitung', '2026-09-20', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000279', 'MIS-000150', 'KOL-01', 779500, NULL, 'Belum Dihitung', '2026-09-20', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000280', 'MIS-000150', 'KOL-02', 343000, NULL, 'Belum Dihitung', '2026-09-20', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000281', 'MIS-000151', 'KOL-01', 214000, 214000, 'Sudah Cocok', '2026-09-24', NULL),
            ('KLK-000282', 'MIS-000152', 'KOL-01', 729000, NULL, 'Belum Dihitung', '2026-09-26', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000283', 'MIS-000152', 'KOL-02', 260500, 260500, 'Sudah Cocok', '2026-09-27', NULL),
            ('KLK-000284', 'MIS-000153', 'KOL-01', 881000, 881000, 'Sudah Cocok', '2026-09-29', NULL),
            ('KLK-000285', 'MIS-000153', 'KOL-02', 489000, 489000, 'Sudah Cocok', '2026-09-29', NULL),
            ('KLK-000286', 'MIS-000154', 'KOL-01', 1323500, 1323500, 'Sudah Cocok', '2026-09-29', NULL),
            ('KLK-000287', 'MIS-000154', 'KOL-02', 599500, 616500, 'Selisih Sedang Ditelusuri', '2026-09-29', 'Selisih sedang ditelusuri bersama petugas penghitung.'),
            ('KLK-000288', 'MIS-000155', 'KOL-01', 446000, 446000, 'Sudah Cocok', '2026-09-29', NULL),
            ('KLK-000289', 'MIS-000155', 'KOL-02', 228500, 228500, 'Sudah Cocok', '2026-09-29', NULL),
            ('KLK-000290', 'MIS-000156', 'KOL-01', 959000, NULL, 'Belum Dihitung', '2026-09-27', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000291', 'MIS-000156', 'KOL-02', 466000, NULL, 'Belum Dihitung', '2026-09-27', 'Menunggu penghitungan oleh tim penghitung kolekte.'),
            ('KLK-000292', 'MIS-000157', 'KOL-01', 205000, NULL, 'Belum Dihitung', '2026-09-30', 'Menunggu penghitungan oleh tim penghitung kolekte.')
    ) AS v (ID_KOLEKTE, ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE, JUMLAH_PENERIMAAN, JUMLAH_HASIL_PENGHITUNGAN, STATUS_REKONSILIASI, TANGGAL_PENCATATAN, KETERANGAN)
) AS s
ON t.ID_KOLEKTE = s.ID_KOLEKTE
WHEN MATCHED THEN UPDATE SET
    ID_KEJADIAN_MISA = s.ID_KEJADIAN_MISA,
    ID_JENIS_KOLEKTE = s.ID_JENIS_KOLEKTE,
    JUMLAH_PENERIMAAN = s.JUMLAH_PENERIMAAN,
    JUMLAH_HASIL_PENGHITUNGAN = s.JUMLAH_HASIL_PENGHITUNGAN,
    STATUS_REKONSILIASI = s.STATUS_REKONSILIASI,
    TANGGAL_PENCATATAN = s.TANGGAL_PENCATATAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_KOLEKTE, ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE, JUMLAH_PENERIMAAN, JUMLAH_HASIL_PENGHITUNGAN, STATUS_REKONSILIASI, TANGGAL_PENCATATAN, KETERANGAN)
    VALUES (s.ID_KOLEKTE, s.ID_KEJADIAN_MISA, s.ID_JENIS_KOLEKTE, s.JUMLAH_PENERIMAAN, s.JUMLAH_HASIL_PENGHITUNGAN, s.STATUS_REKONSILIASI, s.TANGGAL_PENCATATAN, s.KETERANGAN);

-- DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS: 24 rows
MERGE INTO DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS AS t
USING (
    SELECT
        v.ID_SUMBANGAN AS ID_SUMBANGAN,
        v.ID_WILAYAH AS ID_WILAYAH,
        v.ID_KESEMPATAN AS ID_KESEMPATAN,
        CAST(v.PERIODE_MULAI AS DATE) AS PERIODE_MULAI,
        CAST(v.PERIODE_SELESAI AS DATE) AS PERIODE_SELESAI,
        CAST(v.JUMLAH_KELUARGA_PESERTA AS NUMBER(6,0)) AS JUMLAH_KELUARGA_PESERTA,
        CAST(v.JUMLAH_SUMBANGAN AS NUMBER(18,0)) AS JUMLAH_SUMBANGAN,
        CAST(v.TANGGAL_PENCATATAN AS DATE) AS TANGGAL_PENCATATAN,
        v.STATUS_VALIDASI AS STATUS_VALIDASI,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('SMB-001', 'WIL-01', 'KSK-01', '2025-03-05', '2025-04-19', 34, 3000000, '2025-04-24', 'Sudah Divalidasi', NULL),
            ('SMB-002', 'WIL-02', 'KSK-01', '2025-03-05', '2025-04-19', 24, 3220000, '2025-04-26', 'Sudah Divalidasi', NULL),
            ('SMB-003', 'WIL-03', 'KSK-01', '2025-03-05', '2025-04-19', 26, 2925000, '2025-05-03', 'Sudah Divalidasi', NULL),
            ('SMB-004', 'WIL-04', 'KSK-01', '2025-03-05', '2025-04-19', 30, 2855000, '2025-05-02', 'Sudah Divalidasi', NULL),
            ('SMB-005', 'WIL-05', 'KSK-01', '2025-03-05', '2025-04-19', 24, 3360000, '2025-04-27', 'Sudah Divalidasi', NULL),
            ('SMB-006', 'WIL-06', 'KSK-01', '2025-03-05', '2025-04-19', 30, 3230000, '2025-04-22', 'Sudah Divalidasi', NULL),
            ('SMB-007', 'WIL-01', 'KSK-02', '2025-11-30', '2025-12-24', 36, 3235000, '2025-12-27', 'Sudah Divalidasi', NULL),
            ('SMB-008', 'WIL-02', 'KSK-02', '2025-11-30', '2025-12-24', 23, 2480000, '2026-01-06', 'Sudah Divalidasi', NULL),
            ('SMB-009', 'WIL-03', 'KSK-02', '2025-11-30', '2025-12-24', 27, 2530000, '2025-12-29', 'Sudah Divalidasi', NULL),
            ('SMB-010', 'WIL-04', 'KSK-02', '2025-11-30', '2025-12-24', 22, 2525000, '2026-01-03', 'Sudah Divalidasi', NULL),
            ('SMB-011', 'WIL-05', 'KSK-02', '2025-11-30', '2025-12-24', 29, 2300000, '2025-12-31', 'Sudah Divalidasi', NULL),
            ('SMB-012', 'WIL-06', 'KSK-02', '2025-11-30', '2025-12-24', 28, 2165000, '2026-01-06', 'Sudah Divalidasi', NULL),
            ('SMB-013', 'WIL-01', 'KSK-01', '2026-02-18', '2026-04-04', 31, 3300000, '2026-04-14', 'Sudah Divalidasi', NULL),
            ('SMB-014', 'WIL-02', 'KSK-01', '2026-02-18', '2026-04-04', 25, 3315000, '2026-04-13', 'Sudah Divalidasi', NULL),
            ('SMB-015', 'WIL-03', 'KSK-01', '2026-02-18', '2026-04-04', 31, 4760000, '2026-04-07', 'Sudah Divalidasi', NULL),
            ('SMB-016', 'WIL-04', 'KSK-01', '2026-02-18', '2026-04-04', 30, 4445000, '2026-04-14', 'Perlu Dicek Ulang', 'Nominal perlu dicek ulang terhadap bukti setoran.'),
            ('SMB-017', 'WIL-05', 'KSK-01', '2026-02-18', '2026-04-04', 30, 3450000, '2026-04-09', 'Sudah Divalidasi', NULL),
            ('SMB-018', 'WIL-06', 'KSK-01', '2026-02-18', '2026-04-04', 32, 4170000, '2026-04-14', 'Sudah Divalidasi', NULL),
            ('SMB-019', 'WIL-01', 'KSK-03', '2026-07-06', '2026-07-26', 34, 3735000, '2026-07-29', 'Sudah Divalidasi', 'Penggalangan dana tanggap darurat banjir (fiktif).'),
            ('SMB-020', 'WIL-02', 'KSK-03', '2026-07-06', '2026-07-26', 24, 2380000, '2026-07-29', 'Menunggu Validasi', 'Menunggu bukti setoran dari ketua wilayah.'),
            ('SMB-021', 'WIL-03', 'KSK-03', '2026-07-06', '2026-07-26', 26, 2370000, '2026-08-08', 'Sudah Divalidasi', 'Penggalangan dana tanggap darurat banjir (fiktif).'),
            ('SMB-022', 'WIL-04', 'KSK-03', '2026-07-06', '2026-07-26', 22, 2805000, '2026-08-02', 'Sudah Divalidasi', 'Penggalangan dana tanggap darurat banjir (fiktif).'),
            ('SMB-023', 'WIL-05', 'KSK-03', '2026-07-06', '2026-07-26', 20, 2140000, '2026-08-02', 'Menunggu Validasi', 'Menunggu bukti setoran dari ketua wilayah.'),
            ('SMB-024', 'WIL-06', 'KSK-03', '2026-07-06', '2026-07-26', 25, 1895000, '2026-08-04', 'Sudah Divalidasi', 'Penggalangan dana tanggap darurat banjir (fiktif).')
    ) AS v (ID_SUMBANGAN, ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI, PERIODE_SELESAI, JUMLAH_KELUARGA_PESERTA, JUMLAH_SUMBANGAN, TANGGAL_PENCATATAN, STATUS_VALIDASI, KETERANGAN)
) AS s
ON t.ID_SUMBANGAN = s.ID_SUMBANGAN
WHEN MATCHED THEN UPDATE SET
    ID_WILAYAH = s.ID_WILAYAH,
    ID_KESEMPATAN = s.ID_KESEMPATAN,
    PERIODE_MULAI = s.PERIODE_MULAI,
    PERIODE_SELESAI = s.PERIODE_SELESAI,
    JUMLAH_KELUARGA_PESERTA = s.JUMLAH_KELUARGA_PESERTA,
    JUMLAH_SUMBANGAN = s.JUMLAH_SUMBANGAN,
    TANGGAL_PENCATATAN = s.TANGGAL_PENCATATAN,
    STATUS_VALIDASI = s.STATUS_VALIDASI,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_SUMBANGAN, ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI, PERIODE_SELESAI, JUMLAH_KELUARGA_PESERTA, JUMLAH_SUMBANGAN, TANGGAL_PENCATATAN, STATUS_VALIDASI, KETERANGAN)
    VALUES (s.ID_SUMBANGAN, s.ID_WILAYAH, s.ID_KESEMPATAN, s.PERIODE_MULAI, s.PERIODE_SELESAI, s.JUMLAH_KELUARGA_PESERTA, s.JUMLAH_SUMBANGAN, s.TANGGAL_PENCATATAN, s.STATUS_VALIDASI, s.KETERANGAN);

-- DATA_OPERASIONAL.KELUARGA: 227 rows
MERGE INTO DATA_OPERASIONAL.KELUARGA AS t
USING (
    SELECT
        v.ID_KELUARGA AS ID_KELUARGA,
        v.NAMA_KELUARGA_FIKTIF AS NAMA_KELUARGA_FIKTIF,
        v.STATUS_KELUARGA AS STATUS_KELUARGA,
        CAST(v.TANGGAL_TERDAFTAR AS DATE) AS TANGGAL_TERDAFTAR,
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA
    FROM (VALUES
            ('KEL-0001', 'Keluarga Dominika Dian Sutanto', 'Aktif', '2014-03-28', 'KLS-03'),
            ('KEL-0002', 'Keluarga Yosef Manurung', 'Aktif', '2013-11-14', 'KLS-03'),
            ('KEL-0003', 'Keluarga Eko Gunawan', 'Aktif', '2024-04-02', 'KLS-03'),
            ('KEL-0004', 'Keluarga Benediktus Galih Setiawan', 'Aktif', '2022-07-17', 'KLS-03'),
            ('KEL-0005', 'Keluarga Surya Tallo', 'Aktif', '2011-05-11', 'KLS-03'),
            ('KEL-0006', 'Keluarga Nilam Hartono', 'Aktif', '2009-04-18', 'KLS-03'),
            ('KEL-0007', 'Keluarga Emanuel Panjaitan', 'Aktif', '2018-07-13', 'KLS-03'),
            ('KEL-0008', 'Keluarga Yosef Hidayat', 'Aktif', '2022-05-13', 'KLS-03'),
            ('KEL-0009', 'Keluarga Kristoforus Gunawan', 'Aktif', '2008-11-21', 'KLS-03'),
            ('KEL-0010', 'Keluarga Matius Hendra Santoso', 'Aktif', '2020-05-03', 'KLS-03'),
            ('KEL-0011', 'Keluarga Ignatius Lukito Purnomo', 'Aktif', '2021-07-03', 'KLS-03'),
            ('KEL-0012', 'Keluarga Antonius Lukito Ndoen', 'Aktif', '2019-09-05', 'KLS-03'),
            ('KEL-0013', 'Keluarga Yohana Citra Halim', 'Aktif', '2023-02-01', 'KLS-03'),
            ('KEL-0014', 'Keluarga Stefanus Setiawan', 'Aktif', '2016-03-10', 'KLS-03'),
            ('KEL-0015', 'Keluarga Yosef Rizki Kusuma', 'Aktif', '2015-02-11', 'KLS-03'),
            ('KEL-0016', 'Keluarga Ignatius Ferry Simanjuntak', 'Aktif', '2013-04-09', 'KLS-03'),
            ('KEL-0017', 'Keluarga Putra Rumbayan', 'Aktif', '2019-08-31', 'KLS-03'),
            ('KEL-0018', 'Keluarga Maria Rahardjo', 'Aktif', '2015-05-21', 'KLS-03'),
            ('KEL-0019', 'Keluarga Krisna Sihombing', 'Aktif', '2016-05-29', 'KLS-03'),
            ('KEL-0020', 'Keluarga Krisna Nugraha', 'Aktif', '2017-04-07', 'KLS-03'),
            ('KEL-0021', 'Keluarga Lukas Agus Tjandra', 'Aktif', '2020-07-28', 'KLS-03'),
            ('KEL-0022', 'Keluarga Matius Agus Ndoen', 'Pindah Paroki', '2008-11-09', 'KLS-03'),
            ('KEL-0023', 'Keluarga Kristoforus Rumbayan', 'Aktif', '2015-08-29', 'KLS-03'),
            ('KEL-0024', 'Keluarga Yudha Sihombing', 'Pindah Paroki', '2016-03-11', 'KLS-03'),
            ('KEL-0025', 'Keluarga Clara Rahayu Prasetyo', 'Aktif', '2021-11-16', 'KLS-03'),
            ('KEL-0026', 'Keluarga Paulus Lalamentik', 'Aktif', '2025-01-27', 'KLS-03'),
            ('KEL-0027', 'Keluarga Aloysius Ferry Siregar', 'Aktif', '2009-02-15', 'KLS-03'),
            ('KEL-0028', 'Keluarga Agus Simanjuntak', 'Aktif', '2021-07-24', 'KLS-03'),
            ('KEL-0029', 'Keluarga Paulus Purnomo', 'Aktif', '2021-12-05', 'KLS-03'),
            ('KEL-0030', 'Keluarga Benediktus Rizki Ndoen', 'Aktif', '2023-07-17', 'KLS-03'),
            ('KEL-0031', 'Keluarga Vincentius Hadi Situmorang', 'Aktif', '2015-06-27', 'KLS-03'),
            ('KEL-0032', 'Keluarga Anastasia Sri Purnomo', 'Aktif', '2014-12-25', 'KLS-03'),
            ('KEL-0033', 'Keluarga Aloysius Dwi Purnomo', 'Aktif', '2013-11-23', 'KLS-03'),
            ('KEL-0034', 'Keluarga Petrus Dedi Hermawan', 'Aktif', '2020-09-16', 'KLS-03'),
            ('KEL-0035', 'Keluarga Vincentius Budi Manurung', 'Aktif', '2019-09-10', 'KLS-03'),
            ('KEL-0036', 'Keluarga Lestari Nugraha', 'Aktif', '2018-03-16', 'KLS-03'),
            ('KEL-0037', 'Keluarga Markus Surya Bria', 'Aktif', '2020-11-25', 'KLS-03'),
            ('KEL-0038', 'Keluarga Benediktus Krisna Nugraha', 'Aktif', '2008-10-12', 'KLS-03'),
            ('KEL-0039', 'Keluarga Indah Da Costa', 'Aktif', '2016-10-23', 'KLS-03'),
            ('KEL-0040', 'Keluarga Raka Siregar', 'Aktif', '2024-03-18', 'KLS-03'),
            ('KEL-0041', 'Keluarga Ignatius Dwi Wijaya', 'Aktif', '2016-03-06', 'KLS-03'),
            ('KEL-0042', 'Keluarga Emanuel Ferry Simanjuntak', 'Aktif', '2009-01-08', 'KLS-03'),
            ('KEL-0043', 'Keluarga Fransiskus Hermawan', 'Aktif', '2018-03-15', 'KLS-03'),
            ('KEL-0044', 'Keluarga Ignatius Budi Kurniawan', 'Aktif', '2016-06-19', 'KLS-03'),
            ('KEL-0045', 'Keluarga Stefanus Joko Nainggolan', 'Aktif', '2019-05-18', 'KLS-03'),
            ('KEL-0046', 'Keluarga Emanuel Bambang Pratama', 'Aktif', '2019-12-13', 'KLS-03'),
            ('KEL-0047', 'Keluarga Markus Hendra Hidayat', 'Aktif', '2023-07-23', 'KLS-03'),
            ('KEL-0048', 'Keluarga Lukas Krisna Hermawan', 'Aktif', '2017-08-25', 'KLS-03'),
            ('KEL-0049', 'Keluarga Hieronimus Hendra Mamengko', 'Aktif', '2015-03-15', 'KLS-03'),
            ('KEL-0050', 'Keluarga Maria Lewar', 'Aktif', '2022-06-11', 'KLS-03'),
            ('KEL-0051', 'Keluarga Ignatius Hadi Kaunang', 'Aktif', '2011-01-15', 'KLS-03'),
            ('KEL-0052', 'Keluarga Fransiskus Wahyu Manurung', 'Aktif', '2012-01-30', 'KLS-03'),
            ('KEL-0053', 'Keluarga Matius Gunawan', 'Aktif', '2017-09-05', 'KLS-03'),
            ('KEL-0054', 'Keluarga Katarina Mira Mamengko', 'Aktif', '2014-09-13', 'KLS-03'),
            ('KEL-0055', 'Keluarga Aloysius Budi Koten', 'Aktif', '2020-07-18', 'KLS-03'),
            ('KEL-0056', 'Keluarga Raka Wijaya', 'Aktif', '2010-09-15', 'KLS-03'),
            ('KEL-0057', 'Keluarga Mira Tallo', 'Aktif', '2024-07-15', 'KLS-03'),
            ('KEL-0058', 'Keluarga Nugroho Hartono', 'Aktif', '2024-03-02', 'KLS-03'),
            ('KEL-0059', 'Keluarga Ignatia Rahayu Gunawan', 'Aktif', '2009-10-22', 'KLS-03'),
            ('KEL-0060', 'Keluarga Matius Dedi Tallo', 'Aktif', '2016-11-10', 'KLS-03'),
            ('KEL-0061', 'Keluarga Robertus Yudha Tanujaya', 'Aktif', '2009-11-05', 'KLS-03'),
            ('KEL-0062', 'Keluarga Emanuel Wahyu Wibowo', 'Aktif', '2014-02-27', 'KLS-03'),
            ('KEL-0063', 'Keluarga Yustina Kartika Gunadi', 'Aktif', '2017-05-23', 'KLS-03'),
            ('KEL-0064', 'Keluarga Hieronimus Dwi Lalamentik', 'Aktif', '2017-03-19', 'KLS-03'),
            ('KEL-0065', 'Keluarga Andreas Kurnia Koten', 'Aktif', '2020-01-28', 'KLS-03'),
            ('KEL-0066', 'Keluarga Bernadeta Hutabarat', 'Aktif', '2016-03-06', 'KLS-03'),
            ('KEL-0067', 'Keluarga Nugroho Hermawan', 'Aktif', '2016-04-11', 'KLS-03'),
            ('KEL-0068', 'Keluarga Lukas Dedi Lukman', 'Aktif', '2013-06-22', 'KLS-03'),
            ('KEL-0069', 'Keluarga Dominikus Bambang Budiman', 'Aktif', '2016-05-03', 'KLS-03'),
            ('KEL-0070', 'Keluarga Maria Dewi Tallo', 'Aktif', '2019-04-03', 'KLS-03'),
            ('KEL-0071', 'Keluarga Kristoforus Budi Handoko', 'Aktif', '2022-02-09', 'KLS-03'),
            ('KEL-0072', 'Keluarga Galih Kleden', 'Aktif', '2011-06-18', 'KLS-03'),
            ('KEL-0073', 'Keluarga Yohanes Joko Rahardjo', 'Aktif', '2012-11-15', 'KLS-03'),
            ('KEL-0074', 'Keluarga Bayu Santoso', 'Aktif', '2013-11-06', 'KLS-03'),
            ('KEL-0075', 'Keluarga Stefanus Indra Hartono', 'Aktif', '2020-08-08', 'KLS-03'),
            ('KEL-0076', 'Keluarga Albertus Budi Tallo', 'Aktif', '2009-12-20', 'KLS-03'),
            ('KEL-0077', 'Keluarga Stefanus Panjaitan', 'Aktif', '2020-03-10', 'KLS-03'),
            ('KEL-0078', 'Keluarga Stefanus Surya Nainggolan', 'Aktif', '2018-07-04', 'KLS-03'),
            ('KEL-0079', 'Keluarga Matius Wijaya', 'Aktif', '2010-07-11', 'KLS-03'),
            ('KEL-0080', 'Keluarga Adi Santoso', 'Aktif', '2019-06-08', 'KLS-03'),
            ('KEL-0081', 'Keluarga Stefanus Ferry Tjandra', 'Aktif', '2022-01-09', 'KLS-03'),
            ('KEL-0082', 'Keluarga Benediktus Krisna Hermawan', 'Aktif', '2019-05-09', 'KLS-03'),
            ('KEL-0083', 'Keluarga Indra Tjandra', 'Aktif', '2015-07-12', 'KLS-03'),
            ('KEL-0084', 'Keluarga Thomas Wahyu Hutabarat', 'Aktif', '2011-06-23', 'KLS-03'),
            ('KEL-0085', 'Keluarga Hadi Utomo', 'Aktif', '2017-03-15', 'KLS-03'),
            ('KEL-0086', 'Keluarga Thomas Kaunang', 'Aktif', '2020-10-28', 'KLS-03'),
            ('KEL-0087', 'Keluarga Paulus Galih Rumbayan', 'Aktif', '2020-12-01', 'KLS-03'),
            ('KEL-0088', 'Keluarga Agnes Tuti Saputra', 'Aktif', '2012-01-07', 'KLS-03'),
            ('KEL-0089', 'Keluarga Mira Halim', 'Aktif', '2019-10-06', 'KLS-03'),
            ('KEL-0090', 'Keluarga Dedi Mamengko', 'Aktif', '2019-05-26', 'KLS-03'),
            ('KEL-0091', 'Keluarga Indra Halim', 'Aktif', '2021-01-23', 'KLS-03'),
            ('KEL-0092', 'Keluarga Danu Tallo', 'Aktif', '2012-11-30', 'KLS-03'),
            ('KEL-0093', 'Keluarga Yohanes Rizki Kaunang', 'Aktif', '2014-03-12', 'KLS-03'),
            ('KEL-0094', 'Keluarga Dominikus Pratama', 'Aktif', '2015-05-24', 'KLS-03'),
            ('KEL-0095', 'Keluarga Hieronimus Wahyu Budiman', 'Aktif', '2021-03-13', 'KLS-03'),
            ('KEL-0096', 'Keluarga Lukito Kurniawan', 'Aktif', '2009-03-21', 'KLS-03'),
            ('KEL-0097', 'Keluarga Wahyu Kurniawan', 'Aktif', '2021-04-03', 'KLS-03'),
            ('KEL-0098', 'Keluarga Lukas Hermawan', 'Aktif', '2024-05-02', 'KLS-03'),
            ('KEL-0099', 'Keluarga Yohanes Nugraha', 'Aktif', '2021-06-13', 'KLS-03'),
            ('KEL-0100', 'Keluarga Thomas Surya Lukman', 'Aktif', '2015-04-30', 'KLS-03'),
            ('KEL-0101', 'Keluarga Mira Hartono', 'Aktif', '2016-07-02', 'KLS-03'),
            ('KEL-0102', 'Keluarga Yohanes Dwi Tanujaya', 'Aktif', '2013-01-29', 'KLS-03'),
            ('KEL-0103', 'Keluarga Albertus Galih Sihombing', 'Aktif', '2011-10-14', 'KLS-03'),
            ('KEL-0104', 'Keluarga Lukito Panjaitan', 'Aktif', '2015-06-30', 'KLS-03'),
            ('KEL-0105', 'Keluarga Surya Sihombing', 'Aktif', '2011-02-01', 'KLS-03'),
            ('KEL-0106', 'Keluarga Aryo Santoso', 'Aktif', '2008-06-21', 'KLS-03'),
            ('KEL-0107', 'Keluarga Veronika Intan Gunadi', 'Aktif', '2016-03-25', 'KLS-03'),
            ('KEL-0108', 'Keluarga Ignatius Wahyu Bria', 'Aktif', '2020-09-11', 'KLS-03'),
            ('KEL-0109', 'Keluarga Robertus Dwi Lobo', 'Aktif', '2012-04-28', 'KLS-03'),
            ('KEL-0110', 'Keluarga Adi Purnomo', 'Aktif', '2012-06-13', 'KLS-03'),
            ('KEL-0111', 'Keluarga Raka Ndoen', 'Aktif', '2013-06-13', 'KLS-03'),
            ('KEL-0112', 'Keluarga Benediktus Eko Tjandra', 'Aktif', '2010-08-04', 'KLS-03'),
            ('KEL-0113', 'Keluarga Robertus Tanujaya', 'Aktif', '2021-11-13', 'KLS-03'),
            ('KEL-0114', 'Keluarga Angela Melati Da Costa', 'Aktif', '2020-05-16', 'KLS-03'),
            ('KEL-0115', 'Keluarga Antonius Joko Simanjuntak', 'Aktif', '2021-02-23', 'KLS-03'),
            ('KEL-0116', 'Keluarga Benediktus Adi Sutanto', 'Aktif', '2020-11-09', 'KLS-03'),
            ('KEL-0117', 'Keluarga Sri Lukman', 'Aktif', '2024-10-12', 'KLS-03'),
            ('KEL-0118', 'Keluarga Gregorius Imam Santoso', 'Aktif', '2017-02-03', 'KLS-03'),
            ('KEL-0119', 'Keluarga Antonius Putra Siregar', 'Aktif', '2020-04-28', 'KLS-03'),
            ('KEL-0120', 'Keluarga Dominikus Rudi Gunadi', 'Aktif', '2021-07-01', 'KLS-03'),
            ('KEL-0121', 'Keluarga Yohanes Susanto', 'Aktif', '2024-10-27', 'KLS-03'),
            ('KEL-0122', 'Keluarga Markus Danu Utomo', 'Aktif', '2024-04-27', 'KLS-03'),
            ('KEL-0123', 'Keluarga Paulus Bambang Nainggolan', 'Aktif', '2012-10-23', 'KLS-03'),
            ('KEL-0124', 'Keluarga Agnes Yuni Seran', 'Aktif', '2016-06-08', 'KLS-03'),
            ('KEL-0125', 'Keluarga Dominikus Lukman', 'Aktif', '2010-04-06', 'KLS-03'),
            ('KEL-0126', 'Keluarga Regina Fitri Handoko', 'Aktif', '2022-10-06', 'KLS-03'),
            ('KEL-0127', 'Keluarga Matius Situmorang', 'Aktif', '2020-03-23', 'KLS-03'),
            ('KEL-0128', 'Keluarga Paulus Rudi Saputra', 'Aktif', '2011-10-30', 'KLS-03'),
            ('KEL-0129', 'Keluarga Dominikus Galih Kusuma', 'Aktif', '2010-09-16', 'KLS-03'),
            ('KEL-0130', 'Keluarga Elisabeth Dian Purnomo', 'Aktif', '2025-03-09', 'KLS-03'),
            ('KEL-0131', 'Keluarga Matius Nugroho Susanto', 'Aktif', '2012-12-09', 'KLS-03'),
            ('KEL-0132', 'Keluarga Markus Yudha Prasetyo', 'Aktif', '2008-06-03', 'KLS-03'),
            ('KEL-0133', 'Keluarga Albertus Putra Hutabarat', 'Aktif', '2008-12-14', 'KLS-03'),
            ('KEL-0134', 'Keluarga Yosef Galih Rahardjo', 'Aktif', '2008-06-21', 'KLS-03'),
            ('KEL-0135', 'Keluarga Dominikus Agus Tjandra', 'Aktif', '2018-11-10', 'KLS-03'),
            ('KEL-0136', 'Keluarga Emanuel Teguh Bria', 'Aktif', '2021-01-06', 'KLS-03'),
            ('KEL-0137', 'Keluarga Dominikus Krisna Wibowo', 'Aktif', '2023-04-30', 'KLS-03'),
            ('KEL-0138', 'Keluarga Hesti Handoko', 'Aktif', '2014-10-03', 'KLS-03'),
            ('KEL-0139', 'Keluarga Aloysius Sihombing', 'Aktif', '2014-01-26', 'KLS-03'),
            ('KEL-0140', 'Keluarga Fransiska Wulan Lalamentik', 'Aktif', '2017-06-21', 'KLS-03'),
            ('KEL-0141', 'Keluarga Robertus Cahyo Lukman', 'Aktif', '2008-05-01', 'KLS-03'),
            ('KEL-0142', 'Keluarga Rudi Handoko', 'Aktif', '2024-02-07', 'KLS-03'),
            ('KEL-0143', 'Keluarga Clara Fitri Wibowo', 'Aktif', '2016-02-17', 'KLS-03'),
            ('KEL-0144', 'Keluarga Dominikus Joko Kurniawan', 'Aktif', '2015-12-06', 'KLS-03'),
            ('KEL-0145', 'Keluarga Dian Koten', 'Aktif', '2013-07-20', 'KLS-03'),
            ('KEL-0146', 'Keluarga Petrus Rudi Simanjuntak', 'Aktif', '2008-11-20', 'KLS-03'),
            ('KEL-0147', 'Keluarga Ignatius Ferry Wijaya', 'Aktif', '2025-04-21', 'KLS-03'),
            ('KEL-0148', 'Keluarga Bernardus Krisna Tanujaya', 'Aktif', '2016-09-17', 'KLS-03'),
            ('KEL-0149', 'Keluarga Emanuel Eko Purnomo', 'Aktif', '2012-02-27', 'KLS-03'),
            ('KEL-0150', 'Keluarga Indra Siregar', 'Aktif', '2020-03-12', 'KLS-03'),
            ('KEL-0151', 'Keluarga Lukas Santoso', 'Aktif', '2021-05-13', 'KLS-03'),
            ('KEL-0152', 'Keluarga Imam Santoso', 'Aktif', '2020-06-21', 'KLS-03'),
            ('KEL-0153', 'Keluarga Rahayu Situmorang', 'Aktif', '2022-11-02', 'KLS-03'),
            ('KEL-0154', 'Keluarga Robertus Wahyu Tjandra', 'Aktif', '2014-11-26', 'KLS-03'),
            ('KEL-0155', 'Keluarga Ignatius Teguh Kusuma', 'Aktif', '2011-01-13', 'KLS-03'),
            ('KEL-0156', 'Keluarga Vincentius Hadi Prasetyo', 'Aktif', '2023-09-10', 'KLS-03'),
            ('KEL-0157', 'Keluarga Eko Tjandra', 'Aktif', '2010-06-10', 'KLS-03'),
            ('KEL-0158', 'Keluarga Bernardus Nugraha', 'Aktif', '2021-07-01', 'KLS-03'),
            ('KEL-0159', 'Keluarga Adi Saputra', 'Aktif', '2018-04-07', 'KLS-03'),
            ('KEL-0160', 'Keluarga Robertus Dwi Lalamentik', 'Pindah Paroki', '2024-06-17', 'KLS-03'),
            ('KEL-0161', 'Keluarga Hendra Hutabarat', 'Aktif', '2025-06-20', 'KLS-03'),
            ('KEL-0162', 'Keluarga Antonius Budiman', 'Aktif', '2018-08-19', 'KLS-03'),
            ('KEL-0163', 'Keluarga Sri Lewar', 'Aktif', '2017-09-20', 'KLS-03'),
            ('KEL-0164', 'Keluarga Gregorius Adi Rumbayan', 'Aktif', '2011-08-20', 'KLS-03'),
            ('KEL-0165', 'Keluarga Stefanus Budi Santoso', 'Aktif', '2023-02-18', 'KLS-03'),
            ('KEL-0166', 'Keluarga Antonius Adi Hutabarat', 'Aktif', '2020-10-29', 'KLS-03'),
            ('KEL-0167', 'Keluarga Thomas Indra Handoko', 'Aktif', '2015-12-03', 'KLS-03'),
            ('KEL-0168', 'Keluarga Antonius Lukman', 'Aktif', '2021-05-29', 'KLS-03'),
            ('KEL-0169', 'Keluarga Robertus Cahyo Prasetyo', 'Aktif', '2008-03-12', 'KLS-03'),
            ('KEL-0170', 'Keluarga Andreas Danu Nugraha', 'Aktif', '2009-11-09', 'KLS-03'),
            ('KEL-0171', 'Keluarga Gregorius Eko Koten', 'Aktif', '2021-10-24', 'KLS-03'),
            ('KEL-0172', 'Keluarga Kristoforus Putra Siregar', 'Aktif', '2009-07-03', 'KLS-03'),
            ('KEL-0173', 'Keluarga Yohanes Pratama', 'Aktif', '2009-08-12', 'KLS-03'),
            ('KEL-0174', 'Keluarga Aryo Rumbayan', 'Aktif', '2010-02-01', 'KLS-03'),
            ('KEL-0175', 'Keluarga Danu Sihombing', 'Aktif', '2018-03-15', 'KLS-03'),
            ('KEL-0176', 'Keluarga Markus Teguh Kleden', 'Pindah Paroki', '2021-02-06', 'KLS-03'),
            ('KEL-0177', 'Keluarga Albertus Lukito Hutabarat', 'Aktif', '2013-06-15', 'KLS-03'),
            ('KEL-0178', 'Keluarga Putri Mamengko', 'Aktif', '2019-02-19', 'KLS-03'),
            ('KEL-0179', 'Keluarga Ratna Kaunang', 'Aktif', '2008-02-11', 'KLS-03'),
            ('KEL-0180', 'Keluarga Ratna Purnomo', 'Aktif', '2011-01-08', 'KLS-03'),
            ('KEL-0181', 'Keluarga Petrus Aryo Tjandra', 'Aktif', '2012-06-28', 'KLS-03'),
            ('KEL-0182', 'Keluarga Fransiskus Rudi Tanujaya', 'Aktif', '2021-03-20', 'KLS-03'),
            ('KEL-0183', 'Keluarga Aloysius Kaunang', 'Aktif', '2023-03-10', 'KLS-03'),
            ('KEL-0184', 'Keluarga Dominika Sri Sihombing', 'Aktif', '2011-05-02', 'KLS-03'),
            ('KEL-0185', 'Keluarga Bernardus Danu Hutabarat', 'Aktif', '2024-10-06', 'KLS-03'),
            ('KEL-0186', 'Keluarga Ignatius Putra Susanto', 'Aktif', '2018-09-02', 'KLS-03'),
            ('KEL-0187', 'Keluarga Dominika Wulan Budiman', 'Pindah Paroki', '2023-06-09', 'KLS-03'),
            ('KEL-0188', 'Keluarga Andreas Surya Hartono', 'Aktif', '2018-03-10', 'KLS-03'),
            ('KEL-0189', 'Keluarga Yosef Adi Da Costa', 'Aktif', '2008-11-05', 'KLS-03'),
            ('KEL-0190', 'Keluarga Thomas Agus Utomo', 'Aktif', '2010-08-20', 'KLS-03'),
            ('KEL-0191', 'Keluarga Robertus Rudi Kurniawan', 'Pindah Paroki', '2024-07-03', 'KLS-03'),
            ('KEL-0192', 'Keluarga Budi Rahardjo', 'Aktif', '2024-01-05', 'KLS-03'),
            ('KEL-0193', 'Keluarga Yosef Rahardjo', 'Aktif', '2010-02-04', 'KLS-03'),
            ('KEL-0194', 'Keluarga Markus Nugroho Kurniawan', 'Aktif', '2011-01-07', 'KLS-03'),
            ('KEL-0195', 'Keluarga Lukito Sihombing', 'Aktif', '2018-10-01', 'KLS-03'),
            ('KEL-0196', 'Keluarga Bambang Utomo', 'Aktif', '2022-09-12', 'KLS-03'),
            ('KEL-0197', 'Keluarga Kristoforus Rudi Lewar', 'Aktif', '2020-10-30', 'KLS-03'),
            ('KEL-0198', 'Keluarga Dominikus Prasetyo', 'Aktif', '2010-06-30', 'KLS-03'),
            ('KEL-0199', 'Keluarga Hieronimus Danu Hartono', 'Aktif', '2015-05-02', 'KLS-03'),
            ('KEL-0200', 'Keluarga Rizki Saputra', 'Aktif', '2024-07-13', 'KLS-03'),
            ('KEL-0201', 'Keluarga Stefanus Bayu Hermawan', 'Aktif', '2020-08-08', 'KLS-03'),
            ('KEL-0202', 'Keluarga Albertus Teguh Lalamentik', 'Aktif', '2017-03-09', 'KLS-03'),
            ('KEL-0203', 'Keluarga Bernardus Agus Bria', 'Aktif', '2010-01-27', 'KLS-03'),
            ('KEL-0204', 'Keluarga Yosef Budi Wijaya', 'Aktif', '2018-03-24', 'KLS-03'),
            ('KEL-0205', 'Keluarga Yuni Pratama', 'Aktif', '2009-03-13', 'KLS-03'),
            ('KEL-0206', 'Keluarga Lukas Gunadi', 'Aktif', '2016-01-14', 'KLS-03'),
            ('KEL-0207', 'Keluarga Paulus Galih Santoso', 'Aktif', '2013-12-01', 'KLS-03'),
            ('KEL-0208', 'Keluarga Ignatia Wulan Rahardjo', 'Aktif', '2011-10-23', 'KLS-03'),
            ('KEL-0209', 'Keluarga Nugroho Utomo', 'Aktif', '2023-05-04', 'KLS-03'),
            ('KEL-0210', 'Keluarga Aloysius Putra Lalamentik', 'Aktif', '2023-06-26', 'KLS-03'),
            ('KEL-0211', 'Keluarga Markus Danu Sihombing', 'Aktif', '2019-07-21', 'KLS-03'),
            ('KEL-0212', 'Keluarga Antonius Kurnia Sutanto', 'Aktif', '2013-10-04', 'KLS-03'),
            ('KEL-0213', 'Keluarga Galih Gunadi', 'Aktif', '2014-11-23', 'KLS-03'),
            ('KEL-0214', 'Keluarga Agus Tampubolon', 'Aktif', '2009-01-17', 'KLS-03'),
            ('KEL-0215', 'Keluarga Ignatius Tanujaya', 'Aktif', '2015-07-13', 'KLS-03'),
            ('KEL-0216', 'Keluarga Paulus Cahyo Kurniawan', 'Aktif', '2024-01-29', 'KLS-03'),
            ('KEL-0217', 'Keluarga Aryo Gunawan', 'Aktif', '2008-10-08', 'KLS-03'),
            ('KEL-0218', 'Keluarga Albertus Danu Nugraha', 'Aktif', '2016-12-25', 'KLS-03'),
            ('KEL-0219', 'Keluarga Dominikus Teguh Santoso', 'Aktif', '2017-10-22', 'KLS-03'),
            ('KEL-0220', 'Keluarga Lukas Eko Lobo', 'Aktif', '2024-12-28', 'KLS-03'),
            ('KEL-0221', 'Keluarga Fransiskus Lewar', 'Aktif', '2023-10-02', 'KLS-03'),
            ('KEL-0222', 'Keluarga Benediktus Putra Wijaya', 'Aktif', '2024-04-28', 'KLS-03'),
            ('KEL-0223', 'Keluarga Galih Tjandra', 'Aktif', '2024-08-27', 'KLS-03'),
            ('KEL-0224', 'Keluarga Katarina Saputra', 'Aktif', '2024-04-14', 'KLS-03'),
            ('KEL-0225', 'Keluarga Stefanus Lukito Lalamentik', 'Aktif', '2025-06-04', 'KLS-03'),
            ('KEL-0226', 'Keluarga Benedikta Dian Tjandra', 'Aktif', '2025-11-17', 'KLS-03'),
            ('KEL-0227', 'Keluarga Natalia Putri Hutabarat', 'Aktif', '2024-08-26', 'KLS-03')
    ) AS v (ID_KELUARGA, NAMA_KELUARGA_FIKTIF, STATUS_KELUARGA, TANGGAL_TERDAFTAR, ID_KLASIFIKASI_DATA)
) AS s
ON t.ID_KELUARGA = s.ID_KELUARGA
WHEN MATCHED THEN UPDATE SET
    NAMA_KELUARGA_FIKTIF = s.NAMA_KELUARGA_FIKTIF,
    STATUS_KELUARGA = s.STATUS_KELUARGA,
    TANGGAL_TERDAFTAR = s.TANGGAL_TERDAFTAR,
    ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA
WHEN NOT MATCHED THEN INSERT (ID_KELUARGA, NAMA_KELUARGA_FIKTIF, STATUS_KELUARGA, TANGGAL_TERDAFTAR, ID_KLASIFIKASI_DATA)
    VALUES (s.ID_KELUARGA, s.NAMA_KELUARGA_FIKTIF, s.STATUS_KELUARGA, s.TANGGAL_TERDAFTAR, s.ID_KLASIFIKASI_DATA);

-- DATA_OPERASIONAL.UMAT: 653 rows
MERGE INTO DATA_OPERASIONAL.UMAT AS t
USING (
    SELECT
        v.ID_UMAT AS ID_UMAT,
        v.NAMA_FIKTIF AS NAMA_FIKTIF,
        v.JENIS_KELAMIN AS JENIS_KELAMIN,
        CAST(v.TAHUN_LAHIR AS NUMBER(4,0)) AS TAHUN_LAHIR,
        v.STATUS_KEANGGOTAAN AS STATUS_KEANGGOTAAN,
        CAST(v.TANGGAL_TERDAFTAR AS DATE) AS TANGGAL_TERDAFTAR,
        v.ID_KLASIFIKASI_DATA AS ID_KLASIFIKASI_DATA
    FROM (VALUES
            ('UMT-00001', 'Dominika Dian Sutanto', 'Perempuan', 1977, 'Aktif', '2014-03-28', 'KLS-03'),
            ('UMT-00002', 'Bernardus Kurnia Hartono', 'Laki-laki', 1979, 'Aktif', '2014-03-28', 'KLS-03'),
            ('UMT-00003', 'Ferry Sutanto', 'Laki-laki', 2007, 'Aktif', '2014-03-28', 'KLS-03'),
            ('UMT-00004', 'Yosef Manurung', 'Laki-laki', 1981, 'Aktif', '2013-11-14', 'KLS-03'),
            ('UMT-00005', 'Benedikta Manurung', 'Perempuan', 1982, 'Aktif', '2013-11-14', 'KLS-03'),
            ('UMT-00006', 'Yohanes Indra Manurung', 'Laki-laki', 2009, 'Aktif', '2013-11-14', 'KLS-03'),
            ('UMT-00007', 'Maria Citra Manurung', 'Perempuan', 2025, 'Aktif', '2025-06-30', 'KLS-04'),
            ('UMT-00008', 'Rosalia Sri Manurung', 'Perempuan', 1955, 'Aktif', '2013-11-14', 'KLS-03'),
            ('UMT-00009', 'Eko Gunawan', 'Laki-laki', 1971, 'Aktif', '2024-04-02', 'KLS-03'),
            ('UMT-00010', 'Yustina Utami Gunawan', 'Perempuan', 1971, 'Aktif', '2024-04-02', 'KLS-03'),
            ('UMT-00011', 'Hieronimus Eko Gunawan', 'Laki-laki', 2022, 'Aktif', '2024-04-02', 'KLS-04'),
            ('UMT-00012', 'Matius Lukito Gunawan', 'Laki-laki', 2023, 'Aktif', '2024-04-02', 'KLS-04'),
            ('UMT-00013', 'Endang Gunawan', 'Perempuan', 2018, 'Aktif', '2024-04-02', 'KLS-04'),
            ('UMT-00014', 'Benediktus Galih Setiawan', 'Laki-laki', 1991, 'Aktif', '2022-07-17', 'KLS-03'),
            ('UMT-00015', 'Nilam Setiawan', 'Perempuan', 1992, 'Aktif', '2022-07-17', 'KLS-03'),
            ('UMT-00016', 'Bernardus Indra Setiawan', 'Laki-laki', 2022, 'Aktif', '2022-07-17', 'KLS-04'),
            ('UMT-00017', 'Surya Tallo', 'Laki-laki', 1988, 'Aktif', '2011-05-11', 'KLS-03'),
            ('UMT-00018', 'Yuni Tallo', 'Perempuan', 1984, 'Aktif', '2011-05-11', 'KLS-03'),
            ('UMT-00019', 'Nilam Hartono', 'Perempuan', 1978, 'Aktif', '2009-04-18', 'KLS-03'),
            ('UMT-00020', 'Yudha Hartono', 'Laki-laki', 2003, 'Aktif', '2009-04-18', 'KLS-03'),
            ('UMT-00021', 'Hieronimus Cahyo Hartono', 'Laki-laki', 2013, 'Aktif', '2013-06-30', 'KLS-04'),
            ('UMT-00022', 'Emanuel Panjaitan', 'Laki-laki', 1954, 'Aktif', '2018-07-13', 'KLS-03'),
            ('UMT-00023', 'Katarina Kleden', 'Perempuan', 1954, 'Aktif', '2018-07-13', 'KLS-03'),
            ('UMT-00024', 'Yosef Hidayat', 'Laki-laki', 1980, 'Aktif', '2022-05-13', 'KLS-03'),
            ('UMT-00025', 'Elisabeth Hidayat', 'Perempuan', 1981, 'Aktif', '2022-05-13', 'KLS-03'),
            ('UMT-00026', 'Dominika Gita Hidayat', 'Perempuan', 2025, 'Aktif', '2025-06-30', 'KLS-04'),
            ('UMT-00027', 'Kristoforus Gunawan', 'Laki-laki', 1979, 'Aktif', '2008-11-21', 'KLS-03'),
            ('UMT-00028', 'Veronika Rina Gunawan', 'Perempuan', 1982, 'Aktif', '2008-11-21', 'KLS-03'),
            ('UMT-00029', 'Fransiskus Joko Gunawan', 'Laki-laki', 2020, 'Aktif', '2020-06-30', 'KLS-04'),
            ('UMT-00030', 'Benedikta Utami Gunawan', 'Perempuan', 2007, 'Aktif', '2008-11-21', 'KLS-03'),
            ('UMT-00031', 'Rosalia Nilam Gunawan', 'Perempuan', 1949, 'Aktif', '2008-11-21', 'KLS-03'),
            ('UMT-00032', 'Matius Hendra Santoso', 'Laki-laki', 1968, 'Aktif', '2020-05-03', 'KLS-03'),
            ('UMT-00033', 'Clara Setiawan', 'Perempuan', 1966, 'Aktif', '2020-05-03', 'KLS-03'),
            ('UMT-00034', 'Hieronimus Nugroho Santoso', 'Laki-laki', 2018, 'Aktif', '2020-05-03', 'KLS-04'),
            ('UMT-00035', 'Ignatius Lukito Purnomo', 'Laki-laki', 1968, 'Aktif', '2021-07-03', 'KLS-03'),
            ('UMT-00036', 'Antonius Lukito Ndoen', 'Laki-laki', 1968, 'Aktif', '2019-09-05', 'KLS-03'),
            ('UMT-00037', 'Citra Ndoen', 'Perempuan', 1967, 'Aktif', '2019-09-05', 'KLS-03'),
            ('UMT-00038', 'Regina Mira Ndoen', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00039', 'Adi Ndoen', 'Laki-laki', 2013, 'Aktif', '2019-09-05', 'KLS-04'),
            ('UMT-00040', 'Elisabeth Indah Ndoen', 'Perempuan', 1938, 'Aktif', '2019-09-05', 'KLS-03'),
            ('UMT-00041', 'Yohana Citra Halim', 'Perempuan', 1989, 'Aktif', '2023-02-01', 'KLS-03'),
            ('UMT-00042', 'Antonius Adi Halim', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00043', 'Stefanus Setiawan', 'Laki-laki', 1971, 'Aktif', '2016-03-10', 'KLS-03'),
            ('UMT-00044', 'Rosalia Ening Setiawan', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00045', 'Indra Setiawan', 'Laki-laki', 2013, 'Aktif', '2016-03-10', 'KLS-04'),
            ('UMT-00046', 'Yosef Rizki Kusuma', 'Laki-laki', 1972, 'Aktif', '2015-02-11', 'KLS-03'),
            ('UMT-00047', 'Monika Nilam Susanto', 'Perempuan', 1969, 'Aktif', '2015-02-11', 'KLS-03'),
            ('UMT-00048', 'Regina Kusuma', 'Perempuan', 2012, 'Aktif', '2015-02-11', 'KLS-04'),
            ('UMT-00049', 'Ignatius Ferry Simanjuntak', 'Laki-laki', 1978, 'Aktif', '2013-04-09', 'KLS-03'),
            ('UMT-00050', 'Tuti Simanjuntak', 'Perempuan', 1980, 'Aktif', '2013-04-09', 'KLS-03'),
            ('UMT-00051', 'Aloysius Simanjuntak', 'Laki-laki', 2011, 'Aktif', '2013-04-09', 'KLS-04'),
            ('UMT-00052', 'Nugroho Simanjuntak', 'Laki-laki', 2008, 'Aktif', '2013-04-09', 'KLS-03'),
            ('UMT-00053', 'Agnes Fitri Simanjuntak', 'Perempuan', 2014, 'Aktif', '2014-06-30', 'KLS-04'),
            ('UMT-00054', 'Putra Rumbayan', 'Laki-laki', 1985, 'Aktif', '2019-08-31', 'KLS-03'),
            ('UMT-00055', 'Helena Bria', 'Perempuan', 1983, 'Aktif', '2019-08-31', 'KLS-03'),
            ('UMT-00056', 'Maria Rahardjo', 'Perempuan', 1987, 'Aktif', '2015-05-21', 'KLS-03'),
            ('UMT-00057', 'Krisna Sihombing', 'Laki-laki', 1990, 'Aktif', '2016-05-29', 'KLS-03'),
            ('UMT-00058', 'Clara Sihombing', 'Perempuan', 1991, 'Aktif', '2016-05-29', 'KLS-03'),
            ('UMT-00059', 'Gregorius Adi Sihombing', 'Laki-laki', 2012, 'Aktif', '2016-05-29', 'KLS-04'),
            ('UMT-00060', 'Krisna Nugraha', 'Laki-laki', 1977, 'Aktif', '2017-04-07', 'KLS-03'),
            ('UMT-00061', 'Citra Nugraha', 'Perempuan', 1975, 'Aktif', '2017-04-07', 'KLS-03'),
            ('UMT-00062', 'Surya Nugraha', 'Laki-laki', 2017, 'Aktif', '2017-06-30', 'KLS-04'),
            ('UMT-00063', 'Stefanus Lukito Nugraha', 'Laki-laki', 2006, 'Aktif', '2017-04-07', 'KLS-03'),
            ('UMT-00064', 'Stefanus Nugraha', 'Laki-laki', 2012, 'Aktif', '2017-04-07', 'KLS-04'),
            ('UMT-00065', 'Lukas Agus Tjandra', 'Laki-laki', 1974, 'Aktif', '2020-07-28', 'KLS-03'),
            ('UMT-00066', 'Ratna Tjandra', 'Perempuan', 1971, 'Aktif', '2020-07-28', 'KLS-03'),
            ('UMT-00067', 'Matius Agus Ndoen', 'Laki-laki', 1956, 'Pindah Paroki', '2008-11-09', 'KLS-03'),
            ('UMT-00068', 'Veronika Endang Ndoen', 'Perempuan', 1955, 'Pindah Paroki', '2008-11-09', 'KLS-03'),
            ('UMT-00069', 'Kristoforus Rumbayan', 'Laki-laki', 1991, 'Aktif', '2015-08-29', 'KLS-03'),
            ('UMT-00070', 'Dian Tanujaya', 'Perempuan', 1991, 'Aktif', '2015-08-29', 'KLS-03'),
            ('UMT-00071', 'Ignatius Rumbayan', 'Laki-laki', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00072', 'Maria Sri Rumbayan', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00073', 'Rizki Rumbayan', 'Laki-laki', 2019, 'Aktif', '2019-06-30', 'KLS-04'),
            ('UMT-00074', 'Aloysius Dedi Rumbayan', 'Laki-laki', 1966, 'Aktif', '2015-08-29', 'KLS-03'),
            ('UMT-00075', 'Yudha Sihombing', 'Laki-laki', 1977, 'Pindah Paroki', '2016-03-11', 'KLS-03'),
            ('UMT-00076', 'Lusia Gunadi', 'Perempuan', 1978, 'Pindah Paroki', '2016-03-11', 'KLS-03'),
            ('UMT-00077', 'Veronika Gita Sihombing', 'Perempuan', 2009, 'Pindah Paroki', '2016-03-11', 'KLS-03'),
            ('UMT-00078', 'Clara Rahayu Prasetyo', 'Perempuan', 1982, 'Aktif', '2021-11-16', 'KLS-03'),
            ('UMT-00079', 'Rosalia Prasetyo', 'Perempuan', 2021, 'Aktif', '2021-11-16', 'KLS-04'),
            ('UMT-00080', 'Paulus Lalamentik', 'Laki-laki', 1976, 'Aktif', '2025-01-27', 'KLS-03'),
            ('UMT-00081', 'Ening Utomo', 'Perempuan', 1977, 'Aktif', '2025-01-27', 'KLS-03'),
            ('UMT-00082', 'Bernadeta Gita Lalamentik', 'Perempuan', 2012, 'Aktif', '2025-01-27', 'KLS-04'),
            ('UMT-00083', 'Stefanus Lukito Lalamentik', 'Laki-laki', 1998, 'Aktif', '2025-01-27', 'KLS-03'),
            ('UMT-00084', 'Aryo Lalamentik', 'Laki-laki', 2015, 'Aktif', '2025-01-27', 'KLS-04'),
            ('UMT-00085', 'Aloysius Ferry Siregar', 'Laki-laki', 1986, 'Aktif', '2009-02-15', 'KLS-03'),
            ('UMT-00086', 'Fransiska Sari Siregar', 'Perempuan', 1989, 'Aktif', '2009-02-15', 'KLS-03'),
            ('UMT-00087', 'Agus Simanjuntak', 'Laki-laki', 1987, 'Aktif', '2021-07-24', 'KLS-03'),
            ('UMT-00088', 'Agnes Mira Simanjuntak', 'Perempuan', 1985, 'Aktif', '2021-07-24', 'KLS-03'),
            ('UMT-00089', 'Regina Ening Simanjuntak', 'Perempuan', 2012, 'Aktif', '2021-07-24', 'KLS-04'),
            ('UMT-00090', 'Maria Hesti Simanjuntak', 'Perempuan', 2012, 'Aktif', '2021-07-24', 'KLS-04'),
            ('UMT-00091', 'Theresia Dewi Simanjuntak', 'Perempuan', 2010, 'Aktif', '2021-07-24', 'KLS-04'),
            ('UMT-00092', 'Paulus Purnomo', 'Laki-laki', 1980, 'Aktif', '2021-12-05', 'KLS-03'),
            ('UMT-00093', 'Bernadeta Dian Purnomo', 'Perempuan', 1976, 'Aktif', '2021-12-05', 'KLS-03'),
            ('UMT-00094', 'Angela Purnomo', 'Perempuan', 2009, 'Aktif', '2021-12-05', 'KLS-03'),
            ('UMT-00095', 'Benediktus Rizki Ndoen', 'Laki-laki', 1991, 'Aktif', '2023-07-17', 'KLS-03'),
            ('UMT-00096', 'Dewi Rahardjo', 'Perempuan', 1992, 'Aktif', '2023-07-17', 'KLS-03'),
            ('UMT-00097', 'Natalia Endang Ndoen', 'Perempuan', 2023, 'Aktif', '2023-07-17', 'KLS-04'),
            ('UMT-00098', 'Helena Melati Ndoen', 'Perempuan', 2023, 'Aktif', '2023-07-17', 'KLS-04'),
            ('UMT-00099', 'Paulus Ndoen', 'Laki-laki', 2021, 'Aktif', '2023-07-17', 'KLS-04'),
            ('UMT-00100', 'Vincentius Hadi Situmorang', 'Laki-laki', 1990, 'Aktif', '2015-06-27', 'KLS-03'),
            ('UMT-00101', 'Bernadeta Sri Situmorang', 'Perempuan', 1987, 'Aktif', '2015-06-27', 'KLS-03'),
            ('UMT-00102', 'Andreas Hendra Situmorang', 'Laki-laki', 2014, 'Aktif', '2015-06-27', 'KLS-04'),
            ('UMT-00103', 'Anastasia Sri Purnomo', 'Perempuan', 1987, 'Aktif', '2014-12-25', 'KLS-03'),
            ('UMT-00104', 'Emanuel Rizki Purnomo', 'Laki-laki', 1988, 'Aktif', '2014-12-25', 'KLS-03'),
            ('UMT-00105', 'Katarina Endang Purnomo', 'Perempuan', 2010, 'Aktif', '2014-12-25', 'KLS-04'),
            ('UMT-00106', 'Dominika Purnomo', 'Perempuan', 2011, 'Aktif', '2014-12-25', 'KLS-04'),
            ('UMT-00107', 'Aloysius Dwi Purnomo', 'Laki-laki', 1975, 'Aktif', '2013-11-23', 'KLS-03'),
            ('UMT-00108', 'Endang Pratama', 'Perempuan', 1976, 'Aktif', '2013-11-23', 'KLS-03'),
            ('UMT-00109', 'Vincentius Purnomo', 'Laki-laki', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00110', 'Petrus Dedi Hermawan', 'Laki-laki', 1970, 'Aktif', '2020-09-16', 'KLS-03'),
            ('UMT-00111', 'Wulan Hermawan', 'Perempuan', 1971, 'Aktif', '2020-09-16', 'KLS-03'),
            ('UMT-00112', 'Stefanus Hermawan', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00113', 'Paulus Joko Hermawan', 'Laki-laki', 2000, 'Aktif', '2020-09-16', 'KLS-03'),
            ('UMT-00114', 'Robertus Yudha Hermawan', 'Laki-laki', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00115', 'Vincentius Budi Manurung', 'Laki-laki', 1981, 'Aktif', '2019-09-10', 'KLS-03'),
            ('UMT-00116', 'Putri Handoko', 'Perempuan', 1978, 'Aktif', '2019-09-10', 'KLS-03'),
            ('UMT-00117', 'Indra Manurung', 'Laki-laki', 2014, 'Aktif', '2019-09-10', 'KLS-04'),
            ('UMT-00118', 'Lukas Teguh Manurung', 'Laki-laki', 2017, 'Aktif', '2019-09-10', 'KLS-04'),
            ('UMT-00119', 'Lestari Nugraha', 'Perempuan', 1971, 'Aktif', '2018-03-16', 'KLS-03'),
            ('UMT-00120', 'Petrus Krisna Handoko', 'Laki-laki', 1973, 'Aktif', '2018-03-16', 'KLS-03'),
            ('UMT-00121', 'Markus Surya Bria', 'Laki-laki', 1983, 'Aktif', '2020-11-25', 'KLS-03'),
            ('UMT-00122', 'Theresia Fitri Mamengko', 'Perempuan', 1984, 'Aktif', '2020-11-25', 'KLS-03'),
            ('UMT-00123', 'Benediktus Krisna Nugraha', 'Laki-laki', 1984, 'Aktif', '2008-10-12', 'KLS-03'),
            ('UMT-00124', 'Theresia Mira Tallo', 'Perempuan', 1987, 'Aktif', '2008-10-12', 'KLS-03'),
            ('UMT-00125', 'Helena Dian Nugraha', 'Perempuan', 2009, 'Aktif', '2009-06-30', 'KLS-03'),
            ('UMT-00126', 'Indah Da Costa', 'Perempuan', 1979, 'Aktif', '2016-10-23', 'KLS-03'),
            ('UMT-00127', 'Sari Da Costa', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00128', 'Raka Siregar', 'Laki-laki', 1978, 'Aktif', '2024-03-18', 'KLS-03'),
            ('UMT-00129', 'Fransiska Siregar', 'Perempuan', 1977, 'Aktif', '2024-03-18', 'KLS-03'),
            ('UMT-00130', 'Bernardus Bayu Siregar', 'Laki-laki', 2007, 'Aktif', '2024-03-18', 'KLS-03'),
            ('UMT-00131', 'Melati Siregar', 'Perempuan', 2014, 'Aktif', '2024-03-18', 'KLS-04'),
            ('UMT-00132', 'Ignatius Dwi Wijaya', 'Laki-laki', 1973, 'Aktif', '2016-03-06', 'KLS-03'),
            ('UMT-00133', 'Wulan Wijaya', 'Perempuan', 1971, 'Aktif', '2016-03-06', 'KLS-03'),
            ('UMT-00134', 'Benediktus Putra Wijaya', 'Laki-laki', 1998, 'Aktif', '2016-03-06', 'KLS-03'),
            ('UMT-00135', 'Gregorius Wijaya', 'Laki-laki', 2014, 'Aktif', '2016-03-06', 'KLS-04'),
            ('UMT-00136', 'Kurnia Wijaya', 'Laki-laki', 2006, 'Aktif', '2016-03-06', 'KLS-03'),
            ('UMT-00137', 'Markus Joko Wijaya', 'Laki-laki', 1949, 'Meninggal Dunia', '2016-03-06', 'KLS-03'),
            ('UMT-00138', 'Emanuel Ferry Simanjuntak', 'Laki-laki', 1970, 'Aktif', '2009-01-08', 'KLS-03'),
            ('UMT-00139', 'Angela Intan Simanjuntak', 'Perempuan', 1969, 'Aktif', '2009-01-08', 'KLS-03'),
            ('UMT-00140', 'Fransiskus Hermawan', 'Laki-laki', 1988, 'Aktif', '2018-03-15', 'KLS-03'),
            ('UMT-00141', 'Angela Gita Koten', 'Perempuan', 1984, 'Aktif', '2018-03-15', 'KLS-03'),
            ('UMT-00142', 'Ignatius Budi Kurniawan', 'Laki-laki', 1982, 'Aktif', '2016-06-19', 'KLS-03'),
            ('UMT-00143', 'Endang Kurniawan', 'Perempuan', 1979, 'Aktif', '2016-06-19', 'KLS-03'),
            ('UMT-00144', 'Ignatius Surya Kurniawan', 'Laki-laki', 2008, 'Aktif', '2016-06-19', 'KLS-03'),
            ('UMT-00145', 'Paulus Dedi Kurniawan', 'Laki-laki', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00146', 'Stefanus Joko Nainggolan', 'Laki-laki', 1959, 'Aktif', '2019-05-18', 'KLS-03'),
            ('UMT-00147', 'Natalia Dewi Nainggolan', 'Perempuan', 1958, 'Aktif', '2019-05-18', 'KLS-03'),
            ('UMT-00148', 'Emanuel Bambang Pratama', 'Laki-laki', 1982, 'Aktif', '2019-12-13', 'KLS-03'),
            ('UMT-00149', 'Tuti Da Costa', 'Perempuan', 1980, 'Aktif', '2019-12-13', 'KLS-03'),
            ('UMT-00150', 'Theresia Nilam Pratama', 'Perempuan', 2017, 'Aktif', '2019-12-13', 'KLS-04'),
            ('UMT-00151', 'Markus Hendra Hidayat', 'Laki-laki', 1971, 'Aktif', '2023-07-23', 'KLS-03'),
            ('UMT-00152', 'Kristoforus Hidayat', 'Laki-laki', 2025, 'Aktif', '2025-06-30', 'KLS-04'),
            ('UMT-00153', 'Lukas Krisna Hermawan', 'Laki-laki', 1968, 'Aktif', '2017-08-25', 'KLS-03'),
            ('UMT-00154', 'Clara Hesti Saputra', 'Perempuan', 1970, 'Aktif', '2017-08-25', 'KLS-03'),
            ('UMT-00155', 'Clara Hermawan', 'Perempuan', 2010, 'Aktif', '2017-08-25', 'KLS-04'),
            ('UMT-00156', 'Hieronimus Hendra Mamengko', 'Laki-laki', 1977, 'Aktif', '2015-03-15', 'KLS-03'),
            ('UMT-00157', 'Lusia Rina Mamengko', 'Perempuan', 1977, 'Aktif', '2015-03-15', 'KLS-03'),
            ('UMT-00158', 'Thomas Raka Mamengko', 'Laki-laki', 2002, 'Aktif', '2015-03-15', 'KLS-03'),
            ('UMT-00159', 'Theresia Sari Mamengko', 'Perempuan', 1999, 'Aktif', '2015-03-15', 'KLS-03'),
            ('UMT-00160', 'Fransiska Kartika Mamengko', 'Perempuan', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00161', 'Robertus Kurnia Mamengko', 'Laki-laki', 1948, 'Aktif', '2015-03-15', 'KLS-03'),
            ('UMT-00162', 'Maria Lewar', 'Perempuan', 1968, 'Aktif', '2022-06-11', 'KLS-03'),
            ('UMT-00163', 'Bambang Simanjuntak', 'Laki-laki', 1968, 'Aktif', '2022-06-11', 'KLS-03'),
            ('UMT-00164', 'Yohana Hesti Lewar', 'Perempuan', 2001, 'Aktif', '2022-06-11', 'KLS-03'),
            ('UMT-00165', 'Yohana Lewar', 'Perempuan', 2013, 'Aktif', '2022-06-11', 'KLS-04'),
            ('UMT-00166', 'Ignatius Hadi Kaunang', 'Laki-laki', 1974, 'Aktif', '2011-01-15', 'KLS-03'),
            ('UMT-00167', 'Fransiska Kaunang', 'Perempuan', 1970, 'Aktif', '2011-01-15', 'KLS-03'),
            ('UMT-00168', 'Fransiskus Wahyu Manurung', 'Laki-laki', 1978, 'Aktif', '2012-01-30', 'KLS-03'),
            ('UMT-00169', 'Katarina Melati Budiman', 'Perempuan', 1981, 'Aktif', '2012-01-30', 'KLS-03'),
            ('UMT-00170', 'Intan Manurung', 'Perempuan', 2019, 'Aktif', '2019-06-30', 'KLS-04'),
            ('UMT-00171', 'Indah Manurung', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00172', 'Endang Manurung', 'Perempuan', 2012, 'Aktif', '2012-06-30', 'KLS-04'),
            ('UMT-00173', 'Matius Gunawan', 'Laki-laki', 1972, 'Aktif', '2017-09-05', 'KLS-03'),
            ('UMT-00174', 'Ignatia Intan Gunawan', 'Perempuan', 1968, 'Aktif', '2017-09-05', 'KLS-03'),
            ('UMT-00175', 'Dwi Gunawan', 'Laki-laki', 1998, 'Pindah Paroki', '2017-09-05', 'KLS-03'),
            ('UMT-00176', 'Katarina Mira Mamengko', 'Perempuan', 1984, 'Aktif', '2014-09-13', 'KLS-03'),
            ('UMT-00177', 'Aloysius Budi Koten', 'Laki-laki', 1977, 'Aktif', '2020-07-18', 'KLS-03'),
            ('UMT-00178', 'Anastasia Endang Koten', 'Perempuan', 1976, 'Aktif', '2020-07-18', 'KLS-03'),
            ('UMT-00179', 'Intan Koten', 'Perempuan', 2016, 'Aktif', '2020-07-18', 'KLS-04'),
            ('UMT-00180', 'Elisabeth Melati Koten', 'Perempuan', 2005, 'Aktif', '2020-07-18', 'KLS-03'),
            ('UMT-00181', 'Raka Wijaya', 'Laki-laki', 1991, 'Aktif', '2010-09-15', 'KLS-03'),
            ('UMT-00182', 'Mira Tallo', 'Perempuan', 1985, 'Aktif', '2024-07-15', 'KLS-03'),
            ('UMT-00183', 'Nugroho Hartono', 'Laki-laki', 1973, 'Aktif', '2024-03-02', 'KLS-03'),
            ('UMT-00184', 'Lusia Citra Manurung', 'Perempuan', 1973, 'Aktif', '2024-03-02', 'KLS-03'),
            ('UMT-00185', 'Sri Hartono', 'Perempuan', 1997, 'Aktif', '2024-03-02', 'KLS-03'),
            ('UMT-00186', 'Yosef Budi Hartono', 'Laki-laki', 2014, 'Aktif', '2024-03-02', 'KLS-04'),
            ('UMT-00187', 'Ignatia Rahayu Gunawan', 'Perempuan', 1966, 'Aktif', '2009-10-22', 'KLS-03'),
            ('UMT-00188', 'Matius Dedi Tallo', 'Laki-laki', 1982, 'Aktif', '2016-11-10', 'KLS-03'),
            ('UMT-00189', 'Rosalia Melati Tallo', 'Perempuan', 1981, 'Aktif', '2016-11-10', 'KLS-03'),
            ('UMT-00190', 'Robertus Yudha Tanujaya', 'Laki-laki', 1992, 'Aktif', '2009-11-05', 'KLS-03'),
            ('UMT-00191', 'Dominika Tanujaya', 'Perempuan', 1995, 'Aktif', '2009-11-05', 'KLS-03'),
            ('UMT-00192', 'Putra Tanujaya', 'Laki-laki', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00193', 'Emanuel Wahyu Wibowo', 'Laki-laki', 1948, 'Aktif', '2014-02-27', 'KLS-03'),
            ('UMT-00194', 'Clara Endang Mamengko', 'Perempuan', 1948, 'Meninggal Dunia', '2014-02-27', 'KLS-03'),
            ('UMT-00195', 'Yustina Kartika Gunadi', 'Perempuan', 1968, 'Aktif', '2017-05-23', 'KLS-03'),
            ('UMT-00196', 'Andreas Eko Lewar', 'Laki-laki', 1969, 'Aktif', '2017-05-23', 'KLS-03'),
            ('UMT-00197', 'Hieronimus Dwi Lalamentik', 'Laki-laki', 1983, 'Aktif', '2017-03-19', 'KLS-03'),
            ('UMT-00198', 'Rahayu Lalamentik', 'Perempuan', 1982, 'Aktif', '2017-03-19', 'KLS-03'),
            ('UMT-00199', 'Robertus Lalamentik', 'Laki-laki', 2013, 'Aktif', '2017-03-19', 'KLS-04'),
            ('UMT-00200', 'Rina Lalamentik', 'Perempuan', 2010, 'Aktif', '2017-03-19', 'KLS-04'),
            ('UMT-00201', 'Yosef Rizki Lalamentik', 'Laki-laki', 1954, 'Aktif', '2017-03-19', 'KLS-03'),
            ('UMT-00202', 'Andreas Kurnia Koten', 'Laki-laki', 1991, 'Aktif', '2020-01-28', 'KLS-03'),
            ('UMT-00203', 'Margareta Indah Koten', 'Perempuan', 1990, 'Aktif', '2020-01-28', 'KLS-03'),
            ('UMT-00204', 'Katarina Intan Koten', 'Perempuan', 2018, 'Aktif', '2020-01-28', 'KLS-04'),
            ('UMT-00205', 'Bernadeta Hutabarat', 'Perempuan', 1977, 'Aktif', '2016-03-06', 'KLS-03'),
            ('UMT-00206', 'Agnes Nilam Hutabarat', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00207', 'Nugroho Hermawan', 'Laki-laki', 1990, 'Aktif', '2016-04-11', 'KLS-03'),
            ('UMT-00208', 'Dominika Hesti Hermawan', 'Perempuan', 1990, 'Aktif', '2016-04-11', 'KLS-03'),
            ('UMT-00209', 'Ayu Hermawan', 'Perempuan', 2013, 'Aktif', '2016-04-11', 'KLS-04'),
            ('UMT-00210', 'Rizki Hermawan', 'Laki-laki', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00211', 'Lukas Dedi Lukman', 'Laki-laki', 1978, 'Aktif', '2013-06-22', 'KLS-03'),
            ('UMT-00212', 'Sri Siregar', 'Perempuan', 1980, 'Aktif', '2013-06-22', 'KLS-03'),
            ('UMT-00213', 'Dominikus Bambang Budiman', 'Laki-laki', 1965, 'Aktif', '2016-05-03', 'KLS-03'),
            ('UMT-00214', 'Maria Dewi Tallo', 'Perempuan', 1978, 'Aktif', '2019-04-03', 'KLS-03'),
            ('UMT-00215', 'Yosef Tallo', 'Laki-laki', 1974, 'Aktif', '2019-04-03', 'KLS-03'),
            ('UMT-00216', 'Katarina Tuti Tallo', 'Perempuan', 2005, 'Aktif', '2019-04-03', 'KLS-03'),
            ('UMT-00217', 'Kristoforus Budi Handoko', 'Laki-laki', 1981, 'Aktif', '2022-02-09', 'KLS-03'),
            ('UMT-00218', 'Cecilia Sri Handoko', 'Perempuan', 1977, 'Aktif', '2022-02-09', 'KLS-03'),
            ('UMT-00219', 'Galih Kleden', 'Laki-laki', 1982, 'Aktif', '2011-06-18', 'KLS-03'),
            ('UMT-00220', 'Lestari Kleden', 'Perempuan', 1979, 'Aktif', '2011-06-18', 'KLS-03'),
            ('UMT-00221', 'Markus Kleden', 'Laki-laki', 2014, 'Aktif', '2014-06-30', 'KLS-04'),
            ('UMT-00222', 'Rosalia Endang Kleden', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00223', 'Yohanes Joko Rahardjo', 'Laki-laki', 1980, 'Aktif', '2012-11-15', 'KLS-03'),
            ('UMT-00224', 'Bayu Santoso', 'Laki-laki', 1981, 'Aktif', '2013-11-06', 'KLS-03'),
            ('UMT-00225', 'Stefanus Indra Hartono', 'Laki-laki', 1947, 'Aktif', '2020-08-08', 'KLS-03'),
            ('UMT-00226', 'Hesti Hartono', 'Perempuan', 1950, 'Aktif', '2020-08-08', 'KLS-03'),
            ('UMT-00227', 'Albertus Budi Tallo', 'Laki-laki', 1988, 'Aktif', '2009-12-20', 'KLS-03'),
            ('UMT-00228', 'Benedikta Ening Tampubolon', 'Perempuan', 1987, 'Aktif', '2009-12-20', 'KLS-03'),
            ('UMT-00229', 'Lukas Rudi Tallo', 'Laki-laki', 2013, 'Aktif', '2013-06-30', 'KLS-04'),
            ('UMT-00230', 'Thomas Budi Tallo', 'Laki-laki', 2011, 'Aktif', '2011-06-30', 'KLS-04'),
            ('UMT-00231', 'Stefanus Panjaitan', 'Laki-laki', 1975, 'Aktif', '2020-03-10', 'KLS-03'),
            ('UMT-00232', 'Rahayu Panjaitan', 'Perempuan', 1971, 'Aktif', '2020-03-10', 'KLS-03'),
            ('UMT-00233', 'Stefanus Surya Nainggolan', 'Laki-laki', 1973, 'Aktif', '2018-07-04', 'KLS-03'),
            ('UMT-00234', 'Natalia Hesti Nainggolan', 'Perempuan', 1973, 'Aktif', '2018-07-04', 'KLS-03'),
            ('UMT-00235', 'Matius Wijaya', 'Laki-laki', 1979, 'Aktif', '2010-07-11', 'KLS-03'),
            ('UMT-00236', 'Regina Hesti Wijaya', 'Perempuan', 1981, 'Aktif', '2010-07-11', 'KLS-03'),
            ('UMT-00237', 'Margareta Rina Wijaya', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00238', 'Aloysius Nugroho Wijaya', 'Laki-laki', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00239', 'Budi Wijaya', 'Laki-laki', 2015, 'Aktif', '2015-06-30', 'KLS-04'),
            ('UMT-00240', 'Adi Santoso', 'Laki-laki', 1955, 'Aktif', '2019-06-08', 'KLS-03'),
            ('UMT-00241', 'Regina Ayu Santoso', 'Perempuan', 1955, 'Aktif', '2019-06-08', 'KLS-03'),
            ('UMT-00242', 'Stefanus Ferry Tjandra', 'Laki-laki', 1970, 'Aktif', '2022-01-09', 'KLS-03'),
            ('UMT-00243', 'Dian Tallo', 'Perempuan', 1968, 'Aktif', '2022-01-09', 'KLS-03'),
            ('UMT-00244', 'Galih Tjandra', 'Laki-laki', 1996, 'Aktif', '2022-01-09', 'KLS-03'),
            ('UMT-00245', 'Benediktus Krisna Hermawan', 'Laki-laki', 1986, 'Aktif', '2019-05-09', 'KLS-03'),
            ('UMT-00246', 'Regina Wulan Hermawan', 'Perempuan', 1982, 'Aktif', '2019-05-09', 'KLS-03'),
            ('UMT-00247', 'Indra Tjandra', 'Laki-laki', 1987, 'Aktif', '2015-07-12', 'KLS-03'),
            ('UMT-00248', 'Kristoforus Kurnia Tjandra', 'Laki-laki', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00249', 'Citra Tjandra', 'Perempuan', 2012, 'Aktif', '2015-07-12', 'KLS-04'),
            ('UMT-00250', 'Thomas Wahyu Hutabarat', 'Laki-laki', 1972, 'Aktif', '2011-06-23', 'KLS-03'),
            ('UMT-00251', 'Margareta Siregar', 'Perempuan', 1973, 'Aktif', '2011-06-23', 'KLS-03'),
            ('UMT-00252', 'Natalia Putri Hutabarat', 'Perempuan', 2001, 'Aktif', '2011-06-23', 'KLS-03'),
            ('UMT-00253', 'Bernardus Agus Hutabarat', 'Laki-laki', 1946, 'Aktif', '2011-06-23', 'KLS-03'),
            ('UMT-00254', 'Hadi Utomo', 'Laki-laki', 1980, 'Aktif', '2017-03-15', 'KLS-03'),
            ('UMT-00255', 'Nilam Handoko', 'Perempuan', 1976, 'Aktif', '2017-03-15', 'KLS-03'),
            ('UMT-00256', 'Elisabeth Utami Utomo', 'Perempuan', 2005, 'Aktif', '2017-03-15', 'KLS-03'),
            ('UMT-00257', 'Agnes Gita Utomo', 'Perempuan', 2002, 'Aktif', '2017-03-15', 'KLS-03'),
            ('UMT-00258', 'Bernadeta Utomo', 'Perempuan', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00259', 'Thomas Kaunang', 'Laki-laki', 1959, 'Aktif', '2020-10-28', 'KLS-03'),
            ('UMT-00260', 'Paulus Galih Rumbayan', 'Laki-laki', 1977, 'Aktif', '2020-12-01', 'KLS-03'),
            ('UMT-00261', 'Ignatia Rumbayan', 'Perempuan', 1978, 'Aktif', '2020-12-01', 'KLS-03'),
            ('UMT-00262', 'Angela Fitri Rumbayan', 'Perempuan', 2012, 'Aktif', '2020-12-01', 'KLS-04'),
            ('UMT-00263', 'Benedikta Nilam Rumbayan', 'Perempuan', 2001, 'Aktif', '2020-12-01', 'KLS-03'),
            ('UMT-00264', 'Agnes Tuti Saputra', 'Perempuan', 1973, 'Aktif', '2012-01-07', 'KLS-03'),
            ('UMT-00265', 'Elisabeth Ening Saputra', 'Perempuan', 2007, 'Aktif', '2012-01-07', 'KLS-03'),
            ('UMT-00266', 'Mira Halim', 'Perempuan', 1975, 'Aktif', '2019-10-06', 'KLS-03'),
            ('UMT-00267', 'Hieronimus Rudi Setiawan', 'Laki-laki', 1978, 'Aktif', '2019-10-06', 'KLS-03'),
            ('UMT-00268', 'Indah Halim', 'Perempuan', 2011, 'Aktif', '2019-10-06', 'KLS-04'),
            ('UMT-00269', 'Wulan Halim', 'Perempuan', 1997, 'Tidak Aktif', '2019-10-06', 'KLS-03'),
            ('UMT-00270', 'Dedi Mamengko', 'Laki-laki', 1984, 'Aktif', '2019-05-26', 'KLS-03'),
            ('UMT-00271', 'Indra Halim', 'Laki-laki', 1977, 'Aktif', '2021-01-23', 'KLS-03'),
            ('UMT-00272', 'Anastasia Mira Bria', 'Perempuan', 1978, 'Aktif', '2021-01-23', 'KLS-03'),
            ('UMT-00273', 'Albertus Lukito Halim', 'Laki-laki', 2009, 'Aktif', '2021-01-23', 'KLS-03'),
            ('UMT-00274', 'Robertus Hendra Halim', 'Laki-laki', 2007, 'Aktif', '2021-01-23', 'KLS-03'),
            ('UMT-00275', 'Rosalia Rina Halim', 'Perempuan', 2016, 'Aktif', '2021-01-23', 'KLS-04'),
            ('UMT-00276', 'Danu Tallo', 'Laki-laki', 1957, 'Aktif', '2012-11-30', 'KLS-03'),
            ('UMT-00277', 'Yohanes Rizki Kaunang', 'Laki-laki', 1949, 'Aktif', '2014-03-12', 'KLS-03'),
            ('UMT-00278', 'Nilam Kaunang', 'Perempuan', 1948, 'Aktif', '2014-03-12', 'KLS-03'),
            ('UMT-00279', 'Dominikus Pratama', 'Laki-laki', 1970, 'Aktif', '2015-05-24', 'KLS-03'),
            ('UMT-00280', 'Intan Pratama', 'Perempuan', 1966, 'Aktif', '2015-05-24', 'KLS-03'),
            ('UMT-00281', 'Robertus Kurnia Pratama', 'Laki-laki', 2008, 'Aktif', '2015-05-24', 'KLS-03'),
            ('UMT-00282', 'Andreas Wahyu Pratama', 'Laki-laki', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00283', 'Hieronimus Wahyu Budiman', 'Laki-laki', 1970, 'Aktif', '2021-03-13', 'KLS-03'),
            ('UMT-00284', 'Intan Situmorang', 'Perempuan', 1967, 'Aktif', '2021-03-13', 'KLS-03'),
            ('UMT-00285', 'Fransiska Endang Budiman', 'Perempuan', 2004, 'Aktif', '2021-03-13', 'KLS-03'),
            ('UMT-00286', 'Natalia Gita Budiman', 'Perempuan', 1999, 'Pindah Paroki', '2021-03-13', 'KLS-03'),
            ('UMT-00287', 'Cecilia Sari Budiman', 'Perempuan', 2003, 'Aktif', '2021-03-13', 'KLS-03'),
            ('UMT-00288', 'Lukito Kurniawan', 'Laki-laki', 1981, 'Aktif', '2009-03-21', 'KLS-03'),
            ('UMT-00289', 'Rina Hartono', 'Perempuan', 1981, 'Aktif', '2009-03-21', 'KLS-03'),
            ('UMT-00290', 'Kurnia Kurniawan', 'Laki-laki', 2008, 'Aktif', '2009-03-21', 'KLS-03'),
            ('UMT-00291', 'Wahyu Kurniawan', 'Laki-laki', 1980, 'Aktif', '2021-04-03', 'KLS-03'),
            ('UMT-00292', 'Ignatia Sri Siregar', 'Perempuan', 1983, 'Aktif', '2021-04-03', 'KLS-03'),
            ('UMT-00293', 'Emanuel Hadi Kurniawan', 'Laki-laki', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00294', 'Budi Kurniawan', 'Laki-laki', 2005, 'Aktif', '2021-04-03', 'KLS-03'),
            ('UMT-00295', 'Lukas Hermawan', 'Laki-laki', 1990, 'Aktif', '2024-05-02', 'KLS-03'),
            ('UMT-00296', 'Theresia Hermawan', 'Perempuan', 1990, 'Aktif', '2024-05-02', 'KLS-03'),
            ('UMT-00297', 'Agnes Ratna Hermawan', 'Perempuan', 2017, 'Aktif', '2024-05-02', 'KLS-04'),
            ('UMT-00298', 'Margareta Tuti Hermawan', 'Perempuan', 2014, 'Aktif', '2024-05-02', 'KLS-04'),
            ('UMT-00299', 'Benedikta Melati Hermawan', 'Perempuan', 2014, 'Aktif', '2024-05-02', 'KLS-04'),
            ('UMT-00300', 'Yohanes Nugraha', 'Laki-laki', 1955, 'Aktif', '2021-06-13', 'KLS-03'),
            ('UMT-00301', 'Thomas Surya Lukman', 'Laki-laki', 1969, 'Aktif', '2015-04-30', 'KLS-03'),
            ('UMT-00302', 'Elisabeth Rina Gunadi', 'Perempuan', 1968, 'Aktif', '2015-04-30', 'KLS-03'),
            ('UMT-00303', 'Margareta Lukman', 'Perempuan', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00304', 'Petrus Hadi Lukman', 'Laki-laki', 2003, 'Aktif', '2015-04-30', 'KLS-03'),
            ('UMT-00305', 'Mira Hartono', 'Perempuan', 1969, 'Aktif', '2016-07-02', 'KLS-03'),
            ('UMT-00306', 'Dominikus Dwi Rahardjo', 'Laki-laki', 1965, 'Aktif', '2016-07-02', 'KLS-03'),
            ('UMT-00307', 'Yustina Gita Hartono', 'Perempuan', 2002, 'Aktif', '2016-07-02', 'KLS-03'),
            ('UMT-00308', 'Yohanes Dwi Tanujaya', 'Laki-laki', 1976, 'Aktif', '2013-01-29', 'KLS-03'),
            ('UMT-00309', 'Lusia Sari Tanujaya', 'Perempuan', 1972, 'Aktif', '2013-01-29', 'KLS-03'),
            ('UMT-00310', 'Theresia Tuti Tanujaya', 'Perempuan', 2013, 'Aktif', '2013-06-30', 'KLS-04'),
            ('UMT-00311', 'Yosef Cahyo Tanujaya', 'Laki-laki', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00312', 'Ignatia Tanujaya', 'Perempuan', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00313', 'Albertus Galih Sihombing', 'Laki-laki', 1986, 'Aktif', '2011-10-14', 'KLS-03'),
            ('UMT-00314', 'Regina Gita Nainggolan', 'Perempuan', 1989, 'Aktif', '2011-10-14', 'KLS-03'),
            ('UMT-00315', 'Cecilia Dewi Sihombing', 'Perempuan', 2014, 'Aktif', '2014-06-30', 'KLS-04'),
            ('UMT-00316', 'Lukito Panjaitan', 'Laki-laki', 1982, 'Aktif', '2015-06-30', 'KLS-03'),
            ('UMT-00317', 'Dominika Panjaitan', 'Perempuan', 1980, 'Aktif', '2015-06-30', 'KLS-03'),
            ('UMT-00318', 'Wulan Panjaitan', 'Perempuan', 2013, 'Aktif', '2015-06-30', 'KLS-04'),
            ('UMT-00319', 'Surya Sihombing', 'Laki-laki', 1987, 'Aktif', '2011-02-01', 'KLS-03'),
            ('UMT-00320', 'Rahayu Gunadi', 'Perempuan', 1988, 'Aktif', '2011-02-01', 'KLS-03'),
            ('UMT-00321', 'Stefanus Cahyo Sihombing', 'Laki-laki', 2014, 'Aktif', '2014-06-30', 'KLS-04'),
            ('UMT-00322', 'Yohana Rahayu Sihombing', 'Perempuan', 2015, 'Aktif', '2015-06-30', 'KLS-04'),
            ('UMT-00323', 'Maria Dian Sihombing', 'Perempuan', 1963, 'Aktif', '2011-02-01', 'KLS-03'),
            ('UMT-00324', 'Aryo Santoso', 'Laki-laki', 1981, 'Aktif', '2008-06-21', 'KLS-03'),
            ('UMT-00325', 'Citra Santoso', 'Perempuan', 1983, 'Aktif', '2008-06-21', 'KLS-03'),
            ('UMT-00326', 'Veronika Intan Gunadi', 'Perempuan', 1965, 'Aktif', '2016-03-25', 'KLS-03'),
            ('UMT-00327', 'Benediktus Gunadi', 'Laki-laki', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00328', 'Ignatia Sri Gunadi', 'Perempuan', 2013, 'Aktif', '2016-03-25', 'KLS-04'),
            ('UMT-00329', 'Ignatius Wahyu Bria', 'Laki-laki', 1988, 'Aktif', '2020-09-11', 'KLS-03'),
            ('UMT-00330', 'Monika Bria', 'Perempuan', 1991, 'Aktif', '2020-09-11', 'KLS-03'),
            ('UMT-00331', 'Fransiska Bria', 'Perempuan', 2020, 'Aktif', '2020-09-11', 'KLS-04'),
            ('UMT-00332', 'Vincentius Rizki Bria', 'Laki-laki', 2018, 'Aktif', '2020-09-11', 'KLS-04'),
            ('UMT-00333', 'Andreas Budi Bria', 'Laki-laki', 2016, 'Aktif', '2020-09-11', 'KLS-04'),
            ('UMT-00334', 'Robertus Dwi Lobo', 'Laki-laki', 1975, 'Aktif', '2012-04-28', 'KLS-03'),
            ('UMT-00335', 'Fransiska Endang Rahardjo', 'Perempuan', 1976, 'Aktif', '2012-04-28', 'KLS-03'),
            ('UMT-00336', 'Benediktus Lobo', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00337', 'Elisabeth Indah Lobo', 'Perempuan', 1949, 'Aktif', '2012-04-28', 'KLS-03'),
            ('UMT-00338', 'Adi Purnomo', 'Laki-laki', 1970, 'Aktif', '2012-06-13', 'KLS-03'),
            ('UMT-00339', 'Rahayu Hermawan', 'Perempuan', 1973, 'Aktif', '2012-06-13', 'KLS-03'),
            ('UMT-00340', 'Raka Ndoen', 'Laki-laki', 1989, 'Aktif', '2013-06-13', 'KLS-03'),
            ('UMT-00341', 'Elisabeth Mira Tallo', 'Perempuan', 1992, 'Aktif', '2013-06-13', 'KLS-03'),
            ('UMT-00342', 'Helena Fitri Ndoen', 'Perempuan', 2012, 'Aktif', '2013-06-13', 'KLS-04'),
            ('UMT-00343', 'Sri Ndoen', 'Perempuan', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00344', 'Hieronimus Rudi Ndoen', 'Laki-laki', 1959, 'Aktif', '2013-06-13', 'KLS-03'),
            ('UMT-00345', 'Benediktus Eko Tjandra', 'Laki-laki', 1980, 'Aktif', '2010-08-04', 'KLS-03'),
            ('UMT-00346', 'Ignatia Utomo', 'Perempuan', 1981, 'Aktif', '2010-08-04', 'KLS-03'),
            ('UMT-00347', 'Elisabeth Mira Tjandra', 'Perempuan', 2010, 'Aktif', '2010-08-04', 'KLS-04'),
            ('UMT-00348', 'Robertus Tanujaya', 'Laki-laki', 1977, 'Aktif', '2021-11-13', 'KLS-03'),
            ('UMT-00349', 'Anastasia Ayu Tallo', 'Perempuan', 1973, 'Aktif', '2021-11-13', 'KLS-03'),
            ('UMT-00350', 'Yudha Tanujaya', 'Laki-laki', 2014, 'Aktif', '2021-11-13', 'KLS-04'),
            ('UMT-00351', 'Anastasia Nilam Tanujaya', 'Perempuan', 1999, 'Aktif', '2021-11-13', 'KLS-03'),
            ('UMT-00352', 'Cecilia Intan Tanujaya', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00353', 'Angela Melati Da Costa', 'Perempuan', 1973, 'Aktif', '2020-05-16', 'KLS-03'),
            ('UMT-00354', 'Matius Da Costa', 'Laki-laki', 1997, 'Tidak Aktif', '2020-05-16', 'KLS-03'),
            ('UMT-00355', 'Antonius Joko Simanjuntak', 'Laki-laki', 1983, 'Aktif', '2021-02-23', 'KLS-03'),
            ('UMT-00356', 'Regina Rina Simanjuntak', 'Perempuan', 1979, 'Aktif', '2021-02-23', 'KLS-03'),
            ('UMT-00357', 'Bernadeta Utami Simanjuntak', 'Perempuan', 2015, 'Aktif', '2021-02-23', 'KLS-04'),
            ('UMT-00358', 'Benediktus Adi Sutanto', 'Laki-laki', 1991, 'Aktif', '2020-11-09', 'KLS-03'),
            ('UMT-00359', 'Elisabeth Nilam Sutanto', 'Perempuan', 1988, 'Aktif', '2020-11-09', 'KLS-03'),
            ('UMT-00360', 'Dominikus Sutanto', 'Laki-laki', 2020, 'Aktif', '2020-11-09', 'KLS-04'),
            ('UMT-00361', 'Sri Lukman', 'Perempuan', 1949, 'Aktif', '2024-10-12', 'KLS-03'),
            ('UMT-00362', 'Kristoforus Krisna Lukman', 'Laki-laki', 1951, 'Aktif', '2024-10-12', 'KLS-03'),
            ('UMT-00363', 'Gregorius Imam Santoso', 'Laki-laki', 1984, 'Aktif', '2017-02-03', 'KLS-03'),
            ('UMT-00364', 'Regina Mira Santoso', 'Perempuan', 2006, 'Aktif', '2017-02-03', 'KLS-03'),
            ('UMT-00365', 'Antonius Putra Siregar', 'Laki-laki', 1984, 'Aktif', '2020-04-28', 'KLS-03'),
            ('UMT-00366', 'Cecilia Hesti Siregar', 'Perempuan', 1984, 'Aktif', '2020-04-28', 'KLS-03'),
            ('UMT-00367', 'Dominikus Rudi Gunadi', 'Laki-laki', 1983, 'Aktif', '2021-07-01', 'KLS-03'),
            ('UMT-00368', 'Angela Gunadi', 'Perempuan', 1985, 'Aktif', '2021-07-01', 'KLS-03'),
            ('UMT-00369', 'Lusia Hesti Gunadi', 'Perempuan', 2019, 'Aktif', '2021-07-01', 'KLS-04'),
            ('UMT-00370', 'Cecilia Fitri Gunadi', 'Perempuan', 2021, 'Aktif', '2021-07-01', 'KLS-04'),
            ('UMT-00371', 'Yohanes Susanto', 'Laki-laki', 1973, 'Aktif', '2024-10-27', 'KLS-03'),
            ('UMT-00372', 'Regina Mira Gunadi', 'Perempuan', 1969, 'Aktif', '2024-10-27', 'KLS-03'),
            ('UMT-00373', 'Markus Danu Utomo', 'Laki-laki', 1968, 'Aktif', '2024-04-27', 'KLS-03'),
            ('UMT-00374', 'Indah Utomo', 'Perempuan', 1964, 'Aktif', '2024-04-27', 'KLS-03'),
            ('UMT-00375', 'Bernadeta Sri Utomo', 'Perempuan', 1997, 'Tidak Aktif', '2024-04-27', 'KLS-03'),
            ('UMT-00376', 'Bernardus Bambang Utomo', 'Laki-laki', 2023, 'Aktif', '2024-04-27', 'KLS-04'),
            ('UMT-00377', 'Paulus Bambang Nainggolan', 'Laki-laki', 1978, 'Aktif', '2012-10-23', 'KLS-03'),
            ('UMT-00378', 'Monika Kartika Nainggolan', 'Perempuan', 1978, 'Aktif', '2012-10-23', 'KLS-03'),
            ('UMT-00379', 'Kurnia Nainggolan', 'Laki-laki', 2015, 'Aktif', '2015-06-30', 'KLS-04'),
            ('UMT-00380', 'Agnes Yuni Seran', 'Perempuan', 1947, 'Aktif', '2016-06-08', 'KLS-03'),
            ('UMT-00381', 'Ignatius Seran', 'Laki-laki', 1943, 'Aktif', '2016-06-08', 'KLS-03'),
            ('UMT-00382', 'Dominikus Lukman', 'Laki-laki', 1978, 'Aktif', '2010-04-06', 'KLS-03'),
            ('UMT-00383', 'Maria Lukman', 'Perempuan', 1974, 'Aktif', '2010-04-06', 'KLS-03'),
            ('UMT-00384', 'Regina Fitri Handoko', 'Perempuan', 1983, 'Aktif', '2022-10-06', 'KLS-03'),
            ('UMT-00385', 'Matius Situmorang', 'Laki-laki', 1965, 'Aktif', '2020-03-23', 'KLS-03'),
            ('UMT-00386', 'Paulus Rudi Saputra', 'Laki-laki', 1968, 'Aktif', '2011-10-30', 'KLS-03'),
            ('UMT-00387', 'Agnes Ratna Saputra', 'Perempuan', 1970, 'Aktif', '2011-10-30', 'KLS-03'),
            ('UMT-00388', 'Dian Saputra', 'Perempuan', 2012, 'Aktif', '2012-06-30', 'KLS-04'),
            ('UMT-00389', 'Dominikus Galih Kusuma', 'Laki-laki', 1955, 'Aktif', '2010-09-16', 'KLS-03'),
            ('UMT-00390', 'Elisabeth Dian Purnomo', 'Perempuan', 1991, 'Aktif', '2025-03-09', 'KLS-03'),
            ('UMT-00391', 'Markus Eko Manurung', 'Laki-laki', 1990, 'Aktif', '2025-03-09', 'KLS-03'),
            ('UMT-00392', 'Matius Nugroho Susanto', 'Laki-laki', 1957, 'Aktif', '2012-12-09', 'KLS-03'),
            ('UMT-00393', 'Markus Yudha Prasetyo', 'Laki-laki', 1975, 'Aktif', '2008-06-03', 'KLS-03'),
            ('UMT-00394', 'Helena Sari Prasetyo', 'Perempuan', 1977, 'Aktif', '2008-06-03', 'KLS-03'),
            ('UMT-00395', 'Albertus Putra Hutabarat', 'Laki-laki', 1982, 'Aktif', '2008-12-14', 'KLS-03'),
            ('UMT-00396', 'Clara Lestari Da Costa', 'Perempuan', 1978, 'Aktif', '2008-12-14', 'KLS-03'),
            ('UMT-00397', 'Paulus Putra Hutabarat', 'Laki-laki', 2006, 'Aktif', '2008-12-14', 'KLS-03'),
            ('UMT-00398', 'Yosef Galih Rahardjo', 'Laki-laki', 1971, 'Aktif', '2008-06-21', 'KLS-03'),
            ('UMT-00399', 'Anastasia Citra Koten', 'Perempuan', 1969, 'Aktif', '2008-06-21', 'KLS-03'),
            ('UMT-00400', 'Dominikus Agus Tjandra', 'Laki-laki', 1989, 'Aktif', '2018-11-10', 'KLS-03'),
            ('UMT-00401', 'Yohana Tuti Tjandra', 'Perempuan', 1991, 'Aktif', '2018-11-10', 'KLS-03'),
            ('UMT-00402', 'Yosef Dwi Tjandra', 'Laki-laki', 2014, 'Aktif', '2018-11-10', 'KLS-04'),
            ('UMT-00403', 'Emanuel Teguh Bria', 'Laki-laki', 1978, 'Aktif', '2021-01-06', 'KLS-03'),
            ('UMT-00404', 'Fransiska Sari Bria', 'Perempuan', 1974, 'Aktif', '2021-01-06', 'KLS-03'),
            ('UMT-00405', 'Hendra Bria', 'Laki-laki', 2016, 'Aktif', '2021-01-06', 'KLS-04'),
            ('UMT-00406', 'Angela Melati Bria', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00407', 'Gregorius Hadi Bria', 'Laki-laki', 2007, 'Aktif', '2021-01-06', 'KLS-03'),
            ('UMT-00408', 'Dominikus Krisna Wibowo', 'Laki-laki', 1978, 'Aktif', '2023-04-30', 'KLS-03'),
            ('UMT-00409', 'Angela Citra Wibowo', 'Perempuan', 1979, 'Aktif', '2023-04-30', 'KLS-03'),
            ('UMT-00410', 'Sari Wibowo', 'Perempuan', 2015, 'Aktif', '2023-04-30', 'KLS-04'),
            ('UMT-00411', 'Hesti Handoko', 'Perempuan', 1973, 'Aktif', '2014-10-03', 'KLS-03'),
            ('UMT-00412', 'Kurnia Purnomo', 'Laki-laki', 1976, 'Aktif', '2014-10-03', 'KLS-03'),
            ('UMT-00413', 'Budi Handoko', 'Laki-laki', 2012, 'Aktif', '2014-10-03', 'KLS-04'),
            ('UMT-00414', 'Aloysius Sihombing', 'Laki-laki', 1969, 'Aktif', '2014-01-26', 'KLS-03'),
            ('UMT-00415', 'Elisabeth Nilam Sihombing', 'Perempuan', 1970, 'Aktif', '2014-01-26', 'KLS-03'),
            ('UMT-00416', 'Cahyo Sihombing', 'Laki-laki', 1998, 'Aktif', '2014-01-26', 'KLS-03'),
            ('UMT-00417', 'Paulus Wahyu Sihombing', 'Laki-laki', 1998, 'Aktif', '2014-01-26', 'KLS-03'),
            ('UMT-00418', 'Fransiska Wulan Lalamentik', 'Perempuan', 1972, 'Aktif', '2017-06-21', 'KLS-03'),
            ('UMT-00419', 'Veronika Ening Lalamentik', 'Perempuan', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00420', 'Maria Indah Lalamentik', 'Perempuan', 2016, 'Aktif', '2017-06-21', 'KLS-04'),
            ('UMT-00421', 'Robertus Cahyo Lukman', 'Laki-laki', 1974, 'Aktif', '2008-05-01', 'KLS-03'),
            ('UMT-00422', 'Anastasia Ayu Lukman', 'Perempuan', 1976, 'Aktif', '2008-05-01', 'KLS-03'),
            ('UMT-00423', 'Hendra Lukman', 'Laki-laki', 2004, 'Aktif', '2008-05-01', 'KLS-03'),
            ('UMT-00424', 'Matius Cahyo Lukman', 'Laki-laki', 2008, 'Aktif', '2008-06-30', 'KLS-03'),
            ('UMT-00425', 'Danu Lukman', 'Laki-laki', 2008, 'Aktif', '2008-06-30', 'KLS-03'),
            ('UMT-00426', 'Rudi Handoko', 'Laki-laki', 1971, 'Aktif', '2024-02-07', 'KLS-03'),
            ('UMT-00427', 'Elisabeth Rahayu Handoko', 'Perempuan', 1967, 'Aktif', '2024-02-07', 'KLS-03'),
            ('UMT-00428', 'Clara Fitri Wibowo', 'Perempuan', 1989, 'Aktif', '2016-02-17', 'KLS-03'),
            ('UMT-00429', 'Galih Wibowo', 'Laki-laki', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00430', 'Dominikus Joko Kurniawan', 'Laki-laki', 1987, 'Aktif', '2015-12-06', 'KLS-03'),
            ('UMT-00431', 'Matius Putra Kurniawan', 'Laki-laki', 2013, 'Aktif', '2015-12-06', 'KLS-04'),
            ('UMT-00432', 'Dian Koten', 'Perempuan', 1973, 'Aktif', '2013-07-20', 'KLS-03'),
            ('UMT-00433', 'Hendra Koten', 'Laki-laki', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00434', 'Petrus Rudi Simanjuntak', 'Laki-laki', 1992, 'Aktif', '2008-11-20', 'KLS-03'),
            ('UMT-00435', 'Yustina Citra Situmorang', 'Perempuan', 1993, 'Aktif', '2008-11-20', 'KLS-03'),
            ('UMT-00436', 'Ignatius Ferry Wijaya', 'Laki-laki', 1990, 'Aktif', '2025-04-21', 'KLS-03'),
            ('UMT-00437', 'Dominika Rahayu Ndoen', 'Perempuan', 1989, 'Aktif', '2025-04-21', 'KLS-03'),
            ('UMT-00438', 'Andreas Wijaya', 'Laki-laki', 2017, 'Aktif', '2025-04-21', 'KLS-04'),
            ('UMT-00439', 'Rosalia Wijaya', 'Perempuan', 2015, 'Aktif', '2025-04-21', 'KLS-04'),
            ('UMT-00440', 'Clara Wijaya', 'Perempuan', 2013, 'Aktif', '2025-04-21', 'KLS-04'),
            ('UMT-00441', 'Bernardus Krisna Tanujaya', 'Laki-laki', 1968, 'Aktif', '2016-09-17', 'KLS-03'),
            ('UMT-00442', 'Margareta Tanujaya', 'Perempuan', 1969, 'Aktif', '2016-09-17', 'KLS-03'),
            ('UMT-00443', 'Emanuel Eko Purnomo', 'Laki-laki', 1986, 'Aktif', '2012-02-27', 'KLS-03'),
            ('UMT-00444', 'Clara Melati Purnomo', 'Perempuan', 1985, 'Aktif', '2012-02-27', 'KLS-03'),
            ('UMT-00445', 'Lukas Purnomo', 'Laki-laki', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00446', 'Aryo Purnomo', 'Laki-laki', 2011, 'Aktif', '2012-02-27', 'KLS-04'),
            ('UMT-00447', 'Indra Siregar', 'Laki-laki', 1973, 'Aktif', '2020-03-12', 'KLS-03'),
            ('UMT-00448', 'Yohana Siregar', 'Perempuan', 1970, 'Aktif', '2020-03-12', 'KLS-03'),
            ('UMT-00449', 'Helena Dian Siregar', 'Perempuan', 1996, 'Aktif', '2020-03-12', 'KLS-03'),
            ('UMT-00450', 'Ignatia Ayu Siregar', 'Perempuan', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00451', 'Endang Siregar', 'Perempuan', 2003, 'Aktif', '2020-03-12', 'KLS-03'),
            ('UMT-00452', 'Lukas Santoso', 'Laki-laki', 1972, 'Aktif', '2021-05-13', 'KLS-03'),
            ('UMT-00453', 'Margareta Citra Santoso', 'Perempuan', 1972, 'Aktif', '2021-05-13', 'KLS-03'),
            ('UMT-00454', 'Helena Tuti Santoso', 'Perempuan', 2003, 'Aktif', '2021-05-13', 'KLS-03'),
            ('UMT-00455', 'Imam Santoso', 'Laki-laki', 1973, 'Aktif', '2020-06-21', 'KLS-03'),
            ('UMT-00456', 'Anastasia Rahayu Santoso', 'Perempuan', 1970, 'Aktif', '2020-06-21', 'KLS-03'),
            ('UMT-00457', 'Teguh Santoso', 'Laki-laki', 2010, 'Aktif', '2020-06-21', 'KLS-04'),
            ('UMT-00458', 'Rahayu Situmorang', 'Perempuan', 1974, 'Aktif', '2022-11-02', 'KLS-03'),
            ('UMT-00459', 'Robertus Galih Situmorang', 'Laki-laki', 2017, 'Aktif', '2022-11-02', 'KLS-04'),
            ('UMT-00460', 'Gregorius Hadi Situmorang', 'Laki-laki', 2013, 'Aktif', '2022-11-02', 'KLS-04'),
            ('UMT-00461', 'Robertus Wahyu Tjandra', 'Laki-laki', 1986, 'Aktif', '2014-11-26', 'KLS-03'),
            ('UMT-00462', 'Fransiska Indah Tjandra', 'Perempuan', 1987, 'Aktif', '2014-11-26', 'KLS-03'),
            ('UMT-00463', 'Bernadeta Tjandra', 'Perempuan', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00464', 'Dominikus Eko Tjandra', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00465', 'Angela Endang Tjandra', 'Perempuan', 2012, 'Aktif', '2014-11-26', 'KLS-04'),
            ('UMT-00466', 'Ignatius Teguh Kusuma', 'Laki-laki', 1968, 'Aktif', '2011-01-13', 'KLS-03'),
            ('UMT-00467', 'Indah Kusuma', 'Perempuan', 1966, 'Aktif', '2011-01-13', 'KLS-03'),
            ('UMT-00468', 'Ignatia Intan Kusuma', 'Perempuan', 2003, 'Aktif', '2011-01-13', 'KLS-03'),
            ('UMT-00469', 'Matius Teguh Kusuma', 'Laki-laki', 2000, 'Pindah Paroki', '2011-01-13', 'KLS-03'),
            ('UMT-00470', 'Vincentius Hadi Prasetyo', 'Laki-laki', 1975, 'Aktif', '2023-09-10', 'KLS-03'),
            ('UMT-00471', 'Cecilia Prasetyo', 'Perempuan', 1976, 'Aktif', '2023-09-10', 'KLS-03'),
            ('UMT-00472', 'Eko Tjandra', 'Laki-laki', 1972, 'Aktif', '2010-06-10', 'KLS-03'),
            ('UMT-00473', 'Margareta Rahayu Rumbayan', 'Perempuan', 1972, 'Aktif', '2010-06-10', 'KLS-03'),
            ('UMT-00474', 'Benedikta Dian Tjandra', 'Perempuan', 1999, 'Aktif', '2010-06-10', 'KLS-03'),
            ('UMT-00475', 'Antonius Tjandra', 'Laki-laki', 2010, 'Aktif', '2010-06-30', 'KLS-04'),
            ('UMT-00476', 'Rahayu Tjandra', 'Perempuan', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00477', 'Bernardus Nugraha', 'Laki-laki', 1965, 'Aktif', '2021-07-01', 'KLS-03'),
            ('UMT-00478', 'Dedi Nugraha', 'Laki-laki', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00479', 'Adi Saputra', 'Laki-laki', 1970, 'Aktif', '2018-04-07', 'KLS-03'),
            ('UMT-00480', 'Cecilia Koten', 'Perempuan', 1970, 'Aktif', '2018-04-07', 'KLS-03'),
            ('UMT-00481', 'Katarina Saputra', 'Perempuan', 1996, 'Aktif', '2018-04-07', 'KLS-03'),
            ('UMT-00482', 'Cahyo Saputra', 'Laki-laki', 2000, 'Aktif', '2018-04-07', 'KLS-03'),
            ('UMT-00483', 'Robertus Dwi Lalamentik', 'Laki-laki', 1983, 'Pindah Paroki', '2024-06-17', 'KLS-03'),
            ('UMT-00484', 'Hendra Hutabarat', 'Laki-laki', 1979, 'Aktif', '2025-06-20', 'KLS-03'),
            ('UMT-00485', 'Cecilia Hutabarat', 'Perempuan', 1978, 'Aktif', '2025-06-20', 'KLS-03'),
            ('UMT-00486', 'Yosef Hutabarat', 'Laki-laki', 2015, 'Aktif', '2025-06-20', 'KLS-04'),
            ('UMT-00487', 'Joko Hutabarat', 'Laki-laki', 2022, 'Aktif', '2025-06-20', 'KLS-04'),
            ('UMT-00488', 'Antonius Budiman', 'Laki-laki', 1989, 'Aktif', '2018-08-19', 'KLS-03'),
            ('UMT-00489', 'Fitri Budiman', 'Perempuan', 1987, 'Aktif', '2018-08-19', 'KLS-03'),
            ('UMT-00490', 'Surya Budiman', 'Laki-laki', 2012, 'Aktif', '2018-08-19', 'KLS-04'),
            ('UMT-00491', 'Emanuel Cahyo Budiman', 'Laki-laki', 2018, 'Aktif', '2018-08-19', 'KLS-04'),
            ('UMT-00492', 'Sri Lewar', 'Perempuan', 1971, 'Aktif', '2017-09-20', 'KLS-03'),
            ('UMT-00493', 'Thomas Imam Lewar', 'Laki-laki', 1970, 'Aktif', '2017-09-20', 'KLS-03'),
            ('UMT-00494', 'Gregorius Adi Rumbayan', 'Laki-laki', 1969, 'Aktif', '2011-08-20', 'KLS-03'),
            ('UMT-00495', 'Stefanus Budi Santoso', 'Laki-laki', 1972, 'Aktif', '2023-02-18', 'KLS-03'),
            ('UMT-00496', 'Regina Gita Lalamentik', 'Perempuan', 1975, 'Aktif', '2023-02-18', 'KLS-03'),
            ('UMT-00497', 'Putra Santoso', 'Laki-laki', 2009, 'Aktif', '2023-02-18', 'KLS-03'),
            ('UMT-00498', 'Clara Kartika Santoso', 'Perempuan', 2009, 'Aktif', '2023-02-18', 'KLS-03'),
            ('UMT-00499', 'Fransiskus Bayu Santoso', 'Laki-laki', 2019, 'Aktif', '2023-02-18', 'KLS-04'),
            ('UMT-00500', 'Antonius Adi Hutabarat', 'Laki-laki', 1986, 'Aktif', '2020-10-29', 'KLS-03'),
            ('UMT-00501', 'Thomas Indra Handoko', 'Laki-laki', 1986, 'Aktif', '2015-12-03', 'KLS-03'),
            ('UMT-00502', 'Sari Handoko', 'Perempuan', 1988, 'Aktif', '2015-12-03', 'KLS-03'),
            ('UMT-00503', 'Antonius Lukman', 'Laki-laki', 1968, 'Aktif', '2021-05-29', 'KLS-03'),
            ('UMT-00504', 'Rosalia Tuti Lukman', 'Perempuan', 1969, 'Aktif', '2021-05-29', 'KLS-03'),
            ('UMT-00505', 'Joko Lukman', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00506', 'Yohanes Bayu Lukman', 'Laki-laki', 2006, 'Aktif', '2021-05-29', 'KLS-03'),
            ('UMT-00507', 'Fransiskus Lukman', 'Laki-laki', 2014, 'Aktif', '2021-05-29', 'KLS-04'),
            ('UMT-00508', 'Robertus Cahyo Prasetyo', 'Laki-laki', 1988, 'Aktif', '2008-03-12', 'KLS-03'),
            ('UMT-00509', 'Veronika Nilam Rumbayan', 'Perempuan', 1989, 'Aktif', '2008-03-12', 'KLS-03'),
            ('UMT-00510', 'Endang Prasetyo', 'Perempuan', 2012, 'Aktif', '2012-06-30', 'KLS-04'),
            ('UMT-00511', 'Dian Prasetyo', 'Perempuan', 1962, 'Aktif', '2008-03-12', 'KLS-03'),
            ('UMT-00512', 'Andreas Danu Nugraha', 'Laki-laki', 1991, 'Aktif', '2009-11-09', 'KLS-03'),
            ('UMT-00513', 'Ignatia Tjandra', 'Perempuan', 1994, 'Aktif', '2009-11-09', 'KLS-03'),
            ('UMT-00514', 'Gregorius Eko Koten', 'Laki-laki', 1986, 'Aktif', '2021-10-24', 'KLS-03'),
            ('UMT-00515', 'Kartika Koten', 'Perempuan', 1982, 'Aktif', '2021-10-24', 'KLS-03'),
            ('UMT-00516', 'Maria Wulan Koten', 'Perempuan', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00517', 'Kristoforus Putra Siregar', 'Laki-laki', 1997, 'Aktif', '2009-07-03', 'KLS-03'),
            ('UMT-00518', 'Yohanes Pratama', 'Laki-laki', 1984, 'Aktif', '2009-08-12', 'KLS-03'),
            ('UMT-00519', 'Natalia Ayu Pratama', 'Perempuan', 1987, 'Aktif', '2009-08-12', 'KLS-03'),
            ('UMT-00520', 'Hesti Pratama', 'Perempuan', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00521', 'Aloysius Aryo Pratama', 'Laki-laki', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00522', 'Putri Pratama', 'Perempuan', 2010, 'Aktif', '2010-06-30', 'KLS-04'),
            ('UMT-00523', 'Aryo Rumbayan', 'Laki-laki', 1986, 'Aktif', '2010-02-01', 'KLS-03'),
            ('UMT-00524', 'Rosalia Fitri Rumbayan', 'Perempuan', 1988, 'Aktif', '2010-02-01', 'KLS-03'),
            ('UMT-00525', 'Elisabeth Rumbayan', 'Perempuan', 2016, 'Aktif', '2016-06-30', 'KLS-04'),
            ('UMT-00526', 'Yustina Dian Rumbayan', 'Perempuan', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00527', 'Theresia Hesti Rumbayan', 'Perempuan', 2009, 'Aktif', '2010-02-01', 'KLS-03'),
            ('UMT-00528', 'Danu Sihombing', 'Laki-laki', 1959, 'Aktif', '2018-03-15', 'KLS-03'),
            ('UMT-00529', 'Regina Sihombing', 'Perempuan', 1957, 'Aktif', '2018-03-15', 'KLS-03'),
            ('UMT-00530', 'Markus Teguh Kleden', 'Laki-laki', 1976, 'Pindah Paroki', '2021-02-06', 'KLS-03'),
            ('UMT-00531', 'Rosalia Tuti Kleden', 'Perempuan', 1978, 'Pindah Paroki', '2021-02-06', 'KLS-03'),
            ('UMT-00532', 'Paulus Krisna Kleden', 'Laki-laki', 2015, 'Pindah Paroki', '2021-02-06', 'KLS-04'),
            ('UMT-00533', 'Yosef Nugroho Kleden', 'Laki-laki', 2009, 'Pindah Paroki', '2021-02-06', 'KLS-03'),
            ('UMT-00534', 'Bambang Kleden', 'Laki-laki', 2008, 'Pindah Paroki', '2021-02-06', 'KLS-03'),
            ('UMT-00535', 'Albertus Lukito Hutabarat', 'Laki-laki', 1979, 'Aktif', '2013-06-15', 'KLS-03'),
            ('UMT-00536', 'Agnes Nilam Kusuma', 'Perempuan', 1980, 'Aktif', '2013-06-15', 'KLS-03'),
            ('UMT-00537', 'Putri Mamengko', 'Perempuan', 1975, 'Aktif', '2019-02-19', 'KLS-03'),
            ('UMT-00538', 'Fransiskus Agus Mamengko', 'Laki-laki', 1975, 'Aktif', '2019-02-19', 'KLS-03'),
            ('UMT-00539', 'Hieronimus Yudha Mamengko', 'Laki-laki', 2018, 'Aktif', '2019-02-19', 'KLS-04'),
            ('UMT-00540', 'Lukas Dwi Mamengko', 'Laki-laki', 2000, 'Tidak Aktif', '2019-02-19', 'KLS-03'),
            ('UMT-00541', 'Ratna Kaunang', 'Perempuan', 1960, 'Aktif', '2008-02-11', 'KLS-03'),
            ('UMT-00542', 'Ratna Purnomo', 'Perempuan', 1957, 'Aktif', '2011-01-08', 'KLS-03'),
            ('UMT-00543', 'Lukas Lukito Purnomo', 'Laki-laki', 1956, 'Aktif', '2011-01-08', 'KLS-03'),
            ('UMT-00544', 'Petrus Aryo Tjandra', 'Laki-laki', 1982, 'Aktif', '2012-06-28', 'KLS-03'),
            ('UMT-00545', 'Theresia Tuti Handoko', 'Perempuan', 1985, 'Aktif', '2012-06-28', 'KLS-03'),
            ('UMT-00546', 'Elisabeth Hesti Tjandra', 'Perempuan', 2006, 'Aktif', '2012-06-28', 'KLS-03'),
            ('UMT-00547', 'Fransiskus Rudi Tanujaya', 'Laki-laki', 1976, 'Aktif', '2021-03-20', 'KLS-03'),
            ('UMT-00548', 'Fransiska Tanujaya', 'Perempuan', 1973, 'Aktif', '2021-03-20', 'KLS-03'),
            ('UMT-00549', 'Aloysius Kaunang', 'Laki-laki', 1974, 'Aktif', '2023-03-10', 'KLS-03'),
            ('UMT-00550', 'Lusia Melati Kaunang', 'Perempuan', 1970, 'Aktif', '2023-03-10', 'KLS-03'),
            ('UMT-00551', 'Gita Kaunang', 'Perempuan', 2003, 'Aktif', '2023-03-10', 'KLS-03'),
            ('UMT-00552', 'Ignatius Hendra Kaunang', 'Laki-laki', 2021, 'Aktif', '2023-03-10', 'KLS-04'),
            ('UMT-00553', 'Dominika Sri Sihombing', 'Perempuan', 1969, 'Aktif', '2011-05-02', 'KLS-03'),
            ('UMT-00554', 'Stefanus Ferry Sihombing', 'Laki-laki', 2014, 'Aktif', '2014-06-30', 'KLS-04'),
            ('UMT-00555', 'Bernardus Danu Hutabarat', 'Laki-laki', 1984, 'Aktif', '2024-10-06', 'KLS-03'),
            ('UMT-00556', 'Angela Fitri Hutabarat', 'Perempuan', 1986, 'Aktif', '2024-10-06', 'KLS-03'),
            ('UMT-00557', 'Ignatius Putra Susanto', 'Laki-laki', 1984, 'Aktif', '2018-09-02', 'KLS-03'),
            ('UMT-00558', 'Cecilia Handoko', 'Perempuan', 1980, 'Aktif', '2018-09-02', 'KLS-03'),
            ('UMT-00559', 'Dominika Wulan Budiman', 'Perempuan', 1983, 'Pindah Paroki', '2023-06-09', 'KLS-03'),
            ('UMT-00560', 'Hesti Budiman', 'Perempuan', 2012, 'Pindah Paroki', '2023-06-09', 'KLS-04'),
            ('UMT-00561', 'Citra Budiman', 'Perempuan', 2022, 'Pindah Paroki', '2023-06-09', 'KLS-04'),
            ('UMT-00562', 'Andreas Surya Hartono', 'Laki-laki', 1979, 'Aktif', '2018-03-10', 'KLS-03'),
            ('UMT-00563', 'Dominika Sari Hartono', 'Perempuan', 1976, 'Aktif', '2018-03-10', 'KLS-03'),
            ('UMT-00564', 'Ayu Hartono', 'Perempuan', 2015, 'Aktif', '2018-03-10', 'KLS-04'),
            ('UMT-00565', 'Yosef Adi Da Costa', 'Laki-laki', 1969, 'Aktif', '2008-11-05', 'KLS-03'),
            ('UMT-00566', 'Cecilia Endang Da Costa', 'Perempuan', 1971, 'Aktif', '2008-11-05', 'KLS-03'),
            ('UMT-00567', 'Thomas Agus Utomo', 'Laki-laki', 1971, 'Aktif', '2010-08-20', 'KLS-03'),
            ('UMT-00568', 'Maria Fitri Utomo', 'Perempuan', 1969, 'Aktif', '2010-08-20', 'KLS-03'),
            ('UMT-00569', 'Robertus Rudi Kurniawan', 'Laki-laki', 1987, 'Pindah Paroki', '2024-07-03', 'KLS-03'),
            ('UMT-00570', 'Sri Kurniawan', 'Perempuan', 1983, 'Pindah Paroki', '2024-07-03', 'KLS-03'),
            ('UMT-00571', 'Agus Kurniawan', 'Laki-laki', 2016, 'Pindah Paroki', '2024-07-03', 'KLS-04'),
            ('UMT-00572', 'Theresia Nilam Kurniawan', 'Perempuan', 2014, 'Pindah Paroki', '2024-07-03', 'KLS-04'),
            ('UMT-00573', 'Budi Rahardjo', 'Laki-laki', 1947, 'Aktif', '2024-01-05', 'KLS-03'),
            ('UMT-00574', 'Rosalia Lestari Rahardjo', 'Perempuan', 1945, 'Meninggal Dunia', '2024-01-05', 'KLS-03'),
            ('UMT-00575', 'Yosef Rahardjo', 'Laki-laki', 1968, 'Aktif', '2010-02-04', 'KLS-03'),
            ('UMT-00576', 'Cecilia Rina Rahardjo', 'Perempuan', 1966, 'Aktif', '2010-02-04', 'KLS-03'),
            ('UMT-00577', 'Markus Nugroho Kurniawan', 'Laki-laki', 1989, 'Aktif', '2011-01-07', 'KLS-03'),
            ('UMT-00578', 'Lestari Kurniawan', 'Perempuan', 1985, 'Aktif', '2011-01-07', 'KLS-03'),
            ('UMT-00579', 'Bernadeta Tuti Kurniawan', 'Perempuan', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00580', 'Cecilia Ratna Kurniawan', 'Perempuan', 2012, 'Aktif', '2012-06-30', 'KLS-04'),
            ('UMT-00581', 'Lukito Sihombing', 'Laki-laki', 1968, 'Aktif', '2018-10-01', 'KLS-03'),
            ('UMT-00582', 'Melati Sihombing', 'Perempuan', 1966, 'Aktif', '2018-10-01', 'KLS-03'),
            ('UMT-00583', 'Yuni Sihombing', 'Perempuan', 2016, 'Aktif', '2018-10-01', 'KLS-04'),
            ('UMT-00584', 'Vincentius Cahyo Sihombing', 'Laki-laki', 2010, 'Aktif', '2018-10-01', 'KLS-04'),
            ('UMT-00585', 'Bambang Utomo', 'Laki-laki', 1972, 'Aktif', '2022-09-12', 'KLS-03'),
            ('UMT-00586', 'Agnes Setiawan', 'Perempuan', 1973, 'Aktif', '2022-09-12', 'KLS-03'),
            ('UMT-00587', 'Kristoforus Rudi Lewar', 'Laki-laki', 1964, 'Aktif', '2020-10-30', 'KLS-03'),
            ('UMT-00588', 'Dominikus Prasetyo', 'Laki-laki', 1991, 'Aktif', '2010-06-30', 'KLS-03'),
            ('UMT-00589', 'Dominika Wulan Rumbayan', 'Perempuan', 1988, 'Aktif', '2010-06-30', 'KLS-03'),
            ('UMT-00590', 'Katarina Indah Prasetyo', 'Perempuan', 2022, 'Aktif', '2022-06-30', 'KLS-04'),
            ('UMT-00591', 'Gregorius Hendra Prasetyo', 'Laki-laki', 2020, 'Aktif', '2020-06-30', 'KLS-04'),
            ('UMT-00592', 'Hieronimus Lukito Prasetyo', 'Laki-laki', 1964, 'Aktif', '2010-06-30', 'KLS-03'),
            ('UMT-00593', 'Hieronimus Danu Hartono', 'Laki-laki', 1971, 'Aktif', '2015-05-02', 'KLS-03'),
            ('UMT-00594', 'Margareta Intan Handoko', 'Perempuan', 1970, 'Aktif', '2015-05-02', 'KLS-03'),
            ('UMT-00595', 'Petrus Kurnia Hartono', 'Laki-laki', 2008, 'Aktif', '2015-05-02', 'KLS-03'),
            ('UMT-00596', 'Rizki Saputra', 'Laki-laki', 1950, 'Aktif', '2024-07-13', 'KLS-03'),
            ('UMT-00597', 'Katarina Intan Tanujaya', 'Perempuan', 1953, 'Aktif', '2024-07-13', 'KLS-03'),
            ('UMT-00598', 'Stefanus Bayu Hermawan', 'Laki-laki', 1966, 'Aktif', '2020-08-08', 'KLS-03'),
            ('UMT-00599', 'Albertus Teguh Lalamentik', 'Laki-laki', 1992, 'Aktif', '2017-03-09', 'KLS-03'),
            ('UMT-00600', 'Veronika Dewi Lalamentik', 'Perempuan', 1988, 'Aktif', '2017-03-09', 'KLS-03'),
            ('UMT-00601', 'Margareta Ening Lalamentik', 'Perempuan', 2025, 'Aktif', '2025-06-30', 'KLS-04'),
            ('UMT-00602', 'Ignatius Krisna Lalamentik', 'Laki-laki', 2015, 'Aktif', '2017-03-09', 'KLS-04'),
            ('UMT-00603', 'Bernardus Agus Bria', 'Laki-laki', 1974, 'Aktif', '2010-01-27', 'KLS-03'),
            ('UMT-00604', 'Cecilia Nilam Bria', 'Perempuan', 1975, 'Aktif', '2010-01-27', 'KLS-03'),
            ('UMT-00605', 'Yosef Budi Wijaya', 'Laki-laki', 1942, 'Aktif', '2018-03-24', 'KLS-03'),
            ('UMT-00606', 'Rahayu Wijaya', 'Perempuan', 1943, 'Aktif', '2018-03-24', 'KLS-03'),
            ('UMT-00607', 'Yuni Pratama', 'Perempuan', 1987, 'Aktif', '2009-03-13', 'KLS-03'),
            ('UMT-00608', 'Lukas Gunadi', 'Laki-laki', 1984, 'Aktif', '2016-01-14', 'KLS-03'),
            ('UMT-00609', 'Fransiska Indah Gunadi', 'Perempuan', 1980, 'Aktif', '2016-01-14', 'KLS-03'),
            ('UMT-00610', 'Ferry Gunadi', 'Laki-laki', 2017, 'Aktif', '2017-06-30', 'KLS-04'),
            ('UMT-00611', 'Paulus Galih Santoso', 'Laki-laki', 1978, 'Aktif', '2013-12-01', 'KLS-03'),
            ('UMT-00612', 'Kartika Mamengko', 'Perempuan', 1980, 'Aktif', '2013-12-01', 'KLS-03'),
            ('UMT-00613', 'Elisabeth Santoso', 'Perempuan', 2024, 'Aktif', '2024-06-30', 'KLS-04'),
            ('UMT-00614', 'Stefanus Joko Santoso', 'Laki-laki', 2011, 'Aktif', '2013-12-01', 'KLS-04'),
            ('UMT-00615', 'Ignatia Wulan Rahardjo', 'Perempuan', 1974, 'Aktif', '2011-10-23', 'KLS-03'),
            ('UMT-00616', 'Markus Bambang Rahardjo', 'Laki-laki', 1970, 'Aktif', '2011-10-23', 'KLS-03'),
            ('UMT-00617', 'Nugroho Utomo', 'Laki-laki', 1943, 'Meninggal Dunia', '2023-05-04', 'KLS-03'),
            ('UMT-00618', 'Bernadeta Ening Handoko', 'Perempuan', 1939, 'Aktif', '2023-05-04', 'KLS-03'),
            ('UMT-00619', 'Aloysius Putra Lalamentik', 'Laki-laki', 1974, 'Aktif', '2023-06-26', 'KLS-03'),
            ('UMT-00620', 'Clara Gita Seran', 'Perempuan', 1975, 'Aktif', '2023-06-26', 'KLS-03'),
            ('UMT-00621', 'Ignatia Nilam Lalamentik', 'Perempuan', 2002, 'Aktif', '2023-06-26', 'KLS-03'),
            ('UMT-00622', 'Tuti Lalamentik', 'Perempuan', 2009, 'Aktif', '2023-06-26', 'KLS-03'),
            ('UMT-00623', 'Budi Lalamentik', 'Laki-laki', 1944, 'Aktif', '2023-06-26', 'KLS-03'),
            ('UMT-00624', 'Markus Danu Sihombing', 'Laki-laki', 1942, 'Aktif', '2019-07-21', 'KLS-03'),
            ('UMT-00625', 'Veronika Wulan Sihombing', 'Perempuan', 1938, 'Meninggal Dunia', '2019-07-21', 'KLS-03'),
            ('UMT-00626', 'Antonius Kurnia Sutanto', 'Laki-laki', 1974, 'Aktif', '2013-10-04', 'KLS-03'),
            ('UMT-00627', 'Galih Gunadi', 'Laki-laki', 1988, 'Aktif', '2014-11-23', 'KLS-03'),
            ('UMT-00628', 'Margareta Dewi Sihombing', 'Perempuan', 1990, 'Aktif', '2014-11-23', 'KLS-03'),
            ('UMT-00629', 'Agus Tampubolon', 'Laki-laki', 1992, 'Aktif', '2009-01-17', 'KLS-03'),
            ('UMT-00630', 'Yuni Tampubolon', 'Perempuan', 1991, 'Aktif', '2009-01-17', 'KLS-03'),
            ('UMT-00631', 'Vincentius Teguh Tampubolon', 'Laki-laki', 2023, 'Aktif', '2023-06-30', 'KLS-04'),
            ('UMT-00632', 'Raka Tampubolon', 'Laki-laki', 2017, 'Aktif', '2017-06-30', 'KLS-04'),
            ('UMT-00633', 'Ignatius Tanujaya', 'Laki-laki', 1992, 'Aktif', '2015-07-13', 'KLS-03'),
            ('UMT-00634', 'Yustina Wulan Tanujaya', 'Perempuan', 1992, 'Aktif', '2015-07-13', 'KLS-03'),
            ('UMT-00635', 'Benediktus Surya Tanujaya', 'Laki-laki', 2018, 'Aktif', '2018-06-30', 'KLS-04'),
            ('UMT-00636', 'Paulus Cahyo Kurniawan', 'Laki-laki', 1970, 'Aktif', '2024-01-29', 'KLS-03'),
            ('UMT-00637', 'Bernardus Lukito Kurniawan', 'Laki-laki', 2014, 'Aktif', '2024-01-29', 'KLS-04'),
            ('UMT-00638', 'Ignatius Nugroho Kurniawan', 'Laki-laki', 2022, 'Aktif', '2024-01-29', 'KLS-04'),
            ('UMT-00639', 'Aryo Gunawan', 'Laki-laki', 1991, 'Aktif', '2008-10-08', 'KLS-03'),
            ('UMT-00640', 'Lusia Wulan Gunawan', 'Perempuan', 1989, 'Aktif', '2008-10-08', 'KLS-03'),
            ('UMT-00641', 'Ening Gunawan', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00642', 'Sari Gunawan', 'Perempuan', 2013, 'Aktif', '2013-06-30', 'KLS-04'),
            ('UMT-00643', 'Natalia Gunawan', 'Perempuan', 2020, 'Aktif', '2020-06-30', 'KLS-04'),
            ('UMT-00644', 'Albertus Danu Nugraha', 'Laki-laki', 1955, 'Aktif', '2016-12-25', 'KLS-03'),
            ('UMT-00645', 'Ignatia Indah Nugraha', 'Perempuan', 1955, 'Aktif', '2016-12-25', 'KLS-03'),
            ('UMT-00646', 'Dominikus Teguh Santoso', 'Laki-laki', 1991, 'Aktif', '2017-10-22', 'KLS-03'),
            ('UMT-00647', 'Yustina Santoso', 'Perempuan', 1988, 'Aktif', '2017-10-22', 'KLS-03'),
            ('UMT-00648', 'Bernadeta Dewi Santoso', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00649', 'Veronika Wulan Santoso', 'Perempuan', 2021, 'Aktif', '2021-06-30', 'KLS-04'),
            ('UMT-00650', 'Lukas Eko Lobo', 'Laki-laki', 1943, 'Aktif', '2024-12-28', 'KLS-03'),
            ('UMT-00651', 'Natalia Endang Lobo', 'Perempuan', 1939, 'Aktif', '2024-12-28', 'KLS-03'),
            ('UMT-00652', 'Fransiskus Lewar', 'Laki-laki', 1945, 'Aktif', '2023-10-02', 'KLS-03'),
            ('UMT-00653', 'Lusia Lobo', 'Perempuan', 1941, 'Aktif', '2023-10-02', 'KLS-03')
    ) AS v (ID_UMAT, NAMA_FIKTIF, JENIS_KELAMIN, TAHUN_LAHIR, STATUS_KEANGGOTAAN, TANGGAL_TERDAFTAR, ID_KLASIFIKASI_DATA)
) AS s
ON t.ID_UMAT = s.ID_UMAT
WHEN MATCHED THEN UPDATE SET
    NAMA_FIKTIF = s.NAMA_FIKTIF,
    JENIS_KELAMIN = s.JENIS_KELAMIN,
    TAHUN_LAHIR = s.TAHUN_LAHIR,
    STATUS_KEANGGOTAAN = s.STATUS_KEANGGOTAAN,
    TANGGAL_TERDAFTAR = s.TANGGAL_TERDAFTAR,
    ID_KLASIFIKASI_DATA = s.ID_KLASIFIKASI_DATA
WHEN NOT MATCHED THEN INSERT (ID_UMAT, NAMA_FIKTIF, JENIS_KELAMIN, TAHUN_LAHIR, STATUS_KEANGGOTAAN, TANGGAL_TERDAFTAR, ID_KLASIFIKASI_DATA)
    VALUES (s.ID_UMAT, s.NAMA_FIKTIF, s.JENIS_KELAMIN, s.TAHUN_LAHIR, s.STATUS_KEANGGOTAAN, s.TANGGAL_TERDAFTAR, s.ID_KLASIFIKASI_DATA);

-- DATA_OPERASIONAL.PENUGASAN_KELUARGA: 659 rows
MERGE INTO DATA_OPERASIONAL.PENUGASAN_KELUARGA AS t
USING (
    SELECT
        v.ID_PENUGASAN_KELUARGA AS ID_PENUGASAN_KELUARGA,
        v.ID_UMAT AS ID_UMAT,
        v.ID_KELUARGA AS ID_KELUARGA,
        v.PERAN_DALAM_KELUARGA AS PERAN_DALAM_KELUARGA,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU
    FROM (VALUES
            ('PKL-00001', 'UMT-00001', 'KEL-0001', 'Kepala Keluarga', '2014-03-28', NULL),
            ('PKL-00002', 'UMT-00002', 'KEL-0001', 'Pasangan', '2014-03-28', NULL),
            ('PKL-00003', 'UMT-00003', 'KEL-0001', 'Anak', '2014-03-28', NULL),
            ('PKL-00004', 'UMT-00004', 'KEL-0002', 'Kepala Keluarga', '2013-11-14', NULL),
            ('PKL-00005', 'UMT-00005', 'KEL-0002', 'Pasangan', '2013-11-14', NULL),
            ('PKL-00006', 'UMT-00006', 'KEL-0002', 'Anak', '2013-11-14', NULL),
            ('PKL-00007', 'UMT-00007', 'KEL-0002', 'Anak', '2025-06-30', NULL),
            ('PKL-00008', 'UMT-00008', 'KEL-0002', 'Anggota Lain', '2013-11-14', NULL),
            ('PKL-00009', 'UMT-00009', 'KEL-0003', 'Kepala Keluarga', '2024-04-02', NULL),
            ('PKL-00010', 'UMT-00010', 'KEL-0003', 'Pasangan', '2024-04-02', NULL),
            ('PKL-00011', 'UMT-00011', 'KEL-0003', 'Anak', '2024-04-02', NULL),
            ('PKL-00012', 'UMT-00012', 'KEL-0003', 'Anak', '2024-04-02', NULL),
            ('PKL-00013', 'UMT-00013', 'KEL-0003', 'Anak', '2024-04-02', NULL),
            ('PKL-00014', 'UMT-00014', 'KEL-0004', 'Kepala Keluarga', '2022-07-17', NULL),
            ('PKL-00015', 'UMT-00015', 'KEL-0004', 'Pasangan', '2022-07-17', NULL),
            ('PKL-00016', 'UMT-00016', 'KEL-0004', 'Anak', '2022-07-17', NULL),
            ('PKL-00017', 'UMT-00017', 'KEL-0005', 'Kepala Keluarga', '2011-05-11', NULL),
            ('PKL-00018', 'UMT-00018', 'KEL-0005', 'Pasangan', '2011-05-11', NULL),
            ('PKL-00019', 'UMT-00019', 'KEL-0006', 'Kepala Keluarga', '2009-04-18', NULL),
            ('PKL-00020', 'UMT-00020', 'KEL-0006', 'Anak', '2009-04-18', NULL),
            ('PKL-00021', 'UMT-00021', 'KEL-0006', 'Anak', '2013-06-30', NULL),
            ('PKL-00022', 'UMT-00022', 'KEL-0007', 'Kepala Keluarga', '2018-07-13', NULL),
            ('PKL-00023', 'UMT-00023', 'KEL-0007', 'Pasangan', '2018-07-13', NULL),
            ('PKL-00024', 'UMT-00024', 'KEL-0008', 'Kepala Keluarga', '2022-05-13', NULL),
            ('PKL-00025', 'UMT-00025', 'KEL-0008', 'Pasangan', '2022-05-13', NULL),
            ('PKL-00026', 'UMT-00026', 'KEL-0008', 'Anak', '2025-06-30', NULL),
            ('PKL-00027', 'UMT-00027', 'KEL-0009', 'Kepala Keluarga', '2008-11-21', NULL),
            ('PKL-00028', 'UMT-00028', 'KEL-0009', 'Pasangan', '2008-11-21', NULL),
            ('PKL-00029', 'UMT-00029', 'KEL-0009', 'Anak', '2020-06-30', NULL),
            ('PKL-00030', 'UMT-00030', 'KEL-0009', 'Anak', '2008-11-21', NULL),
            ('PKL-00031', 'UMT-00031', 'KEL-0009', 'Anggota Lain', '2008-11-21', NULL),
            ('PKL-00032', 'UMT-00032', 'KEL-0010', 'Kepala Keluarga', '2020-05-03', NULL),
            ('PKL-00033', 'UMT-00033', 'KEL-0010', 'Pasangan', '2020-05-03', NULL),
            ('PKL-00034', 'UMT-00034', 'KEL-0010', 'Anak', '2020-05-03', NULL),
            ('PKL-00035', 'UMT-00035', 'KEL-0011', 'Kepala Keluarga', '2021-07-03', NULL),
            ('PKL-00036', 'UMT-00036', 'KEL-0012', 'Kepala Keluarga', '2019-09-05', NULL),
            ('PKL-00037', 'UMT-00037', 'KEL-0012', 'Pasangan', '2019-09-05', NULL),
            ('PKL-00038', 'UMT-00038', 'KEL-0012', 'Anak', '2021-06-30', NULL),
            ('PKL-00039', 'UMT-00039', 'KEL-0012', 'Anak', '2019-09-05', NULL),
            ('PKL-00040', 'UMT-00040', 'KEL-0012', 'Anggota Lain', '2019-09-05', NULL),
            ('PKL-00041', 'UMT-00041', 'KEL-0013', 'Kepala Keluarga', '2023-02-01', NULL),
            ('PKL-00042', 'UMT-00042', 'KEL-0013', 'Anak', '2023-06-30', NULL),
            ('PKL-00043', 'UMT-00043', 'KEL-0014', 'Kepala Keluarga', '2016-03-10', NULL),
            ('PKL-00044', 'UMT-00044', 'KEL-0014', 'Anak', '2023-06-30', NULL),
            ('PKL-00045', 'UMT-00045', 'KEL-0014', 'Anak', '2016-03-10', NULL),
            ('PKL-00046', 'UMT-00046', 'KEL-0015', 'Kepala Keluarga', '2015-02-11', NULL),
            ('PKL-00047', 'UMT-00047', 'KEL-0015', 'Pasangan', '2015-02-11', NULL),
            ('PKL-00048', 'UMT-00048', 'KEL-0015', 'Anak', '2015-02-11', NULL),
            ('PKL-00049', 'UMT-00049', 'KEL-0016', 'Kepala Keluarga', '2013-04-09', NULL),
            ('PKL-00050', 'UMT-00050', 'KEL-0016', 'Pasangan', '2013-04-09', NULL),
            ('PKL-00051', 'UMT-00051', 'KEL-0016', 'Anak', '2013-04-09', NULL),
            ('PKL-00052', 'UMT-00052', 'KEL-0016', 'Anak', '2013-04-09', NULL),
            ('PKL-00053', 'UMT-00053', 'KEL-0016', 'Anak', '2014-06-30', NULL),
            ('PKL-00054', 'UMT-00054', 'KEL-0017', 'Kepala Keluarga', '2019-08-31', NULL),
            ('PKL-00055', 'UMT-00055', 'KEL-0017', 'Pasangan', '2019-08-31', NULL),
            ('PKL-00056', 'UMT-00056', 'KEL-0018', 'Kepala Keluarga', '2015-05-21', NULL),
            ('PKL-00057', 'UMT-00057', 'KEL-0019', 'Kepala Keluarga', '2016-05-29', NULL),
            ('PKL-00058', 'UMT-00058', 'KEL-0019', 'Pasangan', '2016-05-29', NULL),
            ('PKL-00059', 'UMT-00059', 'KEL-0019', 'Anak', '2016-05-29', NULL),
            ('PKL-00060', 'UMT-00060', 'KEL-0020', 'Kepala Keluarga', '2017-04-07', NULL),
            ('PKL-00061', 'UMT-00061', 'KEL-0020', 'Pasangan', '2017-04-07', NULL),
            ('PKL-00062', 'UMT-00062', 'KEL-0020', 'Anak', '2017-06-30', NULL),
            ('PKL-00063', 'UMT-00063', 'KEL-0020', 'Anak', '2017-04-07', NULL),
            ('PKL-00064', 'UMT-00064', 'KEL-0020', 'Anak', '2017-04-07', NULL),
            ('PKL-00065', 'UMT-00065', 'KEL-0021', 'Kepala Keluarga', '2020-07-28', NULL),
            ('PKL-00066', 'UMT-00066', 'KEL-0021', 'Pasangan', '2020-07-28', NULL),
            ('PKL-00067', 'UMT-00067', 'KEL-0022', 'Kepala Keluarga', '2008-11-09', '2026-04-29'),
            ('PKL-00068', 'UMT-00068', 'KEL-0022', 'Pasangan', '2008-11-09', '2026-04-29'),
            ('PKL-00069', 'UMT-00069', 'KEL-0023', 'Kepala Keluarga', '2015-08-29', NULL),
            ('PKL-00070', 'UMT-00070', 'KEL-0023', 'Pasangan', '2015-08-29', NULL),
            ('PKL-00071', 'UMT-00071', 'KEL-0023', 'Anak', '2016-06-30', NULL),
            ('PKL-00072', 'UMT-00072', 'KEL-0023', 'Anak', '2023-06-30', NULL),
            ('PKL-00073', 'UMT-00073', 'KEL-0023', 'Anak', '2019-06-30', NULL),
            ('PKL-00074', 'UMT-00074', 'KEL-0023', 'Anggota Lain', '2015-08-29', NULL),
            ('PKL-00075', 'UMT-00075', 'KEL-0024', 'Kepala Keluarga', '2016-03-11', '2026-08-20'),
            ('PKL-00076', 'UMT-00076', 'KEL-0024', 'Pasangan', '2016-03-11', '2026-08-20'),
            ('PKL-00077', 'UMT-00077', 'KEL-0024', 'Anak', '2016-03-11', '2026-08-20'),
            ('PKL-00078', 'UMT-00078', 'KEL-0025', 'Kepala Keluarga', '2021-11-16', NULL),
            ('PKL-00079', 'UMT-00079', 'KEL-0025', 'Anak', '2021-11-16', NULL),
            ('PKL-00080', 'UMT-00080', 'KEL-0026', 'Kepala Keluarga', '2025-01-27', NULL),
            ('PKL-00081', 'UMT-00081', 'KEL-0026', 'Pasangan', '2025-01-27', NULL),
            ('PKL-00082', 'UMT-00082', 'KEL-0026', 'Anak', '2025-01-27', NULL),
            ('PKL-00083', 'UMT-00083', 'KEL-0026', 'Anak', '2025-01-27', '2025-06-03'),
            ('PKL-00084', 'UMT-00084', 'KEL-0026', 'Anak', '2025-01-27', NULL),
            ('PKL-00085', 'UMT-00085', 'KEL-0027', 'Kepala Keluarga', '2009-02-15', NULL),
            ('PKL-00086', 'UMT-00086', 'KEL-0027', 'Pasangan', '2009-02-15', NULL),
            ('PKL-00087', 'UMT-00087', 'KEL-0028', 'Kepala Keluarga', '2021-07-24', NULL),
            ('PKL-00088', 'UMT-00088', 'KEL-0028', 'Pasangan', '2021-07-24', NULL),
            ('PKL-00089', 'UMT-00089', 'KEL-0028', 'Anak', '2021-07-24', NULL),
            ('PKL-00090', 'UMT-00090', 'KEL-0028', 'Anak', '2021-07-24', NULL),
            ('PKL-00091', 'UMT-00091', 'KEL-0028', 'Anak', '2021-07-24', NULL),
            ('PKL-00092', 'UMT-00092', 'KEL-0029', 'Kepala Keluarga', '2021-12-05', NULL),
            ('PKL-00093', 'UMT-00093', 'KEL-0029', 'Pasangan', '2021-12-05', NULL),
            ('PKL-00094', 'UMT-00094', 'KEL-0029', 'Anak', '2021-12-05', NULL),
            ('PKL-00095', 'UMT-00095', 'KEL-0030', 'Kepala Keluarga', '2023-07-17', NULL),
            ('PKL-00096', 'UMT-00096', 'KEL-0030', 'Pasangan', '2023-07-17', NULL),
            ('PKL-00097', 'UMT-00097', 'KEL-0030', 'Anak', '2023-07-17', NULL),
            ('PKL-00098', 'UMT-00098', 'KEL-0030', 'Anak', '2023-07-17', NULL),
            ('PKL-00099', 'UMT-00099', 'KEL-0030', 'Anak', '2023-07-17', NULL),
            ('PKL-00100', 'UMT-00100', 'KEL-0031', 'Kepala Keluarga', '2015-06-27', NULL),
            ('PKL-00101', 'UMT-00101', 'KEL-0031', 'Pasangan', '2015-06-27', NULL),
            ('PKL-00102', 'UMT-00102', 'KEL-0031', 'Anak', '2015-06-27', NULL),
            ('PKL-00103', 'UMT-00103', 'KEL-0032', 'Kepala Keluarga', '2014-12-25', NULL),
            ('PKL-00104', 'UMT-00104', 'KEL-0032', 'Pasangan', '2014-12-25', NULL),
            ('PKL-00105', 'UMT-00105', 'KEL-0032', 'Anak', '2014-12-25', NULL),
            ('PKL-00106', 'UMT-00106', 'KEL-0032', 'Anak', '2014-12-25', NULL),
            ('PKL-00107', 'UMT-00107', 'KEL-0033', 'Kepala Keluarga', '2013-11-23', NULL),
            ('PKL-00108', 'UMT-00108', 'KEL-0033', 'Pasangan', '2013-11-23', NULL),
            ('PKL-00109', 'UMT-00109', 'KEL-0033', 'Anak', '2018-06-30', NULL),
            ('PKL-00110', 'UMT-00110', 'KEL-0034', 'Kepala Keluarga', '2020-09-16', NULL),
            ('PKL-00111', 'UMT-00111', 'KEL-0034', 'Pasangan', '2020-09-16', NULL),
            ('PKL-00112', 'UMT-00112', 'KEL-0034', 'Anak', '2023-06-30', NULL),
            ('PKL-00113', 'UMT-00113', 'KEL-0034', 'Anak', '2020-09-16', NULL),
            ('PKL-00114', 'UMT-00114', 'KEL-0034', 'Anak', '2021-06-30', NULL),
            ('PKL-00115', 'UMT-00115', 'KEL-0035', 'Kepala Keluarga', '2019-09-10', NULL),
            ('PKL-00116', 'UMT-00116', 'KEL-0035', 'Pasangan', '2019-09-10', NULL),
            ('PKL-00117', 'UMT-00117', 'KEL-0035', 'Anak', '2019-09-10', NULL),
            ('PKL-00118', 'UMT-00118', 'KEL-0035', 'Anak', '2019-09-10', NULL),
            ('PKL-00119', 'UMT-00119', 'KEL-0036', 'Kepala Keluarga', '2018-03-16', NULL),
            ('PKL-00120', 'UMT-00120', 'KEL-0036', 'Pasangan', '2018-03-16', NULL),
            ('PKL-00121', 'UMT-00121', 'KEL-0037', 'Kepala Keluarga', '2020-11-25', NULL),
            ('PKL-00122', 'UMT-00122', 'KEL-0037', 'Pasangan', '2020-11-25', NULL),
            ('PKL-00123', 'UMT-00123', 'KEL-0038', 'Kepala Keluarga', '2008-10-12', NULL),
            ('PKL-00124', 'UMT-00124', 'KEL-0038', 'Pasangan', '2008-10-12', NULL),
            ('PKL-00125', 'UMT-00125', 'KEL-0038', 'Anak', '2009-06-30', NULL),
            ('PKL-00126', 'UMT-00126', 'KEL-0039', 'Kepala Keluarga', '2016-10-23', NULL),
            ('PKL-00127', 'UMT-00127', 'KEL-0039', 'Anak', '2023-06-30', NULL),
            ('PKL-00128', 'UMT-00128', 'KEL-0040', 'Kepala Keluarga', '2024-03-18', NULL),
            ('PKL-00129', 'UMT-00129', 'KEL-0040', 'Pasangan', '2024-03-18', NULL),
            ('PKL-00130', 'UMT-00130', 'KEL-0040', 'Anak', '2024-03-18', NULL),
            ('PKL-00131', 'UMT-00131', 'KEL-0040', 'Anak', '2024-03-18', NULL),
            ('PKL-00132', 'UMT-00132', 'KEL-0041', 'Kepala Keluarga', '2016-03-06', NULL),
            ('PKL-00133', 'UMT-00133', 'KEL-0041', 'Pasangan', '2016-03-06', NULL),
            ('PKL-00134', 'UMT-00134', 'KEL-0041', 'Anak', '2016-03-06', '2024-04-27'),
            ('PKL-00135', 'UMT-00135', 'KEL-0041', 'Anak', '2016-03-06', NULL),
            ('PKL-00136', 'UMT-00136', 'KEL-0041', 'Anak', '2016-03-06', NULL),
            ('PKL-00137', 'UMT-00137', 'KEL-0041', 'Anggota Lain', '2016-03-06', '2025-05-08'),
            ('PKL-00138', 'UMT-00138', 'KEL-0042', 'Kepala Keluarga', '2009-01-08', NULL),
            ('PKL-00139', 'UMT-00139', 'KEL-0042', 'Pasangan', '2009-01-08', NULL),
            ('PKL-00140', 'UMT-00140', 'KEL-0043', 'Kepala Keluarga', '2018-03-15', NULL),
            ('PKL-00141', 'UMT-00141', 'KEL-0043', 'Pasangan', '2018-03-15', NULL),
            ('PKL-00142', 'UMT-00142', 'KEL-0044', 'Kepala Keluarga', '2016-06-19', NULL),
            ('PKL-00143', 'UMT-00143', 'KEL-0044', 'Pasangan', '2016-06-19', NULL),
            ('PKL-00144', 'UMT-00144', 'KEL-0044', 'Anak', '2016-06-19', NULL),
            ('PKL-00145', 'UMT-00145', 'KEL-0044', 'Anak', '2022-06-30', NULL),
            ('PKL-00146', 'UMT-00146', 'KEL-0045', 'Kepala Keluarga', '2019-05-18', NULL),
            ('PKL-00147', 'UMT-00147', 'KEL-0045', 'Pasangan', '2019-05-18', NULL),
            ('PKL-00148', 'UMT-00148', 'KEL-0046', 'Kepala Keluarga', '2019-12-13', NULL),
            ('PKL-00149', 'UMT-00149', 'KEL-0046', 'Pasangan', '2019-12-13', NULL),
            ('PKL-00150', 'UMT-00150', 'KEL-0046', 'Anak', '2019-12-13', NULL),
            ('PKL-00151', 'UMT-00151', 'KEL-0047', 'Kepala Keluarga', '2023-07-23', NULL),
            ('PKL-00152', 'UMT-00152', 'KEL-0047', 'Anak', '2025-06-30', NULL),
            ('PKL-00153', 'UMT-00153', 'KEL-0048', 'Kepala Keluarga', '2017-08-25', NULL),
            ('PKL-00154', 'UMT-00154', 'KEL-0048', 'Pasangan', '2017-08-25', NULL),
            ('PKL-00155', 'UMT-00155', 'KEL-0048', 'Anak', '2017-08-25', NULL),
            ('PKL-00156', 'UMT-00156', 'KEL-0049', 'Kepala Keluarga', '2015-03-15', NULL),
            ('PKL-00157', 'UMT-00157', 'KEL-0049', 'Pasangan', '2015-03-15', NULL),
            ('PKL-00158', 'UMT-00158', 'KEL-0049', 'Anak', '2015-03-15', NULL),
            ('PKL-00159', 'UMT-00159', 'KEL-0049', 'Anak', '2015-03-15', NULL),
            ('PKL-00160', 'UMT-00160', 'KEL-0049', 'Anak', '2018-06-30', NULL),
            ('PKL-00161', 'UMT-00161', 'KEL-0049', 'Anggota Lain', '2015-03-15', NULL),
            ('PKL-00162', 'UMT-00162', 'KEL-0050', 'Kepala Keluarga', '2022-06-11', NULL),
            ('PKL-00163', 'UMT-00163', 'KEL-0050', 'Pasangan', '2022-06-11', NULL),
            ('PKL-00164', 'UMT-00164', 'KEL-0050', 'Anak', '2022-06-11', NULL),
            ('PKL-00165', 'UMT-00165', 'KEL-0050', 'Anak', '2022-06-11', NULL),
            ('PKL-00166', 'UMT-00166', 'KEL-0051', 'Kepala Keluarga', '2011-01-15', NULL),
            ('PKL-00167', 'UMT-00167', 'KEL-0051', 'Pasangan', '2011-01-15', NULL),
            ('PKL-00168', 'UMT-00168', 'KEL-0052', 'Kepala Keluarga', '2012-01-30', NULL),
            ('PKL-00169', 'UMT-00169', 'KEL-0052', 'Pasangan', '2012-01-30', NULL),
            ('PKL-00170', 'UMT-00170', 'KEL-0052', 'Anak', '2019-06-30', NULL),
            ('PKL-00171', 'UMT-00171', 'KEL-0052', 'Anak', '2023-06-30', NULL),
            ('PKL-00172', 'UMT-00172', 'KEL-0052', 'Anak', '2012-06-30', NULL),
            ('PKL-00173', 'UMT-00173', 'KEL-0053', 'Kepala Keluarga', '2017-09-05', NULL),
            ('PKL-00174', 'UMT-00174', 'KEL-0053', 'Pasangan', '2017-09-05', NULL),
            ('PKL-00175', 'UMT-00175', 'KEL-0053', 'Anak', '2017-09-05', '2025-07-26'),
            ('PKL-00176', 'UMT-00176', 'KEL-0054', 'Kepala Keluarga', '2014-09-13', NULL),
            ('PKL-00177', 'UMT-00177', 'KEL-0055', 'Kepala Keluarga', '2020-07-18', NULL),
            ('PKL-00178', 'UMT-00178', 'KEL-0055', 'Pasangan', '2020-07-18', NULL),
            ('PKL-00179', 'UMT-00179', 'KEL-0055', 'Anak', '2020-07-18', NULL),
            ('PKL-00180', 'UMT-00180', 'KEL-0055', 'Anak', '2020-07-18', NULL),
            ('PKL-00181', 'UMT-00181', 'KEL-0056', 'Kepala Keluarga', '2010-09-15', NULL),
            ('PKL-00182', 'UMT-00182', 'KEL-0057', 'Kepala Keluarga', '2024-07-15', NULL),
            ('PKL-00183', 'UMT-00183', 'KEL-0058', 'Kepala Keluarga', '2024-03-02', NULL),
            ('PKL-00184', 'UMT-00184', 'KEL-0058', 'Pasangan', '2024-03-02', NULL),
            ('PKL-00185', 'UMT-00185', 'KEL-0058', 'Anak', '2024-03-02', NULL),
            ('PKL-00186', 'UMT-00186', 'KEL-0058', 'Anak', '2024-03-02', NULL),
            ('PKL-00187', 'UMT-00187', 'KEL-0059', 'Kepala Keluarga', '2009-10-22', NULL),
            ('PKL-00188', 'UMT-00188', 'KEL-0060', 'Kepala Keluarga', '2016-11-10', NULL),
            ('PKL-00189', 'UMT-00189', 'KEL-0060', 'Pasangan', '2016-11-10', NULL),
            ('PKL-00190', 'UMT-00190', 'KEL-0061', 'Kepala Keluarga', '2009-11-05', NULL),
            ('PKL-00191', 'UMT-00191', 'KEL-0061', 'Pasangan', '2009-11-05', NULL),
            ('PKL-00192', 'UMT-00192', 'KEL-0061', 'Anak', '2018-06-30', NULL),
            ('PKL-00193', 'UMT-00193', 'KEL-0062', 'Kepala Keluarga', '2014-02-27', NULL),
            ('PKL-00194', 'UMT-00194', 'KEL-0062', 'Pasangan', '2014-02-27', '2024-10-29'),
            ('PKL-00195', 'UMT-00195', 'KEL-0063', 'Kepala Keluarga', '2017-05-23', NULL),
            ('PKL-00196', 'UMT-00196', 'KEL-0063', 'Pasangan', '2017-05-23', NULL),
            ('PKL-00197', 'UMT-00197', 'KEL-0064', 'Kepala Keluarga', '2017-03-19', NULL),
            ('PKL-00198', 'UMT-00198', 'KEL-0064', 'Pasangan', '2017-03-19', NULL),
            ('PKL-00199', 'UMT-00199', 'KEL-0064', 'Anak', '2017-03-19', NULL),
            ('PKL-00200', 'UMT-00200', 'KEL-0064', 'Anak', '2017-03-19', NULL),
            ('PKL-00201', 'UMT-00201', 'KEL-0064', 'Anggota Lain', '2017-03-19', NULL),
            ('PKL-00202', 'UMT-00202', 'KEL-0065', 'Kepala Keluarga', '2020-01-28', NULL),
            ('PKL-00203', 'UMT-00203', 'KEL-0065', 'Pasangan', '2020-01-28', NULL),
            ('PKL-00204', 'UMT-00204', 'KEL-0065', 'Anak', '2020-01-28', NULL),
            ('PKL-00205', 'UMT-00205', 'KEL-0066', 'Kepala Keluarga', '2016-03-06', NULL),
            ('PKL-00206', 'UMT-00206', 'KEL-0066', 'Anak', '2023-06-30', NULL),
            ('PKL-00207', 'UMT-00207', 'KEL-0067', 'Kepala Keluarga', '2016-04-11', NULL),
            ('PKL-00208', 'UMT-00208', 'KEL-0067', 'Pasangan', '2016-04-11', NULL),
            ('PKL-00209', 'UMT-00209', 'KEL-0067', 'Anak', '2016-04-11', NULL),
            ('PKL-00210', 'UMT-00210', 'KEL-0067', 'Anak', '2016-06-30', NULL),
            ('PKL-00211', 'UMT-00211', 'KEL-0068', 'Kepala Keluarga', '2013-06-22', NULL),
            ('PKL-00212', 'UMT-00212', 'KEL-0068', 'Pasangan', '2013-06-22', NULL),
            ('PKL-00213', 'UMT-00213', 'KEL-0069', 'Kepala Keluarga', '2016-05-03', NULL),
            ('PKL-00214', 'UMT-00214', 'KEL-0070', 'Kepala Keluarga', '2019-04-03', NULL),
            ('PKL-00215', 'UMT-00215', 'KEL-0070', 'Pasangan', '2019-04-03', NULL),
            ('PKL-00216', 'UMT-00216', 'KEL-0070', 'Anak', '2019-04-03', NULL),
            ('PKL-00217', 'UMT-00217', 'KEL-0071', 'Kepala Keluarga', '2022-02-09', NULL),
            ('PKL-00218', 'UMT-00218', 'KEL-0071', 'Pasangan', '2022-02-09', NULL),
            ('PKL-00219', 'UMT-00219', 'KEL-0072', 'Kepala Keluarga', '2011-06-18', NULL),
            ('PKL-00220', 'UMT-00220', 'KEL-0072', 'Pasangan', '2011-06-18', NULL),
            ('PKL-00221', 'UMT-00221', 'KEL-0072', 'Anak', '2014-06-30', NULL),
            ('PKL-00222', 'UMT-00222', 'KEL-0072', 'Anak', '2021-06-30', NULL),
            ('PKL-00223', 'UMT-00223', 'KEL-0073', 'Kepala Keluarga', '2012-11-15', NULL),
            ('PKL-00224', 'UMT-00224', 'KEL-0074', 'Kepala Keluarga', '2013-11-06', NULL),
            ('PKL-00225', 'UMT-00225', 'KEL-0075', 'Kepala Keluarga', '2020-08-08', NULL),
            ('PKL-00226', 'UMT-00226', 'KEL-0075', 'Pasangan', '2020-08-08', NULL),
            ('PKL-00227', 'UMT-00227', 'KEL-0076', 'Kepala Keluarga', '2009-12-20', NULL),
            ('PKL-00228', 'UMT-00228', 'KEL-0076', 'Pasangan', '2009-12-20', NULL),
            ('PKL-00229', 'UMT-00229', 'KEL-0076', 'Anak', '2013-06-30', NULL),
            ('PKL-00230', 'UMT-00230', 'KEL-0076', 'Anak', '2011-06-30', NULL),
            ('PKL-00231', 'UMT-00231', 'KEL-0077', 'Kepala Keluarga', '2020-03-10', NULL),
            ('PKL-00232', 'UMT-00232', 'KEL-0077', 'Pasangan', '2020-03-10', NULL),
            ('PKL-00233', 'UMT-00233', 'KEL-0078', 'Kepala Keluarga', '2018-07-04', NULL),
            ('PKL-00234', 'UMT-00234', 'KEL-0078', 'Pasangan', '2018-07-04', NULL),
            ('PKL-00235', 'UMT-00235', 'KEL-0079', 'Kepala Keluarga', '2010-07-11', NULL),
            ('PKL-00236', 'UMT-00236', 'KEL-0079', 'Pasangan', '2010-07-11', NULL),
            ('PKL-00237', 'UMT-00237', 'KEL-0079', 'Anak', '2021-06-30', NULL),
            ('PKL-00238', 'UMT-00238', 'KEL-0079', 'Anak', '2024-06-30', NULL),
            ('PKL-00239', 'UMT-00239', 'KEL-0079', 'Anak', '2015-06-30', NULL),
            ('PKL-00240', 'UMT-00240', 'KEL-0080', 'Kepala Keluarga', '2019-06-08', NULL),
            ('PKL-00241', 'UMT-00241', 'KEL-0080', 'Pasangan', '2019-06-08', NULL),
            ('PKL-00242', 'UMT-00242', 'KEL-0081', 'Kepala Keluarga', '2022-01-09', NULL),
            ('PKL-00243', 'UMT-00243', 'KEL-0081', 'Pasangan', '2022-01-09', NULL),
            ('PKL-00244', 'UMT-00244', 'KEL-0081', 'Anak', '2022-01-09', '2024-08-26'),
            ('PKL-00245', 'UMT-00245', 'KEL-0082', 'Kepala Keluarga', '2019-05-09', NULL),
            ('PKL-00246', 'UMT-00246', 'KEL-0082', 'Pasangan', '2019-05-09', NULL),
            ('PKL-00247', 'UMT-00247', 'KEL-0083', 'Kepala Keluarga', '2015-07-12', NULL),
            ('PKL-00248', 'UMT-00248', 'KEL-0083', 'Anak', '2016-06-30', NULL),
            ('PKL-00249', 'UMT-00249', 'KEL-0083', 'Anak', '2015-07-12', NULL),
            ('PKL-00250', 'UMT-00250', 'KEL-0084', 'Kepala Keluarga', '2011-06-23', NULL),
            ('PKL-00251', 'UMT-00251', 'KEL-0084', 'Pasangan', '2011-06-23', NULL),
            ('PKL-00252', 'UMT-00252', 'KEL-0084', 'Anak', '2011-06-23', '2024-08-25'),
            ('PKL-00253', 'UMT-00253', 'KEL-0084', 'Anggota Lain', '2011-06-23', NULL),
            ('PKL-00254', 'UMT-00254', 'KEL-0085', 'Kepala Keluarga', '2017-03-15', NULL),
            ('PKL-00255', 'UMT-00255', 'KEL-0085', 'Pasangan', '2017-03-15', NULL),
            ('PKL-00256', 'UMT-00256', 'KEL-0085', 'Anak', '2017-03-15', NULL),
            ('PKL-00257', 'UMT-00257', 'KEL-0085', 'Anak', '2017-03-15', NULL),
            ('PKL-00258', 'UMT-00258', 'KEL-0085', 'Anak', '2018-06-30', NULL),
            ('PKL-00259', 'UMT-00259', 'KEL-0086', 'Kepala Keluarga', '2020-10-28', NULL),
            ('PKL-00260', 'UMT-00260', 'KEL-0087', 'Kepala Keluarga', '2020-12-01', NULL),
            ('PKL-00261', 'UMT-00261', 'KEL-0087', 'Pasangan', '2020-12-01', NULL),
            ('PKL-00262', 'UMT-00262', 'KEL-0087', 'Anak', '2020-12-01', NULL),
            ('PKL-00263', 'UMT-00263', 'KEL-0087', 'Anak', '2020-12-01', NULL),
            ('PKL-00264', 'UMT-00264', 'KEL-0088', 'Kepala Keluarga', '2012-01-07', NULL),
            ('PKL-00265', 'UMT-00265', 'KEL-0088', 'Anak', '2012-01-07', NULL),
            ('PKL-00266', 'UMT-00266', 'KEL-0089', 'Kepala Keluarga', '2019-10-06', NULL),
            ('PKL-00267', 'UMT-00267', 'KEL-0089', 'Pasangan', '2019-10-06', NULL),
            ('PKL-00268', 'UMT-00268', 'KEL-0089', 'Anak', '2019-10-06', NULL),
            ('PKL-00269', 'UMT-00269', 'KEL-0089', 'Anak', '2019-10-06', NULL),
            ('PKL-00270', 'UMT-00270', 'KEL-0090', 'Kepala Keluarga', '2019-05-26', NULL),
            ('PKL-00271', 'UMT-00271', 'KEL-0091', 'Kepala Keluarga', '2021-01-23', NULL),
            ('PKL-00272', 'UMT-00272', 'KEL-0091', 'Pasangan', '2021-01-23', NULL),
            ('PKL-00273', 'UMT-00273', 'KEL-0091', 'Anak', '2021-01-23', NULL),
            ('PKL-00274', 'UMT-00274', 'KEL-0091', 'Anak', '2021-01-23', NULL),
            ('PKL-00275', 'UMT-00275', 'KEL-0091', 'Anak', '2021-01-23', NULL),
            ('PKL-00276', 'UMT-00276', 'KEL-0092', 'Kepala Keluarga', '2012-11-30', NULL),
            ('PKL-00277', 'UMT-00277', 'KEL-0093', 'Kepala Keluarga', '2014-03-12', NULL),
            ('PKL-00278', 'UMT-00278', 'KEL-0093', 'Pasangan', '2014-03-12', NULL),
            ('PKL-00279', 'UMT-00279', 'KEL-0094', 'Kepala Keluarga', '2015-05-24', NULL),
            ('PKL-00280', 'UMT-00280', 'KEL-0094', 'Pasangan', '2015-05-24', NULL),
            ('PKL-00281', 'UMT-00281', 'KEL-0094', 'Anak', '2015-05-24', NULL),
            ('PKL-00282', 'UMT-00282', 'KEL-0094', 'Anak', '2016-06-30', NULL),
            ('PKL-00283', 'UMT-00283', 'KEL-0095', 'Kepala Keluarga', '2021-03-13', NULL),
            ('PKL-00284', 'UMT-00284', 'KEL-0095', 'Pasangan', '2021-03-13', NULL),
            ('PKL-00285', 'UMT-00285', 'KEL-0095', 'Anak', '2021-03-13', NULL),
            ('PKL-00286', 'UMT-00286', 'KEL-0095', 'Anak', '2021-03-13', '2026-08-13'),
            ('PKL-00287', 'UMT-00287', 'KEL-0095', 'Anak', '2021-03-13', NULL),
            ('PKL-00288', 'UMT-00288', 'KEL-0096', 'Kepala Keluarga', '2009-03-21', NULL),
            ('PKL-00289', 'UMT-00289', 'KEL-0096', 'Pasangan', '2009-03-21', NULL),
            ('PKL-00290', 'UMT-00290', 'KEL-0096', 'Anak', '2009-03-21', NULL),
            ('PKL-00291', 'UMT-00291', 'KEL-0097', 'Kepala Keluarga', '2021-04-03', NULL),
            ('PKL-00292', 'UMT-00292', 'KEL-0097', 'Pasangan', '2021-04-03', NULL),
            ('PKL-00293', 'UMT-00293', 'KEL-0097', 'Anak', '2022-06-30', NULL),
            ('PKL-00294', 'UMT-00294', 'KEL-0097', 'Anak', '2021-04-03', NULL),
            ('PKL-00295', 'UMT-00295', 'KEL-0098', 'Kepala Keluarga', '2024-05-02', NULL),
            ('PKL-00296', 'UMT-00296', 'KEL-0098', 'Pasangan', '2024-05-02', NULL),
            ('PKL-00297', 'UMT-00297', 'KEL-0098', 'Anak', '2024-05-02', NULL),
            ('PKL-00298', 'UMT-00298', 'KEL-0098', 'Anak', '2024-05-02', NULL),
            ('PKL-00299', 'UMT-00299', 'KEL-0098', 'Anak', '2024-05-02', NULL),
            ('PKL-00300', 'UMT-00300', 'KEL-0099', 'Kepala Keluarga', '2021-06-13', NULL),
            ('PKL-00301', 'UMT-00301', 'KEL-0100', 'Kepala Keluarga', '2015-04-30', NULL),
            ('PKL-00302', 'UMT-00302', 'KEL-0100', 'Pasangan', '2015-04-30', NULL),
            ('PKL-00303', 'UMT-00303', 'KEL-0100', 'Anak', '2022-06-30', NULL),
            ('PKL-00304', 'UMT-00304', 'KEL-0100', 'Anak', '2015-04-30', NULL),
            ('PKL-00305', 'UMT-00305', 'KEL-0101', 'Kepala Keluarga', '2016-07-02', NULL),
            ('PKL-00306', 'UMT-00306', 'KEL-0101', 'Pasangan', '2016-07-02', NULL),
            ('PKL-00307', 'UMT-00307', 'KEL-0101', 'Anak', '2016-07-02', NULL),
            ('PKL-00308', 'UMT-00308', 'KEL-0102', 'Kepala Keluarga', '2013-01-29', NULL),
            ('PKL-00309', 'UMT-00309', 'KEL-0102', 'Pasangan', '2013-01-29', NULL),
            ('PKL-00310', 'UMT-00310', 'KEL-0102', 'Anak', '2013-06-30', NULL),
            ('PKL-00311', 'UMT-00311', 'KEL-0102', 'Anak', '2022-06-30', NULL),
            ('PKL-00312', 'UMT-00312', 'KEL-0102', 'Anak', '2022-06-30', NULL),
            ('PKL-00313', 'UMT-00313', 'KEL-0103', 'Kepala Keluarga', '2011-10-14', NULL),
            ('PKL-00314', 'UMT-00314', 'KEL-0103', 'Pasangan', '2011-10-14', NULL),
            ('PKL-00315', 'UMT-00315', 'KEL-0103', 'Anak', '2014-06-30', NULL),
            ('PKL-00316', 'UMT-00316', 'KEL-0104', 'Kepala Keluarga', '2015-06-30', NULL),
            ('PKL-00317', 'UMT-00317', 'KEL-0104', 'Pasangan', '2015-06-30', NULL),
            ('PKL-00318', 'UMT-00318', 'KEL-0104', 'Anak', '2015-06-30', NULL),
            ('PKL-00319', 'UMT-00319', 'KEL-0105', 'Kepala Keluarga', '2011-02-01', NULL),
            ('PKL-00320', 'UMT-00320', 'KEL-0105', 'Pasangan', '2011-02-01', NULL),
            ('PKL-00321', 'UMT-00321', 'KEL-0105', 'Anak', '2014-06-30', NULL),
            ('PKL-00322', 'UMT-00322', 'KEL-0105', 'Anak', '2015-06-30', NULL),
            ('PKL-00323', 'UMT-00323', 'KEL-0105', 'Anggota Lain', '2011-02-01', NULL),
            ('PKL-00324', 'UMT-00324', 'KEL-0106', 'Kepala Keluarga', '2008-06-21', NULL),
            ('PKL-00325', 'UMT-00325', 'KEL-0106', 'Pasangan', '2008-06-21', NULL),
            ('PKL-00326', 'UMT-00326', 'KEL-0107', 'Kepala Keluarga', '2016-03-25', NULL),
            ('PKL-00327', 'UMT-00327', 'KEL-0107', 'Anak', '2021-06-30', NULL),
            ('PKL-00328', 'UMT-00328', 'KEL-0107', 'Anak', '2016-03-25', NULL),
            ('PKL-00329', 'UMT-00329', 'KEL-0108', 'Kepala Keluarga', '2020-09-11', NULL),
            ('PKL-00330', 'UMT-00330', 'KEL-0108', 'Pasangan', '2020-09-11', NULL),
            ('PKL-00331', 'UMT-00331', 'KEL-0108', 'Anak', '2020-09-11', NULL),
            ('PKL-00332', 'UMT-00332', 'KEL-0108', 'Anak', '2020-09-11', NULL),
            ('PKL-00333', 'UMT-00333', 'KEL-0108', 'Anak', '2020-09-11', NULL),
            ('PKL-00334', 'UMT-00334', 'KEL-0109', 'Kepala Keluarga', '2012-04-28', NULL),
            ('PKL-00335', 'UMT-00335', 'KEL-0109', 'Pasangan', '2012-04-28', NULL),
            ('PKL-00336', 'UMT-00336', 'KEL-0109', 'Anak', '2023-06-30', NULL),
            ('PKL-00337', 'UMT-00337', 'KEL-0109', 'Anggota Lain', '2012-04-28', NULL),
            ('PKL-00338', 'UMT-00338', 'KEL-0110', 'Kepala Keluarga', '2012-06-13', NULL),
            ('PKL-00339', 'UMT-00339', 'KEL-0110', 'Pasangan', '2012-06-13', NULL),
            ('PKL-00340', 'UMT-00340', 'KEL-0111', 'Kepala Keluarga', '2013-06-13', NULL),
            ('PKL-00341', 'UMT-00341', 'KEL-0111', 'Pasangan', '2013-06-13', NULL),
            ('PKL-00342', 'UMT-00342', 'KEL-0111', 'Anak', '2013-06-13', NULL),
            ('PKL-00343', 'UMT-00343', 'KEL-0111', 'Anak', '2022-06-30', NULL),
            ('PKL-00344', 'UMT-00344', 'KEL-0111', 'Anggota Lain', '2013-06-13', NULL),
            ('PKL-00345', 'UMT-00345', 'KEL-0112', 'Kepala Keluarga', '2010-08-04', NULL),
            ('PKL-00346', 'UMT-00346', 'KEL-0112', 'Pasangan', '2010-08-04', NULL),
            ('PKL-00347', 'UMT-00347', 'KEL-0112', 'Anak', '2010-08-04', NULL),
            ('PKL-00348', 'UMT-00348', 'KEL-0113', 'Kepala Keluarga', '2021-11-13', NULL),
            ('PKL-00349', 'UMT-00349', 'KEL-0113', 'Pasangan', '2021-11-13', NULL),
            ('PKL-00350', 'UMT-00350', 'KEL-0113', 'Anak', '2021-11-13', NULL),
            ('PKL-00351', 'UMT-00351', 'KEL-0113', 'Anak', '2021-11-13', NULL),
            ('PKL-00352', 'UMT-00352', 'KEL-0113', 'Anak', '2023-06-30', NULL),
            ('PKL-00353', 'UMT-00353', 'KEL-0114', 'Kepala Keluarga', '2020-05-16', NULL),
            ('PKL-00354', 'UMT-00354', 'KEL-0114', 'Anak', '2020-05-16', NULL),
            ('PKL-00355', 'UMT-00355', 'KEL-0115', 'Kepala Keluarga', '2021-02-23', NULL),
            ('PKL-00356', 'UMT-00356', 'KEL-0115', 'Pasangan', '2021-02-23', NULL),
            ('PKL-00357', 'UMT-00357', 'KEL-0115', 'Anak', '2021-02-23', NULL),
            ('PKL-00358', 'UMT-00358', 'KEL-0116', 'Kepala Keluarga', '2020-11-09', NULL),
            ('PKL-00359', 'UMT-00359', 'KEL-0116', 'Pasangan', '2020-11-09', NULL),
            ('PKL-00360', 'UMT-00360', 'KEL-0116', 'Anak', '2020-11-09', NULL),
            ('PKL-00361', 'UMT-00361', 'KEL-0117', 'Kepala Keluarga', '2024-10-12', NULL),
            ('PKL-00362', 'UMT-00362', 'KEL-0117', 'Pasangan', '2024-10-12', NULL),
            ('PKL-00363', 'UMT-00363', 'KEL-0118', 'Kepala Keluarga', '2017-02-03', NULL),
            ('PKL-00364', 'UMT-00364', 'KEL-0118', 'Anak', '2017-02-03', NULL),
            ('PKL-00365', 'UMT-00365', 'KEL-0119', 'Kepala Keluarga', '2020-04-28', NULL),
            ('PKL-00366', 'UMT-00366', 'KEL-0119', 'Pasangan', '2020-04-28', NULL),
            ('PKL-00367', 'UMT-00367', 'KEL-0120', 'Kepala Keluarga', '2021-07-01', NULL),
            ('PKL-00368', 'UMT-00368', 'KEL-0120', 'Pasangan', '2021-07-01', NULL),
            ('PKL-00369', 'UMT-00369', 'KEL-0120', 'Anak', '2021-07-01', NULL),
            ('PKL-00370', 'UMT-00370', 'KEL-0120', 'Anak', '2021-07-01', NULL),
            ('PKL-00371', 'UMT-00371', 'KEL-0121', 'Kepala Keluarga', '2024-10-27', NULL),
            ('PKL-00372', 'UMT-00372', 'KEL-0121', 'Pasangan', '2024-10-27', NULL),
            ('PKL-00373', 'UMT-00373', 'KEL-0122', 'Kepala Keluarga', '2024-04-27', NULL),
            ('PKL-00374', 'UMT-00374', 'KEL-0122', 'Pasangan', '2024-04-27', NULL),
            ('PKL-00375', 'UMT-00375', 'KEL-0122', 'Anak', '2024-04-27', NULL),
            ('PKL-00376', 'UMT-00376', 'KEL-0122', 'Anak', '2024-04-27', NULL),
            ('PKL-00377', 'UMT-00377', 'KEL-0123', 'Kepala Keluarga', '2012-10-23', NULL),
            ('PKL-00378', 'UMT-00378', 'KEL-0123', 'Pasangan', '2012-10-23', NULL),
            ('PKL-00379', 'UMT-00379', 'KEL-0123', 'Anak', '2015-06-30', NULL),
            ('PKL-00380', 'UMT-00380', 'KEL-0124', 'Kepala Keluarga', '2016-06-08', NULL),
            ('PKL-00381', 'UMT-00381', 'KEL-0124', 'Pasangan', '2016-06-08', NULL),
            ('PKL-00382', 'UMT-00382', 'KEL-0125', 'Kepala Keluarga', '2010-04-06', NULL),
            ('PKL-00383', 'UMT-00383', 'KEL-0125', 'Pasangan', '2010-04-06', NULL),
            ('PKL-00384', 'UMT-00384', 'KEL-0126', 'Kepala Keluarga', '2022-10-06', NULL),
            ('PKL-00385', 'UMT-00385', 'KEL-0127', 'Kepala Keluarga', '2020-03-23', NULL),
            ('PKL-00386', 'UMT-00386', 'KEL-0128', 'Kepala Keluarga', '2011-10-30', NULL),
            ('PKL-00387', 'UMT-00387', 'KEL-0128', 'Pasangan', '2011-10-30', NULL),
            ('PKL-00388', 'UMT-00388', 'KEL-0128', 'Anak', '2012-06-30', NULL),
            ('PKL-00389', 'UMT-00389', 'KEL-0129', 'Kepala Keluarga', '2010-09-16', NULL),
            ('PKL-00390', 'UMT-00390', 'KEL-0130', 'Kepala Keluarga', '2025-03-09', NULL),
            ('PKL-00391', 'UMT-00391', 'KEL-0130', 'Pasangan', '2025-03-09', NULL),
            ('PKL-00392', 'UMT-00392', 'KEL-0131', 'Kepala Keluarga', '2012-12-09', NULL),
            ('PKL-00393', 'UMT-00393', 'KEL-0132', 'Kepala Keluarga', '2008-06-03', NULL),
            ('PKL-00394', 'UMT-00394', 'KEL-0132', 'Pasangan', '2008-06-03', NULL),
            ('PKL-00395', 'UMT-00395', 'KEL-0133', 'Kepala Keluarga', '2008-12-14', NULL),
            ('PKL-00396', 'UMT-00396', 'KEL-0133', 'Pasangan', '2008-12-14', NULL),
            ('PKL-00397', 'UMT-00397', 'KEL-0133', 'Anak', '2008-12-14', NULL),
            ('PKL-00398', 'UMT-00398', 'KEL-0134', 'Kepala Keluarga', '2008-06-21', NULL),
            ('PKL-00399', 'UMT-00399', 'KEL-0134', 'Pasangan', '2008-06-21', NULL),
            ('PKL-00400', 'UMT-00400', 'KEL-0135', 'Kepala Keluarga', '2018-11-10', NULL),
            ('PKL-00401', 'UMT-00401', 'KEL-0135', 'Pasangan', '2018-11-10', NULL),
            ('PKL-00402', 'UMT-00402', 'KEL-0135', 'Anak', '2018-11-10', NULL),
            ('PKL-00403', 'UMT-00403', 'KEL-0136', 'Kepala Keluarga', '2021-01-06', NULL),
            ('PKL-00404', 'UMT-00404', 'KEL-0136', 'Pasangan', '2021-01-06', NULL),
            ('PKL-00405', 'UMT-00405', 'KEL-0136', 'Anak', '2021-01-06', NULL),
            ('PKL-00406', 'UMT-00406', 'KEL-0136', 'Anak', '2023-06-30', NULL),
            ('PKL-00407', 'UMT-00407', 'KEL-0136', 'Anak', '2021-01-06', NULL),
            ('PKL-00408', 'UMT-00408', 'KEL-0137', 'Kepala Keluarga', '2023-04-30', NULL),
            ('PKL-00409', 'UMT-00409', 'KEL-0137', 'Pasangan', '2023-04-30', NULL),
            ('PKL-00410', 'UMT-00410', 'KEL-0137', 'Anak', '2023-04-30', NULL),
            ('PKL-00411', 'UMT-00411', 'KEL-0138', 'Kepala Keluarga', '2014-10-03', NULL),
            ('PKL-00412', 'UMT-00412', 'KEL-0138', 'Pasangan', '2014-10-03', NULL),
            ('PKL-00413', 'UMT-00413', 'KEL-0138', 'Anak', '2014-10-03', NULL),
            ('PKL-00414', 'UMT-00414', 'KEL-0139', 'Kepala Keluarga', '2014-01-26', NULL),
            ('PKL-00415', 'UMT-00415', 'KEL-0139', 'Pasangan', '2014-01-26', NULL),
            ('PKL-00416', 'UMT-00416', 'KEL-0139', 'Anak', '2014-01-26', NULL),
            ('PKL-00417', 'UMT-00417', 'KEL-0139', 'Anak', '2014-01-26', NULL),
            ('PKL-00418', 'UMT-00418', 'KEL-0140', 'Kepala Keluarga', '2017-06-21', NULL),
            ('PKL-00419', 'UMT-00419', 'KEL-0140', 'Anak', '2024-06-30', NULL),
            ('PKL-00420', 'UMT-00420', 'KEL-0140', 'Anak', '2017-06-21', NULL),
            ('PKL-00421', 'UMT-00421', 'KEL-0141', 'Kepala Keluarga', '2008-05-01', NULL),
            ('PKL-00422', 'UMT-00422', 'KEL-0141', 'Pasangan', '2008-05-01', NULL),
            ('PKL-00423', 'UMT-00423', 'KEL-0141', 'Anak', '2008-05-01', NULL),
            ('PKL-00424', 'UMT-00424', 'KEL-0141', 'Anak', '2008-06-30', NULL),
            ('PKL-00425', 'UMT-00425', 'KEL-0141', 'Anak', '2008-06-30', NULL),
            ('PKL-00426', 'UMT-00426', 'KEL-0142', 'Kepala Keluarga', '2024-02-07', NULL),
            ('PKL-00427', 'UMT-00427', 'KEL-0142', 'Pasangan', '2024-02-07', NULL),
            ('PKL-00428', 'UMT-00428', 'KEL-0143', 'Kepala Keluarga', '2016-02-17', NULL),
            ('PKL-00429', 'UMT-00429', 'KEL-0143', 'Anak', '2022-06-30', NULL),
            ('PKL-00430', 'UMT-00430', 'KEL-0144', 'Kepala Keluarga', '2015-12-06', NULL),
            ('PKL-00431', 'UMT-00431', 'KEL-0144', 'Anak', '2015-12-06', NULL),
            ('PKL-00432', 'UMT-00432', 'KEL-0145', 'Kepala Keluarga', '2013-07-20', NULL),
            ('PKL-00433', 'UMT-00433', 'KEL-0145', 'Anak', '2018-06-30', NULL),
            ('PKL-00434', 'UMT-00434', 'KEL-0146', 'Kepala Keluarga', '2008-11-20', NULL),
            ('PKL-00435', 'UMT-00435', 'KEL-0146', 'Pasangan', '2008-11-20', NULL),
            ('PKL-00436', 'UMT-00436', 'KEL-0147', 'Kepala Keluarga', '2025-04-21', NULL),
            ('PKL-00437', 'UMT-00437', 'KEL-0147', 'Pasangan', '2025-04-21', NULL),
            ('PKL-00438', 'UMT-00438', 'KEL-0147', 'Anak', '2025-04-21', NULL),
            ('PKL-00439', 'UMT-00439', 'KEL-0147', 'Anak', '2025-04-21', NULL),
            ('PKL-00440', 'UMT-00440', 'KEL-0147', 'Anak', '2025-04-21', NULL),
            ('PKL-00441', 'UMT-00441', 'KEL-0148', 'Kepala Keluarga', '2016-09-17', NULL),
            ('PKL-00442', 'UMT-00442', 'KEL-0148', 'Pasangan', '2016-09-17', NULL),
            ('PKL-00443', 'UMT-00443', 'KEL-0149', 'Kepala Keluarga', '2012-02-27', NULL),
            ('PKL-00444', 'UMT-00444', 'KEL-0149', 'Pasangan', '2012-02-27', NULL),
            ('PKL-00445', 'UMT-00445', 'KEL-0149', 'Anak', '2024-06-30', NULL),
            ('PKL-00446', 'UMT-00446', 'KEL-0149', 'Anak', '2012-02-27', NULL),
            ('PKL-00447', 'UMT-00447', 'KEL-0150', 'Kepala Keluarga', '2020-03-12', NULL),
            ('PKL-00448', 'UMT-00448', 'KEL-0150', 'Pasangan', '2020-03-12', NULL),
            ('PKL-00449', 'UMT-00449', 'KEL-0150', 'Anak', '2020-03-12', NULL),
            ('PKL-00450', 'UMT-00450', 'KEL-0150', 'Anak', '2022-06-30', NULL),
            ('PKL-00451', 'UMT-00451', 'KEL-0150', 'Anak', '2020-03-12', NULL),
            ('PKL-00452', 'UMT-00452', 'KEL-0151', 'Kepala Keluarga', '2021-05-13', NULL),
            ('PKL-00453', 'UMT-00453', 'KEL-0151', 'Pasangan', '2021-05-13', NULL),
            ('PKL-00454', 'UMT-00454', 'KEL-0151', 'Anak', '2021-05-13', NULL),
            ('PKL-00455', 'UMT-00455', 'KEL-0152', 'Kepala Keluarga', '2020-06-21', NULL),
            ('PKL-00456', 'UMT-00456', 'KEL-0152', 'Pasangan', '2020-06-21', NULL),
            ('PKL-00457', 'UMT-00457', 'KEL-0152', 'Anak', '2020-06-21', NULL),
            ('PKL-00458', 'UMT-00458', 'KEL-0153', 'Kepala Keluarga', '2022-11-02', NULL),
            ('PKL-00459', 'UMT-00459', 'KEL-0153', 'Anak', '2022-11-02', NULL),
            ('PKL-00460', 'UMT-00460', 'KEL-0153', 'Anak', '2022-11-02', NULL),
            ('PKL-00461', 'UMT-00461', 'KEL-0154', 'Kepala Keluarga', '2014-11-26', NULL),
            ('PKL-00462', 'UMT-00462', 'KEL-0154', 'Pasangan', '2014-11-26', NULL),
            ('PKL-00463', 'UMT-00463', 'KEL-0154', 'Anak', '2018-06-30', NULL),
            ('PKL-00464', 'UMT-00464', 'KEL-0154', 'Anak', '2023-06-30', NULL),
            ('PKL-00465', 'UMT-00465', 'KEL-0154', 'Anak', '2014-11-26', NULL),
            ('PKL-00466', 'UMT-00466', 'KEL-0155', 'Kepala Keluarga', '2011-01-13', NULL),
            ('PKL-00467', 'UMT-00467', 'KEL-0155', 'Pasangan', '2011-01-13', NULL),
            ('PKL-00468', 'UMT-00468', 'KEL-0155', 'Anak', '2011-01-13', NULL),
            ('PKL-00469', 'UMT-00469', 'KEL-0155', 'Anak', '2011-01-13', '2026-04-05'),
            ('PKL-00470', 'UMT-00470', 'KEL-0156', 'Kepala Keluarga', '2023-09-10', NULL),
            ('PKL-00471', 'UMT-00471', 'KEL-0156', 'Pasangan', '2023-09-10', NULL),
            ('PKL-00472', 'UMT-00472', 'KEL-0157', 'Kepala Keluarga', '2010-06-10', NULL),
            ('PKL-00473', 'UMT-00473', 'KEL-0157', 'Pasangan', '2010-06-10', NULL),
            ('PKL-00474', 'UMT-00474', 'KEL-0157', 'Anak', '2010-06-10', '2025-11-16'),
            ('PKL-00475', 'UMT-00475', 'KEL-0157', 'Anak', '2010-06-30', NULL),
            ('PKL-00476', 'UMT-00476', 'KEL-0157', 'Anak', '2016-06-30', NULL),
            ('PKL-00477', 'UMT-00477', 'KEL-0158', 'Kepala Keluarga', '2021-07-01', NULL),
            ('PKL-00478', 'UMT-00478', 'KEL-0158', 'Anak', '2024-06-30', NULL),
            ('PKL-00479', 'UMT-00479', 'KEL-0159', 'Kepala Keluarga', '2018-04-07', NULL),
            ('PKL-00480', 'UMT-00480', 'KEL-0159', 'Pasangan', '2018-04-07', NULL),
            ('PKL-00481', 'UMT-00481', 'KEL-0159', 'Anak', '2018-04-07', '2024-04-13'),
            ('PKL-00482', 'UMT-00482', 'KEL-0159', 'Anak', '2018-04-07', NULL),
            ('PKL-00483', 'UMT-00483', 'KEL-0160', 'Kepala Keluarga', '2024-06-17', '2025-06-26'),
            ('PKL-00484', 'UMT-00484', 'KEL-0161', 'Kepala Keluarga', '2025-06-20', NULL),
            ('PKL-00485', 'UMT-00485', 'KEL-0161', 'Pasangan', '2025-06-20', NULL),
            ('PKL-00486', 'UMT-00486', 'KEL-0161', 'Anak', '2025-06-20', NULL),
            ('PKL-00487', 'UMT-00487', 'KEL-0161', 'Anak', '2025-06-20', NULL),
            ('PKL-00488', 'UMT-00488', 'KEL-0162', 'Kepala Keluarga', '2018-08-19', NULL),
            ('PKL-00489', 'UMT-00489', 'KEL-0162', 'Pasangan', '2018-08-19', NULL),
            ('PKL-00490', 'UMT-00490', 'KEL-0162', 'Anak', '2018-08-19', NULL),
            ('PKL-00491', 'UMT-00491', 'KEL-0162', 'Anak', '2018-08-19', NULL),
            ('PKL-00492', 'UMT-00492', 'KEL-0163', 'Kepala Keluarga', '2017-09-20', NULL),
            ('PKL-00493', 'UMT-00493', 'KEL-0163', 'Pasangan', '2017-09-20', NULL),
            ('PKL-00494', 'UMT-00494', 'KEL-0164', 'Kepala Keluarga', '2011-08-20', NULL),
            ('PKL-00495', 'UMT-00495', 'KEL-0165', 'Kepala Keluarga', '2023-02-18', NULL),
            ('PKL-00496', 'UMT-00496', 'KEL-0165', 'Pasangan', '2023-02-18', NULL),
            ('PKL-00497', 'UMT-00497', 'KEL-0165', 'Anak', '2023-02-18', NULL),
            ('PKL-00498', 'UMT-00498', 'KEL-0165', 'Anak', '2023-02-18', NULL),
            ('PKL-00499', 'UMT-00499', 'KEL-0165', 'Anak', '2023-02-18', NULL),
            ('PKL-00500', 'UMT-00500', 'KEL-0166', 'Kepala Keluarga', '2020-10-29', NULL),
            ('PKL-00501', 'UMT-00501', 'KEL-0167', 'Kepala Keluarga', '2015-12-03', NULL),
            ('PKL-00502', 'UMT-00502', 'KEL-0167', 'Pasangan', '2015-12-03', NULL),
            ('PKL-00503', 'UMT-00503', 'KEL-0168', 'Kepala Keluarga', '2021-05-29', NULL),
            ('PKL-00504', 'UMT-00504', 'KEL-0168', 'Pasangan', '2021-05-29', NULL),
            ('PKL-00505', 'UMT-00505', 'KEL-0168', 'Anak', '2023-06-30', NULL),
            ('PKL-00506', 'UMT-00506', 'KEL-0168', 'Anak', '2021-05-29', NULL),
            ('PKL-00507', 'UMT-00507', 'KEL-0168', 'Anak', '2021-05-29', NULL),
            ('PKL-00508', 'UMT-00508', 'KEL-0169', 'Kepala Keluarga', '2008-03-12', NULL),
            ('PKL-00509', 'UMT-00509', 'KEL-0169', 'Pasangan', '2008-03-12', NULL),
            ('PKL-00510', 'UMT-00510', 'KEL-0169', 'Anak', '2012-06-30', NULL),
            ('PKL-00511', 'UMT-00511', 'KEL-0169', 'Anggota Lain', '2008-03-12', NULL),
            ('PKL-00512', 'UMT-00512', 'KEL-0170', 'Kepala Keluarga', '2009-11-09', NULL),
            ('PKL-00513', 'UMT-00513', 'KEL-0170', 'Pasangan', '2009-11-09', NULL),
            ('PKL-00514', 'UMT-00514', 'KEL-0171', 'Kepala Keluarga', '2021-10-24', NULL),
            ('PKL-00515', 'UMT-00515', 'KEL-0171', 'Pasangan', '2021-10-24', NULL),
            ('PKL-00516', 'UMT-00516', 'KEL-0171', 'Anak', '2023-06-30', NULL),
            ('PKL-00517', 'UMT-00517', 'KEL-0172', 'Kepala Keluarga', '2009-07-03', NULL),
            ('PKL-00518', 'UMT-00518', 'KEL-0173', 'Kepala Keluarga', '2009-08-12', NULL),
            ('PKL-00519', 'UMT-00519', 'KEL-0173', 'Pasangan', '2009-08-12', NULL),
            ('PKL-00520', 'UMT-00520', 'KEL-0173', 'Anak', '2024-06-30', NULL),
            ('PKL-00521', 'UMT-00521', 'KEL-0173', 'Anak', '2022-06-30', NULL),
            ('PKL-00522', 'UMT-00522', 'KEL-0173', 'Anak', '2010-06-30', NULL),
            ('PKL-00523', 'UMT-00523', 'KEL-0174', 'Kepala Keluarga', '2010-02-01', NULL),
            ('PKL-00524', 'UMT-00524', 'KEL-0174', 'Pasangan', '2010-02-01', NULL),
            ('PKL-00525', 'UMT-00525', 'KEL-0174', 'Anak', '2016-06-30', NULL),
            ('PKL-00526', 'UMT-00526', 'KEL-0174', 'Anak', '2024-06-30', NULL),
            ('PKL-00527', 'UMT-00527', 'KEL-0174', 'Anak', '2010-02-01', NULL),
            ('PKL-00528', 'UMT-00528', 'KEL-0175', 'Kepala Keluarga', '2018-03-15', NULL),
            ('PKL-00529', 'UMT-00529', 'KEL-0175', 'Pasangan', '2018-03-15', NULL),
            ('PKL-00530', 'UMT-00530', 'KEL-0176', 'Kepala Keluarga', '2021-02-06', '2025-05-25'),
            ('PKL-00531', 'UMT-00531', 'KEL-0176', 'Pasangan', '2021-02-06', '2025-05-25'),
            ('PKL-00532', 'UMT-00532', 'KEL-0176', 'Anak', '2021-02-06', '2025-05-25'),
            ('PKL-00533', 'UMT-00533', 'KEL-0176', 'Anak', '2021-02-06', '2025-05-25'),
            ('PKL-00534', 'UMT-00534', 'KEL-0176', 'Anak', '2021-02-06', '2025-05-25'),
            ('PKL-00535', 'UMT-00535', 'KEL-0177', 'Kepala Keluarga', '2013-06-15', NULL),
            ('PKL-00536', 'UMT-00536', 'KEL-0177', 'Pasangan', '2013-06-15', NULL),
            ('PKL-00537', 'UMT-00537', 'KEL-0178', 'Kepala Keluarga', '2019-02-19', NULL),
            ('PKL-00538', 'UMT-00538', 'KEL-0178', 'Pasangan', '2019-02-19', NULL),
            ('PKL-00539', 'UMT-00539', 'KEL-0178', 'Anak', '2019-02-19', NULL),
            ('PKL-00540', 'UMT-00540', 'KEL-0178', 'Anak', '2019-02-19', NULL),
            ('PKL-00541', 'UMT-00541', 'KEL-0179', 'Kepala Keluarga', '2008-02-11', NULL),
            ('PKL-00542', 'UMT-00542', 'KEL-0180', 'Kepala Keluarga', '2011-01-08', NULL),
            ('PKL-00543', 'UMT-00543', 'KEL-0180', 'Pasangan', '2011-01-08', NULL),
            ('PKL-00544', 'UMT-00544', 'KEL-0181', 'Kepala Keluarga', '2012-06-28', NULL),
            ('PKL-00545', 'UMT-00545', 'KEL-0181', 'Pasangan', '2012-06-28', NULL),
            ('PKL-00546', 'UMT-00546', 'KEL-0181', 'Anak', '2012-06-28', NULL),
            ('PKL-00547', 'UMT-00547', 'KEL-0182', 'Kepala Keluarga', '2021-03-20', NULL),
            ('PKL-00548', 'UMT-00548', 'KEL-0182', 'Pasangan', '2021-03-20', NULL),
            ('PKL-00549', 'UMT-00549', 'KEL-0183', 'Kepala Keluarga', '2023-03-10', NULL),
            ('PKL-00550', 'UMT-00550', 'KEL-0183', 'Pasangan', '2023-03-10', NULL),
            ('PKL-00551', 'UMT-00551', 'KEL-0183', 'Anak', '2023-03-10', NULL),
            ('PKL-00552', 'UMT-00552', 'KEL-0183', 'Anak', '2023-03-10', NULL),
            ('PKL-00553', 'UMT-00553', 'KEL-0184', 'Kepala Keluarga', '2011-05-02', NULL),
            ('PKL-00554', 'UMT-00554', 'KEL-0184', 'Anak', '2014-06-30', NULL),
            ('PKL-00555', 'UMT-00555', 'KEL-0185', 'Kepala Keluarga', '2024-10-06', NULL),
            ('PKL-00556', 'UMT-00556', 'KEL-0185', 'Pasangan', '2024-10-06', NULL),
            ('PKL-00557', 'UMT-00557', 'KEL-0186', 'Kepala Keluarga', '2018-09-02', NULL),
            ('PKL-00558', 'UMT-00558', 'KEL-0186', 'Pasangan', '2018-09-02', NULL),
            ('PKL-00559', 'UMT-00559', 'KEL-0187', 'Kepala Keluarga', '2023-06-09', '2025-11-16'),
            ('PKL-00560', 'UMT-00560', 'KEL-0187', 'Anak', '2023-06-09', '2025-11-16'),
            ('PKL-00561', 'UMT-00561', 'KEL-0187', 'Anak', '2023-06-09', '2025-11-16'),
            ('PKL-00562', 'UMT-00562', 'KEL-0188', 'Kepala Keluarga', '2018-03-10', NULL),
            ('PKL-00563', 'UMT-00563', 'KEL-0188', 'Pasangan', '2018-03-10', NULL),
            ('PKL-00564', 'UMT-00564', 'KEL-0188', 'Anak', '2018-03-10', NULL),
            ('PKL-00565', 'UMT-00565', 'KEL-0189', 'Kepala Keluarga', '2008-11-05', NULL),
            ('PKL-00566', 'UMT-00566', 'KEL-0189', 'Pasangan', '2008-11-05', NULL),
            ('PKL-00567', 'UMT-00567', 'KEL-0190', 'Kepala Keluarga', '2010-08-20', NULL),
            ('PKL-00568', 'UMT-00568', 'KEL-0190', 'Pasangan', '2010-08-20', NULL),
            ('PKL-00569', 'UMT-00569', 'KEL-0191', 'Kepala Keluarga', '2024-07-03', '2026-03-07'),
            ('PKL-00570', 'UMT-00570', 'KEL-0191', 'Pasangan', '2024-07-03', '2026-03-07'),
            ('PKL-00571', 'UMT-00571', 'KEL-0191', 'Anak', '2024-07-03', '2026-03-07'),
            ('PKL-00572', 'UMT-00572', 'KEL-0191', 'Anak', '2024-07-03', '2026-03-07'),
            ('PKL-00573', 'UMT-00573', 'KEL-0192', 'Kepala Keluarga', '2024-01-05', NULL),
            ('PKL-00574', 'UMT-00574', 'KEL-0192', 'Pasangan', '2024-01-05', '2024-11-14'),
            ('PKL-00575', 'UMT-00575', 'KEL-0193', 'Kepala Keluarga', '2010-02-04', NULL),
            ('PKL-00576', 'UMT-00576', 'KEL-0193', 'Pasangan', '2010-02-04', NULL),
            ('PKL-00577', 'UMT-00577', 'KEL-0194', 'Kepala Keluarga', '2011-01-07', NULL),
            ('PKL-00578', 'UMT-00578', 'KEL-0194', 'Pasangan', '2011-01-07', NULL),
            ('PKL-00579', 'UMT-00579', 'KEL-0194', 'Anak', '2018-06-30', NULL),
            ('PKL-00580', 'UMT-00580', 'KEL-0194', 'Anak', '2012-06-30', NULL),
            ('PKL-00581', 'UMT-00581', 'KEL-0195', 'Kepala Keluarga', '2018-10-01', NULL),
            ('PKL-00582', 'UMT-00582', 'KEL-0195', 'Pasangan', '2018-10-01', NULL),
            ('PKL-00583', 'UMT-00583', 'KEL-0195', 'Anak', '2018-10-01', NULL),
            ('PKL-00584', 'UMT-00584', 'KEL-0195', 'Anak', '2018-10-01', NULL),
            ('PKL-00585', 'UMT-00585', 'KEL-0196', 'Kepala Keluarga', '2022-09-12', NULL),
            ('PKL-00586', 'UMT-00586', 'KEL-0196', 'Pasangan', '2022-09-12', NULL),
            ('PKL-00587', 'UMT-00587', 'KEL-0197', 'Kepala Keluarga', '2020-10-30', NULL),
            ('PKL-00588', 'UMT-00588', 'KEL-0198', 'Kepala Keluarga', '2010-06-30', NULL),
            ('PKL-00589', 'UMT-00589', 'KEL-0198', 'Pasangan', '2010-06-30', NULL),
            ('PKL-00590', 'UMT-00590', 'KEL-0198', 'Anak', '2022-06-30', NULL),
            ('PKL-00591', 'UMT-00591', 'KEL-0198', 'Anak', '2020-06-30', NULL),
            ('PKL-00592', 'UMT-00592', 'KEL-0198', 'Anggota Lain', '2010-06-30', NULL),
            ('PKL-00593', 'UMT-00593', 'KEL-0199', 'Kepala Keluarga', '2015-05-02', NULL),
            ('PKL-00594', 'UMT-00594', 'KEL-0199', 'Pasangan', '2015-05-02', NULL),
            ('PKL-00595', 'UMT-00595', 'KEL-0199', 'Anak', '2015-05-02', NULL),
            ('PKL-00596', 'UMT-00596', 'KEL-0200', 'Kepala Keluarga', '2024-07-13', NULL),
            ('PKL-00597', 'UMT-00597', 'KEL-0200', 'Pasangan', '2024-07-13', NULL),
            ('PKL-00598', 'UMT-00598', 'KEL-0201', 'Kepala Keluarga', '2020-08-08', NULL),
            ('PKL-00599', 'UMT-00599', 'KEL-0202', 'Kepala Keluarga', '2017-03-09', NULL),
            ('PKL-00600', 'UMT-00600', 'KEL-0202', 'Pasangan', '2017-03-09', NULL),
            ('PKL-00601', 'UMT-00601', 'KEL-0202', 'Anak', '2025-06-30', NULL),
            ('PKL-00602', 'UMT-00602', 'KEL-0202', 'Anak', '2017-03-09', NULL),
            ('PKL-00603', 'UMT-00603', 'KEL-0203', 'Kepala Keluarga', '2010-01-27', NULL),
            ('PKL-00604', 'UMT-00604', 'KEL-0203', 'Pasangan', '2010-01-27', NULL),
            ('PKL-00605', 'UMT-00605', 'KEL-0204', 'Kepala Keluarga', '2018-03-24', NULL),
            ('PKL-00606', 'UMT-00606', 'KEL-0204', 'Pasangan', '2018-03-24', NULL),
            ('PKL-00607', 'UMT-00607', 'KEL-0205', 'Kepala Keluarga', '2009-03-13', NULL),
            ('PKL-00608', 'UMT-00608', 'KEL-0206', 'Kepala Keluarga', '2016-01-14', NULL),
            ('PKL-00609', 'UMT-00609', 'KEL-0206', 'Pasangan', '2016-01-14', NULL),
            ('PKL-00610', 'UMT-00610', 'KEL-0206', 'Anak', '2017-06-30', NULL),
            ('PKL-00611', 'UMT-00611', 'KEL-0207', 'Kepala Keluarga', '2013-12-01', NULL),
            ('PKL-00612', 'UMT-00612', 'KEL-0207', 'Pasangan', '2013-12-01', NULL),
            ('PKL-00613', 'UMT-00613', 'KEL-0207', 'Anak', '2024-06-30', NULL),
            ('PKL-00614', 'UMT-00614', 'KEL-0207', 'Anak', '2013-12-01', NULL),
            ('PKL-00615', 'UMT-00615', 'KEL-0208', 'Kepala Keluarga', '2011-10-23', NULL),
            ('PKL-00616', 'UMT-00616', 'KEL-0208', 'Pasangan', '2011-10-23', NULL),
            ('PKL-00617', 'UMT-00617', 'KEL-0209', 'Kepala Keluarga', '2023-05-04', '2026-08-15'),
            ('PKL-00618', 'UMT-00618', 'KEL-0209', 'Pasangan', '2023-05-04', NULL),
            ('PKL-00619', 'UMT-00619', 'KEL-0210', 'Kepala Keluarga', '2023-06-26', NULL),
            ('PKL-00620', 'UMT-00620', 'KEL-0210', 'Pasangan', '2023-06-26', NULL),
            ('PKL-00621', 'UMT-00621', 'KEL-0210', 'Anak', '2023-06-26', NULL),
            ('PKL-00622', 'UMT-00622', 'KEL-0210', 'Anak', '2023-06-26', NULL),
            ('PKL-00623', 'UMT-00623', 'KEL-0210', 'Anggota Lain', '2023-06-26', NULL),
            ('PKL-00624', 'UMT-00624', 'KEL-0211', 'Kepala Keluarga', '2019-07-21', NULL),
            ('PKL-00625', 'UMT-00625', 'KEL-0211', 'Pasangan', '2019-07-21', '2026-01-29'),
            ('PKL-00626', 'UMT-00626', 'KEL-0212', 'Kepala Keluarga', '2013-10-04', NULL),
            ('PKL-00627', 'UMT-00627', 'KEL-0213', 'Kepala Keluarga', '2014-11-23', NULL),
            ('PKL-00628', 'UMT-00628', 'KEL-0213', 'Pasangan', '2014-11-23', NULL),
            ('PKL-00629', 'UMT-00629', 'KEL-0214', 'Kepala Keluarga', '2009-01-17', NULL),
            ('PKL-00630', 'UMT-00630', 'KEL-0214', 'Pasangan', '2009-01-17', NULL),
            ('PKL-00631', 'UMT-00631', 'KEL-0214', 'Anak', '2023-06-30', NULL),
            ('PKL-00632', 'UMT-00632', 'KEL-0214', 'Anak', '2017-06-30', NULL),
            ('PKL-00633', 'UMT-00633', 'KEL-0215', 'Kepala Keluarga', '2015-07-13', NULL),
            ('PKL-00634', 'UMT-00634', 'KEL-0215', 'Pasangan', '2015-07-13', NULL),
            ('PKL-00635', 'UMT-00635', 'KEL-0215', 'Anak', '2018-06-30', NULL),
            ('PKL-00636', 'UMT-00636', 'KEL-0216', 'Kepala Keluarga', '2024-01-29', NULL),
            ('PKL-00637', 'UMT-00637', 'KEL-0216', 'Anak', '2024-01-29', NULL),
            ('PKL-00638', 'UMT-00638', 'KEL-0216', 'Anak', '2024-01-29', NULL),
            ('PKL-00639', 'UMT-00639', 'KEL-0217', 'Kepala Keluarga', '2008-10-08', NULL),
            ('PKL-00640', 'UMT-00640', 'KEL-0217', 'Pasangan', '2008-10-08', NULL),
            ('PKL-00641', 'UMT-00641', 'KEL-0217', 'Anak', '2021-06-30', NULL),
            ('PKL-00642', 'UMT-00642', 'KEL-0217', 'Anak', '2013-06-30', NULL),
            ('PKL-00643', 'UMT-00643', 'KEL-0217', 'Anak', '2020-06-30', NULL),
            ('PKL-00644', 'UMT-00644', 'KEL-0218', 'Kepala Keluarga', '2016-12-25', NULL),
            ('PKL-00645', 'UMT-00645', 'KEL-0218', 'Pasangan', '2016-12-25', NULL),
            ('PKL-00646', 'UMT-00646', 'KEL-0219', 'Kepala Keluarga', '2017-10-22', NULL),
            ('PKL-00647', 'UMT-00647', 'KEL-0219', 'Pasangan', '2017-10-22', NULL),
            ('PKL-00648', 'UMT-00648', 'KEL-0219', 'Anak', '2021-06-30', NULL),
            ('PKL-00649', 'UMT-00649', 'KEL-0219', 'Anak', '2021-06-30', NULL),
            ('PKL-00650', 'UMT-00650', 'KEL-0220', 'Kepala Keluarga', '2024-12-28', NULL),
            ('PKL-00651', 'UMT-00651', 'KEL-0220', 'Pasangan', '2024-12-28', NULL),
            ('PKL-00652', 'UMT-00652', 'KEL-0221', 'Kepala Keluarga', '2023-10-02', NULL),
            ('PKL-00653', 'UMT-00653', 'KEL-0221', 'Pasangan', '2023-10-02', NULL),
            ('PKL-00654', 'UMT-00134', 'KEL-0222', 'Kepala Keluarga', '2024-04-28', NULL),
            ('PKL-00655', 'UMT-00244', 'KEL-0223', 'Kepala Keluarga', '2024-08-27', NULL),
            ('PKL-00656', 'UMT-00481', 'KEL-0224', 'Kepala Keluarga', '2024-04-14', NULL),
            ('PKL-00657', 'UMT-00083', 'KEL-0225', 'Kepala Keluarga', '2025-06-04', NULL),
            ('PKL-00658', 'UMT-00474', 'KEL-0226', 'Kepala Keluarga', '2025-11-17', NULL),
            ('PKL-00659', 'UMT-00252', 'KEL-0227', 'Kepala Keluarga', '2024-08-26', NULL)
    ) AS v (ID_PENUGASAN_KELUARGA, ID_UMAT, ID_KELUARGA, PERAN_DALAM_KELUARGA, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
) AS s
ON t.ID_PENUGASAN_KELUARGA = s.ID_PENUGASAN_KELUARGA
WHEN MATCHED THEN UPDATE SET
    ID_UMAT = s.ID_UMAT,
    ID_KELUARGA = s.ID_KELUARGA,
    PERAN_DALAM_KELUARGA = s.PERAN_DALAM_KELUARGA,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU
WHEN NOT MATCHED THEN INSERT (ID_PENUGASAN_KELUARGA, ID_UMAT, ID_KELUARGA, PERAN_DALAM_KELUARGA, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
    VALUES (s.ID_PENUGASAN_KELUARGA, s.ID_UMAT, s.ID_KELUARGA, s.PERAN_DALAM_KELUARGA, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU);

-- DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN: 237 rows
MERGE INTO DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN AS t
USING (
    SELECT
        v.ID_PENUGASAN_LINGKUNGAN AS ID_PENUGASAN_LINGKUNGAN,
        v.ID_KELUARGA AS ID_KELUARGA,
        v.ID_LINGKUNGAN AS ID_LINGKUNGAN,
        CAST(v.TANGGAL_MULAI_BERLAKU AS DATE) AS TANGGAL_MULAI_BERLAKU,
        CAST(v.TANGGAL_AKHIR_BERLAKU AS DATE) AS TANGGAL_AKHIR_BERLAKU
    FROM (VALUES
            ('PLG-0001', 'KEL-0001', 'LNG-01', '2014-03-28', NULL),
            ('PLG-0002', 'KEL-0002', 'LNG-01', '2013-11-14', NULL),
            ('PLG-0003', 'KEL-0003', 'LNG-01', '2024-04-02', NULL),
            ('PLG-0004', 'KEL-0004', 'LNG-01', '2022-07-17', NULL),
            ('PLG-0005', 'KEL-0005', 'LNG-01', '2011-05-11', NULL),
            ('PLG-0006', 'KEL-0006', 'LNG-01', '2009-04-18', NULL),
            ('PLG-0007', 'KEL-0007', 'LNG-01', '2018-07-13', NULL),
            ('PLG-0008', 'KEL-0008', 'LNG-01', '2022-05-13', NULL),
            ('PLG-0009', 'KEL-0009', 'LNG-01', '2008-11-21', NULL),
            ('PLG-0010', 'KEL-0010', 'LNG-01', '2020-05-03', NULL),
            ('PLG-0011', 'KEL-0011', 'LNG-01', '2021-07-03', NULL),
            ('PLG-0012', 'KEL-0012', 'LNG-01', '2019-09-05', NULL),
            ('PLG-0013', 'KEL-0013', 'LNG-02', '2023-02-01', NULL),
            ('PLG-0014', 'KEL-0014', 'LNG-02', '2016-03-10', NULL),
            ('PLG-0015', 'KEL-0015', 'LNG-02', '2015-02-11', NULL),
            ('PLG-0016', 'KEL-0016', 'LNG-02', '2013-04-09', NULL),
            ('PLG-0017', 'KEL-0017', 'LNG-02', '2019-08-31', NULL),
            ('PLG-0018', 'KEL-0018', 'LNG-02', '2015-05-21', NULL),
            ('PLG-0019', 'KEL-0019', 'LNG-02', '2016-05-29', NULL),
            ('PLG-0020', 'KEL-0020', 'LNG-02', '2017-04-07', NULL),
            ('PLG-0021', 'KEL-0021', 'LNG-02', '2020-07-28', NULL),
            ('PLG-0022', 'KEL-0022', 'LNG-02', '2008-11-09', '2026-04-29'),
            ('PLG-0023', 'KEL-0023', 'LNG-02', '2015-08-29', NULL),
            ('PLG-0024', 'KEL-0024', 'LNG-02', '2016-03-11', '2026-08-20'),
            ('PLG-0025', 'KEL-0025', 'LNG-02', '2021-11-16', NULL),
            ('PLG-0026', 'KEL-0026', 'LNG-02', '2025-01-27', NULL),
            ('PLG-0027', 'KEL-0027', 'LNG-02', '2009-02-15', NULL),
            ('PLG-0028', 'KEL-0028', 'LNG-19', '2021-07-24', '2024-12-31'),
            ('PLG-0029', 'KEL-0029', 'LNG-19', '2021-12-05', '2024-12-31'),
            ('PLG-0030', 'KEL-0030', 'LNG-19', '2023-07-17', '2024-12-31'),
            ('PLG-0031', 'KEL-0031', 'LNG-19', '2015-06-27', '2024-12-31'),
            ('PLG-0032', 'KEL-0032', 'LNG-19', '2014-12-25', '2024-12-31'),
            ('PLG-0033', 'KEL-0033', 'LNG-19', '2013-11-23', '2024-12-31'),
            ('PLG-0034', 'KEL-0034', 'LNG-03', '2020-09-16', NULL),
            ('PLG-0035', 'KEL-0035', 'LNG-03', '2019-09-10', NULL),
            ('PLG-0036', 'KEL-0036', 'LNG-03', '2018-03-16', NULL),
            ('PLG-0037', 'KEL-0037', 'LNG-03', '2020-11-25', NULL),
            ('PLG-0038', 'KEL-0038', 'LNG-03', '2008-10-12', NULL),
            ('PLG-0039', 'KEL-0039', 'LNG-03', '2016-10-23', NULL),
            ('PLG-0040', 'KEL-0040', 'LNG-03', '2024-03-18', NULL),
            ('PLG-0041', 'KEL-0041', 'LNG-04', '2016-03-06', NULL),
            ('PLG-0042', 'KEL-0042', 'LNG-04', '2009-01-08', NULL),
            ('PLG-0043', 'KEL-0043', 'LNG-04', '2018-03-15', NULL),
            ('PLG-0044', 'KEL-0044', 'LNG-04', '2016-06-19', NULL),
            ('PLG-0045', 'KEL-0045', 'LNG-04', '2019-05-18', NULL),
            ('PLG-0046', 'KEL-0046', 'LNG-04', '2019-12-13', NULL),
            ('PLG-0047', 'KEL-0047', 'LNG-04', '2023-07-23', NULL),
            ('PLG-0048', 'KEL-0048', 'LNG-04', '2017-08-25', NULL),
            ('PLG-0049', 'KEL-0049', 'LNG-04', '2015-03-15', NULL),
            ('PLG-0050', 'KEL-0050', 'LNG-04', '2022-06-11', NULL),
            ('PLG-0051', 'KEL-0051', 'LNG-04', '2011-01-15', NULL),
            ('PLG-0052', 'KEL-0052', 'LNG-04', '2012-01-30', NULL),
            ('PLG-0053', 'KEL-0053', 'LNG-04', '2017-09-05', NULL),
            ('PLG-0054', 'KEL-0054', 'LNG-05', '2014-09-13', NULL),
            ('PLG-0055', 'KEL-0055', 'LNG-05', '2020-07-18', NULL),
            ('PLG-0056', 'KEL-0056', 'LNG-05', '2010-09-15', NULL),
            ('PLG-0057', 'KEL-0057', 'LNG-05', '2024-07-15', NULL),
            ('PLG-0058', 'KEL-0058', 'LNG-05', '2024-03-02', NULL),
            ('PLG-0059', 'KEL-0059', 'LNG-05', '2009-10-22', NULL),
            ('PLG-0060', 'KEL-0060', 'LNG-05', '2016-11-10', NULL),
            ('PLG-0061', 'KEL-0061', 'LNG-05', '2009-11-05', NULL),
            ('PLG-0062', 'KEL-0062', 'LNG-05', '2014-02-27', NULL),
            ('PLG-0063', 'KEL-0063', 'LNG-05', '2017-05-23', NULL),
            ('PLG-0064', 'KEL-0064', 'LNG-06', '2017-03-19', NULL),
            ('PLG-0065', 'KEL-0065', 'LNG-06', '2020-01-28', NULL),
            ('PLG-0066', 'KEL-0066', 'LNG-06', '2016-03-06', NULL),
            ('PLG-0067', 'KEL-0067', 'LNG-06', '2016-04-11', NULL),
            ('PLG-0068', 'KEL-0068', 'LNG-06', '2013-06-22', NULL),
            ('PLG-0069', 'KEL-0069', 'LNG-06', '2016-05-03', NULL),
            ('PLG-0070', 'KEL-0070', 'LNG-06', '2019-04-03', NULL),
            ('PLG-0071', 'KEL-0071', 'LNG-06', '2022-02-09', NULL),
            ('PLG-0072', 'KEL-0072', 'LNG-06', '2011-06-18', NULL),
            ('PLG-0073', 'KEL-0073', 'LNG-06', '2012-11-15', NULL),
            ('PLG-0074', 'KEL-0074', 'LNG-06', '2013-11-06', NULL),
            ('PLG-0075', 'KEL-0075', 'LNG-06', '2020-08-08', NULL),
            ('PLG-0076', 'KEL-0076', 'LNG-07', '2009-12-20', NULL),
            ('PLG-0077', 'KEL-0077', 'LNG-07', '2020-03-10', NULL),
            ('PLG-0078', 'KEL-0078', 'LNG-07', '2018-07-04', NULL),
            ('PLG-0079', 'KEL-0079', 'LNG-07', '2010-07-11', NULL),
            ('PLG-0080', 'KEL-0080', 'LNG-07', '2019-06-08', NULL),
            ('PLG-0081', 'KEL-0081', 'LNG-07', '2022-01-09', NULL),
            ('PLG-0082', 'KEL-0082', 'LNG-07', '2019-05-09', NULL),
            ('PLG-0083', 'KEL-0083', 'LNG-07', '2015-07-12', NULL),
            ('PLG-0084', 'KEL-0084', 'LNG-07', '2011-06-23', NULL),
            ('PLG-0085', 'KEL-0085', 'LNG-07', '2017-03-15', NULL),
            ('PLG-0086', 'KEL-0086', 'LNG-08', '2020-10-28', NULL),
            ('PLG-0087', 'KEL-0087', 'LNG-08', '2020-12-01', NULL),
            ('PLG-0088', 'KEL-0088', 'LNG-08', '2012-01-07', NULL),
            ('PLG-0089', 'KEL-0089', 'LNG-08', '2019-10-06', NULL),
            ('PLG-0090', 'KEL-0090', 'LNG-08', '2019-05-26', NULL),
            ('PLG-0091', 'KEL-0091', 'LNG-08', '2021-01-23', NULL),
            ('PLG-0092', 'KEL-0092', 'LNG-08', '2012-11-30', NULL),
            ('PLG-0093', 'KEL-0093', 'LNG-08', '2014-03-12', NULL),
            ('PLG-0094', 'KEL-0094', 'LNG-08', '2015-05-24', NULL),
            ('PLG-0095', 'KEL-0095', 'LNG-08', '2021-03-13', NULL),
            ('PLG-0096', 'KEL-0096', 'LNG-08', '2009-03-21', NULL),
            ('PLG-0097', 'KEL-0097', 'LNG-08', '2021-04-03', NULL),
            ('PLG-0098', 'KEL-0098', 'LNG-08', '2024-05-02', NULL),
            ('PLG-0099', 'KEL-0099', 'LNG-08', '2021-06-13', NULL),
            ('PLG-0100', 'KEL-0100', 'LNG-08', '2015-04-30', NULL),
            ('PLG-0101', 'KEL-0101', 'LNG-09', '2016-07-02', NULL),
            ('PLG-0102', 'KEL-0102', 'LNG-09', '2013-01-29', NULL),
            ('PLG-0103', 'KEL-0103', 'LNG-09', '2011-10-14', NULL),
            ('PLG-0104', 'KEL-0104', 'LNG-09', '2015-06-30', NULL),
            ('PLG-0105', 'KEL-0105', 'LNG-09', '2011-02-01', NULL),
            ('PLG-0106', 'KEL-0106', 'LNG-09', '2008-06-21', NULL),
            ('PLG-0107', 'KEL-0107', 'LNG-09', '2016-03-25', NULL),
            ('PLG-0108', 'KEL-0108', 'LNG-09', '2020-09-11', NULL),
            ('PLG-0109', 'KEL-0109', 'LNG-09', '2012-04-28', NULL),
            ('PLG-0110', 'KEL-0110', 'LNG-09', '2012-06-13', NULL),
            ('PLG-0111', 'KEL-0111', 'LNG-09', '2013-06-13', NULL),
            ('PLG-0112', 'KEL-0112', 'LNG-10', '2010-08-04', NULL),
            ('PLG-0113', 'KEL-0113', 'LNG-10', '2021-11-13', NULL),
            ('PLG-0114', 'KEL-0114', 'LNG-10', '2020-05-16', NULL),
            ('PLG-0115', 'KEL-0115', 'LNG-10', '2021-02-23', NULL),
            ('PLG-0116', 'KEL-0116', 'LNG-10', '2020-11-09', NULL),
            ('PLG-0117', 'KEL-0117', 'LNG-10', '2024-10-12', NULL),
            ('PLG-0118', 'KEL-0118', 'LNG-10', '2017-02-03', NULL),
            ('PLG-0119', 'KEL-0119', 'LNG-10', '2020-04-28', NULL),
            ('PLG-0120', 'KEL-0120', 'LNG-10', '2021-07-01', NULL),
            ('PLG-0121', 'KEL-0121', 'LNG-10', '2024-10-27', NULL),
            ('PLG-0122', 'KEL-0122', 'LNG-11', '2024-04-27', NULL),
            ('PLG-0123', 'KEL-0123', 'LNG-11', '2012-10-23', NULL),
            ('PLG-0124', 'KEL-0124', 'LNG-11', '2016-06-08', NULL),
            ('PLG-0125', 'KEL-0125', 'LNG-11', '2010-04-06', '2026-04-05'),
            ('PLG-0126', 'KEL-0126', 'LNG-11', '2022-10-06', NULL),
            ('PLG-0127', 'KEL-0127', 'LNG-11', '2020-03-23', NULL),
            ('PLG-0128', 'KEL-0128', 'LNG-11', '2011-10-30', NULL),
            ('PLG-0129', 'KEL-0129', 'LNG-11', '2010-09-16', NULL),
            ('PLG-0130', 'KEL-0130', 'LNG-11', '2025-03-09', NULL),
            ('PLG-0131', 'KEL-0131', 'LNG-11', '2012-12-09', NULL),
            ('PLG-0132', 'KEL-0132', 'LNG-11', '2008-06-03', NULL),
            ('PLG-0133', 'KEL-0133', 'LNG-11', '2008-12-14', NULL),
            ('PLG-0134', 'KEL-0134', 'LNG-11', '2008-06-21', NULL),
            ('PLG-0135', 'KEL-0135', 'LNG-11', '2018-11-10', NULL),
            ('PLG-0136', 'KEL-0136', 'LNG-11', '2021-01-06', NULL),
            ('PLG-0137', 'KEL-0137', 'LNG-12', '2023-04-30', NULL),
            ('PLG-0138', 'KEL-0138', 'LNG-12', '2014-10-03', NULL),
            ('PLG-0139', 'KEL-0139', 'LNG-12', '2014-01-26', NULL),
            ('PLG-0140', 'KEL-0140', 'LNG-12', '2017-06-21', NULL),
            ('PLG-0141', 'KEL-0141', 'LNG-12', '2008-05-01', NULL),
            ('PLG-0142', 'KEL-0142', 'LNG-12', '2024-02-07', NULL),
            ('PLG-0143', 'KEL-0143', 'LNG-12', '2016-02-17', NULL),
            ('PLG-0144', 'KEL-0144', 'LNG-12', '2015-12-06', NULL),
            ('PLG-0145', 'KEL-0145', 'LNG-12', '2013-07-20', NULL),
            ('PLG-0146', 'KEL-0146', 'LNG-12', '2008-11-20', NULL),
            ('PLG-0147', 'KEL-0147', 'LNG-13', '2025-04-21', NULL),
            ('PLG-0148', 'KEL-0148', 'LNG-13', '2016-09-17', NULL),
            ('PLG-0149', 'KEL-0149', 'LNG-13', '2012-02-27', NULL),
            ('PLG-0150', 'KEL-0150', 'LNG-13', '2020-03-12', NULL),
            ('PLG-0151', 'KEL-0151', 'LNG-13', '2021-05-13', NULL),
            ('PLG-0152', 'KEL-0152', 'LNG-13', '2020-06-21', NULL),
            ('PLG-0153', 'KEL-0153', 'LNG-13', '2022-11-02', NULL),
            ('PLG-0154', 'KEL-0154', 'LNG-13', '2014-11-26', NULL),
            ('PLG-0155', 'KEL-0155', 'LNG-13', '2011-01-13', NULL),
            ('PLG-0156', 'KEL-0156', 'LNG-13', '2023-09-10', NULL),
            ('PLG-0157', 'KEL-0157', 'LNG-13', '2010-06-10', NULL),
            ('PLG-0158', 'KEL-0158', 'LNG-14', '2021-07-01', NULL),
            ('PLG-0159', 'KEL-0159', 'LNG-14', '2018-04-07', NULL),
            ('PLG-0160', 'KEL-0160', 'LNG-14', '2024-06-17', '2025-06-26'),
            ('PLG-0161', 'KEL-0161', 'LNG-14', '2025-06-20', NULL),
            ('PLG-0162', 'KEL-0162', 'LNG-14', '2018-08-19', '2026-01-22'),
            ('PLG-0163', 'KEL-0163', 'LNG-14', '2017-09-20', NULL),
            ('PLG-0164', 'KEL-0164', 'LNG-14', '2011-08-20', NULL),
            ('PLG-0165', 'KEL-0165', 'LNG-14', '2023-02-18', NULL),
            ('PLG-0166', 'KEL-0166', 'LNG-14', '2020-10-29', NULL),
            ('PLG-0167', 'KEL-0167', 'LNG-14', '2015-12-03', NULL),
            ('PLG-0168', 'KEL-0168', 'LNG-14', '2021-05-29', NULL),
            ('PLG-0169', 'KEL-0169', 'LNG-14', '2008-03-12', NULL),
            ('PLG-0170', 'KEL-0170', 'LNG-14', '2009-11-09', NULL),
            ('PLG-0171', 'KEL-0171', 'LNG-15', '2021-10-24', NULL),
            ('PLG-0172', 'KEL-0172', 'LNG-15', '2009-07-03', NULL),
            ('PLG-0173', 'KEL-0173', 'LNG-15', '2009-08-12', NULL),
            ('PLG-0174', 'KEL-0174', 'LNG-15', '2010-02-01', '2026-06-25'),
            ('PLG-0175', 'KEL-0175', 'LNG-15', '2018-03-15', '2025-02-09'),
            ('PLG-0176', 'KEL-0176', 'LNG-15', '2021-02-06', '2025-05-25'),
            ('PLG-0177', 'KEL-0177', 'LNG-15', '2013-06-15', NULL),
            ('PLG-0178', 'KEL-0178', 'LNG-15', '2019-02-19', NULL),
            ('PLG-0179', 'KEL-0179', 'LNG-15', '2008-02-11', NULL),
            ('PLG-0180', 'KEL-0180', 'LNG-15', '2011-01-08', NULL),
            ('PLG-0181', 'KEL-0181', 'LNG-15', '2012-06-28', NULL),
            ('PLG-0182', 'KEL-0182', 'LNG-15', '2021-03-20', NULL),
            ('PLG-0183', 'KEL-0183', 'LNG-15', '2023-03-10', NULL),
            ('PLG-0184', 'KEL-0184', 'LNG-16', '2011-05-02', NULL),
            ('PLG-0185', 'KEL-0185', 'LNG-16', '2024-10-06', NULL),
            ('PLG-0186', 'KEL-0186', 'LNG-16', '2018-09-02', NULL),
            ('PLG-0187', 'KEL-0187', 'LNG-16', '2023-06-09', '2025-11-16'),
            ('PLG-0188', 'KEL-0188', 'LNG-16', '2018-03-10', NULL),
            ('PLG-0189', 'KEL-0189', 'LNG-16', '2008-11-05', NULL),
            ('PLG-0190', 'KEL-0190', 'LNG-16', '2010-08-20', NULL),
            ('PLG-0191', 'KEL-0191', 'LNG-16', '2024-07-03', '2026-03-07'),
            ('PLG-0192', 'KEL-0192', 'LNG-16', '2024-01-05', NULL),
            ('PLG-0193', 'KEL-0193', 'LNG-16', '2010-02-04', NULL),
            ('PLG-0194', 'KEL-0194', 'LNG-16', '2011-01-07', NULL),
            ('PLG-0195', 'KEL-0195', 'LNG-16', '2018-10-01', NULL),
            ('PLG-0196', 'KEL-0196', 'LNG-16', '2022-09-12', NULL),
            ('PLG-0197', 'KEL-0197', 'LNG-17', '2020-10-30', NULL),
            ('PLG-0198', 'KEL-0198', 'LNG-17', '2010-06-30', NULL),
            ('PLG-0199', 'KEL-0199', 'LNG-17', '2015-05-02', NULL),
            ('PLG-0200', 'KEL-0200', 'LNG-17', '2024-07-13', NULL),
            ('PLG-0201', 'KEL-0201', 'LNG-17', '2020-08-08', NULL),
            ('PLG-0202', 'KEL-0202', 'LNG-17', '2017-03-09', NULL),
            ('PLG-0203', 'KEL-0203', 'LNG-17', '2010-01-27', NULL),
            ('PLG-0204', 'KEL-0204', 'LNG-17', '2018-03-24', NULL),
            ('PLG-0205', 'KEL-0205', 'LNG-17', '2009-03-13', NULL),
            ('PLG-0206', 'KEL-0206', 'LNG-17', '2016-01-14', NULL),
            ('PLG-0207', 'KEL-0207', 'LNG-17', '2013-12-01', NULL),
            ('PLG-0208', 'KEL-0208', 'LNG-17', '2011-10-23', NULL),
            ('PLG-0209', 'KEL-0209', 'LNG-17', '2023-05-04', NULL),
            ('PLG-0210', 'KEL-0210', 'LNG-17', '2023-06-26', NULL),
            ('PLG-0211', 'KEL-0211', 'LNG-18', '2019-07-21', NULL),
            ('PLG-0212', 'KEL-0212', 'LNG-18', '2013-10-04', NULL),
            ('PLG-0213', 'KEL-0213', 'LNG-18', '2014-11-23', NULL),
            ('PLG-0214', 'KEL-0214', 'LNG-18', '2009-01-17', NULL),
            ('PLG-0215', 'KEL-0215', 'LNG-18', '2015-07-13', NULL),
            ('PLG-0216', 'KEL-0216', 'LNG-18', '2024-01-29', NULL),
            ('PLG-0217', 'KEL-0217', 'LNG-18', '2008-10-08', NULL),
            ('PLG-0218', 'KEL-0218', 'LNG-18', '2016-12-25', NULL),
            ('PLG-0219', 'KEL-0219', 'LNG-18', '2017-10-22', NULL),
            ('PLG-0220', 'KEL-0220', 'LNG-18', '2024-12-28', NULL),
            ('PLG-0221', 'KEL-0221', 'LNG-18', '2023-10-02', NULL),
            ('PLG-0222', 'KEL-0028', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0223', 'KEL-0029', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0224', 'KEL-0030', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0225', 'KEL-0031', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0226', 'KEL-0032', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0227', 'KEL-0033', 'LNG-03', '2025-01-01', NULL),
            ('PLG-0228', 'KEL-0162', 'LNG-04', '2026-01-23', NULL),
            ('PLG-0229', 'KEL-0175', 'LNG-06', '2025-02-10', NULL),
            ('PLG-0230', 'KEL-0174', 'LNG-02', '2026-06-26', NULL),
            ('PLG-0231', 'KEL-0125', 'LNG-15', '2026-04-06', NULL),
            ('PLG-0232', 'KEL-0222', 'LNG-04', '2024-04-28', NULL),
            ('PLG-0233', 'KEL-0223', 'LNG-07', '2024-08-27', NULL),
            ('PLG-0234', 'KEL-0224', 'LNG-14', '2024-04-14', NULL),
            ('PLG-0235', 'KEL-0225', 'LNG-02', '2025-06-04', NULL),
            ('PLG-0236', 'KEL-0226', 'LNG-13', '2025-11-17', NULL),
            ('PLG-0237', 'KEL-0227', 'LNG-07', '2024-08-26', NULL)
    ) AS v (ID_PENUGASAN_LINGKUNGAN, ID_KELUARGA, ID_LINGKUNGAN, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
) AS s
ON t.ID_PENUGASAN_LINGKUNGAN = s.ID_PENUGASAN_LINGKUNGAN
WHEN MATCHED THEN UPDATE SET
    ID_KELUARGA = s.ID_KELUARGA,
    ID_LINGKUNGAN = s.ID_LINGKUNGAN,
    TANGGAL_MULAI_BERLAKU = s.TANGGAL_MULAI_BERLAKU,
    TANGGAL_AKHIR_BERLAKU = s.TANGGAL_AKHIR_BERLAKU
WHEN NOT MATCHED THEN INSERT (ID_PENUGASAN_LINGKUNGAN, ID_KELUARGA, ID_LINGKUNGAN, TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU)
    VALUES (s.ID_PENUGASAN_LINGKUNGAN, s.ID_KELUARGA, s.ID_LINGKUNGAN, s.TANGGAL_MULAI_BERLAKU, s.TANGGAL_AKHIR_BERLAKU);

-- DATA_OPERASIONAL.RESPONDEN_SURVEI: 214 rows
MERGE INTO DATA_OPERASIONAL.RESPONDEN_SURVEI AS t
USING (
    SELECT
        v.ID_RESPONDEN AS ID_RESPONDEN,
        v.ID_SURVEI AS ID_SURVEI,
        v.KELOMPOK_USIA AS KELOMPOK_USIA,
        v.ID_WILAYAH AS ID_WILAYAH,
        CAST(v.TANGGAL_PENGISIAN AS DATE) AS TANGGAL_PENGISIAN
    FROM (VALUES
            ('RSP-0001', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-29'),
            ('RSP-0002', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-10'),
            ('RSP-0003', 'SRV-01', '35-65 tahun', 'WIL-06', '2026-05-17'),
            ('RSP-0004', 'SRV-01', '17-34 tahun', 'WIL-02', '2026-05-06'),
            ('RSP-0005', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-06'),
            ('RSP-0006', 'SRV-01', 'Di atas 65 tahun', 'WIL-06', '2026-05-20'),
            ('RSP-0007', 'SRV-01', 'Di atas 65 tahun', 'WIL-03', '2026-05-08'),
            ('RSP-0008', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-04'),
            ('RSP-0009', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-02'),
            ('RSP-0010', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-01'),
            ('RSP-0011', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-03'),
            ('RSP-0012', 'SRV-01', '35-65 tahun', 'WIL-02', '2026-05-19'),
            ('RSP-0013', 'SRV-01', 'Di atas 65 tahun', 'WIL-06', '2026-05-29'),
            ('RSP-0014', 'SRV-01', '17-34 tahun', 'WIL-01', '2026-05-10'),
            ('RSP-0015', 'SRV-01', 'Di atas 65 tahun', 'WIL-01', '2026-05-13'),
            ('RSP-0016', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-27'),
            ('RSP-0017', 'SRV-01', '35-65 tahun', 'WIL-02', '2026-05-19'),
            ('RSP-0018', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-11'),
            ('RSP-0019', 'SRV-01', '17-34 tahun', 'WIL-03', '2026-05-06'),
            ('RSP-0020', 'SRV-01', 'Di bawah 17 tahun', 'WIL-06', '2026-05-16'),
            ('RSP-0021', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-05'),
            ('RSP-0022', 'SRV-01', 'Di atas 65 tahun', 'WIL-05', '2026-05-15'),
            ('RSP-0023', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-10'),
            ('RSP-0024', 'SRV-01', '17-34 tahun', 'WIL-04', '2026-05-09'),
            ('RSP-0025', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-25'),
            ('RSP-0026', 'SRV-01', 'Di atas 65 tahun', 'WIL-06', '2026-05-20'),
            ('RSP-0027', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-19'),
            ('RSP-0028', 'SRV-01', '17-34 tahun', 'WIL-03', '2026-05-30'),
            ('RSP-0029', 'SRV-01', '17-34 tahun', 'WIL-03', '2026-05-20'),
            ('RSP-0030', 'SRV-01', 'Di atas 65 tahun', 'WIL-05', '2026-05-02'),
            ('RSP-0031', 'SRV-01', '17-34 tahun', 'WIL-02', '2026-05-15'),
            ('RSP-0032', 'SRV-01', 'Di bawah 17 tahun', 'WIL-03', '2026-05-18'),
            ('RSP-0033', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-15'),
            ('RSP-0034', 'SRV-01', '17-34 tahun', 'WIL-05', '2026-05-22'),
            ('RSP-0035', 'SRV-01', 'Di atas 65 tahun', 'WIL-06', '2026-05-08'),
            ('RSP-0036', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-25'),
            ('RSP-0037', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-27'),
            ('RSP-0038', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-05'),
            ('RSP-0039', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-09'),
            ('RSP-0040', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-20'),
            ('RSP-0041', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-30'),
            ('RSP-0042', 'SRV-01', 'Di atas 65 tahun', 'WIL-01', '2026-05-08'),
            ('RSP-0043', 'SRV-01', '17-34 tahun', 'WIL-03', '2026-05-10'),
            ('RSP-0044', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-08'),
            ('RSP-0045', 'SRV-01', 'Di atas 65 tahun', 'WIL-01', '2026-05-01'),
            ('RSP-0046', 'SRV-01', 'Di atas 65 tahun', 'WIL-05', '2026-05-09'),
            ('RSP-0047', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-09'),
            ('RSP-0048', 'SRV-01', '17-34 tahun', 'WIL-05', '2026-05-14'),
            ('RSP-0049', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-02'),
            ('RSP-0050', 'SRV-01', '35-65 tahun', 'WIL-02', '2026-05-09'),
            ('RSP-0051', 'SRV-01', '35-65 tahun', 'WIL-06', '2026-05-29'),
            ('RSP-0052', 'SRV-01', 'Di atas 65 tahun', 'WIL-03', '2026-05-04'),
            ('RSP-0053', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-28'),
            ('RSP-0054', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-28'),
            ('RSP-0055', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-24'),
            ('RSP-0056', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-28'),
            ('RSP-0057', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-06'),
            ('RSP-0058', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-29'),
            ('RSP-0059', 'SRV-01', '17-34 tahun', 'WIL-02', '2026-05-16'),
            ('RSP-0060', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-23'),
            ('RSP-0061', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-26'),
            ('RSP-0062', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-12'),
            ('RSP-0063', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-06'),
            ('RSP-0064', 'SRV-01', '35-65 tahun', 'WIL-06', '2026-05-15'),
            ('RSP-0065', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-03'),
            ('RSP-0066', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-18'),
            ('RSP-0067', 'SRV-01', '35-65 tahun', 'WIL-05', '2026-05-07'),
            ('RSP-0068', 'SRV-01', '17-34 tahun', 'WIL-05', '2026-05-13'),
            ('RSP-0069', 'SRV-01', '35-65 tahun', 'WIL-01', '2026-05-15'),
            ('RSP-0070', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-02'),
            ('RSP-0071', 'SRV-01', '17-34 tahun', 'WIL-03', '2026-05-15'),
            ('RSP-0072', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-11'),
            ('RSP-0073', 'SRV-01', '17-34 tahun', 'WIL-01', '2026-05-10'),
            ('RSP-0074', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-28'),
            ('RSP-0075', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-14'),
            ('RSP-0076', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-28'),
            ('RSP-0077', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-06'),
            ('RSP-0078', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-26'),
            ('RSP-0079', 'SRV-01', '35-65 tahun', 'WIL-03', '2026-05-23'),
            ('RSP-0080', 'SRV-01', '17-34 tahun', 'WIL-01', '2026-05-30'),
            ('RSP-0081', 'SRV-01', '17-34 tahun', 'WIL-04', '2026-05-05'),
            ('RSP-0082', 'SRV-01', '17-34 tahun', 'WIL-06', '2026-05-01'),
            ('RSP-0083', 'SRV-01', '35-65 tahun', 'WIL-04', '2026-05-23'),
            ('RSP-0084', 'SRV-01', 'Di atas 65 tahun', 'WIL-04', '2026-05-03'),
            ('RSP-0085', 'SRV-02', '17-34 tahun', 'WIL-02', '2026-06-26'),
            ('RSP-0086', 'SRV-02', '35-65 tahun', 'WIL-02', '2026-07-11'),
            ('RSP-0087', 'SRV-02', '17-34 tahun', 'WIL-03', '2026-07-01'),
            ('RSP-0088', 'SRV-02', '35-65 tahun', 'WIL-04', '2026-06-28'),
            ('RSP-0089', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-06-24'),
            ('RSP-0090', 'SRV-02', 'Di bawah 17 tahun', 'WIL-06', '2026-06-30'),
            ('RSP-0091', 'SRV-02', 'Di atas 65 tahun', 'WIL-03', '2026-06-17'),
            ('RSP-0092', 'SRV-02', '35-65 tahun', 'WIL-04', '2026-06-20'),
            ('RSP-0093', 'SRV-02', '35-65 tahun', 'WIL-03', '2026-06-18'),
            ('RSP-0094', 'SRV-02', '35-65 tahun', 'WIL-02', '2026-07-07'),
            ('RSP-0095', 'SRV-02', '17-34 tahun', 'WIL-05', '2026-06-27'),
            ('RSP-0096', 'SRV-02', '17-34 tahun', 'WIL-05', '2026-06-18'),
            ('RSP-0097', 'SRV-02', 'Di bawah 17 tahun', 'WIL-05', '2026-06-23'),
            ('RSP-0098', 'SRV-02', 'Di atas 65 tahun', 'WIL-02', '2026-06-29'),
            ('RSP-0099', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-07-13'),
            ('RSP-0100', 'SRV-02', '17-34 tahun', 'WIL-05', '2026-06-16'),
            ('RSP-0101', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-06-27'),
            ('RSP-0102', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-07-03'),
            ('RSP-0103', 'SRV-02', '17-34 tahun', 'WIL-02', '2026-06-18'),
            ('RSP-0104', 'SRV-02', '17-34 tahun', 'WIL-02', '2026-07-08'),
            ('RSP-0105', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-07-14'),
            ('RSP-0106', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-07-12'),
            ('RSP-0107', 'SRV-02', '17-34 tahun', 'WIL-05', '2026-07-02'),
            ('RSP-0108', 'SRV-02', 'Di atas 65 tahun', 'WIL-03', '2026-07-08'),
            ('RSP-0109', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-07-04'),
            ('RSP-0110', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-07-01'),
            ('RSP-0111', 'SRV-02', '35-65 tahun', 'WIL-03', '2026-07-14'),
            ('RSP-0112', 'SRV-02', '35-65 tahun', 'WIL-03', '2026-07-14'),
            ('RSP-0113', 'SRV-02', '17-34 tahun', 'WIL-05', '2026-06-20'),
            ('RSP-0114', 'SRV-02', '17-34 tahun', 'WIL-06', '2026-07-02'),
            ('RSP-0115', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-07-03'),
            ('RSP-0116', 'SRV-02', '17-34 tahun', 'WIL-03', '2026-07-11'),
            ('RSP-0117', 'SRV-02', '17-34 tahun', 'WIL-03', '2026-07-15'),
            ('RSP-0118', 'SRV-02', 'Di atas 65 tahun', 'WIL-02', '2026-07-12'),
            ('RSP-0119', 'SRV-02', 'Di atas 65 tahun', 'WIL-05', '2026-07-14'),
            ('RSP-0120', 'SRV-02', 'Di bawah 17 tahun', 'WIL-06', '2026-06-27'),
            ('RSP-0121', 'SRV-02', '35-65 tahun', 'WIL-02', '2026-07-09'),
            ('RSP-0122', 'SRV-02', '35-65 tahun', 'WIL-02', '2026-06-30'),
            ('RSP-0123', 'SRV-02', '35-65 tahun', 'WIL-02', '2026-07-01'),
            ('RSP-0124', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-06-25'),
            ('RSP-0125', 'SRV-02', '35-65 tahun', 'WIL-06', '2026-06-25'),
            ('RSP-0126', 'SRV-02', 'Di atas 65 tahun', 'WIL-04', '2026-06-29'),
            ('RSP-0127', 'SRV-02', 'Di atas 65 tahun', 'WIL-06', '2026-07-04'),
            ('RSP-0128', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-07-12'),
            ('RSP-0129', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-07-12'),
            ('RSP-0130', 'SRV-02', 'Di atas 65 tahun', 'WIL-05', '2026-06-26'),
            ('RSP-0131', 'SRV-02', 'Di atas 65 tahun', 'WIL-03', '2026-06-22'),
            ('RSP-0132', 'SRV-02', '17-34 tahun', 'WIL-03', '2026-06-15'),
            ('RSP-0133', 'SRV-02', '35-65 tahun', 'WIL-03', '2026-07-11'),
            ('RSP-0134', 'SRV-02', '35-65 tahun', 'WIL-01', '2026-06-19'),
            ('RSP-0135', 'SRV-02', 'Di atas 65 tahun', 'WIL-04', '2026-07-09'),
            ('RSP-0136', 'SRV-02', 'Di atas 65 tahun', 'WIL-02', '2026-07-07'),
            ('RSP-0137', 'SRV-02', '35-65 tahun', 'WIL-04', '2026-07-05'),
            ('RSP-0138', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-07-05'),
            ('RSP-0139', 'SRV-02', '17-34 tahun', 'WIL-02', '2026-06-29'),
            ('RSP-0140', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-07-02'),
            ('RSP-0141', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-06-23'),
            ('RSP-0142', 'SRV-02', '17-34 tahun', 'WIL-02', '2026-06-16'),
            ('RSP-0143', 'SRV-02', 'Di atas 65 tahun', 'WIL-03', '2026-07-11'),
            ('RSP-0144', 'SRV-02', 'Di bawah 17 tahun', 'WIL-02', '2026-06-15'),
            ('RSP-0145', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-07-14'),
            ('RSP-0146', 'SRV-02', 'Di atas 65 tahun', 'WIL-03', '2026-07-15'),
            ('RSP-0147', 'SRV-02', '17-34 tahun', 'WIL-06', '2026-06-28'),
            ('RSP-0148', 'SRV-02', '35-65 tahun', 'WIL-06', '2026-07-06'),
            ('RSP-0149', 'SRV-02', '17-34 tahun', 'WIL-01', '2026-06-29'),
            ('RSP-0150', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-07-09'),
            ('RSP-0151', 'SRV-02', '35-65 tahun', 'WIL-06', '2026-07-04'),
            ('RSP-0152', 'SRV-02', '17-34 tahun', 'WIL-06', '2026-07-01'),
            ('RSP-0153', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-06-21'),
            ('RSP-0154', 'SRV-02', 'Di bawah 17 tahun', 'WIL-04', '2026-07-11'),
            ('RSP-0155', 'SRV-02', '35-65 tahun', 'WIL-05', '2026-07-06'),
            ('RSP-0156', 'SRV-02', '35-65 tahun', 'WIL-06', '2026-07-10'),
            ('RSP-0157', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-29'),
            ('RSP-0158', 'SRV-03', '35-65 tahun', 'WIL-05', '2026-08-20'),
            ('RSP-0159', 'SRV-03', 'Di atas 65 tahun', 'WIL-04', '2026-09-17'),
            ('RSP-0160', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-09-15'),
            ('RSP-0161', 'SRV-03', '35-65 tahun', 'WIL-01', '2026-09-05'),
            ('RSP-0162', 'SRV-03', '17-34 tahun', 'WIL-06', '2026-09-04'),
            ('RSP-0163', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-08-25'),
            ('RSP-0164', 'SRV-03', '17-34 tahun', 'WIL-04', '2026-09-04'),
            ('RSP-0165', 'SRV-03', '35-65 tahun', 'WIL-03', '2026-08-26'),
            ('RSP-0166', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-08-24'),
            ('RSP-0167', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-09'),
            ('RSP-0168', 'SRV-03', 'Di atas 65 tahun', 'WIL-04', '2026-09-21'),
            ('RSP-0169', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-08-26'),
            ('RSP-0170', 'SRV-03', '17-34 tahun', 'WIL-01', '2026-08-31'),
            ('RSP-0171', 'SRV-03', '17-34 tahun', 'WIL-05', '2026-08-30'),
            ('RSP-0172', 'SRV-03', '35-65 tahun', 'WIL-01', '2026-09-01'),
            ('RSP-0173', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-08-21'),
            ('RSP-0174', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-09-07'),
            ('RSP-0175', 'SRV-03', 'Di atas 65 tahun', 'WIL-01', '2026-09-09'),
            ('RSP-0176', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-09-03'),
            ('RSP-0177', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-09-09'),
            ('RSP-0178', 'SRV-03', '17-34 tahun', 'WIL-04', '2026-09-06'),
            ('RSP-0179', 'SRV-03', '17-34 tahun', 'WIL-01', '2026-09-28'),
            ('RSP-0180', 'SRV-03', 'Di atas 65 tahun', 'WIL-05', '2026-09-14'),
            ('RSP-0181', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-09-11'),
            ('RSP-0182', 'SRV-03', '17-34 tahun', 'WIL-04', '2026-09-04'),
            ('RSP-0183', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-09-15'),
            ('RSP-0184', 'SRV-03', 'Di atas 65 tahun', 'WIL-06', '2026-09-20'),
            ('RSP-0185', 'SRV-03', '17-34 tahun', 'WIL-01', '2026-09-24'),
            ('RSP-0186', 'SRV-03', '35-65 tahun', 'WIL-01', '2026-09-22'),
            ('RSP-0187', 'SRV-03', '17-34 tahun', 'WIL-01', '2026-08-26'),
            ('RSP-0188', 'SRV-03', '17-34 tahun', 'WIL-02', '2026-09-28'),
            ('RSP-0189', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-26'),
            ('RSP-0190', 'SRV-03', '35-65 tahun', 'WIL-03', '2026-09-29'),
            ('RSP-0191', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-01'),
            ('RSP-0192', 'SRV-03', '35-65 tahun', 'WIL-01', '2026-09-22'),
            ('RSP-0193', 'SRV-03', '17-34 tahun', 'WIL-06', '2026-09-05'),
            ('RSP-0194', 'SRV-03', '17-34 tahun', 'WIL-02', '2026-09-01'),
            ('RSP-0195', 'SRV-03', 'Di bawah 17 tahun', 'WIL-04', '2026-09-18'),
            ('RSP-0196', 'SRV-03', '35-65 tahun', 'WIL-05', '2026-09-04'),
            ('RSP-0197', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-09-20'),
            ('RSP-0198', 'SRV-03', '17-34 tahun', 'WIL-04', '2026-09-16'),
            ('RSP-0199', 'SRV-03', '17-34 tahun', 'WIL-02', '2026-09-24'),
            ('RSP-0200', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-13'),
            ('RSP-0201', 'SRV-03', '35-65 tahun', 'WIL-04', '2026-08-24'),
            ('RSP-0202', 'SRV-03', '17-34 tahun', 'WIL-02', '2026-08-19'),
            ('RSP-0203', 'SRV-03', '35-65 tahun', 'WIL-05', '2026-09-01'),
            ('RSP-0204', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-08-29'),
            ('RSP-0205', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-19'),
            ('RSP-0206', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-09-23'),
            ('RSP-0207', 'SRV-03', 'Di atas 65 tahun', 'WIL-05', '2026-08-21'),
            ('RSP-0208', 'SRV-03', 'Di atas 65 tahun', 'WIL-02', '2026-09-05'),
            ('RSP-0209', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-08-24'),
            ('RSP-0210', 'SRV-03', '35-65 tahun', 'WIL-02', '2026-08-21'),
            ('RSP-0211', 'SRV-03', 'Di atas 65 tahun', 'WIL-02', '2026-08-22'),
            ('RSP-0212', 'SRV-03', '35-65 tahun', 'WIL-06', '2026-08-27'),
            ('RSP-0213', 'SRV-03', '35-65 tahun', 'WIL-03', '2026-08-21'),
            ('RSP-0214', 'SRV-03', 'Di atas 65 tahun', 'WIL-06', '2026-09-20')
    ) AS v (ID_RESPONDEN, ID_SURVEI, KELOMPOK_USIA, ID_WILAYAH, TANGGAL_PENGISIAN)
) AS s
ON t.ID_RESPONDEN = s.ID_RESPONDEN
WHEN MATCHED THEN UPDATE SET
    ID_SURVEI = s.ID_SURVEI,
    KELOMPOK_USIA = s.KELOMPOK_USIA,
    ID_WILAYAH = s.ID_WILAYAH,
    TANGGAL_PENGISIAN = s.TANGGAL_PENGISIAN
WHEN NOT MATCHED THEN INSERT (ID_RESPONDEN, ID_SURVEI, KELOMPOK_USIA, ID_WILAYAH, TANGGAL_PENGISIAN)
    VALUES (s.ID_RESPONDEN, s.ID_SURVEI, s.KELOMPOK_USIA, s.ID_WILAYAH, s.TANGGAL_PENGISIAN);

-- DATA_OPERASIONAL.JAWABAN_SURVEI: 1040 rows
MERGE INTO DATA_OPERASIONAL.JAWABAN_SURVEI AS t
USING (
    SELECT
        v.ID_JAWABAN AS ID_JAWABAN,
        v.ID_RESPONDEN AS ID_RESPONDEN,
        v.ID_PERTANYAAN AS ID_PERTANYAAN,
        v.ID_OPSI AS ID_OPSI
    FROM (VALUES
            ('JWB-00001', 'RSP-0001', 'PRT-0101', 'OPS-010102'),
            ('JWB-00002', 'RSP-0001', 'PRT-0103', 'OPS-010304'),
            ('JWB-00003', 'RSP-0001', 'PRT-0104', 'OPS-010405'),
            ('JWB-00004', 'RSP-0001', 'PRT-0105', 'OPS-010504'),
            ('JWB-00005', 'RSP-0001', 'PRT-0106', 'OPS-010603'),
            ('JWB-00006', 'RSP-0002', 'PRT-0101', 'OPS-010103'),
            ('JWB-00007', 'RSP-0002', 'PRT-0102', 'OPS-010203'),
            ('JWB-00008', 'RSP-0002', 'PRT-0104', 'OPS-010404'),
            ('JWB-00009', 'RSP-0002', 'PRT-0105', 'OPS-010504'),
            ('JWB-00010', 'RSP-0002', 'PRT-0106', 'OPS-010602'),
            ('JWB-00011', 'RSP-0003', 'PRT-0101', 'OPS-010105'),
            ('JWB-00012', 'RSP-0003', 'PRT-0102', 'OPS-010205'),
            ('JWB-00013', 'RSP-0003', 'PRT-0103', 'OPS-010304'),
            ('JWB-00014', 'RSP-0003', 'PRT-0104', 'OPS-010402'),
            ('JWB-00015', 'RSP-0003', 'PRT-0105', 'OPS-010503'),
            ('JWB-00016', 'RSP-0004', 'PRT-0101', 'OPS-010104'),
            ('JWB-00017', 'RSP-0004', 'PRT-0102', 'OPS-010205'),
            ('JWB-00018', 'RSP-0004', 'PRT-0103', 'OPS-010305'),
            ('JWB-00019', 'RSP-0004', 'PRT-0104', 'OPS-010403'),
            ('JWB-00020', 'RSP-0004', 'PRT-0105', 'OPS-010505'),
            ('JWB-00021', 'RSP-0004', 'PRT-0106', 'OPS-010601'),
            ('JWB-00022', 'RSP-0005', 'PRT-0101', 'OPS-010104'),
            ('JWB-00023', 'RSP-0005', 'PRT-0102', 'OPS-010204'),
            ('JWB-00024', 'RSP-0005', 'PRT-0103', 'OPS-010304'),
            ('JWB-00025', 'RSP-0005', 'PRT-0104', 'OPS-010405'),
            ('JWB-00026', 'RSP-0005', 'PRT-0105', 'OPS-010505'),
            ('JWB-00027', 'RSP-0005', 'PRT-0106', 'OPS-010603'),
            ('JWB-00028', 'RSP-0006', 'PRT-0101', 'OPS-010101'),
            ('JWB-00029', 'RSP-0006', 'PRT-0102', 'OPS-010204'),
            ('JWB-00030', 'RSP-0006', 'PRT-0103', 'OPS-010303'),
            ('JWB-00031', 'RSP-0006', 'PRT-0104', 'OPS-010402'),
            ('JWB-00032', 'RSP-0006', 'PRT-0105', 'OPS-010505'),
            ('JWB-00033', 'RSP-0006', 'PRT-0106', 'OPS-010602'),
            ('JWB-00034', 'RSP-0007', 'PRT-0101', 'OPS-010105'),
            ('JWB-00035', 'RSP-0007', 'PRT-0102', 'OPS-010205'),
            ('JWB-00036', 'RSP-0007', 'PRT-0103', 'OPS-010302'),
            ('JWB-00037', 'RSP-0007', 'PRT-0104', 'OPS-010405'),
            ('JWB-00038', 'RSP-0007', 'PRT-0105', 'OPS-010504'),
            ('JWB-00039', 'RSP-0008', 'PRT-0101', 'OPS-010104'),
            ('JWB-00040', 'RSP-0008', 'PRT-0102', 'OPS-010203'),
            ('JWB-00041', 'RSP-0008', 'PRT-0103', 'OPS-010304'),
            ('JWB-00042', 'RSP-0008', 'PRT-0104', 'OPS-010404'),
            ('JWB-00043', 'RSP-0008', 'PRT-0105', 'OPS-010505'),
            ('JWB-00044', 'RSP-0008', 'PRT-0106', 'OPS-010606'),
            ('JWB-00045', 'RSP-0009', 'PRT-0101', 'OPS-010105'),
            ('JWB-00046', 'RSP-0009', 'PRT-0102', 'OPS-010203'),
            ('JWB-00047', 'RSP-0009', 'PRT-0103', 'OPS-010305'),
            ('JWB-00048', 'RSP-0009', 'PRT-0104', 'OPS-010402'),
            ('JWB-00049', 'RSP-0009', 'PRT-0105', 'OPS-010505'),
            ('JWB-00050', 'RSP-0009', 'PRT-0106', 'OPS-010601'),
            ('JWB-00051', 'RSP-0010', 'PRT-0101', 'OPS-010102'),
            ('JWB-00052', 'RSP-0010', 'PRT-0102', 'OPS-010204'),
            ('JWB-00053', 'RSP-0010', 'PRT-0103', 'OPS-010305'),
            ('JWB-00054', 'RSP-0010', 'PRT-0104', 'OPS-010404'),
            ('JWB-00055', 'RSP-0010', 'PRT-0105', 'OPS-010505'),
            ('JWB-00056', 'RSP-0010', 'PRT-0106', 'OPS-010602'),
            ('JWB-00057', 'RSP-0011', 'PRT-0101', 'OPS-010101'),
            ('JWB-00058', 'RSP-0011', 'PRT-0102', 'OPS-010202'),
            ('JWB-00059', 'RSP-0011', 'PRT-0103', 'OPS-010304'),
            ('JWB-00060', 'RSP-0011', 'PRT-0104', 'OPS-010405'),
            ('JWB-00061', 'RSP-0011', 'PRT-0105', 'OPS-010502'),
            ('JWB-00062', 'RSP-0011', 'PRT-0106', 'OPS-010605'),
            ('JWB-00063', 'RSP-0012', 'PRT-0101', 'OPS-010101'),
            ('JWB-00064', 'RSP-0012', 'PRT-0102', 'OPS-010204'),
            ('JWB-00065', 'RSP-0012', 'PRT-0103', 'OPS-010305'),
            ('JWB-00066', 'RSP-0012', 'PRT-0104', 'OPS-010404'),
            ('JWB-00067', 'RSP-0012', 'PRT-0106', 'OPS-010602'),
            ('JWB-00068', 'RSP-0013', 'PRT-0101', 'OPS-010104'),
            ('JWB-00069', 'RSP-0013', 'PRT-0102', 'OPS-010204'),
            ('JWB-00070', 'RSP-0013', 'PRT-0103', 'OPS-010302'),
            ('JWB-00071', 'RSP-0013', 'PRT-0104', 'OPS-010405'),
            ('JWB-00072', 'RSP-0013', 'PRT-0105', 'OPS-010504'),
            ('JWB-00073', 'RSP-0013', 'PRT-0106', 'OPS-010603'),
            ('JWB-00074', 'RSP-0014', 'PRT-0101', 'OPS-010104'),
            ('JWB-00075', 'RSP-0014', 'PRT-0102', 'OPS-010204'),
            ('JWB-00076', 'RSP-0014', 'PRT-0103', 'OPS-010304'),
            ('JWB-00077', 'RSP-0014', 'PRT-0104', 'OPS-010405'),
            ('JWB-00078', 'RSP-0014', 'PRT-0105', 'OPS-010505'),
            ('JWB-00079', 'RSP-0014', 'PRT-0106', 'OPS-010605'),
            ('JWB-00080', 'RSP-0015', 'PRT-0101', 'OPS-010103'),
            ('JWB-00081', 'RSP-0015', 'PRT-0102', 'OPS-010204'),
            ('JWB-00082', 'RSP-0015', 'PRT-0103', 'OPS-010301'),
            ('JWB-00083', 'RSP-0015', 'PRT-0104', 'OPS-010405'),
            ('JWB-00084', 'RSP-0015', 'PRT-0105', 'OPS-010505'),
            ('JWB-00085', 'RSP-0015', 'PRT-0106', 'OPS-010601'),
            ('JWB-00086', 'RSP-0016', 'PRT-0101', 'OPS-010105'),
            ('JWB-00087', 'RSP-0016', 'PRT-0102', 'OPS-010204'),
            ('JWB-00088', 'RSP-0016', 'PRT-0103', 'OPS-010303'),
            ('JWB-00089', 'RSP-0016', 'PRT-0104', 'OPS-010402'),
            ('JWB-00090', 'RSP-0016', 'PRT-0105', 'OPS-010504'),
            ('JWB-00091', 'RSP-0016', 'PRT-0106', 'OPS-010601'),
            ('JWB-00092', 'RSP-0017', 'PRT-0101', 'OPS-010105'),
            ('JWB-00093', 'RSP-0017', 'PRT-0102', 'OPS-010204'),
            ('JWB-00094', 'RSP-0017', 'PRT-0103', 'OPS-010305'),
            ('JWB-00095', 'RSP-0017', 'PRT-0104', 'OPS-010403'),
            ('JWB-00096', 'RSP-0017', 'PRT-0105', 'OPS-010505'),
            ('JWB-00097', 'RSP-0018', 'PRT-0101', 'OPS-010105'),
            ('JWB-00098', 'RSP-0018', 'PRT-0103', 'OPS-010302'),
            ('JWB-00099', 'RSP-0018', 'PRT-0104', 'OPS-010404'),
            ('JWB-00100', 'RSP-0018', 'PRT-0105', 'OPS-010505'),
            ('JWB-00101', 'RSP-0018', 'PRT-0106', 'OPS-010602'),
            ('JWB-00102', 'RSP-0019', 'PRT-0101', 'OPS-010104'),
            ('JWB-00103', 'RSP-0019', 'PRT-0102', 'OPS-010205'),
            ('JWB-00104', 'RSP-0019', 'PRT-0103', 'OPS-010304'),
            ('JWB-00105', 'RSP-0019', 'PRT-0104', 'OPS-010405'),
            ('JWB-00106', 'RSP-0019', 'PRT-0105', 'OPS-010505'),
            ('JWB-00107', 'RSP-0020', 'PRT-0101', 'OPS-010104'),
            ('JWB-00108', 'RSP-0020', 'PRT-0102', 'OPS-010204'),
            ('JWB-00109', 'RSP-0020', 'PRT-0103', 'OPS-010304'),
            ('JWB-00110', 'RSP-0020', 'PRT-0104', 'OPS-010404'),
            ('JWB-00111', 'RSP-0020', 'PRT-0105', 'OPS-010505'),
            ('JWB-00112', 'RSP-0020', 'PRT-0106', 'OPS-010601'),
            ('JWB-00113', 'RSP-0021', 'PRT-0101', 'OPS-010102'),
            ('JWB-00114', 'RSP-0021', 'PRT-0102', 'OPS-010205'),
            ('JWB-00115', 'RSP-0021', 'PRT-0103', 'OPS-010304'),
            ('JWB-00116', 'RSP-0021', 'PRT-0104', 'OPS-010404'),
            ('JWB-00117', 'RSP-0021', 'PRT-0105', 'OPS-010505'),
            ('JWB-00118', 'RSP-0021', 'PRT-0106', 'OPS-010602'),
            ('JWB-00119', 'RSP-0022', 'PRT-0101', 'OPS-010105'),
            ('JWB-00120', 'RSP-0022', 'PRT-0102', 'OPS-010202'),
            ('JWB-00121', 'RSP-0022', 'PRT-0103', 'OPS-010304'),
            ('JWB-00122', 'RSP-0022', 'PRT-0104', 'OPS-010402'),
            ('JWB-00123', 'RSP-0022', 'PRT-0105', 'OPS-010504'),
            ('JWB-00124', 'RSP-0022', 'PRT-0106', 'OPS-010605'),
            ('JWB-00125', 'RSP-0023', 'PRT-0102', 'OPS-010205'),
            ('JWB-00126', 'RSP-0023', 'PRT-0103', 'OPS-010304'),
            ('JWB-00127', 'RSP-0023', 'PRT-0104', 'OPS-010405'),
            ('JWB-00128', 'RSP-0023', 'PRT-0105', 'OPS-010502'),
            ('JWB-00129', 'RSP-0023', 'PRT-0106', 'OPS-010601'),
            ('JWB-00130', 'RSP-0024', 'PRT-0101', 'OPS-010104'),
            ('JWB-00131', 'RSP-0024', 'PRT-0102', 'OPS-010204'),
            ('JWB-00132', 'RSP-0024', 'PRT-0103', 'OPS-010304'),
            ('JWB-00133', 'RSP-0024', 'PRT-0104', 'OPS-010404'),
            ('JWB-00134', 'RSP-0024', 'PRT-0105', 'OPS-010503'),
            ('JWB-00135', 'RSP-0024', 'PRT-0106', 'OPS-010605'),
            ('JWB-00136', 'RSP-0025', 'PRT-0101', 'OPS-010105'),
            ('JWB-00137', 'RSP-0025', 'PRT-0102', 'OPS-010205'),
            ('JWB-00138', 'RSP-0025', 'PRT-0103', 'OPS-010304'),
            ('JWB-00139', 'RSP-0025', 'PRT-0104', 'OPS-010402'),
            ('JWB-00140', 'RSP-0025', 'PRT-0105', 'OPS-010505'),
            ('JWB-00141', 'RSP-0025', 'PRT-0106', 'OPS-010605'),
            ('JWB-00142', 'RSP-0026', 'PRT-0101', 'OPS-010103'),
            ('JWB-00143', 'RSP-0026', 'PRT-0102', 'OPS-010204'),
            ('JWB-00144', 'RSP-0026', 'PRT-0104', 'OPS-010405'),
            ('JWB-00145', 'RSP-0026', 'PRT-0105', 'OPS-010505'),
            ('JWB-00146', 'RSP-0026', 'PRT-0106', 'OPS-010606'),
            ('JWB-00147', 'RSP-0027', 'PRT-0101', 'OPS-010104'),
            ('JWB-00148', 'RSP-0027', 'PRT-0102', 'OPS-010205'),
            ('JWB-00149', 'RSP-0027', 'PRT-0103', 'OPS-010303'),
            ('JWB-00150', 'RSP-0027', 'PRT-0104', 'OPS-010404'),
            ('JWB-00151', 'RSP-0027', 'PRT-0105', 'OPS-010505'),
            ('JWB-00152', 'RSP-0027', 'PRT-0106', 'OPS-010603'),
            ('JWB-00153', 'RSP-0028', 'PRT-0101', 'OPS-010105'),
            ('JWB-00154', 'RSP-0028', 'PRT-0102', 'OPS-010202'),
            ('JWB-00155', 'RSP-0028', 'PRT-0103', 'OPS-010303'),
            ('JWB-00156', 'RSP-0028', 'PRT-0104', 'OPS-010404'),
            ('JWB-00157', 'RSP-0028', 'PRT-0105', 'OPS-010504'),
            ('JWB-00158', 'RSP-0028', 'PRT-0106', 'OPS-010602'),
            ('JWB-00159', 'RSP-0029', 'PRT-0101', 'OPS-010105'),
            ('JWB-00160', 'RSP-0029', 'PRT-0102', 'OPS-010205'),
            ('JWB-00161', 'RSP-0029', 'PRT-0103', 'OPS-010305'),
            ('JWB-00162', 'RSP-0029', 'PRT-0104', 'OPS-010402'),
            ('JWB-00163', 'RSP-0029', 'PRT-0105', 'OPS-010504'),
            ('JWB-00164', 'RSP-0029', 'PRT-0106', 'OPS-010601'),
            ('JWB-00165', 'RSP-0030', 'PRT-0101', 'OPS-010104'),
            ('JWB-00166', 'RSP-0030', 'PRT-0102', 'OPS-010204'),
            ('JWB-00167', 'RSP-0030', 'PRT-0103', 'OPS-010304'),
            ('JWB-00168', 'RSP-0030', 'PRT-0104', 'OPS-010405'),
            ('JWB-00169', 'RSP-0030', 'PRT-0105', 'OPS-010505'),
            ('JWB-00170', 'RSP-0030', 'PRT-0106', 'OPS-010603'),
            ('JWB-00171', 'RSP-0031', 'PRT-0101', 'OPS-010102'),
            ('JWB-00172', 'RSP-0031', 'PRT-0102', 'OPS-010205'),
            ('JWB-00173', 'RSP-0031', 'PRT-0103', 'OPS-010303'),
            ('JWB-00174', 'RSP-0031', 'PRT-0104', 'OPS-010404'),
            ('JWB-00175', 'RSP-0031', 'PRT-0105', 'OPS-010503'),
            ('JWB-00176', 'RSP-0031', 'PRT-0106', 'OPS-010605'),
            ('JWB-00177', 'RSP-0032', 'PRT-0101', 'OPS-010105'),
            ('JWB-00178', 'RSP-0032', 'PRT-0102', 'OPS-010203'),
            ('JWB-00179', 'RSP-0032', 'PRT-0103', 'OPS-010303'),
            ('JWB-00180', 'RSP-0032', 'PRT-0105', 'OPS-010504'),
            ('JWB-00181', 'RSP-0032', 'PRT-0106', 'OPS-010603'),
            ('JWB-00182', 'RSP-0033', 'PRT-0101', 'OPS-010104'),
            ('JWB-00183', 'RSP-0033', 'PRT-0103', 'OPS-010303'),
            ('JWB-00184', 'RSP-0033', 'PRT-0104', 'OPS-010402'),
            ('JWB-00185', 'RSP-0033', 'PRT-0105', 'OPS-010505'),
            ('JWB-00186', 'RSP-0033', 'PRT-0106', 'OPS-010601'),
            ('JWB-00187', 'RSP-0034', 'PRT-0101', 'OPS-010105'),
            ('JWB-00188', 'RSP-0034', 'PRT-0102', 'OPS-010205'),
            ('JWB-00189', 'RSP-0034', 'PRT-0103', 'OPS-010304'),
            ('JWB-00190', 'RSP-0034', 'PRT-0104', 'OPS-010405'),
            ('JWB-00191', 'RSP-0034', 'PRT-0105', 'OPS-010504'),
            ('JWB-00192', 'RSP-0034', 'PRT-0106', 'OPS-010605'),
            ('JWB-00193', 'RSP-0035', 'PRT-0101', 'OPS-010104'),
            ('JWB-00194', 'RSP-0035', 'PRT-0102', 'OPS-010205'),
            ('JWB-00195', 'RSP-0035', 'PRT-0103', 'OPS-010304'),
            ('JWB-00196', 'RSP-0035', 'PRT-0104', 'OPS-010404'),
            ('JWB-00197', 'RSP-0035', 'PRT-0105', 'OPS-010504'),
            ('JWB-00198', 'RSP-0035', 'PRT-0106', 'OPS-010604'),
            ('JWB-00199', 'RSP-0036', 'PRT-0101', 'OPS-010103'),
            ('JWB-00200', 'RSP-0036', 'PRT-0103', 'OPS-010305'),
            ('JWB-00201', 'RSP-0036', 'PRT-0104', 'OPS-010404'),
            ('JWB-00202', 'RSP-0036', 'PRT-0105', 'OPS-010505'),
            ('JWB-00203', 'RSP-0036', 'PRT-0106', 'OPS-010605'),
            ('JWB-00204', 'RSP-0037', 'PRT-0103', 'OPS-010305'),
            ('JWB-00205', 'RSP-0037', 'PRT-0104', 'OPS-010404'),
            ('JWB-00206', 'RSP-0037', 'PRT-0105', 'OPS-010505'),
            ('JWB-00207', 'RSP-0037', 'PRT-0106', 'OPS-010606'),
            ('JWB-00208', 'RSP-0038', 'PRT-0101', 'OPS-010104'),
            ('JWB-00209', 'RSP-0038', 'PRT-0102', 'OPS-010205'),
            ('JWB-00210', 'RSP-0038', 'PRT-0103', 'OPS-010304'),
            ('JWB-00211', 'RSP-0038', 'PRT-0104', 'OPS-010404'),
            ('JWB-00212', 'RSP-0038', 'PRT-0105', 'OPS-010505'),
            ('JWB-00213', 'RSP-0038', 'PRT-0106', 'OPS-010605'),
            ('JWB-00214', 'RSP-0039', 'PRT-0101', 'OPS-010101'),
            ('JWB-00215', 'RSP-0039', 'PRT-0102', 'OPS-010204'),
            ('JWB-00216', 'RSP-0039', 'PRT-0103', 'OPS-010305'),
            ('JWB-00217', 'RSP-0039', 'PRT-0104', 'OPS-010402'),
            ('JWB-00218', 'RSP-0039', 'PRT-0105', 'OPS-010505'),
            ('JWB-00219', 'RSP-0039', 'PRT-0106', 'OPS-010605'),
            ('JWB-00220', 'RSP-0040', 'PRT-0101', 'OPS-010104'),
            ('JWB-00221', 'RSP-0040', 'PRT-0104', 'OPS-010404'),
            ('JWB-00222', 'RSP-0040', 'PRT-0105', 'OPS-010505'),
            ('JWB-00223', 'RSP-0041', 'PRT-0101', 'OPS-010103'),
            ('JWB-00224', 'RSP-0041', 'PRT-0103', 'OPS-010302'),
            ('JWB-00225', 'RSP-0041', 'PRT-0105', 'OPS-010505'),
            ('JWB-00226', 'RSP-0041', 'PRT-0106', 'OPS-010602'),
            ('JWB-00227', 'RSP-0042', 'PRT-0101', 'OPS-010104'),
            ('JWB-00228', 'RSP-0042', 'PRT-0102', 'OPS-010205'),
            ('JWB-00229', 'RSP-0042', 'PRT-0103', 'OPS-010302'),
            ('JWB-00230', 'RSP-0042', 'PRT-0104', 'OPS-010405'),
            ('JWB-00231', 'RSP-0042', 'PRT-0105', 'OPS-010504'),
            ('JWB-00232', 'RSP-0042', 'PRT-0106', 'OPS-010605'),
            ('JWB-00233', 'RSP-0043', 'PRT-0101', 'OPS-010104'),
            ('JWB-00234', 'RSP-0043', 'PRT-0102', 'OPS-010204'),
            ('JWB-00235', 'RSP-0043', 'PRT-0103', 'OPS-010304'),
            ('JWB-00236', 'RSP-0043', 'PRT-0104', 'OPS-010405'),
            ('JWB-00237', 'RSP-0043', 'PRT-0105', 'OPS-010504'),
            ('JWB-00238', 'RSP-0043', 'PRT-0106', 'OPS-010604'),
            ('JWB-00239', 'RSP-0044', 'PRT-0101', 'OPS-010103'),
            ('JWB-00240', 'RSP-0044', 'PRT-0102', 'OPS-010205'),
            ('JWB-00241', 'RSP-0044', 'PRT-0103', 'OPS-010302'),
            ('JWB-00242', 'RSP-0044', 'PRT-0104', 'OPS-010402'),
            ('JWB-00243', 'RSP-0044', 'PRT-0105', 'OPS-010504'),
            ('JWB-00244', 'RSP-0044', 'PRT-0106', 'OPS-010605'),
            ('JWB-00245', 'RSP-0045', 'PRT-0101', 'OPS-010104'),
            ('JWB-00246', 'RSP-0045', 'PRT-0102', 'OPS-010205'),
            ('JWB-00247', 'RSP-0045', 'PRT-0103', 'OPS-010305'),
            ('JWB-00248', 'RSP-0045', 'PRT-0104', 'OPS-010404'),
            ('JWB-00249', 'RSP-0045', 'PRT-0105', 'OPS-010503'),
            ('JWB-00250', 'RSP-0045', 'PRT-0106', 'OPS-010602'),
            ('JWB-00251', 'RSP-0046', 'PRT-0101', 'OPS-010104'),
            ('JWB-00252', 'RSP-0046', 'PRT-0102', 'OPS-010203'),
            ('JWB-00253', 'RSP-0046', 'PRT-0103', 'OPS-010305'),
            ('JWB-00254', 'RSP-0046', 'PRT-0104', 'OPS-010404'),
            ('JWB-00255', 'RSP-0046', 'PRT-0105', 'OPS-010504'),
            ('JWB-00256', 'RSP-0046', 'PRT-0106', 'OPS-010603'),
            ('JWB-00257', 'RSP-0047', 'PRT-0101', 'OPS-010105'),
            ('JWB-00258', 'RSP-0047', 'PRT-0102', 'OPS-010202'),
            ('JWB-00259', 'RSP-0047', 'PRT-0103', 'OPS-010305'),
            ('JWB-00260', 'RSP-0047', 'PRT-0104', 'OPS-010403'),
            ('JWB-00261', 'RSP-0047', 'PRT-0105', 'OPS-010505'),
            ('JWB-00262', 'RSP-0047', 'PRT-0106', 'OPS-010605'),
            ('JWB-00263', 'RSP-0048', 'PRT-0101', 'OPS-010104'),
            ('JWB-00264', 'RSP-0048', 'PRT-0102', 'OPS-010204'),
            ('JWB-00265', 'RSP-0048', 'PRT-0103', 'OPS-010305'),
            ('JWB-00266', 'RSP-0048', 'PRT-0104', 'OPS-010403'),
            ('JWB-00267', 'RSP-0048', 'PRT-0105', 'OPS-010505'),
            ('JWB-00268', 'RSP-0048', 'PRT-0106', 'OPS-010602'),
            ('JWB-00269', 'RSP-0049', 'PRT-0101', 'OPS-010104'),
            ('JWB-00270', 'RSP-0049', 'PRT-0102', 'OPS-010204'),
            ('JWB-00271', 'RSP-0049', 'PRT-0103', 'OPS-010305'),
            ('JWB-00272', 'RSP-0049', 'PRT-0104', 'OPS-010402'),
            ('JWB-00273', 'RSP-0049', 'PRT-0105', 'OPS-010505'),
            ('JWB-00274', 'RSP-0049', 'PRT-0106', 'OPS-010605'),
            ('JWB-00275', 'RSP-0050', 'PRT-0101', 'OPS-010105'),
            ('JWB-00276', 'RSP-0050', 'PRT-0102', 'OPS-010205'),
            ('JWB-00277', 'RSP-0050', 'PRT-0103', 'OPS-010303'),
            ('JWB-00278', 'RSP-0050', 'PRT-0104', 'OPS-010404'),
            ('JWB-00279', 'RSP-0050', 'PRT-0105', 'OPS-010504'),
            ('JWB-00280', 'RSP-0050', 'PRT-0106', 'OPS-010603'),
            ('JWB-00281', 'RSP-0051', 'PRT-0101', 'OPS-010104'),
            ('JWB-00282', 'RSP-0051', 'PRT-0102', 'OPS-010204'),
            ('JWB-00283', 'RSP-0051', 'PRT-0103', 'OPS-010304'),
            ('JWB-00284', 'RSP-0051', 'PRT-0104', 'OPS-010402'),
            ('JWB-00285', 'RSP-0051', 'PRT-0105', 'OPS-010505'),
            ('JWB-00286', 'RSP-0051', 'PRT-0106', 'OPS-010606'),
            ('JWB-00287', 'RSP-0052', 'PRT-0101', 'OPS-010101'),
            ('JWB-00288', 'RSP-0052', 'PRT-0102', 'OPS-010204'),
            ('JWB-00289', 'RSP-0052', 'PRT-0103', 'OPS-010304'),
            ('JWB-00290', 'RSP-0052', 'PRT-0104', 'OPS-010402'),
            ('JWB-00291', 'RSP-0052', 'PRT-0105', 'OPS-010503'),
            ('JWB-00292', 'RSP-0052', 'PRT-0106', 'OPS-010603'),
            ('JWB-00293', 'RSP-0053', 'PRT-0101', 'OPS-010105'),
            ('JWB-00294', 'RSP-0053', 'PRT-0102', 'OPS-010204'),
            ('JWB-00295', 'RSP-0053', 'PRT-0103', 'OPS-010304'),
            ('JWB-00296', 'RSP-0053', 'PRT-0104', 'OPS-010403'),
            ('JWB-00297', 'RSP-0053', 'PRT-0105', 'OPS-010505'),
            ('JWB-00298', 'RSP-0053', 'PRT-0106', 'OPS-010603'),
            ('JWB-00299', 'RSP-0054', 'PRT-0101', 'OPS-010105'),
            ('JWB-00300', 'RSP-0054', 'PRT-0102', 'OPS-010204'),
            ('JWB-00301', 'RSP-0054', 'PRT-0103', 'OPS-010304'),
            ('JWB-00302', 'RSP-0054', 'PRT-0104', 'OPS-010403'),
            ('JWB-00303', 'RSP-0054', 'PRT-0105', 'OPS-010503'),
            ('JWB-00304', 'RSP-0054', 'PRT-0106', 'OPS-010601'),
            ('JWB-00305', 'RSP-0055', 'PRT-0101', 'OPS-010104'),
            ('JWB-00306', 'RSP-0055', 'PRT-0103', 'OPS-010302'),
            ('JWB-00307', 'RSP-0055', 'PRT-0104', 'OPS-010404'),
            ('JWB-00308', 'RSP-0055', 'PRT-0105', 'OPS-010504'),
            ('JWB-00309', 'RSP-0055', 'PRT-0106', 'OPS-010604'),
            ('JWB-00310', 'RSP-0056', 'PRT-0102', 'OPS-010204'),
            ('JWB-00311', 'RSP-0056', 'PRT-0103', 'OPS-010304'),
            ('JWB-00312', 'RSP-0056', 'PRT-0104', 'OPS-010405'),
            ('JWB-00313', 'RSP-0056', 'PRT-0105', 'OPS-010504'),
            ('JWB-00314', 'RSP-0056', 'PRT-0106', 'OPS-010601'),
            ('JWB-00315', 'RSP-0057', 'PRT-0101', 'OPS-010104'),
            ('JWB-00316', 'RSP-0057', 'PRT-0102', 'OPS-010204'),
            ('JWB-00317', 'RSP-0057', 'PRT-0103', 'OPS-010305'),
            ('JWB-00318', 'RSP-0057', 'PRT-0104', 'OPS-010405'),
            ('JWB-00319', 'RSP-0057', 'PRT-0105', 'OPS-010504'),
            ('JWB-00320', 'RSP-0057', 'PRT-0106', 'OPS-010601'),
            ('JWB-00321', 'RSP-0058', 'PRT-0101', 'OPS-010105'),
            ('JWB-00322', 'RSP-0058', 'PRT-0102', 'OPS-010203'),
            ('JWB-00323', 'RSP-0058', 'PRT-0103', 'OPS-010304'),
            ('JWB-00324', 'RSP-0058', 'PRT-0104', 'OPS-010403'),
            ('JWB-00325', 'RSP-0058', 'PRT-0105', 'OPS-010505'),
            ('JWB-00326', 'RSP-0058', 'PRT-0106', 'OPS-010603'),
            ('JWB-00327', 'RSP-0059', 'PRT-0101', 'OPS-010104'),
            ('JWB-00328', 'RSP-0059', 'PRT-0102', 'OPS-010205'),
            ('JWB-00329', 'RSP-0059', 'PRT-0103', 'OPS-010305'),
            ('JWB-00330', 'RSP-0059', 'PRT-0104', 'OPS-010405'),
            ('JWB-00331', 'RSP-0059', 'PRT-0105', 'OPS-010505'),
            ('JWB-00332', 'RSP-0059', 'PRT-0106', 'OPS-010602'),
            ('JWB-00333', 'RSP-0060', 'PRT-0101', 'OPS-010104'),
            ('JWB-00334', 'RSP-0060', 'PRT-0102', 'OPS-010203'),
            ('JWB-00335', 'RSP-0060', 'PRT-0103', 'OPS-010305'),
            ('JWB-00336', 'RSP-0060', 'PRT-0104', 'OPS-010405'),
            ('JWB-00337', 'RSP-0060', 'PRT-0105', 'OPS-010504'),
            ('JWB-00338', 'RSP-0060', 'PRT-0106', 'OPS-010603'),
            ('JWB-00339', 'RSP-0061', 'PRT-0101', 'OPS-010103'),
            ('JWB-00340', 'RSP-0061', 'PRT-0103', 'OPS-010301'),
            ('JWB-00341', 'RSP-0061', 'PRT-0104', 'OPS-010404'),
            ('JWB-00342', 'RSP-0061', 'PRT-0105', 'OPS-010505'),
            ('JWB-00343', 'RSP-0061', 'PRT-0106', 'OPS-010602'),
            ('JWB-00344', 'RSP-0062', 'PRT-0101', 'OPS-010102'),
            ('JWB-00345', 'RSP-0062', 'PRT-0102', 'OPS-010203'),
            ('JWB-00346', 'RSP-0062', 'PRT-0103', 'OPS-010305'),
            ('JWB-00347', 'RSP-0062', 'PRT-0104', 'OPS-010405'),
            ('JWB-00348', 'RSP-0062', 'PRT-0105', 'OPS-010503'),
            ('JWB-00349', 'RSP-0062', 'PRT-0106', 'OPS-010601'),
            ('JWB-00350', 'RSP-0063', 'PRT-0101', 'OPS-010105'),
            ('JWB-00351', 'RSP-0063', 'PRT-0102', 'OPS-010204'),
            ('JWB-00352', 'RSP-0063', 'PRT-0103', 'OPS-010304'),
            ('JWB-00353', 'RSP-0063', 'PRT-0104', 'OPS-010404'),
            ('JWB-00354', 'RSP-0063', 'PRT-0105', 'OPS-010504'),
            ('JWB-00355', 'RSP-0063', 'PRT-0106', 'OPS-010605'),
            ('JWB-00356', 'RSP-0064', 'PRT-0101', 'OPS-010105'),
            ('JWB-00357', 'RSP-0064', 'PRT-0102', 'OPS-010204'),
            ('JWB-00358', 'RSP-0064', 'PRT-0103', 'OPS-010304'),
            ('JWB-00359', 'RSP-0064', 'PRT-0104', 'OPS-010402'),
            ('JWB-00360', 'RSP-0064', 'PRT-0105', 'OPS-010504'),
            ('JWB-00361', 'RSP-0064', 'PRT-0106', 'OPS-010601'),
            ('JWB-00362', 'RSP-0065', 'PRT-0101', 'OPS-010105'),
            ('JWB-00363', 'RSP-0065', 'PRT-0102', 'OPS-010204'),
            ('JWB-00364', 'RSP-0065', 'PRT-0103', 'OPS-010304'),
            ('JWB-00365', 'RSP-0065', 'PRT-0104', 'OPS-010405'),
            ('JWB-00366', 'RSP-0065', 'PRT-0105', 'OPS-010505'),
            ('JWB-00367', 'RSP-0065', 'PRT-0106', 'OPS-010605'),
            ('JWB-00368', 'RSP-0066', 'PRT-0101', 'OPS-010105'),
            ('JWB-00369', 'RSP-0066', 'PRT-0103', 'OPS-010304'),
            ('JWB-00370', 'RSP-0066', 'PRT-0104', 'OPS-010404'),
            ('JWB-00371', 'RSP-0066', 'PRT-0105', 'OPS-010505'),
            ('JWB-00372', 'RSP-0066', 'PRT-0106', 'OPS-010606'),
            ('JWB-00373', 'RSP-0067', 'PRT-0101', 'OPS-010105'),
            ('JWB-00374', 'RSP-0067', 'PRT-0102', 'OPS-010203'),
            ('JWB-00375', 'RSP-0067', 'PRT-0103', 'OPS-010304'),
            ('JWB-00376', 'RSP-0067', 'PRT-0104', 'OPS-010403'),
            ('JWB-00377', 'RSP-0067', 'PRT-0105', 'OPS-010503'),
            ('JWB-00378', 'RSP-0068', 'PRT-0101', 'OPS-010105'),
            ('JWB-00379', 'RSP-0068', 'PRT-0102', 'OPS-010205'),
            ('JWB-00380', 'RSP-0068', 'PRT-0103', 'OPS-010304'),
            ('JWB-00381', 'RSP-0068', 'PRT-0104', 'OPS-010404'),
            ('JWB-00382', 'RSP-0068', 'PRT-0105', 'OPS-010503'),
            ('JWB-00383', 'RSP-0068', 'PRT-0106', 'OPS-010603'),
            ('JWB-00384', 'RSP-0069', 'PRT-0101', 'OPS-010104'),
            ('JWB-00385', 'RSP-0069', 'PRT-0102', 'OPS-010204'),
            ('JWB-00386', 'RSP-0069', 'PRT-0103', 'OPS-010305'),
            ('JWB-00387', 'RSP-0069', 'PRT-0104', 'OPS-010405'),
            ('JWB-00388', 'RSP-0069', 'PRT-0105', 'OPS-010505'),
            ('JWB-00389', 'RSP-0069', 'PRT-0106', 'OPS-010603'),
            ('JWB-00390', 'RSP-0070', 'PRT-0101', 'OPS-010105'),
            ('JWB-00391', 'RSP-0070', 'PRT-0102', 'OPS-010203'),
            ('JWB-00392', 'RSP-0070', 'PRT-0103', 'OPS-010305'),
            ('JWB-00393', 'RSP-0070', 'PRT-0104', 'OPS-010404'),
            ('JWB-00394', 'RSP-0070', 'PRT-0105', 'OPS-010504'),
            ('JWB-00395', 'RSP-0070', 'PRT-0106', 'OPS-010605'),
            ('JWB-00396', 'RSP-0071', 'PRT-0101', 'OPS-010104'),
            ('JWB-00397', 'RSP-0071', 'PRT-0102', 'OPS-010205'),
            ('JWB-00398', 'RSP-0071', 'PRT-0103', 'OPS-010303'),
            ('JWB-00399', 'RSP-0071', 'PRT-0104', 'OPS-010404'),
            ('JWB-00400', 'RSP-0071', 'PRT-0105', 'OPS-010505'),
            ('JWB-00401', 'RSP-0071', 'PRT-0106', 'OPS-010605'),
            ('JWB-00402', 'RSP-0072', 'PRT-0101', 'OPS-010104'),
            ('JWB-00403', 'RSP-0072', 'PRT-0103', 'OPS-010304'),
            ('JWB-00404', 'RSP-0072', 'PRT-0104', 'OPS-010402'),
            ('JWB-00405', 'RSP-0072', 'PRT-0105', 'OPS-010505'),
            ('JWB-00406', 'RSP-0072', 'PRT-0106', 'OPS-010602'),
            ('JWB-00407', 'RSP-0073', 'PRT-0101', 'OPS-010104'),
            ('JWB-00408', 'RSP-0073', 'PRT-0102', 'OPS-010203'),
            ('JWB-00409', 'RSP-0073', 'PRT-0103', 'OPS-010304'),
            ('JWB-00410', 'RSP-0073', 'PRT-0104', 'OPS-010402'),
            ('JWB-00411', 'RSP-0073', 'PRT-0106', 'OPS-010601'),
            ('JWB-00412', 'RSP-0074', 'PRT-0101', 'OPS-010104'),
            ('JWB-00413', 'RSP-0074', 'PRT-0102', 'OPS-010204'),
            ('JWB-00414', 'RSP-0074', 'PRT-0103', 'OPS-010304'),
            ('JWB-00415', 'RSP-0074', 'PRT-0104', 'OPS-010404'),
            ('JWB-00416', 'RSP-0075', 'PRT-0101', 'OPS-010104'),
            ('JWB-00417', 'RSP-0075', 'PRT-0102', 'OPS-010203'),
            ('JWB-00418', 'RSP-0075', 'PRT-0103', 'OPS-010303'),
            ('JWB-00419', 'RSP-0075', 'PRT-0104', 'OPS-010403'),
            ('JWB-00420', 'RSP-0075', 'PRT-0105', 'OPS-010504'),
            ('JWB-00421', 'RSP-0075', 'PRT-0106', 'OPS-010602'),
            ('JWB-00422', 'RSP-0076', 'PRT-0101', 'OPS-010104'),
            ('JWB-00423', 'RSP-0076', 'PRT-0102', 'OPS-010204'),
            ('JWB-00424', 'RSP-0076', 'PRT-0103', 'OPS-010301'),
            ('JWB-00425', 'RSP-0076', 'PRT-0104', 'OPS-010404'),
            ('JWB-00426', 'RSP-0076', 'PRT-0105', 'OPS-010503'),
            ('JWB-00427', 'RSP-0076', 'PRT-0106', 'OPS-010602'),
            ('JWB-00428', 'RSP-0077', 'PRT-0101', 'OPS-010101'),
            ('JWB-00429', 'RSP-0077', 'PRT-0102', 'OPS-010204'),
            ('JWB-00430', 'RSP-0077', 'PRT-0103', 'OPS-010304'),
            ('JWB-00431', 'RSP-0077', 'PRT-0104', 'OPS-010404'),
            ('JWB-00432', 'RSP-0077', 'PRT-0105', 'OPS-010505'),
            ('JWB-00433', 'RSP-0077', 'PRT-0106', 'OPS-010605'),
            ('JWB-00434', 'RSP-0078', 'PRT-0101', 'OPS-010104'),
            ('JWB-00435', 'RSP-0078', 'PRT-0102', 'OPS-010201'),
            ('JWB-00436', 'RSP-0078', 'PRT-0104', 'OPS-010405'),
            ('JWB-00437', 'RSP-0078', 'PRT-0105', 'OPS-010503'),
            ('JWB-00438', 'RSP-0078', 'PRT-0106', 'OPS-010606'),
            ('JWB-00439', 'RSP-0079', 'PRT-0101', 'OPS-010105'),
            ('JWB-00440', 'RSP-0079', 'PRT-0102', 'OPS-010205'),
            ('JWB-00441', 'RSP-0079', 'PRT-0103', 'OPS-010305'),
            ('JWB-00442', 'RSP-0079', 'PRT-0104', 'OPS-010404'),
            ('JWB-00443', 'RSP-0079', 'PRT-0105', 'OPS-010504'),
            ('JWB-00444', 'RSP-0079', 'PRT-0106', 'OPS-010605'),
            ('JWB-00445', 'RSP-0080', 'PRT-0101', 'OPS-010105'),
            ('JWB-00446', 'RSP-0080', 'PRT-0102', 'OPS-010205'),
            ('JWB-00447', 'RSP-0080', 'PRT-0103', 'OPS-010305'),
            ('JWB-00448', 'RSP-0080', 'PRT-0104', 'OPS-010405'),
            ('JWB-00449', 'RSP-0080', 'PRT-0105', 'OPS-010504'),
            ('JWB-00450', 'RSP-0080', 'PRT-0106', 'OPS-010602'),
            ('JWB-00451', 'RSP-0081', 'PRT-0101', 'OPS-010105'),
            ('JWB-00452', 'RSP-0081', 'PRT-0102', 'OPS-010204'),
            ('JWB-00453', 'RSP-0081', 'PRT-0103', 'OPS-010305'),
            ('JWB-00454', 'RSP-0081', 'PRT-0104', 'OPS-010405'),
            ('JWB-00455', 'RSP-0081', 'PRT-0105', 'OPS-010504'),
            ('JWB-00456', 'RSP-0081', 'PRT-0106', 'OPS-010603'),
            ('JWB-00457', 'RSP-0082', 'PRT-0101', 'OPS-010104'),
            ('JWB-00458', 'RSP-0082', 'PRT-0102', 'OPS-010204'),
            ('JWB-00459', 'RSP-0082', 'PRT-0103', 'OPS-010305'),
            ('JWB-00460', 'RSP-0082', 'PRT-0104', 'OPS-010402'),
            ('JWB-00461', 'RSP-0082', 'PRT-0105', 'OPS-010505'),
            ('JWB-00462', 'RSP-0082', 'PRT-0106', 'OPS-010602'),
            ('JWB-00463', 'RSP-0083', 'PRT-0102', 'OPS-010204'),
            ('JWB-00464', 'RSP-0083', 'PRT-0103', 'OPS-010303'),
            ('JWB-00465', 'RSP-0083', 'PRT-0104', 'OPS-010404'),
            ('JWB-00466', 'RSP-0083', 'PRT-0105', 'OPS-010504'),
            ('JWB-00467', 'RSP-0083', 'PRT-0106', 'OPS-010605'),
            ('JWB-00468', 'RSP-0084', 'PRT-0101', 'OPS-010101'),
            ('JWB-00469', 'RSP-0084', 'PRT-0102', 'OPS-010204'),
            ('JWB-00470', 'RSP-0084', 'PRT-0103', 'OPS-010305'),
            ('JWB-00471', 'RSP-0084', 'PRT-0104', 'OPS-010405'),
            ('JWB-00472', 'RSP-0084', 'PRT-0105', 'OPS-010505'),
            ('JWB-00473', 'RSP-0084', 'PRT-0106', 'OPS-010603'),
            ('JWB-00474', 'RSP-0085', 'PRT-0201', 'OPS-020101'),
            ('JWB-00475', 'RSP-0085', 'PRT-0202', 'OPS-020203'),
            ('JWB-00476', 'RSP-0085', 'PRT-0203', 'OPS-020303'),
            ('JWB-00477', 'RSP-0085', 'PRT-0204', 'OPS-020404'),
            ('JWB-00478', 'RSP-0085', 'PRT-0205', 'OPS-020504'),
            ('JWB-00479', 'RSP-0086', 'PRT-0201', 'OPS-020105'),
            ('JWB-00480', 'RSP-0086', 'PRT-0202', 'OPS-020203'),
            ('JWB-00481', 'RSP-0086', 'PRT-0203', 'OPS-020301'),
            ('JWB-00482', 'RSP-0086', 'PRT-0204', 'OPS-020405'),
            ('JWB-00483', 'RSP-0086', 'PRT-0205', 'OPS-020503'),
            ('JWB-00484', 'RSP-0087', 'PRT-0201', 'OPS-020102'),
            ('JWB-00485', 'RSP-0087', 'PRT-0202', 'OPS-020204'),
            ('JWB-00486', 'RSP-0087', 'PRT-0203', 'OPS-020305'),
            ('JWB-00487', 'RSP-0087', 'PRT-0204', 'OPS-020404'),
            ('JWB-00488', 'RSP-0087', 'PRT-0205', 'OPS-020502'),
            ('JWB-00489', 'RSP-0088', 'PRT-0201', 'OPS-020104'),
            ('JWB-00490', 'RSP-0088', 'PRT-0202', 'OPS-020204'),
            ('JWB-00491', 'RSP-0088', 'PRT-0203', 'OPS-020301'),
            ('JWB-00492', 'RSP-0088', 'PRT-0204', 'OPS-020403'),
            ('JWB-00493', 'RSP-0088', 'PRT-0205', 'OPS-020503'),
            ('JWB-00494', 'RSP-0089', 'PRT-0201', 'OPS-020101'),
            ('JWB-00495', 'RSP-0089', 'PRT-0202', 'OPS-020203'),
            ('JWB-00496', 'RSP-0089', 'PRT-0203', 'OPS-020302'),
            ('JWB-00497', 'RSP-0089', 'PRT-0204', 'OPS-020401'),
            ('JWB-00498', 'RSP-0089', 'PRT-0205', 'OPS-020502'),
            ('JWB-00499', 'RSP-0090', 'PRT-0201', 'OPS-020103'),
            ('JWB-00500', 'RSP-0090', 'PRT-0202', 'OPS-020204'),
            ('JWB-00501', 'RSP-0090', 'PRT-0203', 'OPS-020305'),
            ('JWB-00502', 'RSP-0090', 'PRT-0204', 'OPS-020405'),
            ('JWB-00503', 'RSP-0091', 'PRT-0201', 'OPS-020105'),
            ('JWB-00504', 'RSP-0091', 'PRT-0202', 'OPS-020204'),
            ('JWB-00505', 'RSP-0091', 'PRT-0203', 'OPS-020303'),
            ('JWB-00506', 'RSP-0091', 'PRT-0204', 'OPS-020404'),
            ('JWB-00507', 'RSP-0091', 'PRT-0205', 'OPS-020504'),
            ('JWB-00508', 'RSP-0092', 'PRT-0201', 'OPS-020101'),
            ('JWB-00509', 'RSP-0092', 'PRT-0202', 'OPS-020203'),
            ('JWB-00510', 'RSP-0092', 'PRT-0203', 'OPS-020301'),
            ('JWB-00511', 'RSP-0092', 'PRT-0204', 'OPS-020405'),
            ('JWB-00512', 'RSP-0092', 'PRT-0205', 'OPS-020505'),
            ('JWB-00513', 'RSP-0093', 'PRT-0201', 'OPS-020102'),
            ('JWB-00514', 'RSP-0093', 'PRT-0203', 'OPS-020301'),
            ('JWB-00515', 'RSP-0093', 'PRT-0204', 'OPS-020404'),
            ('JWB-00516', 'RSP-0093', 'PRT-0205', 'OPS-020505'),
            ('JWB-00517', 'RSP-0094', 'PRT-0201', 'OPS-020101'),
            ('JWB-00518', 'RSP-0094', 'PRT-0202', 'OPS-020203'),
            ('JWB-00519', 'RSP-0094', 'PRT-0203', 'OPS-020302'),
            ('JWB-00520', 'RSP-0094', 'PRT-0204', 'OPS-020404'),
            ('JWB-00521', 'RSP-0094', 'PRT-0205', 'OPS-020504'),
            ('JWB-00522', 'RSP-0095', 'PRT-0201', 'OPS-020101'),
            ('JWB-00523', 'RSP-0095', 'PRT-0202', 'OPS-020201'),
            ('JWB-00524', 'RSP-0095', 'PRT-0203', 'OPS-020303'),
            ('JWB-00525', 'RSP-0095', 'PRT-0204', 'OPS-020404'),
            ('JWB-00526', 'RSP-0095', 'PRT-0205', 'OPS-020503'),
            ('JWB-00527', 'RSP-0096', 'PRT-0201', 'OPS-020102'),
            ('JWB-00528', 'RSP-0096', 'PRT-0202', 'OPS-020201'),
            ('JWB-00529', 'RSP-0096', 'PRT-0203', 'OPS-020305'),
            ('JWB-00530', 'RSP-0096', 'PRT-0204', 'OPS-020405'),
            ('JWB-00531', 'RSP-0096', 'PRT-0205', 'OPS-020504'),
            ('JWB-00532', 'RSP-0097', 'PRT-0201', 'OPS-020105'),
            ('JWB-00533', 'RSP-0097', 'PRT-0202', 'OPS-020204'),
            ('JWB-00534', 'RSP-0097', 'PRT-0203', 'OPS-020303'),
            ('JWB-00535', 'RSP-0097', 'PRT-0204', 'OPS-020403'),
            ('JWB-00536', 'RSP-0097', 'PRT-0205', 'OPS-020503'),
            ('JWB-00537', 'RSP-0098', 'PRT-0201', 'OPS-020101'),
            ('JWB-00538', 'RSP-0098', 'PRT-0202', 'OPS-020205'),
            ('JWB-00539', 'RSP-0098', 'PRT-0203', 'OPS-020303'),
            ('JWB-00540', 'RSP-0098', 'PRT-0204', 'OPS-020403'),
            ('JWB-00541', 'RSP-0098', 'PRT-0205', 'OPS-020502'),
            ('JWB-00542', 'RSP-0099', 'PRT-0201', 'OPS-020104'),
            ('JWB-00543', 'RSP-0099', 'PRT-0202', 'OPS-020204'),
            ('JWB-00544', 'RSP-0099', 'PRT-0203', 'OPS-020301'),
            ('JWB-00545', 'RSP-0099', 'PRT-0204', 'OPS-020404'),
            ('JWB-00546', 'RSP-0099', 'PRT-0205', 'OPS-020504'),
            ('JWB-00547', 'RSP-0100', 'PRT-0201', 'OPS-020102'),
            ('JWB-00548', 'RSP-0100', 'PRT-0202', 'OPS-020205'),
            ('JWB-00549', 'RSP-0100', 'PRT-0205', 'OPS-020501'),
            ('JWB-00550', 'RSP-0101', 'PRT-0201', 'OPS-020102'),
            ('JWB-00551', 'RSP-0101', 'PRT-0202', 'OPS-020201'),
            ('JWB-00552', 'RSP-0101', 'PRT-0203', 'OPS-020302'),
            ('JWB-00553', 'RSP-0101', 'PRT-0204', 'OPS-020404'),
            ('JWB-00554', 'RSP-0101', 'PRT-0205', 'OPS-020503'),
            ('JWB-00555', 'RSP-0102', 'PRT-0201', 'OPS-020102'),
            ('JWB-00556', 'RSP-0102', 'PRT-0202', 'OPS-020204'),
            ('JWB-00557', 'RSP-0102', 'PRT-0203', 'OPS-020302'),
            ('JWB-00558', 'RSP-0102', 'PRT-0204', 'OPS-020405'),
            ('JWB-00559', 'RSP-0102', 'PRT-0205', 'OPS-020503'),
            ('JWB-00560', 'RSP-0103', 'PRT-0201', 'OPS-020102'),
            ('JWB-00561', 'RSP-0103', 'PRT-0202', 'OPS-020204'),
            ('JWB-00562', 'RSP-0103', 'PRT-0203', 'OPS-020305'),
            ('JWB-00563', 'RSP-0103', 'PRT-0204', 'OPS-020404'),
            ('JWB-00564', 'RSP-0103', 'PRT-0205', 'OPS-020504'),
            ('JWB-00565', 'RSP-0104', 'PRT-0201', 'OPS-020101'),
            ('JWB-00566', 'RSP-0104', 'PRT-0202', 'OPS-020202'),
            ('JWB-00567', 'RSP-0104', 'PRT-0203', 'OPS-020304'),
            ('JWB-00568', 'RSP-0104', 'PRT-0204', 'OPS-020403'),
            ('JWB-00569', 'RSP-0104', 'PRT-0205', 'OPS-020502'),
            ('JWB-00570', 'RSP-0105', 'PRT-0201', 'OPS-020105'),
            ('JWB-00571', 'RSP-0105', 'PRT-0202', 'OPS-020204'),
            ('JWB-00572', 'RSP-0105', 'PRT-0203', 'OPS-020303'),
            ('JWB-00573', 'RSP-0105', 'PRT-0204', 'OPS-020403'),
            ('JWB-00574', 'RSP-0105', 'PRT-0205', 'OPS-020502'),
            ('JWB-00575', 'RSP-0106', 'PRT-0201', 'OPS-020105'),
            ('JWB-00576', 'RSP-0106', 'PRT-0202', 'OPS-020202'),
            ('JWB-00577', 'RSP-0106', 'PRT-0203', 'OPS-020303'),
            ('JWB-00578', 'RSP-0106', 'PRT-0204', 'OPS-020404'),
            ('JWB-00579', 'RSP-0106', 'PRT-0205', 'OPS-020505'),
            ('JWB-00580', 'RSP-0107', 'PRT-0201', 'OPS-020102'),
            ('JWB-00581', 'RSP-0107', 'PRT-0202', 'OPS-020203'),
            ('JWB-00582', 'RSP-0107', 'PRT-0203', 'OPS-020303'),
            ('JWB-00583', 'RSP-0107', 'PRT-0204', 'OPS-020405'),
            ('JWB-00584', 'RSP-0107', 'PRT-0205', 'OPS-020504'),
            ('JWB-00585', 'RSP-0108', 'PRT-0201', 'OPS-020102'),
            ('JWB-00586', 'RSP-0108', 'PRT-0202', 'OPS-020204'),
            ('JWB-00587', 'RSP-0108', 'PRT-0203', 'OPS-020305'),
            ('JWB-00588', 'RSP-0108', 'PRT-0204', 'OPS-020403'),
            ('JWB-00589', 'RSP-0108', 'PRT-0205', 'OPS-020504'),
            ('JWB-00590', 'RSP-0109', 'PRT-0201', 'OPS-020101'),
            ('JWB-00591', 'RSP-0109', 'PRT-0202', 'OPS-020205'),
            ('JWB-00592', 'RSP-0109', 'PRT-0203', 'OPS-020303'),
            ('JWB-00593', 'RSP-0109', 'PRT-0204', 'OPS-020404'),
            ('JWB-00594', 'RSP-0109', 'PRT-0205', 'OPS-020504'),
            ('JWB-00595', 'RSP-0110', 'PRT-0201', 'OPS-020102'),
            ('JWB-00596', 'RSP-0110', 'PRT-0202', 'OPS-020203'),
            ('JWB-00597', 'RSP-0110', 'PRT-0203', 'OPS-020304'),
            ('JWB-00598', 'RSP-0110', 'PRT-0204', 'OPS-020403'),
            ('JWB-00599', 'RSP-0110', 'PRT-0205', 'OPS-020503'),
            ('JWB-00600', 'RSP-0111', 'PRT-0201', 'OPS-020102'),
            ('JWB-00601', 'RSP-0111', 'PRT-0202', 'OPS-020202'),
            ('JWB-00602', 'RSP-0111', 'PRT-0203', 'OPS-020304'),
            ('JWB-00603', 'RSP-0111', 'PRT-0204', 'OPS-020401'),
            ('JWB-00604', 'RSP-0111', 'PRT-0205', 'OPS-020505'),
            ('JWB-00605', 'RSP-0112', 'PRT-0201', 'OPS-020101'),
            ('JWB-00606', 'RSP-0112', 'PRT-0202', 'OPS-020201'),
            ('JWB-00607', 'RSP-0112', 'PRT-0203', 'OPS-020301'),
            ('JWB-00608', 'RSP-0112', 'PRT-0204', 'OPS-020402'),
            ('JWB-00609', 'RSP-0112', 'PRT-0205', 'OPS-020505'),
            ('JWB-00610', 'RSP-0113', 'PRT-0201', 'OPS-020104'),
            ('JWB-00611', 'RSP-0113', 'PRT-0202', 'OPS-020204'),
            ('JWB-00612', 'RSP-0113', 'PRT-0203', 'OPS-020301'),
            ('JWB-00613', 'RSP-0113', 'PRT-0204', 'OPS-020404'),
            ('JWB-00614', 'RSP-0113', 'PRT-0205', 'OPS-020503'),
            ('JWB-00615', 'RSP-0114', 'PRT-0201', 'OPS-020102'),
            ('JWB-00616', 'RSP-0114', 'PRT-0203', 'OPS-020301'),
            ('JWB-00617', 'RSP-0114', 'PRT-0204', 'OPS-020404'),
            ('JWB-00618', 'RSP-0114', 'PRT-0205', 'OPS-020504'),
            ('JWB-00619', 'RSP-0115', 'PRT-0201', 'OPS-020102'),
            ('JWB-00620', 'RSP-0115', 'PRT-0202', 'OPS-020201'),
            ('JWB-00621', 'RSP-0115', 'PRT-0203', 'OPS-020304'),
            ('JWB-00622', 'RSP-0115', 'PRT-0204', 'OPS-020405'),
            ('JWB-00623', 'RSP-0115', 'PRT-0205', 'OPS-020502'),
            ('JWB-00624', 'RSP-0116', 'PRT-0201', 'OPS-020104'),
            ('JWB-00625', 'RSP-0116', 'PRT-0202', 'OPS-020201'),
            ('JWB-00626', 'RSP-0116', 'PRT-0203', 'OPS-020304'),
            ('JWB-00627', 'RSP-0116', 'PRT-0204', 'OPS-020402'),
            ('JWB-00628', 'RSP-0116', 'PRT-0205', 'OPS-020503'),
            ('JWB-00629', 'RSP-0117', 'PRT-0201', 'OPS-020102'),
            ('JWB-00630', 'RSP-0117', 'PRT-0202', 'OPS-020203'),
            ('JWB-00631', 'RSP-0117', 'PRT-0203', 'OPS-020301'),
            ('JWB-00632', 'RSP-0117', 'PRT-0204', 'OPS-020404'),
            ('JWB-00633', 'RSP-0117', 'PRT-0205', 'OPS-020504'),
            ('JWB-00634', 'RSP-0118', 'PRT-0201', 'OPS-020101'),
            ('JWB-00635', 'RSP-0118', 'PRT-0202', 'OPS-020201'),
            ('JWB-00636', 'RSP-0118', 'PRT-0203', 'OPS-020303'),
            ('JWB-00637', 'RSP-0118', 'PRT-0204', 'OPS-020405'),
            ('JWB-00638', 'RSP-0118', 'PRT-0205', 'OPS-020505'),
            ('JWB-00639', 'RSP-0119', 'PRT-0201', 'OPS-020102'),
            ('JWB-00640', 'RSP-0119', 'PRT-0202', 'OPS-020205'),
            ('JWB-00641', 'RSP-0119', 'PRT-0203', 'OPS-020302'),
            ('JWB-00642', 'RSP-0119', 'PRT-0204', 'OPS-020405'),
            ('JWB-00643', 'RSP-0119', 'PRT-0205', 'OPS-020504'),
            ('JWB-00644', 'RSP-0120', 'PRT-0201', 'OPS-020101'),
            ('JWB-00645', 'RSP-0120', 'PRT-0202', 'OPS-020204'),
            ('JWB-00646', 'RSP-0120', 'PRT-0203', 'OPS-020302'),
            ('JWB-00647', 'RSP-0120', 'PRT-0204', 'OPS-020403'),
            ('JWB-00648', 'RSP-0120', 'PRT-0205', 'OPS-020505'),
            ('JWB-00649', 'RSP-0121', 'PRT-0201', 'OPS-020105'),
            ('JWB-00650', 'RSP-0121', 'PRT-0202', 'OPS-020204'),
            ('JWB-00651', 'RSP-0121', 'PRT-0203', 'OPS-020304'),
            ('JWB-00652', 'RSP-0121', 'PRT-0204', 'OPS-020404'),
            ('JWB-00653', 'RSP-0121', 'PRT-0205', 'OPS-020504'),
            ('JWB-00654', 'RSP-0122', 'PRT-0201', 'OPS-020104'),
            ('JWB-00655', 'RSP-0122', 'PRT-0202', 'OPS-020202'),
            ('JWB-00656', 'RSP-0122', 'PRT-0203', 'OPS-020303'),
            ('JWB-00657', 'RSP-0122', 'PRT-0204', 'OPS-020405'),
            ('JWB-00658', 'RSP-0122', 'PRT-0205', 'OPS-020503'),
            ('JWB-00659', 'RSP-0123', 'PRT-0201', 'OPS-020102'),
            ('JWB-00660', 'RSP-0123', 'PRT-0202', 'OPS-020201'),
            ('JWB-00661', 'RSP-0123', 'PRT-0203', 'OPS-020301'),
            ('JWB-00662', 'RSP-0123', 'PRT-0204', 'OPS-020404'),
            ('JWB-00663', 'RSP-0123', 'PRT-0205', 'OPS-020505'),
            ('JWB-00664', 'RSP-0124', 'PRT-0201', 'OPS-020101'),
            ('JWB-00665', 'RSP-0124', 'PRT-0202', 'OPS-020205'),
            ('JWB-00666', 'RSP-0124', 'PRT-0203', 'OPS-020301'),
            ('JWB-00667', 'RSP-0124', 'PRT-0204', 'OPS-020402'),
            ('JWB-00668', 'RSP-0124', 'PRT-0205', 'OPS-020504'),
            ('JWB-00669', 'RSP-0125', 'PRT-0201', 'OPS-020104'),
            ('JWB-00670', 'RSP-0125', 'PRT-0202', 'OPS-020204'),
            ('JWB-00671', 'RSP-0125', 'PRT-0203', 'OPS-020301'),
            ('JWB-00672', 'RSP-0125', 'PRT-0204', 'OPS-020403'),
            ('JWB-00673', 'RSP-0125', 'PRT-0205', 'OPS-020505'),
            ('JWB-00674', 'RSP-0126', 'PRT-0201', 'OPS-020102'),
            ('JWB-00675', 'RSP-0126', 'PRT-0202', 'OPS-020202'),
            ('JWB-00676', 'RSP-0126', 'PRT-0203', 'OPS-020305'),
            ('JWB-00677', 'RSP-0126', 'PRT-0204', 'OPS-020405'),
            ('JWB-00678', 'RSP-0126', 'PRT-0205', 'OPS-020505'),
            ('JWB-00679', 'RSP-0127', 'PRT-0201', 'OPS-020102'),
            ('JWB-00680', 'RSP-0127', 'PRT-0202', 'OPS-020203'),
            ('JWB-00681', 'RSP-0127', 'PRT-0203', 'OPS-020301'),
            ('JWB-00682', 'RSP-0127', 'PRT-0204', 'OPS-020405'),
            ('JWB-00683', 'RSP-0127', 'PRT-0205', 'OPS-020501'),
            ('JWB-00684', 'RSP-0128', 'PRT-0201', 'OPS-020102'),
            ('JWB-00685', 'RSP-0128', 'PRT-0202', 'OPS-020205'),
            ('JWB-00686', 'RSP-0128', 'PRT-0203', 'OPS-020303'),
            ('JWB-00687', 'RSP-0128', 'PRT-0204', 'OPS-020402'),
            ('JWB-00688', 'RSP-0129', 'PRT-0201', 'OPS-020102'),
            ('JWB-00689', 'RSP-0129', 'PRT-0202', 'OPS-020204'),
            ('JWB-00690', 'RSP-0129', 'PRT-0205', 'OPS-020504'),
            ('JWB-00691', 'RSP-0130', 'PRT-0201', 'OPS-020103'),
            ('JWB-00692', 'RSP-0130', 'PRT-0202', 'OPS-020205'),
            ('JWB-00693', 'RSP-0130', 'PRT-0203', 'OPS-020302'),
            ('JWB-00694', 'RSP-0130', 'PRT-0204', 'OPS-020404'),
            ('JWB-00695', 'RSP-0130', 'PRT-0205', 'OPS-020502'),
            ('JWB-00696', 'RSP-0131', 'PRT-0201', 'OPS-020105'),
            ('JWB-00697', 'RSP-0131', 'PRT-0202', 'OPS-020204'),
            ('JWB-00698', 'RSP-0131', 'PRT-0203', 'OPS-020302'),
            ('JWB-00699', 'RSP-0131', 'PRT-0204', 'OPS-020404'),
            ('JWB-00700', 'RSP-0131', 'PRT-0205', 'OPS-020501'),
            ('JWB-00701', 'RSP-0132', 'PRT-0201', 'OPS-020105'),
            ('JWB-00702', 'RSP-0132', 'PRT-0202', 'OPS-020203'),
            ('JWB-00703', 'RSP-0132', 'PRT-0203', 'OPS-020301'),
            ('JWB-00704', 'RSP-0132', 'PRT-0204', 'OPS-020403'),
            ('JWB-00705', 'RSP-0133', 'PRT-0201', 'OPS-020103'),
            ('JWB-00706', 'RSP-0133', 'PRT-0202', 'OPS-020204'),
            ('JWB-00707', 'RSP-0133', 'PRT-0203', 'OPS-020302'),
            ('JWB-00708', 'RSP-0133', 'PRT-0204', 'OPS-020403'),
            ('JWB-00709', 'RSP-0133', 'PRT-0205', 'OPS-020504'),
            ('JWB-00710', 'RSP-0134', 'PRT-0201', 'OPS-020104'),
            ('JWB-00711', 'RSP-0134', 'PRT-0202', 'OPS-020203'),
            ('JWB-00712', 'RSP-0134', 'PRT-0203', 'OPS-020301'),
            ('JWB-00713', 'RSP-0134', 'PRT-0204', 'OPS-020402'),
            ('JWB-00714', 'RSP-0134', 'PRT-0205', 'OPS-020504'),
            ('JWB-00715', 'RSP-0135', 'PRT-0201', 'OPS-020104'),
            ('JWB-00716', 'RSP-0135', 'PRT-0202', 'OPS-020203'),
            ('JWB-00717', 'RSP-0135', 'PRT-0203', 'OPS-020301'),
            ('JWB-00718', 'RSP-0135', 'PRT-0204', 'OPS-020404'),
            ('JWB-00719', 'RSP-0135', 'PRT-0205', 'OPS-020503'),
            ('JWB-00720', 'RSP-0136', 'PRT-0201', 'OPS-020105'),
            ('JWB-00721', 'RSP-0136', 'PRT-0202', 'OPS-020201'),
            ('JWB-00722', 'RSP-0136', 'PRT-0203', 'OPS-020304'),
            ('JWB-00723', 'RSP-0136', 'PRT-0205', 'OPS-020503'),
            ('JWB-00724', 'RSP-0137', 'PRT-0201', 'OPS-020102'),
            ('JWB-00725', 'RSP-0137', 'PRT-0202', 'OPS-020202'),
            ('JWB-00726', 'RSP-0137', 'PRT-0203', 'OPS-020303'),
            ('JWB-00727', 'RSP-0137', 'PRT-0204', 'OPS-020404'),
            ('JWB-00728', 'RSP-0137', 'PRT-0205', 'OPS-020502'),
            ('JWB-00729', 'RSP-0138', 'PRT-0201', 'OPS-020104'),
            ('JWB-00730', 'RSP-0138', 'PRT-0202', 'OPS-020201'),
            ('JWB-00731', 'RSP-0138', 'PRT-0203', 'OPS-020302'),
            ('JWB-00732', 'RSP-0138', 'PRT-0204', 'OPS-020405'),
            ('JWB-00733', 'RSP-0138', 'PRT-0205', 'OPS-020505'),
            ('JWB-00734', 'RSP-0139', 'PRT-0201', 'OPS-020104'),
            ('JWB-00735', 'RSP-0139', 'PRT-0202', 'OPS-020203'),
            ('JWB-00736', 'RSP-0139', 'PRT-0203', 'OPS-020303'),
            ('JWB-00737', 'RSP-0139', 'PRT-0204', 'OPS-020404'),
            ('JWB-00738', 'RSP-0139', 'PRT-0205', 'OPS-020504'),
            ('JWB-00739', 'RSP-0140', 'PRT-0201', 'OPS-020101'),
            ('JWB-00740', 'RSP-0140', 'PRT-0202', 'OPS-020203'),
            ('JWB-00741', 'RSP-0140', 'PRT-0203', 'OPS-020304'),
            ('JWB-00742', 'RSP-0140', 'PRT-0204', 'OPS-020403'),
            ('JWB-00743', 'RSP-0140', 'PRT-0205', 'OPS-020502'),
            ('JWB-00744', 'RSP-0141', 'PRT-0201', 'OPS-020104'),
            ('JWB-00745', 'RSP-0141', 'PRT-0202', 'OPS-020203'),
            ('JWB-00746', 'RSP-0141', 'PRT-0203', 'OPS-020301'),
            ('JWB-00747', 'RSP-0141', 'PRT-0204', 'OPS-020404'),
            ('JWB-00748', 'RSP-0141', 'PRT-0205', 'OPS-020504'),
            ('JWB-00749', 'RSP-0142', 'PRT-0201', 'OPS-020101'),
            ('JWB-00750', 'RSP-0142', 'PRT-0202', 'OPS-020202'),
            ('JWB-00751', 'RSP-0142', 'PRT-0203', 'OPS-020303'),
            ('JWB-00752', 'RSP-0142', 'PRT-0204', 'OPS-020403'),
            ('JWB-00753', 'RSP-0142', 'PRT-0205', 'OPS-020502'),
            ('JWB-00754', 'RSP-0143', 'PRT-0201', 'OPS-020104'),
            ('JWB-00755', 'RSP-0143', 'PRT-0202', 'OPS-020204'),
            ('JWB-00756', 'RSP-0143', 'PRT-0203', 'OPS-020303'),
            ('JWB-00757', 'RSP-0143', 'PRT-0204', 'OPS-020405'),
            ('JWB-00758', 'RSP-0143', 'PRT-0205', 'OPS-020504'),
            ('JWB-00759', 'RSP-0144', 'PRT-0201', 'OPS-020103'),
            ('JWB-00760', 'RSP-0144', 'PRT-0202', 'OPS-020204'),
            ('JWB-00761', 'RSP-0144', 'PRT-0203', 'OPS-020301'),
            ('JWB-00762', 'RSP-0144', 'PRT-0204', 'OPS-020404'),
            ('JWB-00763', 'RSP-0144', 'PRT-0205', 'OPS-020504'),
            ('JWB-00764', 'RSP-0145', 'PRT-0201', 'OPS-020103'),
            ('JWB-00765', 'RSP-0145', 'PRT-0202', 'OPS-020202'),
            ('JWB-00766', 'RSP-0145', 'PRT-0204', 'OPS-020404'),
            ('JWB-00767', 'RSP-0145', 'PRT-0205', 'OPS-020504'),
            ('JWB-00768', 'RSP-0146', 'PRT-0201', 'OPS-020102'),
            ('JWB-00769', 'RSP-0146', 'PRT-0202', 'OPS-020201'),
            ('JWB-00770', 'RSP-0146', 'PRT-0203', 'OPS-020303'),
            ('JWB-00771', 'RSP-0146', 'PRT-0204', 'OPS-020403'),
            ('JWB-00772', 'RSP-0146', 'PRT-0205', 'OPS-020503'),
            ('JWB-00773', 'RSP-0147', 'PRT-0201', 'OPS-020102'),
            ('JWB-00774', 'RSP-0147', 'PRT-0202', 'OPS-020202'),
            ('JWB-00775', 'RSP-0147', 'PRT-0203', 'OPS-020302'),
            ('JWB-00776', 'RSP-0147', 'PRT-0204', 'OPS-020403'),
            ('JWB-00777', 'RSP-0147', 'PRT-0205', 'OPS-020505'),
            ('JWB-00778', 'RSP-0148', 'PRT-0201', 'OPS-020105'),
            ('JWB-00779', 'RSP-0148', 'PRT-0202', 'OPS-020204'),
            ('JWB-00780', 'RSP-0148', 'PRT-0204', 'OPS-020405'),
            ('JWB-00781', 'RSP-0148', 'PRT-0205', 'OPS-020503'),
            ('JWB-00782', 'RSP-0149', 'PRT-0201', 'OPS-020103'),
            ('JWB-00783', 'RSP-0149', 'PRT-0202', 'OPS-020203'),
            ('JWB-00784', 'RSP-0149', 'PRT-0203', 'OPS-020301'),
            ('JWB-00785', 'RSP-0149', 'PRT-0204', 'OPS-020403'),
            ('JWB-00786', 'RSP-0149', 'PRT-0205', 'OPS-020503'),
            ('JWB-00787', 'RSP-0150', 'PRT-0201', 'OPS-020104'),
            ('JWB-00788', 'RSP-0150', 'PRT-0202', 'OPS-020203'),
            ('JWB-00789', 'RSP-0150', 'PRT-0203', 'OPS-020302'),
            ('JWB-00790', 'RSP-0150', 'PRT-0204', 'OPS-020404'),
            ('JWB-00791', 'RSP-0150', 'PRT-0205', 'OPS-020502'),
            ('JWB-00792', 'RSP-0151', 'PRT-0201', 'OPS-020102'),
            ('JWB-00793', 'RSP-0151', 'PRT-0202', 'OPS-020201'),
            ('JWB-00794', 'RSP-0151', 'PRT-0203', 'OPS-020301'),
            ('JWB-00795', 'RSP-0151', 'PRT-0204', 'OPS-020403'),
            ('JWB-00796', 'RSP-0151', 'PRT-0205', 'OPS-020505'),
            ('JWB-00797', 'RSP-0152', 'PRT-0201', 'OPS-020101'),
            ('JWB-00798', 'RSP-0152', 'PRT-0202', 'OPS-020201'),
            ('JWB-00799', 'RSP-0152', 'PRT-0203', 'OPS-020304'),
            ('JWB-00800', 'RSP-0152', 'PRT-0204', 'OPS-020403'),
            ('JWB-00801', 'RSP-0152', 'PRT-0205', 'OPS-020503'),
            ('JWB-00802', 'RSP-0153', 'PRT-0201', 'OPS-020104'),
            ('JWB-00803', 'RSP-0153', 'PRT-0202', 'OPS-020203'),
            ('JWB-00804', 'RSP-0153', 'PRT-0203', 'OPS-020301'),
            ('JWB-00805', 'RSP-0153', 'PRT-0204', 'OPS-020402'),
            ('JWB-00806', 'RSP-0153', 'PRT-0205', 'OPS-020503'),
            ('JWB-00807', 'RSP-0154', 'PRT-0201', 'OPS-020103'),
            ('JWB-00808', 'RSP-0154', 'PRT-0202', 'OPS-020201'),
            ('JWB-00809', 'RSP-0154', 'PRT-0203', 'OPS-020304'),
            ('JWB-00810', 'RSP-0154', 'PRT-0204', 'OPS-020404'),
            ('JWB-00811', 'RSP-0154', 'PRT-0205', 'OPS-020503'),
            ('JWB-00812', 'RSP-0155', 'PRT-0201', 'OPS-020101'),
            ('JWB-00813', 'RSP-0155', 'PRT-0202', 'OPS-020204'),
            ('JWB-00814', 'RSP-0155', 'PRT-0203', 'OPS-020301'),
            ('JWB-00815', 'RSP-0155', 'PRT-0204', 'OPS-020405'),
            ('JWB-00816', 'RSP-0155', 'PRT-0205', 'OPS-020504'),
            ('JWB-00817', 'RSP-0156', 'PRT-0201', 'OPS-020102'),
            ('JWB-00818', 'RSP-0156', 'PRT-0202', 'OPS-020205'),
            ('JWB-00819', 'RSP-0156', 'PRT-0203', 'OPS-020303'),
            ('JWB-00820', 'RSP-0156', 'PRT-0204', 'OPS-020404'),
            ('JWB-00821', 'RSP-0156', 'PRT-0205', 'OPS-020504'),
            ('JWB-00822', 'RSP-0157', 'PRT-0301', 'OPS-030103'),
            ('JWB-00823', 'RSP-0157', 'PRT-0302', 'OPS-030202'),
            ('JWB-00824', 'RSP-0157', 'PRT-0303', 'OPS-030304'),
            ('JWB-00825', 'RSP-0157', 'PRT-0304', 'OPS-030402'),
            ('JWB-00826', 'RSP-0158', 'PRT-0301', 'OPS-030103'),
            ('JWB-00827', 'RSP-0158', 'PRT-0302', 'OPS-030204'),
            ('JWB-00828', 'RSP-0158', 'PRT-0303', 'OPS-030305'),
            ('JWB-00829', 'RSP-0158', 'PRT-0304', 'OPS-030403'),
            ('JWB-00830', 'RSP-0159', 'PRT-0301', 'OPS-030103'),
            ('JWB-00831', 'RSP-0159', 'PRT-0302', 'OPS-030202'),
            ('JWB-00832', 'RSP-0159', 'PRT-0303', 'OPS-030304'),
            ('JWB-00833', 'RSP-0159', 'PRT-0304', 'OPS-030401'),
            ('JWB-00834', 'RSP-0160', 'PRT-0302', 'OPS-030205'),
            ('JWB-00835', 'RSP-0160', 'PRT-0303', 'OPS-030305'),
            ('JWB-00836', 'RSP-0160', 'PRT-0304', 'OPS-030402'),
            ('JWB-00837', 'RSP-0161', 'PRT-0301', 'OPS-030102'),
            ('JWB-00838', 'RSP-0161', 'PRT-0302', 'OPS-030201'),
            ('JWB-00839', 'RSP-0161', 'PRT-0303', 'OPS-030305'),
            ('JWB-00840', 'RSP-0161', 'PRT-0304', 'OPS-030403'),
            ('JWB-00841', 'RSP-0162', 'PRT-0301', 'OPS-030103'),
            ('JWB-00842', 'RSP-0162', 'PRT-0302', 'OPS-030203'),
            ('JWB-00843', 'RSP-0162', 'PRT-0303', 'OPS-030304'),
            ('JWB-00844', 'RSP-0162', 'PRT-0304', 'OPS-030404'),
            ('JWB-00845', 'RSP-0163', 'PRT-0301', 'OPS-030105'),
            ('JWB-00846', 'RSP-0163', 'PRT-0302', 'OPS-030205'),
            ('JWB-00847', 'RSP-0163', 'PRT-0303', 'OPS-030305'),
            ('JWB-00848', 'RSP-0163', 'PRT-0304', 'OPS-030403'),
            ('JWB-00849', 'RSP-0164', 'PRT-0301', 'OPS-030103'),
            ('JWB-00850', 'RSP-0164', 'PRT-0302', 'OPS-030204'),
            ('JWB-00851', 'RSP-0164', 'PRT-0303', 'OPS-030304'),
            ('JWB-00852', 'RSP-0164', 'PRT-0304', 'OPS-030405'),
            ('JWB-00853', 'RSP-0165', 'PRT-0301', 'OPS-030103'),
            ('JWB-00854', 'RSP-0165', 'PRT-0302', 'OPS-030203'),
            ('JWB-00855', 'RSP-0165', 'PRT-0303', 'OPS-030305'),
            ('JWB-00856', 'RSP-0165', 'PRT-0304', 'OPS-030402'),
            ('JWB-00857', 'RSP-0166', 'PRT-0301', 'OPS-030105'),
            ('JWB-00858', 'RSP-0166', 'PRT-0302', 'OPS-030201'),
            ('JWB-00859', 'RSP-0166', 'PRT-0303', 'OPS-030304'),
            ('JWB-00860', 'RSP-0166', 'PRT-0304', 'OPS-030405'),
            ('JWB-00861', 'RSP-0167', 'PRT-0301', 'OPS-030103'),
            ('JWB-00862', 'RSP-0167', 'PRT-0302', 'OPS-030202'),
            ('JWB-00863', 'RSP-0167', 'PRT-0303', 'OPS-030302'),
            ('JWB-00864', 'RSP-0167', 'PRT-0304', 'OPS-030403'),
            ('JWB-00865', 'RSP-0168', 'PRT-0301', 'OPS-030101'),
            ('JWB-00866', 'RSP-0168', 'PRT-0302', 'OPS-030203'),
            ('JWB-00867', 'RSP-0168', 'PRT-0304', 'OPS-030403'),
            ('JWB-00868', 'RSP-0169', 'PRT-0301', 'OPS-030103'),
            ('JWB-00869', 'RSP-0169', 'PRT-0302', 'OPS-030203'),
            ('JWB-00870', 'RSP-0169', 'PRT-0303', 'OPS-030302'),
            ('JWB-00871', 'RSP-0169', 'PRT-0304', 'OPS-030405'),
            ('JWB-00872', 'RSP-0170', 'PRT-0301', 'OPS-030105'),
            ('JWB-00873', 'RSP-0170', 'PRT-0302', 'OPS-030201'),
            ('JWB-00874', 'RSP-0170', 'PRT-0303', 'OPS-030304'),
            ('JWB-00875', 'RSP-0170', 'PRT-0304', 'OPS-030404'),
            ('JWB-00876', 'RSP-0171', 'PRT-0301', 'OPS-030103'),
            ('JWB-00877', 'RSP-0171', 'PRT-0302', 'OPS-030204'),
            ('JWB-00878', 'RSP-0171', 'PRT-0303', 'OPS-030304'),
            ('JWB-00879', 'RSP-0171', 'PRT-0304', 'OPS-030401'),
            ('JWB-00880', 'RSP-0172', 'PRT-0301', 'OPS-030101'),
            ('JWB-00881', 'RSP-0172', 'PRT-0302', 'OPS-030201'),
            ('JWB-00882', 'RSP-0172', 'PRT-0303', 'OPS-030304'),
            ('JWB-00883', 'RSP-0172', 'PRT-0304', 'OPS-030405'),
            ('JWB-00884', 'RSP-0173', 'PRT-0301', 'OPS-030104'),
            ('JWB-00885', 'RSP-0173', 'PRT-0302', 'OPS-030201'),
            ('JWB-00886', 'RSP-0173', 'PRT-0303', 'OPS-030304'),
            ('JWB-00887', 'RSP-0173', 'PRT-0304', 'OPS-030401'),
            ('JWB-00888', 'RSP-0174', 'PRT-0301', 'OPS-030103'),
            ('JWB-00889', 'RSP-0174', 'PRT-0302', 'OPS-030203'),
            ('JWB-00890', 'RSP-0174', 'PRT-0303', 'OPS-030305'),
            ('JWB-00891', 'RSP-0174', 'PRT-0304', 'OPS-030403'),
            ('JWB-00892', 'RSP-0175', 'PRT-0302', 'OPS-030202'),
            ('JWB-00893', 'RSP-0175', 'PRT-0303', 'OPS-030304'),
            ('JWB-00894', 'RSP-0175', 'PRT-0304', 'OPS-030403'),
            ('JWB-00895', 'RSP-0176', 'PRT-0301', 'OPS-030102'),
            ('JWB-00896', 'RSP-0176', 'PRT-0302', 'OPS-030203'),
            ('JWB-00897', 'RSP-0176', 'PRT-0303', 'OPS-030301'),
            ('JWB-00898', 'RSP-0176', 'PRT-0304', 'OPS-030401'),
            ('JWB-00899', 'RSP-0177', 'PRT-0301', 'OPS-030101'),
            ('JWB-00900', 'RSP-0177', 'PRT-0302', 'OPS-030202'),
            ('JWB-00901', 'RSP-0177', 'PRT-0303', 'OPS-030304'),
            ('JWB-00902', 'RSP-0177', 'PRT-0304', 'OPS-030401'),
            ('JWB-00903', 'RSP-0178', 'PRT-0301', 'OPS-030103'),
            ('JWB-00904', 'RSP-0178', 'PRT-0302', 'OPS-030202'),
            ('JWB-00905', 'RSP-0178', 'PRT-0304', 'OPS-030405'),
            ('JWB-00906', 'RSP-0179', 'PRT-0301', 'OPS-030103'),
            ('JWB-00907', 'RSP-0179', 'PRT-0302', 'OPS-030204'),
            ('JWB-00908', 'RSP-0179', 'PRT-0303', 'OPS-030304'),
            ('JWB-00909', 'RSP-0179', 'PRT-0304', 'OPS-030401'),
            ('JWB-00910', 'RSP-0180', 'PRT-0301', 'OPS-030103'),
            ('JWB-00911', 'RSP-0180', 'PRT-0302', 'OPS-030201'),
            ('JWB-00912', 'RSP-0180', 'PRT-0303', 'OPS-030304'),
            ('JWB-00913', 'RSP-0180', 'PRT-0304', 'OPS-030403'),
            ('JWB-00914', 'RSP-0181', 'PRT-0301', 'OPS-030102'),
            ('JWB-00915', 'RSP-0181', 'PRT-0302', 'OPS-030203'),
            ('JWB-00916', 'RSP-0181', 'PRT-0303', 'OPS-030304'),
            ('JWB-00917', 'RSP-0181', 'PRT-0304', 'OPS-030405'),
            ('JWB-00918', 'RSP-0182', 'PRT-0301', 'OPS-030104'),
            ('JWB-00919', 'RSP-0182', 'PRT-0302', 'OPS-030201'),
            ('JWB-00920', 'RSP-0182', 'PRT-0303', 'OPS-030305'),
            ('JWB-00921', 'RSP-0182', 'PRT-0304', 'OPS-030403'),
            ('JWB-00922', 'RSP-0183', 'PRT-0301', 'OPS-030104'),
            ('JWB-00923', 'RSP-0183', 'PRT-0302', 'OPS-030204'),
            ('JWB-00924', 'RSP-0183', 'PRT-0303', 'OPS-030305'),
            ('JWB-00925', 'RSP-0183', 'PRT-0304', 'OPS-030402'),
            ('JWB-00926', 'RSP-0184', 'PRT-0301', 'OPS-030103'),
            ('JWB-00927', 'RSP-0184', 'PRT-0302', 'OPS-030203'),
            ('JWB-00928', 'RSP-0184', 'PRT-0304', 'OPS-030402'),
            ('JWB-00929', 'RSP-0185', 'PRT-0301', 'OPS-030103'),
            ('JWB-00930', 'RSP-0185', 'PRT-0302', 'OPS-030202'),
            ('JWB-00931', 'RSP-0185', 'PRT-0303', 'OPS-030304'),
            ('JWB-00932', 'RSP-0185', 'PRT-0304', 'OPS-030401'),
            ('JWB-00933', 'RSP-0186', 'PRT-0301', 'OPS-030101'),
            ('JWB-00934', 'RSP-0186', 'PRT-0302', 'OPS-030203'),
            ('JWB-00935', 'RSP-0186', 'PRT-0303', 'OPS-030304'),
            ('JWB-00936', 'RSP-0186', 'PRT-0304', 'OPS-030405'),
            ('JWB-00937', 'RSP-0187', 'PRT-0301', 'OPS-030104'),
            ('JWB-00938', 'RSP-0187', 'PRT-0302', 'OPS-030201'),
            ('JWB-00939', 'RSP-0187', 'PRT-0303', 'OPS-030304'),
            ('JWB-00940', 'RSP-0187', 'PRT-0304', 'OPS-030401'),
            ('JWB-00941', 'RSP-0188', 'PRT-0301', 'OPS-030103'),
            ('JWB-00942', 'RSP-0188', 'PRT-0302', 'OPS-030205'),
            ('JWB-00943', 'RSP-0188', 'PRT-0303', 'OPS-030304'),
            ('JWB-00944', 'RSP-0188', 'PRT-0304', 'OPS-030404'),
            ('JWB-00945', 'RSP-0189', 'PRT-0301', 'OPS-030104'),
            ('JWB-00946', 'RSP-0189', 'PRT-0303', 'OPS-030304'),
            ('JWB-00947', 'RSP-0189', 'PRT-0304', 'OPS-030405'),
            ('JWB-00948', 'RSP-0190', 'PRT-0301', 'OPS-030101'),
            ('JWB-00949', 'RSP-0190', 'PRT-0302', 'OPS-030202'),
            ('JWB-00950', 'RSP-0190', 'PRT-0303', 'OPS-030304'),
            ('JWB-00951', 'RSP-0190', 'PRT-0304', 'OPS-030404'),
            ('JWB-00952', 'RSP-0191', 'PRT-0301', 'OPS-030103'),
            ('JWB-00953', 'RSP-0191', 'PRT-0302', 'OPS-030201'),
            ('JWB-00954', 'RSP-0191', 'PRT-0303', 'OPS-030305'),
            ('JWB-00955', 'RSP-0191', 'PRT-0304', 'OPS-030401'),
            ('JWB-00956', 'RSP-0192', 'PRT-0301', 'OPS-030103'),
            ('JWB-00957', 'RSP-0192', 'PRT-0302', 'OPS-030204'),
            ('JWB-00958', 'RSP-0192', 'PRT-0303', 'OPS-030304'),
            ('JWB-00959', 'RSP-0192', 'PRT-0304', 'OPS-030403'),
            ('JWB-00960', 'RSP-0193', 'PRT-0301', 'OPS-030104'),
            ('JWB-00961', 'RSP-0193', 'PRT-0302', 'OPS-030201'),
            ('JWB-00962', 'RSP-0193', 'PRT-0303', 'OPS-030303'),
            ('JWB-00963', 'RSP-0193', 'PRT-0304', 'OPS-030403'),
            ('JWB-00964', 'RSP-0194', 'PRT-0301', 'OPS-030105'),
            ('JWB-00965', 'RSP-0194', 'PRT-0302', 'OPS-030202'),
            ('JWB-00966', 'RSP-0194', 'PRT-0303', 'OPS-030304'),
            ('JWB-00967', 'RSP-0194', 'PRT-0304', 'OPS-030403'),
            ('JWB-00968', 'RSP-0195', 'PRT-0301', 'OPS-030102'),
            ('JWB-00969', 'RSP-0195', 'PRT-0302', 'OPS-030201'),
            ('JWB-00970', 'RSP-0195', 'PRT-0303', 'OPS-030304'),
            ('JWB-00971', 'RSP-0195', 'PRT-0304', 'OPS-030405'),
            ('JWB-00972', 'RSP-0196', 'PRT-0301', 'OPS-030104'),
            ('JWB-00973', 'RSP-0196', 'PRT-0302', 'OPS-030204'),
            ('JWB-00974', 'RSP-0196', 'PRT-0303', 'OPS-030303'),
            ('JWB-00975', 'RSP-0197', 'PRT-0301', 'OPS-030103'),
            ('JWB-00976', 'RSP-0197', 'PRT-0302', 'OPS-030202'),
            ('JWB-00977', 'RSP-0197', 'PRT-0303', 'OPS-030304'),
            ('JWB-00978', 'RSP-0197', 'PRT-0304', 'OPS-030403'),
            ('JWB-00979', 'RSP-0198', 'PRT-0301', 'OPS-030104'),
            ('JWB-00980', 'RSP-0198', 'PRT-0303', 'OPS-030304'),
            ('JWB-00981', 'RSP-0198', 'PRT-0304', 'OPS-030403'),
            ('JWB-00982', 'RSP-0199', 'PRT-0301', 'OPS-030105'),
            ('JWB-00983', 'RSP-0199', 'PRT-0302', 'OPS-030201'),
            ('JWB-00984', 'RSP-0199', 'PRT-0303', 'OPS-030305'),
            ('JWB-00985', 'RSP-0199', 'PRT-0304', 'OPS-030402'),
            ('JWB-00986', 'RSP-0200', 'PRT-0301', 'OPS-030102'),
            ('JWB-00987', 'RSP-0200', 'PRT-0302', 'OPS-030201'),
            ('JWB-00988', 'RSP-0200', 'PRT-0303', 'OPS-030303'),
            ('JWB-00989', 'RSP-0200', 'PRT-0304', 'OPS-030403'),
            ('JWB-00990', 'RSP-0201', 'PRT-0301', 'OPS-030104'),
            ('JWB-00991', 'RSP-0201', 'PRT-0302', 'OPS-030202'),
            ('JWB-00992', 'RSP-0201', 'PRT-0303', 'OPS-030305'),
            ('JWB-00993', 'RSP-0201', 'PRT-0304', 'OPS-030401'),
            ('JWB-00994', 'RSP-0202', 'PRT-0301', 'OPS-030105'),
            ('JWB-00995', 'RSP-0202', 'PRT-0302', 'OPS-030203'),
            ('JWB-00996', 'RSP-0203', 'PRT-0301', 'OPS-030104'),
            ('JWB-00997', 'RSP-0203', 'PRT-0302', 'OPS-030203'),
            ('JWB-00998', 'RSP-0203', 'PRT-0304', 'OPS-030405'),
            ('JWB-00999', 'RSP-0204', 'PRT-0301', 'OPS-030102'),
            ('JWB-01000', 'RSP-0204', 'PRT-0302', 'OPS-030203'),
            ('JWB-01001', 'RSP-0204', 'PRT-0303', 'OPS-030304'),
            ('JWB-01002', 'RSP-0204', 'PRT-0304', 'OPS-030402'),
            ('JWB-01003', 'RSP-0205', 'PRT-0301', 'OPS-030103'),
            ('JWB-01004', 'RSP-0205', 'PRT-0302', 'OPS-030202'),
            ('JWB-01005', 'RSP-0205', 'PRT-0303', 'OPS-030305'),
            ('JWB-01006', 'RSP-0205', 'PRT-0304', 'OPS-030401'),
            ('JWB-01007', 'RSP-0206', 'PRT-0301', 'OPS-030101'),
            ('JWB-01008', 'RSP-0206', 'PRT-0302', 'OPS-030204'),
            ('JWB-01009', 'RSP-0206', 'PRT-0303', 'OPS-030303'),
            ('JWB-01010', 'RSP-0206', 'PRT-0304', 'OPS-030404'),
            ('JWB-01011', 'RSP-0207', 'PRT-0301', 'OPS-030105'),
            ('JWB-01012', 'RSP-0207', 'PRT-0302', 'OPS-030201'),
            ('JWB-01013', 'RSP-0207', 'PRT-0303', 'OPS-030303'),
            ('JWB-01014', 'RSP-0207', 'PRT-0304', 'OPS-030404'),
            ('JWB-01015', 'RSP-0208', 'PRT-0301', 'OPS-030103'),
            ('JWB-01016', 'RSP-0208', 'PRT-0302', 'OPS-030204'),
            ('JWB-01017', 'RSP-0208', 'PRT-0303', 'OPS-030305'),
            ('JWB-01018', 'RSP-0208', 'PRT-0304', 'OPS-030403'),
            ('JWB-01019', 'RSP-0209', 'PRT-0301', 'OPS-030103'),
            ('JWB-01020', 'RSP-0209', 'PRT-0302', 'OPS-030202'),
            ('JWB-01021', 'RSP-0209', 'PRT-0303', 'OPS-030304'),
            ('JWB-01022', 'RSP-0209', 'PRT-0304', 'OPS-030401'),
            ('JWB-01023', 'RSP-0210', 'PRT-0301', 'OPS-030102'),
            ('JWB-01024', 'RSP-0210', 'PRT-0302', 'OPS-030202'),
            ('JWB-01025', 'RSP-0210', 'PRT-0303', 'OPS-030303'),
            ('JWB-01026', 'RSP-0210', 'PRT-0304', 'OPS-030401'),
            ('JWB-01027', 'RSP-0211', 'PRT-0301', 'OPS-030105'),
            ('JWB-01028', 'RSP-0211', 'PRT-0302', 'OPS-030201'),
            ('JWB-01029', 'RSP-0211', 'PRT-0303', 'OPS-030304'),
            ('JWB-01030', 'RSP-0212', 'PRT-0301', 'OPS-030104'),
            ('JWB-01031', 'RSP-0212', 'PRT-0302', 'OPS-030202'),
            ('JWB-01032', 'RSP-0212', 'PRT-0303', 'OPS-030304'),
            ('JWB-01033', 'RSP-0212', 'PRT-0304', 'OPS-030403'),
            ('JWB-01034', 'RSP-0213', 'PRT-0301', 'OPS-030105'),
            ('JWB-01035', 'RSP-0213', 'PRT-0302', 'OPS-030202'),
            ('JWB-01036', 'RSP-0213', 'PRT-0303', 'OPS-030304'),
            ('JWB-01037', 'RSP-0213', 'PRT-0304', 'OPS-030403'),
            ('JWB-01038', 'RSP-0214', 'PRT-0301', 'OPS-030103'),
            ('JWB-01039', 'RSP-0214', 'PRT-0303', 'OPS-030304'),
            ('JWB-01040', 'RSP-0214', 'PRT-0304', 'OPS-030403')
    ) AS v (ID_JAWABAN, ID_RESPONDEN, ID_PERTANYAAN, ID_OPSI)
) AS s
ON t.ID_JAWABAN = s.ID_JAWABAN
WHEN MATCHED THEN UPDATE SET
    ID_RESPONDEN = s.ID_RESPONDEN,
    ID_PERTANYAAN = s.ID_PERTANYAAN,
    ID_OPSI = s.ID_OPSI
WHEN NOT MATCHED THEN INSERT (ID_JAWABAN, ID_RESPONDEN, ID_PERTANYAAN, ID_OPSI)
    VALUES (s.ID_JAWABAN, s.ID_RESPONDEN, s.ID_PERTANYAAN, s.ID_OPSI);

-- DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT: 76 rows
MERGE INTO DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT AS t
USING (
    SELECT
        v.ID_HASIL AS ID_HASIL,
        v.ID_SURVEI AS ID_SURVEI,
        v.ID_PERTANYAAN AS ID_PERTANYAAN,
        v.ID_OPSI AS ID_OPSI,
        CAST(v.JUMLAH_RESPONDEN AS NUMBER(6,0)) AS JUMLAH_RESPONDEN,
        CAST(v.TOTAL_RESPONDEN_PERTANYAAN AS NUMBER(6,0)) AS TOTAL_RESPONDEN_PERTANYAAN,
        CAST(v.PERSENTASE_JAWABAN AS NUMBER(5,2)) AS PERSENTASE_JAWABAN,
        CAST(v.TANGGAL_AGREGASI AS DATE) AS TANGGAL_AGREGASI
    FROM (VALUES
            ('HSL-010101', 'SRV-01', 'PRT-0101', 'OPS-010101', 7, 80, 8.75, '2026-06-07'),
            ('HSL-010102', 'SRV-01', 'PRT-0101', 'OPS-010102', 5, 80, 6.25, '2026-06-07'),
            ('HSL-010103', 'SRV-01', 'PRT-0101', 'OPS-010103', 7, 80, 8.75, '2026-06-07'),
            ('HSL-010104', 'SRV-01', 'PRT-0101', 'OPS-010104', 34, 80, 42.50, '2026-06-07'),
            ('HSL-010105', 'SRV-01', 'PRT-0101', 'OPS-010105', 27, 80, 33.75, '2026-06-07'),
            ('HSL-010201', 'SRV-01', 'PRT-0102', 'OPS-010201', 1, 73, 1.37, '2026-06-07'),
            ('HSL-010202', 'SRV-01', 'PRT-0102', 'OPS-010202', 4, 73, 5.48, '2026-06-07'),
            ('HSL-010203', 'SRV-01', 'PRT-0102', 'OPS-010203', 12, 73, 16.44, '2026-06-07'),
            ('HSL-010204', 'SRV-01', 'PRT-0102', 'OPS-010204', 34, 73, 46.58, '2026-06-07'),
            ('HSL-010205', 'SRV-01', 'PRT-0102', 'OPS-010205', 22, 73, 30.14, '2026-06-07'),
            ('HSL-010301', 'SRV-01', 'PRT-0103', 'OPS-010301', 3, 80, 3.75, '2026-06-07'),
            ('HSL-010302', 'SRV-01', 'PRT-0103', 'OPS-010302', 7, 80, 8.75, '2026-06-07'),
            ('HSL-010303', 'SRV-01', 'PRT-0103', 'OPS-010303', 11, 80, 13.75, '2026-06-07'),
            ('HSL-010304', 'SRV-01', 'PRT-0103', 'OPS-010304', 34, 80, 42.50, '2026-06-07'),
            ('HSL-010305', 'SRV-01', 'PRT-0103', 'OPS-010305', 25, 80, 31.25, '2026-06-07'),
            ('HSL-010401', 'SRV-01', 'PRT-0104', 'OPS-010401', 0, 82, 0.00, '2026-06-07'),
            ('HSL-010402', 'SRV-01', 'PRT-0104', 'OPS-010402', 17, 82, 20.73, '2026-06-07'),
            ('HSL-010403', 'SRV-01', 'PRT-0104', 'OPS-010403', 9, 82, 10.98, '2026-06-07'),
            ('HSL-010404', 'SRV-01', 'PRT-0104', 'OPS-010404', 31, 82, 37.80, '2026-06-07'),
            ('HSL-010405', 'SRV-01', 'PRT-0104', 'OPS-010405', 25, 82, 30.49, '2026-06-07'),
            ('HSL-010501', 'SRV-01', 'PRT-0105', 'OPS-010501', 0, 81, 0.00, '2026-06-07'),
            ('HSL-010502', 'SRV-01', 'PRT-0105', 'OPS-010502', 2, 81, 2.47, '2026-06-07'),
            ('HSL-010503', 'SRV-01', 'PRT-0105', 'OPS-010503', 11, 81, 13.58, '2026-06-07'),
            ('HSL-010504', 'SRV-01', 'PRT-0105', 'OPS-010504', 28, 81, 34.57, '2026-06-07'),
            ('HSL-010505', 'SRV-01', 'PRT-0105', 'OPS-010505', 40, 81, 49.38, '2026-06-07'),
            ('HSL-010601', 'SRV-01', 'PRT-0106', 'OPS-010601', 14, 77, 18.18, '2026-06-07'),
            ('HSL-010602', 'SRV-01', 'PRT-0106', 'OPS-010602', 17, 77, 22.08, '2026-06-07'),
            ('HSL-010603', 'SRV-01', 'PRT-0106', 'OPS-010603', 16, 77, 20.78, '2026-06-07'),
            ('HSL-010604', 'SRV-01', 'PRT-0106', 'OPS-010604', 3, 77, 3.90, '2026-06-07'),
            ('HSL-010605', 'SRV-01', 'PRT-0106', 'OPS-010605', 21, 77, 27.27, '2026-06-07'),
            ('HSL-010606', 'SRV-01', 'PRT-0106', 'OPS-010606', 6, 77, 7.79, '2026-06-07'),
            ('HSL-020101', 'SRV-02', 'PRT-0201', 'OPS-020101', 16, 72, 22.22, '2026-07-22'),
            ('HSL-020102', 'SRV-02', 'PRT-0201', 'OPS-020102', 25, 72, 34.72, '2026-07-22'),
            ('HSL-020103', 'SRV-02', 'PRT-0201', 'OPS-020103', 7, 72, 9.72, '2026-07-22'),
            ('HSL-020104', 'SRV-02', 'PRT-0201', 'OPS-020104', 14, 72, 19.44, '2026-07-22'),
            ('HSL-020105', 'SRV-02', 'PRT-0201', 'OPS-020105', 10, 72, 13.89, '2026-07-22'),
            ('HSL-020201', 'SRV-02', 'PRT-0202', 'OPS-020201', 14, 70, 20.00, '2026-07-22'),
            ('HSL-020202', 'SRV-02', 'PRT-0202', 'OPS-020202', 9, 70, 12.86, '2026-07-22'),
            ('HSL-020203', 'SRV-02', 'PRT-0202', 'OPS-020203', 18, 70, 25.71, '2026-07-22'),
            ('HSL-020204', 'SRV-02', 'PRT-0202', 'OPS-020204', 21, 70, 30.00, '2026-07-22'),
            ('HSL-020205', 'SRV-02', 'PRT-0202', 'OPS-020205', 8, 70, 11.43, '2026-07-22'),
            ('HSL-020301', 'SRV-02', 'PRT-0203', 'OPS-020301', 22, 68, 32.35, '2026-07-22'),
            ('HSL-020302', 'SRV-02', 'PRT-0203', 'OPS-020302', 12, 68, 17.65, '2026-07-22'),
            ('HSL-020303', 'SRV-02', 'PRT-0203', 'OPS-020303', 18, 68, 26.47, '2026-07-22'),
            ('HSL-020304', 'SRV-02', 'PRT-0203', 'OPS-020304', 10, 68, 14.71, '2026-07-22'),
            ('HSL-020305', 'SRV-02', 'PRT-0203', 'OPS-020305', 6, 68, 8.82, '2026-07-22'),
            ('HSL-020401', 'SRV-02', 'PRT-0204', 'OPS-020401', 2, 69, 2.90, '2026-07-22'),
            ('HSL-020402', 'SRV-02', 'PRT-0204', 'OPS-020402', 6, 69, 8.70, '2026-07-22'),
            ('HSL-020403', 'SRV-02', 'PRT-0204', 'OPS-020403', 18, 69, 26.09, '2026-07-22'),
            ('HSL-020404', 'SRV-02', 'PRT-0204', 'OPS-020404', 27, 69, 39.13, '2026-07-22'),
            ('HSL-020405', 'SRV-02', 'PRT-0204', 'OPS-020405', 16, 69, 23.19, '2026-07-22'),
            ('HSL-020501', 'SRV-02', 'PRT-0205', 'OPS-020501', 3, 69, 4.35, '2026-07-22'),
            ('HSL-020502', 'SRV-02', 'PRT-0205', 'OPS-020502', 11, 69, 15.94, '2026-07-22'),
            ('HSL-020503', 'SRV-02', 'PRT-0205', 'OPS-020503', 18, 69, 26.09, '2026-07-22'),
            ('HSL-020504', 'SRV-02', 'PRT-0205', 'OPS-020504', 24, 69, 34.78, '2026-07-22'),
            ('HSL-020505', 'SRV-02', 'PRT-0205', 'OPS-020505', 13, 69, 18.84, '2026-07-22'),
            ('HSL-030101', 'SRV-03', 'PRT-0301', 'OPS-030101', 6, 56, 10.71, '2026-09-30'),
            ('HSL-030102', 'SRV-03', 'PRT-0301', 'OPS-030102', 7, 56, 12.50, '2026-09-30'),
            ('HSL-030103', 'SRV-03', 'PRT-0301', 'OPS-030103', 23, 56, 41.07, '2026-09-30'),
            ('HSL-030104', 'SRV-03', 'PRT-0301', 'OPS-030104', 11, 56, 19.64, '2026-09-30'),
            ('HSL-030105', 'SRV-03', 'PRT-0301', 'OPS-030105', 9, 56, 16.07, '2026-09-30'),
            ('HSL-030201', 'SRV-03', 'PRT-0302', 'OPS-030201', 15, 55, 27.27, '2026-09-30'),
            ('HSL-030202', 'SRV-03', 'PRT-0302', 'OPS-030202', 16, 55, 29.09, '2026-09-30'),
            ('HSL-030203', 'SRV-03', 'PRT-0302', 'OPS-030203', 12, 55, 21.82, '2026-09-30'),
            ('HSL-030204', 'SRV-03', 'PRT-0302', 'OPS-030204', 9, 55, 16.36, '2026-09-30'),
            ('HSL-030205', 'SRV-03', 'PRT-0302', 'OPS-030205', 3, 55, 5.45, '2026-09-30'),
            ('HSL-030301', 'SRV-03', 'PRT-0303', 'OPS-030301', 1, 53, 1.89, '2026-09-30'),
            ('HSL-030302', 'SRV-03', 'PRT-0303', 'OPS-030302', 2, 53, 3.77, '2026-09-30'),
            ('HSL-030303', 'SRV-03', 'PRT-0303', 'OPS-030303', 6, 53, 11.32, '2026-09-30'),
            ('HSL-030304', 'SRV-03', 'PRT-0303', 'OPS-030304', 31, 53, 58.49, '2026-09-30'),
            ('HSL-030305', 'SRV-03', 'PRT-0303', 'OPS-030305', 13, 53, 24.53, '2026-09-30'),
            ('HSL-030401', 'SRV-03', 'PRT-0304', 'OPS-030401', 13, 55, 23.64, '2026-09-30'),
            ('HSL-030402', 'SRV-03', 'PRT-0304', 'OPS-030402', 7, 55, 12.73, '2026-09-30'),
            ('HSL-030403', 'SRV-03', 'PRT-0304', 'OPS-030403', 19, 55, 34.55, '2026-09-30'),
            ('HSL-030404', 'SRV-03', 'PRT-0304', 'OPS-030404', 6, 55, 10.91, '2026-09-30'),
            ('HSL-030405', 'SRV-03', 'PRT-0304', 'OPS-030405', 10, 55, 18.18, '2026-09-30')
    ) AS v (ID_HASIL, ID_SURVEI, ID_PERTANYAAN, ID_OPSI, JUMLAH_RESPONDEN, TOTAL_RESPONDEN_PERTANYAAN, PERSENTASE_JAWABAN, TANGGAL_AGREGASI)
) AS s
ON t.ID_HASIL = s.ID_HASIL
WHEN MATCHED THEN UPDATE SET
    ID_SURVEI = s.ID_SURVEI,
    ID_PERTANYAAN = s.ID_PERTANYAAN,
    ID_OPSI = s.ID_OPSI,
    JUMLAH_RESPONDEN = s.JUMLAH_RESPONDEN,
    TOTAL_RESPONDEN_PERTANYAAN = s.TOTAL_RESPONDEN_PERTANYAAN,
    PERSENTASE_JAWABAN = s.PERSENTASE_JAWABAN,
    TANGGAL_AGREGASI = s.TANGGAL_AGREGASI
WHEN NOT MATCHED THEN INSERT (ID_HASIL, ID_SURVEI, ID_PERTANYAAN, ID_OPSI, JUMLAH_RESPONDEN, TOTAL_RESPONDEN_PERTANYAAN, PERSENTASE_JAWABAN, TANGGAL_AGREGASI)
    VALUES (s.ID_HASIL, s.ID_SURVEI, s.ID_PERTANYAAN, s.ID_OPSI, s.JUMLAH_RESPONDEN, s.TOTAL_RESPONDEN_PERTANYAAN, s.PERSENTASE_JAWABAN, s.TANGGAL_AGREGASI);

-- DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN: 9 rows
MERGE INTO DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN AS t
USING (
    SELECT
        v.ID_RENCANA_KERJA AS ID_RENCANA_KERJA,
        v.ID_SEKSI AS ID_SEKSI,
        CAST(v.TAHUN_RENCANA AS NUMBER(4,0)) AS TAHUN_RENCANA,
        v.TUJUAN_UMUM AS TUJUAN_UMUM,
        v.STATUS_PENGESAHAN AS STATUS_PENGESAHAN,
        CAST(v.TANGGAL_PENGESAHAN AS DATE) AS TANGGAL_PENGESAHAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('RKT-2026-01', 'SEK-01', 2026, 'Meningkatkan mutu perayaan liturgi dan keterlibatan petugas liturgi pada tahun 2026.', 'Disahkan', '2025-12-09', NULL),
            ('RKT-2026-02', 'SEK-02', 2026, 'Memperkuat pembinaan iman anak, remaja, dan dewasa sepanjang tahun 2026.', 'Disahkan', '2025-12-10', NULL),
            ('RKT-2026-03', 'SEK-03', 2026, 'Mendampingi calon pasangan dan keluarga agar semakin kuat dalam iman pada tahun 2026.', 'Disahkan', '2025-12-11', NULL),
            ('RKT-2026-04', 'SEK-04', 2026, 'Mengembangkan iman, kepemimpinan, dan kepedulian orang muda pada tahun 2026.', 'Dalam Revisi', '2025-12-12', 'Direvisi karena penundaan pelatihan kepemimpinan dan perubahan jadwal semester.'),
            ('RKT-2026-05', 'SEK-05', 2026, 'Memperluas pelayanan sosial dan pemberdayaan ekonomi umat pada tahun 2026.', 'Disahkan', '2025-12-13', NULL),
            ('RKT-2026-06', 'SEK-06', 2026, 'Memperbaiki komunikasi dan dokumentasi paroki melalui relawan yang terlatih pada tahun 2026.', 'Disahkan', '2025-12-14', NULL),
            ('RKT-2026-07', 'SEK-07', 2026, 'Menumbuhkan kebiasaan membaca dan mendalami Kitab Suci pada tahun 2026.', 'Disahkan', '2025-12-15', NULL),
            ('RKT-2026-08', 'SEK-08', 2026, 'Meningkatkan kesehatan umat dan masyarakat sekitar melalui penyuluhan dan layanan pada tahun 2026.', 'Disahkan', '2025-12-16', NULL),
            ('RKT-2026-09', 'SEK-09', 2026, 'Menjaga tata kelola administrasi, data, dan keuangan paroki yang tertib pada tahun 2026.', 'Disahkan', '2025-12-17', NULL)
    ) AS v (ID_RENCANA_KERJA, ID_SEKSI, TAHUN_RENCANA, TUJUAN_UMUM, STATUS_PENGESAHAN, TANGGAL_PENGESAHAN, KETERANGAN)
) AS s
ON t.ID_RENCANA_KERJA = s.ID_RENCANA_KERJA
WHEN MATCHED THEN UPDATE SET
    ID_SEKSI = s.ID_SEKSI,
    TAHUN_RENCANA = s.TAHUN_RENCANA,
    TUJUAN_UMUM = s.TUJUAN_UMUM,
    STATUS_PENGESAHAN = s.STATUS_PENGESAHAN,
    TANGGAL_PENGESAHAN = s.TANGGAL_PENGESAHAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_RENCANA_KERJA, ID_SEKSI, TAHUN_RENCANA, TUJUAN_UMUM, STATUS_PENGESAHAN, TANGGAL_PENGESAHAN, KETERANGAN)
    VALUES (s.ID_RENCANA_KERJA, s.ID_SEKSI, s.TAHUN_RENCANA, s.TUJUAN_UMUM, s.STATUS_PENGESAHAN, s.TANGGAL_PENGESAHAN, s.KETERANGAN);

-- DATA_OPERASIONAL.RENCANA_KEGIATAN: 42 rows
MERGE INTO DATA_OPERASIONAL.RENCANA_KEGIATAN AS t
USING (
    SELECT
        v.ID_RENCANA AS ID_RENCANA,
        v.ID_RENCANA_KERJA AS ID_RENCANA_KERJA,
        v.NAMA_PROGRAM AS NAMA_PROGRAM,
        v.TUJUAN_PROGRAM AS TUJUAN_PROGRAM,
        CAST(v.TANGGAL_RENCANA AS DATE) AS TANGGAL_RENCANA,
        v.STATUS_PELAKSANAAN AS STATUS_PELAKSANAAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('RNC-001', 'RKT-2026-01', 'Pelatihan Lektor dan Pemazmur', 'Meningkatkan kemampuan membaca Kitab Suci dan melagukan mazmur dalam Misa.', '2026-02-14', 'Terlaksana', NULL),
            ('RNC-002', 'RKT-2026-01', 'Rangkaian Perayaan Pekan Suci dan Paskah', 'Menyiapkan dan melaksanakan perayaan Kamis Putih sampai Minggu Paskah dengan khidmat.', '2026-04-02', 'Terlaksana', NULL),
            ('RNC-003', 'RKT-2026-01', 'Pelatihan Putra-Putri Altar Baru', 'Membekali anak-anak calon putra-putri altar dengan pengetahuan dan keterampilan melayani di altar.', '2026-06-20', 'Terlaksana', NULL),
            ('RNC-004', 'RKT-2026-01', 'Pelatihan Operator Tata Suara dan Perangkat Baru', 'Melatih petugas mengoperasikan tata suara dan memperbarui perangkat yang rusak.', '2026-07-18', 'Ditunda', 'Ditunda menunggu penawaran harga dari penyedia perangkat.'),
            ('RNC-005', 'RKT-2026-01', 'Latihan Koor Gabungan Persiapan Natal', 'Menyiapkan koor gabungan lintas lingkungan untuk Misa Natal.', '2026-11-07', 'Direncanakan', NULL),
            ('RNC-006', 'RKT-2026-01', 'Misa Syukur Hari Ulang Tahun Paroki', 'Merayakan ulang tahun paroki bersama seluruh umat dalam suasana syukur.', '2026-10-11', 'Direncanakan', NULL),
            ('RNC-007', 'RKT-2026-02', 'Katekese Persiapan Komuni Pertama', 'Mempersiapkan anak-anak menerima Komuni Pertama melalui pengajaran iman yang menyenangkan.', '2026-02-07', 'Terlaksana', NULL),
            ('RNC-008', 'RKT-2026-02', 'Pendampingan Calon Baptis Dewasa', 'Mendampingi katekumen dewasa menuju sakramen baptis.', '2026-01-24', 'Terlaksana', NULL),
            ('RNC-009', 'RKT-2026-02', 'Katekese Persiapan Sakramen Krisma', 'Membekali remaja dan orang muda untuk menerima sakramen krisma.', '2026-07-04', 'Terlaksana', NULL),
            ('RNC-010', 'RKT-2026-02', 'Pelatihan Katekis Lingkungan', 'Membekali katekis lingkungan dengan metode pendampingan iman yang sederhana.', '2026-05-23', 'Dibatalkan', 'Dibatalkan karena jumlah pendaftar terlalu sedikit, akan diusulkan kembali pada rencana tahun berikutnya.'),
            ('RNC-011', 'RKT-2026-02', 'Pekan Katekese Anak', 'Mengenalkan kisah Kitab Suci kepada anak-anak melalui permainan dan cerita.', '2026-11-14', 'Direncanakan', NULL),
            ('RNC-012', 'RKT-2026-03', 'Kursus Persiapan Perkawinan Angkatan I', 'Membekali calon pasangan dengan pemahaman tentang perkawinan Katolik dan kehidupan berkeluarga.', '2026-03-14', 'Terlaksana', NULL),
            ('RNC-013', 'RKT-2026-03', 'Rekoleksi Pasangan Suami Istri', 'Menguatkan relasi pasangan melalui doa, refleksi, dan berbagi pengalaman.', '2026-06-06', 'Terlaksana', NULL),
            ('RNC-014', 'RKT-2026-03', 'Seminar Pengasuhan Anak di Era Digital', 'Membantu orang tua mendampingi anak dalam penggunaan gawai dan media sosial.', '2026-09-05', 'Terlaksana', NULL),
            ('RNC-015', 'RKT-2026-03', 'Misa Syukur Ulang Tahun Perkawinan', 'Mensyukuri perjalanan pasangan yang merayakan ulang tahun perkawinan pada tahun ini.', '2026-10-24', 'Direncanakan', NULL),
            ('RNC-016', 'RKT-2026-04', 'Retret Orang Muda Katolik', 'Memberi ruang bagi orang muda untuk berefleksi dan memperdalam relasi dengan Tuhan.', '2026-04-25', 'Terlaksana', NULL),
            ('RNC-017', 'RKT-2026-04', 'Turnamen Futsal Antarlingkungan', 'Mempererat persaudaraan antarlingkungan melalui olahraga.', '2026-06-27', 'Terlaksana', NULL),
            ('RNC-018', 'RKT-2026-04', 'Pelatihan Kepemimpinan Orang Muda', 'Melatih orang muda mengelola kegiatan dan memimpin tim pelayanan.', '2026-08-22', 'Ditunda', 'Ditunda karena bertepatan dengan ujian sekolah, jadwal baru ditetapkan setelah rapat seksi.'),
            ('RNC-019', 'RKT-2026-04', 'Bakti Sosial Orang Muda di Panti Asuhan', 'Menumbuhkan kepedulian orang muda melalui kunjungan dan kegiatan bersama anak-anak panti asuhan.', '2026-09-19', 'Terlaksana', NULL),
            ('RNC-020', 'RKT-2026-04', 'Perkemahan Orang Muda Akhir Tahun', 'Membangun kebersamaan orang muda menjelang akhir tahun.', '2026-12-12', 'Direncanakan', NULL),
            ('RNC-021', 'RKT-2026-05', 'Penyaluran Bantuan Aksi Puasa Pembangunan', 'Menyalurkan hasil Aksi Puasa Pembangunan kepada keluarga dan lembaga yang membutuhkan.', '2026-04-11', 'Terlaksana', NULL),
            ('RNC-022', 'RKT-2026-05', 'Pelatihan Kewirausahaan Usaha Mikro Umat', 'Membekali umat dengan keterampilan merintis dan mengelola usaha kecil.', '2026-05-30', 'Terlaksana', NULL),
            ('RNC-023', 'RKT-2026-05', 'Kunjungan dan Santunan Lansia', 'Mengunjungi dan menyantuni umat lanjut usia yang hidup sendiri atau kurang mampu.', '2026-07-11', 'Terlaksana', NULL),
            ('RNC-024', 'RKT-2026-05', 'Penyaluran Bantuan Korban Banjir', 'Menyalurkan dana solidaritas dan bantuan darurat kepada korban banjir.', '2026-07-26', 'Terlaksana', NULL),
            ('RNC-025', 'RKT-2026-05', 'Pasar Murah Menjelang Natal', 'Menyediakan kebutuhan pokok dengan harga terjangkau bagi keluarga yang membutuhkan.', '2026-12-05', 'Direncanakan', NULL),
            ('RNC-026', 'RKT-2026-05', 'Pelatihan Pengelolaan Keuangan Keluarga', 'Membantu keluarga menyusun anggaran dan menabung secara sehat.', '2026-09-12', 'Ditunda', 'Ditunda ke bulan November karena narasumber berhalangan.'),
            ('RNC-027', 'RKT-2026-06', 'Pelatihan Fotografi dan Videografi Liturgi', 'Melatih relawan mendokumentasikan perayaan secara santun dan berkualitas.', '2026-03-21', 'Terlaksana', NULL),
            ('RNC-028', 'RKT-2026-06', 'Lokakarya Penulisan Warta Paroki', 'Meningkatkan keterampilan relawan menulis berita dan warta paroki.', '2026-05-09', 'Terlaksana', NULL),
            ('RNC-029', 'RKT-2026-06', 'Pelatihan Siaran Langsung Misa', 'Melatih relawan mengoperasikan perangkat siaran langsung Misa.', '2026-08-15', 'Terlaksana', NULL),
            ('RNC-030', 'RKT-2026-06', 'Temu Relawan Media Paroki', 'Menyatukan relawan media untuk merencanakan liputan perayaan Natal.', '2026-11-21', 'Direncanakan', NULL),
            ('RNC-031', 'RKT-2026-07', 'Kursus Dasar Kitab Suci Angkatan I', 'Memperkenalkan struktur dan pesan pokok Kitab Suci kepada umat awam.', '2026-01-31', 'Terlaksana', NULL),
            ('RNC-032', 'RKT-2026-07', 'Perayaan Bulan Kitab Suci Nasional', 'Menghidupkan kebiasaan membaca Kitab Suci melalui ibadat dan sarasehan.', '2026-09-26', 'Terlaksana', NULL),
            ('RNC-033', 'RKT-2026-07', 'Lomba Cerdas Cermat Kitab Suci Antarlingkungan', 'Mengajak lingkungan berlomba memahami Kitab Suci dengan gembira.', '2026-09-20', 'Terlaksana', NULL),
            ('RNC-034', 'RKT-2026-07', 'Pendalaman Kitab Suci Masa Adven', 'Mendampingi umat mempersiapkan Natal melalui pendalaman Kitab Suci.', '2026-11-29', 'Direncanakan', NULL),
            ('RNC-035', 'RKT-2026-08', 'Pemeriksaan Kesehatan Gratis untuk Lansia', 'Memberi layanan pemeriksaan tekanan darah, gula darah, dan konsultasi bagi lansia.', '2026-05-16', 'Terlaksana', NULL),
            ('RNC-036', 'RKT-2026-08', 'Aksi Donor Darah Paroki', 'Mengajak umat berdonor darah untuk membantu sesama yang membutuhkan.', '2026-08-29', 'Terlaksana', NULL),
            ('RNC-037', 'RKT-2026-08', 'Pelatihan Pertolongan Pertama', 'Membekali relawan dengan keterampilan pertolongan pertama.', '2026-06-13', 'Dibatalkan', 'Dibatalkan karena instruktur tidak tersedia, dijadwalkan ulang pada tahun depan.'),
            ('RNC-038', 'RKT-2026-08', 'Penyuluhan Gizi Keluarga', 'Meningkatkan pengetahuan keluarga tentang gizi seimbang.', '2026-10-17', 'Direncanakan', NULL),
            ('RNC-039', 'RKT-2026-09', 'Rapat Kerja Pengurus Paroki', 'Menyusun arah dan prioritas pelayanan paroki tahun berjalan.', '2026-01-17', 'Terlaksana', NULL),
            ('RNC-040', 'RKT-2026-09', 'Pelatihan Pengelolaan Data Umat dan Pelindungan Privasi', 'Membekali petugas agar mengelola data umat dengan aman dan menghormati privasi.', '2026-07-25', 'Terlaksana', NULL),
            ('RNC-041', 'RKT-2026-09', 'Lokakarya Digitalisasi Arsip Paroki', 'Memindai dan menata arsip paroki agar mudah dicari dan aman.', '2026-08-08', 'Ditunda', 'Ditunda karena perangkat pemindai belum tersedia.'),
            ('RNC-042', 'RKT-2026-09', 'Rapat Evaluasi Semester dan Penyusunan Anggaran 2027', 'Mengevaluasi pelaksanaan program dan menyusun anggaran tahun berikutnya.', '2026-11-14', 'Direncanakan', NULL)
    ) AS v (ID_RENCANA, ID_RENCANA_KERJA, NAMA_PROGRAM, TUJUAN_PROGRAM, TANGGAL_RENCANA, STATUS_PELAKSANAAN, KETERANGAN)
) AS s
ON t.ID_RENCANA = s.ID_RENCANA
WHEN MATCHED THEN UPDATE SET
    ID_RENCANA_KERJA = s.ID_RENCANA_KERJA,
    NAMA_PROGRAM = s.NAMA_PROGRAM,
    TUJUAN_PROGRAM = s.TUJUAN_PROGRAM,
    TANGGAL_RENCANA = s.TANGGAL_RENCANA,
    STATUS_PELAKSANAAN = s.STATUS_PELAKSANAAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_RENCANA, ID_RENCANA_KERJA, NAMA_PROGRAM, TUJUAN_PROGRAM, TANGGAL_RENCANA, STATUS_PELAKSANAAN, KETERANGAN)
    VALUES (s.ID_RENCANA, s.ID_RENCANA_KERJA, s.NAMA_PROGRAM, s.TUJUAN_PROGRAM, s.TANGGAL_RENCANA, s.STATUS_PELAKSANAAN, s.KETERANGAN);

-- DATA_OPERASIONAL.ALOKASI_ANGGARAN: 117 rows
MERGE INTO DATA_OPERASIONAL.ALOKASI_ANGGARAN AS t
USING (
    SELECT
        v.ID_ALOKASI AS ID_ALOKASI,
        v.ID_RENCANA AS ID_RENCANA,
        v.ID_KATEGORI_BIAYA AS ID_KATEGORI_BIAYA,
        CAST(v.JUMLAH_ANGGARAN AS NUMBER(18,0)) AS JUMLAH_ANGGARAN,
        CAST(v.TANGGAL_PERSETUJUAN AS DATE) AS TANGGAL_PERSETUJUAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('ALK-001', 'RNC-001', 'KBY-01', 800000, '2025-12-09', NULL),
            ('ALK-002', 'RNC-001', 'KBY-04', 1500000, '2025-12-09', NULL),
            ('ALK-003', 'RNC-001', 'KBY-02', 500000, '2025-12-09', NULL),
            ('ALK-004', 'RNC-002', 'KBY-02', 6000000, '2025-12-09', NULL),
            ('ALK-005', 'RNC-002', 'KBY-01', 2000000, '2025-12-09', NULL),
            ('ALK-006', 'RNC-002', 'KBY-05', 500000, '2025-12-09', NULL),
            ('ALK-007', 'RNC-002', 'KBY-06', 1500000, '2025-12-09', NULL),
            ('ALK-008', 'RNC-003', 'KBY-01', 500000, '2025-12-09', NULL),
            ('ALK-009', 'RNC-003', 'KBY-02', 400000, '2025-12-09', NULL),
            ('ALK-010', 'RNC-004', 'KBY-06', 12000000, '2025-12-09', NULL),
            ('ALK-011', 'RNC-004', 'KBY-02', 1500000, '2025-12-09', NULL),
            ('ALK-012', 'RNC-005', 'KBY-01', 1500000, '2025-12-09', NULL),
            ('ALK-013', 'RNC-005', 'KBY-02', 700000, '2025-12-09', NULL),
            ('ALK-014', 'RNC-006', 'KBY-01', 7000000, '2025-12-09', NULL),
            ('ALK-015', 'RNC-006', 'KBY-05', 1200000, '2025-12-09', NULL),
            ('ALK-016', 'RNC-006', 'KBY-02', 2500000, '2025-12-09', NULL),
            ('ALK-017', 'RNC-007', 'KBY-02', 2500000, '2025-12-10', NULL),
            ('ALK-018', 'RNC-007', 'KBY-01', 1800000, '2025-12-10', NULL),
            ('ALK-019', 'RNC-007', 'KBY-04', 1200000, '2025-12-10', NULL),
            ('ALK-020', 'RNC-008', 'KBY-02', 1500000, '2025-12-10', NULL),
            ('ALK-021', 'RNC-008', 'KBY-01', 1000000, '2025-12-10', NULL),
            ('ALK-022', 'RNC-009', 'KBY-02', 2500000, '2025-12-10', NULL),
            ('ALK-023', 'RNC-009', 'KBY-01', 2000000, '2025-12-10', NULL),
            ('ALK-024', 'RNC-009', 'KBY-04', 1500000, '2025-12-10', NULL),
            ('ALK-025', 'RNC-010', 'KBY-04', 2500000, '2025-12-10', NULL),
            ('ALK-026', 'RNC-010', 'KBY-01', 900000, '2025-12-10', NULL),
            ('ALK-027', 'RNC-011', 'KBY-02', 2000000, '2025-12-10', NULL),
            ('ALK-028', 'RNC-011', 'KBY-01', 2500000, '2025-12-10', NULL),
            ('ALK-029', 'RNC-011', 'KBY-05', 500000, '2025-12-10', NULL),
            ('ALK-030', 'RNC-012', 'KBY-06', 3000000, '2025-12-11', NULL),
            ('ALK-031', 'RNC-012', 'KBY-01', 2200000, '2025-12-11', NULL),
            ('ALK-032', 'RNC-012', 'KBY-04', 2000000, '2025-12-11', NULL),
            ('ALK-033', 'RNC-012', 'KBY-02', 600000, '2025-12-11', NULL),
            ('ALK-034', 'RNC-013', 'KBY-01', 2500000, '2025-12-11', NULL),
            ('ALK-035', 'RNC-013', 'KBY-04', 1500000, '2025-12-11', NULL),
            ('ALK-036', 'RNC-013', 'KBY-02', 500000, '2025-12-11', NULL),
            ('ALK-037', 'RNC-014', 'KBY-04', 2000000, '2025-12-11', NULL),
            ('ALK-038', 'RNC-014', 'KBY-01', 2500000, '2025-12-11', NULL),
            ('ALK-039', 'RNC-014', 'KBY-05', 600000, '2025-12-11', NULL),
            ('ALK-040', 'RNC-015', 'KBY-01', 3000000, '2025-12-11', NULL),
            ('ALK-041', 'RNC-015', 'KBY-02', 800000, '2025-12-11', NULL),
            ('ALK-042', 'RNC-016', 'KBY-06', 5000000, '2025-12-12', NULL),
            ('ALK-043', 'RNC-016', 'KBY-01', 3200000, '2025-12-12', NULL),
            ('ALK-044', 'RNC-016', 'KBY-04', 1800000, '2025-12-12', NULL),
            ('ALK-045', 'RNC-016', 'KBY-03', 1500000, '2025-12-12', NULL),
            ('ALK-046', 'RNC-017', 'KBY-06', 2500000, '2025-12-12', NULL),
            ('ALK-047', 'RNC-017', 'KBY-01', 2500000, '2025-12-12', NULL),
            ('ALK-048', 'RNC-017', 'KBY-02', 800000, '2025-12-12', NULL),
            ('ALK-049', 'RNC-017', 'KBY-04', 600000, '2025-12-12', NULL),
            ('ALK-050', 'RNC-018', 'KBY-04', 2500000, '2025-12-12', NULL),
            ('ALK-051', 'RNC-018', 'KBY-01', 1500000, '2025-12-12', NULL),
            ('ALK-052', 'RNC-018', 'KBY-02', 600000, '2025-12-12', NULL),
            ('ALK-053', 'RNC-019', 'KBY-07', 1500000, '2025-12-12', NULL),
            ('ALK-054', 'RNC-019', 'KBY-03', 700000, '2025-12-12', NULL),
            ('ALK-055', 'RNC-019', 'KBY-01', 600000, '2025-12-12', NULL),
            ('ALK-056', 'RNC-020', 'KBY-06', 3000000, '2025-12-12', NULL),
            ('ALK-057', 'RNC-020', 'KBY-01', 3500000, '2025-12-12', NULL),
            ('ALK-058', 'RNC-020', 'KBY-03', 2000000, '2025-12-12', NULL),
            ('ALK-059', 'RNC-021', 'KBY-07', 12000000, '2025-12-13', NULL),
            ('ALK-060', 'RNC-021', 'KBY-05', 500000, '2025-12-13', NULL),
            ('ALK-061', 'RNC-021', 'KBY-01', 1500000, '2025-12-13', NULL),
            ('ALK-062', 'RNC-022', 'KBY-04', 3000000, '2025-12-13', NULL),
            ('ALK-063', 'RNC-022', 'KBY-02', 1500000, '2025-12-13', NULL),
            ('ALK-064', 'RNC-022', 'KBY-01', 1800000, '2025-12-13', NULL),
            ('ALK-065', 'RNC-023', 'KBY-07', 4000000, '2025-12-13', NULL),
            ('ALK-066', 'RNC-023', 'KBY-03', 800000, '2025-12-13', NULL),
            ('ALK-067', 'RNC-023', 'KBY-01', 700000, '2025-12-13', NULL),
            ('ALK-068', 'RNC-024', 'KBY-07', 10000000, '2025-12-13', NULL),
            ('ALK-069', 'RNC-024', 'KBY-03', 1500000, '2025-12-13', NULL),
            ('ALK-070', 'RNC-024', 'KBY-01', 1000000, '2025-12-13', NULL),
            ('ALK-071', 'RNC-025', 'KBY-07', 6000000, '2025-12-13', NULL),
            ('ALK-072', 'RNC-025', 'KBY-02', 1500000, '2025-12-13', NULL),
            ('ALK-073', 'RNC-025', 'KBY-05', 600000, '2025-12-13', NULL),
            ('ALK-074', 'RNC-026', 'KBY-04', 1500000, '2025-12-13', NULL),
            ('ALK-075', 'RNC-026', 'KBY-01', 1500000, '2025-12-13', NULL),
            ('ALK-076', 'RNC-026', 'KBY-02', 400000, '2025-12-13', NULL),
            ('ALK-077', 'RNC-027', 'KBY-04', 1500000, '2025-12-14', NULL),
            ('ALK-078', 'RNC-027', 'KBY-02', 600000, '2025-12-14', NULL),
            ('ALK-079', 'RNC-027', 'KBY-01', 500000, '2025-12-14', NULL),
            ('ALK-080', 'RNC-028', 'KBY-04', 1000000, '2025-12-14', NULL),
            ('ALK-081', 'RNC-028', 'KBY-01', 400000, '2025-12-14', NULL),
            ('ALK-082', 'RNC-029', 'KBY-06', 1500000, '2025-12-14', NULL),
            ('ALK-083', 'RNC-029', 'KBY-04', 800000, '2025-12-14', NULL),
            ('ALK-084', 'RNC-030', 'KBY-01', 500000, '2025-12-14', NULL),
            ('ALK-085', 'RNC-030', 'KBY-02', 300000, '2025-12-14', NULL),
            ('ALK-086', 'RNC-031', 'KBY-02', 1500000, '2025-12-15', NULL),
            ('ALK-087', 'RNC-031', 'KBY-04', 2000000, '2025-12-15', NULL),
            ('ALK-088', 'RNC-031', 'KBY-01', 1200000, '2025-12-15', NULL),
            ('ALK-089', 'RNC-032', 'KBY-01', 2500000, '2025-12-15', NULL),
            ('ALK-090', 'RNC-032', 'KBY-05', 800000, '2025-12-15', NULL),
            ('ALK-091', 'RNC-032', 'KBY-02', 1200000, '2025-12-15', NULL),
            ('ALK-092', 'RNC-033', 'KBY-02', 1500000, '2025-12-15', NULL),
            ('ALK-093', 'RNC-033', 'KBY-01', 2000000, '2025-12-15', NULL),
            ('ALK-094', 'RNC-033', 'KBY-04', 700000, '2025-12-15', NULL),
            ('ALK-095', 'RNC-034', 'KBY-02', 800000, '2025-12-15', NULL),
            ('ALK-096', 'RNC-034', 'KBY-01', 1200000, '2025-12-15', NULL),
            ('ALK-097', 'RNC-035', 'KBY-02', 3000000, '2025-12-16', NULL),
            ('ALK-098', 'RNC-035', 'KBY-01', 2000000, '2025-12-16', NULL),
            ('ALK-099', 'RNC-035', 'KBY-04', 1500000, '2025-12-16', NULL),
            ('ALK-100', 'RNC-036', 'KBY-01', 1800000, '2025-12-16', NULL),
            ('ALK-101', 'RNC-036', 'KBY-05', 500000, '2025-12-16', NULL),
            ('ALK-102', 'RNC-036', 'KBY-02', 700000, '2025-12-16', NULL),
            ('ALK-103', 'RNC-037', 'KBY-04', 1500000, '2025-12-16', NULL),
            ('ALK-104', 'RNC-037', 'KBY-02', 800000, '2025-12-16', NULL),
            ('ALK-105', 'RNC-038', 'KBY-04', 1200000, '2025-12-16', NULL),
            ('ALK-106', 'RNC-038', 'KBY-01', 1200000, '2025-12-16', NULL),
            ('ALK-107', 'RNC-038', 'KBY-05', 300000, '2025-12-16', NULL),
            ('ALK-108', 'RNC-039', 'KBY-06', 3500000, '2025-12-17', NULL),
            ('ALK-109', 'RNC-039', 'KBY-01', 3000000, '2025-12-17', NULL),
            ('ALK-110', 'RNC-039', 'KBY-02', 600000, '2025-12-17', NULL),
            ('ALK-111', 'RNC-040', 'KBY-04', 1500000, '2025-12-17', NULL),
            ('ALK-112', 'RNC-040', 'KBY-01', 700000, '2025-12-17', NULL),
            ('ALK-113', 'RNC-040', 'KBY-02', 300000, '2025-12-17', NULL),
            ('ALK-114', 'RNC-041', 'KBY-02', 2500000, '2025-12-17', NULL),
            ('ALK-115', 'RNC-041', 'KBY-06', 1500000, '2025-12-17', NULL),
            ('ALK-116', 'RNC-042', 'KBY-01', 1000000, '2025-12-17', NULL),
            ('ALK-117', 'RNC-042', 'KBY-02', 300000, '2025-12-17', NULL)
    ) AS v (ID_ALOKASI, ID_RENCANA, ID_KATEGORI_BIAYA, JUMLAH_ANGGARAN, TANGGAL_PERSETUJUAN, KETERANGAN)
) AS s
ON t.ID_ALOKASI = s.ID_ALOKASI
WHEN MATCHED THEN UPDATE SET
    ID_RENCANA = s.ID_RENCANA,
    ID_KATEGORI_BIAYA = s.ID_KATEGORI_BIAYA,
    JUMLAH_ANGGARAN = s.JUMLAH_ANGGARAN,
    TANGGAL_PERSETUJUAN = s.TANGGAL_PERSETUJUAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_ALOKASI, ID_RENCANA, ID_KATEGORI_BIAYA, JUMLAH_ANGGARAN, TANGGAL_PERSETUJUAN, KETERANGAN)
    VALUES (s.ID_ALOKASI, s.ID_RENCANA, s.ID_KATEGORI_BIAYA, s.JUMLAH_ANGGARAN, s.TANGGAL_PERSETUJUAN, s.KETERANGAN);

-- DATA_OPERASIONAL.REALISASI_PENGELUARAN: 124 rows
MERGE INTO DATA_OPERASIONAL.REALISASI_PENGELUARAN AS t
USING (
    SELECT
        v.ID_PENGELUARAN AS ID_PENGELUARAN,
        v.ID_ALOKASI AS ID_ALOKASI,
        CAST(v.TANGGAL_PENGELUARAN AS DATE) AS TANGGAL_PENGELUARAN,
        CAST(v.JUMLAH_PENGELUARAN AS NUMBER(18,0)) AS JUMLAH_PENGELUARAN,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('PGL-0001', 'ALK-001', '2026-02-12', 800000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0002', 'ALK-002', '2026-02-09', 830000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0003', 'ALK-002', '2026-02-16', 555000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0004', 'ALK-004', '2026-03-31', 3570000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0005', 'ALK-004', '2026-04-08', 2380000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0006', 'ALK-005', '2026-03-25', 1200000, 'Uang muka konsumsi peserta.'),
            ('PGL-0007', 'ALK-005', '2026-04-10', 800000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0008', 'ALK-006', '2026-03-27', 455000, 'Pembayaran publikasi dan dokumentasi.'),
            ('PGL-0009', 'ALK-007', '2026-03-27', 710000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0010', 'ALK-007', '2026-04-09', 470000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0011', 'ALK-008', '2026-06-16', 400000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0012', 'ALK-009', '2026-06-18', 400000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0013', 'ALK-017', '2026-01-27', 1220000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0014', 'ALK-017', '2026-04-29', 815000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0015', 'ALK-018', '2026-02-02', 940000, 'Uang muka konsumsi peserta.'),
            ('PGL-0016', 'ALK-018', '2026-04-29', 630000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0017', 'ALK-019', '2026-01-28', 655000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0018', 'ALK-019', '2026-04-29', 435000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0019', 'ALK-020', '2026-01-13', 835000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0020', 'ALK-020', '2026-04-06', 555000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0021', 'ALK-021', '2026-01-18', 970000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0022', 'ALK-022', '2026-06-29', 1495000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0023', 'ALK-022', '2026-09-27', 1000000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0024', 'ALK-023', '2026-06-26', 1175000, 'Uang muka konsumsi peserta.'),
            ('PGL-0025', 'ALK-023', '2026-09-30', 780000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0026', 'ALK-024', '2026-06-21', 825000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0027', 'ALK-024', '2026-09-30', 550000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0028', 'ALK-030', '2026-03-02', 1530000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0029', 'ALK-030', '2026-03-18', 1020000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0030', 'ALK-031', '2026-03-01', 1240000, 'Uang muka konsumsi peserta.'),
            ('PGL-0031', 'ALK-031', '2026-03-20', 830000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0032', 'ALK-032', '2026-03-06', 1200000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0033', 'ALK-032', '2026-03-19', 800000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0034', 'ALK-033', '2026-03-07', 585000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0035', 'ALK-034', '2026-05-29', 1205000, 'Uang muka konsumsi peserta.'),
            ('PGL-0036', 'ALK-034', '2026-06-11', 805000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0037', 'ALK-035', '2026-05-28', 780000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0038', 'ALK-035', '2026-06-09', 520000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0039', 'ALK-036', '2026-06-05', 425000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0040', 'ALK-037', '2026-09-03', 1200000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0041', 'ALK-037', '2026-09-06', 800000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0042', 'ALK-038', '2026-08-23', 1500000, 'Uang muka konsumsi peserta.'),
            ('PGL-0043', 'ALK-038', '2026-09-11', 1000000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0044', 'ALK-042', '2026-04-15', 2660000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0045', 'ALK-042', '2026-04-28', 1770000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0046', 'ALK-043', '2026-04-15', 1820000, 'Uang muka konsumsi peserta.'),
            ('PGL-0047', 'ALK-043', '2026-05-02', 1215000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0048', 'ALK-045', '2026-04-15', 805000, 'Uang muka transportasi dan akomodasi.'),
            ('PGL-0049', 'ALK-045', '2026-04-28', 535000, 'Pelunasan transportasi dan akomodasi.'),
            ('PGL-0050', 'ALK-046', '2026-06-24', 1670000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0051', 'ALK-046', '2026-07-01', 1110000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0052', 'ALK-047', '2026-06-24', 1570000, 'Uang muka konsumsi peserta.'),
            ('PGL-0053', 'ALK-047', '2026-06-28', 1050000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0054', 'ALK-048', '2026-06-26', 850000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0055', 'ALK-049', '2026-06-27', 620000, 'Pembayaran honorarium dan narasumber.'),
            ('PGL-0056', 'ALK-050', '2026-08-12', 625000, 'Uang muka honorarium dan narasumber yang sudah dibayarkan sebelum kegiatan ditunda.'),
            ('PGL-0057', 'ALK-053', '2026-09-06', 715000, 'Uang muka bantuan dan santunan sosial.'),
            ('PGL-0058', 'ALK-053', '2026-09-21', 480000, 'Pelunasan bantuan dan santunan sosial.'),
            ('PGL-0059', 'ALK-054', '2026-09-17', 675000, 'Pembayaran transportasi dan akomodasi.'),
            ('PGL-0060', 'ALK-055', '2026-09-19', 515000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0061', 'ALK-059', '2026-04-06', 6850000, 'Uang muka bantuan dan santunan sosial.'),
            ('PGL-0062', 'ALK-059', '2026-04-16', 4565000, 'Pelunasan bantuan dan santunan sosial.'),
            ('PGL-0063', 'ALK-060', '2026-04-10', 485000, 'Pembayaran publikasi dan dokumentasi.'),
            ('PGL-0064', 'ALK-061', '2026-03-30', 755000, 'Uang muka konsumsi peserta.'),
            ('PGL-0065', 'ALK-061', '2026-04-12', 505000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0066', 'ALK-062', '2026-05-19', 1800000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0067', 'ALK-062', '2026-06-02', 1200000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0068', 'ALK-063', '2026-05-22', 885000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0069', 'ALK-063', '2026-06-06', 590000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0070', 'ALK-064', '2026-05-16', 1070000, 'Uang muka konsumsi peserta.'),
            ('PGL-0071', 'ALK-064', '2026-06-05', 710000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0072', 'ALK-065', '2026-07-01', 2105000, 'Uang muka bantuan dan santunan sosial.'),
            ('PGL-0073', 'ALK-065', '2026-07-17', 1405000, 'Pelunasan bantuan dan santunan sosial.'),
            ('PGL-0074', 'ALK-066', '2026-07-09', 735000, 'Pembayaran transportasi dan akomodasi.'),
            ('PGL-0075', 'ALK-067', '2026-07-06', 675000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0076', 'ALK-068', '2026-07-18', 5355000, 'Uang muka bantuan dan santunan sosial.'),
            ('PGL-0077', 'ALK-068', '2026-07-31', 3570000, 'Pelunasan bantuan dan santunan sosial.'),
            ('PGL-0078', 'ALK-069', '2026-07-18', 740000, 'Uang muka transportasi dan akomodasi.'),
            ('PGL-0079', 'ALK-069', '2026-07-30', 490000, 'Pelunasan transportasi dan akomodasi.'),
            ('PGL-0080', 'ALK-070', '2026-07-24', 810000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0081', 'ALK-077', '2026-03-12', 900000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0082', 'ALK-077', '2026-03-26', 600000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0083', 'ALK-079', '2026-03-19', 500000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0084', 'ALK-080', '2026-05-09', 905000, 'Pembayaran honorarium dan narasumber.'),
            ('PGL-0085', 'ALK-081', '2026-05-06', 370000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0086', 'ALK-082', '2026-08-09', 840000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0087', 'ALK-082', '2026-08-17', 560000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0088', 'ALK-083', '2026-08-08', 795000, 'Pembayaran honorarium dan narasumber.'),
            ('PGL-0089', 'ALK-086', '2026-01-26', 900000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0090', 'ALK-086', '2026-03-16', 600000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0091', 'ALK-087', '2026-01-24', 1200000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0092', 'ALK-087', '2026-03-19', 800000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0093', 'ALK-088', '2026-01-28', 625000, 'Uang muka konsumsi peserta.'),
            ('PGL-0094', 'ALK-088', '2026-03-19', 415000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0095', 'ALK-089', '2026-09-18', 1345000, 'Uang muka konsumsi peserta.'),
            ('PGL-0096', 'ALK-089', '2026-09-30', 900000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0097', 'ALK-090', '2026-09-21', 800000, 'Pembayaran publikasi dan dokumentasi.'),
            ('PGL-0098', 'ALK-091', '2026-09-18', 720000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0099', 'ALK-091', '2026-09-30', 480000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0100', 'ALK-092', '2026-09-15', 800000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0101', 'ALK-092', '2026-09-25', 530000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0102', 'ALK-093', '2026-09-18', 1030000, 'Uang muka konsumsi peserta.'),
            ('PGL-0103', 'ALK-093', '2026-09-22', 690000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0104', 'ALK-094', '2026-09-19', 700000, 'Pembayaran honorarium dan narasumber.'),
            ('PGL-0105', 'ALK-097', '2026-05-12', 1800000, 'Uang muka perlengkapan dan bahan.'),
            ('PGL-0106', 'ALK-097', '2026-05-21', 1200000, 'Pelunasan perlengkapan dan bahan.'),
            ('PGL-0107', 'ALK-098', '2026-05-06', 1120000, 'Uang muka konsumsi peserta.'),
            ('PGL-0108', 'ALK-098', '2026-05-19', 745000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0109', 'ALK-099', '2026-05-14', 900000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0110', 'ALK-099', '2026-05-20', 600000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0111', 'ALK-100', '2026-08-27', 955000, 'Uang muka konsumsi peserta.'),
            ('PGL-0112', 'ALK-100', '2026-09-01', 640000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0113', 'ALK-101', '2026-08-29', 460000, 'Pembayaran publikasi dan dokumentasi.'),
            ('PGL-0114', 'ALK-102', '2026-08-27', 650000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0115', 'ALK-108', '2026-01-05', 2000000, 'Uang muka sewa sarana dan perawatan.'),
            ('PGL-0116', 'ALK-108', '2026-01-23', 1330000, 'Pelunasan sewa sarana dan perawatan.'),
            ('PGL-0117', 'ALK-109', '2026-01-13', 1470000, 'Uang muka konsumsi peserta.'),
            ('PGL-0118', 'ALK-109', '2026-01-24', 980000, 'Pelunasan konsumsi peserta.'),
            ('PGL-0119', 'ALK-110', '2026-01-15', 595000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0120', 'ALK-111', '2026-07-18', 850000, 'Uang muka honorarium dan narasumber.'),
            ('PGL-0121', 'ALK-111', '2026-07-29', 570000, 'Pelunasan honorarium dan narasumber.'),
            ('PGL-0122', 'ALK-112', '2026-07-24', 700000, 'Pembayaran konsumsi peserta.'),
            ('PGL-0123', 'ALK-113', '2026-07-24', 260000, 'Pembayaran perlengkapan dan bahan.'),
            ('PGL-0124', 'ALK-114', '2026-07-29', 625000, 'Uang muka perlengkapan dan bahan yang sudah dibayarkan sebelum kegiatan ditunda.')
    ) AS v (ID_PENGELUARAN, ID_ALOKASI, TANGGAL_PENGELUARAN, JUMLAH_PENGELUARAN, KETERANGAN)
) AS s
ON t.ID_PENGELUARAN = s.ID_PENGELUARAN
WHEN MATCHED THEN UPDATE SET
    ID_ALOKASI = s.ID_ALOKASI,
    TANGGAL_PENGELUARAN = s.TANGGAL_PENGELUARAN,
    JUMLAH_PENGELUARAN = s.JUMLAH_PENGELUARAN,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_PENGELUARAN, ID_ALOKASI, TANGGAL_PENGELUARAN, JUMLAH_PENGELUARAN, KETERANGAN)
    VALUES (s.ID_PENGELUARAN, s.ID_ALOKASI, s.TANGGAL_PENGELUARAN, s.JUMLAH_PENGELUARAN, s.KETERANGAN);

-- DATA_OPERASIONAL.KEGIATAN: 36 rows
MERGE INTO DATA_OPERASIONAL.KEGIATAN AS t
USING (
    SELECT
        v.ID_KEGIATAN AS ID_KEGIATAN,
        v.ID_RENCANA AS ID_RENCANA,
        v.NAMA_KEGIATAN AS NAMA_KEGIATAN,
        v.ID_SEKSI AS ID_SEKSI,
        CAST(v.TANGGAL_MULAI AS DATE) AS TANGGAL_MULAI,
        CAST(v.TANGGAL_SELESAI AS DATE) AS TANGGAL_SELESAI,
        v.LOKASI AS LOKASI,
        v.STATUS_KEGIATAN AS STATUS_KEGIATAN,
        CAST(v.TARGET_PESERTA AS NUMBER(6,0)) AS TARGET_PESERTA,
        CAST(v.JUMLAH_PESERTA_AKTUAL AS NUMBER(6,0)) AS JUMLAH_PESERTA_AKTUAL,
        v.KETERANGAN AS KETERANGAN
    FROM (VALUES
            ('KGT-001', 'RNC-001', 'Pelatihan Lektor dan Pemazmur', 'SEK-01', '2026-02-14', '2026-02-14', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 40, 38, NULL),
            ('KGT-002', 'RNC-002', 'Rangkaian Perayaan Pekan Suci dan Paskah', 'SEK-01', '2026-04-02', '2026-04-05', 'Gereja Santa Maria Contoh', 'Terlaksana', 600, 630, NULL),
            ('KGT-003', 'RNC-003', 'Pelatihan Putra-Putri Altar Baru', 'SEK-01', '2026-06-20', '2026-06-20', 'Gereja Santa Maria Contoh', 'Terlaksana', 25, 21, NULL),
            ('KGT-004', 'RNC-004', 'Pelatihan Operator Tata Suara dan Perangkat Baru', 'SEK-01', '2026-07-18', '2026-07-18', 'Gereja Santa Maria Contoh', 'Ditunda', 10, NULL, 'Ditunda menunggu penawaran harga dari penyedia perangkat.'),
            ('KGT-005', 'RNC-006', 'Misa Syukur Hari Ulang Tahun Paroki', 'SEK-01', '2026-10-11', '2026-10-11', 'Gereja Santa Maria Contoh', 'Direncanakan', 350, NULL, NULL),
            ('KGT-006', 'RNC-007', 'Katekese Persiapan Komuni Pertama', 'SEK-02', '2026-02-07', '2026-04-25', 'Ruang Katekese Paroki', 'Terlaksana', 35, 39, NULL),
            ('KGT-007', 'RNC-008', 'Pendampingan Calon Baptis Dewasa', 'SEK-02', '2026-01-24', '2026-04-04', 'Ruang Katekese Paroki', 'Terlaksana', 12, 10, NULL),
            ('KGT-008', 'RNC-009', 'Katekese Persiapan Sakramen Krisma', 'SEK-02', '2026-07-04', '2026-09-26', 'Ruang Katekese Paroki', 'Terlaksana', 40, 39, NULL),
            ('KGT-009', 'RNC-010', 'Pelatihan Katekis Lingkungan', 'SEK-02', '2026-05-23', '2026-05-23', 'Aula Paroki Santa Maria Contoh', 'Dibatalkan', 30, NULL, 'Dibatalkan karena jumlah pendaftar terlalu sedikit, akan diusulkan kembali pada rencana tahun berikutnya.'),
            ('KGT-010', 'RNC-012', 'Kursus Persiapan Perkawinan Angkatan I', 'SEK-03', '2026-03-14', '2026-03-15', 'Wisma Retret Damai Sejahtera', 'Terlaksana', 20, 22, NULL),
            ('KGT-011', 'RNC-013', 'Rekoleksi Pasangan Suami Istri', 'SEK-03', '2026-06-06', '2026-06-06', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 60, 60, NULL),
            ('KGT-012', 'RNC-014', 'Seminar Pengasuhan Anak di Era Digital', 'SEK-03', '2026-09-05', '2026-09-05', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 80, 89, NULL),
            ('KGT-013', 'RNC-015', 'Misa Syukur Ulang Tahun Perkawinan', 'SEK-03', '2026-10-24', '2026-10-24', 'Gereja Santa Maria Contoh', 'Direncanakan', 70, NULL, NULL),
            ('KGT-014', 'RNC-016', 'Retret Orang Muda Katolik', 'SEK-04', '2026-04-25', '2026-04-26', 'Wisma Retret Damai Sejahtera', 'Terlaksana', 45, 50, NULL),
            ('KGT-015', 'RNC-017', 'Turnamen Futsal Antarlingkungan', 'SEK-04', '2026-06-27', '2026-06-27', 'Lapangan Futsal Sewaan', 'Terlaksana', 120, 132, NULL),
            ('KGT-016', 'RNC-018', 'Pelatihan Kepemimpinan Orang Muda', 'SEK-04', '2026-08-22', '2026-08-22', 'Aula Paroki Santa Maria Contoh', 'Ditunda', 35, NULL, 'Ditunda karena bertepatan dengan ujian sekolah, jadwal baru ditetapkan setelah rapat seksi.'),
            ('KGT-017', 'RNC-019', 'Bakti Sosial Orang Muda di Panti Asuhan', 'SEK-04', '2026-09-19', '2026-09-19', 'Panti Asuhan Kasih Sejahtera', 'Terlaksana', 30, 28, NULL),
            ('KGT-018', 'RNC-021', 'Penyaluran Bantuan Aksi Puasa Pembangunan', 'SEK-05', '2026-04-11', '2026-04-11', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 150, 150, NULL),
            ('KGT-019', 'RNC-022', 'Pelatihan Kewirausahaan Usaha Mikro Umat', 'SEK-05', '2026-05-30', '2026-05-31', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 35, 29, NULL),
            ('KGT-020', 'RNC-023', 'Kunjungan dan Santunan Lansia', 'SEK-05', '2026-07-11', '2026-07-11', 'Rumah Umat di Lingkungan', 'Terlaksana', 60, 47, NULL),
            ('KGT-021', 'RNC-024', 'Penyaluran Bantuan Korban Banjir', 'SEK-05', '2026-07-26', '2026-07-26', 'Posko Bantuan Paroki', 'Terlaksana', 90, 92, NULL),
            ('KGT-022', 'RNC-026', 'Pelatihan Pengelolaan Keuangan Keluarga', 'SEK-05', '2026-09-12', '2026-09-12', 'Aula Paroki Santa Maria Contoh', 'Ditunda', 50, NULL, 'Ditunda ke bulan November karena narasumber berhalangan.'),
            ('KGT-023', 'RNC-027', 'Pelatihan Fotografi dan Videografi Liturgi', 'SEK-06', '2026-03-21', '2026-03-21', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 20, 19, NULL),
            ('KGT-024', 'RNC-028', 'Lokakarya Penulisan Warta Paroki', 'SEK-06', '2026-05-09', '2026-05-09', 'Ruang Rapat Paroki', 'Terlaksana', 15, 15, NULL),
            ('KGT-025', 'RNC-029', 'Pelatihan Siaran Langsung Misa', 'SEK-06', '2026-08-15', '2026-08-15', 'Gereja Santa Maria Contoh', 'Terlaksana', 12, 13, NULL),
            ('KGT-026', 'RNC-031', 'Kursus Dasar Kitab Suci Angkatan I', 'SEK-07', '2026-01-31', '2026-03-14', 'Ruang Katekese Paroki', 'Terlaksana', 30, 24, NULL),
            ('KGT-027', 'RNC-032', 'Perayaan Bulan Kitab Suci Nasional', 'SEK-07', '2026-09-26', '2026-09-26', 'Gereja Santa Maria Contoh', 'Terlaksana', 200, 205, NULL),
            ('KGT-028', 'RNC-033', 'Lomba Cerdas Cermat Kitab Suci Antarlingkungan', 'SEK-07', '2026-09-20', '2026-09-20', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 150, 149, NULL),
            ('KGT-029', 'RNC-035', 'Pemeriksaan Kesehatan Gratis untuk Lansia', 'SEK-08', '2026-05-16', '2026-05-16', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 100, 86, NULL),
            ('KGT-030', 'RNC-036', 'Aksi Donor Darah Paroki', 'SEK-08', '2026-08-29', '2026-08-29', 'Aula Paroki Santa Maria Contoh', 'Terlaksana', 70, 56, NULL),
            ('KGT-031', 'RNC-038', 'Penyuluhan Gizi Keluarga', 'SEK-08', '2026-10-17', '2026-10-17', 'Aula Paroki Santa Maria Contoh', 'Direncanakan', 60, NULL, NULL),
            ('KGT-032', 'RNC-039', 'Rapat Kerja Pengurus Paroki', 'SEK-09', '2026-01-17', '2026-01-18', 'Wisma Retret Damai Sejahtera', 'Terlaksana', 45, 36, NULL),
            ('KGT-033', 'RNC-040', 'Pelatihan Pengelolaan Data Umat dan Pelindungan Privasi', 'SEK-09', '2026-07-25', '2026-07-25', 'Ruang Rapat Paroki', 'Terlaksana', 18, 19, NULL),
            ('KGT-034', 'RNC-041', 'Lokakarya Digitalisasi Arsip Paroki', 'SEK-09', '2026-08-08', '2026-08-08', 'Ruang Arsip Paroki', 'Ditunda', 12, NULL, 'Ditunda karena perangkat pemindai belum tersedia.'),
            ('KGT-035', NULL, 'Doa Bersama dan Penggalangan Bantuan Korban Longsor', 'SEK-05', '2026-03-28', '2026-03-28', 'Gereja Santa Maria Contoh', 'Terlaksana', 60, 85, 'Kegiatan spontan di luar rencana kerja tahunan.'),
            ('KGT-036', NULL, 'Pertemuan Darurat Panitia Pembangunan Kapel', 'SEK-09', '2026-06-02', '2026-06-02', 'Ruang Rapat Paroki', 'Terlaksana', 15, 14, 'Kegiatan spontan di luar rencana kerja tahunan.')
    ) AS v (ID_KEGIATAN, ID_RENCANA, NAMA_KEGIATAN, ID_SEKSI, TANGGAL_MULAI, TANGGAL_SELESAI, LOKASI, STATUS_KEGIATAN, TARGET_PESERTA, JUMLAH_PESERTA_AKTUAL, KETERANGAN)
) AS s
ON t.ID_KEGIATAN = s.ID_KEGIATAN
WHEN MATCHED THEN UPDATE SET
    ID_RENCANA = s.ID_RENCANA,
    NAMA_KEGIATAN = s.NAMA_KEGIATAN,
    ID_SEKSI = s.ID_SEKSI,
    TANGGAL_MULAI = s.TANGGAL_MULAI,
    TANGGAL_SELESAI = s.TANGGAL_SELESAI,
    LOKASI = s.LOKASI,
    STATUS_KEGIATAN = s.STATUS_KEGIATAN,
    TARGET_PESERTA = s.TARGET_PESERTA,
    JUMLAH_PESERTA_AKTUAL = s.JUMLAH_PESERTA_AKTUAL,
    KETERANGAN = s.KETERANGAN
WHEN NOT MATCHED THEN INSERT (ID_KEGIATAN, ID_RENCANA, NAMA_KEGIATAN, ID_SEKSI, TANGGAL_MULAI, TANGGAL_SELESAI, LOKASI, STATUS_KEGIATAN, TARGET_PESERTA, JUMLAH_PESERTA_AKTUAL, KETERANGAN)
    VALUES (s.ID_KEGIATAN, s.ID_RENCANA, s.NAMA_KEGIATAN, s.ID_SEKSI, s.TANGGAL_MULAI, s.TANGGAL_SELESAI, s.LOKASI, s.STATUS_KEGIATAN, s.TARGET_PESERTA, s.JUMLAH_PESERTA_AKTUAL, s.KETERANGAN);

-- DATA_OPERASIONAL.LAPORAN_KEGIATAN: 24 rows
MERGE INTO DATA_OPERASIONAL.LAPORAN_KEGIATAN AS t
USING (
    SELECT
        v.ID_LAPORAN AS ID_LAPORAN,
        v.ID_KEGIATAN AS ID_KEGIATAN,
        CAST(v.TANGGAL_LAPORAN AS DATE) AS TANGGAL_LAPORAN,
        v.STATUS_LAPORAN AS STATUS_LAPORAN,
        v.RINGKASAN_PELAKSANAAN AS RINGKASAN_PELAKSANAAN,
        CAST(v.JUMLAH_PESERTA AS NUMBER(6,0)) AS JUMLAH_PESERTA,
        CAST(v.REALISASI_BIAYA AS NUMBER(18,0)) AS REALISASI_BIAYA,
        v.EVALUASI_LOGISTIK AS EVALUASI_LOGISTIK,
        v.HASIL_KEGIATAN AS HASIL_KEGIATAN,
        v.REKOMENDASI_TINDAK_LANJUT AS REKOMENDASI_TINDAK_LANJUT
    FROM (VALUES
            ('LPK-001', 'KGT-001', '2026-02-24', 'Final', 'Pelatihan Lektor dan Pemazmur dilaksanakan pada 14 Februari 2026 di Aula Paroki Santa Maria Contoh dengan 38 peserta dari target 40 peserta.', 38, 2185000, 'Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.', 'Peserta mengikuti latihan teknik membaca, pernapasan, dan melagukan mazmur, lalu menyelesaikan sesi praktik di depan kelompok.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-002', 'KGT-002', '2026-04-17', 'Final', 'Rangkaian Perayaan Pekan Suci dan Paskah dilaksanakan pada 2 sampai 5 April 2026 di Gereja Santa Maria Contoh dengan 630 peserta dari target 600 peserta.', 630, 9585000, 'Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.', 'Seluruh liturgi Pekan Suci berjalan lancar, dekorasi dan petugas liturgi dinilai baik oleh umat.', 'Publikasi perlu melibatkan lebih banyak lingkungan agar jangkauan peserta lebih luas.'),
            ('LPK-003', 'KGT-003', '2026-06-29', 'Draf', 'Pelatihan Putra-Putri Altar Baru dilaksanakan pada 20 Juni 2026 di Gereja Santa Maria Contoh dengan 21 peserta dari target 25 peserta.', 21, 800000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Peserta mempelajari tugas dasar di altar dan berlatih dalam Misa percobaan.', NULL),
            ('LPK-004', 'KGT-006', '2026-05-04', 'Final', 'Katekese Persiapan Komuni Pertama dilaksanakan pada 7 Februari 2026 sampai 25 April 2026 di Ruang Katekese Paroki dengan 39 peserta dari target 35 peserta.', 39, 4695000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Anak-anak mengikuti seluruh rangkaian pertemuan dan siap menerima Komuni Pertama, orang tua terlibat aktif dalam pendampingan.', 'Siapkan cadangan perlengkapan dan petugas untuk mengantisipasi kendala teknis.'),
            ('LPK-005', 'KGT-007', '2026-04-07', 'Final', 'Pendampingan Calon Baptis Dewasa dilaksanakan pada 24 Januari 2026 sampai 4 April 2026 di Ruang Katekese Paroki dengan 10 peserta dari target 12 peserta.', 10, 2360000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Para katekumen menyelesaikan seluruh pertemuan pendampingan dan dipersiapkan menerima sakramen pada Malam Paskah.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-006', 'KGT-008', '2026-09-30', 'Draf', 'Katekese Persiapan Sakramen Krisma dilaksanakan pada 4 Juli 2026 sampai 26 September 2026 di Ruang Katekese Paroki dengan 39 peserta dari target 40 peserta.', 39, 5825000, NULL, 'Peserta menyelesaikan materi pengajaran dan retret singkat sebagai persiapan menerima sakramen.', NULL),
            ('LPK-007', 'KGT-010', '2026-03-21', 'Final', 'Kursus Persiapan Perkawinan Angkatan I dilaksanakan pada 14 sampai 15 Maret 2026 di Wisma Retret Damai Sejahtera dengan 22 peserta dari target 20 peserta.', 22, 7205000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Para calon pasangan menyelesaikan seluruh materi dan menyatakan lebih siap membangun keluarga.', 'Publikasi perlu melibatkan lebih banyak lingkungan agar jangkauan peserta lebih luas.'),
            ('LPK-008', 'KGT-011', '2026-06-10', 'Draf', 'Rekoleksi Pasangan Suami Istri dilaksanakan pada 6 Juni 2026 di Aula Paroki Santa Maria Contoh dengan 60 peserta dari target 60 peserta.', 60, NULL, 'Tata suara dan proyektor berfungsi baik, konsumsi cukup untuk seluruh peserta.', 'Pasangan peserta berbagi pengalaman dan menyusun komitmen sederhana untuk keluarga masing-masing.', 'Siapkan cadangan perlengkapan dan petugas untuk mengantisipasi kendala teknis.'),
            ('LPK-009', 'KGT-014', '2026-05-04', 'Final', 'Retret Orang Muda Katolik dilaksanakan pada 25 sampai 26 April 2026 di Wisma Retret Damai Sejahtera dengan 50 peserta dari target 45 peserta.', 50, 8805000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Peserta mengikuti sesi refleksi, adorasi, dan berbagi kelompok dengan antusias.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-010', 'KGT-015', '2026-07-03', 'Final', 'Turnamen Futsal Antarlingkungan dilaksanakan pada 27 Juni 2026 di Lapangan Futsal Sewaan dengan 132 peserta dari target 120 peserta.', 132, 6870000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Turnamen berlangsung tertib dan sportif dengan keterlibatan banyak lingkungan.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-011', 'KGT-017', '2026-09-24', 'Perlu Revisi', 'Bakti Sosial Orang Muda di Panti Asuhan dilaksanakan pada 19 September 2026 di Panti Asuhan Kasih Sejahtera dengan 28 peserta dari target 30 peserta.', 32, 2385000, 'Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.', 'Orang muda mengunjungi panti asuhan, bermain bersama anak-anak, dan menyerahkan bantuan perlengkapan sekolah.', 'Siapkan cadangan perlengkapan dan petugas untuk mengantisipasi kendala teknis.'),
            ('LPK-012', 'KGT-018', '2026-04-15', 'Final', 'Penyaluran Bantuan Aksi Puasa Pembangunan dilaksanakan pada 11 April 2026 di Aula Paroki Santa Maria Contoh dengan 150 peserta dari target 150 peserta.', 150, 13160000, 'Tata suara dan proyektor berfungsi baik, konsumsi cukup untuk seluruh peserta.', 'Bantuan tersalurkan kepada keluarga penerima manfaat sesuai daftar yang telah diverifikasi.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-013', 'KGT-019', '2026-06-08', 'Final', 'Pelatihan Kewirausahaan Usaha Mikro Umat dilaksanakan pada 30 sampai 31 Mei 2026 di Aula Paroki Santa Maria Contoh dengan 29 peserta dari target 35 peserta.', 29, 6255000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Peserta menyusun rencana usaha sederhana dan berlatih menghitung modal serta harga jual.', 'Publikasi perlu melibatkan lebih banyak lingkungan agar jangkauan peserta lebih luas.'),
            ('LPK-014', 'KGT-020', '2026-07-21', 'Draf', 'Kunjungan dan Santunan Lansia dilaksanakan pada 11 Juli 2026 di Rumah Umat di Lingkungan dengan 47 peserta dari target 60 peserta.', 47, 4920000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', NULL, NULL),
            ('LPK-015', 'KGT-021', '2026-08-02', 'Final', 'Penyaluran Bantuan Korban Banjir dilaksanakan pada 26 Juli 2026 di Posko Bantuan Paroki dengan 92 peserta dari target 90 peserta.', 92, 10965000, 'Perlengkapan, tempat, dan konsumsi tersedia dengan baik dan tepat waktu.', 'Bantuan darurat berupa kebutuhan pokok tersalurkan kepada keluarga yang terdampak.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-016', 'KGT-023', '2026-03-30', 'Final', 'Pelatihan Fotografi dan Videografi Liturgi dilaksanakan pada 21 Maret 2026 di Aula Paroki Santa Maria Contoh dengan 19 peserta dari target 20 peserta.', 19, 2000000, 'Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.', 'Relawan berlatih mengambil gambar dengan sikap menghormati perayaan dan menyepakati aturan dokumentasi.', 'Pendaftaran perlu dibuka lebih awal agar persiapan konsumsi dan perlengkapan lebih akurat.'),
            ('LPK-017', 'KGT-024', '2026-05-19', 'Draf', 'Lokakarya Penulisan Warta Paroki dilaksanakan pada 9 Mei 2026 di Ruang Rapat Paroki dengan 15 peserta dari target 15 peserta.', 15, 1275000, 'Tempat memadai, tetapi sirkulasi udara di ruangan kurang optimal.', 'Relawan menulis contoh warta dan menerima masukan penyuntingan.', NULL),
            ('LPK-018', 'KGT-026', '2026-03-19', 'Final', 'Kursus Dasar Kitab Suci Angkatan I dilaksanakan pada 31 Januari 2026 sampai 14 Maret 2026 di Ruang Katekese Paroki dengan 24 peserta dari target 30 peserta.', 24, 4540000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Peserta menyelesaikan kursus dan mampu menjelaskan struktur serta tema pokok Kitab Suci.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-019', 'KGT-027', '2026-09-30', 'Draf', 'Perayaan Bulan Kitab Suci Nasional dilaksanakan pada 26 September 2026 di Gereja Santa Maria Contoh dengan 205 peserta dari target 200 peserta.', 205, NULL, 'Perlengkapan, tempat, dan konsumsi tersedia dengan baik dan tepat waktu.', 'Ibadat Sabda dan sarasehan berlangsung khidmat, umat membawa Kitab Suci masing-masing.', 'Siapkan cadangan perlengkapan dan petugas untuk mengantisipasi kendala teknis.'),
            ('LPK-020', 'KGT-029', '2026-05-23', 'Final', 'Pemeriksaan Kesehatan Gratis untuk Lansia dilaksanakan pada 16 Mei 2026 di Aula Paroki Santa Maria Contoh dengan 86 peserta dari target 100 peserta.', 86, 6365000, 'Perlengkapan, tempat, dan konsumsi tersedia dengan baik dan tepat waktu.', 'Para lansia menerima pemeriksaan dasar dan konsultasi, sebagian dirujuk ke fasilitas kesehatan untuk pemeriksaan lanjutan.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-021', 'KGT-030', '2026-09-05', 'Final', 'Aksi Donor Darah Paroki dilaksanakan pada 29 Agustus 2026 di Aula Paroki Santa Maria Contoh dengan 56 peserta dari target 70 peserta.', 56, 2705000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Kantong darah terkumpul dan diserahkan kepada unit donor darah mitra.', 'Kegiatan serupa layak dilanjutkan tahun depan dengan tambahan waktu praktik.'),
            ('LPK-022', 'KGT-032', '2026-01-28', 'Final', 'Rapat Kerja Pengurus Paroki dilaksanakan pada 17 sampai 18 Januari 2026 di Wisma Retret Damai Sejahtera dengan 36 peserta dari target 45 peserta.', 36, 6375000, 'Sebagian peserta yang mendaftar tidak hadir sehingga ada konsumsi yang tersisa.', 'Pengurus menyepakati prioritas pelayanan dan jadwal besar kegiatan tahun 2026.', 'Pendaftaran perlu dibuka lebih awal agar persiapan konsumsi dan perlengkapan lebih akurat.'),
            ('LPK-023', 'KGT-033', '2026-07-31', 'Final', 'Pelatihan Pengelolaan Data Umat dan Pelindungan Privasi dilaksanakan pada 25 Juli 2026 di Ruang Rapat Paroki dengan 19 peserta dari target 18 peserta.', 19, 2380000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Petugas memahami klasifikasi data, batas akses, dan cara menjaga kerahasiaan data umat.', 'Publikasi perlu melibatkan lebih banyak lingkungan agar jangkauan peserta lebih luas.'),
            ('LPK-024', 'KGT-035', '2026-04-07', 'Final', 'Doa Bersama dan Penggalangan Bantuan Korban Longsor dilaksanakan pada 28 Maret 2026 di Gereja Santa Maria Contoh dengan 85 peserta dari target 60 peserta.', 85, 3200000, 'Jumlah peserta melebihi perkiraan sehingga ruangan terasa penuh dan konsumsi hampir tidak cukup.', 'Doa bersama dan penggalangan bantuan berjalan lancar, bantuan diteruskan melalui jaringan pelayanan sosial.', 'Pendaftaran perlu dibuka lebih awal agar persiapan konsumsi dan perlengkapan lebih akurat.')
    ) AS v (ID_LAPORAN, ID_KEGIATAN, TANGGAL_LAPORAN, STATUS_LAPORAN, RINGKASAN_PELAKSANAAN, JUMLAH_PESERTA, REALISASI_BIAYA, EVALUASI_LOGISTIK, HASIL_KEGIATAN, REKOMENDASI_TINDAK_LANJUT)
) AS s
ON t.ID_LAPORAN = s.ID_LAPORAN
WHEN MATCHED THEN UPDATE SET
    ID_KEGIATAN = s.ID_KEGIATAN,
    TANGGAL_LAPORAN = s.TANGGAL_LAPORAN,
    STATUS_LAPORAN = s.STATUS_LAPORAN,
    RINGKASAN_PELAKSANAAN = s.RINGKASAN_PELAKSANAAN,
    JUMLAH_PESERTA = s.JUMLAH_PESERTA,
    REALISASI_BIAYA = s.REALISASI_BIAYA,
    EVALUASI_LOGISTIK = s.EVALUASI_LOGISTIK,
    HASIL_KEGIATAN = s.HASIL_KEGIATAN,
    REKOMENDASI_TINDAK_LANJUT = s.REKOMENDASI_TINDAK_LANJUT
WHEN NOT MATCHED THEN INSERT (ID_LAPORAN, ID_KEGIATAN, TANGGAL_LAPORAN, STATUS_LAPORAN, RINGKASAN_PELAKSANAAN, JUMLAH_PESERTA, REALISASI_BIAYA, EVALUASI_LOGISTIK, HASIL_KEGIATAN, REKOMENDASI_TINDAK_LANJUT)
    VALUES (s.ID_LAPORAN, s.ID_KEGIATAN, s.TANGGAL_LAPORAN, s.STATUS_LAPORAN, s.RINGKASAN_PELAKSANAAN, s.JUMLAH_PESERTA, s.REALISASI_BIAYA, s.EVALUASI_LOGISTIK, s.HASIL_KEGIATAN, s.REKOMENDASI_TINDAK_LANJUT);

-- =============================================================================
-- >>> sql/05_create_views.sql
-- =============================================================================

-- =============================================================================
-- Step 5: Create the ANALISIS summary views
--
-- Creates : 13 views in schema ANALISIS for the first business use cases.
-- Requires: steps 1-4 (tables and data). Views can be created before data is
--           loaded, but they will return no rows.
-- Safe to re-run: yes (CREATE OR REPLACE VIEW only touches the views, never the
--           data tables).
--
-- Design rules
--   * ANALISIS holds aggregated or operational summaries only. No view exposes
--     names, person or household identifiers, or birth years of parishioners.
--     sql/06_validate_data.sql checks this.
--   * Every view carries the column SUMBER_DATA so that the simulated nature of
--     the data travels with every result.
--   * Views that compare donation totals never rank regions.
--   * Views are listed in dependency order: a view only reads views defined above it
--     (views 8 and 9 read view 7, view 10 reads view 9, view 12 reads view 11).
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

-- 1. Region and community structure -------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.STRUKTUR_WILAYAH
    COMMENT = 'Struktur wilayah dan lingkungan beserta masa berlaku. Data simulasi.'
AS
SELECT
    w.ID_WILAYAH,
    w.NAMA_WILAYAH,
    l.ID_LINGKUNGAN,
    l.NAMA_LINGKUNGAN,
    l.STATUS_AKTIF AS LINGKUNGAN_AKTIF,
    l.TANGGAL_MULAI_BERLAKU,
    l.TANGGAL_AKHIR_BERLAKU,
    CASE WHEN g.ID_GEOMETRI IS NULL THEN FALSE ELSE TRUE END AS MEMILIKI_GEOMETRI_ILUSTRATIF,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM MASTER_DATA.MASTER_LINGKUNGAN l
JOIN MASTER_DATA.MASTER_WILAYAH w
    ON w.ID_WILAYAH = l.ID_WILAYAH
LEFT JOIN MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN g
    ON g.ID_LINGKUNGAN = l.ID_LINGKUNGAN;

-- 2. Scheduled versus actual Mass times -----------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.PELAKSANAAN_MISA
    COMMENT = 'Satu baris per kejadian Misa: jadwal, waktu aktual, selisih menit, dan jumlah umat. Data simulasi.'
AS
SELECT
    k.ID_KEJADIAN_MISA,
    k.TANGGAL_MISA,
    p.ID_PERIODE_PELAPORAN,
    p.NAMA_PERIODE,
    j.NAMA_MISA,
    j.HARI,
    j.LOKASI,
    j.BAHASA_MISA,
    k.STATUS_PELAKSANAAN,
    j.WAKTU_MULAI AS WAKTU_MULAI_JADWAL,
    k.WAKTU_MULAI_AKTUAL,
    j.WAKTU_SELESAI AS WAKTU_SELESAI_JADWAL,
    k.WAKTU_SELESAI_AKTUAL,
    CASE WHEN k.WAKTU_MULAI_AKTUAL IS NULL THEN NULL ELSE
        (EXTRACT(HOUR FROM k.WAKTU_MULAI_AKTUAL) * 60 + EXTRACT(MINUTE FROM k.WAKTU_MULAI_AKTUAL))
        - (EXTRACT(HOUR FROM j.WAKTU_MULAI) * 60 + EXTRACT(MINUTE FROM j.WAKTU_MULAI))
    END AS SELISIH_MULAI_MENIT,
    CASE WHEN k.WAKTU_MULAI_AKTUAL IS NULL THEN NULL ELSE
        (EXTRACT(HOUR FROM k.WAKTU_SELESAI_AKTUAL) * 60 + EXTRACT(MINUTE FROM k.WAKTU_SELESAI_AKTUAL))
        - (EXTRACT(HOUR FROM k.WAKTU_MULAI_AKTUAL) * 60 + EXTRACT(MINUTE FROM k.WAKTU_MULAI_AKTUAL))
    END AS DURASI_AKTUAL_MENIT,
    a.JUMLAH_UMAT,
    a.STATUS_VALIDASI AS STATUS_VALIDASI_KEHADIRAN,
    k.KETERANGAN,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.KEJADIAN_MISA k
JOIN MASTER_DATA.JADWAL_MISA j
    ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA
JOIN MASTER_DATA.REFERENSI_PERIODE_PELAPORAN p
    ON k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI
LEFT JOIN DATA_OPERASIONAL.KEHADIRAN_MISA a
    ON a.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA;

-- 3. Monthly attendance by Mass session ---------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.KEHADIRAN_MISA_BULANAN
    COMMENT = 'Kehadiran umat per bulan dan sesi Misa (hanya Misa yang terlaksana). Data simulasi.'
AS
SELECT
    p.ID_PERIODE_PELAPORAN,
    p.TAHUN,
    p.BULAN,
    p.NAMA_PERIODE,
    j.NAMA_MISA,
    COUNT(*) AS JUMLAH_MISA_TERLAKSANA,
    SUM(a.JUMLAH_UMAT) AS TOTAL_UMAT,
    ROUND(AVG(a.JUMLAH_UMAT), 1) AS RATA_RATA_UMAT_PER_MISA,
    MIN(a.JUMLAH_UMAT) AS UMAT_TERENDAH,
    MAX(a.JUMLAH_UMAT) AS UMAT_TERTINGGI,
    SUM(CASE WHEN a.STATUS_VALIDASI = 'Sudah Divalidasi' THEN 1 ELSE 0 END) AS JUMLAH_SUDAH_DIVALIDASI,
    SUM(CASE WHEN a.STATUS_VALIDASI <> 'Sudah Divalidasi' THEN 1 ELSE 0 END) AS JUMLAH_BELUM_FINAL,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.KEJADIAN_MISA k
JOIN DATA_OPERASIONAL.KEHADIRAN_MISA a
    ON a.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA
JOIN MASTER_DATA.JADWAL_MISA j
    ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA
JOIN MASTER_DATA.REFERENSI_PERIODE_PELAPORAN p
    ON k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI
WHERE k.STATUS_PELAKSANAAN = 'Terlaksana'
GROUP BY p.ID_PERIODE_PELAPORAN, p.TAHUN, p.BULAN, p.NAMA_PERIODE, j.NAMA_MISA;

-- 4. Monthly offertory by Mass session and collection type ----------------------------------
CREATE OR REPLACE VIEW ANALISIS.KOLEKTE_MISA_BULANAN
    COMMENT = 'Kolekte per bulan, sesi Misa, dan jenis kolekte: jumlah tercatat, hasil penghitungan, dan status rekonsiliasi. Bukan ukuran iman. Data simulasi.'
AS
SELECT
    p.ID_PERIODE_PELAPORAN,
    p.TAHUN,
    p.BULAN,
    p.NAMA_PERIODE,
    j.NAMA_MISA,
    t.NAMA_JENIS_KOLEKTE,
    COUNT(*) AS JUMLAH_CATATAN,
    SUM(c.JUMLAH_PENERIMAAN) AS TOTAL_TERCATAT,
    SUM(c.JUMLAH_HASIL_PENGHITUNGAN) AS TOTAL_HASIL_PENGHITUNGAN,
    SUM(CASE WHEN c.JUMLAH_HASIL_PENGHITUNGAN IS NOT NULL THEN c.JUMLAH_PENERIMAAN ELSE 0 END) AS TOTAL_TERCATAT_YANG_SUDAH_DIHITUNG,
    SUM(CASE WHEN c.JUMLAH_HASIL_PENGHITUNGAN IS NOT NULL THEN c.JUMLAH_HASIL_PENGHITUNGAN - c.JUMLAH_PENERIMAAN ELSE 0 END) AS SELISIH_PADA_YANG_SUDAH_DIHITUNG,
    SUM(CASE WHEN c.STATUS_REKONSILIASI = 'Sudah Cocok' THEN 1 ELSE 0 END) AS JUMLAH_SUDAH_COCOK,
    SUM(CASE WHEN c.STATUS_REKONSILIASI IN ('Selisih Disetujui', 'Selisih Sedang Ditelusuri') THEN 1 ELSE 0 END) AS JUMLAH_ADA_SELISIH,
    SUM(CASE WHEN c.STATUS_REKONSILIASI = 'Belum Dihitung' THEN 1 ELSE 0 END) AS JUMLAH_BELUM_DIHITUNG,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE c
JOIN DATA_OPERASIONAL.KEJADIAN_MISA k
    ON k.ID_KEJADIAN_MISA = c.ID_KEJADIAN_MISA
JOIN MASTER_DATA.JADWAL_MISA j
    ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA
JOIN MASTER_DATA.REFERENSI_JENIS_KOLEKTE t
    ON t.ID_JENIS_KOLEKTE = c.ID_JENIS_KOLEKTE
JOIN MASTER_DATA.REFERENSI_PERIODE_PELAPORAN p
    ON k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI
GROUP BY p.ID_PERIODE_PELAPORAN, p.TAHUN, p.BULAN, p.NAMA_PERIODE, j.NAMA_MISA, t.NAMA_JENIS_KOLEKTE;

-- 5. Attendance trend across reporting periods -----------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.TREN_KEHADIRAN_PERIODE
    COMMENT = 'Tren kehadiran seluruh Misa per bulan dengan perbandingan terhadap bulan sebelumnya. Data simulasi.'
AS
WITH BULANAN AS (
    SELECT
        p.ID_PERIODE_PELAPORAN,
        p.TAHUN,
        p.BULAN,
        p.NAMA_PERIODE,
        COUNT(*) AS JUMLAH_MISA_TERLAKSANA,
        SUM(a.JUMLAH_UMAT) AS TOTAL_UMAT,
        ROUND(AVG(a.JUMLAH_UMAT), 1) AS RATA_RATA_UMAT_PER_MISA
    FROM DATA_OPERASIONAL.KEJADIAN_MISA k
    JOIN DATA_OPERASIONAL.KEHADIRAN_MISA a
        ON a.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA
    JOIN MASTER_DATA.REFERENSI_PERIODE_PELAPORAN p
        ON k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI
    WHERE k.STATUS_PELAKSANAAN = 'Terlaksana'
    GROUP BY p.ID_PERIODE_PELAPORAN, p.TAHUN, p.BULAN, p.NAMA_PERIODE
),
DENGAN_PEMBANDING AS (
    SELECT
        b.*,
        LAG(b.RATA_RATA_UMAT_PER_MISA) OVER (ORDER BY b.TAHUN, b.BULAN) AS RATA_RATA_BULAN_SEBELUMNYA
    FROM BULANAN b
)
SELECT
    ID_PERIODE_PELAPORAN,
    TAHUN,
    BULAN,
    NAMA_PERIODE,
    JUMLAH_MISA_TERLAKSANA,
    TOTAL_UMAT,
    RATA_RATA_UMAT_PER_MISA,
    RATA_RATA_BULAN_SEBELUMNYA,
    CASE WHEN RATA_RATA_BULAN_SEBELUMNYA IS NULL OR RATA_RATA_BULAN_SEBELUMNYA = 0 THEN NULL
         ELSE ROUND(100.0 * (RATA_RATA_UMAT_PER_MISA - RATA_RATA_BULAN_SEBELUMNYA) / RATA_RATA_BULAN_SEBELUMNYA, 1)
    END AS PERUBAHAN_PERSEN_RATA_RATA,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DENGAN_PEMBANDING;

-- 6. Special occasion donations by region -------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.SUMBANGAN_KHUSUS_PER_WILAYAH
    COMMENT = 'Sumbangan kesempatan khusus per wilayah dan periode. Hanya ringkasan, tidak untuk memeringkat wilayah. Data simulasi.'
AS
SELECT
    s.ID_SUMBANGAN,
    k.NAMA_KESEMPATAN,
    k.MUSIM_LITURGI,
    s.PERIODE_MULAI,
    s.PERIODE_SELESAI,
    w.ID_WILAYAH,
    w.NAMA_WILAYAH,
    s.JUMLAH_KELUARGA_PESERTA,
    s.JUMLAH_SUMBANGAN,
    SUM(s.JUMLAH_SUMBANGAN) OVER (PARTITION BY s.ID_KESEMPATAN, s.PERIODE_MULAI) AS TOTAL_SUMBANGAN_SELURUH_WILAYAH,
    s.TANGGAL_PENCATATAN,
    s.STATUS_VALIDASI,
    'Hanya untuk ringkasan, jangan dipakai untuk memeringkat wilayah.' AS CATATAN_PENGGUNAAN,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS s
JOIN MASTER_DATA.MASTER_WILAYAH w
    ON w.ID_WILAYAH = s.ID_WILAYAH
JOIN MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS k
    ON k.ID_KESEMPATAN = s.ID_KESEMPATAN;

-- 7. Planned budget versus actual expenditure per program ----------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM
    COMMENT = 'Anggaran rencana dibandingkan pengeluaran sebenarnya untuk setiap program. Data simulasi.'
AS
WITH ANGGARAN AS (
    SELECT ID_RENCANA, SUM(JUMLAH_ANGGARAN) AS TOTAL_ANGGARAN
    FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN
    GROUP BY ID_RENCANA
),
REALISASI AS (
    SELECT a.ID_RENCANA, SUM(x.JUMLAH_PENGELUARAN) AS TOTAL_REALISASI
    FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN x
    JOIN DATA_OPERASIONAL.ALOKASI_ANGGARAN a
        ON a.ID_ALOKASI = x.ID_ALOKASI
    GROUP BY a.ID_RENCANA
)
SELECT
    r.ID_RENCANA,
    h.TAHUN_RENCANA,
    s.ID_SEKSI,
    s.NAMA_SEKSI,
    r.NAMA_PROGRAM,
    r.TANGGAL_RENCANA,
    r.STATUS_PELAKSANAAN,
    COALESCE(a.TOTAL_ANGGARAN, 0) AS ANGGARAN_RENCANA,
    COALESCE(x.TOTAL_REALISASI, 0) AS ANGGARAN_TERPAKAI,
    COALESCE(a.TOTAL_ANGGARAN, 0) - COALESCE(x.TOTAL_REALISASI, 0) AS SISA_ANGGARAN,
    CASE WHEN COALESCE(a.TOTAL_ANGGARAN, 0) = 0 THEN NULL
         ELSE ROUND(100.0 * COALESCE(x.TOTAL_REALISASI, 0) / a.TOTAL_ANGGARAN, 1)
    END AS PERSEN_TERPAKAI,
    CASE WHEN COALESCE(x.TOTAL_REALISASI, 0) = 0 THEN 'Belum ada pengeluaran'
         WHEN x.TOTAL_REALISASI > a.TOTAL_ANGGARAN THEN 'Melebihi anggaran'
         WHEN x.TOTAL_REALISASI >= 0.95 * a.TOTAL_ANGGARAN THEN 'Hampir habis'
         ELSE 'Terpakai sebagian'
    END AS STATUS_PENYERAPAN,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.RENCANA_KEGIATAN r
JOIN DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN h
    ON h.ID_RENCANA_KERJA = r.ID_RENCANA_KERJA
JOIN MASTER_DATA.MASTER_SEKSI s
    ON s.ID_SEKSI = h.ID_SEKSI
LEFT JOIN ANGGARAN a
    ON a.ID_RENCANA = r.ID_RENCANA
LEFT JOIN REALISASI x
    ON x.ID_RENCANA = r.ID_RENCANA;

-- 8. Planned budget versus actual expenditure per section ------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.ANGGARAN_VS_REALISASI_SEKSI
    COMMENT = 'Ringkasan anggaran dan pengeluaran per seksi, termasuk pembandingan khusus untuk program yang sudah terlaksana. Data simulasi.'
AS
SELECT
    ID_SEKSI,
    NAMA_SEKSI,
    TAHUN_RENCANA,
    COUNT(*) AS JUMLAH_PROGRAM,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN 1 ELSE 0 END) AS JUMLAH_TERLAKSANA,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Direncanakan' THEN 1 ELSE 0 END) AS JUMLAH_DIRENCANAKAN,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Ditunda' THEN 1 ELSE 0 END) AS JUMLAH_DITUNDA,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Dibatalkan' THEN 1 ELSE 0 END) AS JUMLAH_DIBATALKAN,
    SUM(ANGGARAN_RENCANA) AS ANGGARAN_SEMUA_PROGRAM,
    SUM(ANGGARAN_TERPAKAI) AS ANGGARAN_TERPAKAI_SEMUA_PROGRAM,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN ANGGARAN_RENCANA ELSE 0 END) AS ANGGARAN_PROGRAM_TERLAKSANA,
    SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN ANGGARAN_TERPAKAI ELSE 0 END) AS REALISASI_PROGRAM_TERLAKSANA,
    CASE WHEN SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN ANGGARAN_RENCANA ELSE 0 END) = 0 THEN NULL
         ELSE ROUND(100.0 * SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN ANGGARAN_TERPAKAI ELSE 0 END)
                    / SUM(CASE WHEN STATUS_PELAKSANAAN = 'Terlaksana' THEN ANGGARAN_RENCANA ELSE 0 END), 1)
    END AS PERSEN_TERPAKAI_PROGRAM_TERLAKSANA,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM
GROUP BY ID_SEKSI, NAMA_SEKSI, TAHUN_RENCANA;

-- 9. Events with their post-event report ----------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.KEGIATAN_DAN_LAPORAN
    COMMENT = 'Setiap kegiatan dengan target peserta, peserta aktual, anggaran, dan status laporan pascakegiatan. Data simulasi.'
AS
SELECT
    e.ID_KEGIATAN,
    e.NAMA_KEGIATAN,
    s.NAMA_SEKSI,
    CASE WHEN e.ID_RENCANA IS NULL THEN 'Tidak direncanakan' ELSE 'Sesuai rencana kerja' END AS JENIS_KEGIATAN,
    e.TANGGAL_MULAI,
    e.TANGGAL_SELESAI,
    e.LOKASI,
    e.STATUS_KEGIATAN,
    e.TARGET_PESERTA,
    e.JUMLAH_PESERTA_AKTUAL,
    CASE WHEN e.JUMLAH_PESERTA_AKTUAL IS NULL OR e.TARGET_PESERTA = 0 THEN NULL
         ELSE ROUND(100.0 * e.JUMLAH_PESERTA_AKTUAL / e.TARGET_PESERTA, 1)
    END AS PERSEN_CAPAIAN_TARGET,
    b.ANGGARAN_RENCANA,
    b.ANGGARAN_TERPAKAI,
    r.ID_LAPORAN,
    CASE WHEN r.ID_LAPORAN IS NOT NULL THEN r.STATUS_LAPORAN
         WHEN e.STATUS_KEGIATAN = 'Terlaksana' THEN 'Belum ada laporan'
         ELSE 'Belum diperlukan'
    END AS STATUS_PELAPORAN,
    r.TANGGAL_LAPORAN,
    CASE WHEN r.ID_LAPORAN IS NULL THEN NULL
         WHEN r.RINGKASAN_PELAKSANAAN IS NOT NULL AND r.JUMLAH_PESERTA IS NOT NULL AND r.REALISASI_BIAYA IS NOT NULL
              AND r.EVALUASI_LOGISTIK IS NOT NULL AND r.HASIL_KEGIATAN IS NOT NULL
              AND r.REKOMENDASI_TINDAK_LANJUT IS NOT NULL THEN 'Isi lengkap'
         ELSE 'Isi belum lengkap'
    END AS KELENGKAPAN_ISI_LAPORAN,
    r.REALISASI_BIAYA AS BIAYA_MENURUT_LAPORAN,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.KEGIATAN e
JOIN MASTER_DATA.MASTER_SEKSI s
    ON s.ID_SEKSI = e.ID_SEKSI
LEFT JOIN DATA_OPERASIONAL.LAPORAN_KEGIATAN r
    ON r.ID_KEGIATAN = e.ID_KEGIATAN
LEFT JOIN ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM b
    ON b.ID_RENCANA = e.ID_RENCANA;

-- 10. Report completion per section ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.KELENGKAPAN_LAPORAN_PER_SEKSI
    COMMENT = 'Jumlah kegiatan per status dan kelengkapan laporan pascakegiatan untuk setiap seksi. Data simulasi.'
AS
SELECT
    NAMA_SEKSI,
    COUNT(*) AS JUMLAH_KEGIATAN,
    SUM(CASE WHEN STATUS_KEGIATAN = 'Terlaksana' THEN 1 ELSE 0 END) AS JUMLAH_TERLAKSANA,
    SUM(CASE WHEN STATUS_KEGIATAN = 'Direncanakan' THEN 1 ELSE 0 END) AS JUMLAH_DIRENCANAKAN,
    SUM(CASE WHEN STATUS_KEGIATAN = 'Ditunda' THEN 1 ELSE 0 END) AS JUMLAH_DITUNDA,
    SUM(CASE WHEN STATUS_KEGIATAN = 'Dibatalkan' THEN 1 ELSE 0 END) AS JUMLAH_DIBATALKAN,
    SUM(CASE WHEN STATUS_PELAPORAN = 'Final' THEN 1 ELSE 0 END) AS JUMLAH_LAPORAN_FINAL,
    SUM(CASE WHEN STATUS_PELAPORAN IN ('Draf', 'Perlu Revisi') THEN 1 ELSE 0 END) AS JUMLAH_LAPORAN_DRAF_ATAU_REVISI,
    SUM(CASE WHEN STATUS_PELAPORAN = 'Belum ada laporan' THEN 1 ELSE 0 END) AS JUMLAH_BELUM_ADA_LAPORAN,
    CASE WHEN SUM(CASE WHEN STATUS_KEGIATAN = 'Terlaksana' THEN 1 ELSE 0 END) = 0 THEN NULL
         ELSE ROUND(100.0 * SUM(CASE WHEN STATUS_PELAPORAN = 'Final' THEN 1 ELSE 0 END)
                    / SUM(CASE WHEN STATUS_KEGIATAN = 'Terlaksana' THEN 1 ELSE 0 END), 1)
    END AS PERSEN_TERLAKSANA_DENGAN_LAPORAN_FINAL,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM ANALISIS.KEGIATAN_DAN_LAPORAN
GROUP BY NAMA_SEKSI;

-- 11. Aggregated survey findings ---------------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.HASIL_SURVEI
    COMMENT = 'Hasil survei yang sudah dirangkum: jumlah dan persentase responden per kategori jawaban. Data simulasi.'
AS
SELECT
    sv.ID_SURVEI,
    sv.JUDUL_SURVEI,
    sv.STATUS_SURVEI,
    q.ID_PERTANYAAN,
    q.NOMOR_URUT AS NOMOR_PERTANYAAN,
    q.TEKS_PERTANYAAN,
    q.JENIS_JAWABAN,
    o.NOMOR_URUT AS NOMOR_OPSI,
    o.KATEGORI_JAWABAN,
    o.NILAI_SKOR,
    h.JUMLAH_RESPONDEN,
    h.TOTAL_RESPONDEN_PERTANYAAN,
    h.PERSENTASE_JAWABAN,
    h.TANGGAL_AGREGASI,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT h
JOIN MASTER_DATA.SURVEI sv
    ON sv.ID_SURVEI = h.ID_SURVEI
JOIN MASTER_DATA.PERTANYAAN_SURVEI q
    ON q.ID_PERTANYAAN = h.ID_PERTANYAAN
JOIN MASTER_DATA.OPSI_JAWABAN_SURVEI o
    ON o.ID_OPSI = h.ID_OPSI;

-- 12. Likert score summary --------------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.RINGKASAN_SKOR_LIKERT
    COMMENT = 'Skor rata-rata (1 sampai 5) dan persentase setuju untuk pertanyaan berskala Likert. Data simulasi.'
AS
SELECT
    ID_SURVEI,
    JUDUL_SURVEI,
    ID_PERTANYAAN,
    NOMOR_PERTANYAAN,
    TEKS_PERTANYAAN,
    MAX(TOTAL_RESPONDEN_PERTANYAAN) AS JUMLAH_RESPONDEN,
    CASE WHEN MAX(TOTAL_RESPONDEN_PERTANYAAN) = 0 THEN NULL
         ELSE ROUND(1.0 * SUM(NILAI_SKOR * JUMLAH_RESPONDEN) / MAX(TOTAL_RESPONDEN_PERTANYAAN), 2)
    END AS SKOR_RATA_RATA,
    SUM(CASE WHEN NILAI_SKOR >= 4 THEN PERSENTASE_JAWABAN ELSE 0 END) AS PERSEN_SETUJU_ATAU_SANGAT_SETUJU,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM ANALISIS.HASIL_SURVEI
WHERE JENIS_JAWABAN = 'Skala Likert'
GROUP BY ID_SURVEI, JUDUL_SURVEI, ID_PERTANYAAN, NOMOR_PERTANYAAN, TEKS_PERTANYAAN;

-- 13. Parishioner counts per community (aggregates only) --------------------------------------------------------------
CREATE OR REPLACE VIEW ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN
    COMMENT = 'Jumlah keluarga dan umat aktif per lingkungan. Hanya angka agregat, tanpa nama atau identitas individu. Data simulasi.'
AS
SELECT
    w.ID_WILAYAH,
    w.NAMA_WILAYAH,
    l.ID_LINGKUNGAN,
    l.NAMA_LINGKUNGAN,
    COUNT(DISTINCT pl.ID_KELUARGA) AS JUMLAH_KELUARGA_AKTIF,
    COUNT(DISTINCT u.ID_UMAT) AS JUMLAH_UMAT_AKTIF,
    'Hanya angka agregat, tanpa data pribadi.' AS CATATAN_PRIVASI,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM MASTER_DATA.MASTER_LINGKUNGAN l
JOIN MASTER_DATA.MASTER_WILAYAH w
    ON w.ID_WILAYAH = l.ID_WILAYAH
LEFT JOIN DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN pl
    ON pl.ID_LINGKUNGAN = l.ID_LINGKUNGAN
   AND pl.TANGGAL_AKHIR_BERLAKU IS NULL
LEFT JOIN DATA_OPERASIONAL.PENUGASAN_KELUARGA pk
    ON pk.ID_KELUARGA = pl.ID_KELUARGA
   AND pk.TANGGAL_AKHIR_BERLAKU IS NULL
LEFT JOIN DATA_OPERASIONAL.UMAT u
    ON u.ID_UMAT = pk.ID_UMAT
   AND u.STATUS_KEANGGOTAAN = 'Aktif'
WHERE l.STATUS_AKTIF = TRUE
GROUP BY w.ID_WILAYAH, w.NAMA_WILAYAH, l.ID_LINGKUNGAN, l.NAMA_LINGKUNGAN;

-- =============================================================================
-- >>> sql/06_validate_data.sql
-- =============================================================================

-- =============================================================================
-- Step 6: Validate the data (read-only)
--
-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py
-- after changing sql/02_create_tables.sql, sql/05_create_views.sql or the generator.
--
-- Purpose : Row counts, duplicate keys, orphaned references, allowed values,
--           negative numbers, date plausibility, cross-domain consistency
--           (Mass schedule, attendance, offertory, plans, budgets, events,
--           reports, surveys) and privacy guards.
-- Output  : ONE result table. The first two rows summarise the run.
--           RESULT is PASS, FAIL (data is wrong), WARN (look at it) or INFO
--           (a deliberate demo scenario, for interpretation only).
--           Expected for the bundled demo data: 0 FAIL and exactly 1 WARN.
-- Safe to re-run: yes. This file only reads data and never changes anything.
-- Dates   : checks use the fixed snapshot date 2026-09-30 of the demo data, never today's date.
-- Seed    : 20260930
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

WITH CHECKS AS (
    SELECT 10 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KLASIFIKASI_DATA) AS FOUND_COUNT,
           4 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 20 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_SEKSI) AS FOUND_COUNT,
           9 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 30 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_INFORMASI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KATEGORI_INFORMASI) AS FOUND_COUNT,
           9 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 40 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_DAFTAR_NILAI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_DAFTAR_NILAI) AS FOUND_COUNT,
           68 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 50 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_JENIS_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_JENIS_KOLEKTE) AS FOUND_COUNT,
           3 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 60 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS) AS FOUND_COUNT,
           3 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 70 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_BIAYA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KATEGORI_BIAYA) AS FOUND_COUNT,
           7 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 80 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_PERIODE_PELAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_PERIODE_PELAPORAN) AS FOUND_COUNT,
           24 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 90 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.KEBIJAKAN_AKSES_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.KEBIJAKAN_AKSES_DATA) AS FOUND_COUNT,
           20 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 100 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_WILAYAH) AS FOUND_COUNT,
           6 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 110 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN) AS FOUND_COUNT,
           19 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 120 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN) AS FOUND_COUNT,
           18 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 130 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA) AS FOUND_COUNT,
           7 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 140 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI) AS FOUND_COUNT,
           4 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 150 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.PERTANYAAN_SURVEI) AS FOUND_COUNT,
           17 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 160 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'MASTER_DATA.OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.OPSI_JAWABAN_SURVEI) AS FOUND_COUNT,
           85 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 170 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA) AS FOUND_COUNT,
           182 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 180 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA) AS FOUND_COUNT,
           155 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 190 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE) AS FOUND_COUNT,
           292 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 200 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS) AS FOUND_COUNT,
           24 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 210 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA) AS FOUND_COUNT,
           227 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 220 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT) AS FOUND_COUNT,
           653 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 230 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA) AS FOUND_COUNT,
           659 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 240 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN) AS FOUND_COUNT,
           237 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 250 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI) AS FOUND_COUNT,
           214 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 260 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI) AS FOUND_COUNT,
           1040 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 270 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT) AS FOUND_COUNT,
           76 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 280 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN) AS FOUND_COUNT,
           9 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 290 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN) AS FOUND_COUNT,
           42 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 300 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN) AS FOUND_COUNT,
           117 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 310 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN) AS FOUND_COUNT,
           124 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 320 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN) AS FOUND_COUNT,
           36 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 330 AS SORT_ORDER, 'STRUCTURE' AS CHECK_GROUP, 'Row count' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN) AS FOUND_COUNT,
           24 AS EXPECTED_COUNT, 'ROWS' AS RULE_TYPE,
           'Row count of the bundled demo data.' AS NOTE
    UNION ALL
    SELECT 340 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KLASIFIKASI_DATA FROM MASTER_DATA.REFERENSI_KLASIFIKASI_DATA WHERE ID_KLASIFIKASI_DATA IS NOT NULL GROUP BY ID_KLASIFIKASI_DATA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KLASIFIKASI_DATA).' AS NOTE
    UNION ALL
    SELECT 350 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_SEKSI FROM MASTER_DATA.MASTER_SEKSI WHERE ID_SEKSI IS NOT NULL GROUP BY ID_SEKSI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_SEKSI).' AS NOTE
    UNION ALL
    SELECT 360 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_INFORMASI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KATEGORI_INFORMASI FROM MASTER_DATA.REFERENSI_KATEGORI_INFORMASI WHERE ID_KATEGORI_INFORMASI IS NOT NULL GROUP BY ID_KATEGORI_INFORMASI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KATEGORI_INFORMASI).' AS NOTE
    UNION ALL
    SELECT 370 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_DAFTAR_NILAI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT KELOMPOK_NILAI, NILAI FROM MASTER_DATA.REFERENSI_DAFTAR_NILAI WHERE KELOMPOK_NILAI IS NOT NULL AND NILAI IS NOT NULL GROUP BY KELOMPOK_NILAI, NILAI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (KELOMPOK_NILAI, NILAI).' AS NOTE
    UNION ALL
    SELECT 380 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_JENIS_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_JENIS_KOLEKTE FROM MASTER_DATA.REFERENSI_JENIS_KOLEKTE WHERE ID_JENIS_KOLEKTE IS NOT NULL GROUP BY ID_JENIS_KOLEKTE HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_JENIS_KOLEKTE).' AS NOTE
    UNION ALL
    SELECT 390 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KESEMPATAN FROM MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS WHERE ID_KESEMPATAN IS NOT NULL GROUP BY ID_KESEMPATAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KESEMPATAN).' AS NOTE
    UNION ALL
    SELECT 400 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_BIAYA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KATEGORI_BIAYA FROM MASTER_DATA.REFERENSI_KATEGORI_BIAYA WHERE ID_KATEGORI_BIAYA IS NOT NULL GROUP BY ID_KATEGORI_BIAYA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KATEGORI_BIAYA).' AS NOTE
    UNION ALL
    SELECT 410 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_PERIODE_PELAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PERIODE_PELAPORAN FROM MASTER_DATA.REFERENSI_PERIODE_PELAPORAN WHERE ID_PERIODE_PELAPORAN IS NOT NULL GROUP BY ID_PERIODE_PELAPORAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PERIODE_PELAPORAN).' AS NOTE
    UNION ALL
    SELECT 420 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.KEBIJAKAN_AKSES_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA FROM MASTER_DATA.KEBIJAKAN_AKSES_DATA WHERE ID_KLASIFIKASI_DATA IS NOT NULL AND KELOMPOK_PENGGUNA IS NOT NULL GROUP BY ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA).' AS NOTE
    UNION ALL
    SELECT 430 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_WILAYAH FROM MASTER_DATA.MASTER_WILAYAH WHERE ID_WILAYAH IS NOT NULL GROUP BY ID_WILAYAH HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_WILAYAH).' AS NOTE
    UNION ALL
    SELECT 440 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_LINGKUNGAN FROM MASTER_DATA.MASTER_LINGKUNGAN WHERE ID_LINGKUNGAN IS NOT NULL GROUP BY ID_LINGKUNGAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_LINGKUNGAN).' AS NOTE
    UNION ALL
    SELECT 450 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_GEOMETRI FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN WHERE ID_GEOMETRI IS NOT NULL GROUP BY ID_GEOMETRI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_GEOMETRI).' AS NOTE
    UNION ALL
    SELECT 460 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_GEOMETRI_LINGKUNGAN' AS CHECK_NAME,
           'MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_LINGKUNGAN FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN WHERE ID_LINGKUNGAN IS NOT NULL GROUP BY ID_LINGKUNGAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_LINGKUNGAN).' AS NOTE
    UNION ALL
    SELECT 470 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_JADWAL_MISA FROM MASTER_DATA.JADWAL_MISA WHERE ID_JADWAL_MISA IS NOT NULL GROUP BY ID_JADWAL_MISA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_JADWAL_MISA).' AS NOTE
    UNION ALL
    SELECT 480 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_SURVEI FROM MASTER_DATA.SURVEI WHERE ID_SURVEI IS NOT NULL GROUP BY ID_SURVEI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_SURVEI).' AS NOTE
    UNION ALL
    SELECT 490 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN FROM MASTER_DATA.PERTANYAAN_SURVEI WHERE ID_PERTANYAAN IS NOT NULL GROUP BY ID_PERTANYAAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PERTANYAAN).' AS NOTE
    UNION ALL
    SELECT 500 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_PERTANYAAN_SURVEI_URUT' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_SURVEI, NOMOR_URUT FROM MASTER_DATA.PERTANYAAN_SURVEI WHERE ID_SURVEI IS NOT NULL AND NOMOR_URUT IS NOT NULL GROUP BY ID_SURVEI, NOMOR_URUT HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_SURVEI, NOMOR_URUT).' AS NOTE
    UNION ALL
    SELECT 510 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'MASTER_DATA.OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_OPSI FROM MASTER_DATA.OPSI_JAWABAN_SURVEI WHERE ID_OPSI IS NOT NULL GROUP BY ID_OPSI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_OPSI).' AS NOTE
    UNION ALL
    SELECT 520 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_OPSI_JAWABAN_URUT' AS CHECK_NAME,
           'MASTER_DATA.OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN, NOMOR_URUT FROM MASTER_DATA.OPSI_JAWABAN_SURVEI WHERE ID_PERTANYAAN IS NOT NULL AND NOMOR_URUT IS NOT NULL GROUP BY ID_PERTANYAAN, NOMOR_URUT HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PERTANYAAN, NOMOR_URUT).' AS NOTE
    UNION ALL
    SELECT 530 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEJADIAN_MISA FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE ID_KEJADIAN_MISA IS NOT NULL GROUP BY ID_KEJADIAN_MISA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEJADIAN_MISA).' AS NOTE
    UNION ALL
    SELECT 540 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_KEJADIAN_MISA_JADWAL_TANGGAL' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_JADWAL_MISA, TANGGAL_MISA FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE ID_JADWAL_MISA IS NOT NULL AND TANGGAL_MISA IS NOT NULL GROUP BY ID_JADWAL_MISA, TANGGAL_MISA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_JADWAL_MISA, TANGGAL_MISA).' AS NOTE
    UNION ALL
    SELECT 550 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEHADIRAN FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEHADIRAN IS NOT NULL GROUP BY ID_KEHADIRAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEHADIRAN).' AS NOTE
    UNION ALL
    SELECT 560 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_KEHADIRAN_MISA_KEJADIAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEJADIAN_MISA FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE ID_KEJADIAN_MISA IS NOT NULL GROUP BY ID_KEJADIAN_MISA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEJADIAN_MISA).' AS NOTE
    UNION ALL
    SELECT 570 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KOLEKTE FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE ID_KOLEKTE IS NOT NULL GROUP BY ID_KOLEKTE HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KOLEKTE).' AS NOTE
    UNION ALL
    SELECT 580 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_PENERIMAAN_KOLEKTE_KEJADIAN_JENIS' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE ID_KEJADIAN_MISA IS NOT NULL AND ID_JENIS_KOLEKTE IS NOT NULL GROUP BY ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE).' AS NOTE
    UNION ALL
    SELECT 590 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_SUMBANGAN FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE ID_SUMBANGAN IS NOT NULL GROUP BY ID_SUMBANGAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_SUMBANGAN).' AS NOTE
    UNION ALL
    SELECT 600 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_SUMBANGAN_WILAYAH_KESEMPATAN_PERIODE' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE ID_WILAYAH IS NOT NULL AND ID_KESEMPATAN IS NOT NULL AND PERIODE_MULAI IS NOT NULL GROUP BY ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_WILAYAH, ID_KESEMPATAN, PERIODE_MULAI).' AS NOTE
    UNION ALL
    SELECT 610 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KELUARGA FROM DATA_OPERASIONAL.KELUARGA WHERE ID_KELUARGA IS NOT NULL GROUP BY ID_KELUARGA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KELUARGA).' AS NOTE
    UNION ALL
    SELECT 620 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_UMAT FROM DATA_OPERASIONAL.UMAT WHERE ID_UMAT IS NOT NULL GROUP BY ID_UMAT HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_UMAT).' AS NOTE
    UNION ALL
    SELECT 630 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PENUGASAN_KELUARGA FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA WHERE ID_PENUGASAN_KELUARGA IS NOT NULL GROUP BY ID_PENUGASAN_KELUARGA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PENUGASAN_KELUARGA).' AS NOTE
    UNION ALL
    SELECT 640 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PENUGASAN_LINGKUNGAN FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN WHERE ID_PENUGASAN_LINGKUNGAN IS NOT NULL GROUP BY ID_PENUGASAN_LINGKUNGAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PENUGASAN_LINGKUNGAN).' AS NOTE
    UNION ALL
    SELECT 650 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RESPONDEN FROM DATA_OPERASIONAL.RESPONDEN_SURVEI WHERE ID_RESPONDEN IS NOT NULL GROUP BY ID_RESPONDEN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RESPONDEN).' AS NOTE
    UNION ALL
    SELECT 660 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_JAWABAN FROM DATA_OPERASIONAL.JAWABAN_SURVEI WHERE ID_JAWABAN IS NOT NULL GROUP BY ID_JAWABAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_JAWABAN).' AS NOTE
    UNION ALL
    SELECT 670 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_JAWABAN_RESPONDEN_PERTANYAAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RESPONDEN, ID_PERTANYAAN FROM DATA_OPERASIONAL.JAWABAN_SURVEI WHERE ID_RESPONDEN IS NOT NULL AND ID_PERTANYAAN IS NOT NULL GROUP BY ID_RESPONDEN, ID_PERTANYAAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RESPONDEN, ID_PERTANYAAN).' AS NOTE
    UNION ALL
    SELECT 680 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_HASIL FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE ID_HASIL IS NOT NULL GROUP BY ID_HASIL HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_HASIL).' AS NOTE
    UNION ALL
    SELECT 690 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_HASIL_SURVEI_OPSI' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_OPSI FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE ID_OPSI IS NOT NULL GROUP BY ID_OPSI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_OPSI).' AS NOTE
    UNION ALL
    SELECT 700 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RENCANA_KERJA FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN WHERE ID_RENCANA_KERJA IS NOT NULL GROUP BY ID_RENCANA_KERJA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RENCANA_KERJA).' AS NOTE
    UNION ALL
    SELECT 710 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_RENCANA_KERJA_SEKSI_TAHUN' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_SEKSI, TAHUN_RENCANA FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN WHERE ID_SEKSI IS NOT NULL AND TAHUN_RENCANA IS NOT NULL GROUP BY ID_SEKSI, TAHUN_RENCANA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_SEKSI, TAHUN_RENCANA).' AS NOTE
    UNION ALL
    SELECT 720 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RENCANA FROM DATA_OPERASIONAL.RENCANA_KEGIATAN WHERE ID_RENCANA IS NOT NULL GROUP BY ID_RENCANA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RENCANA).' AS NOTE
    UNION ALL
    SELECT 730 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_ALOKASI FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN WHERE ID_ALOKASI IS NOT NULL GROUP BY ID_ALOKASI HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_ALOKASI).' AS NOTE
    UNION ALL
    SELECT 740 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_ALOKASI_RENCANA_KATEGORI' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RENCANA, ID_KATEGORI_BIAYA FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN WHERE ID_RENCANA IS NOT NULL AND ID_KATEGORI_BIAYA IS NOT NULL GROUP BY ID_RENCANA, ID_KATEGORI_BIAYA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RENCANA, ID_KATEGORI_BIAYA).' AS NOTE
    UNION ALL
    SELECT 750 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PENGELUARAN FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN WHERE ID_PENGELUARAN IS NOT NULL GROUP BY ID_PENGELUARAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_PENGELUARAN).' AS NOTE
    UNION ALL
    SELECT 760 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEGIATAN FROM DATA_OPERASIONAL.KEGIATAN WHERE ID_KEGIATAN IS NOT NULL GROUP BY ID_KEGIATAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEGIATAN).' AS NOTE
    UNION ALL
    SELECT 770 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_KEGIATAN_RENCANA' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_RENCANA FROM DATA_OPERASIONAL.KEGIATAN WHERE ID_RENCANA IS NOT NULL GROUP BY ID_RENCANA HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_RENCANA).' AS NOTE
    UNION ALL
    SELECT 780 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate primary key' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_LAPORAN FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE ID_LAPORAN IS NOT NULL GROUP BY ID_LAPORAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_LAPORAN).' AS NOTE
    UNION ALL
    SELECT 790 AS SORT_ORDER, 'KEYS' AS CHECK_GROUP, 'Duplicate unique key UQ_LAPORAN_KEGIATAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KEGIATAN FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE ID_KEGIATAN IS NOT NULL GROUP BY ID_KEGIATAN HAVING COUNT(*) > 1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Number of key values that occur more than once (ID_KEGIATAN).' AS NOTE
    UNION ALL
    SELECT 800 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_INFORMASI.ID_KLASIFIKASI_DATA -> REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KATEGORI_INFORMASI c LEFT JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA p ON c.ID_KLASIFIKASI_DATA = p.ID_KLASIFIKASI_DATA WHERE c.ID_KLASIFIKASI_DATA IS NOT NULL AND p.ID_KLASIFIKASI_DATA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 810 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KATEGORI_INFORMASI.ID_SEKSI_PENGELOLA -> MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KATEGORI_INFORMASI c LEFT JOIN MASTER_DATA.MASTER_SEKSI p ON c.ID_SEKSI_PENGELOLA = p.ID_SEKSI WHERE c.ID_SEKSI_PENGELOLA IS NOT NULL AND p.ID_SEKSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 820 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.KEBIJAKAN_AKSES_DATA.ID_KLASIFIKASI_DATA -> REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.KEBIJAKAN_AKSES_DATA c LEFT JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA p ON c.ID_KLASIFIKASI_DATA = p.ID_KLASIFIKASI_DATA WHERE c.ID_KLASIFIKASI_DATA IS NOT NULL AND p.ID_KLASIFIKASI_DATA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 830 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN.ID_WILAYAH -> MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN c LEFT JOIN MASTER_DATA.MASTER_WILAYAH p ON c.ID_WILAYAH = p.ID_WILAYAH WHERE c.ID_WILAYAH IS NOT NULL AND p.ID_WILAYAH IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 840 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN.ID_LINGKUNGAN -> MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN c LEFT JOIN MASTER_DATA.MASTER_LINGKUNGAN p ON c.ID_LINGKUNGAN = p.ID_LINGKUNGAN WHERE c.ID_LINGKUNGAN IS NOT NULL AND p.ID_LINGKUNGAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 850 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.SURVEI.ID_SEKSI -> MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI c LEFT JOIN MASTER_DATA.MASTER_SEKSI p ON c.ID_SEKSI = p.ID_SEKSI WHERE c.ID_SEKSI IS NOT NULL AND p.ID_SEKSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 860 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.SURVEI.ID_KLASIFIKASI_DATA -> REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI c LEFT JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA p ON c.ID_KLASIFIKASI_DATA = p.ID_KLASIFIKASI_DATA WHERE c.ID_KLASIFIKASI_DATA IS NOT NULL AND p.ID_KLASIFIKASI_DATA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 870 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI.ID_SURVEI -> SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.PERTANYAAN_SURVEI c LEFT JOIN MASTER_DATA.SURVEI p ON c.ID_SURVEI = p.ID_SURVEI WHERE c.ID_SURVEI IS NOT NULL AND p.ID_SURVEI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 880 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'MASTER_DATA.OPSI_JAWABAN_SURVEI.ID_PERTANYAAN -> PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.OPSI_JAWABAN_SURVEI c LEFT JOIN MASTER_DATA.PERTANYAAN_SURVEI p ON c.ID_PERTANYAAN = p.ID_PERTANYAAN WHERE c.ID_PERTANYAAN IS NOT NULL AND p.ID_PERTANYAAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 890 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA.ID_JADWAL_MISA -> JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA c LEFT JOIN MASTER_DATA.JADWAL_MISA p ON c.ID_JADWAL_MISA = p.ID_JADWAL_MISA WHERE c.ID_JADWAL_MISA IS NOT NULL AND p.ID_JADWAL_MISA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 900 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA.ID_KEJADIAN_MISA -> KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA c LEFT JOIN DATA_OPERASIONAL.KEJADIAN_MISA p ON c.ID_KEJADIAN_MISA = p.ID_KEJADIAN_MISA WHERE c.ID_KEJADIAN_MISA IS NOT NULL AND p.ID_KEJADIAN_MISA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 910 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE.ID_KEJADIAN_MISA -> KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE c LEFT JOIN DATA_OPERASIONAL.KEJADIAN_MISA p ON c.ID_KEJADIAN_MISA = p.ID_KEJADIAN_MISA WHERE c.ID_KEJADIAN_MISA IS NOT NULL AND p.ID_KEJADIAN_MISA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 920 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE.ID_JENIS_KOLEKTE -> REFERENSI_JENIS_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE c LEFT JOIN MASTER_DATA.REFERENSI_JENIS_KOLEKTE p ON c.ID_JENIS_KOLEKTE = p.ID_JENIS_KOLEKTE WHERE c.ID_JENIS_KOLEKTE IS NOT NULL AND p.ID_JENIS_KOLEKTE IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 930 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS.ID_WILAYAH -> MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS c LEFT JOIN MASTER_DATA.MASTER_WILAYAH p ON c.ID_WILAYAH = p.ID_WILAYAH WHERE c.ID_WILAYAH IS NOT NULL AND p.ID_WILAYAH IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 940 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS.ID_KESEMPATAN -> REFERENSI_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS c LEFT JOIN MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS p ON c.ID_KESEMPATAN = p.ID_KESEMPATAN WHERE c.ID_KESEMPATAN IS NOT NULL AND p.ID_KESEMPATAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 950 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA.ID_KLASIFIKASI_DATA -> REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA c LEFT JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA p ON c.ID_KLASIFIKASI_DATA = p.ID_KLASIFIKASI_DATA WHERE c.ID_KLASIFIKASI_DATA IS NOT NULL AND p.ID_KLASIFIKASI_DATA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 960 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT.ID_KLASIFIKASI_DATA -> REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT c LEFT JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA p ON c.ID_KLASIFIKASI_DATA = p.ID_KLASIFIKASI_DATA WHERE c.ID_KLASIFIKASI_DATA IS NOT NULL AND p.ID_KLASIFIKASI_DATA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 970 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA.ID_UMAT -> UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA c LEFT JOIN DATA_OPERASIONAL.UMAT p ON c.ID_UMAT = p.ID_UMAT WHERE c.ID_UMAT IS NOT NULL AND p.ID_UMAT IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 980 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA.ID_KELUARGA -> KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA c LEFT JOIN DATA_OPERASIONAL.KELUARGA p ON c.ID_KELUARGA = p.ID_KELUARGA WHERE c.ID_KELUARGA IS NOT NULL AND p.ID_KELUARGA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 990 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN.ID_KELUARGA -> KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN c LEFT JOIN DATA_OPERASIONAL.KELUARGA p ON c.ID_KELUARGA = p.ID_KELUARGA WHERE c.ID_KELUARGA IS NOT NULL AND p.ID_KELUARGA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1000 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN.ID_LINGKUNGAN -> MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN c LEFT JOIN MASTER_DATA.MASTER_LINGKUNGAN p ON c.ID_LINGKUNGAN = p.ID_LINGKUNGAN WHERE c.ID_LINGKUNGAN IS NOT NULL AND p.ID_LINGKUNGAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1010 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI.ID_SURVEI -> SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI c LEFT JOIN MASTER_DATA.SURVEI p ON c.ID_SURVEI = p.ID_SURVEI WHERE c.ID_SURVEI IS NOT NULL AND p.ID_SURVEI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1020 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI.ID_WILAYAH -> MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI c LEFT JOIN MASTER_DATA.MASTER_WILAYAH p ON c.ID_WILAYAH = p.ID_WILAYAH WHERE c.ID_WILAYAH IS NOT NULL AND p.ID_WILAYAH IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1030 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI.ID_RESPONDEN -> RESPONDEN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI c LEFT JOIN DATA_OPERASIONAL.RESPONDEN_SURVEI p ON c.ID_RESPONDEN = p.ID_RESPONDEN WHERE c.ID_RESPONDEN IS NOT NULL AND p.ID_RESPONDEN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1040 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI.ID_PERTANYAAN -> PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI c LEFT JOIN MASTER_DATA.PERTANYAAN_SURVEI p ON c.ID_PERTANYAAN = p.ID_PERTANYAAN WHERE c.ID_PERTANYAAN IS NOT NULL AND p.ID_PERTANYAAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1050 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI.ID_OPSI -> OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI c LEFT JOIN MASTER_DATA.OPSI_JAWABAN_SURVEI p ON c.ID_OPSI = p.ID_OPSI WHERE c.ID_OPSI IS NOT NULL AND p.ID_OPSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1060 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT.ID_SURVEI -> SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT c LEFT JOIN MASTER_DATA.SURVEI p ON c.ID_SURVEI = p.ID_SURVEI WHERE c.ID_SURVEI IS NOT NULL AND p.ID_SURVEI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1070 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT.ID_PERTANYAAN -> PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT c LEFT JOIN MASTER_DATA.PERTANYAAN_SURVEI p ON c.ID_PERTANYAAN = p.ID_PERTANYAAN WHERE c.ID_PERTANYAAN IS NOT NULL AND p.ID_PERTANYAAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1080 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT.ID_OPSI -> OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT c LEFT JOIN MASTER_DATA.OPSI_JAWABAN_SURVEI p ON c.ID_OPSI = p.ID_OPSI WHERE c.ID_OPSI IS NOT NULL AND p.ID_OPSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1090 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN.ID_SEKSI -> MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN c LEFT JOIN MASTER_DATA.MASTER_SEKSI p ON c.ID_SEKSI = p.ID_SEKSI WHERE c.ID_SEKSI IS NOT NULL AND p.ID_SEKSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1100 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN.ID_RENCANA_KERJA -> RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN c LEFT JOIN DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN p ON c.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE c.ID_RENCANA_KERJA IS NOT NULL AND p.ID_RENCANA_KERJA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1110 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN.ID_RENCANA -> RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN c LEFT JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON c.ID_RENCANA = p.ID_RENCANA WHERE c.ID_RENCANA IS NOT NULL AND p.ID_RENCANA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1120 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN.ID_KATEGORI_BIAYA -> REFERENSI_KATEGORI_BIAYA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN c LEFT JOIN MASTER_DATA.REFERENSI_KATEGORI_BIAYA p ON c.ID_KATEGORI_BIAYA = p.ID_KATEGORI_BIAYA WHERE c.ID_KATEGORI_BIAYA IS NOT NULL AND p.ID_KATEGORI_BIAYA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1130 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN.ID_ALOKASI -> ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN c LEFT JOIN DATA_OPERASIONAL.ALOKASI_ANGGARAN p ON c.ID_ALOKASI = p.ID_ALOKASI WHERE c.ID_ALOKASI IS NOT NULL AND p.ID_ALOKASI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1140 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN.ID_RENCANA -> RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN c LEFT JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON c.ID_RENCANA = p.ID_RENCANA WHERE c.ID_RENCANA IS NOT NULL AND p.ID_RENCANA IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1150 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN.ID_SEKSI -> MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN c LEFT JOIN MASTER_DATA.MASTER_SEKSI p ON c.ID_SEKSI = p.ID_SEKSI WHERE c.ID_SEKSI IS NOT NULL AND p.ID_SEKSI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1160 AS SORT_ORDER, 'REFERENCES' AS CHECK_GROUP, 'Orphaned reference' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN.ID_KEGIATAN -> KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN c LEFT JOIN DATA_OPERASIONAL.KEGIATAN p ON c.ID_KEGIATAN = p.ID_KEGIATAN WHERE c.ID_KEGIATAN IS NOT NULL AND p.ID_KEGIATAN IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Child rows whose parent row does not exist.' AS NOTE
    UNION ALL
    SELECT 1170 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list HARI' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA.HARI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'HARI' AND v.NILAI = x.HARI WHERE x.HARI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1180 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list BAHASA_MISA' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA.BAHASA_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'BAHASA_MISA' AND v.NILAI = x.BAHASA_MISA WHERE x.BAHASA_MISA IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1190 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list MUSIM_LITURGI' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS.MUSIM_LITURGI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'MUSIM_LITURGI' AND v.NILAI = x.MUSIM_LITURGI WHERE x.MUSIM_LITURGI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1200 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list KELOMPOK_PENGGUNA' AS CHECK_NAME,
           'MASTER_DATA.KEBIJAKAN_AKSES_DATA.KELOMPOK_PENGGUNA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.KEBIJAKAN_AKSES_DATA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'KELOMPOK_PENGGUNA' AND v.NILAI = x.KELOMPOK_PENGGUNA WHERE x.KELOMPOK_PENGGUNA IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1210 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list TINGKAT_AKSES' AS CHECK_NAME,
           'MASTER_DATA.KEBIJAKAN_AKSES_DATA.TINGKAT_AKSES' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.KEBIJAKAN_AKSES_DATA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'TINGKAT_AKSES' AND v.NILAI = x.TINGKAT_AKSES WHERE x.TINGKAT_AKSES IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1220 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_SURVEI' AS CHECK_NAME,
           'MASTER_DATA.SURVEI.STATUS_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_SURVEI' AND v.NILAI = x.STATUS_SURVEI WHERE x.STATUS_SURVEI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1230 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list JENIS_JAWABAN' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI.JENIS_JAWABAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.PERTANYAAN_SURVEI x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'JENIS_JAWABAN' AND v.NILAI = x.JENIS_JAWABAN WHERE x.JENIS_JAWABAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1240 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_PELAKSANAAN_MISA' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA.STATUS_PELAKSANAAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_PELAKSANAAN_MISA' AND v.NILAI = x.STATUS_PELAKSANAAN WHERE x.STATUS_PELAKSANAAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1250 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list METODE_PENGHITUNGAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA.METODE_PENGHITUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'METODE_PENGHITUNGAN' AND v.NILAI = x.METODE_PENGHITUNGAN WHERE x.METODE_PENGHITUNGAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1260 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_VALIDASI' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA.STATUS_VALIDASI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_VALIDASI' AND v.NILAI = x.STATUS_VALIDASI WHERE x.STATUS_VALIDASI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1270 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_REKONSILIASI' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE.STATUS_REKONSILIASI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_REKONSILIASI' AND v.NILAI = x.STATUS_REKONSILIASI WHERE x.STATUS_REKONSILIASI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1280 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_VALIDASI' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS.STATUS_VALIDASI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_VALIDASI' AND v.NILAI = x.STATUS_VALIDASI WHERE x.STATUS_VALIDASI IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1290 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_KELUARGA' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA.STATUS_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_KELUARGA' AND v.NILAI = x.STATUS_KELUARGA WHERE x.STATUS_KELUARGA IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1300 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list JENIS_KELAMIN' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT.JENIS_KELAMIN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'JENIS_KELAMIN' AND v.NILAI = x.JENIS_KELAMIN WHERE x.JENIS_KELAMIN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1310 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_KEANGGOTAAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT.STATUS_KEANGGOTAAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_KEANGGOTAAN' AND v.NILAI = x.STATUS_KEANGGOTAAN WHERE x.STATUS_KEANGGOTAAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1320 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list PERAN_DALAM_KELUARGA' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA.PERAN_DALAM_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'PERAN_DALAM_KELUARGA' AND v.NILAI = x.PERAN_DALAM_KELUARGA WHERE x.PERAN_DALAM_KELUARGA IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1330 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list KELOMPOK_USIA' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI.KELOMPOK_USIA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'KELOMPOK_USIA' AND v.NILAI = x.KELOMPOK_USIA WHERE x.KELOMPOK_USIA IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1340 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_PENGESAHAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN.STATUS_PENGESAHAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_PENGESAHAN' AND v.NILAI = x.STATUS_PENGESAHAN WHERE x.STATUS_PENGESAHAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1350 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_PELAKSANAAN_RENCANA' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN.STATUS_PELAKSANAAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_PELAKSANAAN_RENCANA' AND v.NILAI = x.STATUS_PELAKSANAAN WHERE x.STATUS_PELAKSANAAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1360 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_KEGIATAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN.STATUS_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_KEGIATAN' AND v.NILAI = x.STATUS_KEGIATAN WHERE x.STATUS_KEGIATAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1370 AS SORT_ORDER, 'VOCABULARY' AS CHECK_GROUP, 'Value not in list STATUS_LAPORAN' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN.STATUS_LAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN x LEFT JOIN MASTER_DATA.REFERENSI_DAFTAR_NILAI v ON v.KELOMPOK_NILAI = 'STATUS_LAPORAN' AND v.NILAI = x.STATUS_LAPORAN WHERE x.STATUS_LAPORAN IS NOT NULL AND v.NILAI IS NULL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI.' AS NOTE
    UNION ALL
    SELECT 1380 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_KLASIFIKASI_DATA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_KLASIFIKASI_DATA WHERE URUTAN_TINGKAT < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in URUTAN_TINGKAT.' AS NOTE
    UNION ALL
    SELECT 1390 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_SEKSI WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1400 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'MASTER_DATA.MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_SEKSI WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1410 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Active flag matches end date' AS CHECK_NAME,
           'MASTER_DATA.MASTER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_SEKSI WHERE (STATUS_AKTIF = TRUE AND TANGGAL_AKHIR_BERLAKU IS NOT NULL) OR (STATUS_AKTIF = FALSE AND TANGGAL_AKHIR_BERLAKU IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'STATUS_AKTIF must be TRUE exactly when there is no end date.' AS NOTE
    UNION ALL
    SELECT 1420 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_DAFTAR_NILAI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_DAFTAR_NILAI WHERE URUTAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in URUTAN.' AS NOTE
    UNION ALL
    SELECT 1430 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_PERIODE_PELAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_PERIODE_PELAPORAN WHERE TAHUN < 0 OR BULAN < 0 OR KUARTAL < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in TAHUN, BULAN, KUARTAL.' AS NOTE
    UNION ALL
    SELECT 1440 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.REFERENSI_PERIODE_PELAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.REFERENSI_PERIODE_PELAPORAN WHERE TANGGAL_MULAI < DATE '2000-01-01' OR TANGGAL_MULAI > DATE '2027-12-31' OR TANGGAL_SELESAI < DATE '2000-01-01' OR TANGGAL_SELESAI > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI, TANGGAL_SELESAI.' AS NOTE
    UNION ALL
    SELECT 1450 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_WILAYAH WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1460 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'MASTER_DATA.MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_WILAYAH WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1470 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Active flag matches end date' AS CHECK_NAME,
           'MASTER_DATA.MASTER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_WILAYAH WHERE (STATUS_AKTIF = TRUE AND TANGGAL_AKHIR_BERLAKU IS NOT NULL) OR (STATUS_AKTIF = FALSE AND TANGGAL_AKHIR_BERLAKU IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'STATUS_AKTIF must be TRUE exactly when there is no end date.' AS NOTE
    UNION ALL
    SELECT 1480 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1490 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1500 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Active flag matches end date' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN WHERE (STATUS_AKTIF = TRUE AND TANGGAL_AKHIR_BERLAKU IS NOT NULL) OR (STATUS_AKTIF = FALSE AND TANGGAL_AKHIR_BERLAKU IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'STATUS_AKTIF must be TRUE exactly when there is no end date.' AS NOTE
    UNION ALL
    SELECT 1510 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1520 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1530 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Active flag matches end date' AS CHECK_NAME,
           'MASTER_DATA.JADWAL_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.JADWAL_MISA WHERE (STATUS_AKTIF = TRUE AND TANGGAL_AKHIR_BERLAKU IS NOT NULL) OR (STATUS_AKTIF = FALSE AND TANGGAL_AKHIR_BERLAKU IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'STATUS_AKTIF must be TRUE exactly when there is no end date.' AS NOTE
    UNION ALL
    SELECT 1540 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'MASTER_DATA.SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI WHERE TANGGAL_MULAI < DATE '2000-01-01' OR TANGGAL_MULAI > DATE '2027-12-31' OR TANGGAL_SELESAI < DATE '2000-01-01' OR TANGGAL_SELESAI > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI, TANGGAL_SELESAI.' AS NOTE
    UNION ALL
    SELECT 1550 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'MASTER_DATA.PERTANYAAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.PERTANYAAN_SURVEI WHERE NOMOR_URUT < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in NOMOR_URUT.' AS NOTE
    UNION ALL
    SELECT 1560 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'MASTER_DATA.OPSI_JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.OPSI_JAWABAN_SURVEI WHERE NOMOR_URUT < 0 OR NILAI_SKOR < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in NOMOR_URUT, NILAI_SKOR.' AS NOTE
    UNION ALL
    SELECT 1570 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE TANGGAL_MISA < DATE '2000-01-01' OR TANGGAL_MISA > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MISA.' AS NOTE
    UNION ALL
    SELECT 1580 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE JUMLAH_UMAT < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_UMAT.' AS NOTE
    UNION ALL
    SELECT 1590 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE JUMLAH_PENERIMAAN < 0 OR JUMLAH_HASIL_PENGHITUNGAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_PENERIMAAN, JUMLAH_HASIL_PENGHITUNGAN.' AS NOTE
    UNION ALL
    SELECT 1600 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE TANGGAL_PENCATATAN < DATE '2000-01-01' OR TANGGAL_PENCATATAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_PENCATATAN.' AS NOTE
    UNION ALL
    SELECT 1610 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE JUMLAH_KELUARGA_PESERTA < 0 OR JUMLAH_SUMBANGAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_KELUARGA_PESERTA, JUMLAH_SUMBANGAN.' AS NOTE
    UNION ALL
    SELECT 1620 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE PERIODE_MULAI < DATE '2000-01-01' OR PERIODE_MULAI > DATE '2027-12-31' OR PERIODE_SELESAI < DATE '2000-01-01' OR PERIODE_SELESAI > DATE '2027-12-31' OR TANGGAL_PENCATATAN < DATE '2000-01-01' OR TANGGAL_PENCATATAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in PERIODE_MULAI, PERIODE_SELESAI, TANGGAL_PENCATATAN.' AS NOTE
    UNION ALL
    SELECT 1630 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA WHERE TANGGAL_TERDAFTAR < DATE '2000-01-01' OR TANGGAL_TERDAFTAR > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_TERDAFTAR.' AS NOTE
    UNION ALL
    SELECT 1640 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT WHERE TAHUN_LAHIR < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in TAHUN_LAHIR.' AS NOTE
    UNION ALL
    SELECT 1650 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT WHERE TANGGAL_TERDAFTAR < DATE '2000-01-01' OR TANGGAL_TERDAFTAR > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_TERDAFTAR.' AS NOTE
    UNION ALL
    SELECT 1660 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1670 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1680 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN WHERE TANGGAL_MULAI_BERLAKU < DATE '2000-01-01' OR TANGGAL_MULAI_BERLAKU > DATE '2027-12-31' OR TANGGAL_AKHIR_BERLAKU < DATE '2000-01-01' OR TANGGAL_AKHIR_BERLAKU > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI_BERLAKU, TANGGAL_AKHIR_BERLAKU.' AS NOTE
    UNION ALL
    SELECT 1690 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Effective end before start' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows whose end date is earlier than the start date.' AS NOTE
    UNION ALL
    SELECT 1700 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI WHERE TANGGAL_PENGISIAN < DATE '2000-01-01' OR TANGGAL_PENGISIAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_PENGISIAN.' AS NOTE
    UNION ALL
    SELECT 1710 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE JUMLAH_RESPONDEN < 0 OR TOTAL_RESPONDEN_PERTANYAAN < 0 OR PERSENTASE_JAWABAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_RESPONDEN, TOTAL_RESPONDEN_PERTANYAAN, PERSENTASE_JAWABAN.' AS NOTE
    UNION ALL
    SELECT 1720 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE TANGGAL_AGREGASI < DATE '2000-01-01' OR TANGGAL_AGREGASI > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_AGREGASI.' AS NOTE
    UNION ALL
    SELECT 1730 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN WHERE TAHUN_RENCANA < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in TAHUN_RENCANA.' AS NOTE
    UNION ALL
    SELECT 1740 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN WHERE TANGGAL_PENGESAHAN < DATE '2000-01-01' OR TANGGAL_PENGESAHAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_PENGESAHAN.' AS NOTE
    UNION ALL
    SELECT 1750 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN WHERE TANGGAL_RENCANA < DATE '2000-01-01' OR TANGGAL_RENCANA > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_RENCANA.' AS NOTE
    UNION ALL
    SELECT 1760 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN WHERE JUMLAH_ANGGARAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_ANGGARAN.' AS NOTE
    UNION ALL
    SELECT 1770 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN WHERE TANGGAL_PERSETUJUAN < DATE '2000-01-01' OR TANGGAL_PERSETUJUAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_PERSETUJUAN.' AS NOTE
    UNION ALL
    SELECT 1780 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN WHERE JUMLAH_PENGELUARAN < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_PENGELUARAN.' AS NOTE
    UNION ALL
    SELECT 1790 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN WHERE TANGGAL_PENGELUARAN < DATE '2000-01-01' OR TANGGAL_PENGELUARAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_PENGELUARAN.' AS NOTE
    UNION ALL
    SELECT 1800 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN WHERE TARGET_PESERTA < 0 OR JUMLAH_PESERTA_AKTUAL < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in TARGET_PESERTA, JUMLAH_PESERTA_AKTUAL.' AS NOTE
    UNION ALL
    SELECT 1810 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN WHERE TANGGAL_MULAI < DATE '2000-01-01' OR TANGGAL_MULAI > DATE '2027-12-31' OR TANGGAL_SELESAI < DATE '2000-01-01' OR TANGGAL_SELESAI > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_MULAI, TANGGAL_SELESAI.' AS NOTE
    UNION ALL
    SELECT 1820 AS SORT_ORDER, 'NUMBERS' AS CHECK_GROUP, 'Negative numeric value' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE JUMLAH_PESERTA < 0 OR REALISASI_BIAYA < 0) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Rows with a negative value in JUMLAH_PESERTA, REALISASI_BIAYA.' AS NOTE
    UNION ALL
    SELECT 1830 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Date outside 2000-2027' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE TANGGAL_LAPORAN < DATE '2000-01-01' OR TANGGAL_LAPORAN > DATE '2027-12-31') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Implausible dates in TANGGAL_LAPORAN.' AS NOTE
    UNION ALL
    SELECT 1840 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Attendance for a Mass that was not held' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA x JOIN DATA_OPERASIONAL.KEJADIAN_MISA k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE k.STATUS_PELAKSANAAN <> 'Terlaksana') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Attendance may only exist for occurrences with status Terlaksana.' AS NOTE
    UNION ALL
    SELECT 1850 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Offertory for a Mass that was not held' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE x JOIN DATA_OPERASIONAL.KEJADIAN_MISA k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE k.STATUS_PELAKSANAAN <> 'Terlaksana') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Offertory may only exist for occurrences with status Terlaksana.' AS NOTE
    UNION ALL
    SELECT 1860 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Held Mass without attendance' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA k WHERE k.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.KEHADIRAN_MISA x WHERE x.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Every held Mass needs one attendance record.' AS NOTE
    UNION ALL
    SELECT 1870 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Held Mass without offertory' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA k WHERE k.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE x WHERE x.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Every held Mass needs at least one offertory record.' AS NOTE
    UNION ALL
    SELECT 1880 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Actual times inconsistent with status' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE (STATUS_PELAKSANAAN = 'Terlaksana' AND (WAKTU_MULAI_AKTUAL IS NULL OR WAKTU_SELESAI_AKTUAL IS NULL OR WAKTU_SELESAI_AKTUAL <= WAKTU_MULAI_AKTUAL)) OR (STATUS_PELAKSANAAN <> 'Terlaksana' AND (WAKTU_MULAI_AKTUAL IS NOT NULL OR WAKTU_SELESAI_AKTUAL IS NOT NULL))) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Actual times exist only for held Masses and the end must be after the start.' AS NOTE
    UNION ALL
    SELECT 1890 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Occurrence weekday differs from schedule' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA k JOIN MASTER_DATA.JADWAL_MISA j ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA WHERE MOD(DATEDIFF('day', DATE '1900-01-01', k.TANGGAL_MISA), 7) <> CASE j.HARI WHEN 'Senin' THEN 0 WHEN 'Selasa' THEN 1 WHEN 'Rabu' THEN 2 WHEN 'Kamis' THEN 3 WHEN 'Jumat' THEN 4 WHEN 'Sabtu' THEN 5 WHEN 'Minggu' THEN 6 END) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'The date must fall on the weekday of its schedule rule (1900-01-01 was a Monday).' AS NOTE
    UNION ALL
    SELECT 1900 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Occurrence outside schedule validity' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA k JOIN MASTER_DATA.JADWAL_MISA j ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA WHERE k.TANGGAL_MISA < j.TANGGAL_MULAI_BERLAKU OR (j.TANGGAL_AKHIR_BERLAKU IS NOT NULL AND k.TANGGAL_MISA > j.TANGGAL_AKHIR_BERLAKU)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A Mass may only follow a schedule rule that was valid on that date.' AS NOTE
    UNION ALL
    SELECT 1910 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Status inconsistent with the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE (STATUS_PELAKSANAAN = 'Terjadwal' AND TANGGAL_MISA <= DATE '2026-09-30') OR (STATUS_PELAKSANAAN <> 'Terjadwal' AND TANGGAL_MISA > DATE '2026-09-30')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Terjadwal only after 2026-09-30 (the demo snapshot date), otherwise Terlaksana or Dibatalkan.' AS NOTE
    UNION ALL
    SELECT 1920 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'No reporting period for a Mass date' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA k WHERE NOT EXISTS (SELECT 1 FROM MASTER_DATA.REFERENSI_PERIODE_PELAPORAN p WHERE k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'The monthly views join Masses to the reporting calendar.' AS NOTE
    UNION ALL
    SELECT 1930 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Counted amount inconsistent with reconciliation status' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE (STATUS_REKONSILIASI = 'Belum Dihitung' AND JUMLAH_HASIL_PENGHITUNGAN IS NOT NULL) OR (STATUS_REKONSILIASI <> 'Belum Dihitung' AND JUMLAH_HASIL_PENGHITUNGAN IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'The counted amount is empty exactly when the status is Belum Dihitung.' AS NOTE
    UNION ALL
    SELECT 1940 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Sudah Cocok but recorded and counted differ' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE STATUS_REKONSILIASI = 'Sudah Cocok' AND JUMLAH_PENERIMAAN <> JUMLAH_HASIL_PENGHITUNGAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Matched records must have equal recorded and counted amounts.' AS NOTE
    UNION ALL
    SELECT 1950 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Selisih status but amounts are equal' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE STATUS_REKONSILIASI IN ('Selisih Disetujui', 'Selisih Sedang Ditelusuri') AND JUMLAH_PENERIMAAN = JUMLAH_HASIL_PENGHITUNGAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A discrepancy status needs an actual discrepancy.' AS NOTE
    UNION ALL
    SELECT 1960 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Offertory booked before the Mass date' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE x JOIN DATA_OPERASIONAL.KEJADIAN_MISA k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE x.TANGGAL_PENCATATAN < k.TANGGAL_MISA) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'The booking date cannot precede the Mass.' AS NOTE
    UNION ALL
    SELECT 1970 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Offertory with open reconciliation' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE STATUS_REKONSILIASI IN ('Selisih Sedang Ditelusuri', 'Belum Dihitung')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: records still being counted or investigated.' AS NOTE
    UNION ALL
    SELECT 1980 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Attendance waiting for validation or recheck' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE STATUS_VALIDASI <> 'Sudah Divalidasi') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: attendance not yet validated.' AS NOTE
    UNION ALL
    SELECT 1990 AS SORT_ORDER, 'MASS' AS CHECK_GROUP, 'Cancelled Mass occurrences' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEJADIAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEJADIAN_MISA WHERE STATUS_PELAKSANAAN = 'Dibatalkan') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario.' AS NOTE
    UNION ALL
    SELECT 2000 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Expenditure after the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN WHERE TANGGAL_PENGELUARAN > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Spending cannot be dated after the snapshot date.' AS NOTE
    UNION ALL
    SELECT 2010 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Offertory booked after the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENERIMAAN_KOLEKTE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENERIMAAN_KOLEKTE WHERE TANGGAL_PENCATATAN > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Bookings cannot be in the future.' AS NOTE
    UNION ALL
    SELECT 2020 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Attendance recorded after the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEHADIRAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEHADIRAN_MISA WHERE CAST(WAKTU_PENCATATAN AS DATE) > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Records cannot be in the future.' AS NOTE
    UNION ALL
    SELECT 2030 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Birth year implausible or registration before birth' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT WHERE TAHUN_LAHIR < 1900 OR TAHUN_LAHIR > 2026 OR EXTRACT(YEAR FROM TANGGAL_TERDAFTAR) < TAHUN_LAHIR) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Birth years must be plausible.' AS NOTE
    UNION ALL
    SELECT 2040 AS SORT_ORDER, 'DATES' AS CHECK_GROUP, 'Assignment dated after the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA WHERE TANGGAL_MULAI_BERLAKU > DATE '2026-09-30' OR TANGGAL_AKHIR_BERLAKU > DATE '2026-09-30') + (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN WHERE TANGGAL_MULAI_BERLAKU > DATE '2026-09-30' OR TANGGAL_AKHIR_BERLAKU > DATE '2026-09-30')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Household and community assignments in the past only (both assignment tables).' AS NOTE
    UNION ALL
    SELECT 2050 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Person without a household assignment' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT u WHERE NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA x WHERE x.ID_UMAT = u.ID_UMAT)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Every person must belong to at least one household over time.' AS NOTE
    UNION ALL
    SELECT 2060 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Household without a community assignment' AS CHECK_NAME,
           'DATA_OPERASIONAL.KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA f WHERE NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN x WHERE x.ID_KELUARGA = f.ID_KELUARGA)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Every household must belong to a community over time.' AS NOTE
    UNION ALL
    SELECT 2070 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Overlapping household assignments of one person' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_KELUARGA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA a JOIN DATA_OPERASIONAL.PENUGASAN_KELUARGA b ON a.ID_UMAT = b.ID_UMAT AND a.ID_PENUGASAN_KELUARGA < b.ID_PENUGASAN_KELUARGA AND a.TANGGAL_MULAI_BERLAKU <= COALESCE(b.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31') AND b.TANGGAL_MULAI_BERLAKU <= COALESCE(a.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A person can be in only one household at a time.' AS NOTE
    UNION ALL
    SELECT 2080 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Overlapping community assignments of one household' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN a JOIN DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN b ON a.ID_KELUARGA = b.ID_KELUARGA AND a.ID_PENUGASAN_LINGKUNGAN < b.ID_PENUGASAN_LINGKUNGAN AND a.TANGGAL_MULAI_BERLAKU <= COALESCE(b.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31') AND b.TANGGAL_MULAI_BERLAKU <= COALESCE(a.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A household can be in only one community at a time.' AS NOTE
    UNION ALL
    SELECT 2090 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Active member without a current household' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT u WHERE u.STATUS_KEANGGOTAAN = 'Aktif' AND NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.PENUGASAN_KELUARGA x WHERE x.ID_UMAT = u.ID_UMAT AND x.TANGGAL_AKHIR_BERLAKU IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Active members need an open household assignment.' AS NOTE
    UNION ALL
    SELECT 2100 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Personal data not classified Terbatas or stricter' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT, DATA_OPERASIONAL.KELUARGA' AS OBJECT_NAME,
           (SELECT (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT x JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA k ON k.ID_KLASIFIKASI_DATA = x.ID_KLASIFIKASI_DATA WHERE k.URUTAN_TINGKAT < 3) + (SELECT COUNT(*) FROM DATA_OPERASIONAL.KELUARGA x JOIN MASTER_DATA.REFERENSI_KLASIFIKASI_DATA k ON k.ID_KLASIFIKASI_DATA = x.ID_KLASIFIKASI_DATA WHERE k.URUTAN_TINGKAT < 3)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Identifiable personal data must be Terbatas or Sangat Terbatas.' AS NOTE
    UNION ALL
    SELECT 2110 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Minors without the strictest classification' AS CHECK_NAME,
           'DATA_OPERASIONAL.UMAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.UMAT WHERE 2026 - TAHUN_LAHIR < 17 AND ID_KLASIFIKASI_DATA <> 'KLS-04') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Persons under 17 must be Sangat Terbatas (KLS-04).' AS NOTE
    UNION ALL
    SELECT 2120 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Personal-data columns exposed in ANALISIS' AS CHECK_NAME,
           'ANALISIS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE UPPER(TABLE_SCHEMA) = 'ANALISIS' AND UPPER(COLUMN_NAME) IN ('NAMA_FIKTIF', 'NAMA_KELUARGA_FIKTIF', 'ID_UMAT', 'ID_KELUARGA', 'TAHUN_LAHIR', 'ID_RESPONDEN', 'ID_PENUGASAN_KELUARGA')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Summary views must never expose names or person and household identifiers.' AS NOTE
    UNION ALL
    SELECT 2130 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Geometry not marked synthetic' AS CHECK_NAME,
           'MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN WHERE BERSIFAT_SINTETIS = FALSE) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'All demo geometry must be labelled synthetic.' AS NOTE
    UNION ALL
    SELECT 2140 AS SORT_ORDER, 'GOVERNANCE' AS CHECK_GROUP, 'Active community without illustrative geometry' AS CHECK_NAME,
           'MASTER_DATA.MASTER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.MASTER_LINGKUNGAN l WHERE l.STATUS_AKTIF = TRUE AND NOT EXISTS (SELECT 1 FROM MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN g WHERE g.ID_LINGKUNGAN = l.ID_LINGKUNGAN)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_WARN' AS RULE_TYPE,
           'Needed only for map demos.' AS NOTE
    UNION ALL
    SELECT 2150 AS SORT_ORDER, 'PARISHIONERS' AS CHECK_GROUP, 'Households with a community history' AS CHECK_NAME,
           'DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_KELUARGA FROM DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN GROUP BY ID_KELUARGA HAVING COUNT(*) > 1) h) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: merged or relocated communities.' AS NOTE
    UNION ALL
    SELECT 2160 AS SORT_ORDER, 'DONATIONS' AS CHECK_GROUP, 'Period or booking date inconsistent' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE PERIODE_SELESAI < PERIODE_MULAI OR TANGGAL_PENCATATAN < PERIODE_SELESAI OR TANGGAL_PENCATATAN > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Booking happens after the period ends and not after the snapshot date.' AS NOTE
    UNION ALL
    SELECT 2170 AS SORT_ORDER, 'DONATIONS' AS CHECK_GROUP, 'Participating households exceed households in the region' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS s JOIN (SELECT s2.ID_SUMBANGAN, COUNT(p.ID_KELUARGA) AS JUMLAH_KELUARGA FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS s2 LEFT JOIN MASTER_DATA.MASTER_LINGKUNGAN l ON l.ID_WILAYAH = s2.ID_WILAYAH LEFT JOIN DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN p ON p.ID_LINGKUNGAN = l.ID_LINGKUNGAN AND p.TANGGAL_MULAI_BERLAKU <= s2.PERIODE_SELESAI AND (p.TANGGAL_AKHIR_BERLAKU IS NULL OR p.TANGGAL_AKHIR_BERLAKU >= s2.PERIODE_SELESAI) GROUP BY s2.ID_SUMBANGAN) h ON h.ID_SUMBANGAN = s.ID_SUMBANGAN WHERE s.JUMLAH_KELUARGA_PESERTA > h.JUMLAH_KELUARGA) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_WARN' AS RULE_TYPE,
           'Compares participants with households assigned to the region on the last day of the period.' AS NOTE
    UNION ALL
    SELECT 2180 AS SORT_ORDER, 'DONATIONS' AS CHECK_GROUP, 'Donation records waiting for validation' AS CHECK_NAME,
           'DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS WHERE STATUS_VALIDASI <> 'Sudah Divalidasi') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario.' AS NOTE
    UNION ALL
    SELECT 2190 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Event section differs from its plan' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN e JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON p.ID_RENCANA = e.ID_RENCANA JOIN DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE h.ID_SEKSI <> e.ID_SEKSI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'ID_SEKSI is repeated on the event on purpose, so it must agree with the plan.' AS NOTE
    UNION ALL
    SELECT 2200 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Event status differs from its plan status' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN e JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON p.ID_RENCANA = e.ID_RENCANA WHERE p.STATUS_PELAKSANAAN <> e.STATUS_KEGIATAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Plan and event must tell the same story.' AS NOTE
    UNION ALL
    SELECT 2210 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Completed plan without an event' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN p WHERE p.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.KEGIATAN e WHERE e.ID_RENCANA = p.ID_RENCANA)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A plan marked Terlaksana needs the event that carried it out.' AS NOTE
    UNION ALL
    SELECT 2220 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Event dates or participants inconsistent' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN WHERE TANGGAL_SELESAI < TANGGAL_MULAI OR (STATUS_KEGIATAN = 'Terlaksana' AND (JUMLAH_PESERTA_AKTUAL IS NULL OR TANGGAL_SELESAI > DATE '2026-09-30')) OR (STATUS_KEGIATAN <> 'Terlaksana' AND JUMLAH_PESERTA_AKTUAL IS NOT NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Actual participants exist exactly for events that were held, and held events are in the past.' AS NOTE
    UNION ALL
    SELECT 2230 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Plan date outside the plan year' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN p JOIN DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE EXTRACT(YEAR FROM p.TANGGAL_RENCANA) <> h.TAHUN_RENCANA) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Planned dates must fall in the year of the annual plan.' AS NOTE
    UNION ALL
    SELECT 2240 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Expenditure outside the plan year' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN x JOIN DATA_OPERASIONAL.ALOKASI_ANGGARAN a ON a.ID_ALOKASI = x.ID_ALOKASI JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON p.ID_RENCANA = a.ID_RENCANA JOIN DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE EXTRACT(YEAR FROM x.TANGGAL_PENGELUARAN) <> h.TAHUN_RENCANA) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Spending must be dated in the plan year.' AS NOTE
    UNION ALL
    SELECT 2250 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Expenditure on a plan that is Direncanakan or Dibatalkan' AS CHECK_NAME,
           'DATA_OPERASIONAL.REALISASI_PENGELUARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN x JOIN DATA_OPERASIONAL.ALOKASI_ANGGARAN a ON a.ID_ALOKASI = x.ID_ALOKASI JOIN DATA_OPERASIONAL.RENCANA_KEGIATAN p ON p.ID_RENCANA = a.ID_RENCANA WHERE p.STATUS_PELAKSANAAN IN ('Direncanakan', 'Dibatalkan')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_WARN' AS RULE_TYPE,
           'Possible but unusual: spending before a plan starts or after it was cancelled.' AS NOTE
    UNION ALL
    SELECT 2260 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Allocations without any expenditure' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN a WHERE NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN x WHERE x.ID_ALOKASI = a.ID_ALOKASI)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: budget not yet used.' AS NOTE
    UNION ALL
    SELECT 2270 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Allocations partly used' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT a.ID_ALOKASI, a.JUMLAH_ANGGARAN, COALESCE(SUM(x.JUMLAH_PENGELUARAN), 0) AS TERPAKAI FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN a LEFT JOIN DATA_OPERASIONAL.REALISASI_PENGELUARAN x ON x.ID_ALOKASI = a.ID_ALOKASI GROUP BY a.ID_ALOKASI, a.JUMLAH_ANGGARAN) t WHERE t.TERPAKAI BETWEEN 1 AND t.JUMLAH_ANGGARAN - 1) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: spending below budget.' AS NOTE
    UNION ALL
    SELECT 2280 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Allocations spent above budget' AS CHECK_NAME,
           'DATA_OPERASIONAL.ALOKASI_ANGGARAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT a.ID_ALOKASI, a.JUMLAH_ANGGARAN, COALESCE(SUM(x.JUMLAH_PENGELUARAN), 0) AS TERPAKAI FROM DATA_OPERASIONAL.ALOKASI_ANGGARAN a LEFT JOIN DATA_OPERASIONAL.REALISASI_PENGELUARAN x ON x.ID_ALOKASI = a.ID_ALOKASI GROUP BY a.ID_ALOKASI, a.JUMLAH_ANGGARAN) t WHERE t.TERPAKAI > t.JUMLAH_ANGGARAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: overspending to be explained.' AS NOTE
    UNION ALL
    SELECT 2290 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Report for an event that was not held' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN r JOIN DATA_OPERASIONAL.KEGIATAN e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE e.STATUS_KEGIATAN <> 'Terlaksana') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Only events that took place can be reported.' AS NOTE
    UNION ALL
    SELECT 2300 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Report date before the event ended or after the as-of date' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN r JOIN DATA_OPERASIONAL.KEGIATAN e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE r.TANGGAL_LAPORAN < e.TANGGAL_SELESAI OR r.TANGGAL_LAPORAN > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A report follows the event.' AS NOTE
    UNION ALL
    SELECT 2310 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Final report with empty required fields' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE STATUS_LAPORAN = 'Final' AND (RINGKASAN_PELAKSANAAN IS NULL OR JUMLAH_PESERTA IS NULL OR REALISASI_BIAYA IS NULL OR EVALUASI_LOGISTIK IS NULL OR HASIL_KEGIATAN IS NULL OR REKOMENDASI_TINDAK_LANJUT IS NULL)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A final report must be complete.' AS NOTE
    UNION ALL
    SELECT 2320 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Report participants differ from the event' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN r JOIN DATA_OPERASIONAL.KEGIATAN e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE r.JUMLAH_PESERTA IS NOT NULL AND r.JUMLAH_PESERTA <> e.JUMLAH_PESERTA_AKTUAL) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_WARN' AS RULE_TYPE,
           'Expected: 1 (the report with status Perlu Revisi is deliberately inconsistent).' AS NOTE
    UNION ALL
    SELECT 2330 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Report cost differs from recorded expenditure' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN r JOIN DATA_OPERASIONAL.KEGIATAN e ON e.ID_KEGIATAN = r.ID_KEGIATAN LEFT JOIN (SELECT a.ID_RENCANA, SUM(x.JUMLAH_PENGELUARAN) AS TOTAL_PENGELUARAN FROM DATA_OPERASIONAL.REALISASI_PENGELUARAN x JOIN DATA_OPERASIONAL.ALOKASI_ANGGARAN a ON a.ID_ALOKASI = x.ID_ALOKASI GROUP BY a.ID_RENCANA) s ON s.ID_RENCANA = e.ID_RENCANA WHERE r.REALISASI_BIAYA IS NOT NULL AND e.ID_RENCANA IS NOT NULL AND r.REALISASI_BIAYA <> COALESCE(s.TOTAL_PENGELUARAN, 0)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_WARN' AS RULE_TYPE,
           'Compares the cost in the report with the sum of expenditure lines of the planned activity.' AS NOTE
    UNION ALL
    SELECT 2340 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Completed events without a report' AS CHECK_NAME,
           'DATA_OPERASIONAL.KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.KEGIATAN e WHERE e.STATUS_KEGIATAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN r WHERE r.ID_KEGIATAN = e.ID_KEGIATAN)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: reports not yet submitted.' AS NOTE
    UNION ALL
    SELECT 2350 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Draft or revision reports' AS CHECK_NAME,
           'DATA_OPERASIONAL.LAPORAN_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.LAPORAN_KEGIATAN WHERE STATUS_LAPORAN <> 'Final') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: incomplete reports.' AS NOTE
    UNION ALL
    SELECT 2360 AS SORT_ORDER, 'PLANNING' AS CHECK_GROUP, 'Postponed or cancelled plans' AS CHECK_NAME,
           'DATA_OPERASIONAL.RENCANA_KEGIATAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RENCANA_KEGIATAN WHERE STATUS_PELAKSANAAN IN ('Ditunda', 'Dibatalkan')) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario.' AS NOTE
    UNION ALL
    SELECT 2370 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Answer option does not belong to the question' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI j JOIN MASTER_DATA.OPSI_JAWABAN_SURVEI o ON o.ID_OPSI = j.ID_OPSI WHERE o.ID_PERTANYAAN <> j.ID_PERTANYAAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'The chosen option must be one of the question options.' AS NOTE
    UNION ALL
    SELECT 2380 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Question and respondent belong to different surveys' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.JAWABAN_SURVEI j JOIN MASTER_DATA.PERTANYAAN_SURVEI q ON q.ID_PERTANYAAN = j.ID_PERTANYAAN JOIN DATA_OPERASIONAL.RESPONDEN_SURVEI r ON r.ID_RESPONDEN = j.ID_RESPONDEN WHERE q.ID_SURVEI <> r.ID_SURVEI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'A respondent only answers questions of the survey they filled in.' AS NOTE
    UNION ALL
    SELECT 2390 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Aggregate count differs from the answers' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT h LEFT JOIN (SELECT ID_OPSI, COUNT(*) AS N FROM DATA_OPERASIONAL.JAWABAN_SURVEI GROUP BY ID_OPSI) c ON c.ID_OPSI = h.ID_OPSI WHERE h.JUMLAH_RESPONDEN <> COALESCE(c.N, 0)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Recomputes every option count from the raw answers.' AS NOTE
    UNION ALL
    SELECT 2400 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Aggregate total differs from the answers' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT h LEFT JOIN (SELECT ID_PERTANYAAN, COUNT(*) AS N FROM DATA_OPERASIONAL.JAWABAN_SURVEI GROUP BY ID_PERTANYAAN) c ON c.ID_PERTANYAAN = h.ID_PERTANYAAN WHERE h.TOTAL_RESPONDEN_PERTANYAAN <> COALESCE(c.N, 0)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Recomputes the number of respondents per question.' AS NOTE
    UNION ALL
    SELECT 2410 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Percentage differs from count divided by total' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT WHERE (TOTAL_RESPONDEN_PERTANYAAN = 0 AND PERSENTASE_JAWABAN <> 0) OR (TOTAL_RESPONDEN_PERTANYAAN > 0 AND ABS(PERSENTASE_JAWABAN - 100.0 * JUMLAH_RESPONDEN / TOTAL_RESPONDEN_PERTANYAAN) > 0.01)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Tolerance 0.01 percentage point for rounding.' AS NOTE
    UNION ALL
    SELECT 2420 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Option counts do not add up to the question total' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT GROUP BY ID_PERTANYAAN HAVING SUM(JUMLAH_RESPONDEN) <> MAX(TOTAL_RESPONDEN_PERTANYAAN)) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Single answers: option counts must sum to the number of respondents.' AS NOTE
    UNION ALL
    SELECT 2430 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Percentages do not add up to 100' AS CHECK_NAME,
           'DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT GROUP BY ID_PERTANYAAN HAVING MAX(TOTAL_RESPONDEN_PERTANYAAN) > 0 AND ABS(SUM(PERSENTASE_JAWABAN) - 100) > 0.1) d) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Tolerance 0.1 percentage point for rounding.' AS NOTE
    UNION ALL
    SELECT 2440 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Answered question without aggregate rows' AS CHECK_NAME,
           'DATA_OPERASIONAL.JAWABAN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(DISTINCT j.ID_PERTANYAAN) FROM DATA_OPERASIONAL.JAWABAN_SURVEI j WHERE NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT h WHERE h.ID_PERTANYAAN = j.ID_PERTANYAAN)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Every answered question must be summarised.' AS NOTE
    UNION ALL
    SELECT 2450 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Respondent filled outside the survey window' AS CHECK_NAME,
           'DATA_OPERASIONAL.RESPONDEN_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM DATA_OPERASIONAL.RESPONDEN_SURVEI r JOIN MASTER_DATA.SURVEI s ON s.ID_SURVEI = r.ID_SURVEI WHERE r.TANGGAL_PENGISIAN < s.TANGGAL_MULAI OR r.TANGGAL_PENGISIAN > s.TANGGAL_SELESAI OR r.TANGGAL_PENGISIAN > DATE '2026-09-30') AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Responses fall inside the survey dates.' AS NOTE
    UNION ALL
    SELECT 2460 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Survey ends before it starts' AS CHECK_NAME,
           'MASTER_DATA.SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI WHERE TANGGAL_SELESAI < TANGGAL_MULAI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'ZERO_FAIL' AS RULE_TYPE,
           'Survey dates.' AS NOTE
    UNION ALL
    SELECT 2470 AS SORT_ORDER, 'SURVEYS' AS CHECK_GROUP, 'Surveys without responses' AS CHECK_NAME,
           'MASTER_DATA.SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM MASTER_DATA.SURVEI s WHERE NOT EXISTS (SELECT 1 FROM DATA_OPERASIONAL.RESPONDEN_SURVEI r WHERE r.ID_SURVEI = s.ID_SURVEI)) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'INFO' AS RULE_TYPE,
           'Deliberate demo scenario: a planned survey has no responses and no aggregates.' AS NOTE
    UNION ALL
    SELECT 2480 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.STRUKTUR_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.STRUKTUR_WILAYAH) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2490 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.PELAKSANAAN_MISA' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.PELAKSANAAN_MISA) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2500 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.KEHADIRAN_MISA_BULANAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.KEHADIRAN_MISA_BULANAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2510 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.KOLEKTE_MISA_BULANAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.KOLEKTE_MISA_BULANAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2520 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.TREN_KEHADIRAN_PERIODE' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.TREN_KEHADIRAN_PERIODE) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2530 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.SUMBANGAN_KHUSUS_PER_WILAYAH' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.SUMBANGAN_KHUSUS_PER_WILAYAH) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2540 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2550 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.ANGGARAN_VS_REALISASI_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.ANGGARAN_VS_REALISASI_SEKSI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2560 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.KEGIATAN_DAN_LAPORAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.KEGIATAN_DAN_LAPORAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2570 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.KELENGKAPAN_LAPORAN_PER_SEKSI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.KELENGKAPAN_LAPORAN_PER_SEKSI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2580 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.HASIL_SURVEI' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.HASIL_SURVEI) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2590 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.RINGKASAN_SKOR_LIKERT' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.RINGKASAN_SKOR_LIKERT) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
    UNION ALL
    SELECT 2600 AS SORT_ORDER, 'VIEWS' AS CHECK_GROUP, 'View returns rows' AS CHECK_NAME,
           'ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN' AS OBJECT_NAME,
           (SELECT COUNT(*) FROM ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN) AS FOUND_COUNT,
           NULL AS EXPECTED_COUNT, 'NONEMPTY' AS RULE_TYPE,
           'Fails when the view is missing, broken, or empty.' AS NOTE
),
RESULTS AS (
    SELECT
        SORT_ORDER, CHECK_GROUP, CHECK_NAME, OBJECT_NAME, FOUND_COUNT, EXPECTED_COUNT,
        CASE RULE_TYPE
            WHEN 'ROWS' THEN CASE WHEN FOUND_COUNT = 0 THEN 'FAIL' WHEN FOUND_COUNT = EXPECTED_COUNT THEN 'PASS' ELSE 'WARN' END
            WHEN 'NONEMPTY' THEN CASE WHEN FOUND_COUNT > 0 THEN 'PASS' ELSE 'FAIL' END
            WHEN 'ZERO_FAIL' THEN CASE WHEN FOUND_COUNT = 0 THEN 'PASS' ELSE 'FAIL' END
            WHEN 'ZERO_WARN' THEN CASE WHEN FOUND_COUNT = 0 THEN 'PASS' ELSE 'WARN' END
            ELSE 'INFO'
        END AS RESULT,
        NOTE
    FROM CHECKS
)
SELECT SORT_ORDER, CHECK_GROUP, CHECK_NAME, OBJECT_NAME, FOUND_COUNT, EXPECTED_COUNT, RESULT, NOTE
FROM (
    SELECT * FROM RESULTS
    UNION ALL
    SELECT 1, 'SUMMARY', 'Checks with result FAIL', 'ALL CHECKS', COUNT(*), 0,
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Must be 0. Filter RESULT = FAIL to see which checks failed.'
    FROM RESULTS WHERE RESULT = 'FAIL'
    UNION ALL
    SELECT 2, 'SUMMARY', 'Checks with result WARN', 'ALL CHECKS', COUNT(*), 1,
           CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'WARN' END,
           'The bundled demo data has exactly 1 WARN (a report whose participant count is deliberately inconsistent).'
    FROM RESULTS WHERE RESULT = 'WARN'
) ALL_ROWS
ORDER BY SORT_ORDER;
