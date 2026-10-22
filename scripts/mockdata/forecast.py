"""Shadow forecast of the weekly offertory.

A "shadow" forecast runs next to the real process and never changes it. Here, a
simple model forecasts the offertory of every week four weeks before the week
starts, using only what was known on that day. The forecasts are stored as they
were issued (table PERKIRAAN_KOLEKTE_MINGGUAN), so they can later be set against
the offertory that was actually collected.

What the model knows on the day it forecasts (the "origin"):

* the offertory of every complete week before the origin (a rolling window of the
  last 52 weeks, at least 26 weeks needed);
* the liturgical calendar, which is public: feast days and special collections of
  the target week. The size of their effect is a rule of thumb from the parish
  staff (FEAST_RULE_OF_THUMB), deliberately a little different from the true
  effect in the generator;
* the unforeseen events that were already logged before the origin. The weeks
  they disturbed are left out of the training window, so a past disaster does
  not pull later forecasts down.

What it cannot know: an event that starts after the origin. That is the point of
the exercise: a flood or volcanic ash in the target week shows up as a large gap
between forecast and actual, and the event log explains it.

Method, in plain terms: a straight line over time plus a bonus for the Sundays
right after salary day, fitted by least squares on the normal weeks of the window,
then multiplied by the calendar adjustment of the target week. The 80% range is
the typical relative error of the fit, widened by 20% because forecasts are made
a month ahead and not within the window.

No look-ahead: forecast_week() receives the full history but only reads weeks
before the origin. tests/test_generator.py proves it by changing every later week.

Only plain arithmetic and sqrt are used (no exp/log), so the output is identical
on every platform and Python version, like the rest of the generator.
"""

from datetime import timedelta
from decimal import Decimal
from math import sqrt

from . import config, liturgy, util

SCHEMA_M, SCHEMA_O = "MASTER_DATA", "DATA_OPERASIONAL"

MODEL_ID = "MDL-01"
MODEL_NAME = "Garis tren dengan kalender liturgi dan hari gajian"
HORIZON_WEEKS = 4
HORIZON_DAYS = 7 * HORIZON_WEEKS
MIN_HISTORY_WEEKS = 26
TRAINING_WEEKS = 52
RANGE_PERCENT = 80
RANGE_Z = 1.2816  # two-sided 80% under a normal approximation
RANGE_INFLATION = 1.2
MIN_SIGMA = 0.04  # relative; keeps the range from collapsing in very quiet stretches
ROUND_TO = 1000  # rupiah: a forecast does not need to look more exact than it is

# Rule of thumb of the staff: how much bigger the crowd is on these days (1.2 = 20% more).
# Close to, but not equal to, the factors the generator really used.
FEAST_RULE_OF_THUMB = {
    "Minggu Palma.": 1.2,
    "Malam Paskah (Sabtu Suci).": 1.6,
    "Hari Raya Paskah.": 1.7,
    "Hari Raya Pentakosta.": 1.1,
    "Hari Raya Tubuh dan Darah Kristus.": 1.1,
    "Hari Raya Santa Perawan Maria Diangkat ke Surga.": 1.15,
    "Hari Raya Semua Orang Kudus.": 1.1,
}
SPECIAL_COLLECTION_UPLIFT = 0.35  # extra share of the day's offertory for a special collection
MASS_WEEKDAYS = (2, 5, 6)  # Wednesday, Saturday, Sunday


def _monday(day):
    return day - timedelta(days=day.weekday())


def _sunday_of_month(week):
    """Day of the month of the Sunday that ends the week. Payday effect: early in the month is higher."""
    return (week + timedelta(days=6)).day


def complete_weeks(first_week):
    """Mondays from first_week whose Sunday is on or before the snapshot date."""
    weeks, week = [], first_week
    while week + timedelta(days=6) <= config.AS_OF:
        weeks.append(week)
        week += timedelta(days=7)
    return weeks


def weekly_history(data):
    """(offertory per week, offertory per day, week -> event id) of the Masses that were held.
    Mirrors ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA, but kept per day as well for the weekday shares."""
    masses = {m["ID_KEJADIAN_MISA"]: m for m in data[f"{SCHEMA_O}.KEJADIAN_MISA"]}
    attendance = {a["ID_KEJADIAN_MISA"]: a for a in data[f"{SCHEMA_O}.KEHADIRAN_MISA"]}
    per_mass = {}
    for c in data[f"{SCHEMA_O}.PENERIMAAN_KOLEKTE"]:
        counted = c["JUMLAH_HASIL_PENGHITUNGAN"]
        per_mass[c["ID_KEJADIAN_MISA"]] = per_mass.get(c["ID_KEJADIAN_MISA"], 0) + (
            counted if counted is not None else c["JUMLAH_PENERIMAAN"])
    weekly, daily, event_week = {}, {}, {}
    for mass_id, total in per_mass.items():
        mass = masses[mass_id]
        if mass["STATUS_PELAKSANAAN"] != "Terlaksana":
            continue
        day = mass["TANGGAL_MISA"]
        week = _monday(day)
        weekly[week] = weekly.get(week, 0) + total
        daily[day] = daily.get(day, 0) + total
        event_id = attendance[mass_id]["ID_PERISTIWA"]
        if event_id is not None:
            event_week[week] = event_id if week not in event_week else min(event_week[week], event_id)
    return weekly, daily, event_week


def calendar_effects(first_year, last_year):
    """week -> list of (date, extra share, label): what the liturgical calendar adds to a week."""
    effects = {}
    for year in range(first_year, last_year + 1):
        for day, (note, _true_factor) in liturgy.special_days(year).items():
            if day.weekday() in MASS_WEEKDAYS:
                effects.setdefault(_monday(day), []).append((day, FEAST_RULE_OF_THUMB[note] - 1, note.rstrip(".")))
        for day, note in liturgy.special_collections(year).items():
            effects.setdefault(_monday(day), []).append((day, SPECIAL_COLLECTION_UPLIFT, note.rstrip(".")))
    return effects


def _solve3(matrix, vector):
    """Gaussian elimination with partial pivoting for a 3x3 system."""
    rows = [list(matrix[i]) + [vector[i]] for i in range(3)]
    for col in range(3):
        pivot = max(range(col, 3), key=lambda r: abs(rows[r][col]))
        rows[col], rows[pivot] = rows[pivot], rows[col]
        for r in range(col + 1, 3):
            factor = rows[r][col] / rows[col][col]
            for k in range(col, 4):
                rows[r][k] -= factor * rows[col][k]
    solution = [0.0, 0.0, 0.0]
    for r in (2, 1, 0):
        solution[r] = (rows[r][3] - sum(rows[r][k] * solution[k] for k in range(r + 1, 3))) / rows[r][r]
    return solution


def fit(window, weekly, daily, event_week, effects):
    """Fit the model on the weeks of the window. Returns (predict(week) -> rupiah, relative sigma,
    weekday shares, weeks used)."""
    train = [w for w in window if w not in effects and w not in event_week]
    start = window[0]
    rows = [(1.0, (w - start).days / 7.0, float(_sunday_of_month(w))) for w in train]
    y = [float(weekly[w]) for w in train]
    gram = [[sum(r[i] * r[j] for r in rows) for j in range(3)] for i in range(3)]
    moment = [sum(r[i] * v for r, v in zip(rows, y)) for i in range(3)]
    a, slope, payday = _solve3(gram, moment)

    def predict(week):
        return a + slope * ((week - start).days / 7.0) + payday * _sunday_of_month(week)

    residuals = [weekly[w] / predict(w) - 1 for w in train]
    sigma = max(MIN_SIGMA, sqrt(sum(r * r for r in residuals) / len(residuals))) * RANGE_INFLATION
    per_weekday, total = [0.0] * 7, 0.0
    for w in train:
        for i in range(7):
            per_weekday[i] += daily.get(w + timedelta(days=i), 0)
        total += weekly[w]
    return predict, sigma, [x / total for x in per_weekday], len(train)


def forecast_week(target, weekly, daily, event_week, effects):
    """Forecast one target week as it would have been made on the origin date, or None when the
    history before the origin is too short. Reads only weeks strictly before the origin."""
    origin = target - timedelta(days=HORIZON_DAYS)
    history = sorted(w for w in weekly if w < origin)  # a Monday before the origin is a week that ended before it
    if len(history) < MIN_HISTORY_WEEKS:
        return None
    window = history[-TRAINING_WEEKS:]
    predict, sigma, shares, used = fit(window, weekly, daily, event_week, effects)
    multiplier = 1.0
    notes = []
    for day, extra, label in effects.get(target, []):
        multiplier += shares[day.weekday()] * extra
        notes.append(label)
    point = predict(target) * multiplier
    low, high = point * (1 - RANGE_Z * sigma), point * (1 + RANGE_Z * sigma)
    return {
        "origin": origin,
        "used": used,
        "point": util.round_to(point, ROUND_TO),
        "low": max(0, util.round_to(low, ROUND_TO)),
        "high": util.round_to(high, ROUND_TO),
        "multiplier": Decimal(int(multiplier * 1000 + 0.5)) / 1000,
        "notes": notes,
    }


def inputs(data):
    """Everything the forecast may learn from: complete weeks only (the first week is cut off by the
    start date and the last one may still be running), the same weeks the views compare."""
    weekly, daily, event_week = weekly_history(data)
    first_week = config.HISTORY_START + timedelta(days=(7 - config.HISTORY_START.weekday()) % 7)
    complete = set(complete_weeks(first_week))
    weekly = {w: v for w, v in weekly.items() if w in complete}
    effects = calendar_effects(config.HISTORY_START.year, config.AS_OF.year + 1)
    return first_week, weekly, daily, event_week, effects


def build(data):
    first_week, weekly, daily, event_week, effects = inputs(data)
    rows, number = [], 0
    target = first_week
    while target - timedelta(days=HORIZON_DAYS) <= config.AS_OF:
        result = forecast_week(target, weekly, daily, event_week, effects)
        if result is not None:
            number += 1
            note = None
            if result["notes"]:
                note = "Disesuaikan menurut kalender liturgi: " + ", ".join(result["notes"]) + "."
            rows.append({
                "ID_PERKIRAAN": f"PKR-{util.pad(number, 4)}",
                "ID_MODEL": MODEL_ID,
                "AWAL_PEKAN_SASARAN": target,
                "TANGGAL_PERKIRAAN": result["origin"],
                "JUMLAH_PEKAN_PELATIHAN": result["used"],
                "JUMLAH_PERKIRAAN": result["point"],
                "BATAS_BAWAH": result["low"],
                "BATAS_ATAS": result["high"],
                "PENYESUAIAN_KALENDER": result["multiplier"],
                "KETERANGAN": note,
            })
        target += timedelta(days=7)

    model = [{
        "ID_MODEL": MODEL_ID,
        "NAMA_MODEL": MODEL_NAME,
        "DESKRIPSI_METODE": (
            "Perkiraan kolekte satu pekan (Senin sampai Minggu) yang dibuat empat pekan sebelum pekan itu dimulai. "
            "Dasarnya garis tren dari 52 pekan terakhir yang tidak terganggu, kenaikan pada pekan yang berakhir "
            "pada awal bulan (setelah hari gajian), dan penyesuaian untuk hari raya dan kolekte khusus menurut "
            "kalender liturgi. Pekan yang sudah tercatat terganggu peristiwa luar biasa tidak dipakai untuk belajar. "
            "Model tidak mengetahui peristiwa yang belum terjadi, sehingga peristiwa luar biasa tampak sebagai "
            "selisih besar antara perkiraan dan kolekte sebenarnya."),
        "HORIZON_HARI": HORIZON_DAYS,
        "MINIMAL_RIWAYAT_MINGGU": MIN_HISTORY_WEEKS,
        "JENDELA_PELATIHAN_MINGGU": TRAINING_WEEKS,
        "LEBAR_RENTANG_PERSEN": RANGE_PERCENT,
        "STATUS_AKTIF": True,
    }]
    return {f"{SCHEMA_M}.REFERENSI_MODEL_PERKIRAAN": model, f"{SCHEMA_O}.PERKIRAAN_KOLEKTE_MINGGUAN": rows}
