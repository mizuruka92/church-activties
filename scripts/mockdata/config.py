"""Fixed parameters of the demo dataset. Changing any value changes the data."""

from datetime import date

SEED = 20260930

# The dataset is a snapshot "as of" this date. Records dated after it are plans
# or schedules that have not happened yet. Never use date.today() here: the
# output must be reproducible.
AS_OF = date(2026, 9, 30)

# Five full calendar years (2021-2025) plus the current year up to AS_OF.
HISTORY_START = date(2021, 1, 1)
FIRST_PLAN_YEAR = 2021
PLAN_YEAR = 2026  # the current year, partly in the past and partly planned

# Mass occurrences are generated for this window. Those after AS_OF are
# "Terjadwal" (scheduled, not yet held).
MASS_START = HISTORY_START
MASS_END = date(2026, 10, 31)

# Monthly reporting periods in the reference calendar. The calendar runs a few
# years past the snapshot so that projections can be labelled.
PERIOD_START_YEAR = 2021
PERIOD_END_YEAR = 2029

DATASET_LABEL = "Data simulasi (fiktif)"
PARISH_NAME = "Paroki Santa Maria Contoh"
CHURCH_NAME = "Gereja Santa Maria Contoh"
CHAPEL_NAME = "Kapel Santo Petrus Contoh"
HALL_NAME = "Aula Paroki Santa Maria Contoh"
