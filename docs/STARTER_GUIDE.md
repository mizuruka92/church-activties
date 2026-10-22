# Starter guide: from nothing to a running dashboard

This guide is for someone who has **never used Snowflake**. It takes you from "I have no account" to
"the Pusat Informasi Paroki dashboard is running", one small step at a time. You do not need to know SQL or
Python. You will copy and paste.

> **Everything in the demo is fictional.** No real parish data is involved, and you must not load any.
>
> **Read this once:** nothing in this repository has been run inside a real Snowflake account yet, and the
> screens of Snowflake change from release to release. Where this guide describes a Snowflake screen or command,
> it was checked against Snowflake's published documentation, not against your account. Part 12 lists exactly what
> has and has not been tested. If a step fails, part 11 tells you what to do, and it helps a lot if you report
> the exact message so the files can be fixed.

## 0. What you will have at the end

1. A Snowflake account (a free trial is enough).
2. A database called `PUSAT_INFORMASI_PAROKI` with 38 tables of simulated parish data and 22 summary views.
3. A dashboard in Bahasa Indonesia, running inside Snowflake, that shows income versus spending, offertory and
   attendance, unforeseen events, Lent and Advent donations versus Easter and Christmas costs, plans and budgets,
   and survey results.

There are two ways to get the SQL files into Snowflake. Choose one in part 5 and part 6:

| | Path A: copy and paste | Path B: connect GitHub |
|---|---|---|
| Effort at first | Small | Medium (about 10 extra minutes) |
| Moving parts | Your browser only | A token (for private repositories), an "API integration", a "Git repository" object |
| Updating later | Paste the changed files again | One command fetches the newest files |
| Best for | The first successful run, a one-off demo | Keeping the demo up to date, a team |

If you are unsure, **do Path A first**. You can add Path B later.

Time needed: about 45 minutes the first time. Cost: nothing, if you use the free trial and follow part 9.

## 1. Words you will meet

| Word | What it means here |
|---|---|
| **Snowflake** | An online data platform. You use it through a website. |
| **Account** | Your own private Snowflake space. It has a web address, a user name and a password. |
| **Trial** | A free period for a new account. At the time of writing Snowflake describes it as 30 days or about 400 US dollars of usage, whichever ends first, with no credit card needed. Check the sign-up page for today's terms. |
| **Snowsight** | The Snowflake website you work in. |
| **Role** | A set of permissions. `ACCOUNTADMIN` can do everything and is what a new trial account starts with. |
| **Warehouse** | The computer that runs your queries. It uses trial credit only while it is running. A new account usually has one called `COMPUTE_WH`. |
| **Database, schema** | Folders for data. This demo uses the database `PUSAT_INFORMASI_PAROKI` with the schemas `MASTER_DATA`, `DATA_OPERASIONAL` and `ANALISIS`. |
| **Worksheet** | A page in Snowsight where you paste and run SQL. |
| **SQL** | The language that Snowflake understands. The `.sql` files in the `sql/` folder are the instructions. |
| **View** | A saved question about the data. The dashboard reads only the views in `ANALISIS`. |
| **Streamlit** | A tool that turns a Python file into a web dashboard. "Streamlit in Snowflake" runs it inside your account. |
| **GitHub repository** | The online folder where this project's files live: `https://github.com/mizuruka92/church-activties`. |
| **Branch** | A version line in a repository. The guide uses `main`. |
| **Token (personal access token)** | A password-like text that lets Snowflake read a private GitHub repository. Needed only for private repositories. |

## 2. Before you start

* A web browser and an email address you can open.
* About 45 minutes.
* The repository must contain the newest files on the branch `main`. At the time this guide was written, the
  latest work (the five-year data, the analysis views and the dashboard) was on a working branch and had to be
  merged into `main` first. Open `https://github.com/mizuruka92/church-activties/tree/main/app` in your browser. If
  you see a file `streamlit_app.py`, you are ready. If not, ask the person who looks after the repository to merge
  the latest work into `main`.
* You do **not** need to install anything for Path A or Path B. Python is only needed for the optional part 10.

Is the repository public? Open the address above in a private browser window. If you can see the files without
signing in to GitHub, it is public. This matters only for Path B.

## 3. Create a Snowflake trial account

1. Open `https://signup.snowflake.com` and fill in the form. A personal or organisation email works.
2. **Edition:** Standard is enough for this demo. **Cloud and region:** choose the region nearest to you. Reportedly
   these choices cannot be changed later for that account, so take a moment here.
3. Confirm your email address using the message Snowflake sends you.
4. Choose a user name and a password. Store them in a password manager. **Never put them in the repository, in a
   chat, or in an issue.**
5. Snowflake requires multi-factor authentication for people who sign in with a password, so you will be asked to set
   it up (usually with an authenticator app on your phone). Follow the screens.
6. Sign in. You land in **Snowsight**.

Write down your **account URL** (it looks like `https://<something>.snowflakecomputing.com`). You will not need it
for the steps below, but you will for part 10.

## 4. Find your way around Snowsight

The menu is on the left. Labels differ a little between releases, so look for the idea, not the exact word.

| You want | Look for |
|---|---|
| A place to run SQL | **Projects**, then **Worksheets** (or **Workspaces** in newer accounts) |
| To see databases and tables | **Data**, then **Databases** |
| To see warehouses | **Compute** or **Admin**, then **Warehouses** |
| To check your role | Your name or initials (bottom left or top right) |
| Streamlit apps | **Projects**, then **Streamlit** |

**First query.** Open a new SQL worksheet (the `+` button). Paste this and run it with the blue ▶ button:

```sql
SELECT CURRENT_ROLE() AS ROLE_NOW, CURRENT_WAREHOUSE() AS WAREHOUSE_NOW, CURRENT_ACCOUNT() AS ACCOUNT_NOW;
```

* `ROLE_NOW` should be `ACCOUNTADMIN` (or `SYSADMIN`). That is fine for this demo.
* If `WAREHOUSE_NOW` is empty, pick a warehouse in the worksheet header (top right) and run the query again. If you
  have none, create one under Warehouses: size **X-Small**, auto-suspend **1 minute**.

The setup scripts never choose a role or warehouse for you. They use whatever the worksheet header says.

## 5. Path A: put the demo into Snowflake by copy and paste

You will open each SQL file on GitHub, copy its text, paste it into a worksheet, and run it. The files must run **in
this order**.

**How to copy a file from GitHub.** Open the file (links below), click **Raw** (or the copy icon labelled
"Copy raw file"), select everything (Ctrl+A or Cmd+A), copy it, and paste it into the worksheet. No programming
tools needed. You can also use **Code, Download ZIP** and open the files in a text editor.

**How to run a whole file.** Select the worksheet text, click the small arrow beside the blue ▶ button, and choose
**Run All**. Snowflake runs the statements one after another. Run the files one at a time in the same worksheet:
replace the text, then Run All again.

| Step | File | What to look for afterwards |
|---|---|---|
| 0 | [`sql/00_setup.sql`](../sql/00_setup.sql) | A row with your role and warehouse. Nothing is created. |
| 1 | [`sql/01_create_schemas.sql`](../sql/01_create_schemas.sql) | Run `SHOW SCHEMAS IN DATABASE PUSAT_INFORMASI_PAROKI;`. You should see `MASTER_DATA`, `DATA_OPERASIONAL`, `ANALISIS`. |
| 2 | [`sql/02_create_tables.sql`](../sql/02_create_tables.sql) | 38 tables exist (18 in `MASTER_DATA`, 20 in `DATA_OPERASIONAL`). |
| 3 | [`sql/03_load_reference_data.sql`](../sql/03_load_reference_data.sql) | `SELECT COUNT(*) FROM PUSAT_INFORMASI_PAROKI.MASTER_DATA.MASTER_WILAYAH;` gives 6. |
| 4a | [`sql/04a_load_mass_history.sql`](../sql/04a_load_mass_history.sql) | Unforeseen events, Mass occurrences, attendance. |
| 4b | [`sql/04b_load_offertory.sql`](../sql/04b_load_offertory.sql) | Offertory collections. Needs 4a. |
| 4c | [`sql/04c_load_parishioners.sql`](../sql/04c_load_parishioners.sql) | Fictional households and people. |
| 4d | [`sql/04d_load_surveys.sql`](../sql/04d_load_surveys.sql) | Survey answers. |
| 4e | [`sql/04e_load_plans_and_events.sql`](../sql/04e_load_plans_and_events.sql) | Plans, budgets, spending, events, reports. |
| 4f | [`sql/04f_load_donations.sql`](../sql/04f_load_donations.sql) | Donation campaigns and gifts. Needs 4c and 4e. |
| 5 | [`sql/05_create_views.sql`](../sql/05_create_views.sql) | `SHOW VIEWS IN SCHEMA PUSAT_INFORMASI_PAROKI.ANALISIS;` lists 22 views. |
| 6 | [`sql/06_validate_data.sql`](../sql/06_validate_data.sql) | The first two rows say `FAIL = 0` and `WARN = 1`, both `PASS`. See part 7. |

Good to know:

* Every step can be run again safely. Steps 3 and 4 use "update if it exists, insert if it does not", so nothing is
  duplicated, and nothing is deleted.
* There is also one all-in-one file, [`sql/full_setup.sql`](../sql/full_setup.sql) (about 1.8 MB). If your browser
  copes with pasting it, one Run All does steps 0 to 6. Whether Snowsight accepts a file that large in one go has not
  been verified; if it struggles, use the step files.
* **Do not run** [`sql/99_reset_demo.sql`](../sql/99_reset_demo.sql) unless you want to delete the demo. It is
  commented out on purpose.
* If you ran an earlier version of this project in the same account, run the reset (option B or C in that file) first,
  because the tables changed.

Now go to part 7.

## 6. Path B: connect GitHub to Snowflake

Three different things are easy to mix up:

1. **Storing the SQL in GitHub.** Git keeps the files and their history. It runs nothing.
2. **Letting Snowflake read GitHub.** You create a *Git repository object* in Snowflake that mirrors the repository.
   Snowflake can then see the files. It still runs nothing by itself.
3. **Running the SQL.** You tell Snowflake to run each file with `EXECUTE IMMEDIATE FROM`.

You do the connection once. After that, updating means "fetch" and "run".

### 6.1 If the repository is public

Open a worksheet, make sure the role is `ACCOUNTADMIN` (creating an API integration needs an administrator role),
and run this whole block. Nothing here is secret.

```sql
USE ROLE ACCOUNTADMIN;

-- The Git repository object needs a place to live. This database is the demo database itself.
CREATE DATABASE IF NOT EXISTS PUSAT_INFORMASI_PAROKI;

-- Allows Snowflake to talk to GitHub, but only to addresses starting with this prefix.
CREATE OR REPLACE API INTEGRATION PARISH_GITHUB
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/mizuruka92')
  ENABLED = TRUE;

-- The mirror of the repository.
CREATE OR REPLACE GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO
  API_INTEGRATION = PARISH_GITHUB
  ORIGIN = 'https://github.com/mizuruka92/church-activties.git';

-- Download the newest files from GitHub into the mirror.
ALTER GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO FETCH;
```

Check that Snowflake sees the files:

```sql
LS @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/;
```

You should see `01_create_schemas.sql`, `02_create_tables.sql` and the others. If the list is empty or the command
fails, go to part 11.

### 6.2 If the repository is private

Snowflake needs a **token** to read it. Create one on GitHub:

1. On GitHub, open your profile picture, then **Settings**, then **Developer settings**, then **Personal access
   tokens**, then **Fine-grained tokens**, then **Generate new token**.
2. Give it a name such as `snowflake-parish-demo` and a short expiry (for example 30 days).
3. Under **Repository access**, choose **Only select repositories** and pick `church-activties`.
4. Under **Permissions, Repository permissions**, set **Contents** to **Read-only**. Leave everything else off.
5. Generate the token and copy it **now**; GitHub shows it only once.

If the repository belongs to another person and GitHub does not offer it for a fine-grained token, ask the owner to
create the token, or use a *classic* token with the `repo` scope. GitHub's screens change, so follow GitHub's current
wording.

Then run this in a worksheet as `ACCOUNTADMIN`. Replace the two placeholders in angle brackets, including the
brackets:

```sql
USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS PUSAT_INFORMASI_PAROKI;

-- Stores the token inside Snowflake. Do NOT save this text anywhere else, and do NOT commit it.
CREATE OR REPLACE SECRET PUSAT_INFORMASI_PAROKI.PUBLIC.GITHUB_TOKEN
  TYPE = PASSWORD
  USERNAME = '<your GitHub user name>'
  PASSWORD = '<paste the token here>';

CREATE OR REPLACE API INTEGRATION PARISH_GITHUB
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/mizuruka92')
  ALLOWED_AUTHENTICATION_SECRETS = (PUSAT_INFORMASI_PAROKI.PUBLIC.GITHUB_TOKEN)
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO
  API_INTEGRATION = PARISH_GITHUB
  GIT_CREDENTIALS = PUSAT_INFORMASI_PAROKI.PUBLIC.GITHUB_TOKEN
  ORIGIN = 'https://github.com/mizuruka92/church-activties.git';

ALTER GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO FETCH;
LS @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/;
```

Afterwards, **delete the token line from the worksheet**. The text you ran may remain in Snowflake's query history, which
administrators can read, so use a read-only token with a short expiry and revoke it on GitHub when you are done. Never
paste a token into a file in this repository, a chat, or an issue. `.gitignore` blocks common credential files, but it
cannot protect text you type into a tracked file.

### 6.3 The no-SQL alternative: a workspace from Git

Newer Snowsight accounts can connect a repository from the screen: **Projects, Workspaces, From Git repository**. You paste
the repository address, choose or create the API integration (needs an administrator role) and, for a private
repository, create a secret with your token on the same screen. The SQL files then appear in a workspace where you can
open and run them. Menu names change, and this route has not been tried here. If you use it, you still run the files in
the order of part 5.

### 6.4 Run the files from the repository

Run this block. It runs the files in order and stops at the first problem:

```sql
USE ROLE ACCOUNTADMIN;   -- or the role you chose to own the demo
USE WAREHOUSE COMPUTE_WH;  -- replace with your warehouse name

EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/01_create_schemas.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/02_create_tables.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/03_load_reference_data.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04a_load_mass_history.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04b_load_offertory.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04c_load_parishioners.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04d_load_surveys.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04e_load_plans_and_events.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/04f_load_donations.sql;
EXECUTE IMMEDIATE FROM @PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/sql/05_create_views.sql;
```

Do **not** add `sql/99_reset_demo.sql` to this list.

Things to know:

* Select all the lines and use **Run All** so every line runs.
* A file run this way returns a status, not the result table of its last query. That is why the validation (step 6) is
  better opened and run as a normal worksheet, as in part 7.
* The files contain no template directives, so Snowflake runs them as plain SQL.
* The step files are large (the biggest is about 420 KB). Whether `EXECUTE IMMEDIATE FROM` accepts files of that size has
  not been verified. If one fails, run that file with copy and paste (Path A) and carry on.

### 6.5 Getting updates later

When someone pushes new commits to `main`:

```sql
ALTER GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO FETCH;
```

then run the changed files again (every file is safe to repeat). If the **table definitions** changed (the release notes
or the commit message will say so), reset the demo first; see the note in part 5.

**A note about branches.** This guide reads from `main`. If you want to try work that has not been merged yet, replace
`main` in the paths with the branch name. Branch names containing a slash (such as `claude/some-branch`) may not work in
those paths; merging into `main` is the reliable way.

## 7. Check that the demo loaded

Open `sql/06_validate_data.sql` on GitHub, copy it, paste it into a worksheet, and **Run All**. (With Path B you can open the
same file from a workspace.) It only reads.

The result is one table. Look at the **first two rows**:

| CHECK_NAME | FOUND_COUNT | RESULT |
|---|---|---|
| Checks with result FAIL | **0** | PASS |
| Checks with result WARN | **1** | PASS |

* **0 FAIL** means the data is complete and consistent.
* **Exactly 1 WARN** is expected: one post-event report is deliberately inconsistent, to show how validation finds it.
* Rows marked `INFO` count situations the demo is meant to contain (for example attendance waiting for validation). They are not
  problems.
* Anything else: filter the `RESULT` column for `FAIL` and see part 11.

Now try a view:

```sql
SELECT TAHUN, PEMASUKAN_KOLEKTE, PENGELUARAN_PROGRAM, PERSEN_PENGELUARAN_TERHADAP_KOLEKTE
FROM PUSAT_INFORMASI_PAROKI.ANALISIS.PEMASUKAN_PENGELUARAN_TAHUNAN
ORDER BY TAHUN;
```

You should see six rows (2021 to 2026), with spending growing from about 22% of the offertory to about 77%.

## 8. Create the dashboard

The dashboard is the file [`app/streamlit_app.py`](../app/streamlit_app.py). It lives **inside Snowflake**, reads the views
in `ANALISIS`, and needs no installation. Pick one option.

### Option 1: paste it into Snowsight (simplest)

1. In Snowsight go to **Projects**, then **Streamlit**, then **+ Streamlit App**.
2. Give it a name, for example `Pusat Informasi Paroki`.
3. **App location:** database `PUSAT_INFORMASI_PAROKI`, schema `PUBLIC`.
4. **Warehouse / runtime:** choose the option that **runs on a warehouse** and select your warehouse. If Snowsight also offers a
   *container* runtime that needs a compute pool, do not choose it. It costs more and is not needed here. Newer Snowflake releases
   may preselect the container runtime, so check.
5. The editor opens with a small sample app. **Select all the sample code and delete it.**
6. On GitHub open [`app/streamlit_app.py`](../app/streamlit_app.py), click **Raw**, copy everything, and paste it into the editor.
7. Click **Run** (or the app refreshes by itself). The first start can take a minute while the warehouse wakes up.

Use the same role that ran the setup. The app reads the views with its owner's permissions, so that role must be able to read
`PUSAT_INFORMASI_PAROKI.ANALISIS`. The role that created the views can.

### Option 2: create the app from the Git repository (Path B users)

```sql
CREATE OR REPLACE STREAMLIT PUSAT_INFORMASI_PAROKI.PUBLIC.DASBOR_PAROKI
  FROM '@PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO/branches/main/app'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH       -- replace with your warehouse name
  TITLE = 'Pusat Informasi Paroki (simulasi)';
```

If your account makes container-runtime apps by default, add the line `RUNTIME_NAME = 'SYSTEM$WAREHOUSE_RUNTIME'` before the
final semicolon. If your account does not recognise that line, remove it again. Then open **Projects, Streamlit** and click the
app, or run `SHOW STREAMLITS;`. To publish a newer version of the app after `FETCH`, run the `CREATE OR REPLACE STREAMLIT`
statement again. The exact clause order and the behaviour of repository-backed apps were taken from Snowflake's release notes
and have not been tried here.

### What you should see

* The title **Ringkasan** and a blue notice **"DATA SIMULASI"**.
* Eight figures: yearly offertory, spending, the spending-to-offertory ratio, average attendance per Mass, the year spending is
  expected to pass the offertory (**2029**), how much of the Easter and Christmas costs the Lent and Advent donations cover
  (Easter above 100%, Christmas about 66%), and the number of unforeseen events (10).
* A chart with two solid lines (offertory in blue, spending in orange) and dashed trend lines crossing at 2029.
* A menu on the left with eight pages. Click through them.

If you see a red box saying **"Data belum dapat dimuat dari Snowflake"**, open **"Detail teknis untuk pengelola"** and go to part 11.

## 9. Share it and keep the cost low

**Who can open the dashboard.** By default only the owner. To let someone else (with their own Snowflake user) open it, grant their
role permission:

```sql
GRANT USAGE ON STREAMLIT PUSAT_INFORMASI_PAROKI.PUBLIC.DASBOR_PAROKI TO ROLE <their role>;
```

(replace the app name with the one you gave it). The viewer's role may also need access to the database and the warehouse; see
Snowflake's documentation on Streamlit privileges, since this was not tried here. Snowflake's documentation says a Streamlit app runs with its owner's rights, so
sharing it should not give viewers access to the tables behind the views. Check this in your account before you rely on it.

**Cost.** A warehouse costs trial credit only while it runs. This demo is tiny, so an X-Small warehouse is plenty. Make it stop
quickly when idle (optional, and it changes your warehouse's setting):

```sql
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;   -- seconds of idleness before it stops
```

The dashboard keeps each view in memory for ten minutes, so clicking around does not hit Snowflake every time. To see the credits
used, open **Admin, Cost Management** (the name varies).

## 10. Optional: run the dashboard on your own computer

You do not need this to show the demo. It is for people who want to change the dashboard.

1. Install Python 3.11 (3.9 to 3.12 should work). Download the repository (Code, Download ZIP) and unzip it.
2. Open a terminal in the unzipped folder and run:

   ```bash
   python -m venv .venv
   source .venv/bin/activate        # on Windows: .venv\Scripts\activate
   pip install -r app/requirements.txt
   ```

3. Copy `app/.streamlit/secrets.toml.example` to `app/.streamlit/secrets.toml` and fill in your account identifier, user, role and
   warehouse. `secrets.toml` is ignored by Git. Keep it that way.
4. **Signing in from outside the browser.** Snowflake requires multi-factor authentication for password sign-in, and a script
   cannot answer a phone prompt. The simplest method that works without a browser is a **key pair**:

   ```bash
   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
   openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
   ```

   Keep `snowflake_key.p8` **outside the repository** (`.gitignore` blocks `*.p8`, but do not rely on it). Then in a Snowflake
   worksheet, run `ALTER USER <your user> SET RSA_PUBLIC_KEY = '<the text between the BEGIN and END lines of snowflake_key.pub>';`
   and put the path of the `.p8` file in `secrets.toml` (the example shows where). Single sign-on users can use
   `authenticator = "externalbrowser"` instead.
5. Start the app:

   ```bash
   cd app
   streamlit run streamlit_app.py
   ```

   Your browser opens the dashboard.

This route, including the key-pair steps, has not been tried against a real account.

## 11. When something goes wrong

Write down the **exact message** and the **step** where it appeared. Do not edit the generated files by hand.

| Symptom | Likely cause and what to do |
|---|---|
| "No active warehouse selected" | Choose a warehouse in the worksheet header, or create an X-Small one. |
| "Insufficient privileges" when creating the database or the API integration | Switch role to `ACCOUNTADMIN` (or ask an administrator). |
| `CREATE API INTEGRATION` or `CREATE GIT REPOSITORY` fails | Check the address: it must start with `https://`. For a private repository, the secret must be listed in `ALLOWED_AUTHENTICATION_SECRETS`, and the role you use needs `USAGE` on it. |
| `FETCH` fails with "authentication" or "not found" | The repository is private and the token is missing, expired, or lacks **Contents: read**. Create a new token and run `CREATE OR REPLACE SECRET` again. |
| `LS @...PARISH_REPO/branches/main/sql/` shows nothing | `main` may not contain the files yet (see part 2), or `FETCH` has not run. Run `SHOW GIT BRANCHES IN GIT REPOSITORY PUSAT_INFORMASI_PAROKI.PUBLIC.PARISH_REPO;` to see which branches Snowflake has. |
| A step says a table or schema "does not exist" | A previous step was skipped. Run the steps in order. |
| A column or table "does not exist" after updating to a newer version | The tables changed and the database comes from an older version. Reset (see part 5), then run the setup again. |
| A statement fails with a syntax error | Note the file and the statement and report it. The SQL was tested on a different database engine and has not run in Snowflake yet. |
| The validation shows `FAIL` rows | Filter `RESULT = 'FAIL'`. If the row-count or `VIEWS` rows fail, a step did not finish: run steps 3, 4a to 4f and 5 again. |
| `EXECUTE IMMEDIATE FROM` fails for a big file | Run that file with copy and paste instead (Path A). |
| The Streamlit app shows "Data belum dapat dimuat dari Snowflake" | The setup is not finished (steps 1 to 6), the app's warehouse is missing or stopped, or the app's owner role cannot read the views. Open "Detail teknis". An error naming a view means step 5 did not run. A permission error means you should use the role that ran the setup. |
| The app shows nothing for a long time on first start | The warehouse is waking up. Wait a minute. |
| The editor says a package is missing (`altair`, `pandas`) | Streamlit in Snowflake normally includes them. Use the package selector in the editor to add `altair` and `pandas`. |
| `st.context` or another Streamlit feature is reported as unknown | Your Streamlit version is older. The app falls back by itself. If a page still fails, choose a newer Streamlit version in the editor's package list and report the message. |
| Snowsight refuses a very large paste | Use the step files instead of `full_setup.sql`. |
| You see real-looking names or data | You should not. The data is generated. Report it. |

## 12. What has been checked, and what has not

**Checked by running it on this repository's side** (on a different database engine, DuckDB, as a stand-in for Snowflake):
all table and view SQL, loading twice without duplicates, the validation (0 FAIL, 1 WARN) and 34 deliberately damaged copies of the
data being detected, every SQL example in the docs, and the dashboard: every page renders, only the allowed views are read, no ranking
words appear, privacy rules hold. The dashboard was also run in a headless browser in light and dark themes and on two Streamlit /
Altair generations.

**Checked only against Snowflake's published documentation:** the account sign-up steps, the Snowsight menu names, the Git integration
statements (`CREATE API INTEGRATION ... API_PROVIDER = git_https_api`, `CREATE SECRET`, `CREATE GIT REPOSITORY`, `ALTER GIT REPOSITORY
... FETCH`), `EXECUTE IMMEDIATE FROM`, `CREATE STREAMLIT ... FROM`, the warehouse versus container runtime choice, MFA, and trial terms.

**Not done:** nothing has been executed in a Snowflake account. The points most likely to need a small fix on the first real run:

1. The `COMMENT` placed after `NOT NULL` in the table definitions (step 2).
2. The `MERGE ... USING (SELECT ... FROM (VALUES ...))` form in the load files (steps 3 and 4).
3. Compile time of the single validation statement with about 300 `UNION ALL` branches (step 6).
4. The statistical functions in the new views (`MEDIAN`, `CORR`, `REGR_SLOPE`, `REGR_INTERCEPT`, `REGR_R2`) and `DATEADD`/`DATEDIFF`.
5. Whether `EXECUTE IMMEDIATE FROM` accepts the 100 to 420 KB step files, and whether Snowsight accepts the 1.8 MB all-in-one file.
6. How the dashboard behaves inside Streamlit in Snowflake (version, runtime, theme detection, first-start time).
7. The optional local-run route and the key-pair sign-in.

If one of these fails for you, copy the message into a new note for the project. That is the most useful thing you can do.

## 13. Cleaning up

* **Stop the cost:** the warehouse stops by itself after the idle time you set. Nothing else runs.
* **Remove the dashboard:** in **Projects, Streamlit**, open the app's menu and delete it. (The SQL equivalent is `DROP STREAMLIT`, which
  is destructive, so only run it if you mean it.)
* **Remove the demo data:** open [`sql/99_reset_demo.sql`](../sql/99_reset_demo.sql), read the three options, remove the leading `--`
  from the one you want and run only those lines. It names only the demo objects. After a reset you can run the setup again.
* **Revoke the GitHub token** (Path B, private repository) on GitHub when you no longer need it.
* **When the trial ends:** the data is only simulated, so nothing is lost. You can recreate it any time by running the setup again.
  Check Snowflake's current terms on what happens to a trial account after it expires.

## 14. Where to go next

* [`README.md`](../README.md): the project overview.
* [`SETUP_SNOWFLAKE.md`](SETUP_SNOWFLAKE.md): the reference version of parts 4 to 7, including the command-line route.
* [`DASHBOARD.md`](DASHBOARD.md): what each dashboard page shows and why it was designed that way.
* [`USE_CASES.md`](USE_CASES.md): the four analysis stories behind the data, with the figures.
* [`DATA_MODEL.md`](DATA_MODEL.md) and [`DATA_DICTIONARY.md`](DATA_DICTIONARY.md): how the data is organised.
