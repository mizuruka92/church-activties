"""Builds sql/06_validate_data.sql.

The file is ONE statement that returns ONE result table, because Snowsight shows
only the result of the last statement when a worksheet is run with "Run All".

Mechanical checks (row counts, duplicate keys, orphaned references, allowed
values, negative numbers, date ranges) are derived from the DDL, so a new table
or foreign key cannot be forgotten. Business rules are written by hand below.

Rule types
    ROWS       FAIL if the table is empty, PASS if it has the bundled demo row
               count, WARN if the count differs (for example partial load).
    NONEMPTY   FAIL when the object returns no rows.
    ZERO_FAIL  FAIL when the count is above zero.
    ZERO_WARN  WARN when the count is above zero.
    INFO       Reported for interpretation only.
"""

import re

from . import config
from .vocab import NILAI_TERKENDALI

AS_OF = f"DATE '{config.AS_OF.isoformat()}'"
PLAUSIBLE_FROM, PLAUSIBLE_TO = "DATE '2000-01-01'", "DATE '2030-12-31'"
DB = "PUSAT_INFORMASI_PAROKI"

_DAY_CASE = ("CASE {col} WHEN 'Senin' THEN 0 WHEN 'Selasa' THEN 1 WHEN 'Rabu' THEN 2 WHEN 'Kamis' THEN 3 "
             "WHEN 'Jumat' THEN 4 WHEN 'Sabtu' THEN 5 WHEN 'Minggu' THEN 6 END")

M, O, A = "MASTER_DATA", "DATA_OPERASIONAL", "ANALISIS"


def _q(text):
    return text.replace("'", "''")


class Arm:
    def __init__(self, group, name, obj, count_sql, rule, note, expected=None):
        self.group, self.name, self.obj = group, name, obj
        self.count_sql, self.rule, self.note, self.expected = count_sql.strip(), rule, note, expected


def _generic_arms(tables, data):
    arms = []
    for t in tables:
        arms.append(Arm("STRUCTURE", "Row count", t.qualified, f"SELECT COUNT(*) FROM {t.qualified}", "ROWS",
                        "Row count of the bundled demo data.", expected=len(data[t.qualified])))
    for t in tables:
        keys = [("Duplicate primary key", t.primary_key)] + [(f"Duplicate unique key {n}", c) for n, c in t.unique_keys]
        for label, columns in keys:
            cols = ", ".join(columns)
            where = " AND ".join(f"{c} IS NOT NULL" for c in columns)
            arms.append(Arm("KEYS", label, t.qualified,
                            f"SELECT COUNT(*) FROM (SELECT {cols} FROM {t.qualified} WHERE {where} "
                            f"GROUP BY {cols} HAVING COUNT(*) > 1) d",
                            "ZERO_FAIL", f"Number of key values that occur more than once ({cols})."))
    for t in tables:
        for fk in t.foreign_keys:
            parent = f"{fk.ref_schema}.{fk.ref_table}"
            on = " AND ".join(f"c.{a} = p.{b}" for a, b in zip(fk.columns, fk.ref_columns))
            present = " AND ".join(f"c.{a} IS NOT NULL" for a in fk.columns)
            arms.append(Arm("REFERENCES", "Orphaned reference", f"{t.qualified}.{'+'.join(fk.columns)} -> {fk.ref_table}",
                            f"SELECT COUNT(*) FROM {t.qualified} c LEFT JOIN {parent} p ON {on} "
                            f"WHERE {present} AND p.{fk.ref_columns[0]} IS NULL",
                            "ZERO_FAIL", "Child rows whose parent row does not exist."))
    for table, column, group in NILAI_TERKENDALI:
        arms.append(Arm("VOCABULARY", f"Value not in list {group}", f"{table}.{column}",
                        f"SELECT COUNT(*) FROM {table} x LEFT JOIN {M}.REFERENSI_DAFTAR_NILAI v "
                        f"ON v.KELOMPOK_NILAI = '{group}' AND v.NILAI = x.{column} "
                        f"WHERE x.{column} IS NOT NULL AND v.NILAI IS NULL",
                        "ZERO_FAIL", "Rows using a label that is not defined in REFERENSI_DAFTAR_NILAI."))
    for t in tables:
        numbers = [c.name for c in t.columns if c.base_type == "NUMBER"]
        if numbers:
            cond = " OR ".join(f"{c} < 0" for c in numbers)
            arms.append(Arm("NUMBERS", "Negative numeric value", t.qualified,
                            f"SELECT COUNT(*) FROM {t.qualified} WHERE {cond}", "ZERO_FAIL",
                            f"Rows with a negative value in {', '.join(numbers)}."))
        dates = [c.name for c in t.columns if c.base_type == "DATE"]
        if dates:
            cond = " OR ".join(f"{c} < {PLAUSIBLE_FROM} OR {c} > {PLAUSIBLE_TO}" for c in dates)
            arms.append(Arm("DATES", "Date outside 2000-2030", t.qualified,
                            f"SELECT COUNT(*) FROM {t.qualified} WHERE {cond}", "ZERO_FAIL",
                            f"Implausible dates in {', '.join(dates)}."))
        names = t.column_names
        if "TANGGAL_MULAI_BERLAKU" in names and "TANGGAL_AKHIR_BERLAKU" in names:
            arms.append(Arm("DATES", "Effective end before start", t.qualified,
                            f"SELECT COUNT(*) FROM {t.qualified} WHERE TANGGAL_AKHIR_BERLAKU IS NOT NULL "
                            f"AND TANGGAL_AKHIR_BERLAKU < TANGGAL_MULAI_BERLAKU", "ZERO_FAIL",
                            "Rows whose end date is earlier than the start date."))
        if "STATUS_AKTIF" in names and "TANGGAL_AKHIR_BERLAKU" in names:
            arms.append(Arm("GOVERNANCE", "Active flag matches end date", t.qualified,
                            f"SELECT COUNT(*) FROM {t.qualified} WHERE (STATUS_AKTIF = TRUE AND TANGGAL_AKHIR_BERLAKU IS NOT NULL) "
                            f"OR (STATUS_AKTIF = FALSE AND TANGGAL_AKHIR_BERLAKU IS NULL)", "ZERO_FAIL",
                            "STATUS_AKTIF must be TRUE exactly when there is no end date."))
    return arms


def _business_arms(views):
    k, a, c = f"{O}.KEJADIAN_MISA", f"{O}.KEHADIRAN_MISA", f"{O}.PENERIMAAN_KOLEKTE"
    arms = []

    def add(group, name, obj, sql, rule, note):
        arms.append(Arm(group, name, obj, sql, rule, note))

    # --- Mass ---------------------------------------------------------------------
    add("MASS", "Attendance for a Mass that was not held", a,
        f"SELECT COUNT(*) FROM {a} x JOIN {k} k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE k.STATUS_PELAKSANAAN <> 'Terlaksana'",
        "ZERO_FAIL", "Attendance may only exist for occurrences with status Terlaksana.")
    add("MASS", "Offertory for a Mass that was not held", c,
        f"SELECT COUNT(*) FROM {c} x JOIN {k} k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE k.STATUS_PELAKSANAAN <> 'Terlaksana'",
        "ZERO_FAIL", "Offertory may only exist for occurrences with status Terlaksana.")
    add("MASS", "Held Mass without attendance", k,
        f"SELECT COUNT(*) FROM {k} k WHERE k.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS "
        f"(SELECT 1 FROM {a} x WHERE x.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA)",
        "ZERO_FAIL", "Every held Mass needs one attendance record.")
    add("MASS", "Held Mass without offertory", k,
        f"SELECT COUNT(*) FROM {k} k WHERE k.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS "
        f"(SELECT 1 FROM {c} x WHERE x.ID_KEJADIAN_MISA = k.ID_KEJADIAN_MISA)",
        "ZERO_FAIL", "Every held Mass needs at least one offertory record.")
    add("MASS", "Actual times inconsistent with status", k,
        f"SELECT COUNT(*) FROM {k} WHERE (STATUS_PELAKSANAAN = 'Terlaksana' AND (WAKTU_MULAI_AKTUAL IS NULL OR "
        f"WAKTU_SELESAI_AKTUAL IS NULL OR WAKTU_SELESAI_AKTUAL <= WAKTU_MULAI_AKTUAL)) OR (STATUS_PELAKSANAAN <> 'Terlaksana' "
        f"AND (WAKTU_MULAI_AKTUAL IS NOT NULL OR WAKTU_SELESAI_AKTUAL IS NOT NULL))",
        "ZERO_FAIL", "Actual times exist only for held Masses and the end must be after the start.")
    add("MASS", "Occurrence weekday differs from schedule", k,
        f"SELECT COUNT(*) FROM {k} k JOIN {M}.JADWAL_MISA j ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA "
        f"WHERE MOD(DATEDIFF('day', DATE '1900-01-01', k.TANGGAL_MISA), 7) <> {_DAY_CASE.format(col='j.HARI')}",
        "ZERO_FAIL", "The date must fall on the weekday of its schedule rule (1900-01-01 was a Monday).")
    add("MASS", "Occurrence outside schedule validity", k,
        f"SELECT COUNT(*) FROM {k} k JOIN {M}.JADWAL_MISA j ON j.ID_JADWAL_MISA = k.ID_JADWAL_MISA "
        f"WHERE k.TANGGAL_MISA < j.TANGGAL_MULAI_BERLAKU OR (j.TANGGAL_AKHIR_BERLAKU IS NOT NULL AND k.TANGGAL_MISA > j.TANGGAL_AKHIR_BERLAKU)",
        "ZERO_FAIL", "A Mass may only follow a schedule rule that was valid on that date.")
    add("MASS", "Status inconsistent with the as-of date", k,
        f"SELECT COUNT(*) FROM {k} WHERE (STATUS_PELAKSANAAN = 'Terjadwal' AND TANGGAL_MISA <= {AS_OF}) "
        f"OR (STATUS_PELAKSANAAN <> 'Terjadwal' AND TANGGAL_MISA > {AS_OF})",
        "ZERO_FAIL", f"Terjadwal only after {config.AS_OF.isoformat()} (the demo snapshot date), otherwise Terlaksana or Dibatalkan.")
    add("MASS", "No reporting period for a Mass date", k,
        f"SELECT COUNT(*) FROM {k} k WHERE NOT EXISTS (SELECT 1 FROM {M}.REFERENSI_PERIODE_PELAPORAN p "
        f"WHERE k.TANGGAL_MISA BETWEEN p.TANGGAL_MULAI AND p.TANGGAL_SELESAI)",
        "ZERO_FAIL", "The monthly views join Masses to the reporting calendar.")
    add("MASS", "Counted amount inconsistent with reconciliation status", c,
        f"SELECT COUNT(*) FROM {c} WHERE (STATUS_REKONSILIASI = 'Belum Dihitung' AND JUMLAH_HASIL_PENGHITUNGAN IS NOT NULL) "
        f"OR (STATUS_REKONSILIASI <> 'Belum Dihitung' AND JUMLAH_HASIL_PENGHITUNGAN IS NULL)",
        "ZERO_FAIL", "The counted amount is empty exactly when the status is Belum Dihitung.")
    add("MASS", "Sudah Cocok but recorded and counted differ", c,
        f"SELECT COUNT(*) FROM {c} WHERE STATUS_REKONSILIASI = 'Sudah Cocok' AND JUMLAH_PENERIMAAN <> JUMLAH_HASIL_PENGHITUNGAN",
        "ZERO_FAIL", "Matched records must have equal recorded and counted amounts.")
    add("MASS", "Selisih status but amounts are equal", c,
        f"SELECT COUNT(*) FROM {c} WHERE STATUS_REKONSILIASI IN ('Selisih Disetujui', 'Selisih Sedang Ditelusuri') "
        f"AND JUMLAH_PENERIMAAN = JUMLAH_HASIL_PENGHITUNGAN",
        "ZERO_FAIL", "A discrepancy status needs an actual discrepancy.")
    add("MASS", "Offertory booked before the Mass date", c,
        f"SELECT COUNT(*) FROM {c} x JOIN {k} k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA WHERE x.TANGGAL_PENCATATAN < k.TANGGAL_MISA",
        "ZERO_FAIL", "The booking date cannot precede the Mass.")
    add("MASS", "Offertory with open reconciliation", c,
        f"SELECT COUNT(*) FROM {c} WHERE STATUS_REKONSILIASI IN ('Selisih Sedang Ditelusuri', 'Belum Dihitung')",
        "INFO", "Deliberate demo scenario: records still being counted or investigated.")
    add("MASS", "Attendance waiting for validation or recheck", a,
        f"SELECT COUNT(*) FROM {a} WHERE STATUS_VALIDASI <> 'Sudah Divalidasi'",
        "INFO", "Deliberate demo scenario: attendance not yet validated.")
    add("MASS", "Cancelled Mass occurrences", k,
        f"SELECT COUNT(*) FROM {k} WHERE STATUS_PELAKSANAAN = 'Dibatalkan'", "INFO", "Deliberate demo scenario.")

    # --- dates that must be historical -------------------------------------------------
    add("DATES", "Expenditure after the as-of date", f"{O}.REALISASI_PENGELUARAN",
        f"SELECT COUNT(*) FROM {O}.REALISASI_PENGELUARAN WHERE TANGGAL_PENGELUARAN > {AS_OF}", "ZERO_FAIL",
        "Spending cannot be dated after the snapshot date.")
    add("DATES", "Offertory booked after the as-of date", c,
        f"SELECT COUNT(*) FROM {c} WHERE TANGGAL_PENCATATAN > {AS_OF}", "ZERO_FAIL", "Bookings cannot be in the future.")
    add("DATES", "Attendance recorded after the as-of date", a,
        f"SELECT COUNT(*) FROM {a} WHERE CAST(WAKTU_PENCATATAN AS DATE) > {AS_OF}", "ZERO_FAIL", "Records cannot be in the future.")
    add("DATES", "Birth year implausible or registration before birth", f"{O}.UMAT",
        f"SELECT COUNT(*) FROM {O}.UMAT WHERE TAHUN_LAHIR < 1900 OR TAHUN_LAHIR > {config.AS_OF.year} "
        f"OR EXTRACT(YEAR FROM TANGGAL_TERDAFTAR) < TAHUN_LAHIR", "ZERO_FAIL", "Birth years must be plausible.")
    add("DATES", "Assignment dated after the as-of date", f"{O}.PENUGASAN_KELUARGA",
        f"SELECT (SELECT COUNT(*) FROM {O}.PENUGASAN_KELUARGA WHERE TANGGAL_MULAI_BERLAKU > {AS_OF} OR TANGGAL_AKHIR_BERLAKU > {AS_OF}) "
        f"+ (SELECT COUNT(*) FROM {O}.PENUGASAN_LINGKUNGAN WHERE TANGGAL_MULAI_BERLAKU > {AS_OF} OR TANGGAL_AKHIR_BERLAKU > {AS_OF})",
        "ZERO_FAIL", "Household and community assignments in the past only (both assignment tables).")

    # --- parishioners and governance ------------------------------------------------------------
    pk, pl = f"{O}.PENUGASAN_KELUARGA", f"{O}.PENUGASAN_LINGKUNGAN"
    add("PARISHIONERS", "Person without a household assignment", f"{O}.UMAT",
        f"SELECT COUNT(*) FROM {O}.UMAT u WHERE NOT EXISTS (SELECT 1 FROM {pk} x WHERE x.ID_UMAT = u.ID_UMAT)",
        "ZERO_FAIL", "Every person must belong to at least one household over time.")
    add("PARISHIONERS", "Household without a community assignment", f"{O}.KELUARGA",
        f"SELECT COUNT(*) FROM {O}.KELUARGA f WHERE NOT EXISTS (SELECT 1 FROM {pl} x WHERE x.ID_KELUARGA = f.ID_KELUARGA)",
        "ZERO_FAIL", "Every household must belong to a community over time.")
    add("PARISHIONERS", "Overlapping household assignments of one person", pk,
        f"SELECT COUNT(*) FROM {pk} a JOIN {pk} b ON a.ID_UMAT = b.ID_UMAT AND a.ID_PENUGASAN_KELUARGA < b.ID_PENUGASAN_KELUARGA "
        f"AND a.TANGGAL_MULAI_BERLAKU <= COALESCE(b.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31') "
        f"AND b.TANGGAL_MULAI_BERLAKU <= COALESCE(a.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31')",
        "ZERO_FAIL", "A person can be in only one household at a time.")
    add("PARISHIONERS", "Overlapping community assignments of one household", pl,
        f"SELECT COUNT(*) FROM {pl} a JOIN {pl} b ON a.ID_KELUARGA = b.ID_KELUARGA AND a.ID_PENUGASAN_LINGKUNGAN < b.ID_PENUGASAN_LINGKUNGAN "
        f"AND a.TANGGAL_MULAI_BERLAKU <= COALESCE(b.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31') "
        f"AND b.TANGGAL_MULAI_BERLAKU <= COALESCE(a.TANGGAL_AKHIR_BERLAKU, DATE '9999-12-31')",
        "ZERO_FAIL", "A household can be in only one community at a time.")
    add("PARISHIONERS", "Active member without a current household", f"{O}.UMAT",
        f"SELECT COUNT(*) FROM {O}.UMAT u WHERE u.STATUS_KEANGGOTAAN = 'Aktif' AND NOT EXISTS "
        f"(SELECT 1 FROM {pk} x WHERE x.ID_UMAT = u.ID_UMAT AND x.TANGGAL_AKHIR_BERLAKU IS NULL)",
        "ZERO_FAIL", "Active members need an open household assignment.")
    add("GOVERNANCE", "Personal data not classified Terbatas or stricter", f"{O}.UMAT, {O}.KELUARGA",
        f"SELECT (SELECT COUNT(*) FROM {O}.UMAT x JOIN {M}.REFERENSI_KLASIFIKASI_DATA k ON k.ID_KLASIFIKASI_DATA = x.ID_KLASIFIKASI_DATA WHERE k.URUTAN_TINGKAT < 3) "
        f"+ (SELECT COUNT(*) FROM {O}.KELUARGA x JOIN {M}.REFERENSI_KLASIFIKASI_DATA k ON k.ID_KLASIFIKASI_DATA = x.ID_KLASIFIKASI_DATA WHERE k.URUTAN_TINGKAT < 3)",
        "ZERO_FAIL", "Identifiable personal data must be Terbatas or Sangat Terbatas.")
    add("GOVERNANCE", "Minors without the strictest classification", f"{O}.UMAT",
        f"SELECT COUNT(*) FROM {O}.UMAT WHERE {config.AS_OF.year} - TAHUN_LAHIR < 17 AND ID_KLASIFIKASI_DATA <> 'KLS-04'",
        "ZERO_FAIL", "Persons under 17 must be Sangat Terbatas (KLS-04).")
    add("GOVERNANCE", "Personal-data columns exposed in ANALISIS", A,
        "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE UPPER(TABLE_SCHEMA) = 'ANALISIS' AND UPPER(COLUMN_NAME) IN "
        "('NAMA_FIKTIF', 'NAMA_KELUARGA_FIKTIF', 'ID_UMAT', 'ID_KELUARGA', 'TAHUN_LAHIR', 'ID_RESPONDEN', 'ID_PENUGASAN_KELUARGA', 'ID_SUMBANGAN_KELUARGA')",
        "ZERO_FAIL", "Summary views must never expose names or person and household identifiers.")
    add("GOVERNANCE", "Geometry not marked synthetic", f"{M}.GEOMETRI_ILUSTRATIF_LINGKUNGAN",
        f"SELECT COUNT(*) FROM {M}.GEOMETRI_ILUSTRATIF_LINGKUNGAN WHERE BERSIFAT_SINTETIS = FALSE", "ZERO_FAIL",
        "All demo geometry must be labelled synthetic.")
    add("GOVERNANCE", "Active community without illustrative geometry", f"{M}.MASTER_LINGKUNGAN",
        f"SELECT COUNT(*) FROM {M}.MASTER_LINGKUNGAN l WHERE l.STATUS_AKTIF = TRUE AND NOT EXISTS "
        f"(SELECT 1 FROM {M}.GEOMETRI_ILUSTRATIF_LINGKUNGAN g WHERE g.ID_LINGKUNGAN = l.ID_LINGKUNGAN)",
        "ZERO_WARN", "Needed only for map demos.")
    add("PARISHIONERS", "Households with a community history", pl,
        f"SELECT COUNT(*) FROM (SELECT ID_KELUARGA FROM {pl} GROUP BY ID_KELUARGA HAVING COUNT(*) > 1) h", "INFO",
        "Deliberate demo scenario: merged or relocated communities.")

    # --- donations ---------------------------------------------------------------------------------
    camp, summ, gift = f"{O}.KAMPANYE_SUMBANGAN", f"{O}.SUMBANGAN_KESEMPATAN_KHUSUS", f"{O}.SUMBANGAN_KELUARGA"
    per_region = (f"SELECT g.ID_KAMPANYE, l.ID_WILAYAH, COUNT(*) AS JUMLAH_KELUARGA, SUM(g.JUMLAH_SUMBANGAN) AS TOTAL "
                  f"FROM {gift} g JOIN {M}.MASTER_LINGKUNGAN l ON l.ID_LINGKUNGAN = g.ID_LINGKUNGAN GROUP BY g.ID_KAMPANYE, l.ID_WILAYAH")
    add("DONATIONS", "Campaign dates or status inconsistent", camp,
        f"SELECT COUNT(*) FROM {camp} WHERE PERIODE_SELESAI < PERIODE_MULAI "
        f"OR (STATUS_KAMPANYE = 'Selesai' AND PERIODE_SELESAI > {AS_OF}) "
        f"OR (STATUS_KAMPANYE = 'Direncanakan' AND PERIODE_MULAI <= {AS_OF}) "
        f"OR (STATUS_KAMPANYE = 'Berjalan' AND (PERIODE_MULAI > {AS_OF} OR PERIODE_SELESAI <= {AS_OF}))",
        "ZERO_FAIL", "Status must follow the campaign dates and the snapshot date.")
    add("DONATIONS", "Campaign funds an activity that starts before it", camp,
        f"SELECT COUNT(*) FROM {camp} k JOIN {O}.RENCANA_KEGIATAN p ON p.ID_RENCANA = k.ID_RENCANA_PENGGUNAAN "
        f"WHERE p.TANGGAL_RENCANA < k.PERIODE_MULAI", "ZERO_FAIL", "A campaign pays for an activity that happens after it opens.")
    add("DONATIONS", "Gift dated outside its campaign", gift,
        f"SELECT COUNT(*) FROM {gift} g JOIN {camp} k ON k.ID_KAMPANYE = g.ID_KAMPANYE "
        f"WHERE g.TANGGAL_SUMBANGAN < k.PERIODE_MULAI OR g.TANGGAL_SUMBANGAN > k.PERIODE_SELESAI OR g.TANGGAL_SUMBANGAN > {AS_OF}",
        "ZERO_FAIL", "A household gift is received during its campaign.")
    add("DONATIONS", "Gift community differs from the household assignment", gift,
        f"SELECT COUNT(*) FROM {gift} g WHERE NOT EXISTS (SELECT 1 FROM {pl} p WHERE p.ID_KELUARGA = g.ID_KELUARGA "
        f"AND p.ID_LINGKUNGAN = g.ID_LINGKUNGAN AND p.TANGGAL_MULAI_BERLAKU <= g.TANGGAL_SUMBANGAN "
        f"AND (p.TANGGAL_AKHIR_BERLAKU IS NULL OR p.TANGGAL_AKHIR_BERLAKU >= g.TANGGAL_SUMBANGAN))",
        "ZERO_FAIL", "The community recorded on a gift must be the household community on that date.")
    add("DONATIONS", "Regional summary differs from the household gifts", summ,
        f"SELECT COUNT(*) FROM {summ} s LEFT JOIN ({per_region}) d ON d.ID_KAMPANYE = s.ID_KAMPANYE AND d.ID_WILAYAH = s.ID_WILAYAH "
        f"WHERE COALESCE(d.JUMLAH_KELUARGA, 0) <> s.JUMLAH_KELUARGA_PESERTA OR COALESCE(d.TOTAL, 0) <> s.JUMLAH_SUMBANGAN",
        "ZERO_FAIL", "The summary of a region must equal the sum and count of its household gifts.")
    add("DONATIONS", "Household gifts without a regional summary", gift,
        f"SELECT COUNT(*) FROM ({per_region}) d LEFT JOIN {summ} s ON s.ID_KAMPANYE = d.ID_KAMPANYE AND s.ID_WILAYAH = d.ID_WILAYAH "
        f"WHERE s.ID_SUMBANGAN IS NULL", "ZERO_FAIL", "Every region with gifts needs its summary row.")
    add("DONATIONS", "Summary recorded before the campaign ended", summ,
        f"SELECT COUNT(*) FROM {summ} s JOIN {camp} k ON k.ID_KAMPANYE = s.ID_KAMPANYE "
        f"WHERE s.TANGGAL_PENCATATAN < k.PERIODE_SELESAI OR s.TANGGAL_PENCATATAN > {AS_OF}", "ZERO_FAIL",
        "Regions report after the campaign closes and not after the snapshot date.")
    add("DONATIONS", "Participating households exceed households in the region", summ,
        f"SELECT COUNT(*) FROM {summ} s JOIN {camp} k ON k.ID_KAMPANYE = s.ID_KAMPANYE "
        f"JOIN (SELECT s2.ID_SUMBANGAN, COUNT(p.ID_KELUARGA) AS JUMLAH_KELUARGA FROM {summ} s2 "
        f"JOIN {camp} k2 ON k2.ID_KAMPANYE = s2.ID_KAMPANYE "
        f"LEFT JOIN {M}.MASTER_LINGKUNGAN l ON l.ID_WILAYAH = s2.ID_WILAYAH "
        f"LEFT JOIN {pl} p ON p.ID_LINGKUNGAN = l.ID_LINGKUNGAN AND p.TANGGAL_MULAI_BERLAKU <= k2.PERIODE_SELESAI "
        f"AND (p.TANGGAL_AKHIR_BERLAKU IS NULL OR p.TANGGAL_AKHIR_BERLAKU >= k2.PERIODE_SELESAI) "
        f"GROUP BY s2.ID_SUMBANGAN) h ON h.ID_SUMBANGAN = s.ID_SUMBANGAN WHERE s.JUMLAH_KELUARGA_PESERTA > h.JUMLAH_KELUARGA",
        "ZERO_WARN", "Compares participants with households assigned to the region on the last day of the campaign.")
    add("DONATIONS", "Community without an economic profile", f"{M}.MASTER_LINGKUNGAN",
        f"SELECT COUNT(*) FROM {M}.MASTER_LINGKUNGAN l WHERE NOT EXISTS "
        f"(SELECT 1 FROM {M}.PROFIL_EKONOMI_LINGKUNGAN e WHERE e.ID_LINGKUNGAN = l.ID_LINGKUNGAN)",
        "ZERO_FAIL", "The donation analysis relates gifts to the economic profile of the community.")
    add("DONATIONS", "Planned campaigns", camp,
        f"SELECT COUNT(*) FROM {camp} WHERE STATUS_KAMPANYE = 'Direncanakan'", "INFO", "Deliberate demo scenario: Advent of the current year.")
    add("DONATIONS", "Donation summaries waiting for validation", summ,
        f"SELECT COUNT(*) FROM {summ} WHERE STATUS_VALIDASI <> 'Sudah Divalidasi'", "INFO", "Deliberate demo scenario.")

    # --- dataset information and history ---------------------------------------------------------------
    info = f"{M}.INFO_DATASET"
    add("DATASET", "Dataset information missing or duplicated", info,
        f"SELECT CASE WHEN COUNT(*) = 1 THEN 0 ELSE 1 END FROM {info}", "ZERO_FAIL", "Exactly one dataset information row is expected.")
    add("DATASET", "Snapshot date differs from this validation", info,
        f"SELECT COUNT(*) FROM {info} WHERE TANGGAL_SNAPSHOT <> {AS_OF} OR BERSIFAT_SIMULASI <> TRUE", "ZERO_FAIL",
        "The date used by the checks must be the snapshot date of the data, and the data must be marked simulated.")
    add("DATASET", "Mass history shorter than five years", k,
        f"SELECT COUNT(*) FROM {info} i WHERE (SELECT MIN(TANGGAL_MISA) FROM {k}) > DATEADD('day', 7, i.TANGGAL_MULAI_RIWAYAT) "
        f"OR DATEDIFF('day', i.TANGGAL_MULAI_RIWAYAT, i.TANGGAL_SNAPSHOT) < 1826", "ZERO_FAIL",
        "History must start within a week of the recorded start date and cover at least five years.")
    add("DATASET", "Plan history shorter than five years", f"{O}.RENCANA_KERJA_TAHUNAN",
        f"SELECT COUNT(*) FROM {info} i WHERE (SELECT MIN(TAHUN_RENCANA) FROM {O}.RENCANA_KERJA_TAHUNAN) > EXTRACT(YEAR FROM i.TANGGAL_SNAPSHOT) - 5",
        "ZERO_FAIL", "Annual plans must reach at least five years back.")

    # --- unforeseen events ---------------------------------------------------------------------------------
    ev = f"{O}.PERISTIWA_LUAR_BIASA"
    add("EVENTS", "Event ends before it starts", ev,
        f"SELECT COUNT(*) FROM {ev} WHERE TANGGAL_SELESAI < TANGGAL_MULAI", "ZERO_FAIL", "Event dates.")
    add("EVENTS", "Event windows overlap", ev,
        f"SELECT COUNT(*) FROM {ev} a JOIN {ev} b ON a.ID_PERISTIWA < b.ID_PERISTIWA "
        f"AND a.TANGGAL_MULAI <= b.TANGGAL_SELESAI AND b.TANGGAL_MULAI <= a.TANGGAL_SELESAI", "ZERO_FAIL",
        "Overlapping events would make the effect of each one impossible to separate.")
    add("EVENTS", "Attendance linked to an event that does not cover the Mass date", a,
        f"SELECT COUNT(*) FROM {a} x JOIN {k} k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA JOIN {ev} e ON e.ID_PERISTIWA = x.ID_PERISTIWA "
        f"WHERE k.TANGGAL_MISA < e.TANGGAL_MULAI OR k.TANGGAL_MISA > e.TANGGAL_SELESAI", "ZERO_FAIL",
        "A note about an event only applies to Masses inside its window.")
    add("EVENTS", "Attendance during an event without a link to it", a,
        f"SELECT COUNT(*) FROM {a} x JOIN {k} k ON k.ID_KEJADIAN_MISA = x.ID_KEJADIAN_MISA JOIN {ev} e "
        f"ON k.TANGGAL_MISA BETWEEN e.TANGGAL_MULAI AND e.TANGGAL_SELESAI WHERE x.ID_PERISTIWA IS NULL", "ZERO_WARN",
        "Records inside an event window should name the event, otherwise the dip cannot be explained.")
    add("EVENTS", "Attendance records linked to an unforeseen event", a,
        f"SELECT COUNT(*) FROM {a} WHERE ID_PERISTIWA IS NOT NULL", "INFO", "Masses whose attendance and offertory carry an explanation.")
    add("EVENTS", "Masses cancelled", k,
        f"SELECT COUNT(*) FROM {k} WHERE STATUS_PELAKSANAAN = 'Dibatalkan' AND KETERANGAN IS NOT NULL", "INFO",
        "Cancellations, some caused by events.")

    # --- shadow forecast ---------------------------------------------------------------------------------
    fc, fm, fv = f"{O}.PERKIRAAN_KOLEKTE_MINGGUAN", f"{M}.REFERENSI_MODEL_PERKIRAAN", f"{A}.KOLEKTE_AKTUAL_VS_PERKIRAAN"
    add("FORECAST", "Target week does not start on a Monday", fc,
        f"SELECT COUNT(*) FROM {fc} WHERE MOD(DATEDIFF('day', DATE '1900-01-01', AWAL_PEKAN_SASARAN), 7) <> 0",
        "ZERO_FAIL", "Weeks run from Monday to Sunday, like the weekly offertory view (1900-01-01 was a Monday).")
    add("FORECAST", "Forecast not issued exactly one horizon before its week", fc,
        f"SELECT COUNT(*) FROM {fc} f JOIN {fm} m ON m.ID_MODEL = f.ID_MODEL "
        f"WHERE DATEDIFF('day', f.TANGGAL_PERKIRAAN, f.AWAL_PEKAN_SASARAN) <> m.HORIZON_HARI",
        "ZERO_FAIL", "Every forecast is made the number of days ahead that the model declares.")
    add("FORECAST", "Forecast issued after the as-of date", fc,
        f"SELECT COUNT(*) FROM {fc} WHERE TANGGAL_PERKIRAAN > {AS_OF}", "ZERO_FAIL",
        "A forecast cannot be dated in the future of the snapshot.")
    add("FORECAST", "Range does not contain the point forecast", fc,
        f"SELECT COUNT(*) FROM {fc} WHERE BATAS_BAWAH > JUMLAH_PERKIRAAN OR JUMLAH_PERKIRAAN > BATAS_ATAS OR PENYESUAIAN_KALENDER < 0.5",
        "ZERO_FAIL", "Lower bound <= forecast <= upper bound, and the calendar multiplier must be plausible.")
    add("FORECAST", "Too little history behind a forecast", fc,
        f"SELECT COUNT(*) FROM {fc} f JOIN {fm} m ON m.ID_MODEL = f.ID_MODEL "
        f"WHERE f.JUMLAH_PEKAN_PELATIHAN < 10 OR f.JUMLAH_PEKAN_PELATIHAN > m.JENDELA_PELATIHAN_MINGGU",
        "ZERO_FAIL", "The model learns from at least 10 undisturbed weeks and at most its training window.")
    add("FORECAST", "Gap in the weekly forecast series", fc,
        f"SELECT COUNT(*) FROM (SELECT ID_MODEL, COUNT(*) AS N, MIN(AWAL_PEKAN_SASARAN) AS A, MAX(AWAL_PEKAN_SASARAN) AS B "
        f"FROM {fc} GROUP BY ID_MODEL) g WHERE DATEDIFF('day', g.A, g.B) / 7 + 1 <> g.N",
        "ZERO_FAIL", "A forecast exists for every week between the first and the last one.")
    add("FORECAST", "Complete week without a forecast", f"{A}.KOLEKTE_MINGGUAN_DAN_PERISTIWA",
        f"SELECT COUNT(*) FROM {A}.KOLEKTE_MINGGUAN_DAN_PERISTIWA w CROSS JOIN {M}.INFO_DATASET i "
        f"WHERE DATEADD('day', 6, w.AWAL_PEKAN) <= i.TANGGAL_SNAPSHOT "
        f"AND w.AWAL_PEKAN >= (SELECT MIN(AWAL_PEKAN_SASARAN) FROM {fc}) "
        f"AND NOT EXISTS (SELECT 1 FROM {fc} f WHERE f.AWAL_PEKAN_SASARAN = w.AWAL_PEKAN)",
        "ZERO_FAIL", "After the first forecast every complete week with a collection must have been forecast.")
    add("FORECAST", "Forecast view differs from the forecast table", fv,
        f"SELECT ABS((SELECT COUNT(*) FROM {fv}) - (SELECT COUNT(*) FROM {fc}))", "ZERO_FAIL",
        "The comparison view shows exactly one row per stored forecast.")
    add("FORECAST", "Actual offertory in the view differs from the Mass data", fv,
        f"SELECT COUNT(*) FROM {fv} v WHERE v.STATUS_PEKAN = 'Lengkap' AND v.KOLEKTE_AKTUAL <> "
        f"(SELECT COALESCE(SUM(COALESCE(c.JUMLAH_HASIL_PENGHITUNGAN, c.JUMLAH_PENERIMAAN)), 0) FROM {c} c "
        f"JOIN {k} k ON k.ID_KEJADIAN_MISA = c.ID_KEJADIAN_MISA WHERE k.STATUS_PELAKSANAAN = 'Terlaksana' "
        f"AND k.TANGGAL_MISA BETWEEN v.AWAL_PEKAN AND DATEADD('day', 6, v.AWAL_PEKAN))",
        "ZERO_FAIL", "Recomputes the actual weekly offertory from the collections themselves.")
    add("FORECAST", "Weeks with an actual result outside the forecast range", fv,
        f"SELECT COUNT(*) FROM {fv} WHERE POSISI_TERHADAP_RENTANG IN ('Di bawah rentang', 'Di atas rentang')", "INFO",
        "Expected to be about one week in five for ordinary weeks, because the range is an 80% range.")
    add("FORECAST", "Gaps explained by an unforeseen event", fv,
        f"SELECT COUNT(*) FROM {fv} WHERE PENJELASAN_SELISIH = 'Di luar rentang, dijelaskan peristiwa luar biasa'", "INFO",
        "Deliberate demo scenario: the event log explains why the forecast missed.")
    add("FORECAST", "Forecast weeks still to come", fv,
        f"SELECT COUNT(*) FROM {fv} WHERE STATUS_PEKAN <> 'Lengkap'", "INFO",
        "Forecasts for the current week and the weeks ahead, which have no complete actual result yet.")

    # --- public service guides ----------------------------------------------------------------------------
    sv, st, rq, sp = f"{M}.LAYANAN_PAROKI", f"{M}.LANGKAH_LAYANAN", f"{M}.PERSYARATAN_LAYANAN", f"{A}.LAYANAN_PUBLIK"
    add("SERVICES", "Service without steps or without requirements", sv,
        f"SELECT COUNT(*) FROM {sv} l WHERE NOT EXISTS (SELECT 1 FROM {st} g WHERE g.ID_LAYANAN = l.ID_LAYANAN) "
        f"OR NOT EXISTS (SELECT 1 FROM {rq} r WHERE r.ID_LAYANAN = l.ID_LAYANAN)", "ZERO_FAIL",
        "A guide without steps or without requirements is not a guide.")
    add("SERVICES", "Step numbers have gaps or do not start at 1", st,
        f"SELECT COUNT(*) FROM (SELECT ID_LAYANAN FROM {st} GROUP BY ID_LAYANAN HAVING MIN(NOMOR_URUT) <> 1 OR MAX(NOMOR_URUT) <> COUNT(*)) d",
        "ZERO_FAIL", "Steps are numbered 1, 2, 3 and so on without gaps, so the order is unambiguous.")
    add("SERVICES", "Requirement numbers have gaps or do not start at 1", rq,
        f"SELECT COUNT(*) FROM (SELECT ID_LAYANAN FROM {rq} GROUP BY ID_LAYANAN HAVING MIN(NOMOR_URUT) <> 1 OR MAX(NOMOR_URUT) <> COUNT(*)) d",
        "ZERO_FAIL", "Requirements are numbered 1, 2, 3 and so on without gaps.")
    add("SERVICES", "Guide file name does not start with the service id or is not a PDF", sv,
        f"SELECT COUNT(*) FROM {sv} WHERE LEFT(NAMA_BERKAS_PANDUAN, LENGTH(ID_LAYANAN) + 1) <> ID_LAYANAN || '_' "
        f"OR LOWER(NAMA_BERKAS_PANDUAN) NOT LIKE '%.pdf' OR NAMA_BERKAS_PANDUAN LIKE '%/%'", "ZERO_FAIL",
        "Only the file name is stored. The service id at the start of the name is how a file is matched to its row.")
    add("SERVICES", "Service guide with a classification that may not be public", sv,
        f"SELECT COUNT(*) FROM {sv} l JOIN {M}.REFERENSI_KLASIFIKASI_DATA k ON k.ID_KLASIFIKASI_DATA = l.ID_KLASIFIKASI_DATA "
        f"WHERE k.DAPAT_DITAMPILKAN_PUBLIK = FALSE", "ZERO_WARN",
        "Such a service is hidden from the public views. That is allowed, but not what the demo expects.")
    add("SERVICES", "Public view differs from the service tables", sp,
        f"SELECT ABS((SELECT COUNT(*) FROM {sp}) - (SELECT COUNT(*) FROM {sv} l JOIN {M}.REFERENSI_KLASIFIKASI_DATA k "
        f"ON k.ID_KLASIFIKASI_DATA = l.ID_KLASIFIKASI_DATA WHERE k.DAPAT_DITAMPILKAN_PUBLIK = TRUE)) "
        f"+ ABS((SELECT COUNT(*) FROM {A}.LANGKAH_LAYANAN_PUBLIK) - (SELECT SUM(JUMLAH_LANGKAH) FROM {sp})) "
        f"+ ABS((SELECT COUNT(*) FROM {A}.PERSYARATAN_LAYANAN_PUBLIK) - (SELECT SUM(JUMLAH_PERSYARATAN) FROM {sp}))",
        "ZERO_FAIL", "The public views show every step and requirement of every public service, and nothing else.")
    add("SERVICES", "Guide text containing an email address", sv,
        f"SELECT (SELECT COUNT(*) FROM {sv} WHERE RINGKASAN LIKE '%@%' OR CATATAN_PENTING LIKE '%@%') "
        f"+ (SELECT COUNT(*) FROM {st} WHERE URAIAN LIKE '%@%') + (SELECT COUNT(*) FROM {rq} WHERE KETERANGAN LIKE '%@%')",
        "ZERO_FAIL", "Public guides must not carry contact details of individuals.")
    add("SERVICES", "Revision date after the as-of date", sv,
        f"SELECT COUNT(*) FROM {sv} WHERE TANGGAL_REVISI > {AS_OF}", "ZERO_FAIL", "A guide cannot be reviewed in the future of the snapshot.")
    add("SERVICES", "Public services", sp, f"SELECT COUNT(*) FROM {sp}", "INFO",
        "Services whose guide is shown on the public dashboard page.")

    # --- planning, events, reports -------------------------------------------------------------------
    e, r, plan, hdr = f"{O}.KEGIATAN", f"{O}.LAPORAN_KEGIATAN", f"{O}.RENCANA_KEGIATAN", f"{O}.RENCANA_KERJA_TAHUNAN"
    alk, rl = f"{O}.ALOKASI_ANGGARAN", f"{O}.REALISASI_PENGELUARAN"
    add("PLANNING", "Event section differs from its plan", e,
        f"SELECT COUNT(*) FROM {e} e JOIN {plan} p ON p.ID_RENCANA = e.ID_RENCANA JOIN {hdr} h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA "
        f"WHERE h.ID_SEKSI <> e.ID_SEKSI", "ZERO_FAIL", "ID_SEKSI is repeated on the event on purpose, so it must agree with the plan.")
    add("PLANNING", "Event status differs from its plan status", e,
        f"SELECT COUNT(*) FROM {e} e JOIN {plan} p ON p.ID_RENCANA = e.ID_RENCANA WHERE p.STATUS_PELAKSANAAN <> e.STATUS_KEGIATAN",
        "ZERO_FAIL", "Plan and event must tell the same story.")
    add("PLANNING", "Completed plan without an event", plan,
        f"SELECT COUNT(*) FROM {plan} p WHERE p.STATUS_PELAKSANAAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM {e} e WHERE e.ID_RENCANA = p.ID_RENCANA)",
        "ZERO_FAIL", "A plan marked Terlaksana needs the event that carried it out.")
    add("PLANNING", "Event dates or participants inconsistent", e,
        f"SELECT COUNT(*) FROM {e} WHERE TANGGAL_SELESAI < TANGGAL_MULAI OR (STATUS_KEGIATAN = 'Terlaksana' AND (JUMLAH_PESERTA_AKTUAL IS NULL OR TANGGAL_SELESAI > {AS_OF})) "
        f"OR (STATUS_KEGIATAN <> 'Terlaksana' AND JUMLAH_PESERTA_AKTUAL IS NOT NULL)",
        "ZERO_FAIL", "Actual participants exist exactly for events that were held, and held events are in the past.")
    add("PLANNING", "Plan date outside the plan year", plan,
        f"SELECT COUNT(*) FROM {plan} p JOIN {hdr} h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE EXTRACT(YEAR FROM p.TANGGAL_RENCANA) <> h.TAHUN_RENCANA",
        "ZERO_FAIL", "Planned dates must fall in the year of the annual plan.")
    up = f"{A}.KEGIATAN_MENDATANG"
    add("PLANNING", "Open plan missing from the upcoming activities view", plan,
        f"SELECT COUNT(*) FROM {plan} p WHERE p.STATUS_PELAKSANAAN = 'Direncanakan' AND NOT EXISTS "
        f"(SELECT 1 FROM {up} u WHERE u.ID_RENCANA = p.ID_RENCANA)", "ZERO_FAIL",
        "Every plan that has not been carried out yet must show up on the upcoming activities page.")
    add("PLANNING", "Plan listed twice in the upcoming activities view", up,
        f"SELECT COUNT(*) FROM (SELECT ID_RENCANA FROM {up} GROUP BY ID_RENCANA HAVING COUNT(*) > 1) d", "ZERO_FAIL",
        "One row per plan: a duplicate would double the budget shown for upcoming activities.")
    add("PLANNING", "Upcoming activity dated before the snapshot date", up,
        f"SELECT COUNT(*) FROM {up} WHERE TAHAP <> 'Ditunda, perlu jadwal baru' AND TANGGAL_MULAI < TANGGAL_DATA", "ZERO_WARN",
        "A plan still marked Direncanakan after its date is overdue and should be updated.")
    add("PLANNING", "Upcoming activities", up, f"SELECT COUNT(*) FROM {up}", "INFO",
        "Deliberate demo scenario: scheduled events, plan-only activities and postponed ones.")
    add("PLANNING", "Source file name does not start with the report number", r,
        f"SELECT COUNT(*) FROM {r} WHERE NAMA_BERKAS_SUMBER IS NOT NULL "
        f"AND LEFT(NAMA_BERKAS_SUMBER, LENGTH(ID_LAPORAN) + 1) <> ID_LAPORAN || '_'", "ZERO_FAIL",
        "The report number at the start of the file name is how a document is matched to its row.")
    add("PLANNING", "Source file is not a PDF or names a folder", r,
        f"SELECT COUNT(*) FROM {r} WHERE NAMA_BERKAS_SUMBER IS NOT NULL "
        f"AND (LOWER(NAMA_BERKAS_SUMBER) NOT LIKE '%.pdf' OR NAMA_BERKAS_SUMBER LIKE '%/%')", "ZERO_FAIL",
        "Only the file name is stored, never a folder, because the folder differs between a repository and a stage.")
    add("PLANNING", "Reports without a source document", r,
        f"SELECT COUNT(*) FROM {r} WHERE NAMA_BERKAS_SUMBER IS NULL", "ZERO_WARN",
        "Every report in the demo was extracted from a PDF, so a report entered by hand would show here.")
    add("PLANNING", "Expenditure outside the plan year", rl,
        f"SELECT COUNT(*) FROM {rl} x JOIN {alk} a ON a.ID_ALOKASI = x.ID_ALOKASI JOIN {plan} p ON p.ID_RENCANA = a.ID_RENCANA "
        f"JOIN {hdr} h ON h.ID_RENCANA_KERJA = p.ID_RENCANA_KERJA WHERE EXTRACT(YEAR FROM x.TANGGAL_PENGELUARAN) <> h.TAHUN_RENCANA",
        "ZERO_FAIL", "Spending must be dated in the plan year.")
    add("PLANNING", "Expenditure on a plan that is Direncanakan or Dibatalkan", rl,
        f"SELECT COUNT(*) FROM {rl} x JOIN {alk} a ON a.ID_ALOKASI = x.ID_ALOKASI JOIN {plan} p ON p.ID_RENCANA = a.ID_RENCANA "
        f"WHERE p.STATUS_PELAKSANAAN IN ('Direncanakan', 'Dibatalkan')", "ZERO_WARN",
        "Possible but unusual: spending before a plan starts or after it was cancelled.")
    add("PLANNING", "Allocations without any expenditure", alk,
        f"SELECT COUNT(*) FROM {alk} a WHERE NOT EXISTS (SELECT 1 FROM {rl} x WHERE x.ID_ALOKASI = a.ID_ALOKASI)", "INFO",
        "Deliberate demo scenario: budget not yet used.")
    add("PLANNING", "Allocations partly used", alk,
        f"SELECT COUNT(*) FROM (SELECT a.ID_ALOKASI, a.JUMLAH_ANGGARAN, COALESCE(SUM(x.JUMLAH_PENGELUARAN), 0) AS TERPAKAI "
        f"FROM {alk} a LEFT JOIN {rl} x ON x.ID_ALOKASI = a.ID_ALOKASI GROUP BY a.ID_ALOKASI, a.JUMLAH_ANGGARAN) t "
        f"WHERE t.TERPAKAI BETWEEN 1 AND t.JUMLAH_ANGGARAN - 1", "INFO", "Deliberate demo scenario: spending below budget.")
    add("PLANNING", "Allocations spent above budget", alk,
        f"SELECT COUNT(*) FROM (SELECT a.ID_ALOKASI, a.JUMLAH_ANGGARAN, COALESCE(SUM(x.JUMLAH_PENGELUARAN), 0) AS TERPAKAI "
        f"FROM {alk} a LEFT JOIN {rl} x ON x.ID_ALOKASI = a.ID_ALOKASI GROUP BY a.ID_ALOKASI, a.JUMLAH_ANGGARAN) t "
        f"WHERE t.TERPAKAI > t.JUMLAH_ANGGARAN", "INFO", "Deliberate demo scenario: overspending to be explained.")
    add("PLANNING", "Report for an event that was not held", r,
        f"SELECT COUNT(*) FROM {r} r JOIN {e} e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE e.STATUS_KEGIATAN <> 'Terlaksana'",
        "ZERO_FAIL", "Only events that took place can be reported.")
    add("PLANNING", "Report date before the event ended or after the as-of date", r,
        f"SELECT COUNT(*) FROM {r} r JOIN {e} e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE r.TANGGAL_LAPORAN < e.TANGGAL_SELESAI OR r.TANGGAL_LAPORAN > {AS_OF}",
        "ZERO_FAIL", "A report follows the event.")
    add("PLANNING", "Final report with empty required fields", r,
        f"SELECT COUNT(*) FROM {r} WHERE STATUS_LAPORAN = 'Final' AND (RINGKASAN_PELAKSANAAN IS NULL OR JUMLAH_PESERTA IS NULL OR "
        f"REALISASI_BIAYA IS NULL OR EVALUASI_LOGISTIK IS NULL OR HASIL_KEGIATAN IS NULL OR REKOMENDASI_TINDAK_LANJUT IS NULL)",
        "ZERO_FAIL", "A final report must be complete.")
    add("PLANNING", "Report participants differ from the event", r,
        f"SELECT COUNT(*) FROM {r} r JOIN {e} e ON e.ID_KEGIATAN = r.ID_KEGIATAN WHERE r.JUMLAH_PESERTA IS NOT NULL "
        f"AND r.JUMLAH_PESERTA <> e.JUMLAH_PESERTA_AKTUAL", "ZERO_WARN",
        "Expected: 1 (the report with status Perlu Revisi is deliberately inconsistent).")
    add("PLANNING", "Report cost differs from recorded expenditure", r,
        f"SELECT COUNT(*) FROM {r} r JOIN {e} e ON e.ID_KEGIATAN = r.ID_KEGIATAN "
        f"LEFT JOIN (SELECT a.ID_RENCANA, SUM(x.JUMLAH_PENGELUARAN) AS TOTAL_PENGELUARAN FROM {rl} x "
        f"JOIN {alk} a ON a.ID_ALOKASI = x.ID_ALOKASI GROUP BY a.ID_RENCANA) s ON s.ID_RENCANA = e.ID_RENCANA "
        f"WHERE r.REALISASI_BIAYA IS NOT NULL AND e.ID_RENCANA IS NOT NULL AND r.REALISASI_BIAYA <> COALESCE(s.TOTAL_PENGELUARAN, 0)",
        "ZERO_WARN",
        "Compares the cost in the report with the sum of expenditure lines of the planned activity.")
    add("PLANNING", "Completed events without a report", e,
        f"SELECT COUNT(*) FROM {e} e WHERE e.STATUS_KEGIATAN = 'Terlaksana' AND NOT EXISTS (SELECT 1 FROM {r} r WHERE r.ID_KEGIATAN = e.ID_KEGIATAN)",
        "INFO", "Deliberate demo scenario: reports not yet submitted.")
    add("PLANNING", "Draft or revision reports", r,
        f"SELECT COUNT(*) FROM {r} WHERE STATUS_LAPORAN <> 'Final'", "INFO", "Deliberate demo scenario: incomplete reports.")
    add("PLANNING", "Postponed or cancelled plans", plan,
        f"SELECT COUNT(*) FROM {plan} WHERE STATUS_PELAKSANAAN IN ('Ditunda', 'Dibatalkan')", "INFO", "Deliberate demo scenario.")

    # --- surveys -----------------------------------------------------------------------------------------------
    j, h, rs = f"{O}.JAWABAN_SURVEI", f"{O}.HASIL_SURVEI_AGREGAT", f"{O}.RESPONDEN_SURVEI"
    add("SURVEYS", "Answer option does not belong to the question", j,
        f"SELECT COUNT(*) FROM {j} j JOIN {M}.OPSI_JAWABAN_SURVEI o ON o.ID_OPSI = j.ID_OPSI WHERE o.ID_PERTANYAAN <> j.ID_PERTANYAAN",
        "ZERO_FAIL", "The chosen option must be one of the question options.")
    add("SURVEYS", "Question and respondent belong to different surveys", j,
        f"SELECT COUNT(*) FROM {j} j JOIN {M}.PERTANYAAN_SURVEI q ON q.ID_PERTANYAAN = j.ID_PERTANYAAN "
        f"JOIN {rs} r ON r.ID_RESPONDEN = j.ID_RESPONDEN WHERE q.ID_SURVEI <> r.ID_SURVEI", "ZERO_FAIL",
        "A respondent only answers questions of the survey they filled in.")
    add("SURVEYS", "Aggregate count differs from the answers", h,
        f"SELECT COUNT(*) FROM {h} h LEFT JOIN (SELECT ID_OPSI, COUNT(*) AS N FROM {j} GROUP BY ID_OPSI) c "
        f"ON c.ID_OPSI = h.ID_OPSI WHERE h.JUMLAH_RESPONDEN <> COALESCE(c.N, 0)",
        "ZERO_FAIL", "Recomputes every option count from the raw answers.")
    add("SURVEYS", "Aggregate total differs from the answers", h,
        f"SELECT COUNT(*) FROM {h} h LEFT JOIN (SELECT ID_PERTANYAAN, COUNT(*) AS N FROM {j} GROUP BY ID_PERTANYAAN) c "
        f"ON c.ID_PERTANYAAN = h.ID_PERTANYAAN WHERE h.TOTAL_RESPONDEN_PERTANYAAN <> COALESCE(c.N, 0)",
        "ZERO_FAIL", "Recomputes the number of respondents per question.")
    add("SURVEYS", "Percentage differs from count divided by total", h,
        f"SELECT COUNT(*) FROM {h} WHERE (TOTAL_RESPONDEN_PERTANYAAN = 0 AND PERSENTASE_JAWABAN <> 0) OR (TOTAL_RESPONDEN_PERTANYAAN > 0 "
        f"AND ABS(PERSENTASE_JAWABAN - 100.0 * JUMLAH_RESPONDEN / TOTAL_RESPONDEN_PERTANYAAN) > 0.01)", "ZERO_FAIL",
        "Tolerance 0.01 percentage point for rounding.")
    add("SURVEYS", "Option counts do not add up to the question total", h,
        f"SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN FROM {h} GROUP BY ID_PERTANYAAN HAVING SUM(JUMLAH_RESPONDEN) <> MAX(TOTAL_RESPONDEN_PERTANYAAN)) d",
        "ZERO_FAIL", "Single answers: option counts must sum to the number of respondents.")
    add("SURVEYS", "Percentages do not add up to 100", h,
        f"SELECT COUNT(*) FROM (SELECT ID_PERTANYAAN FROM {h} GROUP BY ID_PERTANYAAN HAVING MAX(TOTAL_RESPONDEN_PERTANYAAN) > 0 "
        f"AND ABS(SUM(PERSENTASE_JAWABAN) - 100) > 0.1) d", "ZERO_FAIL", "Tolerance 0.1 percentage point for rounding.")
    add("SURVEYS", "Answered question without aggregate rows", j,
        f"SELECT COUNT(DISTINCT j.ID_PERTANYAAN) FROM {j} j WHERE NOT EXISTS (SELECT 1 FROM {h} h WHERE h.ID_PERTANYAAN = j.ID_PERTANYAAN)",
        "ZERO_FAIL", "Every answered question must be summarised.")
    add("SURVEYS", "Respondent filled outside the survey window", rs,
        f"SELECT COUNT(*) FROM {rs} r JOIN {M}.SURVEI s ON s.ID_SURVEI = r.ID_SURVEI WHERE r.TANGGAL_PENGISIAN < s.TANGGAL_MULAI "
        f"OR r.TANGGAL_PENGISIAN > s.TANGGAL_SELESAI OR r.TANGGAL_PENGISIAN > {AS_OF}", "ZERO_FAIL", "Responses fall inside the survey dates.")
    add("SURVEYS", "Survey ends before it starts", f"{M}.SURVEI",
        f"SELECT COUNT(*) FROM {M}.SURVEI WHERE TANGGAL_SELESAI < TANGGAL_MULAI", "ZERO_FAIL", "Survey dates.")
    add("SURVEYS", "Surveys without responses", f"{M}.SURVEI",
        f"SELECT COUNT(*) FROM {M}.SURVEI s WHERE NOT EXISTS (SELECT 1 FROM {rs} r WHERE r.ID_SURVEI = s.ID_SURVEI)", "INFO",
        "Deliberate demo scenario: a planned survey has no responses and no aggregates.")

    # --- Demographics ----------------------------------------------------------------
    um = f"{O}.UMAT"
    ds, py, rg, fm = (f"{A}.RINGKASAN_DEMOGRAFI_UMAT", f"{A}.DEMOGRAFI_UMAT_USIA_JENIS_KELAMIN",
                      f"{A}.DEMOGRAFI_UMAT_PER_WILAYAH", f"{A}.DEMOGRAFI_KELUARGA")
    add("DEMOGRAPHICS", "Parishioner with an implausible age or an unknown gender", um,
        f"SELECT COUNT(*) FROM {um} WHERE {config.AS_OF.year} - TAHUN_LAHIR NOT BETWEEN 0 AND 110 "
        f"OR JENIS_KELAMIN NOT IN ('Laki-laki', 'Perempuan')", "ZERO_FAIL",
        "The age groups run from 0 and the pyramid has the two genders of the data. Anyone else would silently drop out of the counts.")
    add("DEMOGRAPHICS", "Active parishioners the demographic views cannot place", ds,
        f"SELECT (SELECT COUNT(*) FROM {um} WHERE STATUS_KEANGGOTAAN = 'Aktif') - (SELECT JUMLAH_UMAT_AKTIF FROM {ds})", "ZERO_WARN",
        "An active parishioner without a current household in an active household is not counted. The people not counted are listed in the summary.")
    add("DEMOGRAPHICS", "Pyramid does not add up to the active parishioners", py,
        f"SELECT COUNT(*) FROM {ds} s WHERE NOT EXISTS (SELECT 1 FROM {py} WHERE DISEMBUNYIKAN = TRUE) "
        f"AND s.JUMLAH_UMAT_AKTIF <> (SELECT SUM(JUMLAH_UMAT) FROM {py})", "ZERO_FAIL",
        "When no cell is hidden, the age and gender cells must add up to the headline figure.")
    add("DEMOGRAPHICS", "Households by size do not add up", fm,
        f"SELECT COUNT(*) FROM {ds} s WHERE NOT EXISTS (SELECT 1 FROM {fm} WHERE DISEMBUNYIKAN = TRUE) "
        f"AND (s.JUMLAH_KELUARGA_AKTIF <> (SELECT SUM(JUMLAH_KELUARGA) FROM {fm}) OR s.JUMLAH_UMAT_AKTIF <> (SELECT SUM(JUMLAH_UMAT) FROM {fm}))",
        "ZERO_FAIL", "When no cell is hidden, households and people by household size must add up to the headline figures.")
    add("DEMOGRAPHICS", "Regions do not add up to the active parishioners", rg,
        f"SELECT COUNT(*) FROM {ds} s WHERE NOT EXISTS (SELECT 1 FROM {rg} WHERE DISEMBUNYIKAN = TRUE) "
        f"AND s.JUMLAH_UMAT_AKTIF <> (SELECT SUM(JUMLAH_UMAT) FROM {rg})", "ZERO_WARN",
        "A household without a current community, or in an inactive region, is in the headline figure but in no region.")
    add("DEMOGRAPHICS", "Small cell shown in a demographic view", ds,
        f"SELECT (SELECT COUNT(*) FROM {py} WHERE JUMLAH_UMAT BETWEEN 1 AND 4) + (SELECT COUNT(*) FROM {rg} WHERE JUMLAH_UMAT BETWEEN 1 AND 4 "
        f"OR JUMLAH_UMAT_WILAYAH BETWEEN 1 AND 4) + (SELECT COUNT(*) FROM {fm} WHERE JUMLAH_KELUARGA BETWEEN 1 AND 4)", "ZERO_FAIL",
        "A cell of 1 to 4 people or households must be hidden (NULL), so that nobody can be picked out of a small group.")
    add("DEMOGRAPHICS", "Hidden cells in the demographic views", ds,
        f"SELECT (SELECT COUNT(*) FROM {py} WHERE DISEMBUNYIKAN = TRUE) + (SELECT COUNT(*) FROM {rg} WHERE DISEMBUNYIKAN = TRUE) "
        f"+ (SELECT COUNT(*) FROM {fm} WHERE DISEMBUNYIKAN = TRUE)", "INFO",
        "None in the demo data (every cell has at least 5). The rule is there for smaller groups, for example when the data is real.")

    for view in views:
        add("VIEWS", "View returns rows", f"{A}.{view}", f"SELECT COUNT(*) FROM {A}.{view}", "NONEMPTY",
            "Fails when the view is missing, broken, or empty.")
    return arms


def view_names(views_sql):
    return re.findall(r"CREATE OR REPLACE VIEW ANALISIS\.(\w+)", views_sql)


def build_arms(tables, data, views_sql):
    return _generic_arms(tables, data) + _business_arms(view_names(views_sql))


def render(tables, data, views_sql, seed):
    arms = build_arms(tables, data, views_sql)
    lines = [
        "-- =============================================================================",
        "-- Step 6: Validate the data (read-only)",
        "--",
        "-- GENERATED FILE. Do not edit by hand: run  python scripts/generate_mock_data.py",
        "-- after changing sql/02_create_tables.sql, sql/05_create_views.sql or the generator.",
        "--",
        "-- Purpose : Row counts, duplicate keys, orphaned references, allowed values,",
        "--           negative numbers, date plausibility, cross-domain consistency",
        "--           (Mass schedule, attendance, offertory, plans, budgets, events,",
        "--           reports, surveys) and privacy guards.",
        "-- Output  : ONE result table. The first two rows summarise the run.",
        "--           RESULT is PASS, FAIL (data is wrong), WARN (look at it) or INFO",
        "--           (a deliberate demo scenario, for interpretation only).",
        "--           Expected for the bundled demo data: 0 FAIL and exactly 1 WARN.",
        "-- Safe to re-run: yes. This file only reads data and never changes anything.",
        "-- Dates   : checks use the fixed snapshot date "
        f"{config.AS_OF.isoformat()} of the demo data, never today's date.",
        f"-- Seed    : {seed}",
        "-- =============================================================================",
        "",
        f"USE DATABASE {DB};",
        "",
        "WITH CHECKS AS (",
    ]
    body = []
    for order, arm in enumerate(arms, start=1):
        expected = "NULL" if arm.expected is None else str(arm.expected)
        count_sql = arm.count_sql.replace("\n", "\n        ")
        body.append(
            f"    SELECT {order * 10} AS SORT_ORDER, '{arm.group}' AS CHECK_GROUP, '{_q(arm.name)}' AS CHECK_NAME,\n"
            f"           '{_q(arm.obj)}' AS OBJECT_NAME,\n"
            f"           ({count_sql}) AS FOUND_COUNT,\n"
            f"           {expected} AS EXPECTED_COUNT, '{arm.rule}' AS RULE_TYPE,\n"
            f"           '{_q(arm.note)}' AS NOTE"
        )
    lines.append("\n    UNION ALL\n".join(body))
    lines += [
        "),",
        "RESULTS AS (",
        "    SELECT",
        "        SORT_ORDER, CHECK_GROUP, CHECK_NAME, OBJECT_NAME, FOUND_COUNT, EXPECTED_COUNT,",
        "        CASE RULE_TYPE",
        "            WHEN 'ROWS' THEN CASE WHEN FOUND_COUNT = 0 THEN 'FAIL' WHEN FOUND_COUNT = EXPECTED_COUNT THEN 'PASS' ELSE 'WARN' END",
        "            WHEN 'NONEMPTY' THEN CASE WHEN FOUND_COUNT > 0 THEN 'PASS' ELSE 'FAIL' END",
        "            WHEN 'ZERO_FAIL' THEN CASE WHEN FOUND_COUNT = 0 THEN 'PASS' ELSE 'FAIL' END",
        "            WHEN 'ZERO_WARN' THEN CASE WHEN FOUND_COUNT = 0 THEN 'PASS' ELSE 'WARN' END",
        "            ELSE 'INFO'",
        "        END AS RESULT,",
        "        NOTE",
        "    FROM CHECKS",
        ")",
        "SELECT SORT_ORDER, CHECK_GROUP, CHECK_NAME, OBJECT_NAME, FOUND_COUNT, EXPECTED_COUNT, RESULT, NOTE",
        "FROM (",
        "    SELECT * FROM RESULTS",
        "    UNION ALL",
        "    SELECT 1, 'SUMMARY', 'Checks with result FAIL', 'ALL CHECKS', COUNT(*), 0,",
        "           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,",
        "           'Must be 0. Filter RESULT = FAIL to see which checks failed.'",
        "    FROM RESULTS WHERE RESULT = 'FAIL'",
        "    UNION ALL",
        "    SELECT 2, 'SUMMARY', 'Checks with result WARN', 'ALL CHECKS', COUNT(*), 1,",
        "           CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'WARN' END,",
        "           'The bundled demo data has exactly 1 WARN (a report whose participant count is deliberately inconsistent).'",
        "    FROM RESULTS WHERE RESULT = 'WARN'",
        ") ALL_ROWS",
        "ORDER BY SORT_ORDER;",
        "",
    ]
    return "\n".join(lines)
