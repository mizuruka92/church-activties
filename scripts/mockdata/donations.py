"""Domain 4.4: special occasion donations.

A CAMPAIGN (Lent, Advent, solidarity) collects gifts from households. Region
summaries are derived from the household gifts, so they always reconcile.

How the gifts are shaped (this is what the analysis use case looks for):

* every community has an economic capacity index (reference.EKONOMI). A
  household's gift scales with it, so poorer communities give less in total and
  per household
* in six of the poorer communities one household is a REGULAR LARGE DONOR who
  gives several times the usual gift every year. The community mean is lifted
  by this one gift while the median still shows the real level. Total, mean,
  median and amount per registered household therefore tell different stories
* each campaign points at the celebration or relief activity it funds, which
  allows a break-even analysis year by year (Easter keeps pace, Christmas costs
  more every year than Advent collects)

Nothing here ranks communities or says anything about faith: it describes
economic capacity and the shape of the distribution.
"""

from datetime import date, timedelta

from . import config, liturgy, planning, util
from .reference import ECONOMIC_INDEX, LINGKUNGAN_TO_WILAYAH, WILAYAH
from .rng import Rng

SCHEMA = "DATA_OPERASIONAL"

# Communities with one regular large donor (mostly the poorer ones).
REGULAR_DONOR_COMMUNITIES = ["LNG-05", "LNG-07", "LNG-12", "LNG-14", "LNG-03", "LNG-08"]

# Collected totals in rupiah. Easter costs grow a little faster than Lent gifts,
# Christmas costs grow much faster than Advent gifts.
LENT_TOTAL = {2021: 12_500_000, 2022: 14_000_000, 2023: 15_500_000, 2024: 16_500_000, 2025: 17_500_000, 2026: 18_500_000}
ADVENT_TOTAL = {2021: 11_000_000, 2022: 12_500_000, 2023: 14_000_000, 2024: 15_000_000, 2025: 16_000_000}
ADVENT_TARGET_2026 = 17_000_000


def lent_period(year):
    """Ash Wednesday to Holy Saturday."""
    sunday = liturgy.easter(year)
    return sunday - timedelta(days=46), sunday - timedelta(days=1)


def advent_period(year):
    """First Sunday of Advent to Christmas Eve."""
    day = date(year, 12, 24)
    while day.weekday() != 6:
        day -= timedelta(days=1)
    return day - timedelta(days=21), date(year, 12, 24)


def _campaign_specs():
    specs = []
    for year in range(config.HISTORY_START.year, config.AS_OF.year + 1):
        start, end = lent_period(year)
        specs.append({"occasion": "KSK-01", "year": year, "start": start, "end": end, "total": LENT_TOTAL[year],
                      "funds": "Paskah", "note": None})
        start, end = advent_period(year)
        specs.append({"occasion": "KSK-02", "year": year, "start": start, "end": end,
                      "total": ADVENT_TOTAL.get(year), "funds": "Natal", "note": None})
    specs.append({"occasion": "KSK-03", "year": 2025, "start": date(2025, 6, 16), "end": date(2025, 7, 6),
                  "total": 9_000_000, "funds": "Abu",
                  "note": "Penggalangan dana tanggap darurat hujan abu vulkanik (fiktif)."})
    specs.append({"occasion": "KSK-03", "year": 2026, "start": date(2026, 7, 6), "end": date(2026, 7, 26),
                  "total": 7_500_000, "funds": "Banjir", "note": "Penggalangan dana tanggap darurat banjir (fiktif)."})
    specs.sort(key=lambda spec: spec["start"])
    return specs


def _regular_donors(rng, links_by_family):
    """One stable household per chosen community: in the community since before the history starts."""
    chosen = {}
    for community in REGULAR_DONOR_COMMUNITIES:
        candidates = sorted(
            family for family, links in links_by_family.items()
            if len(links) == 1 and links[0]["ID_LINGKUNGAN"] == community
            and links[0]["TANGGAL_MULAI_BERLAKU"] < config.HISTORY_START and links[0]["TANGGAL_AKHIR_BERLAKU"] is None
        )
        chosen[community] = rng.choice(candidates)
    return chosen


def _link_at(links, day):
    for link in links:
        end = link["TANGGAL_AKHIR_BERLAKU"]
        if link["TANGGAL_MULAI_BERLAKU"] <= day and (end is None or day <= end):
            return link
    return None


def build(data):
    rng = Rng(config.SEED, "donations")
    occasion_name = {r["ID_KESEMPATAN"]: r["NAMA_KESEMPATAN"] for r in data["MASTER_DATA.REFERENSI_KESEMPATAN_KHUSUS"]}
    links_by_family = {}
    for link in data[f"{SCHEMA}.PENUGASAN_LINGKUNGAN"]:
        links_by_family.setdefault(link["ID_KELUARGA"], []).append(link)
    families = sorted(links_by_family)
    regular = _regular_donors(rng, links_by_family)
    funded_by = planning.funding_plans(data)

    campaigns, gifts, summaries = [], [], []
    for number, spec in enumerate(_campaign_specs(), start=1):
        campaign_id = f"KMP-{util.pad(number, 2)}"
        started = spec["start"] <= config.AS_OF
        finished = spec["end"] <= config.AS_OF
        total = spec["total"] if spec["total"] is not None else ADVENT_TARGET_2026
        campaigns.append(
            {
                "ID_KAMPANYE": campaign_id,
                "ID_KESEMPATAN": spec["occasion"],
                "NAMA_KAMPANYE": f"{occasion_name[spec['occasion']]} {spec['year']}",
                "PERIODE_MULAI": spec["start"],
                "PERIODE_SELESAI": spec["end"],
                "TARGET_DANA": util.round_to(total * 1.05, 500_000),
                "ID_RENCANA_PENGGUNAAN": funded_by.get((spec["funds"], spec["year"])),
                "STATUS_KAMPANYE": "Selesai" if finished else ("Berjalan" if started else "Direncanakan"),
                "KETERANGAN": spec["note"],
            }
        )
        if not started or spec["total"] is None:
            continue

        # --- who gives, and how much relative to the others ------------------------------
        span = (min(spec["end"], config.AS_OF) - spec["start"]).days
        givers = []
        for family in families:
            day = spec["start"] + timedelta(days=rng.randint(0, span))
            link = _link_at(links_by_family[family], day)
            if link is None:
                continue
            community = link["ID_LINGKUNGAN"]
            index = float(ECONOMIC_INDEX[community])
            is_regular = regular.get(community) == family
            participation = 0.97 if is_regular else min(0.92, max(0.5, 0.62 + 0.22 * (index - 1)))
            if not rng.chance(participation):
                continue
            weight = index * ((6 + 4 * rng.random()) if is_regular else (0.5 + rng.random()))
            givers.append((family, community, day, weight))
        campaign_total = spec["total"] * (0.97 + 0.06 * rng.random())
        unit = campaign_total / sum(weight for _, _, _, weight in givers)

        for family, community, day, weight in givers:
            gifts.append(
                {
                    "ID_SUMBANGAN_KELUARGA": f"SKL-{util.pad(len(gifts) + 1, 5)}",
                    "ID_KAMPANYE": campaign_id,
                    "ID_KELUARGA": family,
                    "ID_LINGKUNGAN": community,
                    "JUMLAH_SUMBANGAN": max(10_000, util.round_to(unit * weight, 5000)),
                    "TANGGAL_SUMBANGAN": day,
                }
            )

        # --- region summaries, derived from the gifts ----------------------------------------
        for region_id, _ in WILAYAH:
            mine = [g for g in gifts if g["ID_KAMPANYE"] == campaign_id and LINGKUNGAN_TO_WILAYAH[g["ID_LINGKUNGAN"]] == region_id]
            status, note = "Sudah Divalidasi", None
            if spec["occasion"] == "KSK-03" and spec["year"] == 2026 and region_id in ("WIL-02", "WIL-05"):
                status, note = "Menunggu Validasi", "Menunggu bukti setoran dari ketua wilayah."
            elif spec["occasion"] == "KSK-01" and spec["year"] == 2026 and region_id == "WIL-04":
                status, note = "Perlu Dicek Ulang", "Nominal perlu dicek ulang terhadap bukti setoran."
            elif spec["note"]:
                note = spec["note"]
            summaries.append(
                {
                    "ID_SUMBANGAN": f"SMB-{util.pad(len(summaries) + 1, 3)}",
                    "ID_KAMPANYE": campaign_id,
                    "ID_WILAYAH": region_id,
                    "JUMLAH_KELUARGA_PESERTA": len(mine),
                    "JUMLAH_SUMBANGAN": sum(g["JUMLAH_SUMBANGAN"] for g in mine),
                    "TANGGAL_PENCATATAN": min(config.AS_OF, spec["end"] + timedelta(days=rng.randint(3, 14))),
                    "STATUS_VALIDASI": status,
                    "KETERANGAN": note,
                }
            )

    return {
        f"{SCHEMA}.KAMPANYE_SUMBANGAN": campaigns,
        f"{SCHEMA}.SUMBANGAN_KELUARGA": gifts,
        f"{SCHEMA}.SUMBANGAN_KESEMPATAN_KHUSUS": summaries,
    }
