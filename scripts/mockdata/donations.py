"""Domain 4.4: special occasion donations summarised per region.

Participating households are derived from the parishioner assignments, so a
region can never report more participating households than it had on the last
day of the collection period. The data is descriptive only: it must never be
used to rank regions.
"""

from datetime import date, timedelta

from . import config, util
from .parish import active_households_by_region
from .reference import WILAYAH
from .rng import Rng

SCHEMA = "DATA_OPERASIONAL"

# occasion id, period start, period end, average donation per participating household
PERIODS = [
    ("KSK-01", date(2025, 3, 5), date(2025, 4, 19), 120000),
    ("KSK-02", date(2025, 11, 30), date(2025, 12, 24), 95000),
    ("KSK-01", date(2026, 2, 18), date(2026, 4, 4), 130000),
    ("KSK-03", date(2026, 7, 6), date(2026, 7, 26), 105000),
]


def build(data):
    rng = Rng(config.SEED, "donations")
    rows = []
    for occasion, start, end, average in PERIODS:
        households = active_households_by_region(data, end)
        for region_id, _ in WILAYAH:
            eligible = households.get(region_id, 0)
            participants = max(1, min(eligible, int(eligible * (0.55 + rng.random() * 0.35) + 0.5)))
            amount = util.round_to(participants * rng.normal(average, average * 0.18), 5000)
            recorded = min(config.AS_OF, end + timedelta(days=rng.randint(3, 14)))

            status, note = "Sudah Divalidasi", None
            if occasion == "KSK-03":
                note = "Penggalangan dana tanggap darurat banjir (fiktif)."
                if region_id in ("WIL-02", "WIL-05"):
                    status, note = "Menunggu Validasi", "Menunggu bukti setoran dari ketua wilayah."
            elif start.year == 2026 and region_id == "WIL-04":
                status, note = "Perlu Dicek Ulang", "Nominal perlu dicek ulang terhadap bukti setoran."

            rows.append(
                {
                    "ID_SUMBANGAN": f"SMB-{util.pad(len(rows) + 1, 3)}",
                    "ID_WILAYAH": region_id,
                    "ID_KESEMPATAN": occasion,
                    "PERIODE_MULAI": start,
                    "PERIODE_SELESAI": end,
                    "JUMLAH_KELUARGA_PESERTA": participants,
                    "JUMLAH_SUMBANGAN": amount,
                    "TANGGAL_PENCATATAN": recorded,
                    "STATUS_VALIDASI": status,
                    "KETERANGAN": note,
                }
            )
    return {f"{SCHEMA}.SUMBANGAN_KESEMPATAN_KHUSUS": rows}
