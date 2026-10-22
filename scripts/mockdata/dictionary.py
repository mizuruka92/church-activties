"""Builds docs/DATA_DICTIONARY.md (Bahasa Indonesia) from the DDL comments, the
declared keys, the controlled vocabularies and the generated row counts."""

import re

from .vocab import DAFTAR_NILAI, NILAI_TERKENDALI

DOMAINS = [
    ("1", "Kolekte", ["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE", "MASTER_DATA.REFERENSI_JENIS_KOLEKTE"]),
    ("2", "Kehadiran Misa", ["DATA_OPERASIONAL.KEHADIRAN_MISA", "DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA"]),
    ("3", "Basis data umat (simulasi BIDUK)", [
        "DATA_OPERASIONAL.KELUARGA", "DATA_OPERASIONAL.UMAT", "DATA_OPERASIONAL.PENUGASAN_KELUARGA",
        "DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN", "MASTER_DATA.REFERENSI_KLASIFIKASI_DATA",
        "MASTER_DATA.KEBIJAKAN_AKSES_DATA", "MASTER_DATA.REFERENSI_KATEGORI_INFORMASI"]),
    ("4", "Sumbangan kesempatan khusus per wilayah", [
        "DATA_OPERASIONAL.KAMPANYE_SUMBANGAN", "DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS",
        "DATA_OPERASIONAL.SUMBANGAN_KELUARGA", "MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS"]),
    ("5", "Jadwal Misa", ["MASTER_DATA.JADWAL_MISA", "DATA_OPERASIONAL.KEJADIAN_MISA"]),
    ("6", "Survei", [
        "MASTER_DATA.SURVEI", "MASTER_DATA.PERTANYAAN_SURVEI", "MASTER_DATA.OPSI_JAWABAN_SURVEI",
        "DATA_OPERASIONAL.RESPONDEN_SURVEI", "DATA_OPERASIONAL.JAWABAN_SURVEI", "DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT"]),
    ("7", "Rencana tahunan, anggaran, dan realisasi", [
        "DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN", "DATA_OPERASIONAL.RENCANA_KEGIATAN",
        "DATA_OPERASIONAL.ALOKASI_ANGGARAN", "DATA_OPERASIONAL.REALISASI_PENGELUARAN",
        "MASTER_DATA.REFERENSI_KATEGORI_BIAYA"]),
    ("8", "Kegiatan dan laporan pascakegiatan", ["DATA_OPERASIONAL.KEGIATAN", "DATA_OPERASIONAL.LAPORAN_KEGIATAN"]),
    ("9", "Data induk wilayah dan GIS", [
        "MASTER_DATA.MASTER_WILAYAH", "MASTER_DATA.MASTER_LINGKUNGAN", "MASTER_DATA.PROFIL_EKONOMI_LINGKUNGAN",
        "MASTER_DATA.GEOMETRI_ILUSTRATIF_LINGKUNGAN"]),
    ("-", "Referensi bersama", [
        "MASTER_DATA.INFO_DATASET", "MASTER_DATA.MASTER_SEKSI", "MASTER_DATA.REFERENSI_DAFTAR_NILAI",
        "MASTER_DATA.REFERENSI_PERIODE_PELAPORAN"]),
]


def _domain_of(qualified):
    for number, name, tables in DOMAINS:
        if qualified in tables:
            return name
    return "-"


def view_descriptions(views_sql):
    return re.findall(r"CREATE OR REPLACE VIEW ANALISIS\.(\w+)\s+COMMENT = '([^']*)'", views_sql)


def render(tables, data, views_sql):
    by_name = {t.qualified: t for t in tables}
    vocab_columns = {}
    for table, column, group in NILAI_TERKENDALI:
        vocab_columns.setdefault(group, []).append(f"`{table}.{column}`")
    constrained = {(table, column): group for table, column, group in NILAI_TERKENDALI}

    out = []
    w = out.append
    w("# Kamus Data Pusat Informasi Paroki")
    w("")
    w("> **DATA SIMULASI.** Seluruh isi basis data demo ini fiktif: nama orang, keluarga, wilayah, lingkungan, "
      "kegiatan, angka kolekte, dan hasil survei dibuat oleh program dan tidak berasal dari paroki mana pun. "
      "Geometri peta bersifat ilustratif dan bukan batas wilayah resmi.")
    w("")
    w("Dokumen ini **dihasilkan otomatis** dari komentar pada `sql/02_create_tables.sql` oleh "
      "`python scripts/generate_mock_data.py`. Jangan diedit langsung. Untuk mengubah isinya, ubah komentar tabel "
      "atau kolom pada DDL, lalu jalankan ulang perintah tersebut.")
    w("")
    w("## Cara membaca kamus ini")
    w("")
    w("- **Granularitas** menyatakan arti satu baris pada tabel, misalnya satu baris per Misa dan jenis kolekte.")
    w("- **Kunci utama (PK)** dan **kunci unik (UQ)** menjamin sebuah baris dapat dikenali secara unik. "
      "**Relasi (FK)** menunjukkan tabel induk yang dirujuk.")
    w("- Snowflake **tidak menegakkan** PK, UQ, dan FK pada tabel standar (hanya `NOT NULL` yang ditegakkan). "
      "Karena itu `sql/06_validate_data.sql` memeriksa identifikasi ganda dan rujukan yatim secara eksplisit.")
    w("- Nilai uang disimpan sebagai `NUMBER(18,0)` dalam rupiah, tanpa desimal, dan tidak pernah sebagai teks.")
    w("- Status dan kategori disimpan sebagai label Bahasa Indonesia yang daftarnya ada di bagian "
      "[Daftar nilai terkendali](#daftar-nilai-terkendali).")
    w("- Pada kolom `TANGGAL_AKHIR_BERLAKU`, nilai kosong berarti catatan **masih berlaku**.")
    w("- Klasifikasi data: **Publik**, **Internal**, **Terbatas**, **Sangat Terbatas**. Data umat berklasifikasi "
      "Terbatas atau lebih ketat dan tidak boleh tampil di dasbor publik.")
    w("")
    w("## Sembilan domain data")
    w("")
    w("| No | Domain | Tabel |")
    w("|---|---|---|")
    for number, name, members in DOMAINS:
        w(f"| {number} | {name} | " + ", ".join(f"`{m.split('.')[1]}`" for m in members) + " |")
    w("")
    w("## Ringkasan tabel")
    w("")
    w("| Skema | Tabel | Domain | Klasifikasi | Jumlah baris (data simulasi bawaan) |")
    w("|---|---|---|---|---:|")
    total = 0
    for t in tables:
        rows = len(data[t.qualified])
        total += rows
        w(f"| {t.schema} | [`{t.name}`](#{t.schema.lower()}{t.name.lower().replace('_', '')}) | {_domain_of(t.qualified)} | {t.classification} | {rows} |")
    w(f"| | **Jumlah** | | | **{total}** |")
    w("")
    w("## Rincian tabel")
    for t in tables:
        w("")
        w(f"### {t.schema}.{t.name}")
        w(f'<a id="{t.schema.lower()}{t.name.lower().replace("_", "")}"></a>')
        w("")
        w(t.description + ".")
        w("")
        w(f"- **Granularitas:** {t.grain}.")
        w(f"- **Klasifikasi data:** {t.classification}.")
        w(f"- **Domain:** {_domain_of(t.qualified)}.")
        w(f"- **Kunci utama (PK):** `{', '.join(t.primary_key)}`.")
        for name, columns in t.unique_keys:
            w(f"- **Kunci unik (UQ):** `{', '.join(columns)}`.")
        for fk in t.foreign_keys:
            w(f"- **Relasi (FK):** `{', '.join(fk.columns)}` merujuk ke `{fk.ref_schema}.{fk.ref_table}` (`{', '.join(fk.ref_columns)}`).")
        w("")
        w("| Kolom | Tipe data | Wajib diisi | Penjelasan | Nilai yang diizinkan atau rujukan |")
        w("|---|---|---|---|---|")
        fk_of = {}
        for fk in t.foreign_keys:
            for column, ref_column in zip(fk.columns, fk.ref_columns):
                fk_of[column] = f"Merujuk ke `{fk.ref_table}`"
        for c in t.columns:
            key = (t.qualified, c.name)
            if key in constrained:
                values = ", ".join(f"`{v}`" for v, _ in DAFTAR_NILAI[constrained[key]])
                extra = f"Salah satu dari: {values}"
            elif c.name in fk_of:
                extra = fk_of[c.name]
            else:
                extra = ""
            marker = " (PK)" if c.name in t.primary_key else ""
            w(f"| `{c.name}`{marker} | `{c.sql_type}` | {'Ya' if not c.nullable else 'Tidak'} | {c.comment} | {extra} |")

    w("")
    w("## Daftar nilai terkendali")
    w("")
    w("Nilai berikut disimpan pada tabel `MASTER_DATA.REFERENSI_DAFTAR_NILAI`. Kolom pada tabel data hanya boleh "
      "memakai nilai dari kelompok yang sesuai, dan hal ini diperiksa oleh `sql/06_validate_data.sql`.")
    for group, items in DAFTAR_NILAI.items():
        w("")
        w(f"### {group}")
        w("")
        w("Dipakai pada: " + ", ".join(vocab_columns.get(group, ["-"])) + ".")
        w("")
        w("| Nilai | Arti |")
        w("|---|---|")
        for value, meaning in items:
            w(f"| `{value}` | {meaning} |")

    w("")
    w("## View analisis (skema ANALISIS)")
    w("")
    w("View hanya berisi data agregat atau ringkasan operasional. Tidak ada view yang menampilkan nama, "
      "pengenal umat atau keluarga, maupun tahun lahir. Setiap view memiliki kolom `SUMBER_DATA` yang menandai data simulasi.")
    w("")
    w("| View | Kegunaan |")
    w("|---|---|")
    for name, comment in view_descriptions(views_sql):
        w(f"| `ANALISIS.{name}` | {comment} |")

    w("")
    w("## Catatan kewajaran dan privasi")
    w("")
    w("- Nama pada `UMAT` dan `KELUARGA` adalah gabungan acak nama depan dan nama keluarga yang umum. "
      "Kemiripan dengan orang sebenarnya adalah kebetulan.")
    w("- Model data tidak memiliki kolom untuk nomor identitas, nomor telepon, alamat rumah, atau tanggal lahir lengkap.")
    w("- Responden survei bersifat anonim dan tidak terhubung ke `ID_UMAT`.")
    w("- Jumlah kolekte adalah ringkasan administrasi keuangan dan bukan ukuran iman atau komitmen rohani. "
      "Hubungan kolekte dengan jumlah umat dan tanggal dalam bulan dipakai hanya untuk memahami pola dan membuat proyeksi.")
    w("- Sumbangan per wilayah atau per lingkungan tidak boleh dipakai untuk memeringkat wilayah atau lingkungan, "
      "dan tidak menggambarkan iman atau kemurahan hati. Angka tersebut menunjukkan kapasitas ekonomi dan sebaran sumbangan.")
    w("- `SUMBANGAN_KELUARGA` memuat jumlah sumbangan keluarga fiktif yang teridentifikasi. Data ini berklasifikasi "
      "Sangat Terbatas dan hanya boleh tampil sebagai angka agregat (misalnya rata-rata, median, dan total per lingkungan).")
    w("- Kapasitas ekonomi hanya dicatat pada tingkat lingkungan (`PROFIL_EKONOMI_LINGKUNGAN`). Tidak ada data ekonomi "
      "per keluarga, dan keluarga penyumbang besar tidak ditandai pada data mana pun.")
    w("- `PERISTIWA_LUAR_BIASA` mencatat kejadian dan tingkat gangguannya, tetapi sengaja tidak menyimpan besar dampaknya "
      "terhadap kehadiran atau kolekte. Dampak dihitung oleh view analisis dari data.")
    w("- Geometri pada `GEOMETRI_ILUSTRATIF_LINGKUNGAN` sengaja diletakkan di koordinat 0 derajat Lintang dan 0 derajat "
      "Bujur agar tidak disangka batas wilayah paroki yang sebenarnya.")
    w("")
    return "\n".join(out)
