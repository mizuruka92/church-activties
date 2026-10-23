# Presentation for the Parish Council

`pusat_informasi_paroki_dewan.pptx` is a 14-slide deck in Bahasa Indonesia for a non-technical audience. It tells
the story as a journey called **Pastoral Berbasis Data** (data-informed pastoral care), in three steps:

| Step | Idea | Slides |
|---|---|---|
| 1. Kumpulkan (collect) | Parish data lives in one place, as simple tables that link to each other. | 4 to 5 |
| 2. Bagikan (share) | Parishioners see what is useful to them (Mass schedule, upcoming events, service guides). Budgets, offertory, reports and personal data stay with the council. | 6 to 7 |
| 3. Pahami (understand) | From data to insight: four findings, the dashboard, and the pastoral question behind each finding. | 8 to 10 |

Slides 1 to 3 open the talk (cover, the questions the parish already asks, the three steps). Slides 11 to 14 close it
(principles, what exists and what does not, the three decisions asked of the council, and the closing slide).
Every slide has speaker notes in Bahasa Indonesia.

## Please read before presenting

* **All figures are simulated.** Every number comes from the fictional dataset in this repository and every content
  slide says so in its footer. The deck shows the kind of question the dashboards can answer. It says nothing about
  the real parish.
* **The numbers are typed text, not linked to the data.** They were read from the dashboards (pages `Ringkasan`,
  `Perkiraan kolekte`, `Demografi umat`) and from [`docs/USE_CASES.md`](../USE_CASES.md). The dataset is generated
  with a fixed random seed, so they stay the same until the generator changes. If it does, check slides 4, 5, 8 and 9.
* **Screenshots come from the local stand-in, not from Snowflake.** They were taken from the dashboard running on
  DuckDB with the same views (see [`docs/DASHBOARD.md`](../DASHBOARD.md)).
* **Slide 7 corrects a possible misunderstanding.** The activity page of the dashboard is the committee view and
  shows budgets. A parishioner view with only name, date and place is described in the deck but is not built yet.
* **Slide 12 says the example was tried in a Snowflake trial account.** That rests on the repository owner's own
  report (see the verification section of the main [README](../../README.md)). Remove the line if you prefer not to say it.
* **Slide 13 is a proposal.** The three decisions and the first moves are suggestions. No cost or timeline is
  given because none was available.

## Editing

* Open it in PowerPoint (or any tool that reads `.pptx`). Text, shapes and tables are native objects, so they can be
  edited directly. The screenshots are pictures.
* Fonts are Cambria (headings) and Calibri (body). Both ship with Microsoft Office. Other programs substitute
  similar fonts, so line breaks can differ slightly.
* Colours are defined in the theme, and the slides use three layouts (`TERANG` ivory, `PASIR` sand, `GELAP` dark).
  Changing the theme colours restyles the deck.
* The deck was produced by a one-off script and that script is not part of this repository. The `.pptx` itself is
  the source: edit it directly.
