"""Domain 4.3: fictional parishioner database (BIDUK simulation).

Households and individuals are separate entities. Individual-to-household and
household-to-community links are effective-dated assignments. Only a birth YEAR
is stored. No address, phone number or identity number exists in the model.
All names are random combinations of common given names and surnames.
"""

from datetime import date, timedelta

from . import config, util
from .reference import (
    ACTIVE_LINGKUNGAN,
    KLS_SANGAT_TERBATAS,
    KLS_TERBATAS,
    LINGKUNGAN_TO_WILAYAH,
    MERGE_END,
    MERGED_INTO,
    MERGED_LINGKUNGAN,
)
from .rng import Rng

SCHEMA = "DATA_OPERASIONAL"

MALE_BAPTISM = ["Yohanes", "Antonius", "Fransiskus", "Markus", "Petrus", "Paulus", "Andreas", "Yosef", "Ignatius",
                "Benediktus", "Stefanus", "Thomas", "Lukas", "Matius", "Albertus", "Aloysius", "Bernardus",
                "Gregorius", "Emanuel", "Vincentius", "Dominikus", "Robertus", "Hieronimus", "Kristoforus"]
MALE_GIVEN = ["Adi", "Budi", "Dwi", "Eko", "Hendra", "Joko", "Agus", "Bayu", "Rudi", "Wahyu", "Bambang", "Dedi",
              "Ferry", "Hadi", "Imam", "Krisna", "Lukito", "Nugroho", "Putra", "Rizki", "Surya", "Teguh", "Yudha",
              "Aryo", "Cahyo", "Danu", "Galih", "Indra", "Kurnia", "Raka"]
FEMALE_BAPTISM = ["Maria", "Katarina", "Theresia", "Agnes", "Elisabeth", "Veronika", "Margareta", "Monika", "Cecilia",
                  "Clara", "Lusia", "Yohana", "Anastasia", "Bernadeta", "Dominika", "Fransiska", "Helena",
                  "Ignatia", "Natalia", "Regina", "Angela", "Benedikta", "Yustina", "Rosalia"]
FEMALE_GIVEN = ["Sri", "Dewi", "Ayu", "Putri", "Rina", "Wulan", "Indah", "Lestari", "Sari", "Ratna", "Fitri", "Yuni",
                "Endang", "Tuti", "Rahayu", "Melati", "Citra", "Dian", "Ening", "Gita", "Hesti", "Intan",
                "Kartika", "Mira", "Nilam", "Utami"]
SURNAMES = ["Santoso", "Wijaya", "Hartono", "Susanto", "Pratama", "Kusuma", "Setiawan", "Wibowo", "Gunawan", "Halim",
            "Utomo", "Prasetyo", "Saputra", "Hidayat", "Nugraha", "Purnomo", "Rahardjo", "Budiman", "Sutanto",
            "Handoko", "Simanjuntak", "Sihombing", "Nainggolan", "Siregar", "Panjaitan", "Hutabarat", "Situmorang",
            "Tampubolon", "Manurung", "Lalamentik", "Da Costa", "Ndoen", "Kaunang", "Mamengko", "Rumbayan", "Tallo",
            "Lobo", "Seran", "Bria", "Lewar", "Koten", "Kleden", "Tanujaya", "Gunadi", "Hermawan", "Tjandra",
            "Lukman", "Kurniawan"]

HOUSEHOLD_TYPES = [
    ("pasangan_dan_anak", 50),
    ("pasangan", 14),
    ("orang_tua_tunggal", 10),
    ("sendiri", 10),
    ("pasangan_lansia", 10),
    ("tiga_generasi", 6),
]

_SPLIT_START, _SPLIT_END = date(2024, 1, 1), date(2026, 6, 30)


class _Generator:
    def __init__(self):
        self.rng = Rng(config.SEED, "parish")
        self.families = []
        self.persons = []
        self.family_links = []  # PENUGASAN_KELUARGA
        self.community_links = []  # PENUGASAN_LINGKUNGAN
        self._names = set()
        self.merged_family_ids = set()
        self.family_of = {}  # person id -> first family id
        self.members = {}  # family id -> list of person ids

    # --- helpers -------------------------------------------------------------

    def _date_between(self, start, end):
        if end <= start:
            return start
        return start + timedelta(days=self.rng.randint(0, (end - start).days))

    def _full_name(self, gender, surname):
        rng = self.rng
        baptism = MALE_BAPTISM if gender == "Laki-laki" else FEMALE_BAPTISM
        given = MALE_GIVEN if gender == "Laki-laki" else FEMALE_GIVEN
        for _ in range(50):
            pattern = rng.weighted([(0, 60), (1, 25), (2, 15)])
            if pattern == 0:
                name = f"{rng.choice(baptism)} {rng.choice(given)} {surname}"
            elif pattern == 1:
                name = f"{rng.choice(given)} {surname}"
            else:
                name = f"{rng.choice(baptism)} {surname}"
            if name not in self._names:
                self._names.add(name)
                return name
        raise RuntimeError("could not find an unused fictional name")

    def _new_family(self, name, registered):
        family_id = f"KEL-{util.pad(len(self.families) + 1, 4)}"
        self.families.append(
            {
                "ID_KELUARGA": family_id,
                "NAMA_KELUARGA_FIKTIF": name,
                "STATUS_KELUARGA": "Aktif",
                "TANGGAL_TERDAFTAR": registered,
                "ID_KLASIFIKASI_DATA": KLS_TERBATAS,
            }
        )
        self.members[family_id] = []
        return family_id

    def _new_person(self, gender, birth_year, surname, registered, family_id, role):
        person_id = f"UMT-{util.pad(len(self.persons) + 1, 5)}"
        registered = max(registered, date(birth_year, 6, 30))
        self.persons.append(
            {
                "ID_UMAT": person_id,
                "NAMA_FIKTIF": self._full_name(gender, surname),
                "JENIS_KELAMIN": gender,
                "TAHUN_LAHIR": birth_year,
                "STATUS_KEANGGOTAAN": "Aktif",
                "TANGGAL_TERDAFTAR": registered,
                "ID_KLASIFIKASI_DATA": KLS_SANGAT_TERBATAS if config.AS_OF.year - birth_year < 17 else KLS_TERBATAS,
            }
        )
        self._link_family(person_id, family_id, role, registered)
        self.family_of[person_id] = family_id
        return person_id

    def _link_family(self, person_id, family_id, role, start):
        self.family_links.append(
            {
                "ID_PENUGASAN_KELUARGA": f"PKL-{util.pad(len(self.family_links) + 1, 5)}",
                "ID_UMAT": person_id,
                "ID_KELUARGA": family_id,
                "PERAN_DALAM_KELUARGA": role,
                "TANGGAL_MULAI_BERLAKU": start,
                "TANGGAL_AKHIR_BERLAKU": None,
            }
        )
        self.members[family_id].append(person_id)

    def _link_community(self, family_id, lingkungan_id, start, end=None):
        self.community_links.append(
            {
                "ID_PENUGASAN_LINGKUNGAN": f"PLG-{util.pad(len(self.community_links) + 1, 4)}",
                "ID_KELUARGA": family_id,
                "ID_LINGKUNGAN": lingkungan_id,
                "TANGGAL_MULAI_BERLAKU": start,
                "TANGGAL_AKHIR_BERLAKU": end,
            }
        )

    def _person(self, person_id):
        return self.persons[int(person_id.split("-")[1]) - 1]

    def _family(self, family_id):
        return self.families[int(family_id.split("-")[1]) - 1]

    def _open_family_link(self, person_id):
        for link in self.family_links:
            if link["ID_UMAT"] == person_id and link["TANGGAL_AKHIR_BERLAKU"] is None:
                return link
        raise KeyError(person_id)

    def _open_community_link(self, family_id):
        for link in self.community_links:
            if link["ID_KELUARGA"] == family_id and link["TANGGAL_AKHIR_BERLAKU"] is None:
                return link
        raise KeyError(family_id)

    # --- households ----------------------------------------------------------

    def _make_household(self, lingkungan_id, force_old_registration):
        rng = self.rng
        kind = rng.weighted(HOUSEHOLD_TYPES)
        last_registration = date(2023, 12, 31) if force_old_registration else date(2025, 6, 30)
        registered = self._date_between(date(2008, 1, 1), last_registration)
        surname = rng.choice(SURNAMES)

        female_head_probability = 0.7 if kind == "orang_tua_tunggal" else 0.15
        male_head = not rng.chance(female_head_probability)
        head_gender = "Laki-laki" if male_head else "Perempuan"
        spouse_gender = "Perempuan" if male_head else "Laki-laki"
        if kind == "pasangan_lansia":
            head_birth = rng.randint(1941, 1960)
        elif kind == "sendiri":
            head_birth = rng.randint(1955, 2000)
        elif kind == "orang_tua_tunggal":
            head_birth = rng.randint(1965, 1990)
        else:
            head_birth = rng.randint(1968, 1992)

        # Create the head first so that the family can carry the head's name.
        family_id = self._new_family("", registered)
        head_id = self._new_person(head_gender, head_birth, surname, registered, family_id, "Kepala Keluarga")
        self._family(family_id)["NAMA_KELUARGA_FIKTIF"] = "Keluarga " + self._person(head_id)["NAMA_FIKTIF"]

        if kind in ("pasangan_dan_anak", "pasangan", "pasangan_lansia", "tiga_generasi"):
            spouse_surname = surname if rng.chance(0.6) else rng.choice(SURNAMES)
            spouse_birth = head_birth + rng.randint(-4, 3)
            self._new_person(spouse_gender, spouse_birth, spouse_surname, registered, family_id, "Pasangan")
        if kind in ("pasangan_dan_anak", "orang_tua_tunggal", "tiga_generasi"):
            for _ in range(rng.randint(1, 3) if kind != "orang_tua_tunggal" else rng.randint(1, 2)):
                low = max(head_birth + 22, 1996)
                child_birth = rng.randint(low, 2025) if low <= 2025 else 2025
                self._new_person(rng.choice(["Laki-laki", "Perempuan"]), child_birth, surname, registered,
                                 family_id, "Anak")
        if kind == "tiga_generasi":
            elder_gender = rng.choice(["Laki-laki", "Perempuan"])
            self._new_person(elder_gender, head_birth - rng.randint(24, 30), surname, registered,
                             family_id, "Anggota Lain")
        self._link_community(family_id, lingkungan_id, registered)
        return family_id

    # --- life events -----------------------------------------------------------

    def _apply_merge(self, family_ids):
        """These households first belonged to the community that was merged into
        MERGED_INTO at the end of 2024."""
        for family_id in family_ids:
            link = self._open_community_link(family_id)
            start = link["TANGGAL_MULAI_BERLAKU"]
            link["ID_LINGKUNGAN"] = MERGED_LINGKUNGAN
            link["TANGGAL_AKHIR_BERLAKU"] = MERGE_END
            self._link_community(family_id, MERGED_INTO, MERGE_END + timedelta(days=1))
            assert start <= MERGE_END
            self.merged_family_ids.add(family_id)

    def _free_families(self, taken):
        return [f["ID_KELUARGA"] for f in self.families
                if f["ID_KELUARGA"] not in taken and f["ID_KELUARGA"] not in self.merged_family_ids]

    def _apply_events(self):
        rng = self.rng
        touched = set()

        # Whole households that left the parish.
        for family_id in rng.sample(self._free_families(touched), 6):
            earliest = max(l["TANGGAL_MULAI_BERLAKU"] for l in self.family_links if l["ID_KELUARGA"] == family_id)
            moved = self._date_between(max(date(2025, 3, 1), earliest + timedelta(days=1)), date(2026, 8, 31))
            touched.add(family_id)
            self._family(family_id)["STATUS_KELUARGA"] = "Pindah Paroki"
            for person_id in self.members[family_id]:
                self._person(person_id)["STATUS_KEANGGOTAAN"] = "Pindah Paroki"
                self._open_family_link(person_id)["TANGGAL_AKHIR_BERLAKU"] = moved
            self._open_community_link(family_id)["TANGGAL_AKHIR_BERLAKU"] = moved

        # Households that stayed in the parish but changed community.
        for family_id in rng.sample(self._free_families(touched), 4):
            link = self._open_community_link(family_id)
            moved = self._date_between(date(2025, 2, 1), date(2026, 6, 30))
            if moved <= link["TANGGAL_MULAI_BERLAKU"]:
                continue
            others = [l for l in ACTIVE_LINGKUNGAN if l != link["ID_LINGKUNGAN"]]
            touched.add(family_id)
            link["TANGGAL_AKHIR_BERLAKU"] = moved - timedelta(days=1)
            self._link_community(family_id, rng.choice(others), moved)

        # Deaths among the oldest members.
        elderly = [p["ID_UMAT"] for p in self.persons
                   if p["TAHUN_LAHIR"] <= 1950 and p["STATUS_KEANGGOTAAN"] == "Aktif"
                   and self.family_of[p["ID_UMAT"]] not in self.merged_family_ids
                   and self._family(self.family_of[p["ID_UMAT"]])["STATUS_KELUARGA"] == "Aktif"]
        for person_id in rng.sample(elderly, 5):
            person = self._person(person_id)
            link = self._open_family_link(person_id)
            died = self._date_between(max(date(2024, 6, 1), link["TANGGAL_MULAI_BERLAKU"]), date(2026, 9, 15))
            person["STATUS_KEANGGOTAAN"] = "Meninggal Dunia"
            link["TANGGAL_AKHIR_BERLAKU"] = died
            family_id = self.family_of[person_id]
            if all(self._person(m)["STATUS_KEANGGOTAAN"] != "Aktif" for m in self.members[family_id]):
                closing = max(l["TANGGAL_AKHIR_BERLAKU"] for l in self.family_links
                              if l["ID_KELUARGA"] == family_id and l["TANGGAL_AKHIR_BERLAKU"] is not None)
                self._family(family_id)["STATUS_KELUARGA"] = "Tidak Aktif"
                self._open_community_link(family_id)["TANGGAL_AKHIR_BERLAKU"] = closing

        # Adult children: some become inactive, some leave the parish, some start their own household.
        adults = [p["ID_UMAT"] for p in self.persons
                  if p["TAHUN_LAHIR"] <= 2001 and p["STATUS_KEANGGOTAAN"] == "Aktif"
                  and self._open_family_link(p["ID_UMAT"])["PERAN_DALAM_KELUARGA"] == "Anak"]
        chosen = rng.sample(adults, min(13, len(adults)))
        for person_id in chosen[:4]:
            self._person(person_id)["STATUS_KEANGGOTAAN"] = "Tidak Aktif"
        for person_id in chosen[4:7]:
            link = self._open_family_link(person_id)
            self._person(person_id)["STATUS_KEANGGOTAAN"] = "Pindah Paroki"
            link["TANGGAL_AKHIR_BERLAKU"] = self._date_between(
                max(date(2025, 1, 1), link["TANGGAL_MULAI_BERLAKU"]), date(2026, 8, 31))
        for person_id in chosen[7:]:
            link = self._open_family_link(person_id)
            old_family = link["ID_KELUARGA"]
            split = self._date_between(max(_SPLIT_START, link["TANGGAL_MULAI_BERLAKU"] + timedelta(days=1)), _SPLIT_END)
            person = self._person(person_id)
            new_family = self._new_family("Keluarga " + person["NAMA_FIKTIF"], split)
            link["TANGGAL_AKHIR_BERLAKU"] = split - timedelta(days=1)
            self._link_family(person_id, new_family, "Kepala Keluarga", split)
            self._link_community(new_family, self._open_community_link(old_family)["ID_LINGKUNGAN"], split)

    def build(self):
        rng = self.rng
        merged_candidates = []
        for lingkungan_id in ACTIVE_LINGKUNGAN:
            count = rng.randint(9, 15)
            for index in range(count):
                old_registration = lingkungan_id == MERGED_INTO and index < 6
                family_id = self._make_household(lingkungan_id, old_registration)
                if old_registration:
                    merged_candidates.append(family_id)
        self._apply_merge(merged_candidates)
        self._apply_events()
        return {
            f"{SCHEMA}.KELUARGA": self.families,
            f"{SCHEMA}.UMAT": self.persons,
            f"{SCHEMA}.PENUGASAN_KELUARGA": self.family_links,
            f"{SCHEMA}.PENUGASAN_LINGKUNGAN": self.community_links,
        }


def build():
    return _Generator().build()


def active_households_by_region(data, on_date):
    """Number of households assigned to a community of each region on a date."""
    counts = {}
    for link in data[f"{SCHEMA}.PENUGASAN_LINGKUNGAN"]:
        end = link["TANGGAL_AKHIR_BERLAKU"]
        if link["TANGGAL_MULAI_BERLAKU"] <= on_date and (end is None or on_date <= end):
            region = LINGKUNGAN_TO_WILAYAH[link["ID_LINGKUNGAN"]]
            counts[region] = counts.get(region, 0) + 1
    return counts
