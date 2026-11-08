#!/usr/bin/env bash
# Полный ELT-цикл: extract -> load -> transform (SQL внутри ClickHouse)
set -euo pipefail

CH="docker exec -i ch-elt clickhouse-client --user analyst --password analyst_pass"

$CH < sql/01_raw.sql
python scripts/extract.py
python scripts/load.py
$CH < sql/02_staging.sql
$CH < sql/03_marts.sql
$CH < sql/04_queries.sql

echo "ELT-пайплайн выполнен."
