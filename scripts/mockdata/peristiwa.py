"""Unforeseen circumstances that disturbed parish life: floods, haze, volcanic
ash, power cuts. The log records WHAT happened and WHEN, and a staff judgement of
how severe it was. It deliberately does not record the effect on attendance or
offertory: that is what the analysis has to discover from the data.

Wording is generic ("gunung berapi", "kota") on purpose: the parish is fictional
and no real place may be implied."""

from datetime import date

SCHEMA = "DATA_OPERASIONAL"

# id, type, name, start, end, severity, description, short reason used in notes
EVENTS = [
    ("PRS-01", "Hujan Deras dan Banjir", "Banjir besar Februari 2021", date(2021, 2, 13), date(2021, 2, 21), "Berat",
     "Hujan deras berhari-hari membuat jalan menuju gereja tergenang, banyak umat tidak dapat hadir.", "banjir besar"),
    ("PRS-02", "Kabut Asap", "Kabut asap September 2021", date(2021, 9, 4), date(2021, 9, 26), "Sedang",
     "Kualitas udara memburuk karena kabut asap, lansia dan anak-anak diminta tinggal di rumah.", "kabut asap"),
    ("PRS-03", "Hujan Deras dan Banjir", "Hujan deras Januari 2022", date(2022, 1, 15), date(2022, 1, 23), "Ringan",
     "Hujan lebat beberapa hari berturut-turut menyulitkan umat dari wilayah yang jauh.", "hujan deras"),
    ("PRS-04", "Abu Vulkanik", "Hujan abu tipis November 2022", date(2022, 11, 12), date(2022, 11, 27), "Sedang",
     "Letusan kecil gunung berapi di sekitar wilayah menebarkan abu tipis di kota, sebagian umat memilih tinggal di rumah.",
     "hujan abu vulkanik"),
    ("PRS-05", "Gangguan Listrik", "Pemadaman listrik Maret 2023", date(2023, 3, 4), date(2023, 3, 5), "Ringan",
     "Pemadaman listrik luas membuat Misa berlangsung tanpa tata suara dan penerangan penuh.", "pemadaman listrik"),
    ("PRS-06", "Kabut Asap", "Kabut asap sangat tebal September-Oktober 2023", date(2023, 9, 9), date(2023, 10, 22), "Berat",
     "Kabut asap sangat tebal selama enam pekan, jarak pandang dan kualitas udara sangat buruk.", "kabut asap sangat tebal"),
    ("PRS-07", "Hujan Deras dan Banjir", "Banjir Februari 2024", date(2024, 2, 10), date(2024, 2, 18), "Sedang",
     "Banjir di sejumlah lingkungan menghambat umat menuju gereja.", "banjir"),
    ("PRS-08", "Abu Vulkanik", "Hujan abu vulkanik tebal Juni 2025", date(2025, 6, 7), date(2025, 7, 6), "Berat",
     "Letusan besar gunung berapi yang belum pernah terjadi sebelumnya menyebabkan hujan abu tebal di seluruh kota "
     "selama berminggu-minggu. Beberapa Misa dibatalkan dan umat diminta memakai masker.", "hujan abu vulkanik tebal"),
    ("PRS-09", "Hujan Deras dan Banjir", "Hujan deras masa Adven 2025", date(2025, 12, 13), date(2025, 12, 21), "Sedang",
     "Hujan lebat menjelang Natal menurunkan jumlah umat yang hadir pada Misa Adven.", "hujan deras"),
    ("PRS-10", "Hujan Deras dan Banjir", "Banjir Juli 2026", date(2026, 7, 4), date(2026, 7, 12), "Sedang",
     "Banjir di beberapa lingkungan, kemudian ditindaklanjuti dengan penggalangan Dana Solidaritas Kemanusiaan.", "banjir"),
]

# Typical share of the usual attendance that still comes, by severity.
ATTENDANCE_FACTOR = {"Ringan": 0.90, "Sedang": 0.78, "Berat": 0.60}


def event_on(day):
    """The event that covers a date, or None. Windows never overlap."""
    for event in EVENTS:
        if event[3] <= day <= event[4]:
            return event
    return None


def build():
    return {
        f"{SCHEMA}.PERISTIWA_LUAR_BIASA": [
            {
                "ID_PERISTIWA": i,
                "JENIS_PERISTIWA": kind,
                "NAMA_PERISTIWA": name,
                "TANGGAL_MULAI": start,
                "TANGGAL_SELESAI": end,
                "TINGKAT_GANGGUAN": severity,
                "DESKRIPSI": description,
            }
            for i, kind, name, start, end, severity, description, _ in EVENTS
        ]
    }
