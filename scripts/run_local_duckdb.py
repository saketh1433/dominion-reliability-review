"""Run the core Snowflake SQL files (01 to 04) on DuckDB, locally, with no account.

Proves the mart logic end to end from data/input/. Only dialect differences are
patched (TRY_TO_NUMBER, YEAR(), schema names, file formats). Covers the
reliability mart; the NOAA (05) and EIA-930 (06, 07) steps run in Snowflake.
Run with: python -I scripts/run_local_duckdb.py   (pip install duckdb pandas)
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
# 03 analysis
sql03 = translate(open(SQL + "03_analysis.sql").read())
for block in re.split(r"\n(?=-- Q)", sql03):
    title = block.strip().split("\n")[0]
    for s in block.split(";"):
        if not s.strip() or s.strip().startswith("--") and "SELECT" not in s.upper(): continue
        try:
            res = con.execute(s)
            if s.strip().upper().lstrip("-").strip().startswith(("SELECT","WITH")):
                print("\n", title); print(res.df().to_string(index=False))
        except Exception as e:
            print("\nFAILED", title, e, s[:200]); sys.exit(1)
# 04 tests
print("\n==== TESTS")
for s in translate(open(SQL + "04_tests.sql").read()).split(";"):
    if "SELECT" in s.upper():
        name = re.search(r"-- (T\d\..*)", s)
        df = con.execute(s).df()
        print(name.group(1) if name else "", "->", len(df), "rows");
        if len(df) and len(df) < 20: print(df.to_string(index=False))
