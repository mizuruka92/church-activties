-- =============================================================================
-- Step 7 (OPTIONAL): PDF documents on a stage, and the view that links to them
--
-- Creates : stage ANALISIS.DOKUMEN_PAROKI (an internal stage with a directory table) and the view
--           ANALISIS.BERKAS_DOKUMEN, which the dashboard reads to offer "Buka ... (PDF)" links.
-- Requires: steps 1-5 (the view reads two ANALISIS views). The PDFs themselves are not in this file:
--           they are binary files that you upload to the stage (see docs/STARTER_GUIDE.md, part 8b).
-- Safe to re-run: yes (CREATE STAGE IF NOT EXISTS keeps the files that are on the stage; CREATE OR REPLACE
--           VIEW only replaces the view).
-- Not part of the normal setup: sql/full_setup.sql does not contain it, and the dashboard works without it.
--
-- How it works
--   1. Upload the 132 report PDFs (data/documents/laporan_kegiatan/) and the 6 service guides
--      (app/public_documents/) to the root of the stage. File names are already unique and carry the
--      document number (LPK-... for reports, LYN-... for guides).
--   2. Run the ALTER STAGE ... REFRESH statement at the end of this file after every upload, so that the
--      directory table lists the new files.
--   3. The view lists every document that the model knows (the file names stored in the tables), says
--      whether the file is on the stage, and, if it is, gives a pre-signed link that opens it in the browser.
--
-- Things to know before you use it
--   * A pre-signed link works for anyone who holds it until it expires (one hour here). That is fine for the
--     fictional PDFs of this demo. Do NOT use this for real reports: give people access through Snowflake
--     roles instead, and keep the default stage encryption.
--   * Pre-signed links need SNOWFLAKE_SSE encryption on the stage, and the encryption type cannot be changed
--     after the stage exists. If you created the stage with another type, drop the (empty) stage and create it again.
--   * The link is made when the view is queried. The dashboard caches the view for ten minutes, so a link
--     shown in the dashboard is at most ten minutes old and has at least fifty minutes left.
--   * Nothing in this file has been run in Snowflake; the SQL follows the Snowflake documentation for
--     GET_PRESIGNED_URL and directory tables. Report differences from your first run.
-- =============================================================================

USE DATABASE PUSAT_INFORMASI_PAROKI;

CREATE STAGE IF NOT EXISTS ANALISIS.DOKUMEN_PAROKI
    DIRECTORY = (ENABLE = TRUE)
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Berkas PDF contoh (laporan pascakegiatan dan panduan layanan). Seluruhnya fiktif. Tautan bertanda tangan ke berkas ini terbuka bagi siapa pun yang memegangnya sampai kedaluwarsa.';

CREATE OR REPLACE VIEW ANALISIS.BERKAS_DOKUMEN
    COMMENT = 'Setiap berkas PDF yang dikenal model (laporan pascakegiatan dan panduan layanan), apakah berkas itu sudah ada di stage DOKUMEN_PAROKI, dan tautan bertanda tangan untuk membukanya di peramban (berlaku satu jam). Tautan hanya ada bila berkas sudah diunggah dan stage sudah disegarkan. Data simulasi.'
AS
WITH dokumen AS (
    SELECT 'Laporan kegiatan' AS JENIS_DOKUMEN,
           ID_LAPORAN AS ID_DOKUMEN,
           NAMA_BERKAS_LAPORAN AS NAMA_BERKAS
    FROM ANALISIS.KEGIATAN_DAN_LAPORAN
    WHERE NAMA_BERKAS_LAPORAN IS NOT NULL
    UNION ALL
    SELECT 'Panduan layanan',
           ID_LAYANAN,
           NAMA_BERKAS_PANDUAN
    FROM ANALISIS.LAYANAN_PUBLIK
    WHERE NAMA_BERKAS_PANDUAN IS NOT NULL
),
tersimpan AS (
    SELECT RELATIVE_PATH
    FROM DIRECTORY(@PUSAT_INFORMASI_PAROKI.ANALISIS.DOKUMEN_PAROKI)
)
SELECT
    d.JENIS_DOKUMEN,
    d.ID_DOKUMEN,
    d.NAMA_BERKAS,
    t.RELATIVE_PATH IS NOT NULL AS ADA_DI_STAGE,
    IFF(t.RELATIVE_PATH IS NULL,
        NULL,
        GET_PRESIGNED_URL(@PUSAT_INFORMASI_PAROKI.ANALISIS.DOKUMEN_PAROKI, d.NAMA_BERKAS, 3600)) AS TAUTAN_BERKAS,
    3600 AS LAMA_BERLAKU_TAUTAN_DETIK,
    'Data simulasi (fiktif)' AS SUMBER_DATA
FROM dokumen d
LEFT JOIN tersimpan t
    ON t.RELATIVE_PATH = d.NAMA_BERKAS;

-- Run this again after every upload of PDFs, so that the directory table lists them.
ALTER STAGE ANALISIS.DOKUMEN_PAROKI REFRESH;
