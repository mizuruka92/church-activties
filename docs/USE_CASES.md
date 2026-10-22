# Use cases: income versus outcome, unforeseen events, community donations, Easter and Christmas, a shadow forecast, public service guides

This guide describes seven stories that the simulated data was shaped to support, the views
that answer them, and what to look at. It exists so that the next phase (the Streamlit dashboard) can
be built on questions that already have answers.

> **Everything here is simulated.** The parish, the amounts and the events are fictional. The numbers
> in this guide were produced by running the committed SQL on a **local DuckDB stand-in**, not in
> Snowflake (nothing has been executed in Snowflake yet; see the README). They are deterministic, so
> Snowflake should return the same values, but that has not been verified. The stories are
> deliberately clean so that they are easy to present. Real data will be messier.

| # | Question | Main views |
|---|---|---|
| 1 | Is the offertory still larger than what the parish spends, and for how long? | `PEMASUKAN_PENGELUARAN_BULANAN`, `PEMASUKAN_PENGELUARAN_TAHUNAN`, `PROYEKSI_PEMASUKAN_PENGELUARAN` |
| 2 | What moves the offertory from week to week? | `POLA_KOLEKTE_HARI_DALAM_BULAN`, `KORELASI_KOLEKTE_KEHADIRAN`, `KEHADIRAN_MISA_BULANAN`, `KOLEKTE_MISA_BULANAN` |
| 3 | What did an unforeseen event (rain, haze, ash) do, and how does it bias a forecast? | `KOLEKTE_MINGGUAN_DAN_PERISTIWA`, `DAMPAK_PERISTIWA_LUAR_BIASA` |
| 4 | How do Lent and Advent gifts differ between communities, and do they cover the Easter and Christmas celebrations? | `SUMBANGAN_KELUARGA_PER_LINGKUNGAN`, `TITIK_IMPAS_KAMPANYE` |
| 5 | What is coming up, and which activities still need a date, a place or a decision? | `KEGIATAN_MENDATANG` |
| 6 | How good is a forecast of the weekly offertory made four weeks ahead, and which unforeseen events explain its misses? | `KOLEKTE_AKTUAL_VS_PERKIRAAN`, `BIAS_PERKIRAAN_PER_PERISTIWA`, `AKURASI_PERKIRAAN_TAHUNAN` |
| 7 | What do I need, and what do I do, to be baptised, confirmed, married, to join a community or when someone dies? | `LAYANAN_PUBLIK`, `LANGKAH_LAYANAN_PUBLIK`, `PERSYARATAN_LAYANAN_PUBLIK` |

All views carry the column `SUMBER_DATA = 'Data simulasi (fiktif)'`. The queries below use fully
qualified names, so they work in any worksheet once the setup has run.

## How the data was shaped

The generator builds the story from a few explicit assumptions and then adds noise. These are the
knobs, in case you want a different story. After changing one, run
`python scripts/generate_mock_data.py` and `python -m unittest discover -s tests`, then reload.

| Assumption | Where | Value in the bundled data |
|---|---|---|
| History | `config.py` | 1 January 2021 to the snapshot 30 September 2026; plans for 2021 to 2026 |
| Attendance level per year (1.0 = 2026) | `liturgy.ATTENDANCE_KNOTS` | 0.90, 0.94, 0.97, 0.99, 1.00, 1.00 for 2021 to 2026: growth that flattens |
| Offertory per attendee | `liturgy.PER_ATTENDEE_MEAN`, `PER_ATTENDEE_KNOTS` | Mean per collection type, same flattening curve |
| Payday effect | `liturgy.payday_factor` | 1.20 on the 1st of the month, falling in a straight line to 0.80 on the 31st |
| Noise | `liturgy.py` | Attendance about 11 %, amount per attendee about 3 % |
| Unforeseen events | `peristiwa.EVENTS`, `ATTENDANCE_FACTOR` | 10 events, attendance factor 0.90 / 0.78 / 0.60 for light / medium / severe |
| Shadow forecast | `forecast.py` | 4 weeks ahead, 52-week window (at least 26), 80% range widened by 20%, calendar rule of thumb `FEAST_RULE_OF_THUMB` |
| Service guides | `layanan.py` | 6 services with 6 to 9 steps and 6 to 10 requirements each |
| Number of programmes per year | `planning.ACTIVITY_COUNT` | 14, 19, 25, 31, 36 for 2021 to 2025, then the hand-written 2026 plan |
| Programme spending per year | `planning.SPEND_TARGET` | Rp 55 M, 90 M, 125 M, 165 M, 210 M for 2021 to 2025 |
| Easter and Christmas budgets | `planning.BIG_BUDGET` | Easter Rp 7 M rising to 17.5 M, Christmas Rp 9.5 M rising to 29 M |
| Lent and Advent collected | `donations.LENT_TOTAL`, `ADVENT_TOTAL` | Lent Rp 12.5 M rising to 18.5 M, Advent Rp 11 M rising to 16 M |
| Economic capacity per community | `reference.EKONOMI` | 18 communities, index 0.50 to 1.70, four categories |
| Communities with a regular large donor | `donations.REGULAR_DONOR_COMMUNITIES` | six communities, mostly the lower-capacity ones |

## 1. Income versus outcome

**Income** here is the offertory (`PEMASUKAN_KOLEKTE`) and, shown separately, the special donations
(`PEMASUKAN_SUMBANGAN_KHUSUS`). **Outcome** is the programme spending recorded against annual plans
(`PENGELUARAN_PROGRAM`). Running costs outside the plans are not modelled.

```sql
SELECT TAHUN, STATUS_TAHUN, PEMASUKAN_KOLEKTE, PENGELUARAN_PROGRAM,
       SELISIH_KOLEKTE_VS_PENGELUARAN, PERSEN_PENGELUARAN_TERHADAP_KOLEKTE,
       PERTUMBUHAN_KOLEKTE_PERSEN, PERTUMBUHAN_PENGELUARAN_PERSEN,
       PERTUMBUHAN_KOLEKTE_PER_MISA_TANPA_PERISTIWA_PERSEN
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.PEMASUKAN_PENGELUARAN_TAHUNAN
ORDER BY TAHUN;
```

| Year | Offertory (Rp M) | Programme spending (Rp M) | Spending as % of offertory | Offertory growth | Spending growth | Per-Mass growth without events |
|---|---:|---:|---:|---:|---:|---:|
| 2021 | 247.9 | 55.1 | 22 % | | | |
| 2022 | 262.4 | 90.8 | 35 % | +5.9 % | +64.9 % | +7.3 % |
| 2023 | 272.8 | 126.0 | 46 % | +3.9 % | +38.7 % | +4.3 % |
| 2024 | 296.6 | 163.4 | 55 % | +8.7 % | +29.7 % | +2.7 % |
| 2025 | 283.3 | 196.5 | 69 % | -4.5 % | +20.3 % | +1.1 % |
| 2026 (9 months) | 217.7 | 167.6 | 77 % | not comparable | not comparable | about 0 % |

How to read it:

* The offertory is **still larger than spending in every year**, as intended. The gap shrinks from
  Rp 193 M (2021) to Rp 87 M (2025) and Rp 50 M over the first nine months of 2026.
* The raw offertory growth jumps around (+8.7 % then -4.5 %) because the 2025 ash event removed
  several weeks of offertory. The last column removes the effect of the events and shows the
  underlying trend: growth per Mass slows steadily towards zero. Showing both columns side by side
  is the point of the use case.
* Spending growth is positive every year while the growth rate itself falls, because a larger
  programme base is added to each year. Spending still grows by Rp 33 to 37 M every year in absolute terms.
* `STATUS_TAHUN` and `TAHUN_LENGKAP` mark 2026 as a partial year. Do not compare it with full years.

### The forecast

`PROYEKSI_PEMASUKAN_PENGELUARAN` fits a straight line through the complete years 2021 to 2025 for
each series and projects five years ahead.

```sql
SELECT TAHUN, JENIS_DATA, KOLEKTE_TREN, PENGELUARAN_TREN,
       SELISIH_TREN_KOLEKTE_VS_PENGELUARAN, TREN_PENGELUARAN_MELEBIHI_KOLEKTE,
       TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE, CATATAN_METODE
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.PROYEKSI_PEMASUKAN_PENGELUARAN
ORDER BY TAHUN;
```

| Year | Offertory trend (Rp M) | Spending trend (Rp M) | Difference (Rp M) |
|---|---:|---:|---:|
| 2026 | 304.1 | 233.0 | 71.1 |
| 2027 | 314.6 | 268.5 | 46.0 |
| 2028 | 325.1 | 304.1 | 21.0 |
| **2029** | **335.6** | **339.6** | **-4.1** |
| 2030 | 346.0 | 375.1 | -29.1 |

The offertory trend grows by about Rp 10.5 M a year and the spending trend by about Rp 35.5 M a year,
so the lines cross in **2029**, three years after the snapshot. This is the requested "forecast three
years ahead" picture.

Two caveats are built into the view and should be said out loud in a presentation:

* The method is a straight line through five points. It ignores events and ignores that spending
  growth is itself slowing, so it is a demonstration of the idea, not a forecasting model.
* When the special donations are included, the total income stays above spending throughout the
  horizon (`TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_TOTAL_PEMASUKAN` is empty). The comparison with the
  offertory alone is the one the use case asks for; the donations are earmarked for specific
  celebrations (use case 4).

## 2. What drives the offertory

Offertory is generated as *attendance x amount per attendee x payday factor x noise*, so it is
linearly related to attendance and shifts with the day of the month by construction. The views let
you see both effects in the data.

**Day of the month.** Offertory per attendee is highest right after salary day and falls through the month:

```sql
SELECT TAHUN, KELOMPOK_TANGGAL, SUM(TOTAL_KOLEKTE) / SUM(TOTAL_UMAT) AS KOLEKTE_PER_UMAT
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.POLA_KOLEKTE_HARI_DALAM_BULAN
GROUP BY TAHUN, KELOMPOK_TANGGAL
ORDER BY TAHUN, KELOMPOK_TANGGAL;
```

In 2025 the offertory per attendee was Rp 21,485 on the 1st to 7th, 19,107 on the 8th to 14th,
18,458 on the 15th to 21st and 15,469 from the 22nd. The first week is about **1.3 to 1.4 times** the last
one, in every year.

**Attendance.** Within one Mass session and year, offertory follows attendance:

```sql
SELECT TAHUN, NAMA_MISA, JUMLAH_MISA, KORELASI_KOLEKTE_DENGAN_UMAT, R_KUADRAT_KOLEKTE_DARI_UMAT,
       TAMBAHAN_KOLEKTE_PER_UMAT, KORELASI_TANGGAL_DENGAN_KOLEKTE_PER_UMAT
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.KORELASI_KOLEKTE_KEHADIRAN
ORDER BY TAHUN, NAMA_MISA;
```

For sessions with at least 20 Masses in the year, the correlation between attendance and offertory
runs from 0.58 to 0.91 (average 0.78), and the correlation between the day of the month and the
offertory per attendee from -0.99 to -0.75. `TAMBAHAN_KOLEKTE_PER_UMAT` is the regression slope:
the extra rupiah that one more attendee goes with. The relationship is a statistical pattern for
planning and forecasting. It says nothing about the faith of the people who attend.

## 3. Unforeseen events and forecast bias

`PERISTIWA_LUAR_BIASA` is a short log of ten events from 2021 to 2026: heavy rain and flooding, haze,
volcanic ash and a power cut. Each has a type, a period, a severity (light, medium, severe) and a
description. The matching attendance records carry the event id and a note, so the event shows as a
labelled dip on a weekly line chart:

```sql
SELECT AWAL_PEKAN, TOTAL_UMAT, TOTAL_KOLEKTE,
       RATA_RATA_UMAT_8_PEKAN_SEBELUMNYA, RATA_RATA_KOLEKTE_8_PEKAN_SEBELUMNYA,
       PERSEN_UMAT_TERHADAP_8_PEKAN_SEBELUMNYA, NAMA_PERISTIWA, TINGKAT_GANGGUAN
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.KOLEKTE_MINGGUAN_DAN_PERISTIWA
ORDER BY AWAL_PEKAN;
```

Weeks start on Monday. `NAMA_PERISTIWA` is empty for normal weeks, so a chart can draw the line
and mark the weeks where the column is filled.

To explain what an event cost, and therefore why a forecast was off, use the impact view. It
compares each event with the average of the eight weeks before, for the same Mass sessions:

```sql
SELECT NAMA_PERISTIWA, TINGKAT_GANGGUAN, JUMLAH_MISA_DIBATALKAN,
       PERSEN_KEHADIRAN_TERHADAP_HARAPAN, PERSEN_KOLEKTE_TERHADAP_HARAPAN,
       PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.DAMPAK_PERISTIWA_LUAR_BIASA
ORDER BY TANGGAL_MULAI;
```

| Event | Severity | Attendance vs expectation | Offertory vs expectation | Estimated offertory not received (Rp M) |
|---|---|---:|---:|---:|
| Heavy flood, Feb 2021 | severe | 55 % | 53 % | 4.4 |
| Haze, Sep 2021 | medium | 82 % | 84 % | 3.1 |
| Heavy rain, Jan 2022 | light | 88 % | 83 % | 1.7 |
| Light ash fall, Nov 2022 | medium | 77 % | 72 % | 4.5 |
| Power cut, Mar 2023 | light | 91 % | 106 % | -0.3 |
| Very thick haze, Sep-Oct 2023 | severe | 48 % | 51 % | 18.7 |
| Flood, Feb 2024 | medium | 82 % | 86 % | 1.5 |
| Thick volcanic ash, Jun 2025 | severe | 39 % | 37 % | 21.7 |
| Heavy rain in Advent, Dec 2025 | medium | 77 % | 73 % | 3.0 |
| Flood, Jul 2026 | medium | 64 % | 69 % | 3.4 |

The severity orders the relative size of the dip: the three severe events came in at 37 to 55 % of the
expectation, the medium ones at 64 to 86 %, and the light ones at 83 % or more.

**An example of why such a baseline is rough.** The March 2023 power cut lowered attendance to 91 %
of the expectation, but the offertory came out at 106 %. The event fell on the first weekend of the
month, when the payday effect lifts the offertory per attendee by up to a third, and that hid the
dip. The impact view says so in its `CATATAN_METODE` column: *rough estimate, without correction for
payday and season*. This is exactly the kind of result a forecast bias discussion needs. A forecast
fitted without the event log would read the weeks of the severe events (autumn 2023 and mid 2025,
Rp 18.7 M and Rp 21.7 M not received) as real changes in the trend, and the log is what lets you
say otherwise.

The effect size is not stored anywhere in the data. The generator applies it, and the views have
to rediscover it from the numbers, as an analyst would have to with real data.

## 4. Special donations: communities, then Easter and Christmas

### 4a. The economic mapping of communities

`PROFIL_EKONOMI_LINGKUNGAN` gives each of the 18 communities an economic category (*Rendah*,
*Menengah Bawah*, *Menengah Atas*, *Tinggi*) and a capacity index from 0.50 to 1.70. A household's
gift scales with the index of its community. In six of the lower-capacity communities one household
is a **regular large donor**: it gives several times the usual gift in every campaign. Nothing in the
data marks these households.

```sql
SELECT NAMA_LINGKUNGAN, KATEGORI_EKONOMI, INDEKS_KAPASITAS_EKONOMI, JUMLAH_KELUARGA_PENYUMBANG,
       TOTAL_SUMBANGAN, RATA_RATA_PER_KELUARGA_PENYUMBANG, MEDIAN_PER_KELUARGA_PENYUMBANG,
       SELISIH_RATA_RATA_DARI_MEDIAN_PERSEN, PERSEN_TOTAL_DARI_SUMBANGAN_TERBESAR,
       SUMBANGAN_PER_KELUARGA_TERDAFTAR, SUMBANGAN_PER_UMAT_TERDAFTAR
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.SUMBANGAN_KELUARGA_PER_LINGKUNGAN
WHERE NAMA_KAMPANYE = 'Aksi Puasa Pembangunan 2025'
ORDER BY INDEKS_KAPASITAS_EKONOMI;
```

Lent 2025, selected communities (amounts in rupiah):

| Community | Category | Donors | Total | Mean per donor | Median per donor | Mean above median | Largest gift as % of total |
|---|---|---:|---:|---:|---:|---:|---:|
| Santo Gregorius | Rendah | 8 | 705,000 | 88,125 | 47,500 | +86 % | 52 % |
| Santo Dominikus | Rendah | 7 | 955,000 | 136,429 | 75,000 | +82 % | 58 % |
| Santo Benediktus | Menengah Bawah | 4 | 1,085,000 | 271,250 | 122,500 | +121 % | 71 % |
| Santa Veronika | Menengah Bawah | 9 | 760,000 | 84,444 | 90,000 | -6 % | 15 % |
| Santo Nikolas | Menengah Atas | 7 | 915,000 | 130,714 | 130,000 | +0.5 % | 21 % |
| Santa Agnes | Tinggi | 8 | 1,405,000 | 175,625 | 175,000 | 0 % | 18 % |

What it shows:

* **Mean versus median.** In the six communities with a regular large donor, the largest single gift
  is 49 to 71 % of the community's total. The mean is lifted, the median stays at the level of the
  typical household, and `SELISIH_RATA_RATA_DARI_MEDIAN_PERSEN` makes the gap visible (+42 % to
  +121 % in Lent 2025). In the other communities the largest gift is 12 to 37 % of the total, and mean and
  median stay within -6 % to +20 % of each other. Santo Dominikus, a *Rendah* community, has a mean of Rp 136,429, which looks
  better than that of most communities, while its median of Rp 75,000 is among the lowest of all
  18. Only the median describes the typical household. Over all 13 campaigns that collected gifts, the
  average gap between mean and median is +99 % in the six communities with a regular large donor
  and +1 % elsewhere.
* **Total versus per head.** The total depends on how many people a community has. Santa Agnes has
  the second-highest total (Rp 1,405,000) but 46 registered people, which gives Rp 30,543 per person;
  Santa Katarina collects less (Rp 1,240,000) from 28 people, which gives Rp 44,286 per person.
  Santo Dominikus has only 20 registered people, so a total near that of the *Menengah Atas*
  community Santa Klara (Rp 955,000 against 960,000) comes to Rp 47,750 per person against
  Rp 32,000. `SUMBANGAN_PER_KELUARGA_TERDAFTAR` and `SUMBANGAN_PER_UMAT_TERDAFTAR` divide by all
  registered households and people, not only by the donors, so they also show participation.
* The communities with few donors (4 to 9) give noisy figures. A real deployment should merge or
  suppress very small groups before showing them.

The view has **no rank column** and its `CATATAN_PENGGUNAAN` column says that the numbers describe
economic capacity and the shape of the gifts, not faith or generosity, and must not be used to
rank communities. Please keep it that way in any chart: sort alphabetically or by region, not by
amount.

### 4b. Do the donations cover Easter and Christmas?

Each Lent campaign points at the Easter celebration of its year and each Advent campaign at the
Christmas celebration (`KAMPANYE_SUMBANGAN.ID_RENCANA_PENGGUNAAN`). The break-even view joins the
amount collected with the actual cost of that celebration:

```sql
SELECT TAHUN, NAMA_KESEMPATAN, TOTAL_SUMBANGAN, BIAYA_AKTUAL,
       SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL, PERSEN_BIAYA_TERTUTUP_SUMBANGAN,
       PEMASUKAN_BERSIH_UNTUK_GEREJA, DANA_TAMBAHAN_DARI_GEREJA, STATUS_TITIK_IMPAS
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.TITIK_IMPAS_KAMPANYE
ORDER BY TAHUN, NAMA_KESEMPATAN;
```

| Year | Campaign | Collected (Rp M) | Actual cost (Rp M) | Difference (Rp M) | Covered | Result |
|---|---|---:|---:|---:|---:|---|
| 2021 | Lent for Easter | 12.6 | 6.9 | +5.7 | 182 % | surplus |
| 2021 | Advent for Christmas | 11.1 | 9.5 | +1.6 | 117 % | surplus |
| 2022 | Lent | 14.0 | 9.1 | +4.9 | 154 % | surplus |
| 2022 | Advent | 12.7 | 12.6 | +0.1 | 101 % | about break-even |
| 2023 | Lent | 15.8 | 11.0 | +4.8 | 143 % | surplus |
| 2023 | Advent | 13.8 | 16.1 | -2.4 | 85 % | **deficit** |
| 2024 | Lent | 16.9 | 13.5 | +3.4 | 125 % | surplus |
| 2024 | Advent | 14.8 | 20.6 | -5.8 | 72 % | **deficit** |
| 2025 | Lent | 17.3 | 15.6 | +1.7 | 111 % | surplus |
| 2025 | Advent | 16.3 | 24.7 | -8.4 | 66 % | **deficit** |
| 2026 | Lent | 18.7 | 17.3 | +1.5 | 108 % | surplus |
| 2026 | Advent (planned) | target 18.0 | budget 29.1 | -11.1 | | projected deficit |

How it reads:

* **Surplus** (`PEMASUKAN_BERSIH_UNTUK_GEREJA`): the part of the donations that the celebration did
  not use becomes church income. Easter stays in surplus every year, but the cushion shrinks from
  182 % to 108 % coverage, because the Easter budget grows faster than the Lent gifts.
* **Deficit** (`DANA_TAMBAHAN_DARI_GEREJA`): the church has to add its own money. Christmas drops
  below break-even from 2023 and the shortfall widens every year, from Rp 2.4 M to Rp 8.4 M.
* For a campaign that is still planned, the actual cost does not exist yet, so the status says the
  comparison cannot be made, and `PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI` compares the target with the
  planned budget instead. For Advent 2026 even reaching the target would leave Rp 11.1 M uncovered.
* The two relief campaigns (ash 2025, flood 2026) appear in the same view. The 2025 one roughly
  covered its cost; the 2026 one covered 58 %.

Regional summaries (`SUMBANGAN_KHUSUS_PER_WILAYAH`) are derived from the household gifts, so the
totals match. The demo includes some regions whose summary is still waiting for validation, or marked
for re-checking.

## 5. Upcoming activities: the step between plan and report

An activity has a life: it starts as a line in the **annual plan** with a budget, becomes a **scheduled event** with a date, a place and a
participant target, and ends as a **held event with a report**. The first and the last step were already visible. `KEGIATAN_MENDATANG`
shows the middle one: everything that has not been carried out yet.

```sql
SELECT TANGGAL_MULAI, NAMA_PROGRAM, NAMA_SEKSI, TAHAP, HARI_DARI_TANGGAL_DATA, LOKASI, TARGET_PESERTA, ANGGARAN_RENCANA,
       DIDANAI_KAMPANYE, SELISIH_TARGET_DANA_VS_ANGGARAN, CATATAN_KEGIATAN
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.KEGIATAN_MENDATANG
ORDER BY TANGGAL_MULAI;
```

Each row is one plan that has not been carried out. `TAHAP` has three values:

| Stage | Meaning | In the demo (data date 30 September 2026) |
|---|---|---:|
| Sudah dijadwalkan | An event exists, with date, place and participant target | 3 (11, 17 and 24 October) |
| Masih rencana tahunan | Only the annual plan and its budget exist | 8 (7 November to 24 December, including Christmas) |
| Ditunda, perlu jadwal baru | Postponed this year and not yet rescheduled; `CATATAN_KEGIATAN` gives the reason | 4 (July to September) |

What it shows:

* The 11 activities still ahead carry Rp 85.7 M of planned budget. Only three of them are registered as events yet; the other eight
  have no place and no participant target.
* **Christmas is the activity to watch.** *Rangkaian Perayaan Natal* (24 December) is budgeted at Rp 29.1 M, while the Advent campaign that
  pays for it targets Rp 18.0 M, so even a campaign that reaches its target leaves Rp 11.1 M to be covered from church funds
  (`SELISIH_TARGET_DANA_VS_ANGGARAN`). This is the forward-looking side of use case 4.
* Three activities fall within 45 days of the data date and are still only plans. The dashboard lists them so that someone fixes a place and a
  target in time.
* The four postponed activities each carry the reason recorded at the time (supplier quote pending, equipment not available, clash with school
  exams, speaker unavailable).

"Upcoming" is counted from the snapshot date in `MASTER_DATA.INFO_DATASET`, never from the clock, so the demo gives the same answer on any day. With
real data that date would be replaced by `CURRENT_DATE`. The Masses scheduled after the snapshot are in `PELAKSANAAN_MISA` with the status
*Terjadwal* (25 in October 2026) and appear on the second tab of the dashboard page.

## 6. A shadow forecast of the weekly offertory

A **shadow** forecast runs next to the real process and never changes it. Every week from August 2021, a simple model forecasts the offertory of
the week that begins four weeks later, using only what was known that day, and the forecast is **stored as issued** (`PERKIRAAN_KOLEKTE_MINGGUAN`).
Later, once the week has been collected, the stored forecast can be set against the real total without any chance of having peeked.

```sql
-- Week by week: forecast, range and actual, with the event that explains a big miss
SELECT AWAL_PEKAN, JUMLAH_PERKIRAAN, BATAS_BAWAH, BATAS_ATAS, KOLEKTE_AKTUAL, SELISIH_PERSEN, POSISI_TERHADAP_RENTANG, JENIS_PEKAN, NAMA_PERISTIWA
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.KOLEKTE_AKTUAL_VS_PERKIRAAN
ORDER BY AWAL_PEKAN;

-- Each unforeseen event: how far did it pull the offertory below the forecast?
SELECT NAMA_PERISTIWA, TINGKAT_GANGGUAN, JUMLAH_PEKAN_TERDAMPAK, PERKIRAAN_TOTAL, KOLEKTE_AKTUAL_TOTAL, SELISIH_PERSEN, KELIPATAN_GALAT_BIASA
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.BIAS_PERKIRAAN_PER_PERISTIWA
ORDER BY TANGGAL_MULAI;

-- Accuracy per year and kind of week
SELECT TAHUN, JENIS_PEKAN, JUMLAH_PEKAN, GALAT_RATA_RATA_PERSEN, SELISIH_RATA_RATA_PERSEN, PERSEN_DALAM_RENTANG
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.AKURASI_PERKIRAAN_TAHUNAN
ORDER BY TAHUN, JENIS_PEKAN;
```

**What the model knows and does not know.** It sees the offertory of every complete week before its origin (a rolling window of 52 weeks), the
public liturgical calendar (Easter, feast days, the special collections), and the events already logged. The weeks those events disturbed are left
out of what it learns from, so a past disaster does not pull later forecasts down. It cannot know an event that has not started, which is exactly why
an event shows up as a large gap. The size of the calendar adjustments is a rule of thumb of the parish staff, deliberately a little different from the
true effect built into the data.

**What it shows (data date 30 September 2026).** 269 weeks can be compared, from August 2021:

| Kind of week | Weeks | Average error | Weeks inside the 80% range |
|---|---:|---:|---:|
| Ordinary week | 205 | 7.4 % | 82 % |
| Feast or special-collection week (calendar adjustment) | 36 | 7.8 % | 86 % |
| Week hit by an unforeseen event | 28 | 31.2 % | 21 % |

* **Ordinary weeks are forecast well, and not perfectly.** 41 weeks with no logged event still fall outside the 80% range (about one in six), as an 80% range allows. The dashboard lists them in a table instead of hiding them.
* **Events explain the big misses.** The 2025 volcanic ash (`PRS-08`) left the five affected weeks 55 % below the forecast (7.5 times the usual error) and the
  thick haze of autumn 2023 (`PRS-06`) 51 % below (6.9 times). In both, every affected week was outside the range. The flood of July 2026 was 34 % below.
* **A dip can be invisible in money.** The one-day power cut of March 2023 (`PRS-05`) is only 0.4 % off: the week fell just after payday, and the forecast already
  counts the payday bonus. Attendance fell, but the offertory did not move enough to show. This is the same masking effect described in use case 3.
* **A forecast must not learn from the disaster.** Fitting on the disturbed weeks as well biases later forecasts more than 8 % low (a test shows it), which is why the
  event log is used to keep those weeks out of training.
* **The forecast for the weeks ahead is not a promise.** The week in progress and the next four have a forecast but no actual value yet (`STATUS_PEKAN`).

The same chart (actual offertory solid, forecast dashed, 80% range as a band) is shown on the **Kolekte** tab of "Kolekte dan kehadiran" and, for the offertory, on "Peristiwa luar biasa". The dashboard page **Perkiraan kolekte** adds the accuracy figures and the event gaps around it. It draws the actual offertory against the forecast with its range, shades the weeks hit by an event, never ranks anything,
and shows each event's gap beside the usual error. Offertory figures are administrative; they say nothing about faith or commitment.

## 7. Public service guides

The parish answers the same questions again and again: *what do I need for an adult baptism? how do I register in a community? what do we do now that
Grandpa has died?* The guides put the **requirements** and the **steps** of six services in tables and in PDFs that anyone may read:

| Service | Category | Steps | Requirements |
|---|---|---:|---:|
| Baptis Dewasa | Sakramen | 9 | 9 |
| Baptis Batuta (bayi dan anak di bawah 7 tahun) | Sakramen | 7 | 8 |
| Krisma | Sakramen | 6 | 8 |
| Pernikahan | Sakramen | 9 | 10 |
| Pendaftaran Lingkungan | Administrasi Umat | 6 | 6 |
| Pelayanan Kematian (Tutup Usia) | Pelayanan Duka | 9 | 7 |

```sql
SELECT NAMA_LAYANAN, KATEGORI_LAYANAN, PERKIRAAN_WAKTU_PROSES, JUMLAH_LANGKAH, JUMLAH_PERSYARATAN, NAMA_BERKAS_PANDUAN
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.LAYANAN_PUBLIK
ORDER BY ID_LAYANAN;

SELECT NOMOR_URUT, JUDUL_LANGKAH, PELAKU, URAIAN
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.LANGKAH_LAYANAN_PUBLIK
WHERE NAMA_LAYANAN LIKE 'Pelayanan Kematian%'
ORDER BY NOMOR_URUT;
```

* The tables are *Publik*; the public views show only services whose classification may be shown in public, so reclassifying a service hides the service with all its steps.
* Every guide says that it is an **example**, written for the demonstration. The wording is generic and does not claim to be the rule of any diocese or parish. No telephone number
  or other contact detail is included, only the office hours of the fictional secretariat.
* The bereavement guide starts *before* the death (calling the priest for the anointing of the sick), then covers the notice to the community leader and the secretariat, the death
  certificate, prayers at home, the funeral Mass, the entry in the register and the memorial Masses.
* The family registration guide asks for consent to record household data as restricted data, which links the guide to the privacy model.
* The PDFs in `app/public_documents/` are generated from the same rows, so the page and the document say the same thing (a test reads each PDF back and finds every step and requirement).

The dashboard page **Layanan dan prosedur** lets a visitor pick a service, read its requirements and steps, and download the PDF when the file is next to the app.

## Judgement calls

These are choices made while implementing the request. Please say if you want any of them changed.

1. **No real place names.** The request mentions haze and ash affecting Jakarta. The data uses generic
   wording ("kabut asap", "hujan abu vulkanik") and names no city or volcano, because the demo parish
   must not look like a real one. The event log supports a place column later if you want it.
2. **Economics per community, not per household.** The request asked for a household mapping, ideally
   per community. Only the community level is stored. A household-level wealth attribute would be the
   most sensitive field in the model, and the analysis does not need it: the shape of the gifts
   already shows the effect. A household attribute can be added later with an explicit
   classification and access rule.
3. **Household gifts are restricted data.** `SUMBANGAN_KELUARGA` is classified *Sangat Terbatas* and
   is never exposed by an analysis view, even in aggregate form that would identify a single gift.
4. **The effect of events is not stored.** Only the event log and a flag on the attendance records
   are stored. The impact is an estimate computed in a view, as it would be with real data.
5. **A simple forecast.** A straight line through five complete years. It is transparent and
   explainable, which suits the story; it is not a forecasting method.
6. **"Outcome" is programme spending.** Salaries, utilities and maintenance are not in the dataset.
7. **No ranking.** No view orders or ranks communities, regions or Mass sessions by amount.
8. **"Baptis Batuta" means babies and children under seven.** The request used the word *batuta*, which usually means a toddler. The guide covers infants and children under seven, who are baptised at their
   parents' request. If the parish uses the word differently, only the text of `LYN-02` changes.
9. **The guides are generic examples.** The steps and requirements are plausible but invented. The parish and the diocese decide the real ones, and each guide says so.
10. **The shadow forecast is simple on purpose.** A straight line, a payday term and a calendar adjustment, with a stored 80% range. It is meant to show how a forecast is kept honest (stored as issued, no peeking,
    events logged), not to be the best possible model. A second model could be added next to it in the same tables.
11. **The curves are designed.** The crossing in 2029 and the Christmas deficit are set by the
   assumptions in the table at the top. The tests check the shape of the story, not exact figures.

## Changing the data model of an existing Snowflake demo

These use cases added tables and columns (a new donation structure, an event log, an economic
profile, `KEHADIRAN_MISA.ID_PERISTIWA`). Setup step 2 uses `CREATE TABLE IF NOT EXISTS`, which
never alters an existing table. If you ran an earlier version of this repository in Snowflake, reset
the demo first (see `sql/99_reset_demo.sql`, option B or C), then run the setup again.

The shadow forecast and the service guides (use cases 6 and 7) only **add** tables and views. A demo that already has the tables above does not need a reset: run steps 2, 3, 4g, 5 and 6
(see [SETUP_SNOWFLAKE.md](SETUP_SNOWFLAKE.md)).
