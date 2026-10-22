"""Integrity and scenario checks on the generated data, run in Python before any
SQL is written. They mirror part of sql/06_validate_data.sql, so a problem is
caught locally and the Snowflake validation is an independent second opinion.

check_integrity() lists real defects (the data must not be written when any
exist). check_scenarios() confirms that the demo still contains the situations
that CLAUDE.md asks for: pending validation, incomplete reconciliation,
postponed events, incomplete reports, partly used budgets and so on.
"""

import re
from collections import Counter, defaultdict
from datetime import date

from . import config
from .sqlwriter import DataError, validate_rows
from .vocab import DAFTAR_NILAI, NILAI_TERKENDALI

_LONG_DIGITS = re.compile(r"\d{9,}")
_ENGLISH_WORDS = re.compile(r"\b(the|and|with|from|this|that|which|have|will|please)\b", re.IGNORECASE)
_NAME_COLUMNS = {"NAMA_FIKTIF"}
_NAME_PATTERN = re.compile(r"^[A-Za-z .'-]+$")
# Columns that legitimately hold technical text instead of Indonesian prose.
_TECHNICAL_COLUMNS = {"GEOJSON", "JENIS_GEOMETRI"}


def check_integrity(tables, data):
    problems = []
    by_name = {t.qualified: t for t in tables}

    for table in tables:
        rows = data.get(table.qualified)
        if rows is None:
            problems.append(f"{table.qualified}: no data generated")
            continue
        if not rows:
            problems.append(f"{table.qualified}: table is empty")
        try:
            validate_rows(table, rows)
        except DataError as error:
            problems.append(str(error))
            continue

        keys = [table.primary_key] + [columns for _, columns in table.unique_keys]
        for columns in keys:
            seen = set()
            for row in rows:
                value = tuple(row[c] for c in columns)
                if any(v is None for v in value):
                    continue  # unique keys may contain NULLs
                if value in seen:
                    problems.append(f"{table.qualified}: duplicate key {columns} = {value}")
                seen.add(value)

        for column in table.columns:
            if column.base_type == "NUMBER":  # no numeric column of this model may be negative
                for row in rows:
                    if row[column.name] is not None and row[column.name] < 0:
                        problems.append(f"{table.qualified}.{column.name}: negative amount {row[column.name]}")
            if column.base_type == "VARCHAR" and column.name not in _TECHNICAL_COLUMNS:
                for row in rows:
                    value = row[column.name]
                    if value is None:
                        continue
                    if "@" in value or _LONG_DIGITS.search(value):
                        problems.append(f"{table.qualified}.{column.name}: looks like an email or long number: {value[:40]}")
                    if _ENGLISH_WORDS.search(value):
                        problems.append(f"{table.qualified}.{column.name}: English text in business data: {value[:60]}")
                    if column.name in _NAME_COLUMNS and not _NAME_PATTERN.match(value):
                        problems.append(f"{table.qualified}.{column.name}: unexpected characters in name: {value}")

    # Foreign keys.
    for table in tables:
        for fk in table.foreign_keys:
            parent = by_name[f"{fk.ref_schema}.{fk.ref_table}"]
            parent_keys = {tuple(row[c] for c in fk.ref_columns) for row in data[parent.qualified]}
            for row in data[table.qualified]:
                value = tuple(row[c] for c in fk.columns)
                if any(v is None for v in value):
                    continue
                if value not in parent_keys:
                    problems.append(f"{table.qualified}: orphan {fk.name} {value}")

    # Controlled vocabularies.
    for qualified, column, group in NILAI_TERKENDALI:
        allowed = {value for value, _ in DAFTAR_NILAI[group]}
        for row in data[qualified]:
            if row[column] not in allowed:
                problems.append(f"{qualified}.{column}: {row[column]!r} is not in vocabulary {group}")

    problems += _check_masses(data)
    problems += _check_donations(data)
    problems += _check_parishioners(data)
    problems += _check_planning(data)
    problems += _check_surveys(data)
    return problems


def _check_masses(data):
    problems = []
    rules = {r["ID_JADWAL_MISA"]: r for r in data["MASTER_DATA.JADWAL_MISA"]}
    occurrences = {o["ID_KEJADIAN_MISA"]: o for o in data["DATA_OPERASIONAL.KEJADIAN_MISA"]}
    from .util import DAYS_ID

    for occ in occurrences.values():
        rule = rules[occ["ID_JADWAL_MISA"]]
        day = occ["TANGGAL_MISA"]
        if DAYS_ID[day.weekday()] != rule["HARI"]:
            problems.append(f"{occ['ID_KEJADIAN_MISA']}: date {day} is not a {rule['HARI']}")
        if day < rule["TANGGAL_MULAI_BERLAKU"] or (rule["TANGGAL_AKHIR_BERLAKU"] and day > rule["TANGGAL_AKHIR_BERLAKU"]):
            problems.append(f"{occ['ID_KEJADIAN_MISA']}: date outside schedule validity")
        held = occ["STATUS_PELAKSANAAN"] == "Terlaksana"
        if held != (occ["WAKTU_MULAI_AKTUAL"] is not None) or held != (occ["WAKTU_SELESAI_AKTUAL"] is not None):
            problems.append(f"{occ['ID_KEJADIAN_MISA']}: actual times must exist exactly when the Mass was held")
        if held and occ["WAKTU_SELESAI_AKTUAL"] <= occ["WAKTU_MULAI_AKTUAL"]:
            problems.append(f"{occ['ID_KEJADIAN_MISA']}: end time not after start time")
        if (day > config.AS_OF) != (occ["STATUS_PELAKSANAAN"] == "Terjadwal"):
            problems.append(f"{occ['ID_KEJADIAN_MISA']}: status {occ['STATUS_PELAKSANAAN']} inconsistent with date {day}")

    events = {e["ID_PERISTIWA"]: e for e in data["DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA"]}
    ordered = sorted(events.values(), key=lambda e: e["TANGGAL_MULAI"])
    for first, second in zip(ordered, ordered[1:]):
        if second["TANGGAL_MULAI"] <= first["TANGGAL_SELESAI"]:
            problems.append(f"{second['ID_PERISTIWA']}: overlaps {first['ID_PERISTIWA']}")
    for e in events.values():
        if e["TANGGAL_SELESAI"] < e["TANGGAL_MULAI"]:
            problems.append(f"{e['ID_PERISTIWA']}: ends before it starts")
    for a in data["DATA_OPERASIONAL.KEHADIRAN_MISA"]:
        occurrence = occurrences.get(a["ID_KEJADIAN_MISA"])
        if occurrence is None:
            continue  # reported as an orphan by the foreign key check
        day = occurrence["TANGGAL_MISA"]
        linked = events.get(a["ID_PERISTIWA"]) if a["ID_PERISTIWA"] else None
        inside = [e for e in events.values() if e["TANGGAL_MULAI"] <= day <= e["TANGGAL_SELESAI"]]
        if linked is not None and not (linked["TANGGAL_MULAI"] <= day <= linked["TANGGAL_SELESAI"]):
            problems.append(f"{a['ID_KEHADIRAN']}: linked event does not cover the Mass date")
        if bool(inside) != (linked is not None):
            problems.append(f"{a['ID_KEHADIRAN']}: attendance during an event must be linked to it, and only then")

    attended = {a["ID_KEJADIAN_MISA"] for a in data["DATA_OPERASIONAL.KEHADIRAN_MISA"]}
    collected = {c["ID_KEJADIAN_MISA"] for c in data["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"]}
    for occ_id, occ in occurrences.items():
        held = occ["STATUS_PELAKSANAAN"] == "Terlaksana"
        if held != (occ_id in attended) or held != (occ_id in collected):
            problems.append(f"{occ_id}: attendance and offertory must exist exactly for held Masses")

    for c in data["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"]:
        state, recorded, counted = c["STATUS_REKONSILIASI"], c["JUMLAH_PENERIMAAN"], c["JUMLAH_HASIL_PENGHITUNGAN"]
        if (state == "Belum Dihitung") != (counted is None):
            problems.append(f"{c['ID_KOLEKTE']}: counted amount must be empty exactly when status is Belum Dihitung")
        if state == "Sudah Cocok" and counted != recorded:
            problems.append(f"{c['ID_KOLEKTE']}: Sudah Cocok but amounts differ")
        if state in ("Selisih Disetujui", "Selisih Sedang Ditelusuri") and counted == recorded:
            problems.append(f"{c['ID_KOLEKTE']}: {state} but amounts are equal")
    return problems


def _check_parishioners(data):
    problems = []
    for key in ("PENUGASAN_KELUARGA", "PENUGASAN_LINGKUNGAN"):
        for row in data[f"DATA_OPERASIONAL.{key}"]:
            end = row["TANGGAL_AKHIR_BERLAKU"]
            if end is not None and end < row["TANGGAL_MULAI_BERLAKU"]:
                problems.append(f"{key} {list(row.values())[0]}: end before start")
            if row["TANGGAL_MULAI_BERLAKU"] > config.AS_OF or (end and end > config.AS_OF):
                problems.append(f"{key} {list(row.values())[0]}: date after the as-of date")

    # No overlapping assignments per person, none per household.
    for table, subject in (("PENUGASAN_KELUARGA", "ID_UMAT"), ("PENUGASAN_LINGKUNGAN", "ID_KELUARGA")):
        grouped = defaultdict(list)
        for row in data[f"DATA_OPERASIONAL.{table}"]:
            grouped[row[subject]].append((row["TANGGAL_MULAI_BERLAKU"], row["TANGGAL_AKHIR_BERLAKU"] or date.max))
        for who, spans in grouped.items():
            spans.sort()
            for (s1, e1), (s2, e2) in zip(spans, spans[1:]):
                if s2 <= e1:
                    problems.append(f"{table}: overlapping assignments for {who}")

    persons_with_link = {r["ID_UMAT"] for r in data["DATA_OPERASIONAL.PENUGASAN_KELUARGA"]}
    families_with_link = {r["ID_KELUARGA"] for r in data["DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN"]}
    open_person = {r["ID_UMAT"] for r in data["DATA_OPERASIONAL.PENUGASAN_KELUARGA"] if r["TANGGAL_AKHIR_BERLAKU"] is None}
    for p in data["DATA_OPERASIONAL.UMAT"]:
        if p["ID_UMAT"] not in persons_with_link:
            problems.append(f"{p['ID_UMAT']}: no household assignment")
        if p["STATUS_KEANGGOTAAN"] == "Aktif" and p["ID_UMAT"] not in open_person:
            problems.append(f"{p['ID_UMAT']}: active member without a current household")
        if not 1900 <= p["TAHUN_LAHIR"] <= config.AS_OF.year:
            problems.append(f"{p['ID_UMAT']}: implausible birth year")
        if p["TANGGAL_TERDAFTAR"] < date(p["TAHUN_LAHIR"], 1, 1):
            problems.append(f"{p['ID_UMAT']}: registered before birth")
        minor = config.AS_OF.year - p["TAHUN_LAHIR"] < 17
        if minor and p["ID_KLASIFIKASI_DATA"] != "KLS-04":
            problems.append(f"{p['ID_UMAT']}: minor without the strictest classification")
        if p["ID_KLASIFIKASI_DATA"] in ("KLS-01", "KLS-02"):
            problems.append(f"{p['ID_UMAT']}: personal data classified as public or internal")
    for f in data["DATA_OPERASIONAL.KELUARGA"]:
        if f["ID_KELUARGA"] not in families_with_link:
            problems.append(f"{f['ID_KELUARGA']}: no community assignment")
    return problems


def _check_planning(data):
    problems = []
    plans = {p["ID_RENCANA"]: p for p in data["DATA_OPERASIONAL.RENCANA_KEGIATAN"]}
    headers = {h["ID_RENCANA_KERJA"]: h for h in data["DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN"]}
    events = {e["ID_KEGIATAN"]: e for e in data["DATA_OPERASIONAL.KEGIATAN"]}
    allocations = {a["ID_ALOKASI"]: a for a in data["DATA_OPERASIONAL.ALOKASI_ANGGARAN"]}
    spent_by_plan = Counter()
    for x in data["DATA_OPERASIONAL.REALISASI_PENGELUARAN"]:
        alloc = allocations[x["ID_ALOKASI"]]
        plan = plans[alloc["ID_RENCANA"]]
        spent_by_plan[alloc["ID_RENCANA"]] += x["JUMLAH_PENGELUARAN"]
        if x["TANGGAL_PENGELUARAN"] > config.AS_OF:
            problems.append(f"{x['ID_PENGELUARAN']}: expenditure after the as-of date")
        if plan["STATUS_PELAKSANAAN"] in ("Direncanakan",) or (plan["STATUS_PELAKSANAAN"] == "Dibatalkan"):
            problems.append(f"{x['ID_PENGELUARAN']}: expenditure on a plan that is {plan['STATUS_PELAKSANAAN']}")
        if x["TANGGAL_PENGELUARAN"].year != headers[plan["ID_RENCANA_KERJA"]]["TAHUN_RENCANA"]:
            problems.append(f"{x['ID_PENGELUARAN']}: expenditure outside the plan year")

    event_of_plan = {}
    for e in events.values():
        if e["TANGGAL_SELESAI"] < e["TANGGAL_MULAI"]:
            problems.append(f"{e['ID_KEGIATAN']}: end before start")
        held = e["STATUS_KEGIATAN"] == "Terlaksana"
        if held != (e["JUMLAH_PESERTA_AKTUAL"] is not None):
            problems.append(f"{e['ID_KEGIATAN']}: actual participants must exist exactly when the event was held")
        if held and e["TANGGAL_SELESAI"] > config.AS_OF:
            problems.append(f"{e['ID_KEGIATAN']}: held event ends after the as-of date")
        if e["ID_RENCANA"]:
            plan = plans[e["ID_RENCANA"]]
            event_of_plan[e["ID_RENCANA"]] = e
            if plan["STATUS_PELAKSANAAN"] != e["STATUS_KEGIATAN"]:
                problems.append(f"{e['ID_KEGIATAN']}: status differs from its plan")
            if headers[plan["ID_RENCANA_KERJA"]]["ID_SEKSI"] != e["ID_SEKSI"]:
                problems.append(f"{e['ID_KEGIATAN']}: section differs from its plan")
    for plan_id, plan in plans.items():
        if plan["STATUS_PELAKSANAAN"] == "Terlaksana" and plan_id not in event_of_plan:
            problems.append(f"{plan_id}: completed plan without an event")

    for r in data["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]:
        event = events[r["ID_KEGIATAN"]]
        if event["STATUS_KEGIATAN"] != "Terlaksana":
            problems.append(f"{r['ID_LAPORAN']}: report for an event that was not held")
        if r["TANGGAL_LAPORAN"] < event["TANGGAL_SELESAI"] or r["TANGGAL_LAPORAN"] > config.AS_OF:
            problems.append(f"{r['ID_LAPORAN']}: implausible report date")
        if r["STATUS_LAPORAN"] == "Final":
            if r["JUMLAH_PESERTA"] != event["JUMLAH_PESERTA_AKTUAL"]:
                problems.append(f"{r['ID_LAPORAN']}: final report participants differ from the event")
            if event["ID_RENCANA"] and r["REALISASI_BIAYA"] != spent_by_plan[event["ID_RENCANA"]]:
                problems.append(f"{r['ID_LAPORAN']}: final report cost differs from recorded expenditure")
            if any(r[c] is None for c in ("RINGKASAN_PELAKSANAAN", "REALISASI_BIAYA", "EVALUASI_LOGISTIK",
                                          "HASIL_KEGIATAN", "REKOMENDASI_TINDAK_LANJUT")):
                problems.append(f"{r['ID_LAPORAN']}: final report has empty fields")
    return problems


def _check_donations(data):
    problems = []
    campaigns = {c["ID_KAMPANYE"]: c for c in data["DATA_OPERASIONAL.KAMPANYE_SUMBANGAN"]}
    plans = {p["ID_RENCANA"]: p for p in data["DATA_OPERASIONAL.RENCANA_KEGIATAN"]}
    links = {}
    for link in data["DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN"]:
        links.setdefault(link["ID_KELUARGA"], []).append(link)
    region_of = {l["ID_LINGKUNGAN"]: l["ID_WILAYAH"] for l in data["MASTER_DATA.MASTER_LINGKUNGAN"]}

    for c in campaigns.values():
        if c["PERIODE_SELESAI"] < c["PERIODE_MULAI"]:
            problems.append(f"{c['ID_KAMPANYE']}: ends before it starts")
        expected = "Selesai" if c["PERIODE_SELESAI"] <= config.AS_OF else ("Berjalan" if c["PERIODE_MULAI"] <= config.AS_OF else "Direncanakan")
        if c["STATUS_KAMPANYE"] != expected:
            problems.append(f"{c['ID_KAMPANYE']}: status {c['STATUS_KAMPANYE']} but dates say {expected}")
        funded = plans.get(c["ID_RENCANA_PENGGUNAAN"]) if c["ID_RENCANA_PENGGUNAAN"] else None
        if c["ID_RENCANA_PENGGUNAAN"] and (funded is None or funded["TANGGAL_RENCANA"] < c["PERIODE_MULAI"]):
            problems.append(f"{c['ID_KAMPANYE']}: the funded activity must not start before the campaign")

    sums = {}
    for g in data["DATA_OPERASIONAL.SUMBANGAN_KELUARGA"]:
        c = campaigns[g["ID_KAMPANYE"]]
        if not c["PERIODE_MULAI"] <= g["TANGGAL_SUMBANGAN"] <= min(c["PERIODE_SELESAI"], config.AS_OF):
            problems.append(f"{g['ID_SUMBANGAN_KELUARGA']}: gift dated outside its campaign")
        covering = [l for l in links.get(g["ID_KELUARGA"], [])
                    if l["TANGGAL_MULAI_BERLAKU"] <= g["TANGGAL_SUMBANGAN"]
                    and (l["TANGGAL_AKHIR_BERLAKU"] is None or g["TANGGAL_SUMBANGAN"] <= l["TANGGAL_AKHIR_BERLAKU"])]
        if len(covering) != 1 or covering[0]["ID_LINGKUNGAN"] != g["ID_LINGKUNGAN"]:
            problems.append(f"{g['ID_SUMBANGAN_KELUARGA']}: community differs from the household assignment on that date")
        key = (g["ID_KAMPANYE"], region_of[g["ID_LINGKUNGAN"]])
        count, total = sums.get(key, (0, 0))
        sums[key] = (count + 1, total + g["JUMLAH_SUMBANGAN"])

    seen = set()
    for r in data["DATA_OPERASIONAL.SUMBANGAN_KESEMPATAN_KHUSUS"]:
        key = (r["ID_KAMPANYE"], r["ID_WILAYAH"])
        seen.add(key)
        if sums.get(key, (0, 0)) != (r["JUMLAH_KELUARGA_PESERTA"], r["JUMLAH_SUMBANGAN"]):
            problems.append(f"{r['ID_SUMBANGAN']}: regional summary differs from the household gifts")
        if r["TANGGAL_PENCATATAN"] < campaigns[r["ID_KAMPANYE"]]["PERIODE_SELESAI"]:
            problems.append(f"{r['ID_SUMBANGAN']}: recorded before the campaign ended")
    for key in sums:
        if key not in seen:
            problems.append(f"{key}: household gifts without a regional summary")
    return problems


def _check_surveys(data):
    problems = []
    options = {o["ID_OPSI"]: o for o in data["MASTER_DATA.OPSI_JAWABAN_SURVEI"]}
    questions = {q["ID_PERTANYAAN"]: q for q in data["MASTER_DATA.PERTANYAAN_SURVEI"]}
    respondents = {r["ID_RESPONDEN"]: r for r in data["DATA_OPERASIONAL.RESPONDEN_SURVEI"]}
    surveys = {s["ID_SURVEI"]: s for s in data["MASTER_DATA.SURVEI"]}
    counts, totals = Counter(), Counter()
    for a in data["DATA_OPERASIONAL.JAWABAN_SURVEI"]:
        if options[a["ID_OPSI"]]["ID_PERTANYAAN"] != a["ID_PERTANYAAN"]:
            problems.append(f"{a['ID_JAWABAN']}: option does not belong to the question")
        if questions[a["ID_PERTANYAAN"]]["ID_SURVEI"] != respondents[a["ID_RESPONDEN"]]["ID_SURVEI"]:
            problems.append(f"{a['ID_JAWABAN']}: question and respondent belong to different surveys")
        counts[a["ID_OPSI"]] += 1
        totals[a["ID_PERTANYAAN"]] += 1
    percent_per_question = defaultdict(int)
    for h in data["DATA_OPERASIONAL.HASIL_SURVEI_AGREGAT"]:
        if h["JUMLAH_RESPONDEN"] != counts[h["ID_OPSI"]] or h["TOTAL_RESPONDEN_PERTANYAAN"] != totals[h["ID_PERTANYAAN"]]:
            problems.append(f"{h['ID_HASIL']}: aggregate differs from the answers")
        if options[h["ID_OPSI"]]["ID_PERTANYAAN"] != h["ID_PERTANYAAN"] or questions[h["ID_PERTANYAAN"]]["ID_SURVEI"] != h["ID_SURVEI"]:
            problems.append(f"{h['ID_HASIL']}: inconsistent survey, question and option")
        percent_per_question[h["ID_PERTANYAAN"]] += h["PERSENTASE_JAWABAN"]
    for question_id, total in percent_per_question.items():
        if abs(total - 100) > 0.1:
            problems.append(f"{question_id}: percentages add up to {total}")
    for s in surveys.values():
        if s["TANGGAL_SELESAI"] < s["TANGGAL_MULAI"]:
            problems.append(f"{s['ID_SURVEI']}: survey ends before it starts")
    for r in respondents.values():
        s = surveys[r["ID_SURVEI"]]
        if not s["TANGGAL_MULAI"] <= r["TANGGAL_PENGISIAN"] <= min(s["TANGGAL_SELESAI"], config.AS_OF):
            problems.append(f"{r['ID_RESPONDEN']}: filled outside the survey window")
    return problems


def check_scenarios(data):
    """Return the demo situations that are missing from the data (empty = fine)."""
    gaps = []

    def need(condition, text):
        if not condition:
            gaps.append(text)

    def states(table, column):
        return Counter(row[column] for row in data[f"DATA_OPERASIONAL.{table}"])

    masses = states("KEJADIAN_MISA", "STATUS_PELAKSANAAN")
    for value in ("Terjadwal", "Terlaksana", "Dibatalkan"):
        need(masses[value] > 0, f"no Mass occurrence with status {value}")
    for value in ("Sudah Divalidasi", "Menunggu Validasi", "Perlu Dicek Ulang"):
        need(states("KEHADIRAN_MISA", "STATUS_VALIDASI")[value] > 0, f"no attendance with status {value}")
        need(states("SUMBANGAN_KESEMPATAN_KHUSUS", "STATUS_VALIDASI")[value] > 0, f"no donation with status {value}")
    for value in ("Sudah Cocok", "Selisih Disetujui", "Selisih Sedang Ditelusuri", "Belum Dihitung"):
        need(states("PENERIMAAN_KOLEKTE", "STATUS_REKONSILIASI")[value] > 0, f"no offertory with status {value}")
    need({c["ID_JENIS_KOLEKTE"] for c in data["DATA_OPERASIONAL.PENERIMAAN_KOLEKTE"]} == {"KOL-01", "KOL-02", "KOL-03"},
         "not all offertory types are used")
    for value in ("Direncanakan", "Terlaksana", "Ditunda", "Dibatalkan"):
        need(states("RENCANA_KEGIATAN", "STATUS_PELAKSANAAN")[value] > 0, f"no plan with status {value}")
        need(states("KEGIATAN", "STATUS_KEGIATAN")[value] > 0, f"no event with status {value}")
    for value in ("Final", "Draf", "Perlu Revisi"):
        need(states("LAPORAN_KEGIATAN", "STATUS_LAPORAN")[value] > 0, f"no report with status {value}")

    events = data["DATA_OPERASIONAL.KEGIATAN"]
    reported = {r["ID_KEGIATAN"] for r in data["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]}
    need(any(e["STATUS_KEGIATAN"] == "Terlaksana" and e["ID_KEGIATAN"] not in reported for e in events),
         "every completed event has a report")
    need(any(e["ID_RENCANA"] is None for e in events), "no unplanned event")
    plans_with_event = {e["ID_RENCANA"] for e in events if e["ID_RENCANA"]}
    need(any(p["ID_RENCANA"] not in plans_with_event for p in data["DATA_OPERASIONAL.RENCANA_KEGIATAN"]),
         "every plan has an event")
    need(any(r["STATUS_LAPORAN"] == "Draf" and any(r[c] is None for c in (
        "REALISASI_BIAYA", "EVALUASI_LOGISTIK", "HASIL_KEGIATAN", "REKOMENDASI_TINDAK_LANJUT"))
        for r in data["DATA_OPERASIONAL.LAPORAN_KEGIATAN"]), "no incomplete draft report")
    need(any(e["STATUS_KEGIATAN"] == "Terlaksana" and e["JUMLAH_PESERTA_AKTUAL"] < e["TARGET_PESERTA"] for e in events),
         "no event below its participant target")
    need(any(e["STATUS_KEGIATAN"] == "Terlaksana" and e["JUMLAH_PESERTA_AKTUAL"] > e["TARGET_PESERTA"] for e in events),
         "no event above its participant target")

    spent = Counter()
    for x in data["DATA_OPERASIONAL.REALISASI_PENGELUARAN"]:
        spent[x["ID_ALOKASI"]] += x["JUMLAH_PENGELUARAN"]
    allocs = data["DATA_OPERASIONAL.ALOKASI_ANGGARAN"]
    need(any(a["ID_ALOKASI"] not in spent for a in allocs), "every allocation has spending")
    need(any(0 < spent[a["ID_ALOKASI"]] < a["JUMLAH_ANGGARAN"] for a in allocs), "no partly used allocation")
    need(any(spent[a["ID_ALOKASI"]] > a["JUMLAH_ANGGARAN"] for a in allocs), "no overspent allocation")
    need(any(h["STATUS_PENGESAHAN"] == "Dalam Revisi" for h in data["DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN"]),
         "no annual plan under revision")

    families = Counter(r["ID_KELUARGA"] for r in data["DATA_OPERASIONAL.PENUGASAN_LINGKUNGAN"])
    need(any(n > 1 for n in families.values()), "no household with a community history")
    persons = Counter(r["ID_UMAT"] for r in data["DATA_OPERASIONAL.PENUGASAN_KELUARGA"])
    need(any(n > 1 for n in persons.values()), "no person who changed household")
    for value in ("Aktif", "Pindah Paroki", "Tidak Aktif", "Meninggal Dunia"):
        need(states("UMAT", "STATUS_KEANGGOTAAN")[value] > 0, f"no parishioner with status {value}")
    need(states("KELUARGA", "STATUS_KELUARGA")["Pindah Paroki"] > 0, "no household that left the parish")

    attendance = data["DATA_OPERASIONAL.KEHADIRAN_MISA"]
    need(any(a["ID_PERISTIWA"] for a in attendance), "no attendance record linked to an unforeseen event")
    need({e["JENIS_PERISTIWA"] for e in data["DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA"]}
         >= {"Hujan Deras dan Banjir", "Kabut Asap", "Abu Vulkanik"}, "the event log lacks rain, haze or volcanic ash")
    need(any(m["STATUS_PELAKSANAAN"] == "Dibatalkan" and m["KETERANGAN"] and "abu" in m["KETERANGAN"]
             for m in data["DATA_OPERASIONAL.KEJADIAN_MISA"]), "no Mass cancelled because of volcanic ash")
    need(states("KAMPANYE_SUMBANGAN", "STATUS_KAMPANYE")["Direncanakan"] > 0, "no planned campaign")
    first_year = min(m["TANGGAL_MISA"].year for m in data["DATA_OPERASIONAL.KEJADIAN_MISA"])
    need(first_year <= config.AS_OF.year - 5, "the Mass history is shorter than five years")
    need(min(h["TAHUN_RENCANA"] for h in data["DATA_OPERASIONAL.RENCANA_KERJA_TAHUNAN"]) <= config.AS_OF.year - 5,
         "the plan history is shorter than five years")

    survey_status = Counter(s["STATUS_SURVEI"] for s in data["MASTER_DATA.SURVEI"])
    for value in ("Direncanakan", "Sedang Berjalan", "Selesai"):
        need(survey_status[value] > 0, f"no survey with status {value}")
    answered = {a["ID_PERTANYAAN"] for a in data["DATA_OPERASIONAL.JAWABAN_SURVEI"]}
    need(any(q["ID_PERTANYAAN"] not in answered for q in data["MASTER_DATA.PERTANYAAN_SURVEI"]), "no unanswered question")
    return gaps
