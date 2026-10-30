"""Run the EIA reliability pipeline (SQL 01-04) in a local DuckDB database.

Rebuilds the core reliability mart and checks six tests. It does not verify
the full NOAA/EIA-930 pipeline, which requires additional raw downloads.
Dialect differences are
patched (TRY_TO_NUMBER, YEAR(), schema names, file formats). Covers the
reliability mart; the NOAA (05) and EIA-930 (06, 07) steps run in Snowflake.
Run with: pip install -r requirements.txt && python -I scripts/run_local_duckdb.py
"""
import duckdb, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
DATA = str(ROOT / "data" / "input") + "/"
SQL = str(ROOT / "sql") + "/"
con = duckdb.connect()
T = DATA

def translate(sql):
    # strip Snowflake-only setup
    sql = re.sub(r"CREATE DATABASE.*?;|CREATE SCHEMA.*?;|USE WAREHOUSE.*?;", "", sql, flags=re.S)
    sql = re.sub(r"CREATE OR REPLACE FILE FORMAT.*?;", "", sql, flags=re.S)
    sql = re.sub(r"CREATE (OR REPLACE )?STAGE.*?;", "", sql, flags=re.S)
    sql = sql.replace(" COPY GRANTS AS", " AS")   # Snowflake-only clause
    sql = sql.replace("RELIABILITY.RAW.", "raw.").replace("RELIABILITY.STG.", "stg.").replace("RELIABILITY.MART.", "mart.")
    # TRY_TO_NUMBER(x, p, s) -> TRY_CAST(x AS DECIMAL(p,s)); TRY_TO_NUMBER(x) -> TRY_CAST(x AS BIGINT)
    sql = re.sub(r"TRY_TO_NUMBER\(([^()]*(?:\([^()]*\))?[^()]*),\s*(\d+),\s*(\d+)\)", r"TRY_CAST(\1 AS DECIMAL(\2,\3))", sql)
    sql = re.sub(r"TRY_TO_NUMBER\(([^()]*(?:\([^()]*\))?[^()]*)\)", r"TRY_CAST(\1 AS BIGINT)", sql)
    sql = re.sub(r"TRY_TO_DATE\(([^()]*)\)", r"TRY_CAST(\1 AS DATE)", sql)
    sql = re.sub(r"TRY_TO_BOOLEAN\(([^()]*)\)", r"TRY_CAST(\1 AS BOOLEAN)", sql)
    sql = re.sub(r"YEAR\(", "year(", sql)
    sql = sql.replace("NULL::VARCHAR", "CAST(NULL AS VARCHAR)").replace("NULL::BOOLEAN", "CAST(NULL AS BOOLEAN)")
    return sql

con.execute("CREATE SCHEMA raw; CREATE SCHEMA stg; CREATE SCHEMA mart;")
# 01: create raw tables, then load CSVs the way COPY INTO would (all text, NULL_IF)
sql01 = translate(open(SQL + "01_raw_staging.sql").read())
creates = [s for s in sql01.split(";") if "CREATE OR REPLACE TABLE" in s]
for s in creates: con.execute(s)
con.execute(f"INSERT INTO raw.EIA861_RELIABILITY_2025 SELECT * FROM read_csv('{T}Reliability_2025_States.csv', skip=3, header=false, all_varchar=true, nullstr=['.',''])")
for tbl, f in [("PUDL_RELIABILITY","pudl_reliability_2013_2024.csv"),("PUDL_AMI","pudl_ami.csv"),("PUDL_SALES","pudl_sales.csv")]:
    con.execute(f"INSERT INTO raw.{tbl} SELECT * FROM read_csv('{T}{f}', header=true, all_varchar=true, nullstr=['','<NA>','NULL'])")
print("raw rows:", {t: con.execute(f"select count(*) from raw.{t}").fetchone()[0] for t in ["EIA861_RELIABILITY_2025","PUDL_RELIABILITY","PUDL_AMI","PUDL_SALES"]})
views = [s for s in sql01.split(";") if "CREATE OR REPLACE VIEW" in s]
for s in views: con.execute(s)
# 02
for s in translate(open(SQL + "02_mart.sql").read()).split(";"):
    if s.strip(): con.execute(s)
print("fact rows:", con.execute("select count(*), min(year), max(year) from mart.FCT_RELIABILITY").fetchone())
# 03 analysis: strip SQL comments before deciding whether the statement returns rows.
# Earlier code silently skipped queries whose first line was a comment.
print("\n==== ANALYSIS (Q1-Q5) ====")
sql03 = translate((ROOT / "sql" / "03_analysis.sql").read_text())
for block in sql03.split(";"):
    label = re.search(r"(?m)^\s*--\s*(Q\d+[a-z]?)", block)
    stmt = re.sub(r"(?m)^\s*--[^\n]*(?:\n|$)", "", block).strip()
    if not stmt:
        continue
    try:
        res = con.execute(stmt)
    except Exception as exc:
        print("FAILED analysis", label.group(1) if label else "", str(exc), file=sys.stderr)
        sys.exit(1)
    if stmt.upper().startswith(("SELECT", "WITH")):
        print("\n", label.group(1) if label else "Analysis")
        print(res.df().to_string(index=False))

# 04 tests: assert expected row counts rather than merely printing them.
# T3 contains four documented source anomalies; T5 returns one row per year.
expected_rows = {"T1": 0, "T2": 0, "T3": 4, "T4": 0, "T5": 13, "T6": 0}
observed = {}
print("\n==== TESTS ====")
sql04 = translate((ROOT / "sql" / "04_tests.sql").read_text())
for block in sql04.split(";"):
    match = re.search(r"(?m)^\s*--\s*(T[1-6])\.", block)
    stmt = re.sub(r"(?m)^\s*--[^\n]*(?:\n|$)", "", block).strip()
    if not stmt:
        continue
    if not match:
        raise RuntimeError("Unlabelled data-quality test; give it a T1-T6 label")
    name = match.group(1)
    df = con.execute(stmt).df()
    observed[name] = len(df)
    status = "PASS" if len(df) == expected_rows[name] else "FAIL"
    print(f"{name}: {status} ({len(df)} rows; expected {expected_rows[name]})")
    if status == "FAIL" or (name == "T3" and len(df)):
        print(df.to_string(index=False))

missing = set(expected_rows) - set(observed)
if missing:
    raise RuntimeError(f"Missing tests: {sorted(missing)}")
bad = {k: (v, expected_rows[k]) for k, v in observed.items() if v != expected_rows[k]}
if bad:
    raise RuntimeError(f"Reliability tests failed (observed, expected): {bad}")
dominion_count = con.execute(
    "SELECT COUNT(*) FROM mart.FCT_RELIABILITY WHERE utility_key='19876|VA' AND year=2025"
).fetchone()[0]
if dominion_count != 1:
    raise RuntimeError(f"Expected one Dominion VA 2025 record, found {dominion_count}")
# Business-critical figure checks: make sure the rolling averages and
# decomposition printed in the README still agree with the actual mart.
dom = dict(con.execute(
    "SELECT year, saidi_ex_med FROM mart.FCT_RELIABILITY "
    "WHERE utility_key = '19876|VA' AND year BETWEEN 2022 AND 2025"
).fetchall())
for year, expected in ((2022, 136.047), (2023, 123.322), (2024, 131.300), (2025, 144.400)):
    if abs(dom.get(year, float("nan")) - expected) > 0.002:
        raise RuntimeError(f"Dominion VA SAIDI mismatch: {year} expected {expected}, found {dom.get(year)}")

avg_2024 = sum(dom[y] for y in (2022, 2023, 2024)) / 3
avg_2025 = sum(dom[y] for y in (2023, 2024, 2025)) / 3
if abs(avg_2024 - 130.2) > 0.06 or abs(avg_2025 - 133.0) > 0.06:
    raise RuntimeError(f"Rolling SAIDI averages changed: {avg_2024}, {avg_2025}")

# The near-zero SAIDI change in 2019 made the original share metric
# show an uninterpretable value near -2,570%.
share_2019 = con.execute(
    "SELECT frequency_share_of_change FROM mart.V_TREND "
    "WHERE utility_key = '19876|VA' AND year = 2019"
).fetchone()[0]
if share_2019 is not None:
    raise RuntimeError(f"Expected suppressed near-zero 2019 frequency share, got {share_2019}")
print(f"Business check: rolling SAIDI averages = {avg_2024:.1f} and {avg_2025:.1f} minutes.")
print("Core reliability checks passed. NOAA/EIA-930 checks require the full Snowflake pipeline.")
