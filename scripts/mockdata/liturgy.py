"""Domains 4.1, 4.2 and 4.5: Mass schedule rules, Mass occurrences, attendance
and offertory collections. ID_KEJADIAN_MISA is the shared key."""

from datetime import date, datetime, time, timedelta

from . import config, util
from .rng import Rng

CHURCH, CHAPEL = config.CHURCH_NAME, config.CHAPEL_NAME
CAPACITY = {CHURCH: 220, CHAPEL: 40}

# id, name, weekday (Monday = 0), start, end, place, language, valid from,
# valid to (None = open ended), note, typical attendance
RULES = [
    ("JDW-01", "Misa Sabtu Sore", 5, (17, 0), (18, 15), CHURCH, "Bahasa Indonesia",
     date(2018, 1, 1), date(2026, 6, 30), "Digantikan oleh jadwal pukul 17.30 mulai 1 Juli 2026.", 54),
    ("JDW-02", "Misa Sabtu Sore", 5, (17, 30), (18, 45), CHURCH, "Bahasa Indonesia",
     date(2026, 7, 1), None, "Menggantikan jadwal pukul 17.00.", 56),
    ("JDW-03", "Misa Minggu Pagi I", 6, (6, 0), (7, 15), CHURCH, "Bahasa Indonesia",
     date(2018, 1, 1), None, None, 62),
    ("JDW-04", "Misa Minggu Pagi II", 6, (8, 0), (9, 15), CHURCH, "Bahasa Indonesia",
     date(2018, 1, 1), None, "Misa keluarga dengan petugas anak-anak.", 96),
    ("JDW-05", "Misa Minggu Bahasa Inggris", 6, (10, 30), (11, 30), CHURCH, "Bahasa Inggris",
     date(2022, 3, 6), None, None, 30),
    ("JDW-06", "Misa Minggu Sore", 6, (17, 30), (18, 45), CHURCH, "Bahasa Indonesia",
     date(2018, 1, 1), None, None, 60),
    ("JDW-07", "Misa Harian Rabu", 2, (5, 30), (6, 15), CHAPEL, "Bahasa Indonesia",
     date(2018, 1, 1), None, None, 14),
]

# date -> (note, attendance factor). Liturgical dates of 2026.
SPECIAL_DAYS = {
    date(2026, 4, 4): ("Malam Paskah (Sabtu Suci).", 1.7),
    date(2026, 4, 5): ("Hari Raya Paskah.", 1.8),
    date(2026, 5, 24): ("Hari Raya Pentakosta.", 1.15),
    date(2026, 6, 7): ("Hari Raya Tubuh dan Darah Kristus.", 1.1),
    date(2026, 8, 15): ("Hari Raya Santa Perawan Maria Diangkat ke Surga.", 1.2),
}
# Sundays with an additional special collection.
SPECIAL_COLLECTIONS = {
    date(2026, 4, 26): "Kolekte khusus Hari Minggu Panggilan.",
    date(2026, 5, 17): "Kolekte khusus Hari Komunikasi Sosial Sedunia.",
}
CANCEL_REASONS = [
    "Dibatalkan karena imam bertugas di luar paroki.",
    "Dibatalkan karena hujan deras dan genangan air di halaman gereja.",
    "Dibatalkan karena pemadaman listrik pada pagi hari.",
]

SCHEMA_M, SCHEMA_O = "MASTER_DATA", "DATA_OPERASIONAL"


def _rule_active(rule, day):
    return rule[7] <= day and (rule[8] is None or day <= rule[8])


def build():
    rng = Rng(config.SEED, "liturgy")

    schedule = []
    for rid, name, weekday, start, end, place, language, valid_from, valid_to, note, _ in RULES:
        schedule.append(
            {
                "ID_JADWAL_MISA": rid,
                "NAMA_MISA": name,
                "HARI": util.DAYS_ID[weekday],
                "WAKTU_MULAI": time(*start),
                "WAKTU_SELESAI": time(*end),
                "LOKASI": place,
                "BAHASA_MISA": language,
                "STATUS_AKTIF": valid_to is None,
                "TANGGAL_MULAI_BERLAKU": valid_from,
                "TANGGAL_AKHIR_BERLAKU": valid_to,
                "KETERANGAN": note,
            }
        )

    occurrences, attendance, collections = [], [], []
    for day in util.daterange(config.MASS_START, config.MASS_END):
        for rule in RULES:
            if rule[2] != day.weekday() or not _rule_active(rule, day):
                continue
            rid, name, _, start, end, place, _, _, _, _, typical = rule
            number = len(occurrences) + 1
            occ_id = f"MIS-{util.pad(number, 6)}"
            special_note, special_factor = SPECIAL_DAYS.get(day, (None, 1.0))

            if day > config.AS_OF:
                status = "Terjadwal"
            elif special_note is None and rng.chance(0.06 if rid == "JDW-07" else 0.022):
                status = "Dibatalkan"
            else:
                status = "Terlaksana"

            notes = [special_note] if special_note else []
            started = ended = None
            if status == "Terlaksana":
                delay = rng.weighted([(0, 35), (1, 15), (2, 15), (3, 10), (5, 10), (8, 5), (10, 3)])
                planned_length = (end[0] * 60 + end[1]) - (start[0] * 60 + start[1])
                length = max(30, planned_length + rng.randint(-5, 12))
                started_dt = datetime.combine(day, time(*start)) + timedelta(minutes=delay)
                ended_dt = started_dt + timedelta(minutes=length)
                started, ended = started_dt.time(), ended_dt.time()
            elif status == "Dibatalkan":
                notes.append(rng.choice(CANCEL_REASONS))

            occurrences.append(
                {
                    "ID_KEJADIAN_MISA": occ_id,
                    "ID_JADWAL_MISA": rid,
                    "TANGGAL_MISA": day,
                    "WAKTU_MULAI_AKTUAL": started,
                    "WAKTU_SELESAI_AKTUAL": ended,
                    "STATUS_PELAKSANAAN": status,
                    "KETERANGAN": " ".join(notes) if notes else None,
                }
            )
            if status != "Terlaksana":
                continue

            # --- attendance -------------------------------------------------
            holiday = 0.85 if date(2026, 6, 20) <= day <= date(2026, 7, 12) else 1.0
            rainy = rng.chance(0.04)
            rain_factor = 0.8 if rainy else 1.0
            count = typical * holiday * special_factor * rain_factor * (1 + rng.normal(0, 0.07))
            count = max(5, min(CAPACITY[place], int(count + 0.5)))

            recent = day >= date(2026, 9, 1)
            validation = rng.weighted(
                [("Sudah Divalidasi", 62), ("Menunggu Validasi", 33), ("Perlu Dicek Ulang", 5)]
                if recent
                else [("Sudah Divalidasi", 92), ("Menunggu Validasi", 5), ("Perlu Dicek Ulang", 3)]
            )
            method = (
                "Hitung Manual oleh Petugas"
                if place == CHAPEL
                else rng.weighted(
                    [("Hitung Manual oleh Petugas", 55), ("Penghitung Klik", 35), ("Perkiraan Petugas Tata Tertib", 10)]
                )
            )
            att_notes = list(notes)
            if rainy:
                att_notes.append("Hujan deras sejak pagi, jumlah umat berkurang.")
            if validation == "Perlu Dicek Ulang":
                att_notes.append("Angka berbeda jauh dari pekan sebelumnya dan perlu dicek ulang petugas.")
            recorded_at = datetime.combine(day, ended) + timedelta(minutes=rng.randint(5, 60))
            attendance.append(
                {
                    "ID_KEHADIRAN": f"KHD-{util.pad(len(attendance) + 1, 6)}",
                    "ID_KEJADIAN_MISA": occ_id,
                    "JUMLAH_UMAT": count,
                    "METODE_PENGHITUNGAN": method,
                    "STATUS_VALIDASI": validation,
                    "WAKTU_PENCATATAN": recorded_at,
                    "KETERANGAN": " ".join(att_notes) if att_notes else None,
                }
            )

            # --- offertory --------------------------------------------------
            types = [("KOL-01", 14500, 1800)]
            if place != CHAPEL:
                types.append(("KOL-02", 6200, 900))
            if day in SPECIAL_COLLECTIONS and rule[2] == 6:
                types.append(("KOL-03", 8500, 1500))
            for type_id, mean, deviation in types:
                recorded = max(50000, util.round_to(count * rng.normal(mean, deviation), 500))
                too_recent = day > config.AS_OF - timedelta(days=2)
                weights = (
                    [("Sudah Cocok", 55), ("Selisih Disetujui", 5), ("Selisih Sedang Ditelusuri", 10), ("Belum Dihitung", 30)]
                    if recent
                    else [("Sudah Cocok", 84), ("Selisih Disetujui", 7), ("Selisih Sedang Ditelusuri", 4), ("Belum Dihitung", 5)]
                )
                state = "Belum Dihitung" if too_recent else rng.weighted(weights)
                counted, note = recorded, None
                if state == "Selisih Disetujui":
                    delta = max(500, util.round_to(recorded * rng.random() * 0.008, 500))
                    counted = recorded + (delta if rng.chance(0.5) else -delta)
                    note = "Selisih kecil karena uang receh dan pembulatan, sudah disetujui bendahara."
                elif state == "Selisih Sedang Ditelusuri":
                    delta = max(1000, util.round_to(recorded * (0.02 + rng.random() * 0.04), 500))
                    counted = recorded + (delta if rng.chance(0.5) else -delta)
                    note = "Selisih sedang ditelusuri bersama petugas penghitung."
                elif state == "Belum Dihitung":
                    counted = None
                    note = "Menunggu penghitungan oleh tim penghitung kolekte."
                if type_id == "KOL-03" and day in SPECIAL_COLLECTIONS:
                    note = f"{SPECIAL_COLLECTIONS[day]} {note}" if note else SPECIAL_COLLECTIONS[day]
                booked = day if state == "Belum Dihitung" else min(config.AS_OF, day + timedelta(days=rng.randint(1, 2)))
                collections.append(
                    {
                        "ID_KOLEKTE": f"KLK-{util.pad(len(collections) + 1, 6)}",
                        "ID_KEJADIAN_MISA": occ_id,
                        "ID_JENIS_KOLEKTE": type_id,
                        "JUMLAH_PENERIMAAN": recorded,
                        "JUMLAH_HASIL_PENGHITUNGAN": counted,
                        "STATUS_REKONSILIASI": state,
                        "TANGGAL_PENCATATAN": booked,
                        "KETERANGAN": note,
                    }
                )

    return {
        f"{SCHEMA_M}.JADWAL_MISA": schedule,
        f"{SCHEMA_O}.KEJADIAN_MISA": occurrences,
        f"{SCHEMA_O}.KEHADIRAN_MISA": attendance,
        f"{SCHEMA_O}.PENERIMAAN_KOLEKTE": collections,
    }
