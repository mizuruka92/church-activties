"""Domains 4.1, 4.2 and 4.5: Mass schedule rules, Mass occurrences, attendance
and offertory collections. ID_KEJADIAN_MISA is the shared key.

The history runs from 2021-01-01 to the snapshot date. The offertory is built so
that the analysis use cases have something real to find:

* amount = attendance x amount per attendee x a payday factor
* the payday factor falls linearly from +20% on the 1st of the month to -20% on
  the 31st (people give more right after salary day)
* attendance and the amount per attendee both grow, but ever more slowly, so
  the year-on-year growth of the offertory shrinks towards zero
* floods, haze and volcanic ash (see peristiwa.py) lower attendance for a few
  weeks. Attendance records carry a note and a link to the event, but the size
  of the effect is not stored anywhere.

Only plain arithmetic is used (no exp/log), so output is identical on every
platform and Python version.
"""

from datetime import date, datetime, time, timedelta

from . import config, peristiwa, util
from .rng import Rng

CHURCH, CHAPEL = config.CHURCH_NAME, config.CHAPEL_NAME
CAPACITY = {CHURCH: 220, CHAPEL: 40}

# id, name, weekday (Monday = 0), start, end, place, language, valid from,
# valid to (None = open ended), note, typical attendance in 2026
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
     date(2019, 1, 6), None, None, 30),
    ("JDW-06", "Misa Minggu Sore", 6, (17, 30), (18, 45), CHURCH, "Bahasa Indonesia",
     date(2018, 1, 1), None, None, 60),
    ("JDW-07", "Misa Harian Rabu", 2, (5, 30), (6, 15), CHAPEL, "Bahasa Indonesia",
     date(2018, 1, 1), None, None, 14),
]

# Size of attendance and of the amount per attendee on 1 January of each year,
# relative to 2026 (1.0). Their product grows by about 8%, 4.8%, 2.6%, 1.0% and 0.4% in
# successive years: growth that is clearly, steadily slowing.
ATTENDANCE_KNOTS = {2021: 0.8979, 2022: 0.9446, 2023: 0.9706, 2024: 0.9901, 2025: 0.9960, 2026: 1.0, 2027: 1.0}
PER_ATTENDEE_KNOTS = ATTENDANCE_KNOTS

# Mean amount per attendee (rupiah) in 2026 at the monthly average, by collection type.
PER_ATTENDEE_MEAN = {"KOL-01": 12750, "KOL-02": 5450, "KOL-03": 7450}

CANCEL_REASONS = [
    "Dibatalkan karena imam bertugas di luar paroki.",
    "Dibatalkan karena hujan deras dan genangan air di halaman gereja.",
    "Dibatalkan karena pemadaman listrik pada pagi hari.",
]

SCHEMA_M, SCHEMA_O = "MASTER_DATA", "DATA_OPERASIONAL"


def easter(year):
    """Gregorian Easter Sunday (Meeus/Jones/Butcher, integer arithmetic only)."""
    a = year % 19
    b, c = divmod(year, 100)
    d, e = divmod(b, 4)
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i, k = divmod(c, 4)
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = (h + l - 7 * m + 114) % 31 + 1
    return date(year, month, day)


def special_days(year):
    """date -> (note, attendance factor) for the liturgical dates of a year."""
    e = easter(year)
    return {
        e - timedelta(days=7): ("Minggu Palma.", 1.25),
        e - timedelta(days=1): ("Malam Paskah (Sabtu Suci).", 1.7),
        e: ("Hari Raya Paskah.", 1.8),
        e + timedelta(days=49): ("Hari Raya Pentakosta.", 1.15),
        e + timedelta(days=63): ("Hari Raya Tubuh dan Darah Kristus.", 1.1),
        date(year, 8, 15): ("Hari Raya Santa Perawan Maria Diangkat ke Surga.", 1.2),
        date(year, 11, 1): ("Hari Raya Semua Orang Kudus.", 1.15),
    }  # Christmas is left out: its Masses are extra occurrences, not part of the weekly rules


def special_collections(year):
    """Sundays with an extra special collection (date -> note)."""
    e = easter(year)
    october = date(year, 10, 1)
    first_sunday = october + timedelta(days=(6 - october.weekday()) % 7)
    return {
        e + timedelta(days=28): "Kolekte khusus Hari Minggu Panggilan.",
        e + timedelta(days=42): "Kolekte khusus Hari Komunikasi Sosial Sedunia.",
        first_sunday + timedelta(days=14): "Kolekte khusus Hari Minggu Misi Sedunia.",
    }


def level(knots, day):
    """Linear interpolation between the 1 January values of two years."""
    start = date(day.year, 1, 1)
    span = (date(day.year + 1, 1, 1) - start).days
    return knots[day.year] + (knots[day.year + 1] - knots[day.year]) * ((day - start).days / span)


def payday_factor(day):
    """1.20 on the 1st of the month, falling linearly to 0.80 on the 31st."""
    return 1.20 - 0.40 * (day.day - 1) / 30


def _rule_active(rule, day):
    return rule[7] <= day and (rule[8] is None or day <= rule[8])


def _validation_weights(age_days, recent):
    if age_days > 365:
        return [("Sudah Divalidasi", 100)]
    if age_days > 90:
        return [("Sudah Divalidasi", 97), ("Menunggu Validasi", 2), ("Perlu Dicek Ulang", 1)]
    if recent:
        return [("Sudah Divalidasi", 62), ("Menunggu Validasi", 33), ("Perlu Dicek Ulang", 5)]
    return [("Sudah Divalidasi", 92), ("Menunggu Validasi", 5), ("Perlu Dicek Ulang", 3)]


def _reconciliation_weights(age_days, recent):
    if age_days > 365:
        return [("Sudah Cocok", 90), ("Selisih Disetujui", 10)]
    if age_days > 90:
        return [("Sudah Cocok", 86), ("Selisih Disetujui", 9), ("Selisih Sedang Ditelusuri", 3), ("Belum Dihitung", 2)]
    if recent:
        return [("Sudah Cocok", 55), ("Selisih Disetujui", 5), ("Selisih Sedang Ditelusuri", 10), ("Belum Dihitung", 30)]
    return [("Sudah Cocok", 84), ("Selisih Disetujui", 7), ("Selisih Sedang Ditelusuri", 4), ("Belum Dihitung", 5)]


def build():
    rng = Rng(config.SEED, "liturgy")
    specials = {}
    collections_by_day = {}
    for year in range(config.MASS_START.year, config.MASS_END.year + 1):
        specials.update(special_days(year))
        collections_by_day.update(special_collections(year))
    recent_from = date(config.AS_OF.year, config.AS_OF.month, 1)

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
        event = peristiwa.event_on(day)
        special_note, special_factor = specials.get(day, (None, 1.0))
        age = (config.AS_OF - day).days
        recent = day >= recent_from
        for rule in RULES:
            if rule[2] != day.weekday() or not _rule_active(rule, day):
                continue
            rid, name, _, start, end, place, _, _, _, _, typical = rule
            weekday_mass = rid == "JDW-07"
            occ_id = f"MIS-{util.pad(len(occurrences) + 1, 6)}"

            cancel_reason = None
            if day > config.AS_OF:
                status = "Terjadwal"
            elif event is not None and event[5] == "Berat" and rng.chance(0.4 if weekday_mass else 0.12):
                status, cancel_reason = "Dibatalkan", f"Dibatalkan karena {event[7]}."
            elif special_note is None and rng.chance(0.06 if weekday_mass else 0.022):
                status, cancel_reason = "Dibatalkan", rng.choice(CANCEL_REASONS)
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
            elif cancel_reason:
                notes.append(cancel_reason)

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
            holiday = 0.85 if date(day.year, 6, 20) <= day <= date(day.year, 7, 12) else 1.0
            rainy = event is None and rng.chance(0.04)
            disturbance = peristiwa.ATTENDANCE_FACTOR[event[5]] if event else (0.8 if rainy else 1.0)
            count = (typical * level(ATTENDANCE_KNOTS, day) * holiday * special_factor * disturbance
                     * (1 + rng.normal(0, 0.11)))  # counting noise: about 1/sqrt(n) for 80 people
            count = max(5, min(CAPACITY[place], int(count + 0.5)))

            validation = rng.weighted(_validation_weights(age, recent))
            method = (
                "Hitung Manual oleh Petugas"
                if place == CHAPEL
                else rng.weighted(
                    [("Hitung Manual oleh Petugas", 55), ("Penghitung Klik", 35), ("Perkiraan Petugas Tata Tertib", 10)]
                )
            )
            att_notes = list(notes)
            if event is not None:
                att_notes.append(f"Kehadiran menurun karena {event[7]}.")
            elif rainy:
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
                    "ID_PERISTIWA": event[0] if event else None,
                }
            )

            # --- offertory --------------------------------------------------
            types = ["KOL-01"] if place == CHAPEL else ["KOL-01", "KOL-02"]
            if day in collections_by_day and rule[2] == 6:
                types.append("KOL-03")
            for type_id in types:
                per_attendee = (PER_ATTENDEE_MEAN[type_id] * level(PER_ATTENDEE_KNOTS, day) * payday_factor(day)
                                * (1 + rng.normal(0, 0.03)))
                recorded = max(50000, util.round_to(count * per_attendee, 500))
                too_recent = day > config.AS_OF - timedelta(days=2)
                state = "Belum Dihitung" if too_recent else rng.weighted(_reconciliation_weights(age, recent))
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
                if type_id == "KOL-03":
                    note = f"{collections_by_day[day]} {note}" if note else collections_by_day[day]
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

    data = {
        f"{SCHEMA_M}.JADWAL_MISA": schedule,
        f"{SCHEMA_O}.KEJADIAN_MISA": occurrences,
        f"{SCHEMA_O}.KEHADIRAN_MISA": attendance,
        f"{SCHEMA_O}.PENERIMAAN_KOLEKTE": collections,
    }
    data.update(peristiwa.build())
    return data
