"""Public service guides: the steps and requirements to enrol for a sacrament, to register in a
neighbourhood community (lingkungan) and what to do when a parishioner dies.

The guides exist twice, and the two copies are generated from the same rows so they cannot drift apart:

* three tables in MASTER_DATA (LAYANAN_PAROKI, LANGKAH_LAYANAN, PERSYARATAN_LAYANAN), which the dashboard
  reads through the ANALISIS views, and
* one PDF per service in app/public_documents/, which a visitor can download and print.

Everything here is FICTIONAL. The procedures are plausible, generic examples written for a demonstration.
They are not the rules of any diocese or parish, and every document says so. No telephone numbers,
addresses (apart from the clearly fictional one in the letterhead) or personal data appear anywhere.

Interpretation to confirm with the parish: "Baptis Batuta" is read as the baptism of babies and children
under seven years old, who are baptised on the request of their parents.
"""

from datetime import date

from . import documents, pdfdoc, util

SCHEMA = "MASTER_DATA"
FOLDER = "app/public_documents"

KLASIFIKASI_PUBLIK = "KLS-01"
HOURS = "Senin sampai Jumat pukul 08.00 sampai 15.00 dan Sabtu pukul 08.00 sampai 12.00"
NOTICE = ("Panduan ini contoh untuk demonstrasi. Isinya fiktif dan bukan ketentuan resmi gereja, keuskupan, "
          "maupun paroki mana pun. Untuk keperluan nyata, tanyakan langsung kepada sekretariat paroki Anda.")

APPLICANT = "Pemohon atau keluarga"
OFFICE = "Sekretariat paroki"
PASTOR = "Pastor paroki"
SECTION = "Seksi terkait"
LEADER = "Ketua lingkungan"

# id, name, category, summary, processing time, important notes, managing section, revised on
SERVICES = [
    ("LYN-01", "Baptis Dewasa", "Sakramen",
     "Untuk orang berusia 17 tahun ke atas yang ingin menjadi Katolik melalui Sakramen Baptis, setelah mengikuti masa pembinaan calon baptis.",
     "Sekitar 9 sampai 12 bulan, dari pendaftaran sampai penerimaan Sakramen Baptis.",
     "Pendaftaran dapat dilakukan sepanjang tahun dan pembinaan dimulai setiap awal semester. Baptis dewasa biasanya dirayakan pada Malam Paskah. "
     "Tidak ada tarif wajib, persembahan bersifat sukarela.",
     "SEK-02", date(2026, 2, 10)),
    ("LYN-02", "Baptis Batuta (Bayi dan Anak di Bawah 7 Tahun)", "Sakramen",
     "Untuk orang tua yang ingin membaptis bayi atau anak di bawah tujuh tahun dalam iman Katolik.",
     "Sekitar 3 sampai 6 minggu sejak pendaftaran.",
     "Baptis bayi dan anak dirayakan bersama pada hari Minggu yang ditetapkan paroki. Daftarkan anak paling lambat satu bulan sebelum tanggal yang diinginkan. "
     "Tidak ada tarif wajib, persembahan bersifat sukarela.",
     "SEK-03", date(2026, 3, 2)),
    ("LYN-03", "Krisma", "Sakramen",
     "Untuk umat Katolik yang sudah dibaptis dan menerima Komuni Pertama dan ingin dikuatkan imannya melalui Sakramen Krisma.",
     "Sekitar 4 sampai 6 bulan pembinaan, mengikuti jadwal kunjungan Uskup atau imam yang diberi wewenang.",
     "Pendaftaran Krisma dibuka sekali setahun dan diumumkan di Misa serta papan pengumuman. Tidak ada tarif wajib, persembahan bersifat sukarela.",
     "SEK-02", date(2026, 1, 15)),
    ("LYN-04", "Pernikahan", "Sakramen",
     "Untuk pasangan yang ingin menerima Sakramen Perkawinan di paroki ini.",
     "Sekurang-kurangnya 3 bulan, dianjurkan 6 bulan sebelum tanggal pemberkatan.",
     "Datanglah bersama sebelum menentukan tanggal dan tempat resepsi, agar jadwal gereja dan jadwal kursus persiapan dapat diatur lebih dulu. "
     "Pencatatan sipil dilakukan sesuai ketentuan pemerintah.",
     "SEK-03", date(2026, 4, 20)),
    ("LYN-05", "Pendaftaran Lingkungan", "Administrasi Umat",
     "Untuk keluarga Katolik yang baru tinggal di wilayah paroki atau belum tercatat pada sebuah lingkungan.",
     "Sekitar 3 sampai 5 hari kerja setelah berkas lengkap.",
     "Tidak ada biaya pendaftaran. Data keluarga hanya dilihat petugas yang berwenang dan tidak ditampilkan di dasbor umum.",
     "SEK-09", date(2026, 5, 12)),
    ("LYN-06", "Pelayanan Kematian (Tutup Usia)", "Pelayanan Duka",
     "Untuk keluarga yang kehilangan anggota keluarga Katolik. Memuat hal yang perlu dilakukan sejak masa sakit parah sampai peringatan sesudah pemakaman.",
     "Dimulai segera. Perayaan pemakaman biasanya dalam 1 sampai 3 hari, sesuai kesiapan keluarga.",
     "Pelayanan tidak dipungut tarif. Keluarga yang membutuhkan bantuan duka dapat menyampaikannya kepada ketua lingkungan. "
     "Hubungi pastor lebih dulu bila anggota keluarga sakit parah.",
     "SEK-01", date(2026, 6, 8)),
]

# service id -> list of (title, who does it, description)
STEPS = {
    "LYN-01": [
        ("Berkonsultasi di sekretariat", APPLICANT,
         f"Datanglah ke Sekretariat Paroki pada jam layanan ({HOURS}) untuk menyampaikan niat Anda dan mengambil formulir pendaftaran."),
        ("Mengisi formulir dan menyerahkan berkas", APPLICANT,
         "Lengkapi formulir dan serahkan berkas persyaratan. Sekretariat memeriksa kelengkapannya dan memberikan tanda terima."),
        ("Bertemu pastor", PASTOR,
         "Pastor berbincang dengan calon tentang alasan dan kesiapannya, lalu menyetujui masuknya calon ke masa pembinaan."),
        ("Mengikuti pembinaan calon baptis", SECTION,
         "Pertemuan mingguan selama sekitar satu tahun yang dipandu Seksi Katekese. Calon didampingi seorang pendamping dari lingkungan tempat tinggalnya."),
        ("Ritus penerimaan calon baptis", PASTOR,
         "Calon diterima secara resmi sebagai calon baptis dalam perayaan pada Misa hari Minggu, disaksikan umat dan keluarga."),
        ("Rekoleksi dan wawancara akhir", PASTOR,
         "Menjelang perayaan, calon mengikuti rekoleksi satu hari dan wawancara terakhir dengan pastor."),
        ("Menerima Sakramen Baptis", PASTOR,
         "Biasanya dirayakan pada Malam Paskah. Calon hadir bersama wali baptis dan keluarga sejak awal perayaan."),
        ("Pencatatan dan surat baptis", OFFICE,
         "Nama baptisan baru dicatat di buku baptis. Surat baptis dapat diambil di Sekretariat sekitar dua minggu kemudian."),
        ("Pendampingan sesudah baptis", SECTION,
         "Selama beberapa bulan, baptisan baru didampingi agar mengenal kehidupan paroki dan bergabung dengan lingkungannya."),
    ],
    "LYN-02": [
        ("Mendaftar di sekretariat", APPLICANT,
         f"Daftarkan anak paling lambat satu bulan sebelum tanggal yang diinginkan, pada jam layanan ({HOURS}). Ambil formulir dan jadwal baptis bersama."),
        ("Melengkapi berkas", APPLICANT,
         "Serahkan berkas persyaratan dan surat pernyataan orang tua. Sekretariat memeriksa kelengkapannya dan memberikan tanda terima."),
        ("Mengikuti pembekalan orang tua dan wali baptis", SECTION,
         "Satu kali pertemuan sekitar dua jam yang dipandu Seksi Kerasulan Keluarga tentang arti baptis dan peran orang tua serta wali baptis."),
        ("Konfirmasi tanggal baptis", OFFICE,
         "Sekretariat menetapkan tanggal pada hari Minggu yang disediakan paroki dan memberi tahu keluarga."),
        ("Merayakan Sakramen Baptis", PASTOR,
         "Anak dibaptis dalam perayaan bersama. Orang tua dan wali baptis hadir sejak awal perayaan."),
        ("Pencatatan dan surat baptis", OFFICE,
         "Nama anak dicatat di buku baptis. Surat baptis dapat diambil di Sekretariat sekitar dua minggu kemudian."),
        ("Menyambut anak di lingkungan", LEADER,
         "Ketua lingkungan menyambut anak yang baru dibaptis dan memastikan data keluarga pada lingkungan sudah benar."),
    ],
    "LYN-03": [
        ("Mendaftar pada masa pendaftaran", APPLICANT,
         f"Pendaftaran dibuka sekali setahun dan diumumkan di Misa serta papan pengumuman. Daftar di Sekretariat pada jam layanan ({HOURS})."),
        ("Menyerahkan berkas", APPLICANT,
         "Serahkan surat permohonan, fotokopi surat baptis, dan pas foto. Sekretariat memberikan tanda terima."),
        ("Mengikuti pembinaan Krisma", SECTION,
         "Sekitar sepuluh pertemuan yang dipandu Seksi Katekese. Kehadiran dicatat agar pendamping dapat membantu bila ada pertemuan yang terlewat."),
        ("Rekoleksi dan wawancara", PASTOR,
         "Calon mengikuti rekoleksi satu hari dan bertemu pastor atau pendamping untuk wawancara singkat."),
        ("Menerima Sakramen Krisma", PASTOR,
         "Dilayani oleh Uskup atau imam yang diberi wewenang, dalam Misa yang ditetapkan. Calon didampingi pendamping Krisma."),
        ("Pencatatan", OFFICE,
         "Krisma dicatat pada buku baptis. Bila calon dibaptis di paroki lain, paroki itu diberi tahu agar catatannya diperbarui."),
    ],
    "LYN-04": [
        ("Konsultasi awal", APPLICANT,
         f"Datanglah bersama ke Sekretariat pada jam layanan ({HOURS}) untuk menyampaikan niat dan menjajaki tanggal pemberkatan."),
        ("Mendaftar dan menyerahkan berkas", APPLICANT,
         "Isi formulir pendaftaran dan serahkan berkas persyaratan. Sekretariat memeriksa kelengkapannya dan memberikan tanda terima."),
        ("Mengikuti kursus persiapan perkawinan", SECTION,
         "Beberapa pertemuan bersama pasangan lain yang dipandu Seksi Kerasulan Keluarga tentang hidup berkeluarga dan arti Sakramen Perkawinan."),
        ("Penyelidikan kanonik", PASTOR,
         "Pastor atau petugas mewawancarai kedua calon secara terpisah untuk memastikan keduanya bebas dan siap menikah."),
        ("Pengumuman rencana perkawinan", OFFICE,
         "Rencana perkawinan diumumkan di paroki selama beberapa hari Minggu agar umat dapat menyampaikan bila mengetahui adanya halangan."),
        ("Menyusun tata perayaan dan gladi", SECTION,
         "Memilih bacaan dan lagu, mengatur petugas bersama Seksi Liturgi, dan mengadakan gladi satu atau dua hari sebelum pemberkatan."),
        ("Merayakan Sakramen Perkawinan", PASTOR,
         "Pemberkatan dilakukan di gereja dengan dua orang saksi. Pastor atau imam yang ditugaskan memimpin perayaan."),
        ("Pencatatan dan surat nikah gereja", OFFICE,
         "Perkawinan dicatat di buku perkawinan dan paroki tempat kedua mempelai dibaptis diberi tahu. Surat nikah gereja dapat diambil sekitar dua minggu kemudian."),
        ("Mengurus pencatatan sipil", APPLICANT,
         "Pencatatan sipil dilakukan di kantor catatan sipil sesuai ketentuan pemerintah dan urutan yang disepakati dengan pastor."),
    ],
    "LYN-05": [
        ("Mencari lingkungan yang sesuai", APPLICANT,
         f"Tanyakan lingkungan menurut alamat tinggal Anda di Sekretariat pada jam layanan ({HOURS}) atau lihat daftar wilayah paroki."),
        ("Mengisi formulir dan menyerahkan berkas", APPLICANT,
         "Kepala keluarga mengisi formulir pendaftaran dan menyerahkan berkas persyaratan."),
        ("Memeriksa berkas", OFFICE,
         "Sekretariat memeriksa kelengkapan berkas dan memberikan tanda terima."),
        ("Memberi tahu ketua lingkungan", OFFICE,
         "Sekretariat menyampaikan kepada ketua lingkungan bahwa ada keluarga baru yang akan bergabung."),
        ("Menyambut keluarga baru", LEADER,
         "Ketua lingkungan menghubungi keluarga dan mengundangnya pada doa lingkungan terdekat."),
        ("Mencatat di data umat", OFFICE,
         "Data keluarga dicatat dalam basis data paroki dengan akses terbatas. Pemberitahuan bahwa pendaftaran selesai disampaikan kepada keluarga."),
    ],
    "LYN-06": [
        ("Memanggil imam saat sakit parah", APPLICANT,
         "Bila anggota keluarga sakit parah atau mendekati ajal, segera hubungi pastor untuk Sakramen Pengurapan Orang Sakit dan Komuni bekal, sebaiknya selagi yang bersangkutan masih sadar."),
        ("Memberi kabar kepada ketua lingkungan dan sekretariat", APPLICANT,
         f"Setelah meninggal dunia, segera kabari ketua lingkungan dan Sekretariat Paroki (jam layanan: {HOURS}). Di luar jam layanan, kabari ketua lingkungan."),
        ("Mengurus surat keterangan kematian", APPLICANT,
         "Mintalah surat keterangan kematian dari dokter, rumah sakit, atau kelurahan. Surat ini diperlukan untuk pemakaman dan pencatatan."),
        ("Doa bersama di rumah duka", LEADER,
         "Ketua lingkungan mengoordinasi ibadat atau doa arwah bersama umat setempat, biasanya pada malam hari sampai hari pemakaman."),
        ("Menetapkan waktu Misa atau ibadat pemakaman", OFFICE,
         "Sekretariat dan pastor menetapkan waktu bersama keluarga agar tidak bertabrakan dengan jadwal Misa lain."),
        ("Menyiapkan petugas liturgi", SECTION,
         "Seksi Liturgi menyiapkan lektor, pemazmur, dan pemimpin lagu, serta tata ibadat sesuai permintaan keluarga."),
        ("Merayakan pemakaman", PASTOR,
         "Misa requiem atau ibadat sabda, ritus pelepasan jenazah, dan pemakaman."),
        ("Pencatatan di buku kematian", OFFICE,
         "Kematian dicatat di buku kematian. Status keanggotaan umat diperbarui oleh petugas yang berwenang tanpa menampilkan data pribadi di dasbor umum."),
        ("Misa peringatan", APPLICANT,
         "Keluarga dapat mengajukan Misa peringatan melalui Sekretariat, misalnya pada hari ketiga, ketujuh, keempat puluh, keseratus, dan keseribu menurut kebiasaan setempat."),
    ],
}

# service id -> list of (name, type, mandatory, note)
REQUIREMENTS = {
    "LYN-01": [
        ("Berusia 17 tahun ke atas", "Ketentuan Umum", True,
         "Calon yang belum berusia 17 tahun mengikuti pembinaan calon baptis remaja yang dilayani Seksi Katekese."),
        ("Permohonan atas kemauan sendiri", "Ketentuan Umum", True,
         "Calon menulis surat permohonan baptis dengan tulisan tangan, tanpa paksaan dari pihak mana pun."),
        ("Fotokopi kartu identitas", "Dokumen", True,
         "Satu lembar, dipakai hanya untuk pencatatan di buku baptis."),
        ("Fotokopi akta kelahiran atau dokumen pengganti", "Dokumen", True,
         "Memuat nama lengkap dan tanggal lahir yang akan dicatat di buku baptis."),
        ("Pas foto berwarna ukuran 3x4", "Dokumen", True, "Dua lembar."),
        ("Keterangan status perkawinan", "Dokumen", False,
         "Hanya bagi calon yang sudah menikah. Status perkawinan dibicarakan dengan pastor sebelum pembinaan dimulai."),
        ("Wali baptis", "Ketentuan Umum", True,
         "Satu umat Katolik yang sudah menerima Sakramen Baptis, Ekaristi, dan Krisma, berusia sekurang-kurangnya 16 tahun. Bila bukan umat paroki ini, wali membawa keterangan dari paroki asalnya."),
        ("Mengikuti pembinaan calon baptis", "Pembinaan", True,
         "Pertemuan mingguan selama sekitar satu tahun yang dipandu Seksi Katekese."),
        ("Wawancara dengan pastor dan rekoleksi persiapan", "Pembinaan", True,
         "Dilakukan menjelang perayaan untuk memastikan calon siap dan mantap."),
    ],
    "LYN-02": [
        ("Orang tua bersedia mendidik anak dalam iman Katolik", "Ketentuan Umum", True,
         "Salah satu atau kedua orang tua menandatangani surat pernyataan kesediaan di sekretariat."),
        ("Fotokopi akta kelahiran anak", "Dokumen", True, "Satu lembar."),
        ("Fotokopi surat nikah orang tua", "Dokumen", True,
         "Surat nikah gereja bila ada. Bila tidak ada, sekretariat menjelaskan dokumen pengganti yang dapat diterima."),
        ("Fotokopi kartu keluarga", "Dokumen", True,
         "Untuk mencatat lingkungan tempat tinggal dan mengaitkan anak dengan keluarganya."),
        ("Wali baptis", "Ketentuan Umum", True,
         "Satu umat Katolik yang sudah menerima Sakramen Baptis, Ekaristi, dan Krisma, berusia sekurang-kurangnya 16 tahun, dan bukan ayah atau ibu anak."),
        ("Keterangan wali baptis dari paroki asal", "Dokumen", False,
         "Hanya bila wali baptis bukan umat paroki ini."),
        ("Pembekalan orang tua dan wali baptis", "Pembinaan", True,
         "Satu kali pertemuan sekitar dua jam yang dipandu Seksi Kerasulan Keluarga."),
        ("Nama baptis anak", "Ketentuan Umum", False,
         "Orang tua dapat memilih nama baptis. Bila belum ada pilihan, nama pelindung dipilih bersama pastor."),
    ],
    "LYN-03": [
        ("Sudah dibaptis Katolik dan menerima Komuni Pertama", "Ketentuan Umum", True,
         "Dibuktikan dengan surat baptis. Komuni Pertama dicatat oleh paroki asal."),
        ("Berusia sekurang-kurangnya 14 tahun", "Ketentuan Umum", True,
         "Atau duduk di kelas 8. Calon dewasa mendaftar pada kelompok pembinaan dewasa."),
        ("Fotokopi surat baptis", "Dokumen", True,
         "Dari paroki tempat dibaptis. Bila dibaptis di paroki lain, sekretariat dapat memintakan keterangan baptis."),
        ("Surat permohonan dan pas foto berwarna ukuran 3x4", "Dokumen", True,
         "Surat ditulis tangan oleh calon, pas foto dua lembar."),
        ("Pendamping Krisma", "Ketentuan Umum", True,
         "Satu umat Katolik yang sudah menerima Krisma dan menjalani hidup beriman dengan baik, yang menemani calon pada perayaan."),
        ("Mengikuti pembinaan Krisma", "Pembinaan", True,
         "Sekitar sepuluh pertemuan dengan kehadiran sekurang-kurangnya 80 persen."),
        ("Mengikuti rekoleksi persiapan", "Pembinaan", True, "Satu hari bersama, sebelum perayaan."),
        ("Nama Krisma", "Ketentuan Umum", False,
         "Calon boleh memilih nama pelindung baru, boleh juga tetap memakai nama baptisnya."),
    ],
    "LYN-04": [
        ("Surat baptis terbaru kedua calon", "Dokumen", True,
         "Diterbitkan paling lama enam bulan sebelum pendaftaran, dengan catatan Krisma bila sudah menerimanya."),
        ("Fotokopi kartu identitas dan kartu keluarga", "Dokumen", True, "Masing-masing satu lembar untuk setiap calon."),
        ("Fotokopi akta kelahiran", "Dokumen", True, "Masing-masing satu lembar untuk setiap calon."),
        ("Surat keterangan belum menikah", "Dokumen", True,
         "Dari kelurahan atau surat pengantar lain sesuai ketentuan setempat."),
        ("Pas foto berdampingan ukuran 4x6", "Dokumen", True, "Dua lembar."),
        ("Kursus persiapan perkawinan", "Pembinaan", True,
         "Beberapa pertemuan bersama pasangan lain yang dipandu Seksi Kerasulan Keluarga."),
        ("Penyelidikan kanonik", "Pembinaan", True,
         "Wawancara terpisah dengan pastor atau petugas untuk memastikan kedua calon bebas dan siap menikah."),
        ("Dua orang saksi", "Ketentuan Umum", True,
         "Berusia dewasa dan membawa kartu identitas pada hari pemberkatan."),
        ("Izin atau dispensasi dari Keuskupan", "Dokumen", False,
         "Hanya bila salah satu calon bukan Katolik atau ada halangan lain. Sekretariat membantu mengurusnya."),
        ("Pencatatan sipil", "Ketentuan Umum", True,
         "Dilakukan di kantor catatan sipil sesuai ketentuan pemerintah."),
    ],
    "LYN-05": [
        ("Formulir pendaftaran keluarga", "Dokumen", True,
         "Diisi kepala keluarga: nama anggota keluarga, hubungan keluarga, dan alamat tinggal sekarang."),
        ("Fotokopi kartu keluarga", "Dokumen", True,
         "Untuk memastikan alamat tinggal berada di wilayah paroki."),
        ("Fotokopi surat baptis anggota keluarga yang Katolik", "Dokumen", True,
         "Satu lembar untuk setiap anggota. Bila belum ada, cukup keterangan tempat dan tahun baptis."),
        ("Surat pindah dari paroki asal", "Dokumen", False, "Hanya bila sebelumnya tercatat di paroki lain."),
        ("Persetujuan pengelolaan data keluarga", "Ketentuan Umum", True,
         "Kepala keluarga menyetujui bahwa data keluarga dicatat dengan klasifikasi terbatas dan hanya dilihat petugas yang berwenang."),
        ("Tempat tinggal berada di wilayah paroki", "Ketentuan Umum", True,
         "Lingkungan ditentukan menurut tempat tinggal. Sekretariat membantu mencari lingkungan yang sesuai."),
    ],
    "LYN-06": [
        ("Surat keterangan kematian", "Dokumen", True, "Dari dokter, rumah sakit, atau kelurahan."),
        ("Fotokopi surat baptis almarhum atau almarhumah", "Dokumen", False,
         "Untuk pencatatan di buku kematian. Bila tidak ada, cukup sebutkan nama baptis kepada sekretariat."),
        ("Fotokopi kartu identitas almarhum atau almarhumah", "Dokumen", False, "Untuk melengkapi pencatatan."),
        ("Pemberitahuan kepada ketua lingkungan dan sekretariat", "Ketentuan Umum", True,
         "Agar doa bersama dan jadwal pemakaman dapat diatur secepatnya."),
        ("Penghubung dari pihak keluarga", "Ketentuan Umum", False,
         "Satu anggota keluarga menjadi penghubung dengan paroki dan lingkungan agar informasi tidak simpang siur."),
        ("Pilihan tempat dan waktu pemakaman", "Ketentuan Umum", True,
         "Dibicarakan dengan sekretariat dan pastor agar tidak bertabrakan dengan jadwal Misa."),
        ("Permintaan bantuan duka", "Ketentuan Umum", False,
         "Keluarga yang membutuhkan dapat menyampaikannya kepada ketua lingkungan untuk diteruskan ke Seksi Pengembangan Sosial Ekonomi."),
    ],
}


def file_name(service_id, name):
    return f"{service_id}_{documents.slug(name)}.pdf"


def build():
    """The three MASTER_DATA tables."""
    services, steps, requirements = [], [], []
    for sid, name, category, summary, duration, notes, section, revised in SERVICES:
        services.append({
            "ID_LAYANAN": sid,
            "NAMA_LAYANAN": name,
            "KATEGORI_LAYANAN": category,
            "RINGKASAN": summary,
            "PERKIRAAN_WAKTU_PROSES": duration,
            "CATATAN_PENTING": notes,
            "ID_SEKSI_PENGELOLA": section,
            "ID_KLASIFIKASI_DATA": KLASIFIKASI_PUBLIK,
            "NAMA_BERKAS_PANDUAN": file_name(sid, name),
            "TANGGAL_REVISI": revised,
        })
        number = sid.split("-")[1]
        for order, (title, actor, text) in enumerate(STEPS[sid], start=1):
            steps.append({"ID_LANGKAH": f"LGK-{number}{util.pad(order, 2)}", "ID_LAYANAN": sid, "NOMOR_URUT": order,
                          "JUDUL_LANGKAH": title, "URAIAN": text, "PELAKU": actor})
        for order, (item, kind, mandatory, note) in enumerate(REQUIREMENTS[sid], start=1):
            requirements.append({"ID_PERSYARATAN": f"PSY-{number}{util.pad(order, 2)}", "ID_LAYANAN": sid,
                                 "NOMOR_URUT": order, "NAMA_PERSYARATAN": item, "JENIS_PERSYARATAN": kind,
                                 "WAJIB_DIPENUHI": mandatory, "KETERANGAN": note})
    return {f"{SCHEMA}.LAYANAN_PAROKI": services, f"{SCHEMA}.LANGKAH_LAYANAN": steps,
            f"{SCHEMA}.PERSYARATAN_LAYANAN": requirements}


# --------------------------------------------------------------------------------------------
# PDF layout (re-uses the flow layout of the report documents)
# --------------------------------------------------------------------------------------------
INDENT = 24
SMALL = 8.5


def _item(flow, number, title, meta, text, checkbox=False):
    """One numbered entry: bold title, small grey meta line, then the explanation. Kept together on a page."""
    x = documents.LEFT + INDENT
    width = documents.PDF_RIGHT - x
    title_lines = pdfdoc.wrap(title, "F2", documents.BODY, width)
    text_lines = pdfdoc.wrap(text, "F1", documents.BODY, width) if text else []
    flow.need(documents.LEADING * (len(title_lines) + len(text_lines)) + 14)
    top = flow.y
    if checkbox:
        flow.page.rect(documents.LEFT + 4, top + 1.5, 9, 9, 0.7, 0.3)
    else:
        flow.page.text(documents.LEFT, top + documents.BODY, f"{number}.", "F2", documents.BODY)
    for line in title_lines:
        flow.page.text(x, flow.y + documents.BODY, line, "F2", documents.BODY)
        flow.y += documents.LEADING
    flow.page.text(x, flow.y + SMALL, meta, "F1", SMALL, 0.4)
    flow.y += 12
    for line in text_lines:
        flow.page.text(x, flow.y + documents.BODY, line, "F1", documents.BODY)
        flow.y += documents.LEADING
    flow.y += 5


def _notice(flow, text):
    lines = pdfdoc.wrap(text, "F1", documents.BODY, documents.CONTENT_WIDTH - 16)
    height = 12 + documents.LEADING * len(lines) + 6
    flow.need(height + 6)
    top = flow.y + 2
    flow.page.rect(documents.LEFT, top, documents.CONTENT_WIDTH, height, 0.8, 0.35, fill=0.95)
    for index, line in enumerate(lines):
        flow.page.text(documents.LEFT + 8, top + 18 + documents.LEADING * index, line, "F1", documents.BODY)
    flow.y = top + height + 6


def _footer(pdf, service):
    total = len(pdf.pages)
    for number, page in enumerate(pdf.pages, start=1):
        page.line(documents.LEFT, 806, documents.PDF_RIGHT, 806, 0.4, 0.6)
        page.artifact_text(documents.LEFT, 820, f"Panduan {service['ID_LAYANAN']}  |  Halaman {number} dari {total}")
        note_width = pdfdoc.text_width(documents.SIMULATION_NOTE, "F1", 8)
        page.artifact_text(documents.PDF_RIGHT - note_width, 820, documents.SIMULATION_NOTE)


def render(service, section_name, steps, requirements):
    pdf = pdfdoc.Pdf(
        title=f"Panduan Layanan Paroki: {service['NAMA_LAYANAN']}",
        author=f"{section_name} (dokumen simulasi)",
        subject="Panduan layanan paroki untuk umum (data simulasi, fiktif)",
        created=service["TANGGAL_REVISI"])
    flow = documents.Flow(pdf)
    documents.letterhead(flow)

    center = (documents.LEFT + documents.PDF_RIGHT) / 2.0
    title = "PANDUAN LAYANAN PAROKI"
    flow.page.text(center - pdfdoc.text_width(title, "F2", 13) / 2.0, flow.y + 12, title, "F2", 13)
    sub = service["NAMA_LAYANAN"].upper()
    for index, line in enumerate(pdfdoc.wrap(sub, "F1", 10.5, documents.CONTENT_WIDTH)):
        flow.page.text(center - pdfdoc.text_width(line, "F1", 10.5) / 2.0, flow.y + 29 + 13 * index, line, "F1", 10.5)
        flow.y += 13
    flow.y += 40

    flow.field("Nomor panduan", service["ID_LAYANAN"])
    flow.field("Kategori", service["KATEGORI_LAYANAN"])
    flow.field("Dikelola oleh", section_name)
    flow.field("Terakhir ditinjau", util.date_id(service["TANGGAL_REVISI"]))
    flow.field("Perkiraan waktu", service["PERKIRAAN_WAKTU_PROSES"])
    flow.space(4)
    _notice(flow, NOTICE)

    flow.heading("A. Untuk siapa")
    flow.paragraph(service["RINGKASAN"])

    flow.heading("B. Persyaratan")
    for order, req in enumerate(requirements, start=1):
        status = "Wajib" if req["WAJIB_DIPENUHI"] else "Jika berlaku"
        _item(flow, order, req["NAMA_PERSYARATAN"], f"{req['JENIS_PERSYARATAN']}  |  {status}", req["KETERANGAN"], checkbox=True)

    flow.heading("C. Langkah-langkah")
    for step in steps:
        _item(flow, step["NOMOR_URUT"], step["JUDUL_LANGKAH"], f"Pelaku: {step['PELAKU']}", step["URAIAN"])

    flow.heading("D. Catatan penting")
    flow.paragraph(service["CATATAN_PENTING"])
    _footer(pdf, service)
    return pdf.render()


def build_documents(data):
    """{relative path: PDF bytes}, one guide per service."""
    sections = {r["ID_SEKSI"]: r["NAMA_SEKSI"] for r in data["MASTER_DATA.MASTER_SEKSI"]}
    steps, requirements = {}, {}
    for row in data["MASTER_DATA.LANGKAH_LAYANAN"]:
        steps.setdefault(row["ID_LAYANAN"], []).append(row)
    for row in data["MASTER_DATA.PERSYARATAN_LAYANAN"]:
        requirements.setdefault(row["ID_LAYANAN"], []).append(row)
    files = {}
    for service in data["MASTER_DATA.LAYANAN_PAROKI"]:
        sid = service["ID_LAYANAN"]
        files[f"{FOLDER}/{service['NAMA_BERKAS_PANDUAN']}"] = render(
            service, sections[service["ID_SEKSI_PENGELOLA"]],
            sorted(steps.get(sid, []), key=lambda r: r["NOMOR_URUT"]),
            sorted(requirements.get(sid, []), key=lambda r: r["NOMOR_URUT"]))
    return files
