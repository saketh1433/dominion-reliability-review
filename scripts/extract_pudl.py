"""Rebuild data/input/pudl_*.csv from PUDL's published parquet tables.

PUDL (Catalyst Cooperative) publishes cleaned EIA-861 tables as parquet. This
script pulls the three tables the mart needs and writes them as CSV with every
column as text, which is how RAW expects them. If the bucket layout changes,
the current access instructions are at https://catalystcoop-pudl.readthedocs.io/
(Data Access). Run with: python -I scripts/extract_pudl.py
"""
import sys
from pathlib import Path
import duckdb

BUCKET = "https://s3.us-west-2.amazonaws.com/pudl.catalyst.coop/stable"
TABLES = {
    "core_eia861__yearly_reliability": ("pudl_reliability_2013_2024.csv", "report_date BETWEEN '2013-01-01' AND '2024-12-31'"),
    "core_eia861__yearly_advanced_metering_infrastructure": ("pudl_ami.csv", "report_date >= '2013-01-01'"),
    "core_eia861__yearly_sales": ("pudl_sales.csv", "report_date >= '2013-01-01'"),
}
out = Path(__file__).resolve().parent.parent / "data" / "input"
out.mkdir(parents=True, exist_ok=True)
con = duckdb.connect()
con.execute("INSTALL httpfs; LOAD httpfs;")
for table, (fname, where) in TABLES.items():
    url = f"{BUCKET}/{table}.parquet"
    print(f"{table} -> {fname}")
    try:
        n = con.execute(f"COPY (SELECT * FROM read_parquet('{url}') WHERE {where}) TO '{out / fname}' (HEADER, DELIMITER ',')").fetchall()
        print("  rows:", con.execute(f"SELECT COUNT(*) FROM read_csv('{out / fname}', all_varchar=true)").fetchone()[0])
    except Exception as e:
        print("  failed:", e, file=sys.stderr)
        print("  download the parquet by hand from the PUDL data access page and point BUCKET at the local folder", file=sys.stderr)
print("expected rows: 24358, 127720, 198770")
