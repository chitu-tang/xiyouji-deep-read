#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 WORKSPACE_ROOT" >&2
  exit 64
fi

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
WORKSPACE_ROOT=$1
INDEX="$WORKSPACE_ROOT/references/百回导航索引.md"
CATALOG="$WORKSPACE_ROOT/references/百回目录核验清单.tsv"
VOLUMES="$WORKSPACE_ROOT/references/正式底本卷册清单.tsv"

bash "$SKILL_ROOT/scripts/verify-workspace.sh" "$WORKSPACE_ROOT"
for required in "$INDEX" "$CATALOG" "$VOLUMES"; do
  [ -f "$required" ] || { echo "HARD_STOP: missing 0A evidence asset: $required" >&2; exit 66; }
done

python3 - "$INDEX" "$CATALOG" "$VOLUMES" <<'PY'
from pathlib import Path
import csv
import hashlib
import re
import sys

index_path, catalog_path, volumes_path = map(Path, sys.argv[1:])
header = '| 回次 | 回目 | 卷册 | PDF起页 | PDF止页 | 书内起页 | 书内止页 | 目录PDF页 | 导航证据等级 | 核验 |'
separator = '|---:|---|---|---:|---:|---:|---:|---:|---|---|'
pattern = re.compile(r'^\|\s*(\d{1,3})\s*\|\s*(.*?)\s*\|\s*(上册|中册|下册)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(目录锚点、页码连续性及边界抽检)\s*\|\s*(NAVIGATION_CONFIRMED)\s*\|$')
lines = [line.strip() for line in index_path.read_text(encoding='utf-8').splitlines() if line.strip()]
if len(lines) != 102 or lines[0] != header or lines[1] != separator:
    raise SystemExit('HARD_STOP: navigation index must contain one strict header, separator, and exactly 100 records')
volumes = {}
with volumes_path.open(encoding='utf-8', newline='') as f:
    for row in csv.DictReader(f, delimiter='\t'):
        volumes[row['volume']] = int(row['pdf_page_count'])
with catalog_path.open(encoding='utf-8', newline='') as f:
    catalog_rows = list(csv.DictReader(f, delimiter='\t'))
if tuple(catalog_rows[0].keys()) != ('chapter', 'title', 'volume', 'book_start_page', 'toc_pdf_page', 'toc_verification') or len(catalog_rows) != 100:
    raise SystemExit('HARD_STOP: invalid chapter catalog schema')
expected = {}
for row in catalog_rows:
    chapter = int(row['chapter'])
    if chapter in expected or not 1 <= chapter <= 100 or row['toc_verification'] != 'PDF目录页视觉核验':
        raise SystemExit('HARD_STOP: invalid chapter catalog record')
    expected[chapter] = row
records = {}
for line_number, line in enumerate(lines[2:], start=3):
    match = pattern.match(line)
    if not match:
        raise SystemExit(f'HARD_STOP: invalid navigation index line {line_number}')
    chapter = int(match.group(1))
    title, volume = match.group(2), match.group(3)
    pdf_start, pdf_end, book_start, book_end, toc_pdf = map(int, match.groups()[3:8])
    if chapter in records:
        raise SystemExit(f'HARD_STOP: duplicate chapter record {chapter}')
    if chapter not in expected:
        raise SystemExit(f'HARD_STOP: unexpected chapter record {chapter}')
    catalog = expected[chapter]
    if (title, volume, book_start, toc_pdf) != (catalog['title'], catalog['volume'], int(catalog['book_start_page']), int(catalog['toc_pdf_page'])):
        raise SystemExit(f'HARD_STOP: navigation catalog mismatch for chapter {chapter}')
    if pdf_start > pdf_end or book_start > book_end or pdf_start < 1 or book_start < 1 or toc_pdf < 1:
        raise SystemExit(f'HARD_STOP: invalid page range for chapter {chapter}')
    if pdf_end > volumes[volume]:
        raise SystemExit(f'HARD_STOP: PDF range exceeds volume page count for chapter {chapter}')
    records[chapter] = (volume, pdf_start, pdf_end, book_start, book_end)
if set(records) != set(range(1, 101)):
    raise SystemExit('HARD_STOP: incomplete navigation index')
for chapter in range(1, 100):
    volume, _, _, _, book_end = records[chapter]
    next_volume, _, _, next_book_start, _ = records[chapter + 1]
    if volume == next_volume and book_end != next_book_start - 1:
        raise SystemExit(f'HARD_STOP: non-contiguous book-page ranges between chapter {chapter} and {chapter + 1}')
index_hash = hashlib.sha256(index_path.read_bytes()).hexdigest()
catalog_hash = hashlib.sha256(catalog_path.read_bytes()).hexdigest()
print(f'0A_PREFLIGHT=PASS chapters=100 formal_volumes=3 index_sha256={index_hash} catalog_sha256={catalog_hash}')
PY
