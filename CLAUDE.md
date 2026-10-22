# CLAUDE.md
# Parish Information Hub: Snowflake Demo

## 1. Project Overview

Build a lightweight demonstration of a **Parish Information Hub** using Snowflake as the primary data platform.

The purpose of this project is to demonstrate how information from different parish functions can be collected, standardized, stored, related, and prepared for reporting and analysis.

The demo is intended for an initial presentation to parish leadership. It is a proof of concept, not a commitment to a final technology stack or production architecture.

Snowflake is the initial platform because its trial account makes it practical to build and demonstrate the solution quickly. The design should remain portable enough that the concepts can be implemented using other platforms if needed.

### Core principles

1. All project instructions, technical documentation, and code comments should be written in English.
2. **All business-facing content and mock data must be in Bahasa Indonesia**, including names, descriptions, categories, event titles, business statuses, dashboard labels, and sample survey responses.
3. All generated data must be synthetic and fictional. Never use real parishioner data or actual operational records.
4. Model the data as related domains rather than putting everything into one large table.
5. Keep the implementation simple, reproducible, and suitable for a live demonstration.
6. Support both step-by-step execution and a complete first-time setup.
7. Store SQL, scripts, documentation, and other relevant project artifacts in Git.
8. Avoid unnecessary enterprise infrastructure, orchestration, and production-level complexity.
9. Treat the technology stack as replaceable. Focus on demonstrating business value and sound data design.

## 2. Scope and Implementation Phases

Develop the project incrementally.

### Phase 1: Data acquisition and preparation

This is the current priority.

- Define the initial data model.
- Create the required Snowflake database schemas and tables.
- Generate synthetic data in Bahasa Indonesia.
- Load the synthetic data into Snowflake.
- Validate record counts, relationships, and basic data quality.
- Create data dictionaries and model documentation.
- Provide scripts for running individual setup steps.
- Provide an option to execute the complete setup from scratch.

### Phase 2: Dashboard and data exploration

Implement only after Phase 1 is stable.

- Build a lightweight dashboard using Streamlit.
- Connect Streamlit to Snowflake.
- Display useful business indicators, trends, and summaries.
- Use Bahasa Indonesia for all user-facing content.
- Keep the interface simple enough for a nontechnical audience.

### Phase 3: Future enhancements

Do not implement these unless explicitly requested.

Potential enhancements include integration with real data sources, automated ingestion, advanced access control, spatial analysis, and more sophisticated analytics.

## 3. Language and Naming Conventions

### Content language

Use English for:

- Project instructions and technical documentation.
- Code comments and implementation notes.
- Setup instructions and developer-facing troubleshooting.
- Technical explanations and architecture documentation.

Use Bahasa Indonesia for:

- Synthetic business data and sample records.
- Names of fictional people, families, regions, communities, sections, and events.
- Business categories, descriptions, and status values.
- Survey questions and responses.
- Dashboard labels, charts, tooltips, and user-facing messages.
- Business-facing descriptions and sample reports.

Technical product names and standard programming terminology may remain in English.

Do not mix languages inconsistently within the same business-facing dataset.

### Database naming

Use uppercase snake case for Snowflake database objects.

Example:

- `PUSAT_INFORMASI_PAROKI`
- `MASTER_DATA`
- `DATA_OPERASIONAL`
- `ANALISIS`
- `MASTER_WILAYAH`
- `JADWAL_MISA`
- `KEHADIRAN_MISA`
- `PENERIMAAN_KOLEKTE`
- `RENCANA_ANGGARAN`
- `LAPORAN_KEGIATAN`

Keep names consistent and avoid unnecessary abbreviations.

Database object names may use established technical English terms when justified by compatibility or conventions, but do not switch naming styles arbitrarily.

## 4. Initial Data Domains

Create tables and synthetic data for the following nine domains.

### 4.1 Offertory Collections

Purpose: Record offertory collection summaries by Mass occurrence and collection type.

Recommended grain: One record per Mass occurrence and collection type.

Suggested attributes:

- `ID_KOLEKTE`
- `ID_KEJADIAN_MISA`
- `JENIS_KOLEKTE`
- `JUMLAH_PENERIMAAN`
- `JUMLAH_HASIL_PENGHITUNGAN`
- `STATUS_REKONSILIASI`
- `TANGGAL_PENCATATAN`
- `KETERANGAN`

Use numeric values in Indonesian rupiah.

Distinguish the recorded amount, counted amount, and reconciliation status. Include examples with different reconciliation states.

Do not present offertory values as a measure of faith or spiritual commitment.

### 4.2 Mass Attendance

Purpose: Record attendance totals for individual Mass occurrences.

Recommended grain: One record per Mass occurrence.

Suggested attributes:

- `ID_KEHADIRAN`
- `ID_KEJADIAN_MISA`
- `JUMLAH_UMAT`
- `METODE_PENGHITUNGAN`
- `STATUS_VALIDASI`
- `WAKTU_PENCATATAN`
- `KETERANGAN`

Use the same `ID_KEJADIAN_MISA` referenced by the Mass occurrence and offertory domains.

Generate plausible attendance figures and include different validation states.

### 4.3 Parishioner Database (BIDUK Simulation)

Purpose: Demonstrate how parishioner information can be modeled, related, classified, and governed.

Where appropriate, separate the following entities:

- Individual parishioners.
- Households or families.
- Individual-to-household assignments.
- Assignments to communities or regions.
- Data classification and access metadata.

Suggested attributes include:

- `ID_UMAT`
- `ID_KELUARGA`
- `NAMA_FIKTIF`
- `STATUS_KEANGGOTAAN`
- `ID_LINGKUNGAN`
- `TANGGAL_MULAI_BERLAKU`
- `TANGGAL_AKHIR_BERLAKU`
- `KLASIFIKASI_DATA`

All individuals, households, and assignments must be fictional.

Never use actual identity numbers, phone numbers, home addresses, or parishioner records.

Treat identifiable personal information as restricted data. Do not expose detailed individual records through public-facing dashboard views.

### 4.4 Special Occasion Donations by Region

Purpose: Record donation summaries by region and occasion, such as Lent or Advent.

Recommended grain: One record per region, occasion, and reporting period. Create a separate transaction-level table only if required by a specific use case.

Suggested attributes:

- `ID_SUMBANGAN`
- `ID_WILAYAH`
- `NAMA_KESEMPATAN`
- `PERIODE_MULAI`
- `PERIODE_SELESAI`
- `JUMLAH_KELUARGA_PESERTA`
- `JUMLAH_SUMBANGAN`
- `TANGGAL_PENCATATAN`
- `STATUS_VALIDASI`

Use Indonesian rupiah and reference the regional master data.

Do not rank regions in ways that imply a judgment about faith, generosity, or spiritual commitment.

### 4.5 Mass Schedule Master Data

Purpose: Maintain consistent Mass schedule information for public communication and operational reporting.

Separate recurring schedule rules from actual Mass occurrences when appropriate.

Suggested recurring schedule attributes:

- `ID_JADWAL_MISA`
- `NAMA_MISA`
- `HARI`
- `WAKTU_MULAI`
- `WAKTU_SELESAI`
- `LOKASI`
- `BAHASA_MISA`
- `STATUS_AKTIF`

Suggested occurrence attributes:

- `ID_KEJADIAN_MISA`
- `ID_JADWAL_MISA`
- `TANGGAL_MISA`
- `WAKTU_MULAI_AKTUAL`
- `WAKTU_SELESAI_AKTUAL`
- `STATUS_PELAKSANAAN`

Use `ID_KEJADIAN_MISA` as the shared identifier for attendance and offertory records.

Clearly distinguish scheduled times from actual execution times.

### 4.6 Surveys

Purpose: Store survey definitions, questions, synthetic responses, and aggregated results.

Use separate tables where appropriate for:

- Survey master data.
- Survey questions.
- Survey responses.
- Aggregated survey results.

Suggested attributes:

- `ID_SURVEI`
- `JUDUL_SURVEI`
- `TUJUAN_SURVEI`
- `TANGGAL_MULAI`
- `TANGGAL_SELESAI`
- `ID_PERTANYAAN`
- `JENIS_JAWABAN`
- `KATEGORI_JAWABAN`
- `JUMLAH_RESPONDEN`
- `PERSENTASE_JAWABAN`

Use realistic survey topics relevant to parish activities and community needs.

Avoid unnecessary sensitive information. Prefer aggregated results for initial dashboard use cases.

Ensure response counts and percentages are internally consistent.

### 4.7 Annual Plans, Budgets, and Actuals

Purpose: Connect section-level annual plans to activities, budgets, schedules, and actual expenditure.

Use separate entities where appropriate for:

- Annual work plans.
- Planned activities.
- Budget allocations.
- Actual expenditure.
- Reporting periods.

Suggested attributes:

- `ID_RENCANA`
- `ID_SEKSI`
- `TAHUN_RENCANA`
- `NAMA_PROGRAM`
- `TUJUAN_PROGRAM`
- `TANGGAL_RENCANA`
- `ANGGARAN_RENCANA`
- `ANGGARAN_TERPAKAI`
- `STATUS_PELAKSANAAN`
- `KETERANGAN`

Keep planned values separate from actual values where the underlying business model requires it.

Include planned, completed, postponed, and cancelled activities.

Do not assume that every planned activity has already been executed or has incurred expenditure.

### 4.8 Events and Post-Event Reports

Purpose: Connect planned activities with actual execution, attendance, finances, logistics, and outcomes.

Use separate event and post-event report tables where appropriate.

Suggested event attributes:

- `ID_KEGIATAN`
- `ID_RENCANA`
- `NAMA_KEGIATAN`
- `ID_SEKSI`
- `TANGGAL_MULAI`
- `TANGGAL_SELESAI`
- `LOKASI`
- `STATUS_KEGIATAN`
- `TARGET_PESERTA`
- `JUMLAH_PESERTA_AKTUAL`

Suggested post-event report attributes:

- `ID_LAPORAN`
- `ID_KEGIATAN`
- `TANGGAL_LAPORAN`
- `RINGKASAN_PELAKSANAAN`
- `JUMLAH_PESERTA`
- `REALISASI_BIAYA`
- `EVALUASI_LOGISTIK`
- `HASIL_KEGIATAN`
- `REKOMENDASI_TINDAK_LANJUT`

Generate data that supports comparison of participant targets versus actual attendance, planned budgets versus actual expenditure, and documented outcomes.

Do not assume that every event has a completed post-event report.

### 4.9 Regional Master Data and GIS

Purpose: Maintain organizational and geographic references for regional reporting and service coverage analysis.

Suggested attributes:

- `ID_WILAYAH`
- `NAMA_WILAYAH`
- `ID_LINGKUNGAN`
- `NAMA_LINGKUNGAN`
- `STATUS_AKTIF`
- `TANGGAL_MULAI_BERLAKU`
- `TANGGAL_AKHIR_BERLAKU`

For the initial demo, GeoJSON may be used as a source format for illustrative geometry. Store geometry or its reference in Snowflake only when needed for the intended use case.

Never present fictional coordinates or boundaries as official parish geography.

Clearly label illustrative geometry as synthetic. If actual geographic boundaries are not available, do not imply that a demo map accurately represents real parish boundaries.

## 5. Additional Reference Data

Create the reference tables required to connect the domains, such as:

- Section master data.
- Region and community master data.
- Information category master data.
- Event status reference data.
- Offertory type reference data.
- Data classification reference data.
- Reporting period reference data.

Use stable identifiers across related tables.

Avoid duplicating reference attributes in transactional tables when a proper reference relationship is more appropriate.

## 6. Synthetic Data Requirements

Generate enough data to demonstrate relationships, validations, and future dashboards without creating unnecessarily large datasets.

Suggested initial volumes:

- 5–10 fictional regions.
- 15–30 fictional communities.
- 5–10 parish sections.
- Several recurring Mass schedules.
- Several months of Mass occurrences.
- Attendance and offertory records linked to Mass occurrences.
- Fictional households and individuals.
- Several special donation periods.
- Multiple surveys with questions and responses.
- Annual plans, budgets, actuals, events, and post-event reports.

Requirements:

1. All records must be synthetic.
2. All people, households, communities, regions, and event names must be fictional.
3. Use plausible dates, financial amounts, attendance counts, and business scenarios.
4. Maintain valid relationships between parent and child records.
5. Include enough variation to make the demo useful.
6. Include examples of pending validation, incomplete reconciliation, postponed events, incomplete reports, and partially utilized budgets.
7. Use a fixed random seed when generating data with Python, so results are reproducible.
8. Do not import real operational records or personal data.
9. Clearly label the dataset and dashboard as simulated data.
10. Keep mock data volumes small enough for a free trial account and a live demonstration.

## 7. Snowflake Database Design

Use the following initial database:

`PUSAT_INFORMASI_PAROKI`

Use these schemas:

- `MASTER_DATA`: reference and master data.
- `DATA_OPERASIONAL`: operational records and transactions.
- `ANALISIS`: summary views and datasets prepared for demonstration.

Keep the architecture simple. Do not introduce unnecessary staging layers or orchestration frameworks unless the implementation genuinely benefits from them.

Use appropriate Snowflake data types:

- `VARCHAR` for text.
- `NUMBER` for counts and financial values.
- `DATE` for dates.
- `TIME` for time-of-day values.
- `TIMESTAMP_NTZ` for local timestamps when appropriate.
- `BOOLEAN` for logical attributes.
- Snowflake geospatial types and functions only when needed.

Define primary keys and foreign keys conceptually in the DDL.

Be aware that primary key and foreign key constraints on standard Snowflake tables are generally not enforced automatically. Add explicit validation queries for duplicate identifiers and orphaned relationships.

Never store financial amounts as text.

Document the intended grain, key relationships, and business meaning of each table.

## 8. Suggested Project Structure

Create a straightforward repository structure such as:

```text
parish-information-hub/
├── CLAUDE.md
├── README.md
├── sql/
│   ├── 00_setup.sql
│   ├── 01_create_schemas.sql
│   ├── 02_create_tables.sql
│   ├── 03_load_reference_data.sql
│   ├── 04_load_mock_data.sql
│   ├── 05_create_views.sql
│   ├── 06_validate_data.sql
│   └── 99_reset_demo.sql
├── scripts/
│   └── generate_mock_data.py
├── data/
│   ├── generated/
│   └── README.md
├── docs/
│   ├── DATA_DICTIONARY.md
│   ├── DATA_MODEL.md
│   └── SETUP_SNOWFLAKE.md
├── tests/
│   └── validation_queries.sql
└── app/
    └── README.md
```

Adapt this structure when there is a clear technical reason.

Do not create empty files merely to match the example.

Use SQL for simple synthetic data generation when it is maintainable. Use Python when relational data generation, reproducibility, or illustrative geospatial data makes it more suitable.

Avoid maintaining duplicate copies of generated data without a clear reason.

Never commit credentials, tokens, passwords, or private keys.

## 9. Setup and Execution Workflow

Every implementation step must be runnable independently.

### Step 1: Initial setup

Create the database and required schemas, assuming the user has signed in to Snowflake and has the necessary permissions.

Keep warehouse configuration separate from table definitions where practical.

Do not assume a particular warehouse name, role, or privilege configuration.

### Step 2: Create tables

Generate the DDL for all domain and reference tables.

Ensure consistent data types, identifiers, conceptual keys, and required attributes.

### Step 3: Generate synthetic data

Generate reference data first, followed by dependent operational records.

Respect dependency order when creating and loading records.

### Step 4: Load data

Provide a straightforward loading mechanism suitable for a trial account.

Use SQL inserts, `VALUES`, or generated CSV files as appropriate.

Do not require external stages or additional cloud services unless needed.

### Step 5: Validate data

Provide validation queries for:

- Row counts per table.
- Duplicate identifiers.
- Missing parent records and orphaned relationships.
- Unexpected null values in required columns.
- Unexpected negative financial amounts.
- Implausible dates.
- Consistency of Mass occurrence identifiers across schedules, attendance, and offertory.
- Consistency between planned activities, events, budgets, actuals, and post-event reports.
- Consistency of survey response counts and percentages.

Validation should produce clear, interpretable results.

### Step 6: Create summary views

Create views for representative business use cases, such as:

- Monthly attendance by Mass session.
- Monthly offertory by Mass session.
- Attendance trends across reporting periods.
- Special occasion donations by region.
- Planned budget versus actual expenditure.
- Events and post-event report completion.
- Aggregated survey findings.

Use descriptive names and document the purpose of each view.

### Step 7: Full setup

Provide a script or documented mechanism to run the entire setup in the correct order.

The user must be able to:

- Run an individual setup step.
- Run the complete setup against a new demo database.
- Run validations independently without deleting data.

Do not include destructive reset operations in the normal setup workflow.

Explain the execution order for Snowsight. If using Snowflake CLI or another execution mechanism, document the dependencies and exact commands.

Do not assume that connecting a Git repository to Snowflake automatically executes every SQL file.

## 10. Idempotency and Safety

Normal setup scripts should be safe to rerun wherever practical and should minimize duplicate data.

Use appropriate techniques, such as:

- `CREATE ... IF NOT EXISTS`.
- Deterministic identifiers.
- Duplicate-safe data loading.
- `MERGE` when justified.
- Transactions where appropriate.

Do not automatically drop or recreate the entire database or all tables as part of normal setup.

Keep `99_reset_demo.sql` separate. Clearly mark it as destructive and restrict its operations to explicitly identified demo objects.

Never store Snowflake credentials in Git, SQL files, notebooks, or source code.

Do not use real personal or parish operational data.

## 11. Git and Snowflake Integration

All SQL, scripts, documentation, and relevant configuration files should be version-controlled in Git.

For the initial demo, prioritize the simplest reliable workflow:

1. Develop files locally.
2. Commit changes to Git.
3. Execute version-controlled SQL through Snowflake Snowsight or a documented execution mechanism.
4. Validate the results in Snowflake.

Direct Snowflake Git repository integration may be added if useful and supported by the account configuration.

Do not make direct Git integration a prerequisite for the first working demo.

Explain the distinction between storing SQL in Git, accessing a Git repository from Snowflake, and executing SQL statements.

## 12. Phase 1 Acceptance Criteria

Phase 1 is complete when:

- DDL exists for all agreed tables.
- Synthetic Indonesian-language data can be generated reproducibly.
- The data can be loaded into Snowflake.
- Relationships between tables are consistent.
- No real personal data or credentials are included in the repository.
- Validation scripts run and produce interpretable results.
- Individual setup steps can be executed independently.
- A full setup workflow is documented for a fresh demo environment.
- Reset operations are separate and clearly marked as destructive.
- The README explains setup from scratch for a Snowflake beginner.
- The data dictionary explains column meanings, table grain, and relationships.
- Summary views are available for the initial business use cases.

Do not claim that data has been loaded into Snowflake unless the execution has actually been performed and verified.

## 13. Working Instructions for Claude Code

Before changing files:

1. Inspect the existing repository and relevant project files.
2. Read the project instructions and preserve useful existing work.
3. Identify the files to create or modify.
4. Briefly explain the proposed implementation and important design decisions.
5. Do not overwrite existing files without understanding their purpose.

Work incrementally.

Implement Phase 1 first. Do not build the Streamlit dashboard before the data model, generated data, and validation steps are stable.

After implementation, summarize:

- Files created or modified.
- Data model decisions.
- Setup execution order.
- Commands or SQL statements the user must execute.
- Tests and validations actually performed.
- Any actions that still require user input or Snowflake access.

Test data generation and validation locally where possible. Clearly distinguish local testing from successful execution in Snowflake.
