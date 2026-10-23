"use strict";
/* Chart builders. Each returns HTML (a placeholder that is drawn by main.js with Vega-Lite). They mirror the Altair
   charts of the Streamlit dashboard: thin marks, quiet grid, legend on top, fixed colours, no ranking. */

function chartConfig() {
  var k = ink();
  return {
    axis: {grid: true, gridColor: NEUTRAL, gridOpacity: 0.25, gridWidth: 1, domainColor: NEUTRAL, domainOpacity: 0.5,
           tickColor: NEUTRAL, tickOpacity: 0.5, labelFontSize: 12, titleFontSize: 12, titleFontWeight: "normal",
           labelColor: k, titleColor: k},
    view: {stroke: null, strokeWidth: 0},
    // on a phone the legend entries are stacked, because a single row would run off the screen
    legend: Object.assign({orient: "top", labelFontSize: 12, labelLimit: 360, symbolStrokeWidth: 3, labelColor: k, titleColor: k},
                          window.innerWidth < 700 ? {columns: 1, labelLimit: 220} : {})
  };
}
function finalSpec(spec, height) {
  return Object.assign({
    width: "container", height: height,
    autosize: {type: "fit", contains: "padding"}, background: "transparent", config: chartConfig()
  }, spec);
}
var MONTH_LABEL_EXPR = '["Jan","Feb","Mar","Apr","Mei","Jun","Jul","Agu","Sep","Okt","Nov","Des"][month(datum.value)] + " " + year(datum.value)';

// ------------------------------------------------------------------------------------------------
// Income versus outcome per year, with the straight-line trend
// ------------------------------------------------------------------------------------------------
function incomeOutcomeChart(annual, projection) {
  var rows = [];
  annual.filter(function (r) { return r.TAHUN_LENGKAP; }).forEach(function (r) {
    rows.push({Tahun: r.TAHUN, Seri: "Kolekte", Juta: r.PEMASUKAN_KOLEKTE / 1e6, Jenis: "Aktual"});
    rows.push({Tahun: r.TAHUN, Seri: "Pengeluaran program", Juta: r.PENGELUARAN_PROGRAM / 1e6, Jenis: "Aktual"});
  });
  projection.forEach(function (r) {
    rows.push({Tahun: r.TAHUN, Seri: "Kolekte", Juta: r.KOLEKTE_TREN / 1e6, Jenis: "Garis tren dan proyeksi"});
    rows.push({Tahun: r.TAHUN, Seri: "Pengeluaran program", Juta: r.PENGELUARAN_TREN / 1e6, Jenis: "Garis tren dan proyeksi"});
  });
  rows.forEach(function (r) { r.Nilai = "Rp " + number(r.Juta, 1) + " jt"; });
  var series = ["Kolekte", "Pengeluaran program"], kinds = ["Aktual", "Garis tren dan proyeksi"];
  var enc = {
    x: {field: "Tahun", type: "quantitative", axis: {format: "d", title: null, tickMinStep: 1}},
    y: {field: "Juta", type: "quantitative", axis: {title: "Juta rupiah"}, scale: {zero: true}},
    color: {field: "Seri", type: "nominal", scale: colorScale(series), legend: {title: null}},
    tooltip: [{field: "Tahun", type: "quantitative", format: "d"}, {field: "Seri", type: "nominal", title: "Seri"},
              {field: "Nilai", type: "nominal", title: "Nilai"}, {field: "Jenis", type: "nominal", title: "Jenis"}]
  };
  var layers = [
    {mark: {type: "line", strokeWidth: 2, strokeJoin: "round", strokeCap: "round"},
     encoding: Object.assign({}, enc, {strokeDash: {field: "Jenis", type: "nominal", scale: {domain: kinds, range: [[1, 0], [6, 4]]}, legend: {title: null}}})},
    {transform: [{filter: "datum.Jenis === 'Aktual'"}], mark: {type: "point", filled: true, size: 70, opacity: 1}, encoding: enc}
  ];
  var crossing = projection.map(function (r) { return r.TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE; }).filter(function (v) { return !missing(v); });
  if (crossing.length) {
    var marker = [{Tahun: crossing[0], Teks: "Perkiraan titik silang: " + crossing[0]}];
    layers.push({data: {values: marker}, mark: {type: "rule", color: NEUTRAL, strokeWidth: 1}, encoding: {x: {field: "Tahun", type: "quantitative"}}});
    layers.push({data: {values: marker}, mark: {type: "text", align: "right", dx: -6, fontSize: 12, color: NEUTRAL},
                 encoding: {x: {field: "Tahun", type: "quantitative"}, y: {value: 12}, text: {field: "Teks", type: "nominal"}}});
  }
  return chartBox({data: {values: rows}, layer: layers}, 340);
}

// ------------------------------------------------------------------------------------------------
// Lines for one or more series. rows carry the x field and one field per series label.
// ------------------------------------------------------------------------------------------------
function lineChart(rows, xField, series, yTitle, height, dateAxis) {
  var long = [];
  rows.forEach(function (r) {
    series.forEach(function (s) {
      if (!missing(r[s])) {
        long.push({x: r[xField], Seri: s, Nilai: Number(r[s]), Teks: number(r[s], 1),
                   Waktu: dateAxis ? MONTHS[monthOf(r[xField])] + " " + yearOf(r[xField]) : String(r[xField])});
      }
    });
  });
  var xEnc = dateAxis
    ? {field: "x", type: "temporal", axis: {format: "%Y", title: null, tickCount: "year"}}
    : {field: "x", type: "quantitative", axis: {format: "d", title: null, tickMinStep: 1}};
  var enc = {
    x: xEnc,
    y: {field: "Nilai", type: "quantitative", axis: {title: yTitle}, scale: {zero: true}},
    color: {field: "Seri", type: "nominal", scale: colorScale(series), legend: series.length > 1 ? {title: null} : null},
    tooltip: [{field: "Waktu", type: "nominal", title: dateAxis ? "Periode" : "Tahun"}, {field: "Seri", type: "nominal", title: "Seri"},
              {field: "Teks", type: "nominal", title: "Nilai"}]
  };
  var layers = [{mark: {type: "line", strokeWidth: 2, strokeJoin: "round", strokeCap: "round"}, encoding: enc}];
  if (!dateAxis) { layers.push({mark: {type: "point", filled: true, size: 70, opacity: 1}, encoding: enc}); }
  return chartBox({data: {values: long}, layer: layers}, height || 300);
}

// ------------------------------------------------------------------------------------------------
// Bars: one colour, fixed category order (never value order), the value at the tip
// ------------------------------------------------------------------------------------------------
function barChart(rows, category, valueField, valueTitle, order, labelField, height, colorIndex) {
  var data = rows.map(function (r) {
    return {Kategori: r[category], Nilai: Number(r[valueField]), Teks: labelField ? r[labelField] : number(r[valueField], 1)};
  });
  var top = maxOf(col(data, "Nilai"));
  var base = {x: {field: "Kategori", type: "nominal", sort: order, axis: {title: null, labelAngle: 0}},
              y: {field: "Nilai", type: "quantitative", axis: {title: valueTitle}, scale: top > 0 ? {zero: true, domain: [0, top * 1.12]} : {zero: true}},
              tooltip: [{field: "Kategori", type: "nominal", title: "Kelompok"}, {field: "Teks", type: "nominal", title: "Nilai"}]};
  return chartBox({data: {values: data}, layer: [
    {mark: {type: "bar", size: 24, color: palette()[colorIndex || 0], cornerRadiusTopLeft: 4, cornerRadiusTopRight: 4}, encoding: base},
    {mark: {type: "text", dy: -8, fontSize: 12, color: ink()}, encoding: Object.assign({}, base, {text: {field: "Teks", type: "nominal"}})}
  ]}, height || 300);
}
function hbarChart(rows, category, valueField, valueTitle, order, labelField, reference, height, colorIndex, maxValue) {
  var data = rows.map(function (r) {
    return {Kategori: r[category], Nilai: Number(r[valueField]), Teks: labelField ? r[labelField] : number(r[valueField], 1)};
  });
  var top = maxOf(col(data, "Nilai"));
  // room to the right of the longest bar, so that its value is not cut off
  var scale = maxValue ? {zero: true, domain: [0, maxValue]} : (top > 0 ? {zero: true, domain: [0, top * 1.22]} : {zero: true});
  var base = {y: {field: "Kategori", type: "nominal", sort: order, axis: {title: null, labelLimit: 260}},
              x: {field: "Nilai", type: "quantitative", axis: {title: valueTitle}, scale: scale},
              tooltip: [{field: "Kategori", type: "nominal", title: "Kelompok"}, {field: "Teks", type: "nominal", title: "Nilai"}]};
  var layers = [
    {mark: {type: "bar", size: 16, color: palette()[colorIndex || 0], cornerRadiusTopRight: 4, cornerRadiusBottomRight: 4}, encoding: base},
    {mark: {type: "text", align: "left", dx: 6, fontSize: 12, color: ink()}, encoding: Object.assign({}, base, {text: {field: "Teks", type: "nominal"}})}
  ];
  if (reference !== null && reference !== undefined) {
    layers.push({data: {values: [{Acuan: reference}]}, mark: {type: "rule", color: NEUTRAL, strokeWidth: 1}, encoding: {x: {field: "Acuan", type: "quantitative"}}});
  }
  return chartBox({data: {values: data}, layer: layers}, height || Math.max(120, 30 * data.length + 40));
}

// ------------------------------------------------------------------------------------------------
// Shadow forecast against the actual offertory
// ------------------------------------------------------------------------------------------------
var SERIES_ACTUAL = "Kolekte aktual", SERIES_FORECAST = "Perkiraan kolekte", SERIES_EVENT = "Pekan terdampak peristiwa";
var KIND_ORDINARY = "Pekan biasa", KIND_CALENDAR = "Hari raya atau kolekte khusus", KIND_EVENT = "Peristiwa luar biasa";
var FORECAST_KINDS = [KIND_ORDINARY, KIND_CALENDAR, KIND_EVENT];
var RECENT_WEEKS = 52, VIEW_RECENT = "12 bulan terakhir (lebih rinci)", VIEW_ALL = "Seluruh rentang tahun";

function forecastFrames(frame) {
  var rows = sortBy(frame, ["AWAL_PEKAN"]);
  var data = rows.map(function (r) {
    var aktual = missing(r.KOLEKTE_AKTUAL) ? null : r.KOLEKTE_AKTUAL / 1e6;
    var perk = missing(r.JUMLAH_PERKIRAAN) ? null : r.JUMLAH_PERKIRAAN / 1e6;
    var lo = missing(r.BATAS_BAWAH) ? null : r.BATAS_BAWAH / 1e6, hi = missing(r.BATAS_ATAS) ? null : r.BATAS_ATAS / 1e6;
    return {
      t: r.AWAL_PEKAN, akhir: addDays(r.AWAL_PEKAN, 7), aktual: aktual, perk: perk, lo: lo, hi: hi, status: r.STATUS_PEKAN,
      pekan: "Pekan " + longDate(r.AWAL_PEKAN),
      tAktual: aktual === null ? "belum lengkap" : rupiah(aktual * 1e6), tPerk: rupiah(perk === null ? null : perk * 1e6),
      tRentang: juta(lo === null ? null : lo * 1e6) + " sampai " + juta(hi === null ? null : hi * 1e6),
      tSelisih: signedPercent(r.SELISIH_PERSEN),
      tPeristiwa: typeof r.NAMA_PERISTIWA === "string" ? r.NAMA_PERISTIWA : "-",
      tKalender: typeof r.CATATAN_KALENDER === "string" ? r.CATATAN_KALENDER : "-",
      tJenis: typeof r.JENIS_PERISTIWA === "string" ? r.JENIS_PERISTIWA : "-",
      tTingkat: typeof r.TINGKAT_GANGGUAN === "string" ? r.TINGKAT_GANGGUAN : "-",
      kode: typeof r.NAMA_PERISTIWA === "string" ? r.ID_PERISTIWA : null,
      nama: typeof r.NAMA_PERISTIWA === "string" ? r.NAMA_PERISTIWA : null,
      nilai: aktual !== null ? aktual : perk, seri: SERIES_EVENT
    };
  });
  var long = [];
  data.forEach(function (d) {
    if (d.aktual !== null) { long.push({t: d.t, Seri: SERIES_ACTUAL, Juta: d.aktual}); }
  });
  data.forEach(function (d) {
    if (d.perk !== null) { long.push({t: d.t, Seri: SERIES_FORECAST, Juta: d.perk}); }
  });
  return {data: data, long: long, struck: data.filter(function (d) { return d.nama !== null; })};
}
function eventLabels(struck) {
  return groupBy(struck, function (d) { return d.kode; }).map(function (g) {
    var start = minOf(col(g[1], "t")), end = maxOf(col(g[1], "akhir"));
    return {kode: g[0], nama: g[1][0].nama, mulai: start, selesai: end, tengah: start + (end - start) / 2};
  }).sort(function (a, b) { return a.mulai - b.mulai; });
}
function eventList(struck) {
  var labels = eventLabels(struck);
  if (!labels.length) { return ""; }
  var known = {};
  V("DAMPAK_PERISTIWA_LUAR_BIASA").forEach(function (r) { known[r.ID_PERISTIWA] = r; });
  var items = labels.map(function (e) {
    var r = known[e.kode];
    return r ? "<li><strong>" + esc(e.kode) + "</strong>: " + esc(r.NAMA_PERISTIWA) + " (" + esc(r.JENIS_PERISTIWA) + ", gangguan " +
                esc(lower(r.TINGKAT_GANGGUAN)) + "), " + longDate(r.TANGGAL_MULAI) + " sampai " + longDate(r.TANGGAL_SELESAI) + "</li>"
             : "<li><strong>" + esc(e.kode) + "</strong>: " + esc(e.nama) + "</li>";
  });
  return '<div class="event-list"><strong>Peristiwa pada pekan berlatar abu-abu</strong><ul>' + items.join("") + "</ul></div>";
}
function forecastChart(frame, height, closeUp) {
  var f = forecastFrames(frame), data = f.data, p = palette();
  var zoomed = closeUp || data.length <= 80;
  var xAxis = zoomed ? {title: null, labelExpr: MONTH_LABEL_EXPR, tickCount: 6} : {format: "%Y", title: null, tickCount: "year"};
  var x = {field: "t", type: "temporal", axis: xAxis};
  var y = {field: "Juta", type: "quantitative", axis: {title: "Juta rupiah per pekan"}, scale: {zero: true}};
  var lineColour = {field: "Seri", type: "nominal", scale: {domain: [SERIES_ACTUAL, SERIES_FORECAST], range: [p[0], p[1]]}, legend: {title: null}};
  var layers = [];
  if (f.struck.length) {
    layers.push({data: {values: f.struck}, mark: {type: "rect", opacity: 0.22},
      encoding: {x: {field: "t", type: "temporal"}, x2: {field: "akhir"},
        color: {field: "seri", type: "nominal", scale: {domain: [SERIES_EVENT], range: [NEUTRAL]}, legend: {title: null, symbolOpacity: 0.5}},
        tooltip: [{field: "tPeristiwa", type: "nominal", title: "Peristiwa"}, {field: "kode", type: "nominal", title: "Kode"},
                  {field: "tJenis", type: "nominal", title: "Jenis"}, {field: "tTingkat", type: "nominal", title: "Tingkat gangguan"},
                  {field: "pekan", type: "nominal", title: "Pekan"}]}});
    layers.push({data: {values: eventLabels(f.struck)}, mark: {type: "text", angle: 270, align: "right", baseline: "middle", fontSize: 11, color: NEUTRAL},
      encoding: {x: {field: "tengah", type: "temporal"}, y: {value: 6}, text: {field: "kode", type: "nominal"},
                 tooltip: [{field: "nama", type: "nominal", title: "Peristiwa"}]}});
  }
  layers.push({data: {values: data.filter(function (d) { return d.lo !== null; })}, mark: {type: "area", opacity: 0.16, color: p[1]},
    encoding: {x: {field: "t", type: "temporal"}, y: {field: "lo", type: "quantitative"}, y2: {field: "hi"}}});
  layers.push({data: {values: f.long}, mark: {type: "line", strokeWidth: 2, strokeJoin: "round"},
    encoding: {x: x, y: y, color: lineColour,
      strokeDash: {field: "Seri", type: "nominal", scale: {domain: [SERIES_ACTUAL, SERIES_FORECAST], range: [[1, 0], [6, 4]]}, legend: {title: null}}}});
  if (data.length <= 80) {
    layers.push({data: {values: f.long}, mark: {type: "point", filled: true, size: 45, opacity: 1},
      encoding: {x: x, y: y, color: {field: "Seri", type: "nominal", scale: {domain: [SERIES_ACTUAL, SERIES_FORECAST], range: [p[0], p[1]]}, legend: null}}});
  }
  layers.push({data: {values: data}, mark: {type: "circle", size: 60, opacity: 0},
    encoding: {x: {field: "t", type: "temporal"}, y: {field: "nilai", type: "quantitative"},
      tooltip: [{field: "pekan", type: "nominal", title: "Pekan"}, {field: "tAktual", type: "nominal", title: "Kolekte aktual"},
                {field: "tPerk", type: "nominal", title: "Perkiraan kolekte"}, {field: "tRentang", type: "nominal", title: "Rentang 80%"},
                {field: "tSelisih", type: "nominal", title: "Selisih"}, {field: "tPeristiwa", type: "nominal", title: "Peristiwa"},
                {field: "tKalender", type: "nominal", title: "Catatan kalender"}]}});
  var ahead = data.filter(function (d) { return d.status !== "Lengkap"; });
  if (ahead.length && !closeUp) {
    var marker = [{t: minOf(col(ahead, "t")), Teks: "Perkiraan ke depan"}];
    layers.push({data: {values: marker}, mark: {type: "rule", color: NEUTRAL, strokeDash: [4, 4], strokeWidth: 1}, encoding: {x: {field: "t", type: "temporal"}}});
    layers.push({data: {values: marker}, mark: {type: "text", align: "right", dx: -6, fontSize: 12, color: NEUTRAL},
                 encoding: {x: {field: "t", type: "temporal"}, y: {value: 12}, text: {field: "Teks", type: "nominal"}}});
  }
  var spec = {layer: layers, resolve: {scale: {color: "independent", strokeDash: "independent"}}};
  return chartBox(spec, height || 360) + eventList(f.struck);
}

function eventGapChart(events, typical) {
  var data = events.map(function (e) {
    return {Peristiwa: e.NAMA_PERISTIWA, Nilai: e.SELISIH_PERSEN, Teks: signedPercent(e.SELISIH_PERSEN, Math.abs(e.SELISIH_PERSEN) < 1 ? 1 : 0)};
  });
  var order = data.map(function (d) { return d.Peristiwa; });
  var base = {y: {field: "Peristiwa", type: "nominal", sort: order, axis: {title: null, labelLimit: 300}},
              x: {field: "Nilai", type: "quantitative", axis: {title: "Selisih kolekte terhadap perkiraan (%)"}, scale: {zero: true}},
              tooltip: [{field: "Peristiwa", type: "nominal", title: "Peristiwa"}, {field: "Teks", type: "nominal", title: "Selisih"}]};
  var layers = [];
  if (!missing(typical)) {
    layers.push({data: {values: [{Bawah: -Number(typical), Atas: Number(typical)}]}, mark: {type: "rect", color: NEUTRAL, opacity: 0.18},
                 encoding: {x: {field: "Bawah", type: "quantitative"}, x2: {field: "Atas"}}});
  }
  layers.push({mark: {type: "bar", size: 16, color: palette()[1], cornerRadiusTopRight: 4, cornerRadiusBottomRight: 4}, encoding: base});
  // one text layer per side, and only when that side has bars (an empty layer makes Vega warn about an infinite extent)
  [["< 0", "right", -6], [">= 0", "left", 6]].forEach(function (side) {
    var part = data.filter(function (d) { return side[0] === "< 0" ? d.Nilai < 0 : d.Nilai >= 0; });
    if (part.length) {
      layers.push({data: {values: part}, mark: {type: "text", align: side[1], dx: side[2], fontSize: 12, color: ink()},
                   encoding: Object.assign({}, base, {text: {field: "Teks", type: "nominal"}})});
    }
  });
  layers.push({data: {values: [{Nol: 0}]}, mark: {type: "rule", color: NEUTRAL, strokeWidth: 1}, encoding: {x: {field: "Nol", type: "quantitative"}}});
  return chartBox({data: {values: data}, layer: layers}, Math.max(160, 34 * data.length + 50));
}

// Accuracy computed from the weeks that are drawn, so the figures follow the year filter exactly.
function accuracyByKind(rows) {
  var done = rows.filter(function (r) { return r.STATUS_PEKAN === "Lengkap"; }), out = [];
  FORECAST_KINDS.forEach(function (kind) {
    var part = done.filter(function (r) { return r.JENIS_PEKAN === kind; });
    if (!part.length) { return; }
    var err = part.map(function (r) { return 100 * (r.KOLEKTE_AKTUAL - r.JUMLAH_PERKIRAAN) / r.JUMLAH_PERKIRAAN; });
    out.push({kind: kind, n: part.length, galat: mean(err.map(Math.abs), function (v) { return v; }),
              selisih: mean(err, function (v) { return v; }),
              dalam: 100 * part.filter(function (r) { return r.POSISI_TERHADAP_RENTANG === "Dalam rentang"; }).length / part.length});
  });
  return out;
}
function recentWindow(rows) {
  var complete = rows.filter(function (r) { return r.STATUS_PEKAN === "Lengkap"; });
  if (!complete.length) { return rows; }
  var from = addDays(maxOf(col(complete, "AWAL_PEKAN")), -(RECENT_WEEKS - 1) * 7);
  return rows.filter(function (r) { return r.AWAL_PEKAN >= from; });
}
function weeklyWithForecast(weekly, forecasts) {
  var byWeek = {};
  forecasts.forEach(function (f) { byWeek[f.AWAL_PEKAN] = f; });
  return weekly.map(function (w) {
    var f = byWeek[w.AWAL_PEKAN] || {};
    return {AWAL_PEKAN: w.AWAL_PEKAN, KOLEKTE_AKTUAL: w.TOTAL_KOLEKTE, ID_PERISTIWA: w.ID_PERISTIWA, NAMA_PERISTIWA: w.NAMA_PERISTIWA,
            JENIS_PERISTIWA: w.JENIS_PERISTIWA, TINGKAT_GANGGUAN: w.TINGKAT_GANGGUAN, JUMLAH_PERKIRAAN: f.JUMLAH_PERKIRAAN,
            BATAS_BAWAH: f.BATAS_BAWAH, BATAS_ATAS: f.BATAS_ATAS, SELISIH_PERSEN: f.SELISIH_PERSEN,
            POSISI_TERHADAP_RENTANG: f.POSISI_TERHADAP_RENTANG, PENJELASAN_SELISIH: f.PENJELASAN_SELISIH,
            CATATAN_KALENDER: f.CATATAN_KALENDER, STATUS_PEKAN: "Lengkap"};
  });
}
// A radio that zooms the weekly chart to the last year (default) or shows the whole range.
function forecastViewChoice(rows, key) {
  var control = radio(key, "Jangka waktu grafik", [VIEW_RECENT, VIEW_ALL], VIEW_RECENT);
  return {html: control, rows: val(key, VIEW_RECENT) === VIEW_RECENT ? recentWindow(rows) : rows};
}

// ------------------------------------------------------------------------------------------------
// Upcoming activities: one dot per activity, date across, section down
// ------------------------------------------------------------------------------------------------
var STAGE_SCHEDULED = "Sudah dijadwalkan", STAGE_PLAN = "Masih rencana tahunan", STAGE_POSTPONED = "Ditunda, perlu jadwal baru";
function upcomingTimelineChart(rows) {
  var data = rows.map(function (r) {
    return {Tanggal: r.TANGGAL_MULAI, Lengkap: longDate(r.TANGGAL_MULAI), Seksi: r.NAMA_SEKSI, Kegiatan: r.NAMA_PROGRAM, Tahap: r.TAHAP,
            Anggaran: juta(r.ANGGARAN_RENCANA)};
  });
  var sections = uniq(col(data, "Seksi")).sort();
  var spec = {data: {values: data}, mark: {type: "point", filled: true, size: 130, opacity: 1}, encoding: {
    x: {field: "Tanggal", type: "temporal", axis: {format: "%d/%m", title: "Tanggal (hari/bulan)", tickCount: 8}},
    y: {field: "Seksi", type: "nominal", sort: sections, axis: {title: null, labelLimit: 260}},
    color: {field: "Tahap", type: "nominal", scale: colorScale([STAGE_SCHEDULED, STAGE_PLAN]), legend: {title: null}},
    tooltip: [{field: "Kegiatan", type: "nominal"}, {field: "Lengkap", type: "nominal", title: "Tanggal"}, {field: "Seksi", type: "nominal"},
              {field: "Tahap", type: "nominal"}, {field: "Anggaran", type: "nominal", title: "Anggaran rencana"}]}};
  return chartBox(spec, Math.max(220, 32 * sections.length + 70));
}

// ------------------------------------------------------------------------------------------------
// Demographics
// ------------------------------------------------------------------------------------------------
var GENDERS = ["Laki-laki", "Perempuan"];
var STAGE_RAMPS = {light: ["#cfe0f7", "#8db8ec", "#2a78d6", "#154c93"], dark: ["#274b7a", "#3a73bd", "#5e9ae8", "#a9c9f4"]};
function stageScale(labels) { // four ordered life stages are one quantity, young to old: one hue from light to dark
  return {domain: labels.slice(), range: STAGE_RAMPS[theme].slice(0, labels.length)};
}
// Back-to-back bars: men to the left, women to the right, the oldest group on top. A hidden cell has no count and no bar.
function populationPyramid(rows) {
  var data = rows.map(function (r) {
    var n = missing(r.JUMLAH_UMAT) ? null : Number(r.JUMLAH_UMAT);
    return {Usia: r.KELOMPOK_USIA, Urut: r.URUTAN_KELOMPOK, Jenis: r.JENIS_KELAMIN, Nilai: n === null ? null : (r.JENIS_KELAMIN === GENDERS[0] ? -n : n),
            Teks: n === null ? "disembunyikan" : whole(n)};
  });
  var order = uniq(col(sortBy(data, ["Urut"], [true]), "Usia"));
  var base = {
    y: {field: "Usia", type: "nominal", sort: order, axis: {title: "Usia (tahun)", labelLimit: 160}},
    x: {field: "Nilai", type: "quantitative", axis: {title: "Jumlah umat", labelExpr: "abs(datum.value)"}, scale: {zero: true}},
    tooltip: [{field: "Usia", type: "nominal", title: "Usia"}, {field: "Jenis", type: "nominal", title: "Jenis kelamin"}, {field: "Teks", type: "nominal", title: "Jumlah umat"}]
  };
  var shown = data.filter(function (d) { return d.Nilai !== null; });
  var layers = [
    {data: {values: data}, mark: {type: "bar", size: 18},
     encoding: Object.assign({}, base, {color: {field: "Jenis", type: "nominal", scale: colorScale(GENDERS), legend: {title: null}}})}
  ];
  [[function (d) { return d.Nilai < 0; }, "right", -5], [function (d) { return d.Nilai >= 0; }, "left", 5]].forEach(function (side) {
    var part = shown.filter(side[0]);
    if (part.length) {
      layers.push({data: {values: part}, mark: {type: "text", align: side[1], dx: side[2], fontSize: 11, color: ink()},
                   encoding: Object.assign({}, base, {text: {field: "Teks", type: "nominal"}})});
    }
  });
  layers.push({data: {values: [{Nol: 0}]}, mark: {type: "rule", color: NEUTRAL, strokeWidth: 1}, encoding: {x: {field: "Nol", type: "quantitative"}}});
  return chartBox({layer: layers}, Math.max(260, 34 * order.length + 60));
}
// Life stages per region, stacked. share = true draws the percentage within the region instead of the number of people.
function regionStageChart(rows, share) {
  var data = sortBy(rows, ["NAMA_WILAYAH", "URUTAN_KELOMPOK"]).map(function (r) {
    var v = share ? r.PERSEN_DALAM_WILAYAH : r.JUMLAH_UMAT;
    return {Wilayah: r.NAMA_WILAYAH, Kelompok: r.KELOMPOK_KEHIDUPAN, Urut: r.URUTAN_KELOMPOK, Nilai: missing(v) ? null : Number(v),
            Teks: missing(v) ? "disembunyikan" : (share ? percent(v) : whole(v))};
  });
  var regions = uniq(col(data, "Wilayah"));
  var stages = uniq(col(sortBy(data, ["Urut"]), "Kelompok"));
  return chartBox({data: {values: data.filter(function (d) { return d.Nilai !== null; })}, mark: {type: "bar", size: 22}, encoding: {
    y: {field: "Wilayah", type: "nominal", sort: regions, axis: {title: null, labelLimit: 240}},
    x: {field: "Nilai", type: "quantitative", axis: {title: share ? "% umat aktif di wilayah" : "Jumlah umat aktif"}, stack: "zero"},
    color: {field: "Kelompok", type: "nominal", scale: stageScale(stages), legend: {title: null}},
    order: {field: "Urut", type: "quantitative", sort: "ascending"},
    tooltip: [{field: "Wilayah", type: "nominal", title: "Wilayah"}, {field: "Kelompok", type: "nominal", title: "Kelompok"}, {field: "Teks", type: "nominal", title: "Nilai"}]}},
    Math.max(240, 44 * regions.length + 70));
}
