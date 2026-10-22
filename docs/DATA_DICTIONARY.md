# Kamus Data Pusat Informasi Paroki

> **DATA SIMULASI.** Seluruh isi basis data demo ini fiktif: nama orang, keluarga, wilayah, lingkungan, kegiatan, angka kolekte, dan hasil survei dibuat oleh program dan tidak berasal dari paroki mana pun. Geometri peta bersifat ilustratif dan bukan batas wilayah resmi.

Dokumen ini **dihasilkan otomatis** dari komentar pada `sql/02_create_tables.sql` oleh `python scripts/generate_mock_data.py`. Jangan diedit langsung. Untuk mengubah isinya, ubah komentar tabel atau kolom pada DDL, lalu jalankan ulang perintah tersebut.

## Cara membaca kamus ini

- **Granularitas** menyatakan arti satu baris pada tabel, misalnya satu baris per Misa dan jenis kolekte.
- **Kunci utama (PK)** dan **kunci unik (UQ)** menjamin sebuah baris dapat dikenali secara unik. **Relasi (FK)** menunjukkan tabel induk yang dirujuk.
- Snowflake **tidak menegakkan** PK, UQ, dan FK pada tabel standar (hanya `NOT NULL` yang ditegakkan). Karena itu `sql/06_validate_data.sql` memeriksa identifikasi ganda dan rujukan yatim secara eksplisit.
- Nilai uang disimpan sebagai `NUMBER(18,0)` dalam rupiah, tanpa desimal, dan tidak pernah sebagai teks.
- Status dan kategori disimpan sebagai label Bahasa Indonesia yang daftarnya ada di bagian [Daftar nilai terkendali](#daftar-nilai-terkendali).
- Pada kolom `TANGGAL_AKHIR_BERLAKU`, nilai kosong berarti catatan **masih berlaku**.
- Klasifikasi data: **Publik**, **Internal**, **Terbatas**, **Sangat Terbatas**. Data umat berklasifikasi Terbatas atau lebih ketat dan tidak boleh tampil di dasbor publik.

## Sembilan domain data

| No | Domain | Tabel |
|---|---|---|
| 1 | Kolekte | `PENERIMAAN_KOLEKTE`, `REFERENSI_JENIS_KOLEKTE` |
| 2 | Kehadiran Misa | `KEHADIRAN_MISA`, `PERISTIWA_LUAR_BIASA` |
| 3 | Basis data umat (simulasi BIDUK) | `KELUARGA`, `UMAT`, `PENUGASAN_KELUARGA`, `PENUGASAN_LINGKUNGAN`, `REFERENSI_KLASIFIKASI_DATA`, `KEBIJAKAN_AKSES_DATA`, `REFERENSI_KATEGORI_INFORMASI` |
| 4 | Sumbangan kesempatan khusus per wilayah | `KAMPANYE_SUMBANGAN`, `SUMBANGAN_KESEMPATAN_KHUSUS`, `SUMBANGAN_KELUARGA`, `REFERENSI_KESEMPATAN_KHUSUS` |
| 5 | Jadwal Misa | `JADWAL_MISA`, `KEJADIAN_MISA` |
| 6 | Survei | `SURVEI`, `PERTANYAAN_SURVEI`, `OPSI_JAWABAN_SURVEI`, `RESPONDEN_SURVEI`, `JAWABAN_SURVEI`, `HASIL_SURVEI_AGREGAT` |
| 7 | Rencana tahunan, anggaran, dan realisasi | `RENCANA_KERJA_TAHUNAN`, `RENCANA_KEGIATAN`, `ALOKASI_ANGGARAN`, `REALISASI_PENGELUARAN`, `REFERENSI_KATEGORI_BIAYA` |
| 8 | Kegiatan dan laporan pascakegiatan | `KEGIATAN`, `LAPORAN_KEGIATAN` |
| 9 | Data induk wilayah dan GIS | `MASTER_WILAYAH`, `MASTER_LINGKUNGAN`, `PROFIL_EKONOMI_LINGKUNGAN`, `GEOMETRI_ILUSTRATIF_LINGKUNGAN` |
| - | Referensi bersama | `INFO_DATASET`, `MASTER_SEKSI`, `REFERENSI_DAFTAR_NILAI`, `REFERENSI_PERIODE_PELAPORAN` |

## Ringkasan tabel

| Skema | Tabel | Domain | Klasifikasi | Jumlah baris (data simulasi bawaan) |
|---|---|---|---|---:|
| MASTER_DATA | [`INFO_DATASET`](#master_datainfodataset) | Referensi bersama | Publik | 1 |
| MASTER_DATA | [`REFERENSI_KLASIFIKASI_DATA`](#master_datareferensiklasifikasidata) | Basis data umat (simulasi BIDUK) | Publik | 4 |
| MASTER_DATA | [`MASTER_SEKSI`](#master_datamasterseksi) | Referensi bersama | Publik | 9 |
| MASTER_DATA | [`REFERENSI_KATEGORI_INFORMASI`](#master_datareferensikategoriinformasi) | Basis data umat (simulasi BIDUK) | Internal | 9 |
| MASTER_DATA | [`REFERENSI_DAFTAR_NILAI`](#master_datareferensidaftarnilai) | Referensi bersama | Publik | 82 |
| MASTER_DATA | [`REFERENSI_JENIS_KOLEKTE`](#master_datareferensijeniskolekte) | Kolekte | Publik | 3 |
| MASTER_DATA | [`REFERENSI_KESEMPATAN_KHUSUS`](#master_datareferensikesempatankhusus) | Sumbangan kesempatan khusus per wilayah | Publik | 3 |
| MASTER_DATA | [`REFERENSI_KATEGORI_BIAYA`](#master_datareferensikategoribiaya) | Rencana tahunan, anggaran, dan realisasi | Internal | 7 |
| MASTER_DATA | [`REFERENSI_PERIODE_PELAPORAN`](#master_datareferensiperiodepelaporan) | Referensi bersama | Publik | 108 |
| MASTER_DATA | [`KEBIJAKAN_AKSES_DATA`](#master_datakebijakanaksesdata) | Basis data umat (simulasi BIDUK) | Internal | 20 |
| MASTER_DATA | [`MASTER_WILAYAH`](#master_datamasterwilayah) | Data induk wilayah dan GIS | Publik | 6 |
| MASTER_DATA | [`MASTER_LINGKUNGAN`](#master_datamasterlingkungan) | Data induk wilayah dan GIS | Publik | 19 |
| MASTER_DATA | [`PROFIL_EKONOMI_LINGKUNGAN`](#master_dataprofilekonomilingkungan) | Data induk wilayah dan GIS | Internal | 19 |
| MASTER_DATA | [`GEOMETRI_ILUSTRATIF_LINGKUNGAN`](#master_datageometriilustratiflingkungan) | Data induk wilayah dan GIS | Internal | 18 |
| MASTER_DATA | [`JADWAL_MISA`](#master_datajadwalmisa) | Jadwal Misa | Publik | 7 |
| MASTER_DATA | [`SURVEI`](#master_datasurvei) | Survei | Internal | 4 |
| MASTER_DATA | [`PERTANYAAN_SURVEI`](#master_datapertanyaansurvei) | Survei | Internal | 17 |
| MASTER_DATA | [`OPSI_JAWABAN_SURVEI`](#master_dataopsijawabansurvei) | Survei | Internal | 85 |
| DATA_OPERASIONAL | [`KEJADIAN_MISA`](#data_operasionalkejadianmisa) | Jadwal Misa | Internal | 1825 |
| DATA_OPERASIONAL | [`PERISTIWA_LUAR_BIASA`](#data_operasionalperistiwaluarbiasa) | Kehadiran Misa | Internal | 10 |
| DATA_OPERASIONAL | [`KEHADIRAN_MISA`](#data_operasionalkehadiranmisa) | Kehadiran Misa | Internal | 1734 |
| DATA_OPERASIONAL | [`PENERIMAAN_KOLEKTE`](#data_operasionalpenerimaankolekte) | Kolekte | Internal | 3263 |
| DATA_OPERASIONAL | [`KELUARGA`](#data_operasionalkeluarga) | Basis data umat (simulasi BIDUK) | Terbatas | 227 |
| DATA_OPERASIONAL | [`UMAT`](#data_operasionalumat) | Basis data umat (simulasi BIDUK) | Terbatas (anak di bawah 17 tahun: Sangat Terbatas) | 653 |
| DATA_OPERASIONAL | [`PENUGASAN_KELUARGA`](#data_operasionalpenugasankeluarga) | Basis data umat (simulasi BIDUK) | Terbatas | 659 |
| DATA_OPERASIONAL | [`PENUGASAN_LINGKUNGAN`](#data_operasionalpenugasanlingkungan) | Basis data umat (simulasi BIDUK) | Terbatas | 237 |
| DATA_OPERASIONAL | [`RESPONDEN_SURVEI`](#data_operasionalrespondensurvei) | Survei | Terbatas | 214 |
| DATA_OPERASIONAL | [`JAWABAN_SURVEI`](#data_operasionaljawabansurvei) | Survei | Terbatas | 1040 |
| DATA_OPERASIONAL | [`HASIL_SURVEI_AGREGAT`](#data_operasionalhasilsurveiagregat) | Survei | Internal | 76 |
| DATA_OPERASIONAL | [`RENCANA_KERJA_TAHUNAN`](#data_operasionalrencanakerjatahunan) | Rencana tahunan, anggaran, dan realisasi | Internal | 54 |
| DATA_OPERASIONAL | [`RENCANA_KEGIATAN`](#data_operasionalrencanakegiatan) | Rencana tahunan, anggaran, dan realisasi | Internal | 179 |
| DATA_OPERASIONAL | [`KAMPANYE_SUMBANGAN`](#data_operasionalkampanyesumbangan) | Sumbangan kesempatan khusus per wilayah | Internal | 14 |
| DATA_OPERASIONAL | [`SUMBANGAN_KESEMPATAN_KHUSUS`](#data_operasionalsumbangankesempatankhusus) | Sumbangan kesempatan khusus per wilayah | Internal | 78 |
| DATA_OPERASIONAL | [`SUMBANGAN_KELUARGA`](#data_operasionalsumbangankeluarga) | Sumbangan kesempatan khusus per wilayah | Sangat Terbatas | 1695 |
| DATA_OPERASIONAL | [`ALOKASI_ANGGARAN`](#data_operasionalalokasianggaran) | Rencana tahunan, anggaran, dan realisasi | Internal | 521 |
| DATA_OPERASIONAL | [`REALISASI_PENGELUARAN`](#data_operasionalrealisasipengeluaran) | Rencana tahunan, anggaran, dan realisasi | Internal | 698 |
| DATA_OPERASIONAL | [`KEGIATAN`](#data_operasionalkegiatan) | Kegiatan dan laporan pascakegiatan | Internal | 169 |
| DATA_OPERASIONAL | [`LAPORAN_KEGIATAN`](#data_operasionallaporankegiatan) | Kegiatan dan laporan pascakegiatan | Internal | 132 |
| | **Jumlah** | | | **13899** |

## Rincian tabel

### MASTER_DATA.INFO_DATASET
<a id="master_datainfodataset"></a>

Keterangan dataset demo, termasuk tanggal acuan yang dipakai view untuk membedakan tahun lengkap dari tahun berjalan.

- **Granularitas:** satu baris untuk seluruh dataset.
- **Klasifikasi data:** Publik.
- **Domain:** Referensi bersama.
- **Kunci utama (PK):** `ID_DATASET`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_DATASET` (PK) | `VARCHAR(30)` | Ya | Pengenal dataset (contoh: DS-01) |  |
| `NAMA_DATASET` | `VARCHAR(150)` | Ya | Nama dataset demo |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Penjelasan singkat isi dataset |  |
| `BERSIFAT_SIMULASI` | `BOOLEAN` | Ya | TRUE jika seluruh data adalah data simulasi (fiktif) |  |
| `TANGGAL_MULAI_RIWAYAT` | `DATE` | Ya | Tanggal pertama yang dicakup oleh data riwayat |  |
| `TANGGAL_SNAPSHOT` | `DATE` | Ya | Tanggal acuan data: catatan setelah tanggal ini adalah jadwal atau rencana, bukan kejadian |  |

### MASTER_DATA.REFERENSI_KLASIFIKASI_DATA
<a id="master_datareferensiklasifikasidata"></a>

Daftar tingkat klasifikasi data untuk tata kelola akses.

- **Granularitas:** satu baris per tingkat klasifikasi.
- **Klasifikasi data:** Publik.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_KLASIFIKASI_DATA`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KLASIFIKASI_DATA` (PK) | `VARCHAR(30)` | Ya | Pengenal tingkat klasifikasi data (contoh: KLS-01) |  |
| `NAMA_KLASIFIKASI` | `VARCHAR(50)` | Ya | Nama tingkat klasifikasi: Publik, Internal, Terbatas, Sangat Terbatas |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Arti tingkat klasifikasi dan siapa yang boleh melihatnya |  |
| `DAPAT_DITAMPILKAN_PUBLIK` | `BOOLEAN` | Ya | TRUE jika data dengan klasifikasi ini boleh tampil di dasbor publik |  |
| `URUTAN_TINGKAT` | `NUMBER(2,0)` | Ya | Urutan tingkat kerahasiaan: 1 paling terbuka, 4 paling ketat |  |

### MASTER_DATA.MASTER_SEKSI
<a id="master_datamasterseksi"></a>

Daftar seksi (bidang pelayanan) paroki.

- **Granularitas:** satu baris per seksi.
- **Klasifikasi data:** Publik.
- **Domain:** Referensi bersama.
- **Kunci utama (PK):** `ID_SEKSI`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_SEKSI` (PK) | `VARCHAR(30)` | Ya | Pengenal seksi paroki (contoh: SEK-01) |  |
| `NAMA_SEKSI` | `VARCHAR(100)` | Ya | Nama seksi atau bidang pelayanan paroki |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Ringkasan tugas pelayanan seksi |  |
| `STATUS_AKTIF` | `BOOLEAN` | Ya | TRUE jika seksi masih aktif |  |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal seksi mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal seksi berhenti berlaku, kosong jika masih berlaku |  |

### MASTER_DATA.REFERENSI_KATEGORI_INFORMASI
<a id="master_datareferensikategoriinformasi"></a>

Kategori informasi paroki beserta klasifikasi bawaan dan seksi pengelola.

- **Granularitas:** satu baris per kategori informasi.
- **Klasifikasi data:** Internal.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_KATEGORI_INFORMASI`.
- **Relasi (FK):** `ID_KLASIFIKASI_DATA` merujuk ke `MASTER_DATA.REFERENSI_KLASIFIKASI_DATA` (`ID_KLASIFIKASI_DATA`).
- **Relasi (FK):** `ID_SEKSI_PENGELOLA` merujuk ke `MASTER_DATA.MASTER_SEKSI` (`ID_SEKSI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KATEGORI_INFORMASI` (PK) | `VARCHAR(30)` | Ya | Pengenal kategori informasi (contoh: KIN-01) |  |
| `NAMA_KATEGORI` | `VARCHAR(100)` | Ya | Nama kategori informasi, sejalan dengan sembilan domain data |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Isi kategori informasi |  |
| `ID_KLASIFIKASI_DATA` | `VARCHAR(30)` | Ya | Klasifikasi bawaan untuk data dalam kategori ini | Merujuk ke `REFERENSI_KLASIFIKASI_DATA` |
| `ID_SEKSI_PENGELOLA` | `VARCHAR(30)` | Ya | Seksi yang bertanggung jawab atas data dalam kategori ini | Merujuk ke `MASTER_SEKSI` |

### MASTER_DATA.REFERENSI_DAFTAR_NILAI
<a id="master_datareferensidaftarnilai"></a>

Daftar nilai terkendali: status, jenis jawaban, peran, hari, dan sejenisnya.

- **Granularitas:** satu baris per kelompok dan nilai.
- **Klasifikasi data:** Publik.
- **Domain:** Referensi bersama.
- **Kunci utama (PK):** `KELOMPOK_NILAI, NILAI`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `KELOMPOK_NILAI` (PK) | `VARCHAR(50)` | Ya | Nama kelompok daftar nilai (contoh: STATUS_VALIDASI) |  |
| `NILAI` (PK) | `VARCHAR(100)` | Ya | Nilai yang diizinkan dalam kelompok tersebut, persis seperti tersimpan di tabel data |  |
| `URUTAN` | `NUMBER(3,0)` | Ya | Urutan tampil nilai dalam kelompok |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Arti nilai bagi pengguna bisnis |  |

### MASTER_DATA.REFERENSI_JENIS_KOLEKTE
<a id="master_datareferensijeniskolekte"></a>

Jenis kolekte yang dicatat pada setiap Misa.

- **Granularitas:** satu baris per jenis kolekte.
- **Klasifikasi data:** Publik.
- **Domain:** Kolekte.
- **Kunci utama (PK):** `ID_JENIS_KOLEKTE`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_JENIS_KOLEKTE` (PK) | `VARCHAR(30)` | Ya | Pengenal jenis kolekte (contoh: KOL-01) |  |
| `NAMA_JENIS_KOLEKTE` | `VARCHAR(100)` | Ya | Nama jenis kolekte |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Peruntukan jenis kolekte |  |

### MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS
<a id="master_datareferensikesempatankhusus"></a>

Jenis kesempatan khusus untuk gerakan sumbangan.

- **Granularitas:** satu baris per kesempatan khusus.
- **Klasifikasi data:** Publik.
- **Domain:** Sumbangan kesempatan khusus per wilayah.
- **Kunci utama (PK):** `ID_KESEMPATAN`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KESEMPATAN` (PK) | `VARCHAR(30)` | Ya | Pengenal kesempatan khusus (contoh: KSK-01) |  |
| `NAMA_KESEMPATAN` | `VARCHAR(150)` | Ya | Nama kesempatan atau gerakan sumbangan, misalnya masa Prapaskah atau Adven |  |
| `MUSIM_LITURGI` | `VARCHAR(50)` | Ya | Musim liturgi terkait: Prapaskah, Adven, atau Tidak Terkait Musim | Salah satu dari: `Prapaskah`, `Adven`, `Tidak Terkait Musim` |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Tujuan gerakan sumbangan |  |

### MASTER_DATA.REFERENSI_KATEGORI_BIAYA
<a id="master_datareferensikategoribiaya"></a>

Kategori biaya untuk alokasi anggaran dan realisasi pengeluaran.

- **Granularitas:** satu baris per kategori biaya.
- **Klasifikasi data:** Internal.
- **Domain:** Rencana tahunan, anggaran, dan realisasi.
- **Kunci utama (PK):** `ID_KATEGORI_BIAYA`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KATEGORI_BIAYA` (PK) | `VARCHAR(30)` | Ya | Pengenal kategori biaya (contoh: KBY-01) |  |
| `NAMA_KATEGORI_BIAYA` | `VARCHAR(100)` | Ya | Nama kategori biaya anggaran |  |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Contoh pengeluaran dalam kategori ini |  |

### MASTER_DATA.REFERENSI_PERIODE_PELAPORAN
<a id="master_datareferensiperiodepelaporan"></a>

Kalender periode pelaporan bulanan.

- **Granularitas:** satu baris per bulan kalender.
- **Klasifikasi data:** Publik.
- **Domain:** Referensi bersama.
- **Kunci utama (PK):** `ID_PERIODE_PELAPORAN`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PERIODE_PELAPORAN` (PK) | `VARCHAR(30)` | Ya | Pengenal periode pelaporan bulanan (contoh: PER-202604) |  |
| `TAHUN` | `NUMBER(4,0)` | Ya | Tahun kalender periode |  |
| `BULAN` | `NUMBER(2,0)` | Ya | Nomor bulan dalam tahun, 1 sampai 12 |  |
| `NAMA_PERIODE` | `VARCHAR(50)` | Ya | Nama periode untuk tampilan, misalnya April 2026 |  |
| `KUARTAL` | `NUMBER(1,0)` | Ya | Nomor kuartal kalender, 1 sampai 4 |  |
| `TANGGAL_MULAI` | `DATE` | Ya | Tanggal pertama periode |  |
| `TANGGAL_SELESAI` | `DATE` | Ya | Tanggal terakhir periode |  |

### MASTER_DATA.KEBIJAKAN_AKSES_DATA
<a id="master_datakebijakanaksesdata"></a>

Matriks contoh kebijakan akses data menurut klasifikasi dan kelompok pengguna (simulasi, bukan kebijakan resmi).

- **Granularitas:** satu baris per klasifikasi dan kelompok pengguna.
- **Klasifikasi data:** Internal.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_KLASIFIKASI_DATA, KELOMPOK_PENGGUNA`.
- **Relasi (FK):** `ID_KLASIFIKASI_DATA` merujuk ke `MASTER_DATA.REFERENSI_KLASIFIKASI_DATA` (`ID_KLASIFIKASI_DATA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KLASIFIKASI_DATA` (PK) | `VARCHAR(30)` | Ya | Klasifikasi data yang diatur | Merujuk ke `REFERENSI_KLASIFIKASI_DATA` |
| `KELOMPOK_PENGGUNA` (PK) | `VARCHAR(100)` | Ya | Kelompok pengguna yang diatur aksesnya | Salah satu dari: `Pastor Paroki dan Pengurus Harian`, `Ketua Seksi`, `Ketua Wilayah dan Lingkungan`, `Sekretariat dan Keuangan`, `Dasbor Umum` |
| `TINGKAT_AKSES` | `VARCHAR(50)` | Ya | Tingkat akses: Penuh, Agregat Saja, atau Tidak Ada | Salah satu dari: `Penuh`, `Agregat Saja`, `Tidak Ada` |
| `CATATAN` | `VARCHAR(500)` | Tidak | Penjelasan atau syarat tambahan akses |  |

### MASTER_DATA.MASTER_WILAYAH
<a id="master_datamasterwilayah"></a>

Daftar wilayah paroki (fiktif).

- **Granularitas:** satu baris per wilayah.
- **Klasifikasi data:** Publik.
- **Domain:** Data induk wilayah dan GIS.
- **Kunci utama (PK):** `ID_WILAYAH`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_WILAYAH` (PK) | `VARCHAR(30)` | Ya | Pengenal wilayah (contoh: WIL-01) |  |
| `NAMA_WILAYAH` | `VARCHAR(100)` | Ya | Nama wilayah, kelompok beberapa lingkungan |  |
| `STATUS_AKTIF` | `BOOLEAN` | Ya | TRUE jika wilayah masih aktif |  |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal wilayah mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal wilayah berhenti berlaku, kosong jika masih berlaku |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan |  |

### MASTER_DATA.MASTER_LINGKUNGAN
<a id="master_datamasterlingkungan"></a>

Daftar lingkungan (fiktif) beserta wilayah induknya.

- **Granularitas:** satu baris per lingkungan.
- **Klasifikasi data:** Publik.
- **Domain:** Data induk wilayah dan GIS.
- **Kunci utama (PK):** `ID_LINGKUNGAN`.
- **Relasi (FK):** `ID_WILAYAH` merujuk ke `MASTER_DATA.MASTER_WILAYAH` (`ID_WILAYAH`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_LINGKUNGAN` (PK) | `VARCHAR(30)` | Ya | Pengenal lingkungan (contoh: LNG-01) |  |
| `ID_WILAYAH` | `VARCHAR(30)` | Ya | Wilayah tempat lingkungan bernaung | Merujuk ke `MASTER_WILAYAH` |
| `NAMA_LINGKUNGAN` | `VARCHAR(100)` | Ya | Nama lingkungan, komunitas basis umat |  |
| `STATUS_AKTIF` | `BOOLEAN` | Ya | TRUE jika lingkungan masih aktif |  |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal lingkungan mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal lingkungan berhenti berlaku, kosong jika masih berlaku |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan, misalnya penggabungan lingkungan |  |

### MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN
<a id="master_dataprofilekonomilingkungan"></a>

Gambaran kapasitas ekonomi umum setiap lingkungan (simulasi, hanya tingkat lingkungan, tidak ada data ekonomi rumah tangga). Menjelaskan konteks, bukan menilai kemurahan hati atau iman.

- **Granularitas:** satu baris per lingkungan.
- **Klasifikasi data:** Internal.
- **Domain:** Data induk wilayah dan GIS.
- **Kunci utama (PK):** `ID_PROFIL`.
- **Kunci unik (UQ):** `ID_LINGKUNGAN`.
- **Relasi (FK):** `ID_LINGKUNGAN` merujuk ke `MASTER_DATA.MASTER_LINGKUNGAN` (`ID_LINGKUNGAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PROFIL` (PK) | `VARCHAR(30)` | Ya | Pengenal profil ekonomi (contoh: PEK-01) |  |
| `ID_LINGKUNGAN` | `VARCHAR(30)` | Ya | Lingkungan yang dinilai | Merujuk ke `MASTER_LINGKUNGAN` |
| `TAHUN_PENILAIAN` | `NUMBER(4,0)` | Ya | Tahun penilaian profil |  |
| `KATEGORI_EKONOMI` | `VARCHAR(50)` | Ya | Kapasitas ekonomi umum lingkungan: Rendah, Menengah Bawah, Menengah Atas, atau Tinggi | Salah satu dari: `Rendah`, `Menengah Bawah`, `Menengah Atas`, `Tinggi` |
| `INDEKS_KAPASITAS_EKONOMI` | `NUMBER(4,2)` | Ya | Indeks kapasitas ekonomi relatif terhadap rata-rata paroki, 1.00 berarti rata-rata |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan penilaian |  |

### MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN
<a id="master_datageometriilustratiflingkungan"></a>

Poligon ilustratif sintetis untuk lingkungan, sengaja diletakkan di koordinat 0 derajat Lintang dan 0 derajat Bujur agar tidak dikira batas wilayah nyata.

- **Granularitas:** satu baris per lingkungan aktif.
- **Klasifikasi data:** Internal.
- **Domain:** Data induk wilayah dan GIS.
- **Kunci utama (PK):** `ID_GEOMETRI`.
- **Kunci unik (UQ):** `ID_LINGKUNGAN`.
- **Relasi (FK):** `ID_LINGKUNGAN` merujuk ke `MASTER_DATA.MASTER_LINGKUNGAN` (`ID_LINGKUNGAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_GEOMETRI` (PK) | `VARCHAR(30)` | Ya | Pengenal geometri (contoh: GEO-01) |  |
| `ID_LINGKUNGAN` | `VARCHAR(30)` | Ya | Lingkungan yang digambarkan | Merujuk ke `MASTER_LINGKUNGAN` |
| `GEOJSON` | `VARCHAR(4000)` | Ya | Poligon berformat GeoJSON, bersifat ilustratif dan sintetis |  |
| `JENIS_GEOMETRI` | `VARCHAR(30)` | Ya | Jenis geometri GeoJSON, saat ini hanya Polygon |  |
| `BERSIFAT_SINTETIS` | `BOOLEAN` | Ya | TRUE jika geometri dibuat sintetis dan bukan batas resmi |  |
| `CATATAN` | `VARCHAR(500)` | Ya | Peringatan penggunaan geometri |  |

### MASTER_DATA.JADWAL_MISA
<a id="master_datajadwalmisa"></a>

Aturan jadwal Misa berulang (mingguan).

- **Granularitas:** satu baris per aturan jadwal, dengan masa berlaku.
- **Klasifikasi data:** Publik.
- **Domain:** Jadwal Misa.
- **Kunci utama (PK):** `ID_JADWAL_MISA`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_JADWAL_MISA` (PK) | `VARCHAR(30)` | Ya | Pengenal aturan jadwal Misa berulang (contoh: JDW-01) |  |
| `NAMA_MISA` | `VARCHAR(100)` | Ya | Nama sesi Misa yang dikenal umat, dipakai untuk pengelompokan laporan |  |
| `HARI` | `VARCHAR(20)` | Ya | Hari pelaksanaan mingguan: Senin sampai Minggu | Salah satu dari: `Senin`, `Selasa`, `Rabu`, `Kamis`, `Jumat`, `Sabtu`, `Minggu` |
| `WAKTU_MULAI` | `TIME` | Ya | Jam mulai menurut jadwal (bukan waktu aktual) |  |
| `WAKTU_SELESAI` | `TIME` | Ya | Jam selesai menurut jadwal (bukan waktu aktual) |  |
| `LOKASI` | `VARCHAR(150)` | Ya | Tempat pelaksanaan Misa |  |
| `BAHASA_MISA` | `VARCHAR(50)` | Ya | Bahasa pengantar Misa | Salah satu dari: `Bahasa Indonesia`, `Bahasa Inggris` |
| `STATUS_AKTIF` | `BOOLEAN` | Ya | TRUE jika aturan jadwal masih dipakai |  |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal aturan jadwal mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal aturan jadwal berhenti berlaku, kosong jika masih berlaku |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan, misalnya penggantian jadwal |  |

### MASTER_DATA.SURVEI
<a id="master_datasurvei"></a>

Definisi survei umat.

- **Granularitas:** satu baris per survei.
- **Klasifikasi data:** Internal.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_SURVEI`.
- **Relasi (FK):** `ID_SEKSI` merujuk ke `MASTER_DATA.MASTER_SEKSI` (`ID_SEKSI`).
- **Relasi (FK):** `ID_KLASIFIKASI_DATA` merujuk ke `MASTER_DATA.REFERENSI_KLASIFIKASI_DATA` (`ID_KLASIFIKASI_DATA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_SURVEI` (PK) | `VARCHAR(30)` | Ya | Pengenal survei (contoh: SRV-01) |  |
| `JUDUL_SURVEI` | `VARCHAR(200)` | Ya | Judul survei |  |
| `TUJUAN_SURVEI` | `VARCHAR(500)` | Ya | Tujuan survei dan keputusan yang ingin dibantu |  |
| `TANGGAL_MULAI` | `DATE` | Ya | Tanggal survei mulai dibuka |  |
| `TANGGAL_SELESAI` | `DATE` | Ya | Tanggal survei ditutup |  |
| `STATUS_SURVEI` | `VARCHAR(50)` | Ya | Status survei: Direncanakan, Sedang Berjalan, atau Selesai | Salah satu dari: `Direncanakan`, `Sedang Berjalan`, `Selesai` |
| `ID_SEKSI` | `VARCHAR(30)` | Ya | Seksi penanggung jawab survei | Merujuk ke `MASTER_SEKSI` |
| `ID_KLASIFIKASI_DATA` | `VARCHAR(30)` | Ya | Klasifikasi data survei | Merujuk ke `REFERENSI_KLASIFIKASI_DATA` |

### MASTER_DATA.PERTANYAAN_SURVEI
<a id="master_datapertanyaansurvei"></a>

Pertanyaan dalam survei.

- **Granularitas:** satu baris per pertanyaan.
- **Klasifikasi data:** Internal.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_PERTANYAAN`.
- **Kunci unik (UQ):** `ID_SURVEI, NOMOR_URUT`.
- **Relasi (FK):** `ID_SURVEI` merujuk ke `MASTER_DATA.SURVEI` (`ID_SURVEI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PERTANYAAN` (PK) | `VARCHAR(30)` | Ya | Pengenal pertanyaan (contoh: PRT-0101) |  |
| `ID_SURVEI` | `VARCHAR(30)` | Ya | Survei tempat pertanyaan berada | Merujuk ke `SURVEI` |
| `NOMOR_URUT` | `NUMBER(3,0)` | Ya | Nomor urut pertanyaan dalam survei |  |
| `TEKS_PERTANYAAN` | `VARCHAR(500)` | Ya | Teks pertanyaan atau pernyataan yang ditampilkan kepada responden |  |
| `JENIS_JAWABAN` | `VARCHAR(50)` | Ya | Jenis jawaban: Skala Likert atau Pilihan Tunggal | Salah satu dari: `Skala Likert`, `Pilihan Tunggal` |

### MASTER_DATA.OPSI_JAWABAN_SURVEI
<a id="master_dataopsijawabansurvei"></a>

Opsi jawaban yang tersedia untuk setiap pertanyaan.

- **Granularitas:** satu baris per opsi jawaban.
- **Klasifikasi data:** Internal.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_OPSI`.
- **Kunci unik (UQ):** `ID_PERTANYAAN, NOMOR_URUT`.
- **Relasi (FK):** `ID_PERTANYAAN` merujuk ke `MASTER_DATA.PERTANYAAN_SURVEI` (`ID_PERTANYAAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_OPSI` (PK) | `VARCHAR(30)` | Ya | Pengenal opsi jawaban (contoh: OPS-010101) |  |
| `ID_PERTANYAAN` | `VARCHAR(30)` | Ya | Pertanyaan pemilik opsi | Merujuk ke `PERTANYAAN_SURVEI` |
| `NOMOR_URUT` | `NUMBER(3,0)` | Ya | Nomor urut opsi dalam pertanyaan |  |
| `KATEGORI_JAWABAN` | `VARCHAR(150)` | Ya | Teks kategori jawaban, misalnya Setuju atau Sabtu pagi |  |
| `NILAI_SKOR` | `NUMBER(2,0)` | Tidak | Skor 1 sampai 5 untuk skala Likert, kosong untuk pilihan tunggal |  |

### DATA_OPERASIONAL.KEJADIAN_MISA
<a id="data_operasionalkejadianmisa"></a>

Kejadian Misa yang sebenarnya, hasil penerapan aturan jadwal pada tanggal tertentu.

- **Granularitas:** satu baris per Misa pada satu tanggal.
- **Klasifikasi data:** Internal.
- **Domain:** Jadwal Misa.
- **Kunci utama (PK):** `ID_KEJADIAN_MISA`.
- **Kunci unik (UQ):** `ID_JADWAL_MISA, TANGGAL_MISA`.
- **Relasi (FK):** `ID_JADWAL_MISA` merujuk ke `MASTER_DATA.JADWAL_MISA` (`ID_JADWAL_MISA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KEJADIAN_MISA` (PK) | `VARCHAR(30)` | Ya | Pengenal kejadian Misa, dipakai bersama oleh kehadiran dan kolekte (contoh: MIS-000001) |  |
| `ID_JADWAL_MISA` | `VARCHAR(30)` | Ya | Aturan jadwal yang melandasi kejadian ini | Merujuk ke `JADWAL_MISA` |
| `TANGGAL_MISA` | `DATE` | Ya | Tanggal Misa menurut kalender |  |
| `WAKTU_MULAI_AKTUAL` | `TIME` | Tidak | Jam mulai sebenarnya, kosong jika Misa belum atau tidak terlaksana |  |
| `WAKTU_SELESAI_AKTUAL` | `TIME` | Tidak | Jam selesai sebenarnya, kosong jika Misa belum atau tidak terlaksana |  |
| `STATUS_PELAKSANAAN` | `VARCHAR(50)` | Ya | Status: Terjadwal, Terlaksana, atau Dibatalkan | Salah satu dari: `Terjadwal`, `Terlaksana`, `Dibatalkan` |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan, misalnya hari raya atau alasan pembatalan |  |

### DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA
<a id="data_operasionalperistiwaluarbiasa"></a>

Catatan peristiwa luar biasa seperti hujan deras, kabut asap, atau abu vulkanik yang dapat menurunkan kehadiran dan kolekte. Besar dampak sengaja tidak disimpan agar dapat dianalisis dari data.

- **Granularitas:** satu baris per peristiwa.
- **Klasifikasi data:** Internal.
- **Domain:** Kehadiran Misa.
- **Kunci utama (PK):** `ID_PERISTIWA`.

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PERISTIWA` (PK) | `VARCHAR(30)` | Ya | Pengenal peristiwa (contoh: PRS-01) |  |
| `JENIS_PERISTIWA` | `VARCHAR(100)` | Ya | Jenis peristiwa, misalnya Hujan Deras dan Banjir, Kabut Asap, atau Abu Vulkanik | Salah satu dari: `Hujan Deras dan Banjir`, `Kabut Asap`, `Abu Vulkanik`, `Gangguan Listrik` |
| `NAMA_PERISTIWA` | `VARCHAR(200)` | Ya | Nama peristiwa untuk tampilan pada grafik riwayat |  |
| `TANGGAL_MULAI` | `DATE` | Ya | Tanggal peristiwa mulai memengaruhi paroki |  |
| `TANGGAL_SELESAI` | `DATE` | Ya | Tanggal peristiwa berakhir |  |
| `TINGKAT_GANGGUAN` | `VARCHAR(50)` | Ya | Penilaian petugas atas gangguan: Ringan, Sedang, atau Berat | Salah satu dari: `Ringan`, `Sedang`, `Berat` |
| `DESKRIPSI` | `VARCHAR(500)` | Ya | Penjelasan singkat peristiwa dan akibatnya bagi kegiatan paroki |  |

### DATA_OPERASIONAL.KEHADIRAN_MISA
<a id="data_operasionalkehadiranmisa"></a>

Total kehadiran umat pada setiap Misa yang terlaksana.

- **Granularitas:** satu baris per kejadian Misa.
- **Klasifikasi data:** Internal.
- **Domain:** Kehadiran Misa.
- **Kunci utama (PK):** `ID_KEHADIRAN`.
- **Kunci unik (UQ):** `ID_KEJADIAN_MISA`.
- **Relasi (FK):** `ID_KEJADIAN_MISA` merujuk ke `DATA_OPERASIONAL.KEJADIAN_MISA` (`ID_KEJADIAN_MISA`).
- **Relasi (FK):** `ID_PERISTIWA` merujuk ke `DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA` (`ID_PERISTIWA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KEHADIRAN` (PK) | `VARCHAR(30)` | Ya | Pengenal catatan kehadiran (contoh: KHD-000001) |  |
| `ID_KEJADIAN_MISA` | `VARCHAR(30)` | Ya | Kejadian Misa yang dihitung kehadirannya | Merujuk ke `KEJADIAN_MISA` |
| `JUMLAH_UMAT` | `NUMBER(6,0)` | Ya | Jumlah umat yang hadir menurut penghitungan |  |
| `METODE_PENGHITUNGAN` | `VARCHAR(100)` | Ya | Cara penghitungan jumlah umat | Salah satu dari: `Hitung Manual oleh Petugas`, `Penghitung Klik`, `Perkiraan Petugas Tata Tertib` |
| `STATUS_VALIDASI` | `VARCHAR(50)` | Ya | Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang | Salah satu dari: `Sudah Divalidasi`, `Menunggu Validasi`, `Perlu Dicek Ulang` |
| `WAKTU_PENCATATAN` | `TIMESTAMP_NTZ` | Ya | Waktu lokal pencatatan jumlah umat |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan, misalnya kondisi cuaca atau alasan pengecekan ulang |  |
| `ID_PERISTIWA` | `VARCHAR(30)` | Tidak | Peristiwa luar biasa yang dicatat petugas sebagai penyebab kehadiran berbeda, kosong jika tidak ada | Merujuk ke `PERISTIWA_LUAR_BIASA` |

### DATA_OPERASIONAL.PENERIMAAN_KOLEKTE
<a id="data_operasionalpenerimaankolekte"></a>

Ringkasan kolekte per Misa dan jenis kolekte, membedakan jumlah tercatat, hasil penghitungan, dan status rekonsiliasi. Bukan ukuran iman atau komitmen rohani.

- **Granularitas:** satu baris per kejadian Misa dan jenis kolekte.
- **Klasifikasi data:** Internal.
- **Domain:** Kolekte.
- **Kunci utama (PK):** `ID_KOLEKTE`.
- **Kunci unik (UQ):** `ID_KEJADIAN_MISA, ID_JENIS_KOLEKTE`.
- **Relasi (FK):** `ID_KEJADIAN_MISA` merujuk ke `DATA_OPERASIONAL.KEJADIAN_MISA` (`ID_KEJADIAN_MISA`).
- **Relasi (FK):** `ID_JENIS_KOLEKTE` merujuk ke `MASTER_DATA.REFERENSI_JENIS_KOLEKTE` (`ID_JENIS_KOLEKTE`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KOLEKTE` (PK) | `VARCHAR(30)` | Ya | Pengenal catatan kolekte (contoh: KLK-000001) |  |
| `ID_KEJADIAN_MISA` | `VARCHAR(30)` | Ya | Kejadian Misa tempat kolekte dikumpulkan | Merujuk ke `KEJADIAN_MISA` |
| `ID_JENIS_KOLEKTE` | `VARCHAR(30)` | Ya | Jenis kolekte | Merujuk ke `REFERENSI_JENIS_KOLEKTE` |
| `JUMLAH_PENERIMAAN` | `NUMBER(18,0)` | Ya | Jumlah yang dicatat petugas saat Misa, dalam rupiah |  |
| `JUMLAH_HASIL_PENGHITUNGAN` | `NUMBER(18,0)` | Tidak | Jumlah hasil penghitungan tim penghitung, dalam rupiah, kosong jika belum dihitung |  |
| `STATUS_REKONSILIASI` | `VARCHAR(50)` | Ya | Status: Sudah Cocok, Selisih Disetujui, Selisih Sedang Ditelusuri, atau Belum Dihitung | Salah satu dari: `Sudah Cocok`, `Selisih Disetujui`, `Selisih Sedang Ditelusuri`, `Belum Dihitung` |
| `TANGGAL_PENCATATAN` | `DATE` | Ya | Tanggal hasil terakhir dicatat |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan, misalnya penjelasan selisih |  |

### DATA_OPERASIONAL.KELUARGA
<a id="data_operasionalkeluarga"></a>

Rumah tangga fiktif pada simulasi basis data umat. Tidak memuat alamat atau nomor identitas.

- **Granularitas:** satu baris per keluarga.
- **Klasifikasi data:** Terbatas.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_KELUARGA`.
- **Relasi (FK):** `ID_KLASIFIKASI_DATA` merujuk ke `MASTER_DATA.REFERENSI_KLASIFIKASI_DATA` (`ID_KLASIFIKASI_DATA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KELUARGA` (PK) | `VARCHAR(30)` | Ya | Pengenal keluarga fiktif (contoh: KEL-0001) |  |
| `NAMA_KELUARGA_FIKTIF` | `VARCHAR(150)` | Ya | Nama keluarga fiktif untuk simulasi |  |
| `STATUS_KELUARGA` | `VARCHAR(50)` | Ya | Status keluarga: Aktif, Pindah Paroki, atau Tidak Aktif | Salah satu dari: `Aktif`, `Pindah Paroki`, `Tidak Aktif` |
| `TANGGAL_TERDAFTAR` | `DATE` | Ya | Tanggal keluarga pertama kali terdaftar |  |
| `ID_KLASIFIKASI_DATA` | `VARCHAR(30)` | Ya | Klasifikasi data catatan keluarga | Merujuk ke `REFERENSI_KLASIFIKASI_DATA` |

### DATA_OPERASIONAL.UMAT
<a id="data_operasionalumat"></a>

Individu umat fiktif pada simulasi basis data umat. Tanpa nomor identitas, telepon, atau alamat. Dilarang tampil di dasbor publik.

- **Granularitas:** satu baris per umat.
- **Klasifikasi data:** Terbatas (anak di bawah 17 tahun: Sangat Terbatas).
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_UMAT`.
- **Relasi (FK):** `ID_KLASIFIKASI_DATA` merujuk ke `MASTER_DATA.REFERENSI_KLASIFIKASI_DATA` (`ID_KLASIFIKASI_DATA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_UMAT` (PK) | `VARCHAR(30)` | Ya | Pengenal umat fiktif (contoh: UMT-00001) |  |
| `NAMA_FIKTIF` | `VARCHAR(150)` | Ya | Nama fiktif untuk simulasi, bukan nama orang sebenarnya |  |
| `JENIS_KELAMIN` | `VARCHAR(20)` | Ya | Laki-laki atau Perempuan | Salah satu dari: `Laki-laki`, `Perempuan` |
| `TAHUN_LAHIR` | `NUMBER(4,0)` | Ya | Tahun lahir saja, tanpa tanggal lengkap, untuk mengurangi risiko identifikasi |  |
| `STATUS_KEANGGOTAAN` | `VARCHAR(50)` | Ya | Status: Aktif, Pindah Paroki, Tidak Aktif, atau Meninggal Dunia | Salah satu dari: `Aktif`, `Pindah Paroki`, `Tidak Aktif`, `Meninggal Dunia` |
| `TANGGAL_TERDAFTAR` | `DATE` | Ya | Tanggal umat pertama kali terdaftar |  |
| `ID_KLASIFIKASI_DATA` | `VARCHAR(30)` | Ya | Klasifikasi data catatan umat, anak di bawah 17 tahun lebih ketat | Merujuk ke `REFERENSI_KLASIFIKASI_DATA` |

### DATA_OPERASIONAL.PENUGASAN_KELUARGA
<a id="data_operasionalpenugasankeluarga"></a>

Riwayat keanggotaan umat dalam keluarga dengan masa berlaku.

- **Granularitas:** satu baris per umat, keluarga, dan masa berlaku.
- **Klasifikasi data:** Terbatas.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_PENUGASAN_KELUARGA`.
- **Relasi (FK):** `ID_UMAT` merujuk ke `DATA_OPERASIONAL.UMAT` (`ID_UMAT`).
- **Relasi (FK):** `ID_KELUARGA` merujuk ke `DATA_OPERASIONAL.KELUARGA` (`ID_KELUARGA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PENUGASAN_KELUARGA` (PK) | `VARCHAR(30)` | Ya | Pengenal penugasan (contoh: PKL-00001) |  |
| `ID_UMAT` | `VARCHAR(30)` | Ya | Umat yang ditugaskan | Merujuk ke `UMAT` |
| `ID_KELUARGA` | `VARCHAR(30)` | Ya | Keluarga tempat umat berada | Merujuk ke `KELUARGA` |
| `PERAN_DALAM_KELUARGA` | `VARCHAR(50)` | Ya | Kepala Keluarga, Pasangan, Anak, atau Anggota Lain | Salah satu dari: `Kepala Keluarga`, `Pasangan`, `Anak`, `Anggota Lain` |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal penugasan mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal penugasan berakhir, kosong jika masih berlaku |  |

### DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN
<a id="data_operasionalpenugasanlingkungan"></a>

Riwayat keanggotaan keluarga dalam lingkungan dengan masa berlaku. Wilayah diperoleh dari lingkungan.

- **Granularitas:** satu baris per keluarga, lingkungan, dan masa berlaku.
- **Klasifikasi data:** Terbatas.
- **Domain:** Basis data umat (simulasi BIDUK).
- **Kunci utama (PK):** `ID_PENUGASAN_LINGKUNGAN`.
- **Relasi (FK):** `ID_KELUARGA` merujuk ke `DATA_OPERASIONAL.KELUARGA` (`ID_KELUARGA`).
- **Relasi (FK):** `ID_LINGKUNGAN` merujuk ke `MASTER_DATA.MASTER_LINGKUNGAN` (`ID_LINGKUNGAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PENUGASAN_LINGKUNGAN` (PK) | `VARCHAR(30)` | Ya | Pengenal penugasan (contoh: PLG-0001) |  |
| `ID_KELUARGA` | `VARCHAR(30)` | Ya | Keluarga yang ditugaskan ke lingkungan | Merujuk ke `KELUARGA` |
| `ID_LINGKUNGAN` | `VARCHAR(30)` | Ya | Lingkungan tempat keluarga berada | Merujuk ke `MASTER_LINGKUNGAN` |
| `TANGGAL_MULAI_BERLAKU` | `DATE` | Ya | Tanggal penugasan mulai berlaku |  |
| `TANGGAL_AKHIR_BERLAKU` | `DATE` | Tidak | Tanggal penugasan berakhir, kosong jika masih berlaku |  |

### DATA_OPERASIONAL.RESPONDEN_SURVEI
<a id="data_operasionalrespondensurvei"></a>

Responden survei sintetis yang anonim.

- **Granularitas:** satu baris per responden per survei.
- **Klasifikasi data:** Terbatas.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_RESPONDEN`.
- **Relasi (FK):** `ID_SURVEI` merujuk ke `MASTER_DATA.SURVEI` (`ID_SURVEI`).
- **Relasi (FK):** `ID_WILAYAH` merujuk ke `MASTER_DATA.MASTER_WILAYAH` (`ID_WILAYAH`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_RESPONDEN` (PK) | `VARCHAR(30)` | Ya | Kode responden anonim (contoh: RSP-0001), tidak terhubung ke ID_UMAT |  |
| `ID_SURVEI` | `VARCHAR(30)` | Ya | Survei yang diisi | Merujuk ke `SURVEI` |
| `KELOMPOK_USIA` | `VARCHAR(50)` | Ya | Kelompok usia kasar responden | Salah satu dari: `Di bawah 17 tahun`, `17-34 tahun`, `35-65 tahun`, `Di atas 65 tahun` |
| `ID_WILAYAH` | `VARCHAR(30)` | Ya | Wilayah responden (tingkat wilayah saja, bukan lingkungan) | Merujuk ke `MASTER_WILAYAH` |
| `TANGGAL_PENGISIAN` | `DATE` | Ya | Tanggal survei diisi |  |

### DATA_OPERASIONAL.JAWABAN_SURVEI
<a id="data_operasionaljawabansurvei"></a>

Jawaban sintetis responden. Pertanyaan yang dilewati tidak punya baris.

- **Granularitas:** satu baris per responden dan pertanyaan.
- **Klasifikasi data:** Terbatas.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_JAWABAN`.
- **Kunci unik (UQ):** `ID_RESPONDEN, ID_PERTANYAAN`.
- **Relasi (FK):** `ID_RESPONDEN` merujuk ke `DATA_OPERASIONAL.RESPONDEN_SURVEI` (`ID_RESPONDEN`).
- **Relasi (FK):** `ID_PERTANYAAN` merujuk ke `MASTER_DATA.PERTANYAAN_SURVEI` (`ID_PERTANYAAN`).
- **Relasi (FK):** `ID_OPSI` merujuk ke `MASTER_DATA.OPSI_JAWABAN_SURVEI` (`ID_OPSI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_JAWABAN` (PK) | `VARCHAR(30)` | Ya | Pengenal jawaban (contoh: JWB-00001) |  |
| `ID_RESPONDEN` | `VARCHAR(30)` | Ya | Responden yang menjawab | Merujuk ke `RESPONDEN_SURVEI` |
| `ID_PERTANYAAN` | `VARCHAR(30)` | Ya | Pertanyaan yang dijawab | Merujuk ke `PERTANYAAN_SURVEI` |
| `ID_OPSI` | `VARCHAR(30)` | Ya | Opsi jawaban yang dipilih | Merujuk ke `OPSI_JAWABAN_SURVEI` |

### DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT
<a id="data_operasionalhasilsurveiagregat"></a>

Hasil survei yang sudah dirangkum, aman untuk dasbor.

- **Granularitas:** satu baris per opsi jawaban pada survei yang sudah memiliki jawaban.
- **Klasifikasi data:** Internal.
- **Domain:** Survei.
- **Kunci utama (PK):** `ID_HASIL`.
- **Kunci unik (UQ):** `ID_OPSI`.
- **Relasi (FK):** `ID_SURVEI` merujuk ke `MASTER_DATA.SURVEI` (`ID_SURVEI`).
- **Relasi (FK):** `ID_PERTANYAAN` merujuk ke `MASTER_DATA.PERTANYAAN_SURVEI` (`ID_PERTANYAAN`).
- **Relasi (FK):** `ID_OPSI` merujuk ke `MASTER_DATA.OPSI_JAWABAN_SURVEI` (`ID_OPSI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_HASIL` (PK) | `VARCHAR(30)` | Ya | Pengenal hasil agregat (contoh: HSL-010101) |  |
| `ID_SURVEI` | `VARCHAR(30)` | Ya | Survei yang dirangkum | Merujuk ke `SURVEI` |
| `ID_PERTANYAAN` | `VARCHAR(30)` | Ya | Pertanyaan yang dirangkum | Merujuk ke `PERTANYAAN_SURVEI` |
| `ID_OPSI` | `VARCHAR(30)` | Ya | Opsi jawaban (kategori jawaban) yang dihitung | Merujuk ke `OPSI_JAWABAN_SURVEI` |
| `JUMLAH_RESPONDEN` | `NUMBER(6,0)` | Ya | Jumlah responden yang memilih opsi ini |  |
| `TOTAL_RESPONDEN_PERTANYAAN` | `NUMBER(6,0)` | Ya | Jumlah responden yang menjawab pertanyaan ini (penyebut persentase) |  |
| `PERSENTASE_JAWABAN` | `NUMBER(5,2)` | Ya | Persentase responden yang memilih opsi, dibulatkan dua desimal, 0 jika belum ada jawaban |  |
| `TANGGAL_AGREGASI` | `DATE` | Ya | Tanggal ringkasan dihitung |  |

### DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN
<a id="data_operasionalrencanakerjatahunan"></a>

Rencana kerja tahunan setiap seksi.

- **Granularitas:** satu baris per seksi per tahun.
- **Klasifikasi data:** Internal.
- **Domain:** Rencana tahunan, anggaran, dan realisasi.
- **Kunci utama (PK):** `ID_RENCANA_KERJA`.
- **Kunci unik (UQ):** `ID_SEKSI, TAHUN_RENCANA`.
- **Relasi (FK):** `ID_SEKSI` merujuk ke `MASTER_DATA.MASTER_SEKSI` (`ID_SEKSI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_RENCANA_KERJA` (PK) | `VARCHAR(30)` | Ya | Pengenal rencana kerja tahunan (contoh: RKT-2026-01) |  |
| `ID_SEKSI` | `VARCHAR(30)` | Ya | Seksi pemilik rencana kerja | Merujuk ke `MASTER_SEKSI` |
| `TAHUN_RENCANA` | `NUMBER(4,0)` | Ya | Tahun rencana kerja |  |
| `TUJUAN_UMUM` | `VARCHAR(500)` | Ya | Tujuan umum seksi pada tahun tersebut |  |
| `STATUS_PENGESAHAN` | `VARCHAR(50)` | Ya | Status pengesahan: Disahkan atau Dalam Revisi | Salah satu dari: `Disahkan`, `Dalam Revisi` |
| `TANGGAL_PENGESAHAN` | `DATE` | Ya | Tanggal rencana kerja disahkan |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan, misalnya alasan revisi |  |

### DATA_OPERASIONAL.RENCANA_KEGIATAN
<a id="data_operasionalrencanakegiatan"></a>

Kegiatan yang direncanakan dalam rencana kerja tahunan. Tidak semua rencana sudah terlaksana atau memiliki pengeluaran.

- **Granularitas:** satu baris per kegiatan yang direncanakan.
- **Klasifikasi data:** Internal.
- **Domain:** Rencana tahunan, anggaran, dan realisasi.
- **Kunci utama (PK):** `ID_RENCANA`.
- **Relasi (FK):** `ID_RENCANA_KERJA` merujuk ke `DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN` (`ID_RENCANA_KERJA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_RENCANA` (PK) | `VARCHAR(30)` | Ya | Pengenal rencana kegiatan (contoh: RNC-0001) |  |
| `ID_RENCANA_KERJA` | `VARCHAR(30)` | Ya | Rencana kerja tahunan induk, dari sini diperoleh seksi dan tahun | Merujuk ke `RENCANA_KERJA_TAHUNAN` |
| `NAMA_PROGRAM` | `VARCHAR(200)` | Ya | Nama program atau kegiatan yang direncanakan |  |
| `TUJUAN_PROGRAM` | `VARCHAR(500)` | Ya | Tujuan program |  |
| `TANGGAL_RENCANA` | `DATE` | Ya | Tanggal pelaksanaan menurut rencana (tanggal mulai) |  |
| `STATUS_PELAKSANAAN` | `VARCHAR(50)` | Ya | Status: Direncanakan, Terlaksana, Ditunda, atau Dibatalkan | Salah satu dari: `Direncanakan`, `Terlaksana`, `Ditunda`, `Dibatalkan` |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan, misalnya alasan penundaan atau pembatalan |  |

### DATA_OPERASIONAL.KAMPANYE_SUMBANGAN
<a id="data_operasionalkampanyesumbangan"></a>

Satu kampanye sumbangan pada satu periode, dengan kegiatan besar yang didanainya. Dasar analisis titik impas.

- **Granularitas:** satu baris per kesempatan khusus dan periode.
- **Klasifikasi data:** Internal.
- **Domain:** Sumbangan kesempatan khusus per wilayah.
- **Kunci utama (PK):** `ID_KAMPANYE`.
- **Kunci unik (UQ):** `ID_KESEMPATAN, PERIODE_MULAI`.
- **Relasi (FK):** `ID_KESEMPATAN` merujuk ke `MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS` (`ID_KESEMPATAN`).
- **Relasi (FK):** `ID_RENCANA_PENGGUNAAN` merujuk ke `DATA_OPERASIONAL.RENCANA_KEGIATAN` (`ID_RENCANA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KAMPANYE` (PK) | `VARCHAR(30)` | Ya | Pengenal kampanye sumbangan (contoh: KMP-01) |  |
| `ID_KESEMPATAN` | `VARCHAR(30)` | Ya | Kesempatan khusus yang melandasi kampanye | Merujuk ke `REFERENSI_KESEMPATAN_KHUSUS` |
| `NAMA_KAMPANYE` | `VARCHAR(200)` | Ya | Nama kampanye beserta tahunnya, misalnya Aksi Puasa Pembangunan 2026 |  |
| `PERIODE_MULAI` | `DATE` | Ya | Tanggal awal pengumpulan |  |
| `PERIODE_SELESAI` | `DATE` | Ya | Tanggal akhir pengumpulan |  |
| `TARGET_DANA` | `NUMBER(18,0)` | Ya | Target dana kampanye, dalam rupiah |  |
| `ID_RENCANA_PENGGUNAAN` | `VARCHAR(30)` | Tidak | Rencana kegiatan yang akan dibiayai dana kampanye, misalnya perayaan Paskah atau Natal, kosong jika belum ditentukan | Merujuk ke `RENCANA_KEGIATAN` |
| `STATUS_KAMPANYE` | `VARCHAR(50)` | Ya | Status kampanye: Direncanakan, Berjalan, atau Selesai | Salah satu dari: `Direncanakan`, `Berjalan`, `Selesai` |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan |  |

### DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS
<a id="data_operasionalsumbangankesempatankhusus"></a>

Ringkasan sumbangan kampanye per wilayah. Harus sama dengan jumlah sumbangan keluarga di wilayah itu. Tidak dipakai untuk memeringkat wilayah.

- **Granularitas:** satu baris per kampanye dan wilayah.
- **Klasifikasi data:** Internal.
- **Domain:** Sumbangan kesempatan khusus per wilayah.
- **Kunci utama (PK):** `ID_SUMBANGAN`.
- **Kunci unik (UQ):** `ID_KAMPANYE, ID_WILAYAH`.
- **Relasi (FK):** `ID_KAMPANYE` merujuk ke `DATA_OPERASIONAL.KAMPANYE_SUMBANGAN` (`ID_KAMPANYE`).
- **Relasi (FK):** `ID_WILAYAH` merujuk ke `MASTER_DATA.MASTER_WILAYAH` (`ID_WILAYAH`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_SUMBANGAN` (PK) | `VARCHAR(30)` | Ya | Pengenal catatan sumbangan wilayah (contoh: SMB-001) |  |
| `ID_KAMPANYE` | `VARCHAR(30)` | Ya | Kampanye yang dilaporkan, dari sini diperoleh kesempatan khusus dan periode | Merujuk ke `KAMPANYE_SUMBANGAN` |
| `ID_WILAYAH` | `VARCHAR(30)` | Ya | Wilayah pelapor sumbangan | Merujuk ke `MASTER_WILAYAH` |
| `JUMLAH_KELUARGA_PESERTA` | `NUMBER(6,0)` | Ya | Jumlah keluarga di wilayah yang ikut menyumbang |  |
| `JUMLAH_SUMBANGAN` | `NUMBER(18,0)` | Ya | Total sumbangan wilayah pada kampanye tersebut, dalam rupiah |  |
| `TANGGAL_PENCATATAN` | `DATE` | Ya | Tanggal laporan wilayah dicatat |  |
| `STATUS_VALIDASI` | `VARCHAR(50)` | Ya | Status validasi: Sudah Divalidasi, Menunggu Validasi, atau Perlu Dicek Ulang | Salah satu dari: `Sudah Divalidasi`, `Menunggu Validasi`, `Perlu Dicek Ulang` |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan |  |

### DATA_OPERASIONAL.SUMBANGAN_KELUARGA
<a id="data_operasionalsumbangankeluarga"></a>

Sumbangan setiap keluarga fiktif pada satu kampanye. Data keuangan keluarga yang teridentifikasi, hanya boleh tampil sebagai angka agregat.

- **Granularitas:** satu baris per keluarga dan kampanye.
- **Klasifikasi data:** Sangat Terbatas.
- **Domain:** Sumbangan kesempatan khusus per wilayah.
- **Kunci utama (PK):** `ID_SUMBANGAN_KELUARGA`.
- **Kunci unik (UQ):** `ID_KAMPANYE, ID_KELUARGA`.
- **Relasi (FK):** `ID_KAMPANYE` merujuk ke `DATA_OPERASIONAL.KAMPANYE_SUMBANGAN` (`ID_KAMPANYE`).
- **Relasi (FK):** `ID_KELUARGA` merujuk ke `DATA_OPERASIONAL.KELUARGA` (`ID_KELUARGA`).
- **Relasi (FK):** `ID_LINGKUNGAN` merujuk ke `MASTER_DATA.MASTER_LINGKUNGAN` (`ID_LINGKUNGAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_SUMBANGAN_KELUARGA` (PK) | `VARCHAR(30)` | Ya | Pengenal sumbangan keluarga (contoh: SKL-00001) |  |
| `ID_KAMPANYE` | `VARCHAR(30)` | Ya | Kampanye yang disumbang | Merujuk ke `KAMPANYE_SUMBANGAN` |
| `ID_KELUARGA` | `VARCHAR(30)` | Ya | Keluarga fiktif penyumbang | Merujuk ke `KELUARGA` |
| `ID_LINGKUNGAN` | `VARCHAR(30)` | Ya | Lingkungan keluarga pada tanggal sumbangan, dicatat agar riwayat pindah lingkungan tidak mengubah angka lama | Merujuk ke `MASTER_LINGKUNGAN` |
| `JUMLAH_SUMBANGAN` | `NUMBER(18,0)` | Ya | Jumlah sumbangan keluarga pada kampanye ini, dalam rupiah |  |
| `TANGGAL_SUMBANGAN` | `DATE` | Ya | Tanggal sumbangan diterima |  |

### DATA_OPERASIONAL.ALOKASI_ANGGARAN
<a id="data_operasionalalokasianggaran"></a>

Anggaran yang direncanakan, terpisah dari realisasi pengeluaran.

- **Granularitas:** satu baris per kegiatan dan kategori biaya.
- **Klasifikasi data:** Internal.
- **Domain:** Rencana tahunan, anggaran, dan realisasi.
- **Kunci utama (PK):** `ID_ALOKASI`.
- **Kunci unik (UQ):** `ID_RENCANA, ID_KATEGORI_BIAYA`.
- **Relasi (FK):** `ID_RENCANA` merujuk ke `DATA_OPERASIONAL.RENCANA_KEGIATAN` (`ID_RENCANA`).
- **Relasi (FK):** `ID_KATEGORI_BIAYA` merujuk ke `MASTER_DATA.REFERENSI_KATEGORI_BIAYA` (`ID_KATEGORI_BIAYA`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_ALOKASI` (PK) | `VARCHAR(30)` | Ya | Pengenal alokasi anggaran (contoh: ALK-0001) |  |
| `ID_RENCANA` | `VARCHAR(30)` | Ya | Kegiatan yang dianggarkan | Merujuk ke `RENCANA_KEGIATAN` |
| `ID_KATEGORI_BIAYA` | `VARCHAR(30)` | Ya | Kategori biaya yang dianggarkan | Merujuk ke `REFERENSI_KATEGORI_BIAYA` |
| `JUMLAH_ANGGARAN` | `NUMBER(18,0)` | Ya | Jumlah anggaran yang disetujui, dalam rupiah |  |
| `TANGGAL_PERSETUJUAN` | `DATE` | Ya | Tanggal anggaran disetujui |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan tambahan |  |

### DATA_OPERASIONAL.REALISASI_PENGELUARAN
<a id="data_operasionalrealisasipengeluaran"></a>

Pengeluaran sebenarnya. Satu alokasi bisa memiliki banyak pengeluaran atau belum ada sama sekali.

- **Granularitas:** satu baris per transaksi pengeluaran.
- **Klasifikasi data:** Internal.
- **Domain:** Rencana tahunan, anggaran, dan realisasi.
- **Kunci utama (PK):** `ID_PENGELUARAN`.
- **Relasi (FK):** `ID_ALOKASI` merujuk ke `DATA_OPERASIONAL.ALOKASI_ANGGARAN` (`ID_ALOKASI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_PENGELUARAN` (PK) | `VARCHAR(30)` | Ya | Pengenal pengeluaran (contoh: PGL-00001) |  |
| `ID_ALOKASI` | `VARCHAR(30)` | Ya | Alokasi anggaran yang digunakan | Merujuk ke `ALOKASI_ANGGARAN` |
| `TANGGAL_PENGELUARAN` | `DATE` | Ya | Tanggal pengeluaran terjadi |  |
| `JUMLAH_PENGELUARAN` | `NUMBER(18,0)` | Ya | Jumlah pengeluaran sebenarnya, dalam rupiah |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Uraian pengeluaran |  |

### DATA_OPERASIONAL.KEGIATAN
<a id="data_operasionalkegiatan"></a>

Kegiatan yang benar-benar terdaftar atau terlaksana. Satu rencana memiliki paling banyak satu kegiatan.

- **Granularitas:** satu baris per kegiatan.
- **Klasifikasi data:** Internal.
- **Domain:** Kegiatan dan laporan pascakegiatan.
- **Kunci utama (PK):** `ID_KEGIATAN`.
- **Kunci unik (UQ):** `ID_RENCANA`.
- **Relasi (FK):** `ID_RENCANA` merujuk ke `DATA_OPERASIONAL.RENCANA_KEGIATAN` (`ID_RENCANA`).
- **Relasi (FK):** `ID_SEKSI` merujuk ke `MASTER_DATA.MASTER_SEKSI` (`ID_SEKSI`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_KEGIATAN` (PK) | `VARCHAR(30)` | Ya | Pengenal kegiatan (contoh: KGT-0001) |  |
| `ID_RENCANA` | `VARCHAR(30)` | Tidak | Rencana kegiatan asal, kosong untuk kegiatan yang tidak direncanakan | Merujuk ke `RENCANA_KEGIATAN` |
| `NAMA_KEGIATAN` | `VARCHAR(200)` | Ya | Nama kegiatan |  |
| `ID_SEKSI` | `VARCHAR(30)` | Ya | Seksi penyelenggara | Merujuk ke `MASTER_SEKSI` |
| `TANGGAL_MULAI` | `DATE` | Ya | Tanggal mulai kegiatan |  |
| `TANGGAL_SELESAI` | `DATE` | Ya | Tanggal selesai kegiatan |  |
| `LOKASI` | `VARCHAR(150)` | Ya | Tempat kegiatan |  |
| `STATUS_KEGIATAN` | `VARCHAR(50)` | Ya | Status: Direncanakan, Terlaksana, Ditunda, atau Dibatalkan | Salah satu dari: `Direncanakan`, `Terlaksana`, `Ditunda`, `Dibatalkan` |
| `TARGET_PESERTA` | `NUMBER(6,0)` | Ya | Target jumlah peserta |  |
| `JUMLAH_PESERTA_AKTUAL` | `NUMBER(6,0)` | Tidak | Jumlah peserta sebenarnya, kosong jika kegiatan belum atau tidak terlaksana |  |
| `KETERANGAN` | `VARCHAR(500)` | Tidak | Catatan, misalnya alasan penundaan |  |

### DATA_OPERASIONAL.LAPORAN_KEGIATAN
<a id="data_operasionallaporankegiatan"></a>

Laporan pascakegiatan. Tidak semua kegiatan memiliki laporan, dan sebagian laporan belum lengkap.

- **Granularitas:** satu baris per kegiatan yang dilaporkan.
- **Klasifikasi data:** Internal.
- **Domain:** Kegiatan dan laporan pascakegiatan.
- **Kunci utama (PK):** `ID_LAPORAN`.
- **Kunci unik (UQ):** `ID_KEGIATAN`.
- **Relasi (FK):** `ID_KEGIATAN` merujuk ke `DATA_OPERASIONAL.KEGIATAN` (`ID_KEGIATAN`).

| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |
|---|---|---|---|---|
| `ID_LAPORAN` (PK) | `VARCHAR(30)` | Ya | Pengenal laporan (contoh: LPK-0001) |  |
| `ID_KEGIATAN` | `VARCHAR(30)` | Ya | Kegiatan yang dilaporkan | Merujuk ke `KEGIATAN` |
| `TANGGAL_LAPORAN` | `DATE` | Ya | Tanggal laporan dibuat atau terakhir diubah |  |
| `STATUS_LAPORAN` | `VARCHAR(50)` | Ya | Status laporan: Final, Draf, atau Perlu Revisi | Salah satu dari: `Final`, `Draf`, `Perlu Revisi` |
| `RINGKASAN_PELAKSANAAN` | `VARCHAR(2000)` | Tidak | Ringkasan pelaksanaan kegiatan |  |
| `JUMLAH_PESERTA` | `NUMBER(6,0)` | Tidak | Jumlah peserta menurut laporan, kosong jika belum diisi |  |
| `REALISASI_BIAYA` | `NUMBER(18,0)` | Tidak | Total biaya menurut laporan, dalam rupiah, kosong jika belum diisi |  |
| `EVALUASI_LOGISTIK` | `VARCHAR(2000)` | Tidak | Evaluasi perlengkapan, tempat, dan konsumsi |  |
| `HASIL_KEGIATAN` | `VARCHAR(2000)` | Tidak | Hasil atau capaian kegiatan |  |
| `REKOMENDASI_TINDAK_LANJUT` | `VARCHAR(2000)` | Tidak | Rekomendasi tindak lanjut, kosong jika belum diisi |  |

## Daftar nilai terkendali

Nilai berikut disimpan pada tabel `MASTER_DATA.REFERENSI_DAFTAR_NILAI`. Kolom pada tabel data hanya boleh memakai nilai dari kelompok yang sesuai, dan hal ini diperiksa oleh `sql/06_validate_data.sql`.

### STATUS_VALIDASI

Dipakai pada: `DATA_OPERASIONAL.KEHADIRAN_MISA.STATUS_VALIDASI`, `DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS.STATUS_VALIDASI`.

| Nilai | Arti |
|---|---|
| `Sudah Divalidasi` | Angka telah diperiksa dan disetujui petugas. |
| `Menunggu Validasi` | Angka sudah dicatat tetapi belum diperiksa. |
| `Perlu Dicek Ulang` | Angka tampak janggal dan harus diperiksa kembali. |

### STATUS_REKONSILIASI

Dipakai pada: `DATA_OPERASIONAL.PENERIMAAN_KOLEKTE.STATUS_REKONSILIASI`.

| Nilai | Arti |
|---|---|
| `Sudah Cocok` | Jumlah tercatat sama dengan hasil penghitungan. |
| `Selisih Disetujui` | Ada selisih kecil yang sudah dijelaskan dan disetujui bendahara. |
| `Selisih Sedang Ditelusuri` | Ada selisih yang masih ditelusuri bersama petugas. |
| `Belum Dihitung` | Hasil penghitungan belum tersedia. |

### METODE_PENGHITUNGAN

Dipakai pada: `DATA_OPERASIONAL.KEHADIRAN_MISA.METODE_PENGHITUNGAN`.

| Nilai | Arti |
|---|---|
| `Hitung Manual oleh Petugas` | Petugas menghitung umat satu per satu. |
| `Penghitung Klik` | Petugas memakai alat penghitung klik di pintu masuk. |
| `Perkiraan Petugas Tata Tertib` | Perkiraan petugas berdasarkan jumlah baris tempat duduk. |

### STATUS_PELAKSANAAN_MISA

Dipakai pada: `DATA_OPERASIONAL.KEJADIAN_MISA.STATUS_PELAKSANAAN`.

| Nilai | Arti |
|---|---|
| `Terjadwal` | Misa belum berlangsung. |
| `Terlaksana` | Misa sudah berlangsung. |
| `Dibatalkan` | Misa dibatalkan dan tidak berlangsung. |

### STATUS_PELAKSANAAN_RENCANA

Dipakai pada: `DATA_OPERASIONAL.RENCANA_KEGIATAN.STATUS_PELAKSANAAN`.

| Nilai | Arti |
|---|---|
| `Direncanakan` | Kegiatan belum dilaksanakan dan masih sesuai rencana. |
| `Terlaksana` | Kegiatan sudah dilaksanakan. |
| `Ditunda` | Kegiatan ditunda dan belum dilaksanakan. |
| `Dibatalkan` | Kegiatan dibatalkan dan tidak akan dilaksanakan. |

### STATUS_KEGIATAN

Dipakai pada: `DATA_OPERASIONAL.KEGIATAN.STATUS_KEGIATAN`.

| Nilai | Arti |
|---|---|
| `Direncanakan` | Kegiatan sudah terdaftar tetapi belum berlangsung. |
| `Terlaksana` | Kegiatan sudah berlangsung. |
| `Ditunda` | Kegiatan ditunda dan belum berlangsung. |
| `Dibatalkan` | Kegiatan dibatalkan. |

### STATUS_LAPORAN

Dipakai pada: `DATA_OPERASIONAL.LAPORAN_KEGIATAN.STATUS_LAPORAN`.

| Nilai | Arti |
|---|---|
| `Final` | Laporan sudah lengkap dan diserahkan. |
| `Draf` | Laporan masih disusun dan belum lengkap. |
| `Perlu Revisi` | Laporan dikembalikan untuk diperbaiki. |

### STATUS_PENGESAHAN

Dipakai pada: `DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN.STATUS_PENGESAHAN`.

| Nilai | Arti |
|---|---|
| `Disahkan` | Rencana kerja sudah disahkan pengurus paroki. |
| `Dalam Revisi` | Rencana kerja sedang direvisi. |

### STATUS_KEANGGOTAAN

Dipakai pada: `DATA_OPERASIONAL.UMAT.STATUS_KEANGGOTAAN`.

| Nilai | Arti |
|---|---|
| `Aktif` | Terdaftar dan aktif di paroki. |
| `Pindah Paroki` | Sudah pindah ke paroki lain. |
| `Tidak Aktif` | Terdaftar tetapi sudah lama tidak aktif. |
| `Meninggal Dunia` | Sudah meninggal dunia. |

### STATUS_KELUARGA

Dipakai pada: `DATA_OPERASIONAL.KELUARGA.STATUS_KELUARGA`.

| Nilai | Arti |
|---|---|
| `Aktif` | Keluarga terdaftar dan aktif di paroki. |
| `Pindah Paroki` | Seluruh keluarga sudah pindah ke paroki lain. |
| `Tidak Aktif` | Keluarga terdaftar tetapi tidak aktif. |

### STATUS_SURVEI

Dipakai pada: `MASTER_DATA.SURVEI.STATUS_SURVEI`.

| Nilai | Arti |
|---|---|
| `Direncanakan` | Survei belum dibuka. |
| `Sedang Berjalan` | Survei sedang dibuka dan menerima jawaban. |
| `Selesai` | Survei sudah ditutup. |

### JENIS_JAWABAN

Dipakai pada: `MASTER_DATA.PERTANYAAN_SURVEI.JENIS_JAWABAN`.

| Nilai | Arti |
|---|---|
| `Skala Likert` | Responden memilih tingkat kesetujuan dari Sangat Tidak Setuju sampai Sangat Setuju. |
| `Pilihan Tunggal` | Responden memilih satu dari beberapa opsi. |

### KELOMPOK_USIA

Dipakai pada: `DATA_OPERASIONAL.RESPONDEN_SURVEI.KELOMPOK_USIA`.

| Nilai | Arti |
|---|---|
| `Di bawah 17 tahun` | Responden berusia di bawah 17 tahun. |
| `17-34 tahun` | Responden berusia 17 sampai 34 tahun. |
| `35-65 tahun` | Responden berusia 35 sampai 65 tahun. |
| `Di atas 65 tahun` | Responden berusia di atas 65 tahun. |

### JENIS_KELAMIN

Dipakai pada: `DATA_OPERASIONAL.UMAT.JENIS_KELAMIN`.

| Nilai | Arti |
|---|---|
| `Laki-laki` | Jenis kelamin laki-laki. |
| `Perempuan` | Jenis kelamin perempuan. |

### PERAN_DALAM_KELUARGA

Dipakai pada: `DATA_OPERASIONAL.PENUGASAN_KELUARGA.PERAN_DALAM_KELUARGA`.

| Nilai | Arti |
|---|---|
| `Kepala Keluarga` | Penanggung jawab keluarga. |
| `Pasangan` | Suami atau istri kepala keluarga. |
| `Anak` | Anak dalam keluarga. |
| `Anggota Lain` | Anggota keluarga lain, misalnya orang tua atau saudara. |

### HARI

Dipakai pada: `MASTER_DATA.JADWAL_MISA.HARI`.

| Nilai | Arti |
|---|---|
| `Senin` | Hari Senin. |
| `Selasa` | Hari Selasa. |
| `Rabu` | Hari Rabu. |
| `Kamis` | Hari Kamis. |
| `Jumat` | Hari Jumat. |
| `Sabtu` | Hari Sabtu. |
| `Minggu` | Hari Minggu. |

### BAHASA_MISA

Dipakai pada: `MASTER_DATA.JADWAL_MISA.BAHASA_MISA`.

| Nilai | Arti |
|---|---|
| `Bahasa Indonesia` | Misa dengan bahasa pengantar Bahasa Indonesia. |
| `Bahasa Inggris` | Misa dengan bahasa pengantar Bahasa Inggris. |

### MUSIM_LITURGI

Dipakai pada: `MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS.MUSIM_LITURGI`.

| Nilai | Arti |
|---|---|
| `Prapaskah` | Masa persiapan menjelang Paskah. |
| `Adven` | Masa persiapan menjelang Natal. |
| `Tidak Terkait Musim` | Tidak terkait musim liturgi tertentu. |

### STATUS_KAMPANYE

Dipakai pada: `DATA_OPERASIONAL.KAMPANYE_SUMBANGAN.STATUS_KAMPANYE`.

| Nilai | Arti |
|---|---|
| `Direncanakan` | Kampanye belum dibuka. |
| `Berjalan` | Kampanye sedang mengumpulkan sumbangan. |
| `Selesai` | Kampanye sudah ditutup. |

### JENIS_PERISTIWA

Dipakai pada: `DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA.JENIS_PERISTIWA`.

| Nilai | Arti |
|---|---|
| `Hujan Deras dan Banjir` | Hujan lebat atau banjir yang menyulitkan umat menuju gereja. |
| `Kabut Asap` | Kualitas udara buruk akibat kabut asap. |
| `Abu Vulkanik` | Hujan abu dari letusan gunung berapi. |
| `Gangguan Listrik` | Pemadaman listrik yang mengganggu pelaksanaan Misa. |

### TINGKAT_GANGGUAN

Dipakai pada: `DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA.TINGKAT_GANGGUAN`.

| Nilai | Arti |
|---|---|
| `Ringan` | Gangguan kecil, sebagian kecil umat terpengaruh. |
| `Sedang` | Gangguan yang nyata menurunkan jumlah umat yang datang. |
| `Berat` | Gangguan besar, kegiatan dapat dibatalkan. |

### KATEGORI_EKONOMI

Dipakai pada: `MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN.KATEGORI_EKONOMI`.

| Nilai | Arti |
|---|---|
| `Rendah` | Kapasitas ekonomi umum lingkungan di bawah rata-rata paroki. |
| `Menengah Bawah` | Kapasitas ekonomi umum lingkungan agak di bawah rata-rata paroki. |
| `Menengah Atas` | Kapasitas ekonomi umum lingkungan agak di atas rata-rata paroki. |
| `Tinggi` | Kapasitas ekonomi umum lingkungan di atas rata-rata paroki. |

### KELOMPOK_PENGGUNA

Dipakai pada: `MASTER_DATA.KEBIJAKAN_AKSES_DATA.KELOMPOK_PENGGUNA`.

| Nilai | Arti |
|---|---|
| `Pastor Paroki dan Pengurus Harian` | Pimpinan paroki. |
| `Ketua Seksi` | Ketua seksi pelayanan. |
| `Ketua Wilayah dan Lingkungan` | Pengurus wilayah dan lingkungan. |
| `Sekretariat dan Keuangan` | Petugas administrasi, data, dan pembukuan. |
| `Dasbor Umum` | Pengunjung dasbor yang terbuka untuk umum. |

### TINGKAT_AKSES

Dipakai pada: `MASTER_DATA.KEBIJAKAN_AKSES_DATA.TINGKAT_AKSES`.

| Nilai | Arti |
|---|---|
| `Penuh` | Boleh melihat rincian data. |
| `Agregat Saja` | Hanya boleh melihat ringkasan tanpa rincian pribadi. |
| `Tidak Ada` | Tidak boleh mengakses data. |

## View analisis (skema ANALISIS)

View hanya berisi data agregat atau ringkasan operasional. Tidak ada view yang menampilkan nama, pengenal umat atau keluarga, maupun tahun lahir. Setiap view memiliki kolom `SUMBER_DATA` yang menandai data simulasi.

| View | Kegunaan |
|---|---|
| `ANALISIS.STRUKTUR_WILAYAH` | Struktur wilayah dan lingkungan beserta masa berlaku. Data simulasi. |
| `ANALISIS.PELAKSANAAN_MISA` | Satu baris per kejadian Misa: jadwal, waktu aktual, selisih menit, dan jumlah umat. Data simulasi. |
| `ANALISIS.KEHADIRAN_MISA_BULANAN` | Kehadiran umat per bulan dan sesi Misa (hanya Misa yang terlaksana). Data simulasi. |
| `ANALISIS.KOLEKTE_MISA_BULANAN` | Kolekte per bulan, sesi Misa, dan jenis kolekte: jumlah tercatat, hasil penghitungan, dan status rekonsiliasi. Bukan ukuran iman. Data simulasi. |
| `ANALISIS.TREN_KEHADIRAN_PERIODE` | Tren kehadiran seluruh Misa per bulan dengan perbandingan terhadap bulan sebelumnya. Data simulasi. |
| `ANALISIS.SUMBANGAN_KHUSUS_PER_WILAYAH` | Sumbangan kampanye (Prapaskah, Adven, solidaritas) per wilayah. Hanya ringkasan, tidak untuk memeringkat wilayah. Data simulasi. |
| `ANALISIS.ANGGARAN_VS_REALISASI_PROGRAM` | Anggaran rencana dibandingkan pengeluaran sebenarnya untuk setiap program. Data simulasi. |
| `ANALISIS.ANGGARAN_VS_REALISASI_SEKSI` | Ringkasan anggaran dan pengeluaran per seksi, termasuk pembandingan khusus untuk program yang sudah terlaksana. Data simulasi. |
| `ANALISIS.KEGIATAN_DAN_LAPORAN` | Setiap kegiatan dengan target peserta, peserta aktual, anggaran, dan status laporan pascakegiatan. Data simulasi. |
| `ANALISIS.KELENGKAPAN_LAPORAN_PER_SEKSI` | Jumlah kegiatan per status dan kelengkapan laporan pascakegiatan untuk setiap seksi. Data simulasi. |
| `ANALISIS.HASIL_SURVEI` | Hasil survei yang sudah dirangkum: jumlah dan persentase responden per kategori jawaban. Data simulasi. |
| `ANALISIS.RINGKASAN_SKOR_LIKERT` | Skor rata-rata (1 sampai 5) dan persentase setuju untuk pertanyaan berskala Likert. Data simulasi. |
| `ANALISIS.RINGKASAN_UMAT_PER_LINGKUNGAN` | Jumlah keluarga dan umat aktif per lingkungan. Hanya angka agregat, tanpa nama atau identitas individu. Data simulasi. |
| `ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA` | Kolekte dan kehadiran per pekan (Senin sampai Minggu) dengan peristiwa luar biasa, untuk grafik riwayat dan membaca penyimpangan peramalan. Data simulasi. |
| `ANALISIS.DAMPAK_PERISTIWA_LUAR_BIASA` | Kehadiran dan kolekte selama setiap peristiwa luar biasa dibandingkan dengan yang diharapkan dari rata-rata 8 pekan sebelumnya untuk sesi Misa yang sama. Data simulasi. |
| `ANALISIS.POLA_KOLEKTE_HARI_DALAM_BULAN` | Kolekte per umat yang hadir menurut tanggal dalam bulan, per tahun. Pola administrasi (setelah hari gajian), bukan ukuran iman. Data simulasi. |
| `ANALISIS.KORELASI_KOLEKTE_KEHADIRAN` | Korelasi kolekte dengan jumlah umat dan dengan tanggal dalam bulan, per tahun dan sesi Misa. Data simulasi. |
| `ANALISIS.PEMASUKAN_PENGELUARAN_BULANAN` | Pemasukan (kolekte, sumbangan khusus) dan pengeluaran program per bulan, dengan peristiwa luar biasa. Data simulasi. |
| `ANALISIS.PEMASUKAN_PENGELUARAN_TAHUNAN` | Pemasukan dan pengeluaran program per tahun, pertumbuhan tahun ke tahun, dan kolekte per Misa tanpa peristiwa luar biasa. Tahun berjalan ditandai belum lengkap. Data simulasi. |
| `ANALISIS.PROYEKSI_PEMASUKAN_PENGELUARAN` | Garis tren linear dari tahun-tahun lengkap dan proyeksinya ke depan, serta tahun ketika tren pengeluaran melampaui tren kolekte. Metode sederhana. Data simulasi. |
| `ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN` | Sumbangan kampanye per lingkungan: total, rata-rata, median, dan per keluarga atau umat terdaftar, beserta kapasitas ekonomi lingkungan. Menggambarkan sebaran, bukan menilai iman atau kemurahan hati. Data simulasi. |
| `ANALISIS.TITIK_IMPAS_KAMPANYE` | Sumbangan kampanye (Prapaskah, Adven, solidaritas) dibandingkan dengan biaya kegiatan besar yang didanainya, per tahun. Surplus menjadi pemasukan gereja, defisit ditutup gereja. Data simulasi. |
| `ANALISIS.KEGIATAN_MENDATANG` | Kegiatan yang akan datang, satu baris per rencana yang belum terlaksana: sudah dijadwalkan sebagai kegiatan, masih berupa rencana tahunan, atau ditunda tahun ini dan perlu jadwal baru. Lengkap dengan tanggal, tempat, target peserta, anggaran, dan dana pendukung. Acuan waktu adalah tanggal data. Data simulasi. |

## Catatan kewajaran dan privasi

- Nama pada `UMAT` dan `KELUARGA` adalah gabungan acak nama depan dan nama keluarga yang umum. Kemiripan dengan orang sebenarnya adalah kebetulan.
- Model data tidak memiliki kolom untuk nomor identitas, nomor telepon, alamat rumah, atau tanggal lahir lengkap.
- Responden survei bersifat anonim dan tidak terhubung ke `ID_UMAT`.
- Jumlah kolekte adalah ringkasan administrasi keuangan dan bukan ukuran iman atau komitmen rohani. Hubungan kolekte dengan jumlah umat dan tanggal dalam bulan dipakai hanya untuk memahami pola dan membuat proyeksi.
- Sumbangan per wilayah atau per lingkungan tidak boleh dipakai untuk memeringkat wilayah atau lingkungan, dan tidak menggambarkan iman atau kemurahan hati. Angka tersebut menunjukkan kapasitas ekonomi dan sebaran sumbangan.
- `SUMBANGAN_KELUARGA` memuat jumlah sumbangan keluarga fiktif yang teridentifikasi. Data ini berklasifikasi Sangat Terbatas dan hanya boleh tampil sebagai angka agregat (misalnya rata-rata, median, dan total per lingkungan).
- Kapasitas ekonomi hanya dicatat pada tingkat lingkungan (`PROFIL_EKONOMI_LINGKUNGAN`). Tidak ada data ekonomi per keluarga, dan keluarga penyumbang besar tidak ditandai pada data mana pun.
- `PERISTIWA_LUAR_BIASA` mencatat kejadian dan tingkat gangguannya, tetapi sengaja tidak menyimpan besar dampaknya terhadap kehadiran atau kolekte. Dampak dihitung oleh view analisis dari data.
- Geometri pada `GEOMETRI_ILUSTRATIF_LINGKUNGAN` sengaja diletakkan di koordinat 0 derajat Lintang dan 0 derajat Bujur agar tidak disangka batas wilayah paroki yang sebenarnya.
