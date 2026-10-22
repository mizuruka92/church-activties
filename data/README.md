# data/

This folder intentionally holds **no committed data files**.

The synthetic dataset is produced by `scripts/generate_mock_data.py` and is committed once, as SQL:

* `sql/03_load_reference_data.sql` (schema `MASTER_DATA`)
* `sql/04a_load_mass_history.sql` to `sql/04f_load_donations.sql` (schema `DATA_OPERASIONAL`), one file per business area

Keeping a second copy of the same rows as CSV would only create two files that can disagree, so CSV
is an optional export:

```bash
python scripts/generate_mock_data.py --csv-dir data/generated
```

This writes one `SCHEMA.TABLE.csv` file per table into `data/generated/`, which Git ignores. Use it to
inspect the data in a spreadsheet or, if you prefer, to load a table through the Snowsight upload
wizard. The normal setup does not need CSV files, stages or any other cloud service.

Every value is fictional and reproducible (fixed seed and snapshot date, see
`scripts/mockdata/config.py`). Do not place real parishioner data or real operational records in this
folder or anywhere in this repository.
