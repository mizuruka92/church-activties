"use strict";
/* Pusat Informasi Paroki: static HTML dashboard. ALL DATA IS SIMULATED.
   Core: formatting (Indonesian conventions), data access, small pandas-like helpers, UI building blocks.
   The text shown to users is Bahasa Indonesia; code and comments are English. */

// ------------------------------------------------------------------------------------------------
// Constants
// ------------------------------------------------------------------------------------------------
var MONTHS = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];
var PALETTES = {light: ["#2a78d6", "#eb6834", "#1baf7a"], dark: ["#3987e5", "#d95926", "#199e70"]};
var INK = {light: "#0b0b0b", dark: "#f0efec"};
var NEUTRAL = "#898781";
var DAY_MS = 86400000;
var theme = "light";

function palette() { return PALETTES[theme]; }
function ink() { return INK[theme]; }
function colorScale(labels) { return {domain: labels.slice(), range: palette().slice(0, labels.length)}; }

// ------------------------------------------------------------------------------------------------
// Dates: the views return ISO dates ("2026-09-30"). They become local-midnight timestamps so that
// charts, axis ticks and arithmetic never shift by a day in another time zone.
// ------------------------------------------------------------------------------------------------
function ts(iso) {
  var p = iso.split("-");
  return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])).getTime();
}
function addDays(ms, n) {
  var d = new Date(ms);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n).getTime();
}
function yearOf(ms) { return new Date(ms).getFullYear(); }
function monthOf(ms) { return new Date(ms).getMonth(); }
function dayOf(ms) { return new Date(ms).getDate(); }
function monthStart(year, month) { return new Date(Number(year), Number(month) - 1, 1).getTime(); }

// ------------------------------------------------------------------------------------------------
// Formatting (dot for thousands, comma for decimals, like the Streamlit dashboard)
// ------------------------------------------------------------------------------------------------
function missing(v) { return v === null || v === undefined || (typeof v === "number" && isNaN(v)); }

// Rounds like Python's format(): the exact binary value of the number decides, and only a real tie (0.125, 2.5) goes to
// the even digit. toFixed() rounds an exact tie upward, so a tie is recognised from the exact expansion and settled here.
function fixed(x, d) { // x >= 0
  var long = x.toFixed(Math.min(100, d + 25)), tail = long.slice(long.length - 25);
  if (!/^50*$/.test(tail)) { return x.toFixed(d); }
  var kept = long.slice(0, long.length - 25).replace(/\.$/, "");   // the digits before the tie
  var lastDigit = Number(kept.charAt(kept.length - 1));
  return lastDigit % 2 === 0 ? kept : (Number(kept) + Math.pow(10, -d)).toFixed(d);
}
function number(v, d) {
  if (missing(v)) { return "-"; }
  d = d || 0;
  var x = Number(v), s = fixed(Math.abs(x), d), parts = s.split(".");
  parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  var out = parts.join(",");
  return (x < 0 ? "-" : "") + out;   // like Python: a small negative number that rounds to zero keeps its sign
}
function rupiah(v) { return missing(v) ? "-" : (Number(v) < 0 ? "-" : "") + "Rp " + number(Math.abs(Number(v))); }
function juta(v, d) {
  if (missing(v)) { return "-"; }
  return (Number(v) < 0 ? "-" : "") + "Rp " + number(Math.abs(Number(v)) / 1e6, d === undefined ? 1 : d) + " jt";
}
function percent(v, d) { return missing(v) ? "-" : number(v, d === undefined ? 1 : d) + "%"; }
function signedPercent(v, d) {
  if (missing(v)) { return "-"; }
  return (Number(v) > 0 ? "+" : "") + number(v, d === undefined ? 1 : d) + "%";
}
function longDate(ms) {
  if (missing(ms)) { return "-"; }
  var d = new Date(ms);
  return d.getDate() + " " + MONTHS[d.getMonth()] + " " + d.getFullYear();
}
function whole(v) { return number(v, 0); }
function text(v) { return missing(v) ? "-" : String(v); }
function daysAway(n) {
  if (missing(n)) { return "-"; }
  n = Math.trunc(n);
  if (n === 0) { return "hari ini"; }
  return n > 0 ? n + " hari lagi" : (-n) + " hari lalu";
}
function lower(s) { return String(s).toLowerCase(); }
function esc(s) {
  return String(s === null || s === undefined ? "" : s).replace(/[&<>"']/g, function (c) {
    return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}[c];
  });
}
// **bold** inside plain text, for sentences that mix text and emphasis
function md(s) { return esc(s).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>"); }

// ------------------------------------------------------------------------------------------------
// Data access: DATA[view] = {c: [columns], r: [[values]]}, rebuilt as row objects on first use.
// ------------------------------------------------------------------------------------------------
var _views = {};
function V(name) {
  if (!_views[name]) {
    var table = DATA[name];
    if (!table) { throw new Error("Tampilan " + name + " tidak ada pada data."); }
    _views[name] = table.r.map(function (row) {
      var o = {};
      for (var i = 0; i < table.c.length; i++) {
        var v = row[i];
        o[table.c[i]] = (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v)) ? ts(v) : v;
      }
      return o;
    });
  }
  return _views[name];
}

// ------------------------------------------------------------------------------------------------
// Small pandas-like helpers
// ------------------------------------------------------------------------------------------------
function cmp(a, b) { return a < b ? -1 : (a > b ? 1 : 0); }
function sortBy(rows, keys, descending) { // keys: field names or functions; stable
  var fns = keys.map(function (k) { return typeof k === "function" ? k : function (r) { return r[k]; }; });
  var desc = descending || [];
  return rows.map(function (r, i) { return [r, i]; }).sort(function (a, b) {
    for (var i = 0; i < fns.length; i++) {
      var c = cmp(fns[i](a[0]), fns[i](b[0]));
      if (c !== 0) { return desc[i] ? -c : c; }
    }
    return a[1] - b[1];
  }).map(function (p) { return p[0]; });
}
function sum(rows, f) {
  var fn = typeof f === "function" ? f : function (r) { return r[f]; }, t = 0;
  rows.forEach(function (r) { var v = fn(r); if (!missing(v)) { t += Number(v); } });
  return t;
}
function mean(rows, f) {
  var fn = typeof f === "function" ? f : function (r) { return r[f]; }, t = 0, n = 0;
  rows.forEach(function (r) { var v = fn(r); if (!missing(v)) { t += Number(v); n++; } });
  return n ? t / n : null;
}
function median(values) {
  var a = values.filter(function (v) { return !missing(v); }).sort(function (x, y) { return x - y; });
  if (!a.length) { return null; }
  var m = Math.floor(a.length / 2);
  return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
}
function maxOf(values) { var a = values.filter(function (v) { return !missing(v); }); return a.length ? Math.max.apply(null, a) : null; }
function minOf(values) { var a = values.filter(function (v) { return !missing(v); }); return a.length ? Math.min.apply(null, a) : null; }
function col(rows, f) { return rows.map(typeof f === "function" ? f : function (r) { return r[f]; }); }
function uniq(values) { var seen = {}, out = []; values.forEach(function (v) { if (!seen[v]) { seen[v] = 1; out.push(v); } }); return out; }
function groupBy(rows, keyFn) { // insertion-ordered groups: [[key, rows], ...]
  var index = {}, out = [];
  rows.forEach(function (r) {
    var k = keyFn(r), s = String(k);
    if (!(s in index)) { index[s] = out.length; out.push([k, []]); }
    out[index[s]][1].push(r);
  });
  return out;
}
function where(rows, fn) { return rows.filter(fn); }
function notMissing(rows, f) { return rows.filter(function (r) { return !missing(r[f]); }); }
function last(rows) { return rows[rows.length - 1]; }
function range(a, b) { var o = []; for (var i = a; i <= b; i++) { o.push(i); } return o; }

// Year of a week taken from its Sunday, so a week that straddles New Year counts for the new year.
function weekYear(ms) { return yearOf(addDays(ms, 6)); }

// First or last week that holds only part of the Masses (the data starts or ends mid-week) is dropped.
function completeWeeks(weekly) {
  var rows = sortBy(weekly, ["AWAL_PEKAN"]);
  var typical = median(col(rows, "JUMLAH_MISA_TERLAKSANA"));
  var enough = rows.map(function (r) { return r.JUMLAH_MISA_TERLAKSANA >= 0.6 * typical; });
  var start = 0, end = enough.length;
  while (start < end && !enough[start]) { start++; }
  while (end > start && !enough[end - 1]) { end--; }
  return rows.slice(start, end);
}

// ------------------------------------------------------------------------------------------------
// UI state and building blocks. Pages return HTML strings; charts are placeholders that are drawn
// after the page is inserted (see main.js). Every control carries data-key, and a change re-renders.
// ------------------------------------------------------------------------------------------------
var S = {};            // control state: key -> value
var pending = [];      // charts to draw after the page HTML is in the document
var chartCounter = 0;

function val(key, fallback) { return (key in S) ? S[key] : fallback; }

function metric(label, value, help, delta) {
  return '<div class="metric"' + (help ? ' title="' + esc(help) + '"' : "") + '><div class="m-label">' + esc(label) +
    (help ? ' <span class="m-help">?</span>' : "") + '</div><div class="m-value">' + esc(value) + "</div>" +
    (delta ? '<div class="m-delta">' + esc(delta) + "</div>" : "") + "</div>";
}
function tiles(list) { return '<div class="tiles">' + list.join("") + "</div>"; }
function banner() {
  return '<div class="callout info"><strong>DATA SIMULASI.</strong> Seluruh angka, nama, dan peristiwa pada dasbor ini fiktif dan ' +
    "dibuat oleh program untuk demonstrasi. Tidak ada data nyata paroki.</div>";
}
function info(html) { return '<div class="callout info">' + html + "</div>"; }
function warn(html) { return '<div class="callout warn">' + html + "</div>"; }
function caption(html) { return '<p class="caption">' + html + "</p>"; }
function para(html) { return "<p>" + html + "</p>"; }
function title(t) { return "<h1>" + esc(t) + "</h1>"; }
function sub(t) { return "<h2>" + esc(t) + "</h2>"; }
function sub3(t) { return "<h3>" + esc(t) + "</h3>"; }
function bullets(items) { return "<ul>" + items.map(function (i) { return "<li>" + i + "</li>"; }).join("") + "</ul>"; }
function howToRead(lines) {
  return '<details class="expander"><summary>Cara membaca halaman ini</summary>' + bullets(lines.map(md)) + "</details>";
}
function expander(summary, inner) { return '<details class="expander"><summary>' + esc(summary) + "</summary>" + inner + "</details>"; }
function columns(parts) { return '<div class="cols cols-' + parts.length + '">' + parts.map(function (p) { return "<div>" + p + "</div>"; }).join("") + "</div>"; }

function select(key, label, options, fallback) {
  var cur = val(key, fallback === undefined ? options[0] : fallback);
  if (options.map(String).indexOf(String(cur)) < 0) {
    cur = (fallback !== undefined && options.map(String).indexOf(String(fallback)) >= 0) ? fallback : options[0];
    S[key] = cur;
  }
  return '<label class="ctl"><span>' + esc(label) + '</span><select data-key="' + esc(key) + '">' + options.map(function (o) {
    return '<option value="' + esc(o) + '"' + (String(o) === String(cur) ? " selected" : "") + ">" + esc(o) + "</option>";
  }).join("") + "</select></label>";
}
function radio(key, label, options, fallback) {
  var cur = val(key, fallback === undefined ? options[0] : fallback);
  if (options.indexOf(cur) < 0) { cur = options[0]; S[key] = cur; }
  return '<fieldset class="ctl radio"><legend>' + esc(label) + "</legend>" + options.map(function (o) {
    return '<label><input type="radio" name="' + esc(key) + '" data-key="' + esc(key) + '" value="' + esc(o) + '"' +
      (o === cur ? " checked" : "") + "> " + esc(o) + "</label>";
  }).join("") + "</fieldset>";
}
// Two selects (from, to) in place of Streamlit's range slider; the pair always stays ordered.
function yearRange(key, years, label) {
  var ys = uniq(years.map(Number)).sort(function (a, b) { return a - b; });
  var a = Number(val(key + ".a", ys[0])), b = Number(val(key + ".b", ys[ys.length - 1]));
  if (ys.indexOf(a) < 0) { a = ys[0]; }
  if (ys.indexOf(b) < 0) { b = ys[ys.length - 1]; }
  if (a > b) { b = a; }
  S[key + ".a"] = a; S[key + ".b"] = b;
  var html = '<div class="ctl yearrange"><span>' + esc(label || "Rentang tahun") + "</span>" +
    select(key + ".a", "Dari", ys, a) + select(key + ".b", "Sampai", ys, b) + "</div>";
  return {first: a, last: b, html: html};
}
function tabs(key, labels) {
  var cur = val(key, labels[0]);
  if (labels.indexOf(cur) < 0) { cur = labels[0]; S[key] = cur; }
  return {
    active: cur,
    html: '<div class="tabs" role="tablist">' + labels.map(function (l) {
      return '<button type="button" role="tab" class="tab' + (l === cur ? " active" : "") + '" data-tab="' + esc(key) + '" data-value="' + esc(l) + '">' + esc(l) + "</button>";
    }).join("") + "</div>"
  };
}
function chartBox(spec, height, extra) {
  var id = "chart" + (++chartCounter);
  pending.push({id: id, spec: spec, height: height});
  return '<div class="chart" id="' + id + '" style="min-height:' + (height + 10) + 'px"' + (extra || "") + "></div>";
}
