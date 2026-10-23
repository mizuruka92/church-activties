"use strict";
/* Pages: Ringkasan, Kegiatan mendatang, Pemasukan dan pengeluaran. Ports of the Streamlit pages (tables left out). */

var HORIZONS = {"30 hari ke depan": 30, "60 hari ke depan": 60, "Semua yang akan datang": null};
var PREPARATION_DAYS = 45;
var STAGE_LABELS = {};
STAGE_LABELS[STAGE_SCHEDULED] = "Sudah dijadwalkan";
STAGE_LABELS[STAGE_PLAN] = "Masih rencana tahunan";
STAGE_LABELS[STAGE_POSTPONED] = "Ditunda";

function splitUpcoming(rows) {
  var postponed = sortBy(rows.filter(function (r) { return r.TAHAP === STAGE_POSTPONED; }), ["TANGGAL_MULAI"]);
  var coming = sortBy(rows.filter(function (r) { return r.TAHAP !== STAGE_POSTPONED; }), ["TANGGAL_MULAI", "NAMA_PROGRAM"]);
  return {coming: coming, postponed: postponed};
}
function lastCompleteYear(annual) {
  return maxOf(annual.filter(function (r) { return r.TAHUN_LENGKAP; }).map(function (r) { return r.TAHUN; }));
}
function sentenceCase(s) { return String(s).replace(/\.+$/, ""); }

// A compact, readable list in place of the tables of the Streamlit pages
function agendaList(rows) {
  var items = rows.map(function (r) {
    return '<li><span class="when">' + esc(longDate(r.TANGGAL_MULAI)) + " <em>(" + esc(daysAway(r.HARI_DARI_TANGGAL_DATA)) + ")</em></span> " +
      "<strong>" + esc(r.NAMA_PROGRAM) + "</strong> <span class=\"muted\">" + esc(r.NAMA_SEKSI) + " | " + esc(STAGE_LABELS[r.TAHAP] || r.TAHAP) +
      " | " + esc(juta(r.ANGGARAN_RENCANA)) + (typeof r.LOKASI === "string" ? " | " + esc(r.LOKASI) : "") + "</span></li>";
  });
  return '<ul class="agenda">' + items.join("") + "</ul>";
}

// ------------------------------------------------------------------------------------------------
function pageSummary() {
  var annual = sortBy(V("PEMASUKAN_PENGELUARAN_TAHUNAN"), ["TAHUN"]);
  var projection = sortBy(V("PROYEKSI_PEMASUKAN_PENGELUARAN"), ["TAHUN"]);
  var attendance = V("KEHADIRAN_MISA_BULANAN"), campaigns = V("TITIK_IMPAS_KAMPANYE");
  var impact = V("DAMPAK_PERISTIWA_LUAR_BIASA"), reports = V("KELENGKAPAN_LAPORAN_PER_SEKSI");
  var split = splitUpcoming(V("KEGIATAN_MENDATANG")), coming = split.coming, postponed = split.postponed;

  var year = lastCompleteYear(annual);
  var now = annual.filter(function (r) { return r.TAHUN === year; })[0];
  var previous = annual.filter(function (r) { return r.TAHUN === year - 1; })[0];
  var yearly = attendance.filter(function (r) { return r.TAHUN === year; });
  var perMass = sum(yearly, "TOTAL_UMAT") / Math.max(1, sum(yearly, "JUMLAH_MISA_TERLAKSANA"));

  var out = [title("Ringkasan"), banner(), sub("Keadaan tahun " + year + " (tahun lengkap terakhir)")];
  var ratioDelta = null;
  if (previous) {
    var diff = now.PERSEN_PENGELUARAN_TERHADAP_KOLEKTE - previous.PERSEN_PENGELUARAN_TERHADAP_KOLEKTE;
    ratioDelta = (now.PERSEN_PENGELUARAN_TERHADAP_KOLEKTE >= previous.PERSEN_PENGELUARAN_TERHADAP_KOLEKTE ? "+" : "") + number(diff, 1) + " poin dari " + (year - 1);
  }
  out.push(tiles([
    metric("Kolekte", juta(now.PEMASUKAN_KOLEKTE), null, signedPercent(now.PERTUMBUHAN_KOLEKTE_PERSEN) + " dari " + (year - 1)),
    metric("Pengeluaran program", juta(now.PENGELUARAN_PROGRAM), null, signedPercent(now.PERTUMBUHAN_PENGELUARAN_PERSEN) + " dari " + (year - 1)),
    metric("Pengeluaran terhadap kolekte", percent(now.PERSEN_PENGELUARAN_TERHADAP_KOLEKTE), null, ratioDelta),
    metric("Rata-rata umat per Misa", number(perMass, 0))
  ]));

  var crossing = projection.map(function (r) { return r.TAHUN_PERTAMA_PENGELUARAN_MELEBIHI_KOLEKTE; }).filter(function (v) { return !missing(v); });
  var finished = sortBy(campaigns.filter(function (r) { return r.STATUS_KAMPANYE === "Selesai"; }), ["TAHUN"]);
  var second = [metric("Pengeluaran melampaui kolekte", crossing.length ? String(Math.trunc(crossing[0])) : "Belum dalam jangkauan",
    "Tahun pertama ketika garis tren pengeluaran program berada di atas garis tren kolekte. Penyederhanaan, bukan ramalan.")];
  [["Puasa", "Biaya Paskah tertutup"], ["Adven", "Biaya Natal tertutup"]].forEach(function (pair) {
    var mine = finished.filter(function (r) { return String(r.NAMA_KESEMPATAN).indexOf(pair[0]) >= 0; });
    if (!mine.length) { second.push(metric(pair[1], "-")); return; }
    var latest = last(mine);
    second.push(metric(pair[1], percent(latest.PERSEN_BIAYA_TERTUTUP_SUMBANGAN, 0),
      "Sumbangan terkumpul dibandingkan biaya perayaan, tahun " + Math.trunc(latest.TAHUN) + "."));
  });
  var lostTotal = sum(impact, function (r) { return Math.max(0, r.PERKIRAAN_KOLEKTE_YANG_TIDAK_DITERIMA); });
  second.push(metric("Peristiwa luar biasa", whole(impact.length), "Perkiraan kolekte yang tidak diterima akibat peristiwa: " + juta(lostTotal)));
  out.push(tiles(second));

  out.push(sub("Kolekte dan pengeluaran program, dengan garis tren"));
  out.push(incomeOutcomeChart(annual, projection));
  var partial = annual.filter(function (r) { return !r.TAHUN_LENGKAP; });
  if (partial.length) {
    out.push(caption("Tahun " + Math.trunc(partial[0].TAHUN) + " baru berjalan sebagian (" + esc(lower(partial[0].STATUS_TAHUN)) +
      "), sehingga tidak digambarkan sebagai titik aktual."));
  }
  out.push(caption(esc(projection[0].CATATAN_METODE)));

  out.push(sub("Kegiatan terdekat"));
  if (!coming.length) { out.push(para("Tidak ada kegiatan yang akan datang.")); }
  else { out.push(agendaList(coming.slice(0, 3))); out.push(caption("Selengkapnya ada pada halaman Kegiatan mendatang.")); }

  out.push(sub("Perlu perhatian"));
  var notes = [];
  if (postponed.length) { notes.push("**" + postponed.length + "** kegiatan ditunda tahun ini dan belum memiliki jadwal baru."); }
  if (crossing.length) {
    notes.push("Jika pola lima tahun terakhir berlanjut, pengeluaran program diperkirakan melampaui kolekte pada tahun **" + Math.trunc(crossing[0]) +
      "**. Ini gambaran tren, bukan ramalan pasti.");
  }
  var deficits = finished.filter(function (r) { return !missing(r.DANA_TAMBAHAN_DARI_GEREJA) && r.DANA_TAMBAHAN_DARI_GEREJA > 0; });
  if (deficits.length) {
    notes.push("Sumbangan khusus belum menutup biaya kegiatan yang didanai pada: " + deficits.slice(-3).map(function (r) { return r.NAMA_KAMPANYE; }).join(", ") +
      ". Selisihnya ditutup dari dana gereja.");
  }
  var openReports = sum(reports, "JUMLAH_BELUM_ADA_LAPORAN") + sum(reports, "JUMLAH_LAPORAN_DRAF_ATAU_REVISI");
  if (openReports) { notes.push("Ada **" + openReports + "** kegiatan terlaksana yang laporannya belum final atau belum dibuat."); }
  out.push(notes.length ? bullets(notes.map(md)) : para("Tidak ada hal khusus."));

  out.push(howToRead([
    "**Kolekte** adalah ringkasan penerimaan dari Misa. **Pengeluaran program** adalah biaya yang tercatat pada rencana kerja tahunan seksi.",
    "Biaya operasional rutin (listrik, gaji, pemeliharaan) tidak ada dalam data demo ini.",
    "Garis putus-putus adalah garis lurus yang ditarik dari tahun-tahun lengkap. Ini penyederhanaan untuk demonstrasi.",
    "Angka kolekte menggambarkan administrasi keuangan, bukan tingkat iman atau komitmen umat."
  ]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageUpcoming() {
  var data = V("KEGIATAN_MENDATANG"), masses = V("PELAKSANAAN_MISA");
  var out = [title("Kegiatan mendatang"), banner()];
  var t = tabs("tab.mendatang", ["Kegiatan dan rencana", "Jadwal Misa"]);
  out.push(t.html);

  if (t.active === "Kegiatan dan rencana") {
    if (!data.length) { out.push(info("Tidak ada kegiatan yang akan datang atau ditunda.")); return out.join(""); }
    var dataDate = maxOf(col(data, "TANGGAL_DATA"));
    out.push(para('Data per <strong>' + esc(longDate(dataDate)) + '</strong>. "Mendatang" dihitung dari tanggal data ini, bukan dari tanggal hari ini, ' +
      "supaya contoh tetap sama kapan pun dibuka."));
    var split = splitUpcoming(data), coming = split.coming, postponed = split.postponed;
    var horizons = Object.keys(HORIZONS);
    var sections = ["Semua seksi"].concat(uniq(col(data, "NAMA_SEKSI")).sort());
    out.push(columns([radio("jangka_waktu", "Jangka waktu", horizons, horizons[horizons.length - 1]),
                      select("seksi_mendatang", "Seksi", sections)]));
    var horizon = HORIZONS[val("jangka_waktu", horizons[horizons.length - 1])];
    var section = val("seksi_mendatang", "Semua seksi");
    var shown = coming;
    if (horizon !== null) { shown = shown.filter(function (r) { return r.HARI_DARI_TANGGAL_DATA <= horizon; }); }
    if (section !== "Semua seksi") { shown = shown.filter(function (r) { return r.NAMA_SEKSI === section; }); }

    out.push(tiles([
      metric("Kegiatan mendatang", whole(shown.length)),
      metric("Sudah dijadwalkan", whole(shown.filter(function (r) { return r.TAHAP === STAGE_SCHEDULED; }).length),
        "Sudah terdaftar sebagai kegiatan dengan tanggal, tempat, dan target peserta."),
      metric("Masih rencana tahunan", whole(shown.filter(function (r) { return r.TAHAP === STAGE_PLAN; }).length),
        "Ada pada rencana kerja dan anggaran, tetapi belum punya tempat dan target peserta."),
      metric("Anggaran rencana", juta(sum(shown, "ANGGARAN_RENCANA")))
    ]));

    out.push(sub("Agenda"));
    if (!shown.length) { out.push(info("Tidak ada kegiatan pada pilihan ini.")); }
    else {
      groupBy(shown, function (r) { return MONTHS[monthOf(r.TANGGAL_MULAI)] + " " + yearOf(r.TANGGAL_MULAI); }).forEach(function (g) {
        out.push("<p><strong>" + esc(g[0]) + "</strong></p>" + agendaList(g[1]));
      });
      out.push(sub("Peta waktu"));
      out.push(upcomingTimelineChart(shown));
      out.push(caption("Setiap titik adalah satu kegiatan. Biru sudah dijadwalkan, oranye masih berupa rencana tahunan."));
    }

    out.push(sub("Perlu perhatian"));
    var attention = false;
    if (postponed.length) {
      attention = true;
      out.push(warn("<strong>" + postponed.length + " kegiatan ditunda</strong> tahun ini dan belum memiliki jadwal baru:" + bullets(postponed.map(function (r) {
        return "<strong>" + esc(r.NAMA_PROGRAM) + "</strong> (" + esc(r.NAMA_SEKSI) + "), semula " + esc(longDate(r.TANGGAL_MULAI)) + ". " +
          esc(sentenceCase(text(r.CATATAN_KEGIATAN))) + ".";
      }))));
    }
    coming.filter(function (r) { return !missing(r.DIDANAI_KAMPANYE); }).forEach(function (r) {
      attention = true;
      var gap = r.SELISIH_TARGET_DANA_VS_ANGGARAN;
      var result = gap < 0 ? "masih kurang " + juta(-gap) + " dan harus ditutup dari dana gereja" : "cukup, dengan kelebihan " + juta(gap);
      out.push(warn("<strong>" + esc(r.NAMA_PROGRAM) + "</strong> (" + esc(longDate(r.TANGGAL_MULAI)) + ", " + esc(daysAway(r.HARI_DARI_TANGGAL_DATA)) + ") dianggarkan " +
        esc(juta(r.ANGGARAN_RENCANA)) + ". Kampanye " + esc(r.DIDANAI_KAMPANYE) + " menargetkan " + esc(juta(r.TARGET_DANA_KAMPANYE)) +
        ". Bila target tercapai, dana " + esc(result) + "."));
    });
    var near = coming.filter(function (r) { return r.TAHAP === STAGE_PLAN && r.HARI_DARI_TANGGAL_DATA <= PREPARATION_DAYS; });
    if (near.length) {
      attention = true;
      out.push(warn("<strong>" + near.length + " kegiatan</strong> kurang dari " + PREPARATION_DAYS + " hari lagi tetapi masih berupa rencana tahunan " +
        "(belum punya tempat dan target peserta): " + near.map(function (r) { return esc(r.NAMA_PROGRAM) + " (" + esc(longDate(r.TANGGAL_MULAI)) + ")"; }).join("; ") + "."));
    }
    if (!attention) { out.push(para("Tidak ada hal khusus.")); }

    out.push(howToRead([
      "**Masih rencana tahunan**: kegiatan ada pada rencana kerja dan anggaran seksi, tetapi belum didaftarkan dengan tempat dan target peserta.",
      "**Sudah dijadwalkan**: sudah terdaftar sebagai kegiatan dengan tanggal, tempat, dan target peserta.",
      "**Ditunda**: pernah dijadwalkan, lalu diundur dan belum memiliki tanggal baru. Catatan menjelaskan alasannya.",
      "Setelah terlaksana, kegiatan muncul pada halaman Rencana, anggaran, kegiatan lengkap dengan laporan pascakegiatan.",
      "Dana pendukung berasal dari kampanye sumbangan yang ditujukan untuk kegiatan itu (misalnya Adven untuk Natal)."
    ]));
  } else {
    var planned = sortBy(masses.filter(function (r) { return r.STATUS_PELAKSANAAN === "Terjadwal"; }), ["TANGGAL_MISA", "WAKTU_MULAI_JADWAL"]);
    if (!planned.length) { out.push(info("Tidak ada Misa terjadwal pada data ini.")); return out.join(""); }
    out.push(tiles([metric("Misa terjadwal", whole(planned.length)), metric("Mulai", longDate(minOf(col(planned, "TANGGAL_MISA")))),
                    metric("Sampai", longDate(maxOf(col(planned, "TANGGAL_MISA"))))]));
    var names = ["Semua sesi"].concat(uniq(col(planned, "NAMA_MISA")).sort());
    out.push(select("sesi_mendatang", "Sesi Misa", names));
    var choice = val("sesi_mendatang", "Semua sesi");
    if (choice !== "Semua sesi") { planned = planned.filter(function (r) { return r.NAMA_MISA === choice; }); }
    out.push('<ul class="agenda">' + planned.map(function (r) {
      return '<li><span class="when">' + esc(longDate(r.TANGGAL_MISA)) + " <em>(" + esc(text(r.HARI)) + ", " + esc(text(r.WAKTU_MULAI_JADWAL)) + ")</em></span> <strong>" +
        esc(r.NAMA_MISA) + '</strong> <span class="muted">' + esc(text(r.LOKASI)) + " | " + esc(text(r.BAHASA_MISA)) + "</span></li>";
    }).join("") + "</ul>");
    out.push(caption("Jam yang ditampilkan adalah jam yang dijadwalkan. Jam sebenarnya baru tercatat setelah Misa berlangsung."));
  }
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageIncomeOutcome() {
  var annual = sortBy(V("PEMASUKAN_PENGELUARAN_TAHUNAN"), ["TAHUN"]);
  var projection = sortBy(V("PROYEKSI_PEMASUKAN_PENGELUARAN"), ["TAHUN"]);
  var monthly = sortBy(V("PEMASUKAN_PENGELUARAN_BULANAN"), ["TAHUN", "BULAN"]);
  var out = [title("Pemasukan dan pengeluaran"), banner()];
  var t = tabs("tab.pemasukan", ["Per tahun dan proyeksi", "Per bulan"]);
  out.push(t.html);

  if (t.active === "Per tahun dan proyeksi") {
    out.push(sub("Apakah kolekte masih lebih besar dari pengeluaran?"));
    out.push(incomeOutcomeChart(annual, projection));
    out.push(caption(esc(projection[0].CATATAN_METODE)));
    out.push(sub("Pertumbuhan melambat, pengeluaran terus naik"));
    var growth = annual.filter(function (r) { return r.TAHUN_LENGKAP && !missing(r.PERTUMBUHAN_PENGELUARAN_PERSEN); }).map(function (r) {
      return {TAHUN: r.TAHUN, "Kolekte per Misa (tanpa peristiwa)": r.PERTUMBUHAN_KOLEKTE_PER_MISA_TANPA_PERISTIWA_PERSEN,
              "Pengeluaran program": r.PERTUMBUHAN_PENGELUARAN_PERSEN, "Kolekte (angka mentah)": r.PERTUMBUHAN_KOLEKTE_PERSEN};
    });
    if (growth.length) {
      out.push(lineChart(growth, "TAHUN", ["Kolekte per Misa (tanpa peristiwa)", "Pengeluaran program", "Kolekte (angka mentah)"],
        "Pertumbuhan dari tahun sebelumnya (%)", 300, false));
      out.push(caption('Kolekte mentah naik turun karena peristiwa luar biasa. Garis "tanpa peristiwa" menghitung kolekte per Misa tanpa pekan yang terkena ' +
        "peristiwa, sehingga menunjukkan kecenderungan dasarnya."));
    }
    out.push(caption("Sumbangan khusus tidak digabung dengan kolekte pada proyeksi ini karena dikumpulkan untuk perayaan tertentu, " +
      "lihat halaman Sumbangan khusus."));
  } else {
    var yr = yearRange("rentang.bulanan", col(monthly, "TAHUN"));
    out.push(yr.html);
    var shown = monthly.filter(function (r) { return r.TAHUN >= yr.first && r.TAHUN <= yr.last; }).map(function (r) {
      return {Bulan: monthStart(r.TAHUN, r.BULAN), Kolekte: Number(r.PEMASUKAN_KOLEKTE) / 1e6, "Pengeluaran program": Number(r.PENGELUARAN_PROGRAM) / 1e6,
              NAMA_PERIODE: r.NAMA_PERIODE, NAMA_PERISTIWA: r.NAMA_PERISTIWA};
    });
    out.push(sub("Kolekte dan pengeluaran program per bulan"));
    out.push(lineChart(shown, "Bulan", ["Kolekte", "Pengeluaran program"], "Juta rupiah", 320, true));
    var events = shown.filter(function (r) { return !missing(r.NAMA_PERISTIWA); });
    if (events.length) {
      out.push(caption("Bulan dengan peristiwa luar biasa: " + esc(events.map(function (r) { return r.NAMA_PERIODE; }).join(", ")) +
        ". Rinciannya ada pada halaman Peristiwa luar biasa."));
    }
    out.push(caption("Pengeluaran program tidak merata sepanjang tahun karena mengikuti jadwal kegiatan."));
  }
  out.push(howToRead([
    "Kolekte per bulan sangat dipengaruhi jumlah umat yang hadir dan tanggal dalam bulan (lihat halaman Kolekte dan kehadiran).",
    "Pengeluaran program dicatat pada tanggal pengeluarannya, sehingga bulan dengan banyak kegiatan terlihat tinggi."
  ]));
  return out.join("");
}
