#!/usr/bin/env bash
# Download the EIA-930 six-month "Subregion" files (hourly demand by subregion,
# every balancing authority) into data/raw/eia930/. Subregion reporting starts
# 1 July 2018, so 2018_Jan_Jun does not exist and is skipped.
set -euo pipefail
BASE="https://www.eia.gov/electricity/gridmonitor/sixMonthFiles"
OUT="$(dirname "$0")/../data/raw/eia930"
mkdir -p "$OUT" && cd "$OUT"
for y in $(seq 2018 "$(date +%Y)"); do
  for h in Jan_Jun Jul_Dec; do
    [ "$y" = 2018 ] && [ "$h" = Jan_Jun ] && continue
    f="EIA930_SUBREGION_${y}_${h}.csv"
    echo "fetching $f"
    curl -fsSLO "$BASE/$f" || echo "  not available yet: $f"
  done
done
# Remove any file that is an HTML error page rather than CSV
for f in *.csv; do
  if head -c 15 "$f" | grep -qi '<!doctype'; then echo "removing HTML page $f"; rm -f "$f"; fi
done
echo "---"
ls -lh
echo "expected: 17 files to Oct 2026, 6,077,232 rows together, 72,864 for PJM/DOM"
