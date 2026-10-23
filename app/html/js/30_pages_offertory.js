"use strict";
/* Pages: Kolekte dan kehadiran, Perkiraan kolekte, Peristiwa luar biasa. */

var PAYDAY_GROUPS = ["Tanggal 1-7", "Tanggal 8-14", "Tanggal 15-21", "Tanggal 22-31"];
var SEVERITY_ORDER = ["Ringan", "Sedang", "Berat"];

function inYears(rows, first, lastYear) { // weeks are filtered by the year of their Sunday
  return rows.filter(function (r) { var y = weekYear(r.AWAL_PEKAN); return y >= first && y <= lastYear; });
}
function eventHeading(row) {
  return "<p><strong>" + esc(row.NAMA_PERISTIWA) + "</strong> (" + esc(row.JENIS_PERISTIWA) + ", gangguan " + esc(lower(row.TINGKAT_GANGGUAN)) + "), " +
    esc(longDate(row.TANGGAL_MULAI)) + " sampai " + esc(longDate(row.TANGGAL_SELESAI)) + "</p>";
}

// ------------------------------------------------------------------------------------------------
function pageOffertoryAttendance() {
  var attendance = V("KEHADIRAN_MISA_BULANAN"), offertory = V("KOLEKTE_MISA_BULANAN");
  var weekly = completeWeeks(V("KOLEKTE_MINGGUAN_DAN_PERISTIWA")), payday = V("POLA_KOLEKTE_HARI_DALAM_BULAN");
  var trend = sortBy(V("TREN_KEHADIRAN_PERIODE"), ["TAHUN", "BULAN"]);
  var out = [title("Kolekte dan kehadiran"), banner()];

  var sessions = ["Semua sesi"].concat(uniq(col(attendance, "NAMA_MISA")).sort());
  var yr = yearRange("rentang.kolekte", col(attendance, "TAHUN"));
  out.push(columns([select("sesi_kolekte", "Sesi Misa", sessions), yr.html]));
  var choice = val("sesi_kolekte", "Semua sesi"), first = yr.first, lastYear = yr.last;

  var att = attendance.filter(function (r) { return r.TAHUN >= first && r.TAHUN <= lastYear; });
  var off = offertory.filter(function (r) { return r.TAHUN >= first && r.TAHUN <= lastYear; });
  if (choice !== "Semua sesi") {
    att = att.filter(function (r) { return r.NAMA_MISA === choice; });
    off = off.filter(function (r) { return r.NAMA_MISA === choice; });
  }
  out.push(tiles([
    metric("Misa terlaksana", whole(sum(att, "JUMLAH_MISA_TERLAKSANA"))),
    metric("Rata-rata umat per Misa", number(sum(att, "TOTAL_UMAT") / Math.max(1, sum(att, "JUMLAH_MISA_TERLAKSANA")), 0)),
    metric("Kolekte belum dihitung", whole(sum(off, "JUMLAH_BELUM_DIHITUNG")), "Catatan kolekte yang hasil penghitungannya belum masuk."),
    metric("Kehadiran belum final", whole(sum(att, "JUMLAH_BELUM_FINAL")), "Catatan kehadiran yang masih menunggu validasi.")
  ]));

  var t = tabs("tab.kolekte", ["Kehadiran", "Kolekte", "Hari gajian", "Hubungan dengan kehadiran"]);
  out.push(t.html);

  if (t.active === "Kehadiran") {
    var monthly = sortBy(groupBy(att, function (r) { return r.TAHUN * 100 + r.BULAN; }).map(function (g) {
      var umat = sum(g[1], "TOTAL_UMAT"), misa = sum(g[1], "JUMLAH_MISA_TERLAKSANA");
      return {Bulan: monthStart(g[1][0].TAHUN, g[1][0].BULAN), "Rata-rata umat per Misa": umat / Math.max(1, misa), key: g[0]};
    }), ["key"]);
    out.push(sub("Rata-rata umat per Misa, per bulan"));
    out.push(lineChart(monthly, "Bulan", ["Rata-rata umat per Misa"], "Umat per Misa", 300, true));
    var typical = median(col(trend, "JUMLAH_MISA_TERLAKSANA"));
    var full = trend.filter(function (r) { return r.JUMLAH_MISA_TERLAKSANA >= 0.8 * typical; });
    if (full.length) {
      var latest = last(full);
      out.push(caption("Seluruh sesi, " + esc(latest.NAMA_PERIODE) + " (bulan lengkap terakhir): " + number(latest.RATA_RATA_UMAT_PER_MISA, 0) +
        " umat per Misa, " + signedPercent(latest.PERUBAHAN_PERSEN_RATA_RATA) + " dibanding bulan sebelumnya."));
    }
  } else if (t.active === "Kolekte") {
    out.push(sub("Kolekte aktual dan perkiraan kolekte, per pekan"));
    var forecasts = inYears(V("KOLEKTE_AKTUAL_VS_PERKIRAAN"), first, lastYear);
    var drawn = forecastViewChoice(forecasts, "jangka_grafik_kolekte");
    out.push(drawn.html);
    out.push(forecastChart(drawn.rows, 340));
    out.push(caption("Garis biru adalah kolekte aktual seluruh sesi Misa, garis putus-putus oranye adalah perkiraan kolekte yang dibuat empat pekan sebelumnya, " +
      "dan pita oranye muda adalah rentang 80%. Pekan berlatar abu-abu terkena peristiwa luar biasa. Ke kanan garis putus-putus vertikal " +
      'hanya ada perkiraan. Seberapa tepat perkiraan ini dibahas pada halaman "Perkiraan kolekte".'));
    if (choice !== "Semua sesi") { out.push(info("Perkiraan dibuat untuk seluruh sesi Misa, sehingga grafik ini tidak mengikuti pilihan sesi di atas.")); }

    var preferred = ["Kolekte Pertama", "Kolekte Kedua", "Kolekte Khusus"];
    var found = uniq(col(off, "NAMA_JENIS_KOLEKTE"));
    var types = preferred.filter(function (n) { return found.indexOf(n) >= 0; }).concat(found.filter(function (n) { return preferred.indexOf(n) < 0; }).sort());
    var warning = "";
    if (types.length > 3) { warning = warn("Jenis kolekte lebih dari tiga; grafik hanya menampilkan tiga jenis pertama."); types = types.slice(0, 3); }
    var grouped = groupBy(off.filter(function (r) { return types.indexOf(r.NAMA_JENIS_KOLEKTE) >= 0; }), function (r) { return r.TAHUN * 100 + r.BULAN + "|" + r.NAMA_JENIS_KOLEKTE; })
      .map(function (g) {
        var jt = sum(g[1], "TOTAL_TERCATAT") / 1e6, r0 = g[1][0];
        return {Bulan: monthStart(r0.TAHUN, r0.BULAN), Juta: jt, Jenis: r0.NAMA_JENIS_KOLEKTE, Teks: "Rp " + number(jt, 2) + " jt",
                Waktu: MONTHS[r0.BULAN - 1] + " " + r0.TAHUN};
      });
    out.push(sub("Kolekte tercatat per bulan menurut jenis kolekte"));
    out.push(warning);
    out.push(chartBox({data: {values: grouped}, mark: {type: "bar", size: 6}, encoding: {
      x: {field: "Bulan", type: "temporal", axis: {format: "%Y", title: null, tickCount: "year"}},
      y: {field: "Juta", type: "quantitative", axis: {title: "Juta rupiah"}, stack: "zero"},
      color: {field: "Jenis", type: "nominal", scale: colorScale(types), legend: {title: null}},
      tooltip: [{field: "Waktu", type: "nominal", title: "Bulan"}, {field: "Jenis", type: "nominal", title: "Jenis"}, {field: "Teks", type: "nominal", title: "Nilai"}]}}, 320));
    out.push(caption("Jumlah tercatat adalah angka yang dicatat saat Misa. Hasil penghitungan menyusul dan statusnya " +
      "(cocok, ada selisih, belum dihitung) dihitung pada ringkasan di bawah."));
    out.push(expander("Status rekonsiliasi", bullets([
      "Sudah cocok: <strong>" + whole(sum(off, "JUMLAH_SUDAH_COCOK")) + "</strong> catatan",
      "Ada selisih: <strong>" + whole(sum(off, "JUMLAH_ADA_SELISIH")) + "</strong> catatan",
      "Belum dihitung: <strong>" + whole(sum(off, "JUMLAH_BELUM_DIHITUNG")) + "</strong> catatan"])));
  } else if (t.active === "Hari gajian") {
    var years = payday.filter(function (r) { return r.TAHUN >= first && r.TAHUN <= lastYear; });
    var byGroup = PAYDAY_GROUPS.map(function (name) {
      var part = years.filter(function (r) { return r.KELOMPOK_TANGGAL === name; });
      return part.length ? {Kelompok: name, Kolekte: sum(part, "TOTAL_KOLEKTE"), Umat: sum(part, "TOTAL_UMAT")} : null;
    }).filter(function (r) { return r; });
    byGroup.forEach(function (r) { r.PerUmat = r.Kolekte / Math.max(1, r.Umat); r.Teks = rupiah(r.PerUmat); });
    out.push(sub("Kolekte per umat menurut tanggal dalam bulan"));
    out.push(barChart(byGroup, "Kelompok", "PerUmat", "Rupiah per umat", PAYDAY_GROUPS, "Teks", 300, 0));
    if (byGroup.length && minOf(col(byGroup, "PerUmat")) > 0) {
      var firstWeek = byGroup.filter(function (r) { return r.Kelompok === PAYDAY_GROUPS[0]; })[0];
      var lastWeek = byGroup.filter(function (r) { return r.Kelompok === PAYDAY_GROUPS[PAYDAY_GROUPS.length - 1]; })[0];
      if (firstWeek && lastWeek) {
        out.push(para("Pada minggu pertama setiap bulan (sesudah gajian), kolekte per umat sekitar <strong>" + number(firstWeek.PerUmat / lastWeek.PerUmat, 1) +
          " kali</strong> kolekte pada akhir bulan."));
      }
    }
    out.push(caption("Perbedaan ini wajar dan perlu diperhitungkan ketika membandingkan bulan atau membuat perkiraan."));
  } else {
    var weeks = inYears(weekly, first, lastYear).map(function (r) {
      var flagged = typeof r.NAMA_PERISTIWA === "string";
      return {Umat: Number(r.TOTAL_UMAT), Juta: Number(r.TOTAL_KOLEKTE) / 1e6, Jenis: flagged ? "Pekan terdampak peristiwa" : "Pekan biasa",
              Pekan: "Pekan " + longDate(r.AWAL_PEKAN), Peristiwa: text(r.NAMA_PERISTIWA), Teks: "Rp " + number(Number(r.TOTAL_KOLEKTE) / 1e6, 1) + " jt"};
    });
    var kinds = ["Pekan biasa", "Pekan terdampak peristiwa"];
    var normal = weeks.filter(function (r) { return r.Jenis === "Pekan biasa"; });
    var encX = {field: "Umat", type: "quantitative", axis: {title: "Jumlah umat dalam satu pekan"}};
    var encY = {field: "Juta", type: "quantitative", axis: {title: "Kolekte (juta rupiah)"}, scale: {zero: true}};
    var layers = [{data: {values: weeks}, mark: {type: "point", filled: true, size: 60, opacity: 0.85},
      encoding: {x: encX, y: encY, color: {field: "Jenis", type: "nominal", scale: colorScale(kinds), legend: {title: null}},
        tooltip: [{field: "Pekan", type: "nominal"}, {field: "Umat", type: "quantitative", title: "Umat", format: "d"},
                  {field: "Teks", type: "nominal", title: "Kolekte"}, {field: "Peristiwa", type: "nominal"}]}}];
    if (normal.length >= 3) {
      layers.push({data: {values: normal}, transform: [{regression: "Juta", on: "Umat"}], mark: {type: "line", color: NEUTRAL, strokeWidth: 2},
        encoding: {x: {field: "Umat", type: "quantitative"}, y: {field: "Juta", type: "quantitative"}}});
    }
    out.push(sub("Jumlah umat dan kolekte per pekan"));
    out.push(chartBox({layer: layers}, 340));
    out.push(caption("Semakin banyak umat hadir, semakin besar kolekte pekan itu. Garis abu-abu dihitung dari pekan biasa; " +
      "pekan dengan peristiwa luar biasa (oranye) cenderung berada di kiri bawah."));
  }
  out.push(howToRead([
    "Korelasi mendekati 1 berarti kolekte naik bersama jumlah umat. Korelasi negatif pada tanggal berarti kolekte per umat turun menjelang akhir bulan.",
    "Hubungan ini dipakai untuk memahami pola dan membuat perkiraan, bukan untuk menilai umat.",
    'Jumlah "belum dihitung" dan "belum final" menunjukkan catatan yang masih menunggu proses administrasi.'
  ]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageEvents() {
  var weekly = completeWeeks(V("KOLEKTE_MINGGUAN_DAN_PERISTIWA"));
  var impact = sortBy(V("DAMPAK_PERISTIWA_LUAR_BIASA"), ["TANGGAL_MULAI"]);
  var out = [title("Peristiwa luar biasa"), banner()];
  out.push(para("Hujan deras, kabut asap, abu vulkanik, atau gangguan listrik dapat menurunkan kehadiran dan kolekte. " +
    "Peristiwa seperti ini tidak bisa diramalkan, tetapi bila dicatat, penyimpangan pada perkiraan dapat dijelaskan."));

  var yr = yearRange("rentang.peristiwa", weekly.map(function (r) { return weekYear(r.AWAL_PEKAN); }));
  out.push(columns([radio("ukuran_peristiwa", "Tampilkan", ["Jumlah umat per pekan", "Kolekte per pekan"]), yr.html]));
  var measure = val("ukuran_peristiwa", "Jumlah umat per pekan"), first = yr.first, lastYear = yr.last;
  var weeks = inYears(weekly, first, lastYear);

  if (measure === "Kolekte per pekan") {
    out.push(forecastChart(weeklyWithForecast(weeks, V("KOLEKTE_AKTUAL_VS_PERKIRAAN")), 340));
    out.push(caption("Garis biru adalah kolekte aktual dan garis putus-putus oranye adalah perkiraan kolekte yang dibuat empat pekan sebelumnya, dengan rentang 80% " +
      "sebagai pita oranye muda. Pekan berlatar abu-abu terkena peristiwa luar biasa: perkiraan belum mengetahui peristiwa itu. " +
      "Perkiraan baru ada sejak Agustus 2021. Pekan pertama dan terakhir yang belum lengkap tidak ditampilkan."));
  } else {
    var nameA = "Pekan ini", nameB = "Rata-rata 8 pekan sebelumnya", nameC = "Pekan terdampak peristiwa";
    var longRows = [], flagged = [];
    weeks.forEach(function (r) {
      var label = "Pekan " + longDate(r.AWAL_PEKAN);
      if (!missing(r.TOTAL_UMAT)) { longRows.push({t: r.AWAL_PEKAN, Seri: nameA, Nilai: Number(r.TOTAL_UMAT), Pekan: label, Teks: number(r.TOTAL_UMAT, 1)}); }
      if (!missing(r.RATA_RATA_UMAT_8_PEKAN_SEBELUMNYA)) {
        longRows.push({t: r.AWAL_PEKAN, Seri: nameB, Nilai: Number(r.RATA_RATA_UMAT_8_PEKAN_SEBELUMNYA), Pekan: label, Teks: number(r.RATA_RATA_UMAT_8_PEKAN_SEBELUMNYA, 1)});
      }
      if (typeof r.NAMA_PERISTIWA === "string") {
        flagged.push({t: r.AWAL_PEKAN, Seri: nameC, Nilai: Number(r.TOTAL_UMAT), Pekan: label, Teks: number(r.TOTAL_UMAT, 1), Peristiwa: r.NAMA_PERISTIWA});
      }
    });
    var p = palette();
    var colour = {field: "Seri", type: "nominal", scale: {domain: [nameA, nameB, nameC], range: [p[0], NEUTRAL, p[1]]}, legend: {title: null}};
    var x = {field: "t", type: "temporal", axis: {format: "%Y", title: null, tickCount: "year"}};
    var y = {field: "Nilai", type: "quantitative", axis: {title: "Umat per pekan"}, scale: {zero: true}};
    var tip = [{field: "Pekan", type: "nominal"}, {field: "Seri", type: "nominal"}, {field: "Teks", type: "nominal", title: "Nilai"}];
    var layers2 = [{data: {values: longRows}, mark: {type: "line", strokeWidth: 2, strokeJoin: "round"}, encoding: {x: x, y: y, color: colour, tooltip: tip}}];
    if (flagged.length) {
      layers2.push({data: {values: flagged}, mark: {type: "point", filled: true, size: 70, opacity: 1},
        encoding: {x: x, y: y, color: colour, tooltip: tip.concat([{field: "Peristiwa", type: "nominal"}])}});
    }
    out.push(chartBox({layer: layers2}, 340));
    out.push(caption("Titik oranye menandai pekan yang terkena peristiwa luar biasa. Garis abu-abu adalah rata-rata delapan pekan " +
      "sebelumnya, dipakai sebagai pembanding kasar. Pekan pertama dan terakhir yang belum lengkap tidak ditampilkan. " +
      'Pilih "Kolekte per pekan" untuk membandingkan kolekte aktual dengan perkiraan kolekte pada grafik yang sama.'));
  }

  out.push(sub("Seberapa besar dampaknya?"));
  var inside = impact.filter(function (r) { var y2 = yearOf(r.TANGGAL_MULAI); return y2 >= first && y2 <= lastYear; });
  if (!inside.length) { out.push(info("Tidak ada peristiwa pada rentang tahun yang dipilih.")); }
  else {
    var order = col(inside, "NAMA_PERISTIWA");
    var rowsH = inside.map(function (r) {
      return {NAMA_PERISTIWA: r.NAMA_PERISTIWA, Hadir: r.PERSEN_KEHADIRAN_TERHADAP_HARAPAN, Kolekte: r.PERSEN_KOLEKTE_TERHADAP_HARAPAN,
              TeksHadir: percent(r.PERSEN_KEHADIRAN_TERHADAP_HARAPAN, 0), TeksKolekte: percent(r.PERSEN_KOLEKTE_TERHADAP_HARAPAN, 0)};
    });
    out.push(columns([
      "<p><strong>Kehadiran terhadap rata-rata 8 pekan sebelumnya (%)</strong></p>" +
        hbarChart(rowsH, "NAMA_PERISTIWA", "Hadir", "% dari rata-rata 8 pekan", order, "TeksHadir", 100, null, 0, 125),
      "<p><strong>Kolekte terhadap rata-rata 8 pekan sebelumnya (%)</strong></p>" +
        hbarChart(rowsH, "NAMA_PERISTIWA", "Kolekte", "% dari rata-rata 8 pekan", order, "TeksKolekte", 100, null, 1, 125)
    ]));
    out.push(caption("Garis abu-abu vertikal adalah 100%, yaitu sama dengan rata-rata 8 pekan sebelumnya. Urutan mengikuti tanggal kejadian, bukan besar dampak."));
    var lost = sum(inside, function (r) { return Math.max(0, r.PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA); });
    out.push(para("Kolekte yang tidak diterima akibat " + inside.length + " peristiwa pada rentang ini, dibandingkan rata-rata 8 pekan sebelumnya: <strong>" +
      esc(juta(lost)) + "</strong>. Angka ini kasar, karena belum membedakan pengaruh hari gajian dan musim."));
    inside.filter(function (r) { return r.PERSEN_KOLEKTE_TERHADAP_HARAPAN > 100 && r.PERSEN_KEHADIRAN_TERHADAP_HARAPAN < 100; }).forEach(function (r) {
      out.push(info("<strong>" + esc(r.NAMA_PERISTIWA) + "</strong>: kehadiran " + esc(percent(r.PERSEN_KEHADIRAN_TERHADAP_HARAPAN, 0)) +
        " dari rata-rata 8 pekan sebelumnya, tetapi kolekte " + esc(percent(r.PERSEN_KOLEKTE_TERHADAP_HARAPAN, 0)) +
        ". Peristiwa jatuh pada awal bulan sesudah gajian, sehingga kolekte per umat yang lebih tinggi menutupi penurunan kehadiran. " +
        "Contoh ini menunjukkan mengapa perbandingan sederhana bisa menyesatkan."));
    });

    out.push(sub("Rincian per peristiwa"));
    out.push(select("pilih_peristiwa", "Pilih peristiwa", order));
    var chosen = val("pilih_peristiwa", order[0]);
    var row = inside.filter(function (r) { return r.NAMA_PERISTIWA === chosen; })[0];
    out.push(eventHeading(row));
    out.push(para(esc(row.DESKRIPSI)));
    out.push(tiles([
      metric("Misa terlaksana / dibatalkan", whole(row.JUMLAH_MISA_TERLAKSANA) + " / " + whole(row.JUMLAH_MISA_DIBATALKAN)),
      metric("Kehadiran terhadap rata-rata", percent(row.PERSEN_KEHADIRAN_TERHADAP_HARAPAN, 0)),
      metric("Kolekte terhadap rata-rata", percent(row.PERSEN_KOLEKTE_TERHADAP_HARAPAN, 0)),
      metric("Kolekte yang tidak diterima", juta(row.PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA))
    ]));
    out.push(caption(esc(row.CATATAN_METODE)));
  }
  out.push(caption("Bagian di bawah grafik membandingkan dengan rata-rata 8 pekan sebelumnya, pembanding kasar yang sama untuk kehadiran dan kolekte. " +
    'Untuk melihat bagaimana peristiwa-peristiwa ini membuat perkiraan kolekte yang disimpan meleset, buka halaman "Perkiraan kolekte".'));
  out.push(howToRead([
    "Catatan peristiwa menjelaskan mengapa angka pada suatu periode menyimpang dari tren. Dampaknya tidak disimpan sebagai angka, " +
      "tetapi dihitung dari perbandingan dengan delapan pekan sebelumnya.",
    "Bila perkiraan masa depan dibuat tanpa memisahkan pekan-pekan ini, penurunan sementara bisa terbaca sebagai perubahan tren."
  ]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageForecast() {
  var weeks = sortBy(V("KOLEKTE_AKTUAL_VS_PERKIRAAN"), ["AWAL_PEKAN"]);
  var events = sortBy(V("BIAS_PERKIRAAN_PER_PERISTIWA"), ["TANGGAL_MULAI"]);
  var out = [title("Perkiraan kolekte"), banner()];
  out.push(para("Perkiraan kolekte ini adalah perkiraan bayangan: dibuat <strong>empat pekan sebelum</strong> pekan yang diperkirakan, hanya dari data yang saat itu sudah ada, " +
    "lalu disimpan apa adanya. Perkiraan tidak pernah diubah setelah hasilnya diketahui, sehingga dapat dibandingkan " +
    "dengan kolekte aktual secara jujur. Perkiraan tidak mengetahui peristiwa yang belum terjadi, dan di situlah " +
    "catatan peristiwa luar biasa menjelaskan selisihnya."));

  var yr = yearRange("rentang.perkiraan", weeks.map(function (r) { return weekYear(r.AWAL_PEKAN); }));
  out.push(yr.html);
  var first = yr.first, lastYear = yr.last;
  var chosen = inYears(weeks, first, lastYear);

  var table = accuracyByKind(chosen), byKind = {};
  table.forEach(function (r) { byKind[r.kind] = r; });
  function fig(kind, column) { return byKind[kind] ? byKind[kind][column] : null; }
  out.push(tiles([
    metric("Galat pekan biasa", percent(fig(KIND_ORDINARY, "galat")), "Rata-rata selisih mutlak terhadap perkiraan pada pekan tanpa peristiwa dan tanpa hari raya."),
    metric("Pekan biasa dalam rentang", percent(fig(KIND_ORDINARY, "dalam"), 0), "Rentang perkiraan dirancang memuat sekitar 80% pekan."),
    metric("Galat pekan berperistiwa", percent(fig(KIND_EVENT, "galat")), "Rata-rata selisih mutlak pada pekan yang terkena peristiwa luar biasa."),
    metric("Berperistiwa dalam rentang", percent(fig(KIND_EVENT, "dalam"), 0), "Peristiwa membuat kolekte keluar dari rentang perkiraan.")
  ]));

  var drawn = forecastViewChoice(chosen, "jangka_grafik_perkiraan");
  out.push(drawn.html);
  out.push(forecastChart(drawn.rows));
  out.push(caption("Garis biru adalah kolekte aktual, garis putus-putus oranye adalah perkiraan kolekte yang dibuat empat pekan sebelumnya, dan pita oranye muda " +
    "adalah rentang yang diharapkan memuat 80% hasil. Pekan berlatar abu-abu terkena peristiwa luar biasa. " +
    "Garis putus-putus vertikal menandai awal pekan yang belum lengkap pada tanggal data: ke kanan hanya ada perkiraan."));
  var outside = chosen.filter(function (r) { return r.POSISI_TERHADAP_RENTANG === "Di bawah rentang" || r.POSISI_TERHADAP_RENTANG === "Di atas rentang"; });
  if (outside.length) {
    var unexplained = outside.filter(function (r) { return r.PENJELASAN_SELISIH === "Di luar rentang, tanpa peristiwa tercatat"; }).length;
    out.push(caption(unexplained + " dari " + outside.length + " pekan di luar rentang tidak memiliki peristiwa tercatat. Itu wajar: rentang 80% memang " +
      "diperkirakan meleset pada sekitar satu dari lima pekan biasa."));
  }

  out.push(sub("Mengapa perkiraan meleset?"));
  var insideEvents = events.filter(function (r) { var y = yearOf(r.TANGGAL_MULAI); return y >= first && y <= lastYear; });
  if (!insideEvents.length) { out.push(info("Tidak ada peristiwa yang dapat dibandingkan pada rentang tahun yang dipilih.")); }
  else {
    var typicals = insideEvents.map(function (r) { return r.GALAT_PEKAN_BIASA_PERSEN; }).filter(function (v) { return !missing(v); });
    var typical = typicals.length ? typicals[0] : null;
    out.push(eventGapChart(insideEvents, typical));
    out.push(caption("Setiap batang menunjukkan selisih total kolekte pada pekan-pekan peristiwa terhadap perkiraannya. Pita abu-abu adalah galat biasa " +
      "pada pekan tanpa peristiwa sepanjang seluruh riwayat (sekitar plus minus " + esc(percent(typical)) + "). Batang yang jauh keluar dari pita tidak bisa dijelaskan " +
      "oleh kebiasaan perkiraan, tetapi oleh peristiwa itu sendiri. Urutan mengikuti tanggal kejadian, bukan besar selisih."));

    var names = col(insideEvents, "NAMA_PERISTIWA");
    out.push(select("pilih_peristiwa_perkiraan", "Pilih peristiwa untuk dilihat dari dekat", names, names[names.length - 1]));
    var pick = val("pilih_peristiwa_perkiraan", names[names.length - 1]);
    var row = insideEvents.filter(function (r) { return r.NAMA_PERISTIWA === pick; })[0];
    out.push(eventHeading(row));
    out.push(para(esc(row.DESKRIPSI)));
    out.push(tiles([
      metric("Pekan terdampak", whole(row.JUMLAH_PEKAN_TERDAMPAK), whole(row.JUMLAH_PEKAN_DI_LUAR_RENTANG) + " dari pekan ini berada di luar rentang perkiraan."),
      metric("Perkiraan kolekte", juta(row.PERKIRAAN_TOTAL)),
      metric("Kolekte aktual", juta(row.KOLEKTE_AKTUAL_TOTAL)),
      metric("Selisih", signedPercent(row.SELISIH_PERSEN), "Kolekte aktual dikurangi perkiraan, dibagi perkiraan.")
    ]));
    var multiple = row.KELIPATAN_GALAT_BIASA;
    if (!missing(multiple) && multiple < 1) {
      out.push(info("Selisihnya masih dalam batas galat biasa: peristiwa ini nyaris tidak terlihat pada kolekte. " +
        "Perkiraan sudah memperhitungkan kenaikan kolekte setelah hari gajian, dan peristiwa jatuh pada awal bulan."));
    } else if (!missing(multiple)) {
      out.push(para("Selisih ini sekitar <strong>" + number(multiple, 1) + " kali</strong> galat biasa pada pekan tanpa peristiwa (sepanjang seluruh riwayat). " +
        "Perkiraan dibuat sebelum peristiwa terjadi dan tidak dapat mengetahuinya."));
    }
    var close = weeks.filter(function (r) { return r.AWAL_PEKAN >= addDays(row.PEKAN_PERTAMA, -42) && r.AWAL_PEKAN <= addDays(row.PEKAN_TERAKHIR, 42); });
    out.push(forecastChart(close, 300, true));
  }

  out.push(sub("Seberapa tepat perkiraan ini?"));
  if (table.length) {
    var order = col(table, "kind");
    var rows = table.map(function (r) { return {Jenis: r.kind, Galat: r.galat, Dalam: r.dalam, TeksGalat: percent(r.galat), TeksRentang: percent(r.dalam, 0)}; });
    out.push(columns([
      "<p><strong>Galat rata-rata (%)</strong></p>" + hbarChart(rows, "Jenis", "Galat", "Galat rata-rata (%)", order, "TeksGalat", null, 190, 0, null),
      "<p><strong>Pekan yang jatuh dalam rentang (%)</strong></p>" + hbarChart(rows, "Jenis", "Dalam", "% pekan dalam rentang", order, "TeksRentang", 80, 190, 1, 110)
    ]));
    out.push(caption("Garis abu-abu pada grafik kanan adalah 80%, yaitu ketepatan rentang yang dirancang. Perkiraan tepat pada pekan biasa dan pekan hari raya, " +
      "dan meleset terutama bila ada peristiwa luar biasa."));
  }

  out.push(sub("Perkiraan untuk pekan-pekan ke depan"));
  var ahead = weeks.filter(function (r) { return r.STATUS_PEKAN !== "Lengkap"; });
  if (!ahead.length) { out.push(para("Belum ada perkiraan untuk pekan yang akan datang.")); }
  else {
    out.push('<ul class="agenda">' + ahead.map(function (r) {
      return '<li><span class="when">Pekan ' + esc(longDate(r.AWAL_PEKAN)) + "</span> <strong>" + esc(rupiah(r.JUMLAH_PERKIRAAN)) + '</strong> <span class="muted">rentang ' +
        esc(juta(r.BATAS_BAWAH)) + " sampai " + esc(juta(r.BATAS_ATAS)) + (typeof r.CATATAN_KALENDER === "string" ? " | " + esc(r.CATATAN_KALENDER) : "") + "</span></li>";
    }).join("") + "</ul>");
    out.push(caption("Perkiraan ini belum mengetahui peristiwa yang mungkin terjadi. Bila ada, selisihnya akan terlihat pada grafik di atas."));
  }
  out.push(howToRead([
    "Selisih adalah kolekte aktual dikurangi perkiraan. Selisih negatif berarti kolekte lebih rendah dari perkiraan.",
    "Perkiraan memakai garis tren dari 52 pekan terakhir yang tidak terganggu, kenaikan setelah hari gajian, dan kalender liturgi (hari raya dan kolekte khusus). " +
      "Pekan yang sudah tercatat terganggu peristiwa tidak dipakai untuk belajar, agar bencana yang lalu tidak menurunkan perkiraan berikutnya.",
    "Angka kolekte adalah ringkasan administrasi keuangan. Angka ini bukan ukuran iman atau komitmen rohani dan tidak dipakai untuk menilai siapa pun.",
    "Tahun 2021 hanya memuat pekan sejak Agustus karena model memerlukan sekitar setengah tahun riwayat sebelum mulai membuat perkiraan."
  ]));
  return out.join("");
}
