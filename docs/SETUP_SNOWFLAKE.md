# Setting up the demo in Snowflake

This guide expands the quick start in the [README](../README.md). If you have never used Snowflake, start with the
[starter guide](STARTER_GUIDE.md) instead: it also covers creating the account, connecting GitHub and creating the dashboard. Nothing in this repository connects
to Snowflake for you: you run the SQL files yourself, in Snowsight or from a command line.

> **Verification status.** The SQL was tested locally (DuckDB as a stand-in engine and a syntax lint),
> but it has **not** been executed in Snowflake yet. The first real run is the real test. See
> [Troubleshooting](#troubleshooting) and the checklist in the README.

## 1. Four words you need

| Word | Meaning here |
|---|---|
| **Role** | Decides what you may do. Creating a database needs a role such as `SYSADMIN` (or `ACCOUNTADMIN`, which a trial account gives you at first). |
| **Warehouse** | The compute that runs your SQL. It must be selected and running. The smallest size is enough. This project does not assume a warehouse name. |
| **Database and schema** | Folders for tables. This demo uses database `PUSAT_INFORMASI_PAROKI` with schemas `MASTER_DATA`, `DATA_OPERASIONAL` and `ANALISIS`. |
| **Worksheet** | The Snowsight page where you paste and run SQL. Snowsight also has a newer "Workspaces" experience; both can run these files. |

## 2. Run the setup in Snowsight

### Option A: everything at once

1. Open [`sql/full_setup.sql`](../sql/full_setup.sql) in GitHub and copy its raw text. Alternatively download the repository as a ZIP and open the file locally.
2. In Snowsight create a new SQL worksheet and paste the whole text.
3. Choose a role and a warehouse in the worksheet header.
4. Use **Run All** (the arrow beside the Run button). Snowsight runs the statements in order. When it ends, it shows the result of the **last** statement, which is the validation table.

The file is about 1.8 MB. If pasting or running it is slow, or Snowsight refuses it, use option B: the largest step file is about 420 KB. Whether Snowsight accepts the all-in-one file in a single paste has not been verified.

### Option B: one file at a time

Create one worksheet and, for each file below, replace its content and **Run All**. Every file
selects the database itself, so you can also use one worksheet per file.

| Step | File | Check afterwards |
|---|---|---|
| 0 | `sql/00_setup.sql` | `ACTIVE_ROLE` and `ACTIVE_WAREHOUSE` are filled in. If the warehouse is empty, select one. |
| 1 | `sql/01_create_schemas.sql` | `SHOW SCHEMAS IN DATABASE PUSAT_INFORMASI_PAROKI;` lists `MASTER_DATA`, `DATA_OPERASIONAL`, `ANALISIS` (plus Snowflake's own `PUBLIC` and `INFORMATION_SCHEMA`). |
| 2 | `sql/02_create_tables.sql` | `SHOW TABLES IN SCHEMA PUSAT_INFORMASI_PAROKI.MASTER_DATA;` lists 18 tables and the same command for `DATA_OPERASIONAL` lists 20. |
| 3 | `sql/03_load_reference_data.sql` | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.MASTER_DATA.MASTER_WILAYAH;` returns 6. |
| 4a | `sql/04a_load_mass_history.sql` | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.PERISTIWA_LUAR_BIASA;` returns 10. |
| 4b | `sql/04b_load_offertory.sql` | Needs 4a. `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.PENERIMAAN_KOLEKTE;` returns the number listed in the dictionary. |
| 4c | `sql/04c_load_parishioners.sql` | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.UMAT;` returns 653. |
| 4d | `sql/04d_load_surveys.sql` | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.JAWABAN_SURVEI;` returns the number listed in the dictionary. |
| 4e | `sql/04e_load_plans_and_events.sql` | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.RENCANA_KEGIATAN;` returns 179. |
| 4f | `sql/04f_load_donations.sql` | Needs 4c and 4e. `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.DATA_OPERASIONAL.KAMPANYE_SUMBANGAN;` returns 14. |
| 5 | `sql/05_create_views.sql` | `SHOW VIEWS IN SCHEMA PUSAT_INFORMASI_PAROKI.ANALISIS;` lists 22 views. |
| 6 | `sql/06_validate_data.sql` | The first two rows say `Checks with result FAIL = 0` and `Checks with result WARN = 1`, both `PASS`. |

The `STRUCTURE` rows of the validation compare every table's row count with the bundled data
(`FOUND_COUNT` against `EXPECTED_COUNT`), so you do not need to remember the numbers. The full list
of expected row counts is the summary table in [DATA_DICTIONARY.md](DATA_DICTIONARY.md).

Steps 1 to 6 can be repeated at any time. Step 6 only reads data and can be run on its own whenever you want to re-check.

## 3. Run the setup from a command line (optional)

You only need this if you prefer a terminal. The commands below were **not** run against a real
account while building this repository, so check them against `snow --help` or `snowsql --help` for
your installed version.

Both tools read connection details (account, user, authentication, default role and warehouse)
from a configuration file **outside** this repository. Create a named connection once (for the
Snowflake CLI: `snow connection add`) and set the role and warehouse in it. Never put passwords,
tokens or key files inside the repository.

**Snowflake CLI** (`snow`), one file per call, stopping at the first error:

```bash
for f in sql/01_create_schemas.sql sql/02_create_tables.sql sql/03_load_reference_data.sql \
         sql/04a_load_mass_history.sql sql/04b_load_offertory.sql sql/04c_load_parishioners.sql \
         sql/04d_load_surveys.sql sql/04e_load_plans_and_events.sql sql/04f_load_donations.sql \
         sql/05_create_views.sql sql/06_validate_data.sql; do
  snow sql --connection my_demo -f "$f" || break
done
```

Or the single all-in-one file: `snow sql --connection my_demo -f sql/full_setup.sql`

**SnowSQL**: `snowsql -c my_demo -f sql/full_setup.sql`

Replace `my_demo` with the name of your connection. Steps 0 and 99 are deliberately not in the loop.

## 4. Git, Snowflake and executing SQL are three different things

It is easy to mix these up, so here is the distinction used in this project.

1. **Storing SQL in Git.** The `.sql` files live in this repository so they are versioned, reviewed and reproducible. Git on its own runs nothing. Having the files on GitHub does not create a single object in Snowflake.
2. **Letting Snowflake read a Git repository.** Snowflake can mirror a repository as a read-only *Git repository object* (created with an API integration and `CREATE GIT REPOSITORY`, then refreshed with `ALTER GIT REPOSITORY ... FETCH`). The files then become visible under a stage-like path such as `@my_repo/branches/main/sql/`. Even then, connecting the repository does not run any file automatically.
3. **Executing SQL.** Something must run the statements: you in Snowsight (Run All), a command-line tool (`snow sql -f`, `snowsql -f`), or, once a Git repository object exists, `EXECUTE IMMEDIATE FROM @my_repo/branches/main/sql/02_create_tables.sql;` for each file you want to run.

For this demo the simplest reliable workflow is: develop locally, commit to Git, paste or run the
files in Snowsight, and read the validation table. Git integration inside Snowflake is optional and
is **not** a prerequisite. It adds an API integration, network and privilege setup that a first
demo does not need. The Git-to-Snowflake route is not tested here.

## 5. Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| "No active warehouse selected" | Pick a warehouse in the worksheet header (or run the optional block in `00_setup.sql`). |
| "Insufficient privileges" on `CREATE DATABASE` | Switch to a role that can create databases, for example `SYSADMIN` or `ACCOUNTADMIN`. |
| "Database ... does not exist or not authorized" | Run step 1 first, or use the role that created the database. |
| "Object ... does not exist" for a table | A previous step was skipped. Run the steps in order. |
| A statement fails with a syntax error | Note the file and statement and report it. The generated files should never be edited by hand. See the verification status above: this SQL has not run in Snowflake yet. |
| The validation shows `FAIL` rows | Filter `RESULT = 'FAIL'`. Row-count or `VIEWS` failures mean a step did not finish. Re-run steps 3, 4a to 4f and 5. They are safe to repeat. |
| Row counts show `WARN` (count differs from the bundled data) | The data was only partly loaded or was changed after loading. Re-run steps 3 and 4a to 4f to restore the bundled rows. |
| `Report participants differ from the event` shows `WARN` | Expected. It is the one deliberate inconsistency. |
| The validation statement runs for a long time | It is one query with about 300 branches. Give it a moment. A larger warehouse is not needed. |
| You edited `02_create_tables.sql` and nothing changed | `CREATE TABLE IF NOT EXISTS` never alters an existing table. Reset the demo (below) and run the setup again, or write an `ALTER TABLE`. |
| A column or table named in the views or loads "does not exist" after pulling a newer version | The tables changed (event log, campaigns, household gifts, economic profile) and the database was created by an older version. Reset the demo (below) and run the setup again. |
| A view fails with an unknown function | The new views use `MEDIAN`, `CORR`, `REGR_SLOPE`, `REGR_INTERCEPT`, `REGR_R2` and `DATEADD`. These are standard Snowflake functions but were only tested on the DuckDB stand-in. Report the view name and the message. |
| A 4x file fails with a foreign-key or missing-parent style message | Run the files in order: 4b needs 4a, and 4f needs 4c and 4e. Foreign keys are not enforced, so more likely a validation check reports the problem. |

## 6. Resetting the demo (destructive)

[`sql/99_reset_demo.sql`](../sql/99_reset_demo.sql) can empty the tables, drop the three schemas, or
drop the database. All statements are commented out so that running the file by accident does nothing.
Open it, read the three options, remove the leading `-- ` from the one you want, and run only
those lines. It names only the demo objects. After a reset, run `sql/full_setup.sql` again.

## 7. Who may see what

The model separates storage from presentation: `MASTER_DATA` and `DATA_OPERASIONAL` hold
detail (including fictional parishioner records classified *Terbatas*), while `ANALISIS` holds
only aggregates. Dashboards and other consumers should be given access to `ANALISIS` only. Advanced
access control is Phase 3 and is not set up here. See *Data classification* in
[DATA_MODEL.md](DATA_MODEL.md).
