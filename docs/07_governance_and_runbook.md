# 07. Governance and runbook

How access, secrets, change and refresh are handled. Written for the person who picks this up after me.

## Access model

| Principal | Role | Can do | Cannot do |
|---|---|---|---|
| Builder (my own Snowflake user) | `ACCOUNTADMIN` on a personal trial account | Create and replace everything in `RELIABILITY` | n/a |
| `POWERBI_SVC` | `BI_READER` | `SELECT` on every table and view in `RELIABILITY.MART`, including ones created later (`FUTURE` grants). `USAGE` on the warehouse. | Read `RAW` or `STG`. Write anything. See any other database. |

Why a separate role: the report is the one thing other people will open. It should be able to read exactly what it needs and nothing else. Someone with the report credentials can query the mart. They cannot see the raw filings or change a view.

`sql/08_grants.sql` creates the role and user. Two details that cost me an hour each:

- `CREATE OR REPLACE` on a table or view drops its grants. Two guards, both used: `GRANT SELECT ON FUTURE TABLES/VIEWS` so new or rebuilt objects are readable and `COPY GRANTS` on every `CREATE OR REPLACE` in MART so an existing object keeps its grants through a rebuild.
- Power BI's Snowflake connector with a plain username and password needs the user to be `TYPE = LEGACY_SERVICE`. A default user type will fail authentication with no useful message.

## Secrets

No password, key or token appears in this repository, in any SQL file, or in any screenshot. `08_grants.sql` has a placeholder. The real password lives in the Snowflake account only and in the Power BI credential store on the build machine. If this were a team repository: Snowflake key-pair authentication for the service user, the private key in a secrets manager, rotation on a calendar.

`.gitignore` excludes `*.pbix` (binary and it embeds the connection), any `*.env`, `*.key` or `*.p8` file and the large raw downloads.

## Layering contract

| Layer | May read | May be read by | Rebuild cost |
|---|---|---|---|
| `RAW` | stages | `STG` | Re-upload and `COPY INTO` |
| `STG` | `RAW` | `MART` | Instant (views) |
| `MART` | `STG`, other `MART` objects | Power BI, analysts | Seconds |

A change to a source file touches `RAW` and nothing else needs to know. A change to a definition touches one view in `STG` or one table in `MART` and every consumer sees it on refresh. The tests are the check that a change did not break the contract.

## Refresh runbook

### Annual, each October (EIA-861 final release)

1. Download the new `Reliability_YYYY.xlsx` and `Service_Territory_YYYY.xlsx`, save the named sheets as CSV into `data/input/` and `data/reference/`.
2. Run `scripts/extract_pudl.py` once PUDL has published the prior year's cleaned tables (usually a few weeks after EIA).
3. Upload to the stages. Run `sql/01` (new year loads into `RAW`; the `RELIABILITY_2025` view becomes `RELIABILITY_YYYY`, two places to change: the view name and the `source` string).
4. Run `sql/02`. Run `sql/04`. Every test except T3 and T5 must return zero rows; T3's count must be explained.
5. Update the peer-page year windows in `powerbi/measures.dax` (the `IN {...}` sets) and the three-year measures.
6. Refresh Power BI. Check the scorecard against the new annual report. Record in `CHANGELOG.md`.

### Monthly (NOAA)

NOAA re-issues files with a new `_c` stamp when events are revised. `scripts/download_noaa.sh` pulls whatever is current. Re-run `sql/05`. T8 tells you whether the latest year is complete.

### Daily or as needed (EIA-930)

`scripts/download_eia930.sh`, re-run `sql/06` and `sql/07`. The six-month file for the current half-year grows every day.

### Automating the tests in Snowflake

```sql
CREATE OR REPLACE TABLE RELIABILITY.MART.TEST_RESULTS (run_at TIMESTAMP_NTZ, test VARCHAR, rows_returned NUMBER, expected VARCHAR, status VARCHAR);

CREATE OR REPLACE TASK RELIABILITY.MART.RUN_TESTS
  WAREHOUSE = SNOWFLAKE_LEARNING_WH
  SCHEDULE = 'USING CRON 0 6 15 10 * America/New_York'   -- 15 October, after the EIA release
AS
INSERT INTO RELIABILITY.MART.TEST_RESULTS
SELECT CURRENT_TIMESTAMP, 'T1', COUNT(*), '0', IFF(COUNT(*) = 0, 'pass', 'flag')
FROM (SELECT utility_key, year FROM RELIABILITY.MART.FCT_RELIABILITY GROUP BY 1,2 HAVING COUNT(*) > 1)
UNION ALL
SELECT CURRENT_TIMESTAMP, 'T4', COUNT(*), '0', IFF(COUNT(*) = 0, 'pass', 'flag')
FROM RELIABILITY.MART.FCT_RELIABILITY
WHERE utility_key = '19876|VA' AND year = 2025 AND NOT (saidi_all = 306.7 AND saidi_ex_med = 144.4);
-- add the rest the same way
```

The Data notes page then reads `TEST_RESULTS` instead of a typed sheet: tests write to a table, the dashboard reads the table.

## Change control

- Every change to a SQL file is a commit with a message that says what changed and which test proved it.
- `CHANGELOG.md` records what changed per load, the row counts and any test whose result moved.
- A definition change (a new event type in the storm index, a new peer) is a decision: add it to `docs/04_decisions.md` with the alternative considered.
- Dashboard screenshots are not committed. The PDF export of each presented version is kept outside the repo with its date.

## Known limitations, stated once

1. Dominion's major-event rule differs from IEEE 1366. Peer comparisons are indicative.
2. EIA-861 identifies utilities, not customers. "Data centre" is an inference from the shape of the load, not a label in the data.
3. The weather fit is ten points. It is a check on one year, not a model.
4. EIA-930's DOM zone includes co-ops that take power through Dominion's transmission. It is the load on Dominion's wires, slightly larger than Dominion's retail load.
5. Nothing here measures the effect of the grid transformation programme. It measures what the public annual number can and cannot show.

## Where the non-committed artefacts are

| Artefact | Location | Why not in the repo |
|---|---|---|
| `Dominion_Reliability.pbix` (Import and DirectQuery copies) | Build machine, with a dated PDF export kept beside each presented version | Binary, embeds connection details |
| NOAA and EIA-930 raw downloads | `data/raw/` locally, ignored by git | 560 MB; scripts re-create them |
| Snowflake account | Personal trial, `RELIABILITY` database | Credentials |
