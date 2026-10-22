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
