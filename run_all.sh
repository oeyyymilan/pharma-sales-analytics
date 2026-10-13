#!/usr/bin/env bash
# Rebuilds the whole database from the raw CSVs.  Usage: ./run_all.sh [mysql_user]   (prompts for password)
# Run from the repo root so LOAD DATA paths resolve.
set -euo pipefail
U="${1:-root}"
python3 data/generate_data.py            # optional: regenerates data/raw/*.csv (seeded, so identical each time)
for f in 01_schema 02_load_data 03_cleaning 05_powerbi_views; do
  echo ">>> sql/$f.sql"
  mysql --local-infile=1 -u "$U" -p < "sql/$f.sql"
done
echo ">>> done. Run sql/04_analysis_queries.sql for the business answers."
