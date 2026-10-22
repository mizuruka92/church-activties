"""Small shared helpers (Indonesian calendar names, rounding, date formatting)."""

import calendar
from datetime import date, timedelta

MONTHS_ID = [
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember",
]
# Index = date.weekday(): Monday is 0.
DAYS_ID = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]


def date_id(value):
    """5 April 2026"""
    return f"{value.day} {MONTHS_ID[value.month - 1]} {value.year}"


def day_name(value):
    return DAYS_ID[value.weekday()]


def month_end(year, month):
    return date(year, month, calendar.monthrange(year, month)[1])


def daterange(start, end):
    """Every date from start to end, both included."""
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def round_to(value, step):
    """Round half up to a multiple of step (used for rupiah amounts)."""
    return int((value + step / 2) // step) * step


def pad(number, width):
    return str(number).zfill(width)
