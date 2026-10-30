"""Validate the small annual summaries committed with this project.

This checks arithmetic and that the saved CSVs agree with each other.
It does not rebuild the NOAA or EIA-930 raw-data pipelines.
"""
import csv
from math import isclose, sqrt
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data" / "output"


def rows(filename):
    with (OUT / filename).open(newline="", encoding="utf-8") as stream:
        records = list(csv.DictReader(stream))
    assert records, f"{filename} contains no rows"
    return records


def check(condition, message):
    if not condition:
        raise AssertionError(message)
    print("PASS:", message)


storm = {int(r["year"]): r for r in rows("storm_index.csv")}
paired = {int(r["year"]): r for r in rows("storm_vs_saidi.csv")}
check(set(storm) == set(paired) == set(range(2013, 2026)), "2013-2025 complete and matching")
for year in storm:
    for col in ("storm_county_days", "wind_days", "winter_days", "tropical_days", "severe_gust_days"):
        check(storm[year][col] == paired[year][col], f"{year} {col} matches the annual index")
check(int(storm[2024]["storm_county_days"]) == 465, "2024 storm county-days = 465")
check(int(storm[2025]["storm_county_days"]) == 796, "2025 storm county-days = 796")

training = [paired[y] for y in range(2015, 2025)]
x = [float(r["storm_county_days"]) for r in training]
y = [float(r["saidi_ex_med"]) for r in training]
mx, my = sum(x) / len(x), sum(y) / len(y)
ssx = sum((v - mx) ** 2 for v in x)
ssy = sum((v - my) ** 2 for v in y)
cross = sum((a - mx) * (b - my) for a, b in zip(x, y))
slope = cross / ssx
intercept = my - slope * mx
r = cross / sqrt(ssx * ssy)
pred_2025 = intercept + slope * float(paired[2025]["storm_county_days"])
actual_2025 = float(paired[2025]["saidi_ex_med"])
adjusted_2025 = actual_2025 - pred_2025 + my
check(0.69 < r < 0.71, f"2015-2024 Pearson correlation = {r:.3f}")
check(0.050 < slope < 0.053, f"2015-2024 regression slope = {slope:.4f}")
check(isclose(pred_2025, 145.3, abs_tol=0.15), f"2025 holdout prediction = {pred_2025:.2f} minutes")
check(isclose(actual_2025, 144.4, abs_tol=0.001), "2025 actual SAIDI ex-MED = 144.4")
check(isclose(adjusted_2025, 133.1, abs_tol=0.2), f"exploratory adjusted SAIDI = {adjusted_2025:.2f}")
print("NOTE: regression checks confirm calculations, not weather causality.")

load = {int(r["yr"]): r for r in rows("dom_annual.csv")}
check(2019 in load and 2025 in load, "DOM annual demand has 2019 and 2025")
check(float(load[2019]["floor_mw"]) == 7167, "2019 minimum hourly demand = 7167 MW")
check(float(load[2025]["floor_mw"]) == 10903, "2025 minimum hourly demand = 10903 MW")
peak19 = max(float(load[2019]["winter_peak_mw"]), float(load[2019]["summer_peak_mw"]))
peak25 = max(float(load[2025]["winter_peak_mw"]), float(load[2025]["summer_peak_mw"]))
check(peak19 == 19803 and peak25 == 24957, "DOM annual peaks match source output")
check(isclose((peak25 / peak19 - 1) * 100, 26, abs_tol=0.1), "peak-hour demand growth rounds to 26%")
check(isclose((10903 / 7167 - 1) * 100, 52, abs_tol=0.2), "minimum-hour demand growth rounds to 52%")
print("All committed-output checks passed.")
