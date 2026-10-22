"""Tests for the shadow forecast of the weekly offertory (scripts/mockdata/forecast.py).

Standard library only:   python -m unittest tests.test_forecast
The SQL side (views, validation) is tested in test_sql_local.py.
"""

import copy
import sys
import unittest
from datetime import timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from mockdata import build, config, forecast  # noqa: E402

DATA = build.build_all()
FIRST_WEEK, WEEKLY, DAILY, EVENT_WEEK, EFFECTS = forecast.inputs(DATA)
ROWS = DATA["DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN"]
BY_WEEK = {r["AWAL_PEKAN_SASARAN"]: r for r in ROWS}
COMPARED = sorted(w for w in BY_WEEK if w in WEEKLY)


def error(week):
    row = BY_WEEK[week]
    return (WEEKLY[week] - row["JUMLAH_PERKIRAAN"]) / row["JUMLAH_PERKIRAAN"]


def inside(week):
    row = BY_WEEK[week]
    return row["BATAS_BAWAH"] <= WEEKLY[week] <= row["BATAS_ATAS"]


class NoLookAheadTests(unittest.TestCase):
    """A forecast may only use what was known on the day it was made."""

    def weekly_with_future_changed(self, origin, factor):
        changed = dict(WEEKLY)
        for week in changed:
            if week >= origin:
                changed[week] = changed[week] * factor
        return changed

    def test_changing_every_week_from_the_origin_on_changes_nothing(self):
        samples = [BY_WEEK[w] for w in COMPARED[::13]] + [BY_WEEK[w] for w in COMPARED if w in EVENT_WEEK][:6]
        self.assertGreater(len(samples), 20)
        for row in samples:
            target, origin = row["AWAL_PEKAN_SASARAN"], row["TANGGAL_PERKIRAAN"]
            for factor in (0, 0.2, 5):
                changed = self.weekly_with_future_changed(origin, factor)
                again = forecast.forecast_week(target, changed, DAILY, EVENT_WEEK, EFFECTS)
                self.assertEqual(again["point"], row["JUMLAH_PERKIRAAN"], (target, factor))
                self.assertEqual((again["low"], again["high"]), (row["BATAS_BAWAH"], row["BATAS_ATAS"]), (target, factor))

    def test_the_event_log_after_the_origin_is_not_used_either(self):
        for week in [w for w in COMPARED if w in EVENT_WEEK][:6]:
            row = BY_WEEK[week]
            known = {w: e for w, e in EVENT_WEEK.items() if w < row["TANGGAL_PERKIRAAN"]}
            again = forecast.forecast_week(week, WEEKLY, DAILY, known, EFFECTS)
            self.assertEqual(again["point"], row["JUMLAH_PERKIRAAN"], week)

    def test_the_target_week_itself_is_never_a_training_week(self):
        for row in ROWS[::17]:
            origin = row["TANGGAL_PERKIRAAN"]
            self.assertLess(origin, row["AWAL_PEKAN_SASARAN"])
            self.assertEqual((row["AWAL_PEKAN_SASARAN"] - origin).days, forecast.HORIZON_DAYS)

    def test_a_forecast_needs_enough_history(self):
        first = ROWS[0]["AWAL_PEKAN_SASARAN"]
        earlier = first - timedelta(days=7)
        self.assertIsNone(forecast.forecast_week(earlier, WEEKLY, DAILY, EVENT_WEEK, EFFECTS))
        history = [w for w in WEEKLY if w < ROWS[0]["TANGGAL_PERKIRAAN"]]
        self.assertGreaterEqual(len(history), forecast.MIN_HISTORY_WEEKS)
        self.assertIsNone(forecast.forecast_week(earlier, {w: WEEKLY[w] for w in history[:-1]}, DAILY, EVENT_WEEK, EFFECTS))


class AccuracyTests(unittest.TestCase):
    """The forecast is good when nothing unusual happens and wrong where an event struck."""

    def group(self, kind):
        events = [w for w in COMPARED if w in EVENT_WEEK]
        calendar = [w for w in COMPARED if w not in EVENT_WEEK and BY_WEEK[w]["KETERANGAN"] is not None]
        ordinary = [w for w in COMPARED if w not in EVENT_WEEK and BY_WEEK[w]["KETERANGAN"] is None]
        return {"events": events, "calendar": calendar, "ordinary": ordinary}[kind]

    def test_ordinary_weeks_are_forecast_within_ten_percent_on_average(self):
        weeks = self.group("ordinary")
        self.assertGreater(len(weeks), 150)
        mean = sum(abs(error(w)) for w in weeks) / len(weeks)
        self.assertLess(mean, 0.10)
        bias = sum(error(w) for w in weeks) / len(weeks)
        self.assertLess(abs(bias), 0.02, "no systematic over- or under-forecasting on ordinary weeks")

    def test_the_eighty_percent_range_holds_about_four_weeks_in_five(self):
        for kind in ("ordinary", "calendar"):
            weeks = self.group(kind)
            share = sum(inside(w) for w in weeks) / len(weeks)
            self.assertTrue(0.72 <= share <= 0.95, (kind, share))

    def test_feast_weeks_are_forecast_as_well_as_ordinary_weeks(self):
        weeks = self.group("calendar")
        self.assertGreaterEqual(len(weeks), 30)
        mean = sum(abs(error(w)) for w in weeks) / len(weeks)
        self.assertLess(mean, 0.12)
        multipliers = [BY_WEEK[w]["PENYESUAIAN_KALENDER"] for w in weeks]
        self.assertGreater(max(multipliers), 1.3, "Easter should raise the forecast clearly")
        self.assertTrue(all(m > 1 for m in multipliers))

    def test_event_weeks_are_far_below_the_forecast_and_mostly_outside_the_range(self):
        weeks = self.group("events")
        self.assertGreaterEqual(len(weeks), 20)
        mean = sum(abs(error(w)) for w in weeks) / len(weeks)
        self.assertGreater(mean, 0.25)
        outside = [w for w in weeks if not inside(w)]
        self.assertGreater(len(outside), 0.6 * len(weeks))
        self.assertTrue(all(WEEKLY[w] < BY_WEEK[w]["JUMLAH_PERKIRAAN"] for w in outside), "events only ever lower the offertory here")

    def test_the_big_events_miss_the_most(self):
        def event_bias(event_id):
            weeks = [w for w in COMPARED if EVENT_WEEK.get(w) == event_id]
            forecast_total = sum(BY_WEEK[w]["JUMLAH_PERKIRAAN"] for w in weeks)
            return (sum(WEEKLY[w] for w in weeks) - forecast_total) / forecast_total

        self.assertLess(event_bias("PRS-08"), -0.40)  # the volcanic ash of 2025
        self.assertLess(event_bias("PRS-06"), -0.35)  # the thick haze of 2023
        self.assertGreater(event_bias("PRS-05"), -0.20)  # a one-day power cut barely shows

    def test_forecasts_recover_after_an_event_because_disturbed_weeks_are_left_out_of_training(self):
        ash = [w for w in COMPARED if EVENT_WEEK.get(w) == "PRS-08"]
        after = [w for w in COMPARED if w > max(ash) + timedelta(days=84) and w < max(ash) + timedelta(days=200)
                 and w not in EVENT_WEEK and BY_WEEK[w]["KETERANGAN"] is None]
        self.assertGreaterEqual(len(after), 10)
        mean = sum(error(w) for w in after) / len(after)
        self.assertLess(abs(mean), 0.06, "a past disaster must not drag later forecasts down")

    def test_without_that_exclusion_later_forecasts_would_be_biased(self):
        """Mutation: train on the disturbed weeks too and the bias after the event appears."""
        ash = [w for w in COMPARED if EVENT_WEEK.get(w) == "PRS-08"]
        after = [w for w in COMPARED if max(ash) + timedelta(days=42) < w < max(ash) + timedelta(days=150)
                 and w not in EVENT_WEEK and BY_WEEK[w]["KETERANGAN"] is None]
        errors = []
        for week in after:
            result = forecast.forecast_week(week, WEEKLY, DAILY, {}, EFFECTS)  # nothing is excluded
            if result is not None:
                errors.append((WEEKLY[week] - result["point"]) / result["point"])
        self.assertGreater(len(errors), 8)
        self.assertGreater(sum(errors) / len(errors), 0.08, "ignoring the event log makes the forecast too low afterwards")


class StoredRowsTests(unittest.TestCase):
    def test_one_row_per_week_without_gaps_and_ids_in_order(self):
        weeks = [r["AWAL_PEKAN_SASARAN"] for r in ROWS]
        self.assertEqual(weeks, sorted(set(weeks)))
        self.assertTrue(all((b - a).days == 7 for a, b in zip(weeks, weeks[1:])))
        self.assertEqual([r["ID_PERKIRAAN"] for r in ROWS], [f"PKR-{i:04d}" for i in range(1, len(ROWS) + 1)])
        self.assertTrue(all(w.weekday() == 0 for w in weeks))

    def test_forecasts_run_from_august_2021_to_the_weeks_ahead_of_the_snapshot(self):
        self.assertEqual(ROWS[0]["AWAL_PEKAN_SASARAN"].isoformat(), "2021-08-02")
        self.assertTrue(all(r["TANGGAL_PERKIRAAN"] <= config.AS_OF for r in ROWS))
        ahead = [r for r in ROWS if r["AWAL_PEKAN_SASARAN"] + timedelta(days=6) > config.AS_OF]
        self.assertEqual(len(ahead), 5, "the week in progress and four weeks ahead")
        self.assertTrue(all(r["AWAL_PEKAN_SASARAN"] > config.AS_OF - timedelta(days=7) for r in ahead))

    def test_ranges_are_ordered_and_rounded_to_thousands(self):
        for r in ROWS:
            self.assertLessEqual(r["BATAS_BAWAH"], r["JUMLAH_PERKIRAAN"])
            self.assertLessEqual(r["JUMLAH_PERKIRAAN"], r["BATAS_ATAS"])
            for column in ("JUMLAH_PERKIRAAN", "BATAS_BAWAH", "BATAS_ATAS"):
                self.assertEqual(r[column] % forecast.ROUND_TO, 0)
            width = (r["BATAS_ATAS"] - r["BATAS_BAWAH"]) / r["JUMLAH_PERKIRAAN"]
            self.assertTrue(0.15 < width < 0.9, (r["ID_PERKIRAAN"], width))

    def test_calendar_notes_name_the_feast_in_indonesian(self):
        notes = [r["KETERANGAN"] for r in ROWS if r["KETERANGAN"]]
        self.assertTrue(any("Paskah" in n for n in notes))
        self.assertTrue(any("Misi Sedunia" in n for n in notes))
        for r in ROWS:
            self.assertEqual(r["KETERANGAN"] is None, r["PENYESUAIAN_KALENDER"] == 1)

    def test_the_model_row_matches_the_constants_used(self):
        (model,) = DATA["MASTER_DATA.REFERENSI_MODEL_PERKIRAAN"]
        self.assertEqual(model["HORIZON_HARI"], forecast.HORIZON_DAYS)
        self.assertEqual(model["JENDELA_PELATIHAN_MINGGU"], forecast.TRAINING_WEEKS)
        self.assertEqual(model["MINIMAL_RIWAYAT_MINGGU"], forecast.MIN_HISTORY_WEEKS)
        self.assertEqual({r["ID_MODEL"] for r in ROWS}, {model["ID_MODEL"]})

    def test_the_output_is_reproducible(self):
        again = forecast.build(copy.deepcopy(DATA))
        self.assertEqual(again["DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN"], ROWS)
        self.assertEqual(again["MASTER_DATA.REFERENSI_MODEL_PERKIRAAN"], DATA["MASTER_DATA.REFERENSI_MODEL_PERKIRAAN"])

    def test_the_demo_still_contains_the_story(self):
        """The scenario guard in checks.py must keep failing if the story is lost."""
        from mockdata import checks
        broken = copy.deepcopy(DATA)
        for r in broken["DATA_OPERASIONAL.PERKIRAAN_KOLEKTE_MINGGUAN"]:
            r["JUMLAH_PERKIRAAN"] = r["JUMLAH_PERKIRAAN"] // 3  # a forecast that is far too low everywhere
            r["BATAS_BAWAH"] = r["JUMLAH_PERKIRAAN"] // 2
            r["BATAS_ATAS"] = r["JUMLAH_PERKIRAAN"] * 2
        gaps = checks.check_scenarios(broken)
        self.assertTrue(any("ordinary weeks" in g or "falls outside" in g or "fall outside" in g or "no longer" in g for g in gaps), gaps)
        self.assertEqual(checks.check_scenarios(DATA), [])


if __name__ == "__main__":
    unittest.main()
