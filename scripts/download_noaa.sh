#!/usr/bin/env bash
# Download the NOAA Storm Events "details" files for 2013 to 2025 into data/raw/noaa/.
# File names carry a creation stamp (_cYYYYMMDD) that changes when NOAA re-issues a
# year, so the script reads the directory listing to find the current names.
set -euo pipefail
BASE="https://www.ncei.noaa.gov/pub/data/swdi/stormevents/csvfiles"
OUT="$(dirname "$0")/../data/raw/noaa"
mkdir -p "$OUT" && cd "$OUT"
curl -fsSL "$BASE/" \
  | grep -o 'StormEvents_details-ftp_v1\.0_d20\(1[3-9]\|2[0-5]\)_c[0-9]\{8\}\.csv\.gz' \
  | sort -u \
  | while read -r f; do
      echo "fetching $f"
      curl -fsSLO "$BASE/$f"
    done
echo "---"
ls -lh
echo "expected: 13 files, 831,288 rows together after COPY INTO"
