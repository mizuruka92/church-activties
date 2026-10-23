# Presentation for the Parish Council

`pusat_informasi_paroki_dewan.pptx` is a 15-slide deck in Bahasa Indonesia for a non-technical audience. It is framed
as **a picture of what a parish information bank can do**, not as a proof of concept and not as a progress report.

The council asked for an information bank without a clear idea of what to build. The deck answers with one message:
an information bank is not just a place to store data. Its value comes from the pastoral purposes it serves, so the
first question is "what do we want to achieve with it?" and not "what data do we keep?". The simulated example shows
what becomes possible when that question has an answer, and the destination is **Pastoral Berbasis Data**
(data-informed pastoral care).

The talk follows a journey in three steps:

| Step | Idea | Slides |
|---|---|---|
| 1. Kumpulkan (collect) | Parish data lives in one place, as simple tables that link to each other. This is the foundation, not the goal. | 5 to 6 |
| 2. Bagikan (share) | Parishioners see what is useful to them (Mass schedule, upcoming events, service guides). Budgets, offertory, reports and personal data stay with the council. | 7 to 8 |
| 3. Pahami (understand) | From data to insight: four findings, the dashboard, the pastoral question behind each finding, and six purposes the bank could serve. | 9 to 12 |

Slides 1 to 4 open the talk:

* Slide 1 is the cover.
* Slide 2 contrasts "only a place to store data" with "an information bank that works", and states that every example is fictional.
* Slide 3 shows the questions the parish already asks.
* Slide 4 gives the three steps.

Slides 13 to 15 close it: principles, the decisions the council would need to make (the first is "what do we want to achieve?"), and the closing slide.
Every slide has speaker notes in Bahasa Indonesia.

## Please read before presenting

* **All figures are simulated.** Every number comes from the fictional dataset in this repository and every content
  slide says so in its footer. Slide 2 also says so in the body. The deck shows the kind of question the dashboards
  can answer. It says nothing about the real parish.
* **The numbers are typed text, not linked to the data.** They were read from the dashboards (pages `Ringkasan`,
  `Perkiraan kolekte`, `Demografi umat`) and from [`docs/USE_CASES.md`](../USE_CASES.md). The dataset is generated
  with a fixed random seed, so they stay the same until the generator changes. If it does, check slides 5, 6, 9 and 10.
* **Screenshots come from the local stand-in, not from Snowflake.** They were taken from the dashboard running on
  DuckDB with the same views (see [`docs/DASHBOARD.md`](../DASHBOARD.md)). They are on slides 8 and 10.
* **Slide 8 corrects a possible misunderstanding.** The activity page of the dashboard is the committee view and
  shows budgets. A parishioner view with only name, date and place is described in the deck but is not built yet.
* **Slide 12 separates what is shown from what is only possible.** Each of the six purposes carries a tag.
  *Ada di contoh* means a dashboard page already demonstrates it with simulated data. *Kemungkinan* means it is not built.

  | Purpose | Tag | Where it appears in the example |
  |---|---|---|
  | Mendengar umat | Ada di contoh | Pages `Demografi umat` and `Survei umat` |
  | Menata pelayanan Misa | Kemungkinan | Attendance per Mass session exists, but matching schedules and volunteers to it is not built |
  | Mengelola dengan bijak | Ada di contoh | Pages `Pemasukan dan pengeluaran` and `Sumbangan khusus` |
  | Bersiap menghadapi peristiwa | Ada di contoh | Page `Peristiwa luar biasa` |
  | Belajar dari kegiatan | Ada di contoh | Page `Rencana, anggaran, kegiatan` |
  | Menjangkau lebih luas | Kemungkinan | There is deliberately no map, because illustrative geometry could be mistaken for real parish boundaries (see [`docs/DASHBOARD.md`](../DASHBOARD.md), section 4) |

  If a *Kemungkinan* item is built later, change its tag and the matching sentence in the speaker notes.
* **Slide 14 asks questions, not for approval.** It lists what the council would need to decide. No cost or timeline is
  given because none was available. The notes mention Snowflake only as the platform used for the example, and say
  the concept is not tied to it.
* **Names.** The deck says "Bank Informasi Paroki". The Snowflake database and the repository documentation keep
  the technical name `PUSAT_INFORMASI_PAROKI`.

## Editing

* Open it in PowerPoint (or any tool that reads `.pptx`). Text, shapes and tables are native objects, so they can be
  edited directly. The screenshots are pictures.
* Fonts are Cambria (headings) and Calibri (body). Both ship with Microsoft Office. Other programs substitute
  similar fonts, so line breaks can differ slightly.
* Colours are defined in the theme, and the slides use three layouts (`TERANG` ivory, `PASIR` sand, `GELAP` dark).
  The content slides alternate between ivory and sand. Changing the theme colours restyles the deck.
* Slide numbers are live fields, so adding or moving slides renumbers them. The step indicator at the bottom right
  of the content slides ("1 Kumpulkan · 2 Bagikan · 3 Pahami") is typed text and must be updated by hand.
* The deck was produced, and later reframed, with one-off scripts that are not part of this repository. The `.pptx`
  itself is the source: edit it directly.
