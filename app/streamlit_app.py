"""Pusat Informasi Paroki: Streamlit dashboard (Phase 2 of the Parish Information Hub demo).

ALL DATA IS SIMULATED. The dashboard reads only the aggregated views of the ANALISIS schema,
never the detail tables, and it never shows an individual, a household or a single gift.

Where it runs
    * Streamlit in Snowflake (recommended): paste this file into a new Streamlit app in
      Snowsight, or create the app from the Git repository. No installation, no credentials.
    * Locally: `streamlit run app/streamlit_app.py` with a connection named "snowflake" in
      .streamlit/secrets.toml (kept out of Git). See app/README.md.

Design notes for developers
    * One file on purpose, so it can be pasted into the Snowsight editor.
    * Every query is `SELECT * FROM <DATABASE>.ANALISIS.<VIEW>`. Filtering and charting happen
      in pandas, because the views are small. To use another database name, change DATABASE.
    * The code sticks to Streamlit, pandas and Altair features that exist in older releases
      (Python 3.9 syntax, no st.navigation, no Altair 5-only encodings), because the versions
      available in a Snowflake account differ.
    * `run_query` is the only function that talks to Snowflake. The tests replace it.
    * All text shown to users is Bahasa Indonesia; code and comments are English.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

import altair as alt
import pandas as pd
import streamlit as st

DATABASE = "PUSAT_INFORMASI_PAROKI"
SCHEMA = "ANALISIS"
CACHE_SECONDS = 600
PREPARATION_DAYS = 45  # an activity closer than this that is still only a plan needs a place and a target soon
DATA_LABEL = "Data simulasi (fiktif)"

# The only views this dashboard may read. A test checks that each one exists in sql/05.
VIEWS = (
    "ANGGARAN_VS_REALISASI_PROGRAM",
    "ANGGARAN_VS_REALISASI_SEKSI",
    "DAMPAK_PERISTIWA_LUAR_BIASA",
    "HASIL_SURVEI",
    "KEGIATAN_DAN_LAPORAN",
    "KEGIATAN_MENDATANG",
    "KEHADIRAN_MISA_BULANAN",
    "KELENGKAPAN_LAPORAN_PER_SEKSI",
    "KOLEKTE_MINGGUAN_DAN_PERISTIWA",
    "KOLEKTE_MISA_BULANAN",
    "KORELASI_KOLEKTE_KEHADIRAN",
    "PELAKSANAAN_MISA",
    "PEMASUKAN_PENGELUARAN_BULANAN",
    "PEMASUKAN_PENGELUARAN_TAHUNAN",
    "POLA_KOLEKTE_HARI_DALAM_BULAN",
    "PROYEKSI_PEMASUKAN_PENGELUARAN",
    "RINGKASAN_SKOR_LIKERT",
    "SUMBANGAN_KELUARGA_PER_LINGKUNGAN",
    "SUMBANGAN_KHUSUS_PER_WILAYAH",
    "TITIK_IMPAS_KAMPANYE",
    "TREN_KEHADIRAN_PERIODE",
)

MONTHS = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus",
          "September", "Oktober", "November", "Desember"]

# Chart colours: the first three slots of a validated categorical palette, in order.
# Light and dark steps are chosen separately (see docs/DASHBOARD.md).
PALETTES = {
    "light": ["#2a78d6", "#eb6834", "#1baf7a"],
    "dark": ["#3987e5", "#d95926", "#199e70"],
}
NEUTRAL = "#898781"
INK = {"light": "#0b0b0b", "dark": "#f0efec"}  # text drawn inside charts follows the theme


# --------------------------------------------------------------------------------------------
# Data access
# --------------------------------------------------------------------------------------------
def _active_snowflake_session():
    """The session of Streamlit in Snowflake, or None when running anywhere else."""
    try:
        from snowflake.snowpark.context import get_active_session

        return get_active_session()
    except Exception:  # noqa: BLE001 - no Snowpark, or no active session
        return None


def run_query(sql):
    """Run one SQL statement and return a pandas DataFrame. The only function that reaches Snowflake."""
    session = _active_snowflake_session()
    if session is not None:
        return session.sql(sql).to_pandas()
    return st.connection("snowflake").query(sql, ttl=0)


def _normalise(frame):
    """Upper-case column names, decimals to numbers, dates to timestamps (Snowflake and DuckDB differ)."""
    frame = frame.copy()
    frame.columns = [str(name).upper() for name in frame.columns]
    for name in frame.columns:
        values = frame[name].dropna()
        if values.empty or values.map(lambda v: isinstance(v, bool)).any():
            continue
        if values.map(lambda v: isinstance(v, (Decimal, int, float))).all():
            frame[name] = pd.to_numeric(frame[name], errors="coerce")
        elif values.map(lambda v: isinstance(v, (date, datetime, pd.Timestamp))).all():
            frame[name] = pd.to_datetime(frame[name])
    return frame


@st.cache_data(ttl=CACHE_SECONDS, show_spinner=False)
def load_view(name):
    if name not in VIEWS:
        raise ValueError(f"{name} is not a view this dashboard is allowed to read")
    return _normalise(run_query(f"SELECT * FROM {DATABASE}.{SCHEMA}.{name}"))


def get(name):
    """Load a view, or stop the page with a plain explanation when Snowflake cannot be reached."""
    try:
        return load_view(name)
    except Exception as error:  # noqa: BLE001 - shown to the user, then the page stops
        st.error(
            "Data belum dapat dimuat dari Snowflake. Pastikan penyiapan data sudah selesai "
            "(langkah 1 sampai 6 pada panduan) dan aplikasi memakai gudang data (warehouse) yang aktif."
        )
        with st.expander("Detail teknis untuk pengelola"):
            st.code(f"{type(error).__name__}: {error}")
        st.stop()


# --------------------------------------------------------------------------------------------
# Formatting (Indonesian conventions: thousands with a dot, decimals with a comma)
# --------------------------------------------------------------------------------------------
def _missing(value):
    return value is None or (not isinstance(value, str) and bool(pd.isna(value)))


def number(value, digits=0):
    if _missing(value):
        return "-"
    text = f"{float(value):,.{digits}f}"
    return text.replace(",", "\0").replace(".", ",").replace("\0", ".")


def rupiah(value):
    if _missing(value):
        return "-"
    return ("-" if float(value) < 0 else "") + "Rp " + number(abs(float(value)))


def juta(value, digits=1):
    if _missing(value):
        return "-"
    return ("-" if float(value) < 0 else "") + "Rp " + number(abs(float(value)) / 1_000_000, digits) + " jt"


def percent(value, digits=1):
    return "-" if _missing(value) else number(value, digits) + "%"


def signed_percent(value, digits=1):
    if _missing(value):
        return "-"
    return ("+" if float(value) > 0 else "") + number(value, digits) + "%"


def long_date(value):
    if _missing(value):
        return "-"
    return f"{value.day} {MONTHS[value.month - 1]} {value.year}"


def text(value):
    return "-" if _missing(value) else str(value)


def whole(value):
    return number(value, 0)


def clock(value):
    """Time of day as HH:MM from a time, a timedelta or text (Snowflake and DuckDB return different types)."""
    if _missing(value):
        return "-"
    if isinstance(value, pd.Timedelta):
        seconds = int(value.total_seconds())
        return f"{seconds // 3600:02d}:{seconds % 3600 // 60:02d}"
    if hasattr(value, "strftime"):
        return value.strftime("%H:%M")
    return str(value)[:5]


def days_away(days):
    if _missing(days):
        return "-"
    days = int(days)
    if days == 0:
        return "hari ini"
    return f"{days} hari lagi" if days > 0 else f"{-days} hari lalu"


def two_decimals(value):
    return number(value, 2)


# --------------------------------------------------------------------------------------------
# Presentation helpers
# --------------------------------------------------------------------------------------------
def _stretch(element, *args, **kwargs):
    """Call a Streamlit element at full width on old and new Streamlit releases."""
    try:
        return element(*args, width="stretch", **kwargs)
    except TypeError:
        return element(*args, use_container_width=True, **kwargs)


def show_table(frame, columns):
    """Show a table whose cells are already formatted. `columns` is a list of (column, label, formatter)."""
    shown = pd.DataFrame({label: [(formatter or text)(v) for v in frame[column]] for column, label, formatter in columns})
    try:
        _stretch(st.dataframe, shown, hide_index=True)
    except TypeError:
        _stretch(st.dataframe, shown)


def is_dark():
    try:
        return st.context.theme.type == "dark"
    except Exception:  # noqa: BLE001 - older Streamlit or no theme information
        try:
            return st.get_option("theme.base") == "dark"
        except Exception:  # noqa: BLE001
            return False


def palette():
    return PALETTES["dark" if is_dark() else "light"]


def ink():
    return INK["dark" if is_dark() else "light"]


def show_chart(chart, height=320):
    """Apply the shared chart style (thin marks, quiet grid, legend on top) and draw it."""
    styled = (
        chart.properties(height=height)
        .configure_axis(grid=True, gridColor=NEUTRAL, gridOpacity=0.25, gridWidth=1, domainColor=NEUTRAL,
                        domainOpacity=0.5, tickColor=NEUTRAL, tickOpacity=0.5, labelFontSize=12, titleFontSize=12,
                        titleFontWeight="normal")
        .configure_view(strokeWidth=0)
        .configure_legend(orient="top", labelFontSize=12, labelLimit=360, symbolStrokeWidth=3)
    )
    _stretch(st.altair_chart, styled)


def color_scale(labels):
    """Fixed colour per series label, in palette order, so a series keeps its colour on every chart."""
    return alt.Scale(domain=list(labels), range=palette()[: len(labels)])


def banner():
    st.info(
        "🧪 **DATA SIMULASI.** Seluruh angka, nama, dan peristiwa pada dasbor ini fiktif dan dibuat oleh program "
        "untuk demonstrasi. Tidak ada data nyata paroki."
    )


def how_to_read(*lines):
    with st.expander("Cara membaca halaman ini"):
        for line in lines:
            st.markdown("- " + line)


def complete_weeks(weekly):
    """Drop a first or last week that holds only part of the Masses (the data starts or ends mid-week)."""
    weekly = weekly.sort_values("AWAL_PEKAN").reset_index(drop=True)
    typical = weekly["JUMLAH_MISA_TERLAKSANA"].median()
    enough = (weekly["JUMLAH_MISA_TERLAKSANA"] >= 0.6 * typical).tolist()
    start, end = 0, len(enough)
    while start < end and not enough[start]:
        start += 1
    while end > start and not enough[end - 1]:
        end -= 1
    return weekly.iloc[start:end].reset_index(drop=True)


def week_year(frame):
    """Year of each week taken from its last day (Sunday), so a week that straddles New Year counts for the new year."""
    return (frame["AWAL_PEKAN"] + pd.Timedelta(days=6)).dt.year


def month_start(frame):
    """First day of the month for frames with TAHUN and BULAN columns."""
    parts = pd.DataFrame({"year": frame["TAHUN"].astype(int), "month": frame["BULAN"].astype(int), "day": 1})
    return pd.to_datetime(parts)


def year_range_slider(label, years):
    years = sorted(int(y) for y in years)
    if len(years) < 2:
        return years[0], years[0]
    return st.select_slider(label, options=years, value=(years[0], years[-1]))


# --------------------------------------------------------------------------------------------
# Charts
# --------------------------------------------------------------------------------------------
def income_outcome_chart(annual, projection):
    """Offertory and programme spending per year (solid, complete years) with the straight-line trend (dashed)."""
    actual = annual[annual["TAHUN_LENGKAP"].astype(bool)]
    rows = []
    for _, row in actual.iterrows():
        rows.append((int(row["TAHUN"]), "Kolekte", float(row["PEMASUKAN_KOLEKTE"]) / 1e6, "Aktual"))
        rows.append((int(row["TAHUN"]), "Pengeluaran program", float(row["PENGELUARAN_PROGRAM"]) / 1e6, "Aktual"))
    for _, row in projection.iterrows():
        rows.append((int(row["TAHUN"]), "Kolekte", float(row["KOLEKTE_TREN"]) / 1e6, "Garis tren dan proyeksi"))
        rows.append((int(row["TAHUN"]), "Pengeluaran program", float(row["PENGELUARAN_TREN"]) / 1e6, "Garis tren dan proyeksi"))
    frame = pd.DataFrame(rows, columns=["Tahun", "Seri", "Juta", "Jenis"])
    frame["Nilai"] = [f"Rp {number(v, 1)} jt" for v in frame["Juta"]]

    series = ["Kolekte", "Pengeluaran program"]
    kinds = ["Aktual", "Garis tren dan proyeksi"]
    base = alt.Chart(frame).encode(
        x=alt.X("Tahun:Q", axis=alt.Axis(format="d", title=None, tickMinStep=1)),
        y=alt.Y("Juta:Q", axis=alt.Axis(title="Juta rupiah"), scale=alt.Scale(zero=True)),
        color=alt.Color("Seri:N", scale=color_scale(series), legend=alt.Legend(title=None)),
        tooltip=[alt.Tooltip("Tahun:Q", format="d"), alt.Tooltip("Seri:N", title="Seri"),
                 alt.Tooltip("Nilai:N", title="Nilai"), alt.Tooltip("Jenis:N", title="Jenis")],
    )
    lines = base.mark_line(strokeWidth=2, strokeJoin="round", strokeCap="round").encode(
        strokeDash=alt.StrokeDash("Jenis:N", scale=alt.Scale(domain=kinds, range=[[1, 0], [6, 4]]),
                                  legend=alt.Legend(title=None)))
    points = base.transform_filter(alt.datum.Jenis == "Aktual").mark_point(filled=True, size=70, opacity=1)
    layers = [lines, points]

    crossing = projection["TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE"].dropna()
    if not crossing.empty:
        year = int(crossing.iloc[0])
        marker = pd.DataFrame({"Tahun": [year], "Teks": [f"Perkiraan titik silang: {year}"]})
        layers.append(alt.Chart(marker).mark_rule(color=NEUTRAL, strokeWidth=1).encode(x="Tahun:Q"))
        layers.append(alt.Chart(marker).mark_text(align="right", dx=-6, fontSize=12, color=NEUTRAL)
                      .encode(x="Tahun:Q", y=alt.value(12), text="Teks:N"))
    show_chart(alt.layer(*layers), height=340)


def line_chart(frame, x, series, y_title, height=300, date_axis=True):
    """Lines for one or more series. `frame` has the x column and one column per series label."""
    labels = list(series)
    long = frame[[x] + labels].melt(id_vars=x, var_name="Seri", value_name="Nilai")
    long = long.dropna(subset=["Nilai"])
    long["Teks"] = [number(v, 1) for v in long["Nilai"]]
    if date_axis:
        long["Waktu"] = [long_date(v) if hasattr(v, "month") else str(v) for v in long[x]]
        x_enc = alt.X(f"{x}:T", axis=alt.Axis(format="%Y", title=None, tickCount="year"))
        tip_time = alt.Tooltip("Waktu:N", title="Periode")
    else:
        x_enc = alt.X(f"{x}:Q", axis=alt.Axis(format="d", title=None, tickMinStep=1))
        tip_time = alt.Tooltip(f"{x}:Q", title="Tahun", format="d")
    base = alt.Chart(long).encode(
        x=x_enc,
        y=alt.Y("Nilai:Q", axis=alt.Axis(title=y_title), scale=alt.Scale(zero=True)),
        color=alt.Color("Seri:N", scale=color_scale(labels), legend=alt.Legend(title=None) if len(labels) > 1 else None),
        tooltip=[tip_time, alt.Tooltip("Seri:N", title="Seri"), alt.Tooltip("Teks:N", title="Nilai")],
    )
    layers = [base.mark_line(strokeWidth=2, strokeJoin="round", strokeCap="round")]
    if not date_axis:
        layers.append(base.mark_point(filled=True, size=70, opacity=1))
    show_chart(alt.layer(*layers), height=height)


def bar_chart(frame, category, value, value_title, order, label_column=None, height=300, color_index=0):
    """One-colour columns with the value on the cap. `order` fixes the category order (never value order)."""
    data = frame[[category, value] + ([label_column] if label_column else [])].copy()
    data["Teks"] = data[label_column] if label_column else [number(v, 1) for v in data[value]]
    base = alt.Chart(data).encode(
        x=alt.X(f"{category}:N", sort=list(order), axis=alt.Axis(title=None, labelAngle=0)),
        y=alt.Y(f"{value}:Q", axis=alt.Axis(title=value_title), scale=alt.Scale(zero=True)),
        tooltip=[alt.Tooltip(f"{category}:N", title="Kelompok"), alt.Tooltip("Teks:N", title="Nilai")],
    )
    bars = base.mark_bar(size=24, color=palette()[color_index], cornerRadiusTopLeft=4, cornerRadiusTopRight=4)
    labels = base.mark_text(dy=-8, fontSize=12, color=ink()).encode(text="Teks:N")
    show_chart(alt.layer(bars, labels), height=height)


def horizontal_bar_chart(frame, category, value, value_title, order, label_column=None, reference=None, height=None,
                         color_index=0, max_value=None):
    """One-colour horizontal bars in a fixed order, the value at the tip, and an optional reference line."""
    data = frame[[category, value] + ([label_column] if label_column else [])].copy()
    data["Teks"] = data[label_column] if label_column else [number(v, 1) for v in data[value]]
    base = alt.Chart(data).encode(
        y=alt.Y(f"{category}:N", sort=list(order), axis=alt.Axis(title=None, labelLimit=260)),
        x=alt.X(f"{value}:Q", axis=alt.Axis(title=value_title),
                scale=alt.Scale(zero=True, domain=[0, max_value]) if max_value else alt.Scale(zero=True)),
        tooltip=[alt.Tooltip(f"{category}:N", title="Kelompok"), alt.Tooltip("Teks:N", title="Nilai")],
    )
    layers = [base.mark_bar(size=16, color=palette()[color_index], cornerRadiusTopRight=4, cornerRadiusBottomRight=4),
             base.mark_text(align="left", dx=6, fontSize=12, color=ink()).encode(text="Teks:N")]
    if reference is not None:
        line = pd.DataFrame({"Acuan": [reference]})
        layers.append(alt.Chart(line).mark_rule(color=NEUTRAL, strokeWidth=1).encode(x="Acuan:Q"))
    show_chart(alt.layer(*layers), height=height or max(120, 30 * len(data) + 40))


# --------------------------------------------------------------------------------------------
# Upcoming activities (shared by the summary and the page "Kegiatan mendatang")
# --------------------------------------------------------------------------------------------
STAGE_SCHEDULED = "Sudah dijadwalkan"
STAGE_PLAN = "Masih rencana tahunan"
STAGE_POSTPONED = "Ditunda, perlu jadwal baru"
STAGE_LABELS = {STAGE_SCHEDULED: "✅ Sudah dijadwalkan", STAGE_PLAN: "📝 Masih rencana tahunan", STAGE_POSTPONED: "⏸ Ditunda"}


def split_upcoming(frame):
    """(coming, postponed): activities still ahead of the data date, and those postponed this year."""
    postponed = frame[frame["TAHAP"] == STAGE_POSTPONED].sort_values("TANGGAL_MULAI")
    coming = frame[frame["TAHAP"] != STAGE_POSTPONED].sort_values(["TANGGAL_MULAI", "NAMA_PROGRAM"])
    return coming.reset_index(drop=True), postponed.reset_index(drop=True)


def with_stage_label(frame):
    frame = frame.copy()
    frame["Tahap"] = [STAGE_LABELS.get(t, t) for t in frame["TAHAP"]]
    frame["Dalam"] = [days_away(d) for d in frame["HARI_DARI_TANGGAL_DATA"]]
    return frame


def upcoming_timeline_chart(frame):
    """One dot per activity: date across, section down (alphabetical), colour by stage."""
    data = frame.copy()
    data["Tanggal"] = data["TANGGAL_MULAI"]
    data["Tanggal lengkap"] = [long_date(d) for d in data["TANGGAL_MULAI"]]
    data["Anggaran"] = [juta(v) for v in data["ANGGARAN_RENCANA"]]
    stages = [STAGE_SCHEDULED, STAGE_PLAN]
    chart = alt.Chart(data).mark_point(filled=True, size=130, opacity=1).encode(
        x=alt.X("Tanggal:T", axis=alt.Axis(format="%d/%m", title="Tanggal (hari/bulan)", tickCount=8)),
        y=alt.Y("NAMA_SEKSI:N", sort=sorted(data["NAMA_SEKSI"].unique()), axis=alt.Axis(title=None, labelLimit=260)),
        color=alt.Color("TAHAP:N", scale=color_scale(stages), legend=alt.Legend(title=None)),
        tooltip=[alt.Tooltip("NAMA_PROGRAM:N", title="Kegiatan"), alt.Tooltip("Tanggal lengkap:N", title="Tanggal"),
                 alt.Tooltip("NAMA_SEKSI:N", title="Seksi"), alt.Tooltip("TAHAP:N", title="Tahap"),
                 alt.Tooltip("Anggaran:N", title="Anggaran rencana")])
    show_chart(chart, height=max(220, 32 * data["NAMA_SEKSI"].nunique() + 70))


# --------------------------------------------------------------------------------------------
# Page: Ringkasan
# --------------------------------------------------------------------------------------------
def last_complete_year(annual):
    years = annual.loc[annual["TAHUN_LENGKAP"].astype(bool), "TAHUN"]
    return int(years.max())


def page_summary():
    st.title("Ringkasan")
    banner()
    annual = get("PEMASUKAN_PENGELUARAN_TAHUNAN").sort_values("TAHUN")
    projection = get("PROYEKSI_PEMASUKAN_PENGELUARAN").sort_values("TAHUN")
    attendance = get("KEHADIRAN_MISA_BULANAN")
    campaigns = get("TITIK_IMPAS_KAMPANYE")
    impact = get("DAMPAK_PERISTIWA_LUAR_BIASA")
    reports = get("KELENGKAPAN_LAPORAN_PER_SEKSI")
    coming, postponed = split_upcoming(get("KEGIATAN_MENDATANG"))

    year = last_complete_year(annual)
    now = annual[annual["TAHUN"] == year].iloc[0]
    before = annual[annual["TAHUN"] == year - 1]
    previous = before.iloc[0] if not before.empty else None

    yearly = attendance[attendance["TAHUN"] == year]
    per_mass = yearly["TOTAL_UMAT"].sum() / max(1, yearly["JUMLAH_MISA_TERLAKSANA"].sum())

    st.subheader(f"Keadaan tahun {year} (tahun lengkap terakhir)")
    cols = st.columns(4)
    cols[0].metric("Kolekte", juta(now["PEMASUKAN_KOLEKTE"]),
                   signed_percent(now["PERTUMBUHAN_KOLEKTE_PERSEN"]) + f" dari {year - 1}", delta_color="off")
    cols[1].metric("Pengeluaran program", juta(now["PENGELUARAN_PROGRAM"]),
                   signed_percent(now["PERTUMBUHAN_PENGELUARAN_PERSEN"]) + f" dari {year - 1}", delta_color="off")
    ratio_delta = None
    if previous is not None:
        ratio_delta = f"{'+' if now['PERSEN_PENGELUARAN_TERHADAP_KOLEKTE'] >= previous['PERSEN_PENGELUARAN_TERHADAP_KOLEKTE'] else ''}" \
                      f"{number(now['PERSEN_PENGELUARAN_TERHADAP_KOLEKTE'] - previous['PERSEN_PENGELUARAN_TERHADAP_KOLEKTE'], 1)} poin dari {year - 1}"
    cols[2].metric("Pengeluaran terhadap kolekte", percent(now["PERSEN_PENGELUARAN_TERHADAP_KOLEKTE"]), ratio_delta,
                   delta_color="off")
    cols[3].metric("Rata-rata umat per Misa", number(per_mass, 0))

    cols = st.columns(4)
    crossing = projection["TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE"].dropna()
    cols[0].metric("Pengeluaran melampaui kolekte", str(int(crossing.iloc[0])) if not crossing.empty else "Belum dalam jangkauan",
                   help="Tahun pertama ketika garis tren pengeluaran program berada di atas garis tren kolekte. Penyederhanaan, bukan ramalan.")
    finished = campaigns[campaigns["STATUS_KAMPANYE"] == "Selesai"].sort_values("TAHUN")
    for column, keyword, label in ((cols[1], "Puasa", "Biaya Paskah tertutup"),
                                   (cols[2], "Adven", "Biaya Natal tertutup")):
        mine = finished[finished["NAMA_KESEMPATAN"].str.contains(keyword)]
        if mine.empty:
            column.metric(label, "-")
        else:
            latest = mine.iloc[-1]
            column.metric(label, percent(latest["PERSEN_BIAYA_TERTUTUP_SUMBANGAN"], 0),
                          help=f"Sumbangan terkumpul dibandingkan biaya perayaan, tahun {int(latest['TAHUN'])}.")
    cols[3].metric("Peristiwa luar biasa", whole(len(impact)),
                   help="Perkiraan kolekte yang tidak diterima akibat peristiwa: "
                        + juta(impact["PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA"].clip(lower=0).sum()))

    st.subheader("Kolekte dan pengeluaran program, dengan garis tren")
    income_outcome_chart(annual, projection)
    partial = annual[~annual["TAHUN_LENGKAP"].astype(bool)]
    if not partial.empty:
        st.caption(f"Tahun {int(partial.iloc[0]['TAHUN'])} baru berjalan sebagian ({partial.iloc[0]['STATUS_TAHUN'].lower()}), "
                   "sehingga tidak digambarkan sebagai titik aktual.")
    st.caption(projection["CATATAN_METODE"].iloc[0])

    st.subheader("Kegiatan terdekat")
    if coming.empty:
        st.write("Tidak ada kegiatan yang akan datang.")
    else:
        nearest = with_stage_label(coming.head(3))
        show_table(nearest, [("TANGGAL_MULAI", "Tanggal", long_date), ("Dalam", "Dalam", text), ("NAMA_PROGRAM", "Kegiatan", text),
                             ("NAMA_SEKSI", "Seksi", text), ("Tahap", "Tahap", text)])
        st.caption("Selengkapnya ada pada halaman Kegiatan mendatang.")

    st.subheader("Perlu perhatian")
    notes = []
    if not postponed.empty:
        notes.append(f"**{len(postponed)}** kegiatan ditunda tahun ini dan belum memiliki jadwal baru.")
    if not crossing.empty:
        notes.append(f"Jika pola lima tahun terakhir berlanjut, pengeluaran program diperkirakan melampaui kolekte pada tahun "
                     f"**{int(crossing.iloc[0])}**. Ini gambaran tren, bukan ramalan pasti.")
    deficits = finished[finished["DANA_TAMBAHAN_DARI_GEREJA"].fillna(0) > 0]
    if not deficits.empty:
        names = ", ".join(f"{r['NAMA_KAMPANYE']}" for _, r in deficits.tail(3).iterrows())
        notes.append(f"Sumbangan khusus belum menutup biaya kegiatan yang didanai pada: {names}. Selisihnya ditutup dari dana gereja.")
    open_reports = int(reports["JUMLAH_BELUM_ADA_LAPORAN"].sum() + reports["JUMLAH_LAPORAN_DRAF_ATAU_REVISI"].sum())
    if open_reports:
        notes.append(f"Ada **{open_reports}** kegiatan terlaksana yang laporannya belum final atau belum dibuat.")
    for note in notes:
        st.markdown("- " + note)
    if not notes:
        st.write("Tidak ada hal khusus.")

    how_to_read(
        "**Kolekte** adalah ringkasan penerimaan dari Misa. **Pengeluaran program** adalah biaya yang tercatat pada rencana kerja tahunan seksi.",
        "Biaya operasional rutin (listrik, gaji, pemeliharaan) tidak ada dalam data demo ini.",
        "Garis putus-putus adalah garis lurus yang ditarik dari tahun-tahun lengkap. Ini penyederhanaan untuk demonstrasi.",
        "Angka kolekte menggambarkan administrasi keuangan, bukan tingkat iman atau komitmen umat.",
    )


# --------------------------------------------------------------------------------------------
# Page: Kegiatan mendatang
# --------------------------------------------------------------------------------------------
HORIZONS = {"30 hari ke depan": 30, "60 hari ke depan": 60, "Semua yang akan datang": None}


def page_upcoming():
    st.title("Kegiatan mendatang")
    banner()
    data = get("KEGIATAN_MENDATANG")
    masses = get("PELAKSANAAN_MISA")

    tab_activities, tab_masses = st.tabs(["Kegiatan dan rencana", "Jadwal Misa"])

    with tab_activities:
        if data.empty:
            st.info("Tidak ada kegiatan yang akan datang atau ditunda.")
        else:
            data_date = data["TANGGAL_DATA"].max()
            st.write(f"Data per **{long_date(data_date)}**. \"Mendatang\" dihitung dari tanggal data ini, bukan dari tanggal hari ini, "
                     "supaya contoh tetap sama kapan pun dibuka.")
            coming, postponed = split_upcoming(data)

            left, right = st.columns(2)
            horizon = left.radio("Jangka waktu", list(HORIZONS), index=len(HORIZONS) - 1, horizontal=True, key="jangka_waktu")
            sections = ["Semua seksi"] + sorted(data["NAMA_SEKSI"].unique())
            section = right.selectbox("Seksi", sections, key="seksi_mendatang")

            shown = coming
            if HORIZONS[horizon] is not None:
                shown = shown[shown["HARI_DARI_TANGGAL_DATA"] <= HORIZONS[horizon]]
            if section != "Semua seksi":
                shown = shown[shown["NAMA_SEKSI"] == section]

            tiles = st.columns(4)
            tiles[0].metric("Kegiatan mendatang", whole(len(shown)))
            tiles[1].metric("Sudah dijadwalkan", whole((shown["TAHAP"] == STAGE_SCHEDULED).sum()),
                            help="Sudah terdaftar sebagai kegiatan dengan tanggal, tempat, dan target peserta.")
            tiles[2].metric("Masih rencana tahunan", whole((shown["TAHAP"] == STAGE_PLAN).sum()),
                            help="Ada pada rencana kerja dan anggaran, tetapi belum punya tempat dan target peserta.")
            tiles[3].metric("Anggaran rencana", juta(shown["ANGGARAN_RENCANA"].sum()))

            st.subheader("Agenda")
            if shown.empty:
                st.info("Tidak ada kegiatan pada pilihan ini.")
            else:
                agenda = with_stage_label(shown)
                agenda["Bulan"] = [f"{MONTHS[d.month - 1]} {d.year}" for d in agenda["TANGGAL_MULAI"]]
                for month in dict.fromkeys(agenda["Bulan"]):
                    st.markdown(f"**{month}**")
                    show_table(agenda[agenda["Bulan"] == month], [
                        ("TANGGAL_MULAI", "Tanggal", long_date), ("NAMA_PROGRAM", "Kegiatan", text),
                        ("NAMA_SEKSI", "Seksi", text), ("Tahap", "Tahap", text), ("ANGGARAN_RENCANA", "Anggaran rencana", rupiah),
                        ("LOKASI", "Tempat", text), ("TARGET_PESERTA", "Target peserta", whole)])

                st.subheader("Peta waktu")
                upcoming_timeline_chart(shown)
                st.caption("Setiap titik adalah satu kegiatan. Biru sudah dijadwalkan, oranye masih berupa rencana tahunan.")

            st.subheader("Perlu perhatian")
            attention = False
            if not postponed.empty:
                attention = True
                st.warning(f"**{len(postponed)} kegiatan ditunda** tahun ini dan belum memiliki jadwal baru:\n\n" + "\n".join(
                    f"- **{r['NAMA_PROGRAM']}** ({r['NAMA_SEKSI']}), semula {long_date(r['TANGGAL_MULAI'])}. {text(r['CATATAN_KEGIATAN']).rstrip('.')}."
                    for _, r in postponed.iterrows()))
            for _, row in coming[coming["DIDANAI_KAMPANYE"].notna()].iterrows():
                attention = True
                gap = row["SELISIH_TARGET_DANA_VS_ANGGARAN"]
                result = (f"masih kurang {juta(-gap)} dan harus ditutup dari dana gereja" if gap < 0
                          else f"cukup, dengan kelebihan {juta(gap)}")
                st.warning(f"**{row['NAMA_PROGRAM']}** ({long_date(row['TANGGAL_MULAI'])}, {days_away(row['HARI_DARI_TANGGAL_DATA'])}) "
                           f"dianggarkan {juta(row['ANGGARAN_RENCANA'])}. Kampanye {row['DIDANAI_KAMPANYE']} menargetkan "
                           f"{juta(row['TARGET_DANA_KAMPANYE'])}. Bila target tercapai, dana {result}.")
            near = coming[(coming["TAHAP"] == STAGE_PLAN) & (coming["HARI_DARI_TANGGAL_DATA"] <= PREPARATION_DAYS)]
            if not near.empty:
                attention = True
                st.warning(f"**{len(near)} kegiatan** kurang dari {PREPARATION_DAYS} hari lagi tetapi masih berupa rencana tahunan "
                           "(belum punya tempat dan target peserta): " + "; ".join(
                               f"{r['NAMA_PROGRAM']} ({long_date(r['TANGGAL_MULAI'])})" for _, r in near.iterrows()) + ".")
            if not attention:
                st.write("Tidak ada hal khusus.")

            how_to_read(
                "**Masih rencana tahunan**: kegiatan ada pada rencana kerja dan anggaran seksi, tetapi belum didaftarkan dengan tempat dan target peserta.",
                "**Sudah dijadwalkan**: sudah terdaftar sebagai kegiatan dengan tanggal, tempat, dan target peserta.",
                "**Ditunda**: pernah dijadwalkan, lalu diundur dan belum memiliki tanggal baru. Catatan menjelaskan alasannya.",
                "Setelah terlaksana, kegiatan muncul pada halaman Rencana, anggaran, kegiatan lengkap dengan laporan pascakegiatan.",
                "Dana pendukung berasal dari kampanye sumbangan yang ditujukan untuk kegiatan itu (misalnya Adven untuk Natal).",
            )

    with tab_masses:
        planned = masses[masses["STATUS_PELAKSANAAN"] == "Terjadwal"].sort_values(["TANGGAL_MISA", "WAKTU_MULAI_JADWAL"])
        if planned.empty:
            st.info("Tidak ada Misa terjadwal pada data ini.")
        else:
            tiles = st.columns(3)
            tiles[0].metric("Misa terjadwal", whole(len(planned)))
            tiles[1].metric("Mulai", long_date(planned["TANGGAL_MISA"].min()))
            tiles[2].metric("Sampai", long_date(planned["TANGGAL_MISA"].max()))
            sessions = ["Semua sesi"] + sorted(planned["NAMA_MISA"].unique())
            choice = st.selectbox("Sesi Misa", sessions, key="sesi_mendatang")
            if choice != "Semua sesi":
                planned = planned[planned["NAMA_MISA"] == choice]
            show_table(planned, [("TANGGAL_MISA", "Tanggal", long_date), ("HARI", "Hari", text), ("NAMA_MISA", "Misa", text),
                                 ("WAKTU_MULAI_JADWAL", "Jam mulai", clock), ("LOKASI", "Tempat", text), ("BAHASA_MISA", "Bahasa", text)])
            st.caption("Jam yang ditampilkan adalah jam yang dijadwalkan. Jam sebenarnya baru tercatat setelah Misa berlangsung.")


# --------------------------------------------------------------------------------------------
# Page: Pemasukan dan pengeluaran
# --------------------------------------------------------------------------------------------
def page_income_outcome():
    st.title("Pemasukan dan pengeluaran")
    banner()
    annual = get("PEMASUKAN_PENGELUARAN_TAHUNAN").sort_values("TAHUN")
    projection = get("PROYEKSI_PEMASUKAN_PENGELUARAN").sort_values("TAHUN")
    monthly = get("PEMASUKAN_PENGELUARAN_BULANAN").sort_values(["TAHUN", "BULAN"])

    yearly, by_month = st.tabs(["Per tahun dan proyeksi", "Per bulan"])

    with yearly:
        st.subheader("Apakah kolekte masih lebih besar dari pengeluaran?")
        income_outcome_chart(annual, projection)
        st.caption(projection["CATATAN_METODE"].iloc[0])

        st.subheader("Pertumbuhan melambat, pengeluaran terus naik")
        growth = annual[annual["TAHUN_LENGKAP"].astype(bool)].copy()
        growth = growth.dropna(subset=["PERTUMBUHAN_PENGELUARAN_PERSEN"])
        if not growth.empty:
            growth = growth.rename(columns={
                "PERTUMBUHAN_KOLEKTE_PER_MISA_TANPA_PERISTIWA_PERSEN": "Kolekte per Misa (tanpa peristiwa)",
                "PERTUMBUHAN_PENGELUARAN_PERSEN": "Pengeluaran program",
                "PERTUMBUHAN_KOLEKTE_PERSEN": "Kolekte (angka mentah)",
            })
            line_chart(growth, "TAHUN", ["Kolekte per Misa (tanpa peristiwa)", "Pengeluaran program",
                                         "Kolekte (angka mentah)"], "Pertumbuhan dari tahun sebelumnya (%)", date_axis=False)
            st.caption("Kolekte mentah naik turun karena peristiwa luar biasa. Garis \"tanpa peristiwa\" "
                       "menghitung kolekte per Misa tanpa pekan yang terkena peristiwa, sehingga menunjukkan kecenderungan dasarnya.")

        st.subheader("Tabel")
        show_table(annual, [
            ("TAHUN", "Tahun", lambda v: str(int(v))), ("STATUS_TAHUN", "Keterangan", text),
            ("PEMASUKAN_KOLEKTE", "Kolekte", rupiah), ("PEMASUKAN_SUMBANGAN_KHUSUS", "Sumbangan khusus", rupiah),
            ("PENGELUARAN_PROGRAM", "Pengeluaran program", rupiah),
            ("SELISIH_KOLEKTE_VS_PENGELUARAN", "Kolekte dikurangi pengeluaran", rupiah),
            ("PERSEN_PENGELUARAN_TERHADAP_KOLEKTE", "Pengeluaran terhadap kolekte", percent),
            ("PERTUMBUHAN_KOLEKTE_PERSEN", "Pertumbuhan kolekte", signed_percent),
            ("PERTUMBUHAN_KOLEKTE_PER_MISA_TANPA_PERISTIWA_PERSEN", "Pertumbuhan kolekte per Misa (tanpa peristiwa)", signed_percent),
            ("PERTUMBUHAN_PENGELUARAN_PERSEN", "Pertumbuhan pengeluaran", signed_percent),
        ])
        st.subheader("Proyeksi garis lurus")
        show_table(projection, [
            ("TAHUN", "Tahun", lambda v: str(int(v))), ("JENIS_DATA", "Jenis", text),
            ("KOLEKTE_TREN", "Kolekte (tren)", rupiah), ("PENGELUARAN_TREN", "Pengeluaran (tren)", rupiah),
            ("SELISIH_TREN_KOLEKTE_VS_PENGELUARAN", "Selisih menurut tren", rupiah),
        ])
        st.caption("Sumbangan khusus tidak digabung dengan kolekte pada proyeksi ini karena dikumpulkan untuk perayaan tertentu, "
                   "lihat halaman Sumbangan khusus.")

    with by_month:
        first, last = year_range_slider("Rentang tahun", monthly["TAHUN"].unique())
        shown = monthly[(monthly["TAHUN"] >= first) & (monthly["TAHUN"] <= last)].copy()
        shown["Bulan"] = month_start(shown)
        shown = shown.rename(columns={"PEMASUKAN_KOLEKTE": "Kolekte", "PENGELUARAN_PROGRAM": "Pengeluaran program"})
        for column in ("Kolekte", "Pengeluaran program"):
            shown[column] = shown[column].astype(float) / 1e6
        st.subheader("Kolekte dan pengeluaran program per bulan")
        line_chart(shown, "Bulan", ["Kolekte", "Pengeluaran program"], "Juta rupiah", height=320)
        events = shown.dropna(subset=["NAMA_PERISTIWA"])
        if not events.empty:
            st.caption("Bulan dengan peristiwa luar biasa: " + ", ".join(events["NAMA_PERIODE"])
                       + ". Rinciannya ada pada halaman Peristiwa luar biasa.")
        st.caption("Pengeluaran program tidak merata sepanjang tahun karena mengikuti jadwal kegiatan.")
        with st.expander("Tabel bulanan"):
            show_table(shown, [
                ("NAMA_PERIODE", "Bulan", text), ("Kolekte", "Kolekte (juta)", lambda v: number(v, 1)),
                ("Pengeluaran program", "Pengeluaran program (juta)", lambda v: number(v, 1)),
                ("NAMA_PERISTIWA", "Peristiwa luar biasa", text),
            ])

    how_to_read(
        "Kolekte per bulan sangat dipengaruhi jumlah umat yang hadir dan tanggal dalam bulan (lihat halaman Kolekte dan kehadiran).",
        "Pengeluaran program dicatat pada tanggal pengeluarannya, sehingga bulan dengan banyak kegiatan terlihat tinggi.",
    )


# --------------------------------------------------------------------------------------------
# Page: Kolekte dan kehadiran
# --------------------------------------------------------------------------------------------
PAYDAY_GROUPS = ["Tanggal 1-7", "Tanggal 8-14", "Tanggal 15-21", "Tanggal 22-31"]


def page_offertory_attendance():
    st.title("Kolekte dan kehadiran")
    banner()
    attendance = get("KEHADIRAN_MISA_BULANAN")
    offertory = get("KOLEKTE_MISA_BULANAN")
    weekly = complete_weeks(get("KOLEKTE_MINGGUAN_DAN_PERISTIWA"))
    payday = get("POLA_KOLEKTE_HARI_DALAM_BULAN")
    correlation = get("KORELASI_KOLEKTE_KEHADIRAN")
    trend = get("TREN_KEHADIRAN_PERIODE").sort_values(["TAHUN", "BULAN"])

    sessions = sorted(attendance["NAMA_MISA"].unique())
    choice = st.selectbox("Sesi Misa", ["Semua sesi"] + sessions)
    first, last = year_range_slider("Rentang tahun", attendance["TAHUN"].unique())

    att = attendance[(attendance["TAHUN"] >= first) & (attendance["TAHUN"] <= last)]
    off = offertory[(offertory["TAHUN"] >= first) & (offertory["TAHUN"] <= last)]
    if choice != "Semua sesi":
        att = att[att["NAMA_MISA"] == choice]
        off = off[off["NAMA_MISA"] == choice]

    tiles = st.columns(4)
    tiles[0].metric("Misa terlaksana", whole(att["JUMLAH_MISA_TERLAKSANA"].sum()))
    tiles[1].metric("Rata-rata umat per Misa", number(att["TOTAL_UMAT"].sum() / max(1, att["JUMLAH_MISA_TERLAKSANA"].sum()), 0))
    tiles[2].metric("Kolekte belum dihitung", whole(off["JUMLAH_BELUM_DIHITUNG"].sum()),
                    help="Catatan kolekte yang hasil penghitungannya belum masuk.")
    tiles[3].metric("Kehadiran belum final", whole(att["JUMLAH_BELUM_FINAL"].sum()),
                    help="Catatan kehadiran yang masih menunggu validasi.")

    tab_att, tab_off, tab_pay, tab_rel = st.tabs(["Kehadiran", "Kolekte", "Hari gajian", "Hubungan dengan kehadiran"])

    with tab_att:
        monthly = att.groupby(["TAHUN", "BULAN"], as_index=False).agg(
            Umat=("TOTAL_UMAT", "sum"), Misa=("JUMLAH_MISA_TERLAKSANA", "sum"))
        monthly["Bulan"] = month_start(monthly)
        monthly["Rata-rata umat per Misa"] = monthly["Umat"] / monthly["Misa"].clip(lower=1)
        st.subheader("Rata-rata umat per Misa, per bulan")
        line_chart(monthly, "Bulan", ["Rata-rata umat per Misa"], "Umat per Misa")
        full = trend[trend["JUMLAH_MISA_TERLAKSANA"] >= 0.8 * trend["JUMLAH_MISA_TERLAKSANA"].median()]
        if not full.empty:
            latest = full.iloc[-1]
            st.caption(f"Seluruh sesi, {latest['NAMA_PERIODE']} (bulan lengkap terakhir): {number(latest['RATA_RATA_UMAT_PER_MISA'], 0)} umat per Misa, "
                       f"{signed_percent(latest['PERUBAHAN_PERSEN_RATA_RATA'])} dibanding bulan sebelumnya.")
        with st.expander("Tabel"):
            monthly = monthly.sort_values("Bulan")
            monthly["Periode"] = [f"{MONTHS[int(m) - 1]} {int(y)}" for y, m in zip(monthly["TAHUN"], monthly["BULAN"])]
            show_table(monthly, [("Periode", "Bulan", text), ("Misa", "Misa", whole), ("Umat", "Total umat", whole),
                                 ("Rata-rata umat per Misa", "Rata-rata per Misa", lambda v: number(v, 1))])

    with tab_off:
        preferred = ["Kolekte Pertama", "Kolekte Kedua", "Kolekte Khusus"]
        found = set(off["NAMA_JENIS_KOLEKTE"].unique())
        types = [t for t in preferred if t in found] + sorted(found - set(preferred))
        grouped = off.groupby(["TAHUN", "BULAN", "NAMA_JENIS_KOLEKTE"], as_index=False)["TOTAL_TERCATAT"].sum()
        grouped["Bulan"] = month_start(grouped)
        grouped["Juta"] = grouped["TOTAL_TERCATAT"].astype(float) / 1e6
        grouped["Teks"] = [f"Rp {number(v, 2)} jt" for v in grouped["Juta"]]
        grouped["Waktu"] = [f"{MONTHS[m.month - 1]} {m.year}" for m in grouped["Bulan"]]
        st.subheader("Kolekte tercatat per bulan menurut jenis kolekte")
        if len(types) > 3:
            st.warning("Jenis kolekte lebih dari tiga; grafik hanya menampilkan tiga jenis pertama.")
            types = types[:3]
            grouped = grouped[grouped["NAMA_JENIS_KOLEKTE"].isin(types)]
        chart = alt.Chart(grouped).mark_bar(size=6).encode(
            x=alt.X("Bulan:T", axis=alt.Axis(format="%Y", title=None, tickCount="year")),
            y=alt.Y("Juta:Q", axis=alt.Axis(title="Juta rupiah"), stack="zero"),
            color=alt.Color("NAMA_JENIS_KOLEKTE:N", scale=color_scale(types), legend=alt.Legend(title=None)),
            tooltip=[alt.Tooltip("Waktu:N", title="Bulan"), alt.Tooltip("NAMA_JENIS_KOLEKTE:N", title="Jenis"),
                     alt.Tooltip("Teks:N", title="Nilai")])
        show_chart(chart, height=320)
        st.caption("Jumlah tercatat adalah angka yang dicatat saat Misa. Hasil penghitungan menyusul dan statusnya "
                   "(cocok, ada selisih, belum dihitung) dihitung pada tabel di bawah.")
        with st.expander("Tabel kolekte per bulan dan jenis"):
            pivot = grouped.pivot_table(index=["TAHUN", "BULAN"], columns="NAMA_JENIS_KOLEKTE", values="TOTAL_TERCATAT",
                                        aggfunc="sum").reset_index().sort_values(["TAHUN", "BULAN"])
            pivot["Periode"] = [f"{MONTHS[int(m) - 1]} {int(y)}" for y, m in zip(pivot["TAHUN"], pivot["BULAN"])]
            show_table(pivot, [("Periode", "Bulan", text)] + [(t, t, rupiah) for t in types])
        with st.expander("Status rekonsiliasi"):
            status = pd.DataFrame({
                "Status": ["Sudah cocok", "Ada selisih", "Belum dihitung"],
                "Jumlah catatan": [off["JUMLAH_SUDAH_COCOK"].sum(), off["JUMLAH_ADA_SELISIH"].sum(), off["JUMLAH_BELUM_DIHITUNG"].sum()],
            })
            show_table(status, [("Status", "Status", text), ("Jumlah catatan", "Jumlah catatan", whole)])

    with tab_pay:
        years = payday[(payday["TAHUN"] >= first) & (payday["TAHUN"] <= last)]
        by_group = years.groupby("KELOMPOK_TANGGAL", as_index=False).agg(Kolekte=("TOTAL_KOLEKTE", "sum"), Umat=("TOTAL_UMAT", "sum"))
        by_group["Per umat"] = by_group["Kolekte"].astype(float) / by_group["Umat"].astype(float).clip(lower=1)
        by_group["Teks"] = [rupiah(v) for v in by_group["Per umat"]]
        st.subheader("Kolekte per umat menurut tanggal dalam bulan")
        bar_chart(by_group, "KELOMPOK_TANGGAL", "Per umat", "Rupiah per umat", PAYDAY_GROUPS, label_column="Teks")
        if not by_group.empty and by_group["Per umat"].min() > 0:
            first_week = by_group.loc[by_group["KELOMPOK_TANGGAL"] == PAYDAY_GROUPS[0], "Per umat"]
            last_week = by_group.loc[by_group["KELOMPOK_TANGGAL"] == PAYDAY_GROUPS[-1], "Per umat"]
            if not first_week.empty and not last_week.empty:
                st.write(f"Pada minggu pertama setiap bulan (sesudah gajian), kolekte per umat sekitar "
                         f"**{number(first_week.iloc[0] / last_week.iloc[0], 1)} kali** kolekte pada akhir bulan.")
        st.caption("Perbedaan ini wajar dan perlu diperhitungkan ketika membandingkan bulan atau membuat perkiraan.")

    with tab_rel:
        weeks = weekly[(week_year(weekly) >= first) & (week_year(weekly) <= last)].copy()
        weeks["Umat"] = weeks["TOTAL_UMAT"].astype(float)
        weeks["Juta"] = weeks["TOTAL_KOLEKTE"].astype(float) / 1e6
        weeks["Jenis"] = ["Pekan terdampak peristiwa" if isinstance(n, str) else "Pekan biasa" for n in weeks["NAMA_PERISTIWA"]]
        weeks["Pekan"] = [f"Pekan {long_date(d)}" for d in weeks["AWAL_PEKAN"]]
        weeks["Peristiwa"] = [text(n) for n in weeks["NAMA_PERISTIWA"]]
        weeks["Teks"] = [f"Rp {number(v, 1)} jt" for v in weeks["Juta"]]
        st.subheader("Jumlah umat dan kolekte per pekan")
        kinds = ["Pekan biasa", "Pekan terdampak peristiwa"]
        base = alt.Chart(weeks).encode(
            x=alt.X("Umat:Q", axis=alt.Axis(title="Jumlah umat dalam satu pekan")),
            y=alt.Y("Juta:Q", axis=alt.Axis(title="Kolekte (juta rupiah)"), scale=alt.Scale(zero=True)))
        points = base.mark_point(filled=True, size=60, opacity=0.85).encode(
            color=alt.Color("Jenis:N", scale=color_scale(kinds), legend=alt.Legend(title=None)),
            tooltip=[alt.Tooltip("Pekan:N", title="Pekan"), alt.Tooltip("Umat:Q", title="Umat", format="d"),
                     alt.Tooltip("Teks:N", title="Kolekte"), alt.Tooltip("Peristiwa:N", title="Peristiwa")])
        normal = weeks[weeks["Jenis"] == "Pekan biasa"]
        layers = [points]
        if len(normal) >= 3:
            layers.append(alt.Chart(normal).transform_regression("Umat", "Juta").mark_line(color=NEUTRAL, strokeWidth=2)
                          .encode(x="Umat:Q", y="Juta:Q"))
        show_chart(alt.layer(*layers), height=340)
        st.caption("Semakin banyak umat hadir, semakin besar kolekte pekan itu. Garis abu-abu dihitung dari pekan biasa; "
                   "pekan dengan peristiwa luar biasa (oranye) cenderung berada di kiri bawah.")
        per_session = correlation[(correlation["TAHUN"] >= first) & (correlation["TAHUN"] <= last)]
        if choice != "Semua sesi":
            per_session = per_session[per_session["NAMA_MISA"] == choice]
        with st.expander("Angka korelasi per sesi dan tahun"):
            show_table(per_session.sort_values(["NAMA_MISA", "TAHUN"]), [
                ("NAMA_MISA", "Sesi Misa", text), ("TAHUN", "Tahun", lambda v: str(int(v))),
                ("JUMLAH_MISA", "Jumlah Misa", whole),
                ("KORELASI_KOLEKTE_DENGAN_UMAT", "Korelasi kolekte dan umat", two_decimals),
                ("TAMBAHAN_KOLEKTE_PER_UMAT", "Tambahan kolekte per umat tambahan", rupiah),
                ("KORELASI_TANGGAL_DENGAN_KOLEKTE_PER_UMAT", "Korelasi tanggal dan kolekte per umat", two_decimals),
            ])

    how_to_read(
        "Korelasi mendekati 1 berarti kolekte naik bersama jumlah umat. Korelasi negatif pada tanggal berarti kolekte per umat turun menjelang akhir bulan.",
        "Hubungan ini dipakai untuk memahami pola dan membuat perkiraan, bukan untuk menilai umat.",
        "Jumlah \"belum dihitung\" dan \"belum final\" menunjukkan catatan yang masih menunggu proses administrasi.",
    )


# --------------------------------------------------------------------------------------------
# Page: Peristiwa luar biasa
# --------------------------------------------------------------------------------------------
SEVERITY_ORDER = ["Ringan", "Sedang", "Berat"]


def page_events():
    st.title("Peristiwa luar biasa")
    banner()
    weekly = complete_weeks(get("KOLEKTE_MINGGUAN_DAN_PERISTIWA"))
    impact = get("DAMPAK_PERISTIWA_LUAR_BIASA").sort_values("TANGGAL_MULAI")

    st.write("Hujan deras, kabut asap, abu vulkanik, atau gangguan listrik dapat menurunkan kehadiran dan kolekte. "
             "Peristiwa seperti ini tidak bisa diramalkan, tetapi bila dicatat, penyimpangan pada perkiraan dapat dijelaskan.")

    measure = st.radio("Tampilkan", ["Jumlah umat per pekan", "Kolekte per pekan"], horizontal=True)
    if measure == "Jumlah umat per pekan":
        value, baseline, title, scale = "TOTAL_UMAT", "RATA_RATA_UMAT_8_PEKAN_SEBELUMNYA", "Umat per pekan", 1.0
    else:
        value, baseline, title, scale = "TOTAL_KOLEKTE", "RATA_RATA_KOLEKTE_8_PEKAN_SEBELUMNYA", "Juta rupiah per pekan", 1e6
    first, last = year_range_slider("Rentang tahun", week_year(weekly).unique())
    weeks = weekly[(week_year(weekly) >= first) & (week_year(weekly) <= last)].copy()

    name_a, name_b, name_c = ("Pekan ini", "Rata-rata 8 pekan sebelumnya", "Pekan terdampak peristiwa")
    weeks[name_a] = weeks[value].astype(float) / scale
    weeks[name_b] = weeks[baseline].astype(float) / scale
    long = weeks[["AWAL_PEKAN", name_a, name_b]].melt(id_vars="AWAL_PEKAN", var_name="Seri", value_name="Nilai").dropna(subset=["Nilai"])
    long["Pekan"] = [f"Pekan {long_date(d)}" for d in long["AWAL_PEKAN"]]
    long["Teks"] = [number(v, 1) for v in long["Nilai"]]
    flagged = weeks[weeks["NAMA_PERISTIWA"].map(lambda n: isinstance(n, str))].copy()
    flagged["Seri"] = name_c
    flagged["Nilai"] = flagged[name_a]
    flagged["Pekan"] = [f"Pekan {long_date(d)}" for d in flagged["AWAL_PEKAN"]]
    flagged["Teks"] = [number(v, 1) for v in flagged["Nilai"]]
    scale_colors = alt.Scale(domain=[name_a, name_b, name_c], range=[palette()[0], NEUTRAL, palette()[1]])
    x_axis = alt.X("AWAL_PEKAN:T", axis=alt.Axis(format="%Y", title=None, tickCount="year"))
    y_axis = alt.Y("Nilai:Q", axis=alt.Axis(title=title), scale=alt.Scale(zero=True))
    tip = [alt.Tooltip("Pekan:N", title="Pekan"), alt.Tooltip("Seri:N", title="Seri"), alt.Tooltip("Teks:N", title="Nilai")]
    colour = alt.Color("Seri:N", scale=scale_colors, legend=alt.Legend(title=None))
    lines = alt.Chart(long).mark_line(strokeWidth=2, strokeJoin="round").encode(x=x_axis, y=y_axis, color=colour, tooltip=tip)
    layers = [lines]
    if not flagged.empty:
        layers.append(alt.Chart(flagged).mark_point(filled=True, size=70, opacity=1).encode(
            x=x_axis, y=y_axis, color=colour,
            tooltip=tip + [alt.Tooltip("NAMA_PERISTIWA:N", title="Peristiwa")]))
    show_chart(alt.layer(*layers), height=340)
    st.caption("Titik oranye menandai pekan yang terkena peristiwa luar biasa. Garis abu-abu adalah rata-rata delapan pekan "
               "sebelumnya, dipakai sebagai pembanding kasar. Pekan pertama dan terakhir yang belum lengkap tidak ditampilkan.")

    st.subheader("Seberapa besar dampaknya?")
    inside = impact[(impact["TANGGAL_MULAI"].dt.year >= first) & (impact["TANGGAL_MULAI"].dt.year <= last)].copy()
    if inside.empty:
        st.info("Tidak ada peristiwa pada rentang tahun yang dipilih.")
    else:
        order = list(inside["NAMA_PERISTIWA"])
        inside["Teks hadir"] = [percent(v, 0) for v in inside["PERSEN_KEHADIRAN_TERHADAP_HARAPAN"]]
        inside["Teks kolekte"] = [percent(v, 0) for v in inside["PERSEN_KOLEKTE_TERHADAP_HARAPAN"]]
        left, right = st.columns(2)
        with left:
            st.markdown("**Kehadiran terhadap perkiraan (%)**")
            horizontal_bar_chart(inside, "NAMA_PERISTIWA", "PERSEN_KEHADIRAN_TERHADAP_HARAPAN", "% dari perkiraan", order,
                                 reference=100, label_column="Teks hadir", color_index=0, max_value=125)
        with right:
            st.markdown("**Kolekte terhadap perkiraan (%)**")
            horizontal_bar_chart(inside, "NAMA_PERISTIWA", "PERSEN_KOLEKTE_TERHADAP_HARAPAN", "% dari perkiraan", order,
                                 reference=100, label_column="Teks kolekte", color_index=1, max_value=125)
        st.caption("Garis abu-abu vertikal adalah 100%, yaitu sama dengan perkiraan. Urutan mengikuti tanggal kejadian, bukan besar dampak.")

        lost = inside["PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA"].clip(lower=0).sum()
        st.markdown(f"Perkiraan kolekte yang tidak diterima akibat {len(inside)} peristiwa pada rentang ini: **{juta(lost)}**. "
                    "Angka ini kasar, karena belum membedakan pengaruh hari gajian dan musim.")
        masked = inside[(inside["PERSEN_KOLEKTE_TERHADAP_HARAPAN"] > 100) & (inside["PERSEN_KEHADIRAN_TERHADAP_HARAPAN"] < 100)]
        for _, row in masked.iterrows():
            st.info(f"**{row['NAMA_PERISTIWA']}**: kehadiran {percent(row['PERSEN_KEHADIRAN_TERHADAP_HARAPAN'], 0)} dari perkiraan, "
                    f"tetapi kolekte {percent(row['PERSEN_KOLEKTE_TERHADAP_HARAPAN'], 0)}. Peristiwa jatuh pada awal bulan sesudah gajian, "
                    "sehingga kolekte per umat yang lebih tinggi menutupi penurunan kehadiran. Contoh ini menunjukkan mengapa "
                    "perbandingan sederhana bisa menyesatkan.")

        st.subheader("Rincian per peristiwa")
        chosen = st.selectbox("Pilih peristiwa", order)
        row = inside[inside["NAMA_PERISTIWA"] == chosen].iloc[0]
        st.markdown(f"**{row['NAMA_PERISTIWA']}** ({row['JENIS_PERISTIWA']}, gangguan {row['TINGKAT_GANGGUAN'].lower()}), "
                    f"{long_date(row['TANGGAL_MULAI'])} sampai {long_date(row['TANGGAL_SELESAI'])}")
        st.write(row["DESKRIPSI"])
        tiles = st.columns(4)
        tiles[0].metric("Misa terlaksana / dibatalkan", f"{whole(row['JUMLAH_MISA_TERLAKSANA'])} / {whole(row['JUMLAH_MISA_DIBATALKAN'])}")
        tiles[1].metric("Kehadiran terhadap perkiraan", percent(row["PERSEN_KEHADIRAN_TERHADAP_HARAPAN"], 0))
        tiles[2].metric("Kolekte terhadap perkiraan", percent(row["PERSEN_KOLEKTE_TERHADAP_HARAPAN"], 0))
        tiles[3].metric("Kolekte yang tidak diterima", juta(row["PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA"]))
        st.caption(row["CATATAN_METODE"])

        with st.expander("Tabel semua peristiwa"):
            show_table(inside, [
                ("NAMA_PERISTIWA", "Peristiwa", text), ("JENIS_PERISTIWA", "Jenis", text),
                ("TINGKAT_GANGGUAN", "Tingkat gangguan", text), ("TANGGAL_MULAI", "Mulai", long_date),
                ("TANGGAL_SELESAI", "Selesai", long_date),
                ("PERSEN_KEHADIRAN_TERHADAP_HARAPAN", "Kehadiran (%)", lambda v: number(v, 0)),
                ("PERSEN_KOLEKTE_TERHADAP_HARAPAN", "Kolekte (%)", lambda v: number(v, 0)),
                ("PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA", "Kolekte tidak diterima", rupiah),
            ])

    how_to_read(
        "Catatan peristiwa menjelaskan mengapa angka pada suatu periode menyimpang dari tren. Dampaknya tidak disimpan sebagai angka, "
        "tetapi dihitung dari perbandingan dengan delapan pekan sebelumnya.",
        "Bila perkiraan masa depan dibuat tanpa memisahkan pekan-pekan ini, penurunan sementara bisa terbaca sebagai perubahan tren.",
    )


# --------------------------------------------------------------------------------------------
# Page: Sumbangan khusus
# --------------------------------------------------------------------------------------------
def finished_campaigns(breakeven):
    """Campaigns that have ended and have both a collected amount and an actual cost (planned ones have neither yet)."""
    return breakeven[(breakeven["STATUS_KAMPANYE"] == "Selesai") & breakeven["BIAYA_AKTUAL"].notna()
                     & breakeven["TOTAL_SUMBANGAN"].notna()]


def funded_celebration(occasion):
    for keyword, celebration in (("Puasa", "Paskah"), ("Prapaskah", "Paskah"), ("Adven", "Natal")):
        if keyword in occasion:
            return celebration
    return ""


def break_even_status(row):
    if row["STATUS_KAMPANYE"] != "Selesai" or _missing(row["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"]):
        return "⏳ Belum dapat dihitung"
    return "✅ Surplus" if row["SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL"] >= 0 else "⚠️ Defisit"


def page_donations():
    st.title("Sumbangan khusus")
    banner()
    st.info("Angka pada halaman ini menggambarkan kapasitas ekonomi dan sebaran sumbangan. Angka ini **bukan** ukuran iman atau "
            "kemurahan hati, dan tidak boleh dipakai untuk memeringkat wilayah atau lingkungan. Urutan tampilan sengaja mengikuti abjad.")
    breakeven = get("TITIK_IMPAS_KAMPANYE").sort_values(["NAMA_KESEMPATAN", "TAHUN"])
    communities = get("SUMBANGAN_KELUARGA_PER_LINGKUNGAN")
    regions = get("SUMBANGAN_KHUSUS_PER_WILAYAH")

    tab_even, tab_comm, tab_region = st.tabs(["Titik impas perayaan", "Sebaran per lingkungan", "Per wilayah"])

    with tab_even:
        st.subheader("Apakah sumbangan menutup biaya perayaan?")
        st.write("Sumbangan masa Prapaskah dan Adven dikumpulkan untuk perayaan Paskah dan Natal. Jika sumbangan lebih besar dari biaya, "
                 "kelebihannya menjadi pemasukan gereja. Jika lebih kecil, gereja menambah dana.")
        finished = finished_campaigns(breakeven)
        occasions = [name for name, group in finished.groupby("NAMA_KESEMPATAN") if len(group) >= 3]
        if occasions:
            columns = st.columns(len(occasions))
            for column, occasion in zip(columns, occasions):
                with column:
                    st.markdown(f"**{occasion}**" + (f" (untuk perayaan {funded_celebration(occasion)})" if funded_celebration(occasion) else ""))
                    data = finished[finished["NAMA_KESEMPATAN"] == occasion].copy()
                    data["Sumbangan terkumpul"] = data["TOTAL_SUMBANGAN"].astype(float) / 1e6
                    data["Biaya perayaan"] = data["BIAYA_AKTUAL"].astype(float) / 1e6
                    line_chart(data, "TAHUN", ["Sumbangan terkumpul", "Biaya perayaan"], "Juta rupiah", height=280, date_axis=False)
        st.subheader("Tabel titik impas")
        table = breakeven.copy()
        table["Status"] = [break_even_status(r) for _, r in table.iterrows()]
        notyet = table["STATUS_KAMPANYE"] != "Selesai"
        for column in ("TOTAL_SUMBANGAN", "BIAYA_AKTUAL"):
            table[column] = table[column].astype(float).where(~notyet)
        show_table(table, [
            ("NAMA_KAMPANYE", "Kampanye", text), ("Status", "Status", text), ("TOTAL_SUMBANGAN", "Terkumpul", rupiah),
            ("BIAYA_AKTUAL", "Biaya aktual", rupiah), ("ANGGARAN_RENCANA", "Anggaran rencana", rupiah),
            ("SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL", "Selisih", rupiah),
            ("PERSEN_BIAYA_TERTUTUP_SUMBANGAN", "Biaya tertutup", lambda v: percent(v, 0)),
            ("PEMASUKAN_BERSIH_UNTUK_GEREJA", "Menjadi pemasukan gereja", rupiah),
            ("DANA_TAMBAHAN_DARI_GEREJA", "Ditambah dari dana gereja", rupiah),
        ])
        planned = breakeven[breakeven["PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI"].notna()]
        for _, row in planned.iterrows():
            gap = row["PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI"]
            sentence = "masih kurang" if gap < 0 else "berlebih"
            st.warning(f"**{row['NAMA_KAMPANYE']}** masih direncanakan. Bila target {juta(row['TARGET_DANA'])} tercapai, dana {sentence} "
                       f"**{juta(abs(gap))}** terhadap anggaran perayaan {juta(row['ANGGARAN_RENCANA'])}.")

    with tab_comm:
        campaigns = (communities[["ID_KAMPANYE", "NAMA_KAMPANYE", "TAHUN"]].drop_duplicates()
                     .sort_values(["TAHUN", "NAMA_KAMPANYE"], ascending=[False, True]))
        if campaigns.empty:
            st.info("Belum ada data sumbangan keluarga.")
        else:
            labels = list(campaigns["NAMA_KAMPANYE"])
            default = next((i for i, n in enumerate(labels) if "Puasa" in n), 0)
            chosen = st.selectbox("Kampanye", labels, index=default, key="kampanye_lingkungan")
            data = communities[communities["NAMA_KAMPANYE"] == chosen].sort_values(["NAMA_WILAYAH", "NAMA_LINGKUNGAN"]).copy()
            data = data[data["JUMLAH_KELUARGA_PENYUMBANG"] > 0]
            order = list(data["NAMA_LINGKUNGAN"])

            st.subheader("Rata-rata dan median sumbangan per keluarga")
            st.write("Jika satu keluarga memberi jauh lebih besar dari yang lain, rata-rata terangkat sedangkan median tetap menunjukkan "
                     "sumbangan keluarga pada umumnya. Jarak antara kedua titik menunjukkan besarnya perbedaan itu.")
            points = pd.concat([
                pd.DataFrame({"Lingkungan": data["NAMA_LINGKUNGAN"], "Ukuran": "Median", "Ribu": data["MEDIAN_PER_KELUARGA_PENYUMBANG"].astype(float) / 1e3}),
                pd.DataFrame({"Lingkungan": data["NAMA_LINGKUNGAN"], "Ukuran": "Rata-rata", "Ribu": data["RATA_RATA_PER_KELUARGA_PENYUMBANG"].astype(float) / 1e3}),
            ])
            points["Teks"] = [f"Rp {number(v, 1)} ribu" for v in points["Ribu"]]
            span = pd.DataFrame({"Lingkungan": data["NAMA_LINGKUNGAN"], "Median": data["MEDIAN_PER_KELUARGA_PENYUMBANG"].astype(float) / 1e3,
                                 "Rata-rata": data["RATA_RATA_PER_KELUARGA_PENYUMBANG"].astype(float) / 1e3})
            y_axis = alt.Y("Lingkungan:N", sort=order, axis=alt.Axis(title=None, labelLimit=240))
            connector = alt.Chart(span).mark_rule(color=NEUTRAL, strokeWidth=2).encode(
                y=y_axis, x=alt.X("Median:Q", axis=alt.Axis(title="Ribu rupiah per keluarga penyumbang"), scale=alt.Scale(zero=True)), x2="Rata-rata:Q")
            dots = alt.Chart(points).mark_point(filled=True, size=90, opacity=1).encode(
                y=y_axis, x="Ribu:Q",
                color=alt.Color("Ukuran:N", scale=color_scale(["Median", "Rata-rata"]), legend=alt.Legend(title=None)),
                tooltip=[alt.Tooltip("Lingkungan:N"), alt.Tooltip("Ukuran:N"), alt.Tooltip("Teks:N", title="Nilai")])
            show_chart(alt.layer(connector, dots), height=max(260, 28 * len(data) + 60))

            st.subheader("Total dan sumbangan per umat terdaftar")
            st.write("Total dipengaruhi jumlah umat di lingkungan. Sumbangan per umat terdaftar membagi dengan seluruh umat, "
                     "sehingga dua ukuran ini bisa menceritakan hal yang berbeda.")
            left, right = st.columns(2)
            with left:
                st.markdown("**Total sumbangan (juta rupiah)**")
                total = data.assign(Juta=data["TOTAL_SUMBANGAN"].astype(float) / 1e6)
                total["Teks"] = [f"Rp {number(v, 2)} jt" for v in total["Juta"]]
                horizontal_bar_chart(total, "NAMA_LINGKUNGAN", "Juta", "Juta rupiah", order, label_column="Teks", color_index=0)
            with right:
                st.markdown("**Sumbangan per umat terdaftar (ribu rupiah)**")
                per_person = data.assign(Ribu=data["SUMBANGAN_PER_UMAT_TERDAFTAR"].astype(float) / 1e3)
                per_person["Teks"] = [f"Rp {number(v, 1)} ribu" for v in per_person["Ribu"]]
                horizontal_bar_chart(per_person, "NAMA_LINGKUNGAN", "Ribu", "Ribu rupiah", order, label_column="Teks", color_index=1)

            st.subheader("Tabel")
            table = data.copy()
            table["Catatan"] = ["Penyumbang sedikit, angka mudah berubah" if n < 5 else "-" for n in table["JUMLAH_KELUARGA_PENYUMBANG"]]
            show_table(table, [
                ("NAMA_WILAYAH", "Wilayah", text), ("NAMA_LINGKUNGAN", "Lingkungan", text), ("KATEGORI_EKONOMI", "Kategori ekonomi", text),
                ("JUMLAH_KELUARGA_PENYUMBANG", "Keluarga penyumbang", whole), ("TOTAL_SUMBANGAN", "Total", rupiah),
                ("RATA_RATA_PER_KELUARGA_PENYUMBANG", "Rata-rata", rupiah), ("MEDIAN_PER_KELUARGA_PENYUMBANG", "Median", rupiah),
                ("SELISIH_RATA_RATA_DARI_MEDIAN_PERSEN", "Rata-rata di atas median", signed_percent),
                ("PERSEN_TOTAL_DARI_SUMBANGAN_TERBESAR", "Porsi sumbangan terbesar", lambda v: percent(v, 0)),
                ("SUMBANGAN_PER_UMAT_TERDAFTAR", "Per umat terdaftar", rupiah), ("Catatan", "Catatan", text),
            ])
            st.caption(data["CATATAN_PENGGUNAAN"].iloc[0] if not data.empty else "")

    with tab_region:
        names = list(regions.sort_values("PERIODE_MULAI", ascending=False)["NAMA_KAMPANYE"].drop_duplicates())
        chosen = st.selectbox("Kampanye", names, key="kampanye_wilayah")
        data = regions[regions["NAMA_KAMPANYE"] == chosen].sort_values("NAMA_WILAYAH").copy()
        data["Juta"] = data["JUMLAH_SUMBANGAN"].astype(float) / 1e6
        data["Teks"] = [f"Rp {number(v, 2)} jt" for v in data["Juta"]]
        st.subheader("Sumbangan terkumpul per wilayah")
        horizontal_bar_chart(data, "NAMA_WILAYAH", "Juta", "Juta rupiah", list(data["NAMA_WILAYAH"]), label_column="Teks")
        show_table(data, [
            ("NAMA_WILAYAH", "Wilayah", text), ("JUMLAH_KELUARGA_PESERTA", "Keluarga peserta", whole),
            ("JUMLAH_SUMBANGAN", "Sumbangan", rupiah), ("STATUS_VALIDASI", "Status validasi", text),
        ])
        pending = data[data["STATUS_VALIDASI"] != "Sudah Divalidasi"]
        if not pending.empty:
            st.caption("Belum divalidasi: " + ", ".join(f"{r['NAMA_WILAYAH']} ({r['STATUS_VALIDASI']})" for _, r in pending.iterrows()))
        st.caption(data["CATATAN_PENGGUNAAN"].iloc[0] if not data.empty else "")


# --------------------------------------------------------------------------------------------
# Page: Rencana, anggaran, kegiatan
# --------------------------------------------------------------------------------------------
def page_plans():
    st.title("Rencana, anggaran, dan kegiatan")
    banner()
    by_section = get("ANGGARAN_VS_REALISASI_SEKSI")
    programs = get("ANGGARAN_VS_REALISASI_PROGRAM")
    events = get("KEGIATAN_DAN_LAPORAN")
    completeness = get("KELENGKAPAN_LAPORAN_PER_SEKSI")

    tab_budget, tab_events = st.tabs(["Anggaran dan realisasi", "Kegiatan dan laporan"])

    with tab_budget:
        years = sorted(int(y) for y in by_section["TAHUN_RENCANA"].unique())
        year = st.selectbox("Tahun rencana", years, index=len(years) - 1)
        mine = by_section[by_section["TAHUN_RENCANA"] == year].sort_values("NAMA_SEKSI")
        tiles = st.columns(4)
        tiles[0].metric("Program direncanakan", whole(mine["JUMLAH_PROGRAM"].sum()))
        tiles[1].metric("Terlaksana", whole(mine["JUMLAH_TERLAKSANA"].sum()))
        tiles[2].metric("Ditunda atau dibatalkan", whole(mine["JUMLAH_DITUNDA"].sum() + mine["JUMLAH_DIBATALKAN"].sum()))
        spent, planned = mine["REALISASI_PROGRAM_TERLAKSANA"].sum(), mine["ANGGARAN_PROGRAM_TERLAKSANA"].sum()
        tiles[3].metric("Anggaran terpakai", percent(100 * spent / planned) if planned else "-",
                    help="Realisasi dibagi anggaran, hanya untuk program yang sudah terlaksana.")

        st.subheader("Persentase anggaran terpakai per seksi")
        shown = mine.dropna(subset=["PERSEN_TERPAKAI_PROGRAM_TERLAKSANA"]).copy()
        shown["Teks"] = [percent(v, 0) for v in shown["PERSEN_TERPAKAI_PROGRAM_TERLAKSANA"]]
        horizontal_bar_chart(shown, "NAMA_SEKSI", "PERSEN_TERPAKAI_PROGRAM_TERLAKSANA", "% anggaran terpakai", list(shown["NAMA_SEKSI"]),
                             label_column="Teks", reference=100, max_value=125)
        st.caption("Hanya program yang sudah terlaksana. Garis abu-abu adalah 100% dari anggaran. Program yang ditunda, dibatalkan, "
                   "atau belum berjalan tidak dihitung agar tidak tampak boros atau hemat.")
        show_table(mine, [
            ("NAMA_SEKSI", "Seksi", text), ("JUMLAH_PROGRAM", "Program", whole), ("JUMLAH_TERLAKSANA", "Terlaksana", whole),
            ("JUMLAH_DIRENCANAKAN", "Direncanakan", whole), ("JUMLAH_DITUNDA", "Ditunda", whole), ("JUMLAH_DIBATALKAN", "Dibatalkan", whole),
            ("ANGGARAN_PROGRAM_TERLAKSANA", "Anggaran (terlaksana)", rupiah), ("REALISASI_PROGRAM_TERLAKSANA", "Realisasi", rupiah),
            ("PERSEN_TERPAKAI_PROGRAM_TERLAKSANA", "Terpakai", lambda v: percent(v, 0)),
        ])

        st.subheader("Rincian program")
        sections = ["Semua seksi"] + sorted(programs["NAMA_SEKSI"].unique())
        statuses = ["Semua status"] + sorted(programs["STATUS_PELAKSANAAN"].unique())
        left, right = st.columns(2)
        section = left.selectbox("Seksi", sections, key="seksi_program")
        status = right.selectbox("Status pelaksanaan", statuses, key="status_program")
        detail = programs[programs["TAHUN_RENCANA"] == year]
        if section != "Semua seksi":
            detail = detail[detail["NAMA_SEKSI"] == section]
        if status != "Semua status":
            detail = detail[detail["STATUS_PELAKSANAAN"] == status]
        show_table(detail.sort_values(["NAMA_SEKSI", "TANGGAL_RENCANA"]), [
            ("NAMA_SEKSI", "Seksi", text), ("NAMA_PROGRAM", "Program", text), ("TANGGAL_RENCANA", "Tanggal rencana", long_date),
            ("STATUS_PELAKSANAAN", "Status", text), ("ANGGARAN_RENCANA", "Anggaran", rupiah), ("ANGGARAN_TERPAKAI", "Terpakai", rupiah),
            ("STATUS_PENYERAPAN", "Penyerapan", text),
        ])

    with tab_events:
        st.subheader("Kelengkapan laporan kegiatan terlaksana")
        done = completeness.sort_values("NAMA_SEKSI")
        long = done.rename(columns={"JUMLAH_LAPORAN_FINAL": "Laporan final", "JUMLAH_LAPORAN_DRAF_ATAU_REVISI": "Laporan draf atau revisi",
                                    "JUMLAH_BELUM_ADA_LAPORAN": "Belum ada laporan"})
        names = ["Laporan final", "Laporan draf atau revisi", "Belum ada laporan"]
        stacked = long[["NAMA_SEKSI"] + names].melt(id_vars="NAMA_SEKSI", var_name="Status", value_name="Jumlah")
        stacked["Urut"] = [names.index(v) for v in stacked["Status"]]
        chart = alt.Chart(stacked).mark_bar(size=16).encode(
            y=alt.Y("NAMA_SEKSI:N", sort=list(done["NAMA_SEKSI"]), axis=alt.Axis(title=None, labelLimit=240)),
            x=alt.X("Jumlah:Q", axis=alt.Axis(title="Jumlah kegiatan terlaksana"), stack="zero"),
            color=alt.Color("Status:N", scale=color_scale(names), legend=alt.Legend(title=None)),
            order=alt.Order("Urut:Q", sort="ascending"),
            tooltip=[alt.Tooltip("NAMA_SEKSI:N", title="Seksi"), alt.Tooltip("Status:N"), alt.Tooltip("Jumlah:Q", format="d")])
        show_chart(chart, height=max(240, 34 * len(done) + 60))
        show_table(done, [
            ("NAMA_SEKSI", "Seksi", text), ("JUMLAH_KEGIATAN", "Kegiatan", whole), ("JUMLAH_TERLAKSANA", "Terlaksana", whole),
            ("JUMLAH_LAPORAN_FINAL", "Laporan final", whole), ("JUMLAH_LAPORAN_DRAF_ATAU_REVISI", "Draf atau revisi", whole),
            ("JUMLAH_BELUM_ADA_LAPORAN", "Belum ada laporan", whole),
            ("PERSEN_TERLAKSANA_DENGAN_LAPORAN_FINAL", "Terlaksana dengan laporan final", lambda v: percent(v, 0)),
        ])

        st.subheader("Target peserta dan kehadiran sebenarnya")
        held = events[events["STATUS_KEGIATAN"] == "Terlaksana"].dropna(subset=["PERSEN_CAPAIAN_TARGET"]).copy()
        if held.empty:
            st.info("Belum ada kegiatan terlaksana dengan target peserta.")
        else:
            held["Tahun"] = held["TANGGAL_MULAI"].dt.year
            yearly = held.groupby("Tahun", as_index=False)["PERSEN_CAPAIAN_TARGET"].mean()
            yearly["Teks"] = [percent(v, 0) for v in yearly["PERSEN_CAPAIAN_TARGET"]]
            yearly["Tahun"] = yearly["Tahun"].astype(str)
            bar_chart(yearly, "Tahun", "PERSEN_CAPAIAN_TARGET", "Rata-rata % capaian target peserta", list(yearly["Tahun"]),
                      label_column="Teks")
            st.caption("Rata-rata persentase peserta aktual terhadap target, untuk kegiatan yang terlaksana pada tahun itu.")

        st.subheader("Daftar kegiatan")
        sections = ["Semua seksi"] + sorted(events["NAMA_SEKSI"].unique())
        section = st.selectbox("Seksi", sections, key="seksi_kegiatan")
        listing = events if section == "Semua seksi" else events[events["NAMA_SEKSI"] == section]
        show_table(listing.sort_values("TANGGAL_MULAI", ascending=False), [
            ("NAMA_KEGIATAN", "Kegiatan", text), ("NAMA_SEKSI", "Seksi", text), ("TANGGAL_MULAI", "Mulai", long_date),
            ("STATUS_KEGIATAN", "Status", text), ("TARGET_PESERTA", "Target peserta", whole),
            ("JUMLAH_PESERTA_AKTUAL", "Peserta aktual", whole), ("STATUS_PELAPORAN", "Laporan", text),
        ])


# --------------------------------------------------------------------------------------------
# Page: Survei
# --------------------------------------------------------------------------------------------
def page_surveys():
    st.title("Survei umat")
    banner()
    results = get("HASIL_SURVEI")
    likert = get("RINGKASAN_SKOR_LIKERT")

    surveys = (results[["ID_SURVEI", "JUDUL_SURVEI", "STATUS_SURVEI"]].drop_duplicates().sort_values("JUDUL_SURVEI"))
    if surveys.empty:
        st.info("Belum ada hasil survei.")
        return
    titles = list(surveys["JUDUL_SURVEI"])
    chosen = st.selectbox("Survei", titles)
    survey = surveys[surveys["JUDUL_SURVEI"] == chosen].iloc[0]
    st.caption(f"Status survei: {survey['STATUS_SURVEI']}. Hasil ditampilkan dalam bentuk agregat; tidak ada jawaban individu.")
    data = results[results["ID_SURVEI"] == survey["ID_SURVEI"]]

    questions = (data[["ID_PERTANYAAN", "NOMOR_PERTANYAAN", "TEKS_PERTANYAAN"]].drop_duplicates().sort_values("NOMOR_PERTANYAAN"))
    labels = [f"{int(r['NOMOR_PERTANYAAN'])}. {r['TEKS_PERTANYAAN']}" for _, r in questions.iterrows()]
    pick = st.selectbox("Pertanyaan", labels)
    question = questions.iloc[labels.index(pick)]
    answers = data[data["ID_PERTANYAAN"] == question["ID_PERTANYAAN"]].sort_values("NOMOR_OPSI").copy()

    respondents = answers["TOTAL_RESPONDEN_PERTANYAAN"].max()
    if _missing(respondents) or respondents == 0:
        st.info("Survei ini belum memiliki jawaban.")
    else:
        st.subheader(question["TEKS_PERTANYAAN"])
        st.caption(f"{whole(respondents)} responden menjawab pertanyaan ini.")
        answers["Teks"] = [f"{percent(p, 1)} ({whole(n)} responden)" for p, n in zip(answers["PERSENTASE_JAWABAN"], answers["JUMLAH_RESPONDEN"])]
        horizontal_bar_chart(answers, "KATEGORI_JAWABAN", "PERSENTASE_JAWABAN", "% responden", list(answers["KATEGORI_JAWABAN"]),
                             label_column="Teks")
        with st.expander("Tabel"):
            show_table(answers, [("KATEGORI_JAWABAN", "Jawaban", text), ("JUMLAH_RESPONDEN", "Responden", whole),
                                 ("PERSENTASE_JAWABAN", "Persentase", lambda v: percent(v, 1))])

    mine = likert[likert["ID_SURVEI"] == survey["ID_SURVEI"]].sort_values("NOMOR_PERTANYAAN")
    if not mine.empty:
        st.subheader("Ringkasan skala setuju")
        show_table(mine, [
            ("NOMOR_PERTANYAAN", "No", whole), ("TEKS_PERTANYAAN", "Pernyataan", text), ("JUMLAH_RESPONDEN", "Responden", whole),
            ("SKOR_RATA_RATA", "Skor rata-rata", two_decimals),
            ("PERSEN_SETUJU_ATAU_SANGAT_SETUJU", "Setuju atau sangat setuju", lambda v: percent(v, 1)),
        ])
    how_to_read("Persentase dihitung dari responden yang menjawab pertanyaan itu; responden boleh melewati pertanyaan.",
                "Urutan jawaban mengikuti urutan pilihan pada kuesioner.")


# --------------------------------------------------------------------------------------------
# Page: Tentang data
# --------------------------------------------------------------------------------------------
def page_about():
    st.title("Tentang data")
    banner()
    masses = get("PELAKSANAAN_MISA")
    held = masses[masses["STATUS_PELAKSANAAN"] == "Terlaksana"]
    if not held.empty:
        st.write(f"Catatan Misa yang terlaksana tersedia sampai **{long_date(held['TANGGAL_MISA'].max())}** "
                 f"(mulai {long_date(held['TANGGAL_MISA'].min())}).")
    st.markdown(
        """
**Apa ini?** Demonstrasi Pusat Informasi Paroki: contoh bagaimana informasi dari berbagai fungsi paroki dapat dikumpulkan,
dirapikan, dihubungkan, dan disajikan. Ini bukti konsep, bukan sistem produksi.

**Seluruh data fiktif.** Nama, keluarga, wilayah, lingkungan, kegiatan, angka kolekte, dan peristiwa dibuat oleh program.
Batas wilayah dan peta, bila ada pada versi mendatang, hanya ilustrasi dan bukan batas resmi.

**Privasi.** Dasbor hanya membaca ringkasan agregat. Tidak ada nama, keluarga, atau sumbangan perorangan yang ditampilkan.

**Tentang angka sumbangan dan kolekte.** Angka ini menggambarkan administrasi keuangan dan kapasitas ekonomi. Angka ini bukan ukuran iman,
komitmen rohani, atau kemurahan hati, dan tidak dipakai untuk memeringkat wilayah atau lingkungan.

**Tentang proyeksi.** Garis tren adalah garis lurus dari lima tahun lengkap. Ia membantu menggambarkan arah, bukan meramalkan masa depan.
Peristiwa luar biasa tidak bisa diprediksi; karena itu dicatat agar penyimpangan perkiraan dapat dijelaskan.
"""
    )
    st.subheader("Sumber data")
    st.write(f"Dasbor membaca {len(VIEWS)} tampilan (view) pada skema `{SCHEMA}` di basis data `{DATABASE}`:")
    st.code("\n".join(VIEWS))
    st.caption(f"Label sumber pada setiap tampilan: \"{DATA_LABEL}\". Data disegarkan dari Snowflake setiap {CACHE_SECONDS // 60} menit, "
               "atau gunakan tombol \"Muat ulang data\" pada menu samping.")


# --------------------------------------------------------------------------------------------
# Navigation
# --------------------------------------------------------------------------------------------
PAGES = {
    "Ringkasan": page_summary,
    "Kegiatan mendatang": page_upcoming,
    "Pemasukan dan pengeluaran": page_income_outcome,
    "Kolekte dan kehadiran": page_offertory_attendance,
    "Peristiwa luar biasa": page_events,
    "Sumbangan khusus": page_donations,
    "Rencana, anggaran, kegiatan": page_plans,
    "Survei umat": page_surveys,
    "Tentang data": page_about,
}


def main():
    st.set_page_config(page_title="Pusat Informasi Paroki (simulasi)", page_icon="⛪", layout="wide")
    st.sidebar.title("Pusat Informasi Paroki")
    st.sidebar.caption("Demonstrasi dengan data simulasi")
    choice = st.sidebar.radio("Menu", list(PAGES))
    st.sidebar.button("Muat ulang data", on_click=st.cache_data.clear)
    st.sidebar.caption("Sumber: skema ANALISIS (hanya angka agregat).")
    PAGES[choice]()


if __name__ == "__main__":
    main()
