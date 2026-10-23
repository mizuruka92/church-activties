"use strict";
/* Shell: sidebar navigation, hash routing, theme, event handling, and drawing the charts of the current page. */

var PAGES = [
  ["Ringkasan", pageSummary],
  ["Kegiatan mendatang", pageUpcoming],
  ["Pemasukan dan pengeluaran", pageIncomeOutcome],
  ["Kolekte dan kehadiran", pageOffertoryAttendance],
  ["Perkiraan kolekte", pageForecast],
  ["Peristiwa luar biasa", pageEvents],
  ["Sumbangan khusus", pageDonations],
  ["Rencana, anggaran, kegiatan", pagePlans],
  ["Survei umat", pageSurveys],
  ["Layanan dan prosedur", pageServices],
  ["Tentang data", pageAbout]
];
var THEME_CHOICES = ["otomatis", "terang", "gelap"];
var themeChoice = "otomatis";
var currentPage = PAGES[0][0];
var errors = [];     // collected for tests and for a visible message; the page keeps working
var drawToken = 0;   // a newer render makes older, unfinished chart drawing stop
var lastSpecs = [];  // the specs of the charts on the page now, for tests

function storageGet(key) { try { return window.localStorage.getItem(key); } catch (e) { return null; } }
function storageSet(key, value) { try { window.localStorage.setItem(key, value); } catch (e) { /* private window or blocked storage */ } }

function resolveTheme() {
  if (themeChoice === "terang") { return "light"; }
  if (themeChoice === "gelap") { return "dark"; }
  return (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) ? "dark" : "light";
}
function applyTheme() {
  theme = resolveTheme();
  var root = document.documentElement;
  if (themeChoice === "otomatis") { root.removeAttribute("data-theme"); } else { root.setAttribute("data-theme", theme); }
  var button = document.getElementById("theme-toggle");
  if (button) { button.textContent = "Tema: " + themeChoice; }
}

function pageFromHash() {
  var name = "";
  try { name = decodeURIComponent((location.hash || "").replace(/^#/, "")); } catch (e) { name = ""; }
  for (var i = 0; i < PAGES.length; i++) { if (PAGES[i][0] === name) { return name; } }
  return PAGES[0][0];
}

function renderNav() {
  document.getElementById("nav").innerHTML = PAGES.map(function (p) {
    return '<a href="#' + encodeURIComponent(p[0]) + '" class="nav-item' + (p[0] === currentPage ? " active" : "") + '"' +
      (p[0] === currentPage ? ' aria-current="page"' : "") + ">" + esc(p[0]) + "</a>";
  }).join("");
}

function reportError(where, err) {
  var message = where + ": " + (err && err.message ? err.message : String(err));
  errors.push(message);
  if (window.console && console.error) { console.error(message, err); }
}

function drawCharts(token) {
  var jobs = pending.slice();
  pending = [];
  var chain = Promise.resolve();
  jobs.forEach(function (job) {
    chain = chain.then(function () {
      if (token !== drawToken) { return null; }
      var box = document.getElementById(job.id);
      if (!box) { return null; }
      var tooltipTheme = theme === "dark" ? "dark" : "light";
      return vegaEmbed(box, finalSpec(job.spec, job.height), {mode: "vega-lite", actions: false, renderer: "svg", tooltip: {theme: tooltipTheme}})
        .then(function () { box.setAttribute("data-drawn", "1"); })
        .catch(function (err) {
          reportError("Grafik " + job.id, err);
          box.innerHTML = '<div class="callout warn">Grafik ini tidak dapat digambar.</div>';
        });
    });
  });
  return chain.then(function () { if (token === drawToken) { document.body.setAttribute("data-ready", String(++readyCount)); } });
}
var readyCount = 0;

function render(keepScroll) {
  var scrollY = window.pageYOffset, focusKey = document.activeElement && document.activeElement.getAttribute ? document.activeElement.getAttribute("data-key") : null;
  var focusValue = focusKey && document.activeElement.tagName === "INPUT" ? document.activeElement.value : null;
  pending = [];
  chartCounter = 0;
  var main = document.getElementById("page");
  var html;
  try {
    html = PAGES.filter(function (p) { return p[0] === currentPage; })[0][1]();
  } catch (err) {
    reportError("Halaman " + currentPage, err);
    html = title(currentPage) + warn("Halaman ini tidak dapat ditampilkan: " + esc(err.message));
    pending = [];
  }
  main.innerHTML = html;
  lastSpecs = pending.map(function (job) { return job.spec; });
  renderNav();
  document.title = currentPage + " | Pusat Informasi Paroki (simulasi)";
  if (focusKey) {
    var nodes = main.querySelectorAll('[data-key="' + focusKey.replace(/"/g, '\\"') + '"]'), target = null;
    for (var i = 0; i < nodes.length; i++) { if (focusValue === null || nodes[i].value === focusValue) { target = nodes[i]; } }
    if (target) { target.focus({preventScroll: true}); }
  }
  window.scrollTo(0, keepScroll ? scrollY : 0);
  var token = ++drawToken;
  document.body.removeAttribute("data-ready");
  return drawCharts(token);
}

function showPage(name) {
  currentPage = name;
  S = {};   // controls start fresh on each page, like a new Streamlit page
  return render(false);
}

function downloadGuide(file) {
  var b64 = GUIDES[file];
  if (!b64) { return; }
  var raw = atob(b64), bytes = new Uint8Array(raw.length);
  for (var i = 0; i < raw.length; i++) { bytes[i] = raw.charCodeAt(i); }
  var url = URL.createObjectURL(new Blob([bytes], {type: "application/pdf"}));
  var a = document.createElement("a");
  a.href = url; a.download = file;
  document.body.appendChild(a); a.click(); document.body.removeChild(a);
  setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
}

function start() {
  try { var saved = storageGet("pip.tema"); if (THEME_CHOICES.indexOf(saved) >= 0) { themeChoice = saved; } } catch (e) { /* default */ }
  applyTheme();
  currentPage = pageFromHash();

  document.addEventListener("change", function (e) {
    var el = e.target, key = el.getAttribute && el.getAttribute("data-key");
    if (!key) { return; }
    S[key] = el.value;
    render(true);
  });
  document.addEventListener("click", function (e) {
    var el = e.target.closest ? e.target.closest("[data-tab],[data-download],#theme-toggle") : null;
    if (!el) { return; }
    if (el.hasAttribute("data-tab")) { S[el.getAttribute("data-tab")] = el.getAttribute("data-value"); render(true); }
    else if (el.hasAttribute("data-download")) { downloadGuide(el.getAttribute("data-download")); }
    else if (el.id === "theme-toggle") {
      themeChoice = THEME_CHOICES[(THEME_CHOICES.indexOf(themeChoice) + 1) % THEME_CHOICES.length];
      storageSet("pip.tema", themeChoice);
      applyTheme();
      render(true);
    }
  });
  window.addEventListener("hashchange", function () { var next = pageFromHash(); if (next !== currentPage) { showPage(next); } });
  if (window.matchMedia) {
    var query = window.matchMedia("(prefers-color-scheme: dark)");
    var onScheme = function () { if (themeChoice === "otomatis") { applyTheme(); render(true); } };
    if (query.addEventListener) { query.addEventListener("change", onScheme); } else if (query.addListener) { query.addListener(onScheme); }
  }
  showPage(currentPage);
}

window.__dashboard = {pages: PAGES.map(function (p) { return p[0]; }), errors: errors, show: showPage, state: function () { return S; }, charts: function () { return lastSpecs; }};
if (document.readyState === "loading") { document.addEventListener("DOMContentLoaded", start); } else { start(); }
