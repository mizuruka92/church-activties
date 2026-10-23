"use strict";
/* Pages: Sumbangan khusus, Rencana anggaran kegiatan, Survei umat, Layanan dan prosedur, Tentang data. */

function fundedCelebration(occasion) {
  var pairs = [["Puasa", "Paskah"], ["Prapaskah", "Paskah"], ["Adven", "Natal"]];
  for (var i = 0; i < pairs.length; i++) { if (String(occasion).indexOf(pairs[i][0]) >= 0) { return pairs[i][1]; } }
  return "";
}
function finishedCampaigns(rows) {
  return rows.filter(function (r) { return r.STATUS_KAMPANYE === "Selesai" && !missing(r.BIAYA_AKTUAL) && !missing(r.TOTAL_SUMBANGAN); });
}

// ------------------------------------------------------------------------------------------------
function pageDonations() {
  var breakeven = sortBy(V("TITIK_IMPAS_KAMPANYE"), ["NAMA_KESEMPATAN", "TAHUN"]);
  var communities = V("SUMBANGAN_KELUARGA_PER_LINGKUNGAN"), regions = V("SUMBANGAN_KHUSUS_PER_WILAYAH");
  var out = [title("Sumbangan khusus"), banner()];
  out.push(info("Angka pada halaman ini menggambarkan kapasitas ekonomi dan sebaran sumbangan. Angka ini <strong>bukan</strong> ukuran iman atau " +
    "kemurahan hati, dan tidak boleh dipakai untuk memeringkat wilayah atau lingkungan. Urutan tampilan sengaja mengikuti abjad."));
  var t = tabs("tab.sumbangan", ["Titik impas perayaan", "Sebaran per lingkungan", "Per wilayah"]);
  out.push(t.html);

  if (t.active === "Titik impas perayaan") {
    out.push(sub("Apakah sumbangan menutup biaya perayaan?"));
    out.push(para("Sumbangan masa Prapaskah dan Adven dikumpulkan untuk perayaan Paskah dan Natal. Jika sumbangan lebih besar dari biaya, " +
      "kelebihannya menjadi pemasukan gereja. Jika lebih kecil, gereja menambah dana."));
    var finished = finishedCampaigns(breakeven);
    var occasions = groupBy(finished, function (r) { return r.NAMA_KESEMPATAN; }).filter(function (g) { return g[1].length >= 3; });
    if (occasions.length) {
      out.push(columns(occasions.map(function (g) {
        var celebration = fundedCelebration(g[0]);
        var rows = sortBy(g[1], ["TAHUN"]).map(function (r) {
          return {TAHUN: r.TAHUN, "Sumbangan terkumpul": Number(r.TOTAL_SUMBANGAN) / 1e6, "Biaya perayaan": Number(r.BIAYA_AKTUAL) / 1e6};
        });
        return "<p><strong>" + esc(g[0]) + "</strong>" + (celebration ? " (untuk perayaan " + esc(celebration) + ")" : "") + "</p>" +
          lineChart(rows, "TAHUN", ["Sumbangan terkumpul", "Biaya perayaan"], "Juta rupiah", 280, false);
      })));
    }
    var surplus = finished.filter(function (r) { return r.SELISIH_SUMBANGAN_VS_BIAYA_AKTUAL >= 0; }).length;
    if (finished.length) {
      out.push(caption("Dari " + finished.length + " kampanye yang sudah selesai, " + surplus + " menutup biaya perayaan dan " + (finished.length - surplus) +
        " masih memerlukan tambahan dari dana gereja."));
    }
    breakeven.filter(function (r) { return !missing(r.PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI); }).forEach(function (r) {
      var gap = r.PROYEKSI_SELISIH_JIKA_TARGET_TERCAPAI;
      out.push(warn("<strong>" + esc(r.NAMA_KAMPANYE) + "</strong> masih direncanakan. Bila target " + esc(juta(r.TARGET_DANA)) + " tercapai, dana " +
        (gap < 0 ? "masih kurang" : "berlebih") + " <strong>" + esc(juta(Math.abs(gap))) + "</strong> terhadap anggaran perayaan " + esc(juta(r.ANGGARAN_RENCANA)) + "."));
    });
  } else if (t.active === "Sebaran per lingkungan") {
    var seen = {}, campaigns = [];
    communities.forEach(function (r) {
      if (!seen[r.ID_KAMPANYE]) { seen[r.ID_KAMPANYE] = 1; campaigns.push({id: r.ID_KAMPANYE, nama: r.NAMA_KAMPANYE, tahun: r.TAHUN}); }
    });
    campaigns = sortBy(campaigns, ["tahun", "nama"], [true, false]);
    if (!campaigns.length) { out.push(info("Belum ada data sumbangan keluarga.")); return out.join(""); }
    var labels = col(campaigns, "nama");
    var puasa = labels.filter(function (n) { return n.indexOf("Puasa") >= 0; });
    out.push(select("kampanye_lingkungan", "Kampanye", labels, puasa.length ? puasa[0] : labels[0]));
    var chosen = val("kampanye_lingkungan", labels[0]);
    var data = sortBy(communities.filter(function (r) { return r.NAMA_KAMPANYE === chosen && r.JUMLAH_KELUARGA_PENYUMBANG > 0; }), ["NAMA_WILAYAH", "NAMA_LINGKUNGAN"]);
    var order = col(data, "NAMA_LINGKUNGAN");

    out.push(sub("Rata-rata dan median sumbangan per keluarga"));
    out.push(para("Jika satu keluarga memberi jauh lebih besar dari yang lain, rata-rata terangkat sedangkan median tetap menunjukkan " +
      "sumbangan keluarga pada umumnya. Jarak antara kedua titik menunjukkan besarnya perbedaan itu."));
    var points = [], span = [];
    data.forEach(function (r) {
      var med = Number(r.MEDIAN_PER_KELUARGA_PENYUMBANG) / 1e3, avg = Number(r.RATA_RATA_PER_KELUARGA_PENYUMBANG) / 1e3;
      points.push({Lingkungan: r.NAMA_LINGKUNGAN, Ukuran: "Median", Ribu: med, Teks: "Rp " + number(med, 1) + " ribu"});
      points.push({Lingkungan: r.NAMA_LINGKUNGAN, Ukuran: "Rata-rata", Ribu: avg, Teks: "Rp " + number(avg, 1) + " ribu"});
      span.push({Lingkungan: r.NAMA_LINGKUNGAN, Median: med, "Rata-rata": avg});
    });
    var yAxis = {field: "Lingkungan", type: "nominal", sort: order, axis: {title: null, labelLimit: 240}};
    out.push(chartBox({layer: [
      {data: {values: span}, mark: {type: "rule", color: NEUTRAL, strokeWidth: 2},
        encoding: {y: yAxis, x: {field: "Median", type: "quantitative", axis: {title: "Ribu rupiah per keluarga penyumbang"}, scale: {zero: true}}, x2: {field: "Rata-rata"}}},
      {data: {values: points}, mark: {type: "point", filled: true, size: 90, opacity: 1},
        encoding: {y: yAxis, x: {field: "Ribu", type: "quantitative"},
          color: {field: "Ukuran", type: "nominal", scale: colorScale(["Median", "Rata-rata"]), legend: {title: null}},
          tooltip: [{field: "Lingkungan", type: "nominal"}, {field: "Ukuran", type: "nominal"}, {field: "Teks", type: "nominal", title: "Nilai"}]}}
    ]}, Math.max(260, 28 * data.length + 60)));

    out.push(sub("Total dan sumbangan per umat terdaftar"));
    out.push(para("Total dipengaruhi jumlah umat di lingkungan. Sumbangan per umat terdaftar membagi dengan seluruh umat, " +
      "sehingga dua ukuran ini bisa menceritakan hal yang berbeda."));
    var total = data.map(function (r) { var v = Number(r.TOTAL_SUMBANGAN) / 1e6; return {Lingkungan: r.NAMA_LINGKUNGAN, Juta: v, Teks: "Rp " + number(v, 2) + " jt"}; });
    var perPerson = data.map(function (r) { var v = Number(r.SUMBANGAN_PER_UMAT_TERDAFTAR) / 1e3; return {Lingkungan: r.NAMA_LINGKUNGAN, Ribu: v, Teks: "Rp " + number(v, 1) + " ribu"}; });
    out.push(columns([
      "<p><strong>Total sumbangan (juta rupiah)</strong></p>" + hbarChart(total, "Lingkungan", "Juta", "Juta rupiah", order, "Teks", null, null, 0, null),
      "<p><strong>Sumbangan per umat terdaftar (ribu rupiah)</strong></p>" + hbarChart(perPerson, "Lingkungan", "Ribu", "Ribu rupiah", order, "Teks", null, null, 1, null)
    ]));
    var few = data.filter(function (r) { return r.JUMLAH_KELUARGA_PENYUMBANG < 5; });
    if (few.length) {
      out.push(caption("Penyumbang sedikit, angka mudah berubah: " + esc(few.map(function (r) { return r.NAMA_LINGKUNGAN; }).join(", ")) + "."));
    }
    if (data.length) { out.push(caption(esc(data[0].CATATAN_PENGGUNAAN))); }
  } else {
    var names = uniq(col(sortBy(regions, ["PERIODE_MULAI"], [true]), "NAMA_KAMPANYE"));
    out.push(select("kampanye_wilayah", "Kampanye", names));
    var pickedName = val("kampanye_wilayah", names[0]);
    var rdata = sortBy(regions.filter(function (r) { return r.NAMA_KAMPANYE === pickedName; }), ["NAMA_WILAYAH"]).map(function (r) {
      var v = Number(r.JUMLAH_SUMBANGAN) / 1e6;
      return {Wilayah: r.NAMA_WILAYAH, Juta: v, Teks: "Rp " + number(v, 2) + " jt", status: r.STATUS_VALIDASI};
    });
    out.push(sub("Sumbangan terkumpul per wilayah"));
    out.push(hbarChart(rdata, "Wilayah", "Juta", "Juta rupiah", col(rdata, "Wilayah"), "Teks", null, null, 0, null));
    var notYet = rdata.filter(function (r) { return r.status !== "Sudah Divalidasi"; });
    if (notYet.length) {
      out.push(caption("Belum divalidasi: " + esc(notYet.map(function (r) { return r.Wilayah + " (" + r.status + ")"; }).join(", "))));
    }
    var any = regions.filter(function (r) { return r.NAMA_KAMPANYE === pickedName; })[0];
    if (any) { out.push(caption(esc(any.CATATAN_PENGGUNAAN))); }
  }
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pagePlans() {
  var bySection = V("ANGGARAN_VS_REALISASI_SEKSI"), events = V("KEGIATAN_DAN_LAPORAN"), completeness = V("KELENGKAPAN_LAPORAN_PER_SEKSI");
  var out = [title("Rencana, anggaran, dan kegiatan"), banner()];
  var t = tabs("tab.rencana", ["Anggaran dan realisasi", "Kegiatan dan laporan"]);
  out.push(t.html);

  if (t.active === "Anggaran dan realisasi") {
    var years = uniq(col(bySection, "TAHUN_RENCANA").map(Number)).sort(function (a, b) { return a - b; });
    out.push(select("tahun_rencana", "Tahun rencana", years, years[years.length - 1]));
    var year = Number(val("tahun_rencana", years[years.length - 1]));
    var mine = sortBy(bySection.filter(function (r) { return Number(r.TAHUN_RENCANA) === year; }), ["NAMA_SEKSI"]);
    var spent = sum(mine, "REALISASI_PROGRAM_TERLAKSANA"), planned = sum(mine, "ANGGARAN_PROGRAM_TERLAKSANA");
    out.push(tiles([
      metric("Program direncanakan", whole(sum(mine, "JUMLAH_PROGRAM"))),
      metric("Terlaksana", whole(sum(mine, "JUMLAH_TERLAKSANA"))),
      metric("Ditunda atau dibatalkan", whole(sum(mine, "JUMLAH_DITUNDA") + sum(mine, "JUMLAH_DIBATALKAN"))),
      metric("Anggaran terpakai", planned ? percent(100 * spent / planned) : "-", "Realisasi dibagi anggaran, hanya untuk program yang sudah terlaksana.")
    ]));
    out.push(sub("Persentase anggaran terpakai per seksi"));
    var shown = notMissing(mine, "PERSEN_TERPAKAI_PROGRAM_TERLAKSANA").map(function (r) {
      return {Seksi: r.NAMA_SEKSI, Persen: r.PERSEN_TERPAKAI_PROGRAM_TERLAKSANA, Teks: percent(r.PERSEN_TERPAKAI_PROGRAM_TERLAKSANA, 0)};
    });
    out.push(hbarChart(shown, "Seksi", "Persen", "% anggaran terpakai", col(shown, "Seksi"), "Teks", 100, null, 0, 125));
    out.push(caption("Hanya program yang sudah terlaksana. Garis abu-abu adalah 100% dari anggaran. Program yang ditunda, dibatalkan, " +
      "atau belum berjalan tidak dihitung agar tidak tampak boros atau hemat."));
  } else {
    out.push(sub("Kelengkapan laporan kegiatan terlaksana"));
    var done = sortBy(completeness, ["NAMA_SEKSI"]);
    var names = ["Laporan final", "Laporan draf atau revisi", "Belum ada laporan"];
    var fields = ["JUMLAH_LAPORAN_FINAL", "JUMLAH_LAPORAN_DRAF_ATAU_REVISI", "JUMLAH_BELUM_ADA_LAPORAN"];
    var stacked = [];
    done.forEach(function (r) {
      names.forEach(function (n, i) { stacked.push({Seksi: r.NAMA_SEKSI, Status: n, Jumlah: Number(r[fields[i]]), Urut: i}); });
    });
    out.push(chartBox({data: {values: stacked}, mark: {type: "bar", size: 16}, encoding: {
      y: {field: "Seksi", type: "nominal", sort: col(done, "NAMA_SEKSI"), axis: {title: null, labelLimit: 240}},
      x: {field: "Jumlah", type: "quantitative", axis: {title: "Jumlah kegiatan terlaksana", tickMinStep: 1, format: "d"}, stack: "zero"},
      color: {field: "Status", type: "nominal", scale: colorScale(names), legend: {title: null}},
      order: {field: "Urut", type: "quantitative", sort: "ascending"},
      tooltip: [{field: "Seksi", type: "nominal"}, {field: "Status", type: "nominal"}, {field: "Jumlah", type: "quantitative", format: "d"}]}},
      Math.max(240, 34 * done.length + 60)));

    out.push(sub("Target peserta dan kehadiran sebenarnya"));
    var held = events.filter(function (r) { return r.STATUS_KEGIATAN === "Terlaksana" && !missing(r.PERSEN_CAPAIAN_TARGET); });
    if (!held.length) { out.push(info("Belum ada kegiatan terlaksana dengan target peserta.")); }
    else {
      var yearly = sortBy(groupBy(held, function (r) { return yearOf(r.TANGGAL_MULAI); }).map(function (g) {
        var v = mean(g[1], "PERSEN_CAPAIAN_TARGET");
        return {Tahun: String(g[0]), key: g[0], Persen: v, Teks: percent(v, 0)};
      }), ["key"]);
      out.push(barChart(yearly, "Tahun", "Persen", "Rata-rata % capaian target peserta", col(yearly, "Tahun"), "Teks", 300, 0));
      out.push(caption("Rata-rata persentase peserta aktual terhadap target, untuk kegiatan yang terlaksana pada tahun itu."));
    }

    // The Streamlit page lists the events and the names of their report files in a table. Here the list is a dropdown, and the report opens.
    out.push(sub("Laporan kegiatan (PDF)"));
    out.push(para("Pilih kegiatan untuk membuka laporan pascakegiatannya. Berkas ini adalah dokumen contoh (fiktif). Baris tabel laporan " +
      "diambil dari dokumen seperti ini."));
    var sections = ["Semua seksi"].concat(uniq(col(events, "NAMA_SEKSI")).sort());
    out.push(select("seksi_kegiatan", "Seksi", sections));
    var section = val("seksi_kegiatan", "Semua seksi");
    var inSection = events.filter(function (r) { return section === "Semua seksi" || r.NAMA_SEKSI === section; });
    var listing = sortBy(inSection.filter(function (r) { return !missing(r.NAMA_BERKAS_LAPORAN); }), ["TANGGAL_MULAI", "ID_KEGIATAN"], [true, false]);
    if (!listing.length) { out.push(info("Belum ada laporan pada pilihan ini.")); return out.join(""); }
    var labels = listing.map(function (r) { return r.ID_KEGIATAN + " | " + longDate(r.TANGGAL_MULAI) + " | " + r.NAMA_KEGIATAN; });
    out.push(select("laporan_kegiatan", "Kegiatan", labels));
    var ev = listing[labels.indexOf(val("laporan_kegiatan", labels[0]))];
    out.push(para("<strong>" + esc(ev.NAMA_KEGIATAN) + "</strong> (" + esc(ev.NAMA_SEKSI) + "), " + esc(longDate(ev.TANGGAL_MULAI)) + ", " + esc(text(ev.LOKASI))));
    out.push(tiles([
      metric("Status kegiatan", text(ev.STATUS_KEGIATAN)),
      metric("Peserta aktual / target", whole(ev.JUMLAH_PESERTA_AKTUAL) + " / " + whole(ev.TARGET_PESERTA)),
      metric("Anggaran terpakai", juta(ev.ANGGARAN_TERPAKAI), "Anggaran rencana: " + juta(ev.ANGGARAN_RENCANA)),
      metric("Status laporan", text(ev.STATUS_PELAPORAN))
    ]));
    out.push(caption("Laporan " + esc(ev.ID_LAPORAN) + ", tanggal " + esc(longDate(ev.TANGGAL_LAPORAN)) + ". " + esc(text(ev.KELENGKAPAN_ISI_LAPORAN)) + "."));
    out.push(pdfButtons(ev.NAMA_BERKAS_LAPORAN, "laporan"));
    var without = inSection.filter(function (r) { return r.STATUS_PELAPORAN === "Belum ada laporan"; }).length;
    if (without) {
      out.push(caption(without + " kegiatan terlaksana pada pilihan ini belum memiliki laporan, jadi tidak ada berkasnya."));
    }
  }
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageSurveys() {
  var results = V("HASIL_SURVEI"), likert = V("RINGKASAN_SKOR_LIKERT");
  var out = [title("Survei umat"), banner()];
  var seen = {}, surveys = [];
  results.forEach(function (r) { if (!seen[r.ID_SURVEI]) { seen[r.ID_SURVEI] = 1; surveys.push({id: r.ID_SURVEI, judul: r.JUDUL_SURVEI, status: r.STATUS_SURVEI}); } });
  surveys = sortBy(surveys, ["judul"]);
  if (!surveys.length) { out.push(info("Belum ada hasil survei.")); return out.join(""); }
  out.push(select("survei", "Survei", col(surveys, "judul")));
  var survey = surveys.filter(function (s) { return s.judul === val("survei", surveys[0].judul); })[0];
  out.push(caption("Status survei: " + esc(survey.status) + ". Hasil ditampilkan dalam bentuk agregat; tidak ada jawaban individu."));
  var data = results.filter(function (r) { return r.ID_SURVEI === survey.id; });

  var qseen = {}, questions = [];
  data.forEach(function (r) { if (!qseen[r.ID_PERTANYAAN]) { qseen[r.ID_PERTANYAAN] = 1; questions.push({id: r.ID_PERTANYAAN, no: r.NOMOR_PERTANYAAN, teks: r.TEKS_PERTANYAAN}); } });
  questions = sortBy(questions, ["no"]);
  var labels = questions.map(function (q) { return Math.trunc(q.no) + ". " + q.teks; });
  out.push(select("pertanyaan." + survey.id, "Pertanyaan", labels));
  var pick = val("pertanyaan." + survey.id, labels[0]);
  var question = questions[labels.indexOf(pick)];
  var answers = sortBy(data.filter(function (r) { return r.ID_PERTANYAAN === question.id; }), ["NOMOR_OPSI"]);
  var respondents = maxOf(col(answers, "TOTAL_RESPONDEN_PERTANYAAN"));
  if (missing(respondents) || respondents === 0) { out.push(info("Survei ini belum memiliki jawaban.")); }
  else {
    out.push(sub(question.teks));
    out.push(caption(whole(respondents) + " responden menjawab pertanyaan ini."));
    var rows = answers.map(function (a) {
      return {Jawaban: a.KATEGORI_JAWABAN, Persen: a.PERSENTASE_JAWABAN, Teks: percent(a.PERSENTASE_JAWABAN, 1) + " (" + whole(a.JUMLAH_RESPONDEN) + " responden)"};
    });
    out.push(hbarChart(rows, "Jawaban", "Persen", "% responden", col(rows, "Jawaban"), "Teks", null, null, 0, null));
  }

  var mine = sortBy(likert.filter(function (r) { return r.ID_SURVEI === survey.id; }), ["NOMOR_PERTANYAAN"]);
  if (mine.length) {
    out.push(sub("Ringkasan skala setuju"));
    var lrows = mine.map(function (r) {
      return {Pernyataan: Math.trunc(r.NOMOR_PERTANYAAN) + ". " + r.TEKS_PERTANYAAN, Persen: r.PERSEN_SETUJU_ATAU_SANGAT_SETUJU,
              Teks: percent(r.PERSEN_SETUJU_ATAU_SANGAT_SETUJU, 1) + " (skor rata-rata " + number(r.SKOR_RATA_RATA, 2) + ")"};
    });
    out.push(hbarChart(lrows, "Pernyataan", "Persen", "% setuju atau sangat setuju", col(lrows, "Pernyataan"), "Teks", null, null, 1, 125));
  }
  out.push(howToRead(["Persentase dihitung dari responden yang menjawab pertanyaan itu; responden boleh melewati pertanyaan.",
                      "Urutan jawaban mengikuti urutan pilihan pada kuesioner."]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageDemographics() {
  var out = [title("Demografi umat"), banner()];
  out.push(info("Halaman ini hanya memuat angka agregat umat aktif: tidak ada nama, keluarga, atau data perorangan. Kelompok yang hanya berisi 1 sampai 4 orang " +
    "(atau keluarga) disembunyikan agar tidak ada yang dapat dikenali. Angka ini menggambarkan susunan umat, bukan ukuran iman, " +
    "dan tidak boleh dipakai untuk memeringkat wilayah atau lingkungan."));
  var s = V("RINGKASAN_DEMOGRAFI_UMAT")[0];
  var pyramid = sortBy(V("DEMOGRAFI_UMAT_USIA_JENIS_KELAMIN"), ["URUTAN_KELOMPOK", "JENIS_KELAMIN"]);
  var regions = V("DEMOGRAFI_UMAT_PER_WILAYAH");
  var households = sortBy(V("DEMOGRAFI_KELUARGA"), ["URUTAN_UKURAN"]);

  out.push(tiles([
    metric("Umat aktif", whole(s.JUMLAH_UMAT_AKTIF), "Umat berstatus aktif pada keluarga yang masih aktif."),
    metric("Keluarga aktif", whole(s.JUMLAH_KELUARGA_AKTIF)),
    metric("Rata-rata anggota per keluarga", number(s.RATA_RATA_ANGGOTA_KELUARGA, 1)),
    metric("Usia median", number(s.USIA_MEDIAN, 0) + " tahun", "Separuh umat aktif lebih muda dan separuh lebih tua dari usia ini.")
  ]));
  out.push(tiles([
    metric("Perempuan", percent(s.PERSEN_PEREMPUAN)),
    metric("Anak dan remaja (0-16)", percent(s.PERSEN_ANAK_REMAJA)),
    metric("Lansia (60 ke atas)", percent(s.PERSEN_LANSIA)),
    metric("Umat tercatat yang tidak dihitung", whole(s.JUMLAH_UMAT_TIDAK_DIHITUNG),
      "Umat yang pindah paroki, tidak aktif, atau meninggal dunia, atau yang tidak berada pada keluarga aktif.")
  ]));
  out.push(caption("Data per " + esc(longDate(s.TANGGAL_DATA)) + ". Usia dihitung dari tahun lahir pada tanggal data, sehingga bisa meleset satu tahun."));

  var t = tabs("tab.demografi", ["Usia dan jenis kelamin", "Susunan umur per wilayah", "Keluarga"]);
  out.push(t.html);
  if (t.active === "Usia dan jenis kelamin") {
    out.push(sub("Piramida umat menurut usia dan jenis kelamin"));
    out.push(populationPyramid(pyramid));
    out.push(caption("Batang ke kiri adalah laki-laki dan batang ke kanan adalah perempuan, per kelompok usia sepuluh tahunan. " +
      "Kelompok teratas, 70 tahun ke atas, dijadikan satu."));
    var hiddenAge = pyramid.filter(function (r) { return r.DISEMBUNYIKAN; }).length;
    if (hiddenAge) { out.push(info(hiddenAge + " kelompok dengan 1 sampai 4 orang disembunyikan dan tidak digambar.")); }
    out.push(sub("Kelompok kehidupan"));
    var stages = [["Anak dan remaja (0-16)", s.PERSEN_ANAK_REMAJA], ["Orang muda (17-35)", s.PERSEN_ORANG_MUDA], ["Dewasa (36-59)", s.PERSEN_DEWASA],
                  ["Lansia (60 ke atas)", s.PERSEN_LANSIA]].map(function (x) { return {Kelompok: x[0], Persen: x[1], Teks: percent(x[1])}; });
    out.push(hbarChart(stages, "Kelompok", "Persen", "% umat aktif", col(stages, "Kelompok"), "Teks", null, 200, 0, 60));
    out.push(caption("Kelompok kehidupan memudahkan merencanakan pelayanan: anak dan remaja, orang muda, dewasa, dan lansia. Batasnya 16, 35, dan 59 tahun."));
  } else if (t.active === "Susunan umur per wilayah") {
    out.push(sub("Susunan umur setiap wilayah"));
    out.push(radio("ukuran_demografi", "Tampilkan", ["Jumlah umat", "Persentase dalam wilayah"]));
    out.push(regionStageChart(regions, val("ukuran_demografi", "Jumlah umat") === "Persentase dalam wilayah"));
    out.push(caption("Wilayah diurutkan menurut abjad. Grafik ini menggambarkan susunan umur di setiap wilayah, untuk membantu merencanakan pelayanan, " +
      "bukan untuk membandingkan atau memeringkat wilayah."));
    var hiddenRegion = regions.filter(function (r) { return r.DISEMBUNYIKAN; }).length;
    if (hiddenRegion) { out.push(info(hiddenRegion + " kelompok dengan 1 sampai 4 orang disembunyikan dan tidak digambar.")); }
  } else {
    out.push(sub("Keluarga menurut banyaknya anggota"));
    var sizes = households.filter(function (r) { return !r.DISEMBUNYIKAN; }).map(function (r) {
      return {Ukuran: r.UKURAN_KELUARGA, Keluarga: Number(r.JUMLAH_KELUARGA), Teks: whole(r.JUMLAH_KELUARGA)};
    });
    out.push(barChart(sizes, "Ukuran", "Keluarga", "Jumlah keluarga aktif", col(households, "UKURAN_KELUARGA"), "Teks", 300, 0));
    var withChildren = s.JUMLAH_KELUARGA_DENGAN_ANAK_REMAJA;
    out.push(para("Sebanyak <strong>" + whole(withChildren) + "</strong> dari " + whole(s.JUMLAH_KELUARGA_AKTIF) + " keluarga aktif (" +
      percent(100 * withChildren / s.JUMLAH_KELUARGA_AKTIF, 0) + ") memiliki anak atau remaja di bawah 17 tahun."));
    out.push(caption("Keluarga dihitung dari umat aktif pada keluarga yang masih aktif. Kelompok terakhir menggabungkan keluarga dengan lima anggota atau lebih."));
    var hiddenFamily = households.filter(function (r) { return r.DISEMBUNYIKAN; }).length;
    if (hiddenFamily) { out.push(info(hiddenFamily + " kelompok dengan 1 sampai 4 keluarga disembunyikan dan tidak digambar.")); }
  }
  out.push(howToRead([
    "**Umat aktif** adalah umat berstatus aktif pada keluarga yang masih aktif. Umat yang pindah paroki, tidak aktif, atau meninggal dunia tidak dihitung.",
    "**Usia** dihitung dari tahun lahir pada tanggal data, bukan dari tanggal hari ini, sehingga bisa meleset satu tahun.",
    "**Angka kecil disembunyikan.** Bila suatu kelompok hanya berisi 1 sampai 4 orang, jumlahnya tidak ditampilkan. Ini aturan sederhana untuk demonstrasi, " +
      "bukan perlindungan formal; untuk data nyata perlu ditinjau lebih lanjut.",
    "Halaman ini tidak memeringkat wilayah atau lingkungan dan tidak mengukur iman atau komitmen umat."
  ]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageServices() {
  var services = sortBy(V("LAYANAN_PUBLIK"), ["ID_LAYANAN"]);
  var steps = sortBy(V("LANGKAH_LAYANAN_PUBLIK"), ["ID_LAYANAN", "NOMOR_URUT"]);
  var requirements = sortBy(V("PERSYARATAN_LAYANAN_PUBLIK"), ["ID_LAYANAN", "NOMOR_URUT"]);
  var out = [title("Layanan dan prosedur"), banner()];
  out.push(para("Langkah dan persyaratan layanan paroki, untuk dibaca siapa saja. Pilih layanan, lihat apa yang perlu disiapkan dan urutan langkahnya, " +
    "atau unduh panduan PDF untuk dicetak."));
  if (!services.length) { out.push(info("Belum ada layanan yang dapat ditampilkan untuk umum.")); return out.join(""); }
  out.push(warn(esc(services[0].CATATAN_PENGGUNAAN)));

  out.push(select("layanan", "Pilih layanan", col(services, "NAMA_LAYANAN")));
  var row = services.filter(function (s) { return s.NAMA_LAYANAN === val("layanan", services[0].NAMA_LAYANAN); })[0], sid = row.ID_LAYANAN;
  out.push(sub(row.NAMA_LAYANAN));
  out.push(caption(esc(row.KATEGORI_LAYANAN) + " | dikelola " + esc(row.SEKSI_PENGELOLA) + " | terakhir ditinjau " + esc(longDate(row.TANGGAL_REVISI))));
  out.push(para(esc(row.RINGKASAN)));
  out.push(para("<strong>Perkiraan waktu:</strong> " + esc(row.PERKIRAAN_WAKTU_PROSES)));

  var needs = requirements.filter(function (r) { return r.ID_LAYANAN === sid; }), todo = steps.filter(function (r) { return r.ID_LAYANAN === sid; });
  var first = "Persyaratan (" + needs.length + ")", second = "Langkah-langkah (" + todo.length + ")";
  var t = tabs("tab.layanan", [first, second]);
  out.push(t.html);
  if (t.active === first) {
    out.push(para(whole(row.JUMLAH_PERSYARATAN_WAJIB) + " dari " + needs.length + " persyaratan selalu wajib. Sisanya hanya berlaku pada keadaan tertentu."));
    out.push('<ul class="checklist">' + needs.map(function (n) {
      return "<li><strong>" + esc(n.NAMA_PERSYARATAN) + "</strong> (" + esc(n.JENIS_PERSYARATAN) + ", " + esc(lower(n.STATUS_PERSYARATAN)) + ")" +
        (typeof n.KETERANGAN === "string" ? "<br><span class=\"muted\">" + esc(n.KETERANGAN) + "</span>" : "") + "</li>";
    }).join("") + "</ul>");
  } else {
    out.push('<ol class="steps">' + todo.map(function (s) {
      return "<li><strong>" + esc(s.JUDUL_LANGKAH) + "</strong><br><em>Pelaku: " + esc(s.PELAKU) + ".</em> " + esc(s.URAIAN) + "</li>";
    }).join("") + "</ol>");
  }
  out.push(info("<strong>Catatan penting.</strong> " + esc(row.CATATAN_PENTING)));
  out.push(pdfButtons(row.NAMA_BERKAS_PANDUAN, "panduan"));
  out.push(howToRead([
    "Isi halaman ini sama dengan isi panduan PDF: keduanya dibuat dari data yang sama.",
    "Data pribadi tidak ditampilkan. Pendaftaran dan data keluarga hanya dilihat petugas yang berwenang.",
    "Panduan ini contoh untuk demonstrasi. Ketentuan sebenarnya ditetapkan oleh paroki dan keuskupan masing-masing."
  ]));
  return out.join("");
}

// ------------------------------------------------------------------------------------------------
function pageAbout() {
  var masses = V("PELAKSANAAN_MISA");
  var held = masses.filter(function (r) { return r.STATUS_PELAKSANAAN === "Terlaksana"; });
  var out = [title("Tentang data"), banner()];
  if (held.length) {
    out.push(para("Catatan Misa yang terlaksana tersedia sampai <strong>" + esc(longDate(maxOf(col(held, "TANGGAL_MISA")))) + "</strong> (mulai " +
      esc(longDate(minOf(col(held, "TANGGAL_MISA")))) + ")."));
  }
  [
    "**Apa ini?** Demonstrasi Pusat Informasi Paroki: contoh bagaimana informasi dari berbagai fungsi paroki dapat dikumpulkan, dirapikan, dihubungkan, dan disajikan. Ini bukti konsep, bukan sistem produksi.",
    "**Seluruh data fiktif.** Nama, keluarga, wilayah, lingkungan, kegiatan, angka kolekte, dan peristiwa dibuat oleh program. Batas wilayah dan peta, bila ada pada versi mendatang, hanya ilustrasi dan bukan batas resmi.",
    "**Privasi.** Dasbor hanya membaca ringkasan agregat. Tidak ada nama, keluarga, atau sumbangan perorangan yang ditampilkan. Halaman Demografi umat hanya memuat jumlah dan persentase, dan kelompok yang hanya berisi 1 sampai 4 orang disembunyikan.",
    "**Tentang angka sumbangan dan kolekte.** Angka ini menggambarkan administrasi keuangan dan kapasitas ekonomi. Angka ini bukan ukuran iman, komitmen rohani, atau kemurahan hati, dan tidak dipakai untuk memeringkat wilayah atau lingkungan.",
    "**Tentang perkiraan bayangan.** Perkiraan kolekte mingguan dibuat empat pekan sebelumnya dan disimpan tanpa pernah diubah. Dasbor membandingkannya dengan kolekte aktual agar terlihat seberapa tepat perkiraan itu dan peristiwa apa yang membuatnya meleset.",
    "**Tentang layanan dan prosedur.** Halaman layanan memuat panduan contoh (langkah dan persyaratan) yang fiktif dan bukan ketentuan resmi.",
    "**Tentang proyeksi.** Garis tren adalah garis lurus dari lima tahun lengkap. Ia membantu menggambarkan arah, bukan meramalkan masa depan. Peristiwa luar biasa tidak bisa diprediksi; karena itu dicatat agar penyimpangan perkiraan dapat dijelaskan."
  ].forEach(function (p) { out.push(para(md(p))); });

  out.push(sub("Tentang berkas ini"));
  out.push(para("Ini adalah <strong>salinan statis</strong> dari dasbor Streamlit: satu berkas HTML yang dapat dibuka tanpa instalasi, tanpa akun, dan tanpa koneksi internet. " +
    "Angka di dalamnya adalah potret data pada saat berkas dibuat. Berkas ini <strong>tidak terhubung ke Snowflake</strong> dan tidak menyegarkan data. " +
    "Tabel data tidak disertakan; yang ada hanya grafik dan pilihan (dropdown)."));
  out.push(sub("Sumber data"));
  out.push(para("Grafik dibuat dari " + Object.keys(DATA).length + " tampilan (view) yang sama dengan dasbor Streamlit, yaitu skema <code>ANALISIS</code> pada basis data " +
    "<code>PUSAT_INFORMASI_PAROKI</code>:"));
  out.push('<pre class="code">' + esc(Object.keys(DATA).sort().join("\n")) + "</pre>");
  out.push(caption('Label sumber pada setiap tampilan: "Data simulasi (fiktif)".'));
  return out.join("");
}
