"""Domain 4.6: surveys. Definitions, questions and options are master data.
Respondents are anonymous (no link to a parishioner). Aggregated results are
computed from the synthetic answers with integer arithmetic, so counts and
percentages are internally consistent by construction."""

from datetime import date, timedelta
from decimal import Decimal

from . import config, util
from .reference import KLS_INTERNAL, WILAYAH
from .rng import Rng

SCHEMA_M, SCHEMA_O = "MASTER_DATA", "DATA_OPERASIONAL"

LIKERT = ["Sangat Tidak Setuju", "Tidak Setuju", "Netral", "Setuju", "Sangat Setuju"]
AGE_GROUPS = [
    ("Di bawah 17 tahun", 6),
    ("17-34 tahun", 24),
    ("35-65 tahun", 52),
    ("Di atas 65 tahun", 18),
]

# Question kinds: ("likert", text, [probability per level]) or ("single", text, [(option, weight)])
SURVEYS = [
    {
        "id": "SRV-01",
        "title": "Survei Kepuasan Pelayanan Liturgi 2026",
        "purpose": "Mengetahui kepuasan umat terhadap pelayanan liturgi agar seksi dapat memperbaiki tata suara, jadwal, dan pelayanan petugas.",
        "start": date(2026, 5, 1), "end": date(2026, 5, 31), "status": "Selesai", "section": "SEK-01",
        "respondents": 84,
        "questions": [
            ("likert", "Tata suara di gereja membuat bacaan dan homili terdengar jelas.", [3, 10, 14, 45, 28]),
            ("likert", "Homili mudah dipahami dan berkaitan dengan kehidupan sehari-hari.", [2, 6, 14, 46, 32]),
            ("likert", "Nyanyian dan musik membantu saya berdoa dengan khusyuk.", [2, 7, 16, 45, 30]),
            ("likert", "Jadwal Misa mingguan sesuai dengan kebutuhan keluarga saya.", [4, 12, 18, 40, 26]),
            ("likert", "Petugas tata tertib dan penyambut umat bersikap ramah dan membantu.", [1, 4, 10, 43, 42]),
            ("single", "Jadwal Misa mana yang paling sering Anda ikuti?", [
                ("Misa Sabtu Sore", 14), ("Misa Minggu Pagi I", 17), ("Misa Minggu Pagi II", 34),
                ("Misa Minggu Bahasa Inggris", 8), ("Misa Minggu Sore", 20), ("Misa Harian", 7)]),
        ],
    },
    {
        "id": "SRV-02",
        "title": "Survei Kebutuhan Pembinaan Iman 2026",
        "purpose": "Mengetahui bentuk, waktu, dan topik pembinaan iman yang paling dibutuhkan umat sebagai dasar rencana katekese tahun berikutnya.",
        "start": date(2026, 6, 15), "end": date(2026, 7, 15), "status": "Selesai", "section": "SEK-02",
        "respondents": 72,
        "questions": [
            ("single", "Bentuk pembinaan iman apa yang paling Anda butuhkan saat ini?", [
                ("Katekese tatap muka di paroki", 26), ("Pendalaman iman di lingkungan", 30),
                ("Kelas daring", 16), ("Retret dan rekoleksi", 18), ("Belum membutuhkan", 10)]),
            ("single", "Kapan waktu yang paling memungkinkan bagi Anda?", [
                ("Hari kerja malam", 18), ("Sabtu pagi", 15), ("Sabtu sore", 22),
                ("Minggu setelah Misa", 35), ("Tidak ada waktu tertentu", 10)]),
            ("single", "Topik apa yang paling ingin Anda dalami?", [
                ("Kitab Suci", 28), ("Liturgi dan sakramen", 20), ("Hidup berkeluarga", 24),
                ("Pendampingan anak dan remaja", 18), ("Iman dan dunia kerja", 10)]),
            ("likert", "Saya merasa terbantu oleh kegiatan pembinaan iman yang sudah ada di paroki.", [3, 10, 24, 43, 20]),
            ("likert", "Informasi tentang kegiatan pembinaan iman mudah saya temukan.", [6, 18, 24, 35, 17]),
        ],
    },
    {
        "id": "SRV-03",
        "title": "Survei Kepedulian Sosial dan Kebutuhan Lingkungan 2026",
        "purpose": "Memetakan kebutuhan bantuan sosial di lingkungan dan kesediaan umat terlibat sebagai dasar program pelayanan sosial.",
        "start": date(2026, 8, 17), "end": date(2026, 10, 15), "status": "Sedang Berjalan", "section": "SEK-05",
        "respondents": 58,
        "questions": [
            ("likert", "Saya mengetahui program bantuan sosial yang dikelola paroki.", [6, 20, 22, 36, 16]),
            ("single", "Bentuk bantuan sosial apa yang paling dibutuhkan di lingkungan Anda?", [
                ("Bantuan pendidikan anak", 25), ("Bantuan kesehatan dan pengobatan", 28),
                ("Pelatihan keterampilan dan usaha", 20), ("Kunjungan dan pendampingan lansia", 17),
                ("Bantuan darurat bencana", 10)]),
            ("likert", "Saya bersedia terlibat sebagai relawan dalam kegiatan sosial paroki.", [5, 12, 25, 38, 20]),
            ("single", "Cara berpartisipasi apa yang paling sesuai bagi Anda?", [
                ("Donasi dana", 22), ("Donasi barang", 18), ("Tenaga sebagai relawan", 30),
                ("Keahlian profesional", 12), ("Doa dan dukungan moral", 18)]),
        ],
    },
    {
        "id": "SRV-04",
        "title": "Survei Minat Kegiatan Orang Muda 2027",
        "purpose": "Menjajaki minat orang muda terhadap jenis dan waktu kegiatan untuk rencana kerja tahun 2027.",
        "start": date(2026, 11, 1), "end": date(2026, 11, 30), "status": "Direncanakan", "section": "SEK-04",
        "respondents": 0,
        "questions": [
            ("single", "Jenis kegiatan orang muda apa yang paling Anda minati?", [
                ("Retret dan rekoleksi", 1), ("Olahraga dan turnamen", 1), ("Musik dan paduan suara", 1),
                ("Pelayanan sosial", 1), ("Pelatihan keterampilan", 1)]),
            ("single", "Kapan waktu kegiatan yang paling cocok bagi Anda?", [
                ("Sabtu sore", 1), ("Sabtu malam", 1), ("Minggu sore", 1), ("Hari libur nasional", 1)]),
        ],
    },
]


def build():
    rng = Rng(config.SEED, "surveys")
    region_ids = [row[0] for row in WILAYAH]

    surveys, questions, options = [], [], []
    for number, spec in enumerate(SURVEYS, start=1):
        surveys.append(
            {
                "ID_SURVEI": spec["id"],
                "JUDUL_SURVEI": spec["title"],
                "TUJUAN_SURVEI": spec["purpose"],
                "TANGGAL_MULAI": spec["start"],
                "TANGGAL_SELESAI": spec["end"],
                "STATUS_SURVEI": spec["status"],
                "ID_SEKSI": spec["section"],
                "ID_KLASIFIKASI_DATA": KLS_INTERNAL,
            }
        )
        for q_number, (kind, text, choices) in enumerate(spec["questions"], start=1):
            question_id = f"PRT-{util.pad(number, 2)}{util.pad(q_number, 2)}"
            questions.append(
                {
                    "ID_PERTANYAAN": question_id,
                    "ID_SURVEI": spec["id"],
                    "NOMOR_URUT": q_number,
                    "TEKS_PERTANYAAN": text,
                    "JENIS_JAWABAN": "Skala Likert" if kind == "likert" else "Pilihan Tunggal",
                }
            )
            labels = LIKERT if kind == "likert" else [label for label, _ in choices]
            for o_number, label in enumerate(labels, start=1):
                options.append(
                    {
                        "ID_OPSI": f"OPS-{util.pad(number, 2)}{util.pad(q_number, 2)}{util.pad(o_number, 2)}",
                        "ID_PERTANYAAN": question_id,
                        "NOMOR_URUT": o_number,
                        "KATEGORI_JAWABAN": label,
                        "NILAI_SKOR": o_number if kind == "likert" else None,
                    }
                )

    # --- synthetic respondents and answers ------------------------------------
    respondents, answers = [], []
    for number, spec in enumerate(SURVEYS, start=1):
        last_day = min(spec["end"], config.AS_OF)
        for _ in range(spec["respondents"]):
            respondent_id = f"RSP-{util.pad(len(respondents) + 1, 4)}"
            filled = spec["start"] + timedelta(days=rng.randint(0, (last_day - spec["start"]).days))
            respondents.append(
                {
                    "ID_RESPONDEN": respondent_id,
                    "ID_SURVEI": spec["id"],
                    "KELOMPOK_USIA": rng.weighted(AGE_GROUPS),
                    "ID_WILAYAH": rng.choice(region_ids),
                    "TANGGAL_PENGISIAN": filled,
                }
            )
            for q_number, (kind, _, choices) in enumerate(spec["questions"], start=1):
                if rng.chance(0.04):  # a skipped question has no answer row
                    continue
                weights = choices if kind == "likert" else [weight for _, weight in choices]
                chosen = rng.weighted(list(enumerate(weights, start=1)))
                answers.append(
                    {
                        "ID_JAWABAN": f"JWB-{util.pad(len(answers) + 1, 5)}",
                        "ID_RESPONDEN": respondent_id,
                        "ID_PERTANYAAN": f"PRT-{util.pad(number, 2)}{util.pad(q_number, 2)}",
                        "ID_OPSI": f"OPS-{util.pad(number, 2)}{util.pad(q_number, 2)}{util.pad(chosen, 2)}",
                    }
                )

    # --- aggregated results -----------------------------------------------------
    counts = {}
    totals = {}
    for answer in answers:
        counts[answer["ID_OPSI"]] = counts.get(answer["ID_OPSI"], 0) + 1
        totals[answer["ID_PERTANYAAN"]] = totals.get(answer["ID_PERTANYAAN"], 0) + 1
    survey_of_question = {q["ID_PERTANYAAN"]: q["ID_SURVEI"] for q in questions}
    spec_by_id = {s["id"]: s for s in SURVEYS}
    aggregates = []
    for option in options:
        question_id = option["ID_PERTANYAAN"]
        survey_id = survey_of_question[question_id]
        spec = spec_by_id[survey_id]
        if spec["respondents"] == 0:
            continue  # a survey without responses has nothing to aggregate
        count = counts.get(option["ID_OPSI"], 0)
        total = totals[question_id]
        hundredths = (count * 20000 + total) // (2 * total)  # round half up
        computed_on = config.AS_OF if spec["status"] == "Sedang Berjalan" else min(config.AS_OF, spec["end"] + timedelta(days=7))
        aggregates.append(
            {
                "ID_HASIL": "HSL-" + option["ID_OPSI"].split("-")[1],
                "ID_SURVEI": survey_id,
                "ID_PERTANYAAN": question_id,
                "ID_OPSI": option["ID_OPSI"],
                "JUMLAH_RESPONDEN": count,
                "TOTAL_RESPONDEN_PERTANYAAN": total,
                "PERSENTASE_JAWABAN": Decimal(hundredths).scaleb(-2),
                "TANGGAL_AGREGASI": computed_on,
            }
        )

    return {
        f"{SCHEMA_M}.SURVEI": surveys,
        f"{SCHEMA_M}.PERTANYAAN_SURVEI": questions,
        f"{SCHEMA_M}.OPSI_JAWABAN_SURVEI": options,
        f"{SCHEMA_O}.RESPONDEN_SURVEI": respondents,
        f"{SCHEMA_O}.JAWABAN_SURVEI": answers,
        f"{SCHEMA_O}.HASIL_SURVEI_AGREGAT": aggregates,
    }
