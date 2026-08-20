#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "usage: $0 SNAPSHOT_DIR SOURCE_ARTICLE SOURCE_VERSION ASSET_PLAN_TSV" >&2
  exit 64
fi

SNAPSHOT_DIR=$1
SOURCE_ARTICLE=$2
SOURCE_VERSION=$3
ASSET_PLAN=$4
[ -d "$SNAPSHOT_DIR" ] || { echo "ARCHIVE_MANIFEST=FAIL snapshot_missing" >&2; exit 66; }
[ -f "$SOURCE_ARTICLE" ] || { echo "ARCHIVE_MANIFEST=FAIL source_missing" >&2; exit 66; }
[ -f "$ASSET_PLAN" ] || { echo "ARCHIVE_MANIFEST=FAIL asset_plan_missing" >&2; exit 66; }
SOURCE_SHA=$(shasum -a 256 "$SOURCE_ARTICLE" | awk '{print $1}')
PLAN_SHA=$(shasum -a 256 "$ASSET_PLAN" | awk '{print $1}')

python3 - "$SNAPSHOT_DIR" "$SOURCE_ARTICLE" "$SOURCE_VERSION" "$SOURCE_SHA" "$ASSET_PLAN" "$PLAN_SHA" <<'PY'
from pathlib import Path
import csv
import hashlib
import json
import re
import sys

snapshot = Path(sys.argv[1])
source = Path(sys.argv[2])
source_version = sys.argv[3]
source_sha = sys.argv[4]
plan_path = Path(sys.argv[5])
plan_sha = sys.argv[6]
expected_fields = ('snapshot_filename', 'role', 'version_status')
allowed_roles = {'article', 'evidence', 'research', 'review', 'revision', 'metadata'}
allowed_status = {'current', 'historical_superseded'}
with plan_path.open(encoding='utf-8', newline='') as fh:
    rows = list(csv.DictReader(fh, delimiter='\t'))
if not rows or tuple(rows[0].keys()) != expected_fields:
    raise SystemExit('ARCHIVE_MANIFEST=FAIL invalid_asset_plan_schema')
assets = []
for row in rows:
    name, role, status = (row[key] for key in expected_fields)
    if not name or Path(name).name != name or name in {'archive-manifest.json', 'snapshot-checksums.sha256'}:
        raise SystemExit(f'ARCHIVE_MANIFEST=FAIL invalid_asset_plan_filename={name}')
    if name == '审核报告.md':
        raise SystemExit('ARCHIVE_MANIFEST=FAIL ambiguous_generic_audit_filename')
    if role not in allowed_roles or status not in allowed_status:
        raise SystemExit(f'ARCHIVE_MANIFEST=FAIL invalid_asset_plan_role_or_status={name}')
    if status == 'historical_superseded' and not re.search(r'v\d+', name):
        raise SystemExit(f'ARCHIVE_MANIFEST=FAIL superseded_asset_requires_versioned_filename={name}')
    assets.append({'snapshot_filename': name, 'role': role, 'version_status': status})
if len({item['snapshot_filename'] for item in assets}) != len(assets):
    raise SystemExit('ARCHIVE_MANIFEST=FAIL duplicate_asset_plan_filename')
article_entries = [item for item in assets if item['role'] == 'article']
if len(article_entries) != 1 or article_entries[0]['version_status'] != 'current':
    raise SystemExit('ARCHIVE_MANIFEST=FAIL asset_plan_requires_one_current_article')
article_name = article_entries[0]['snapshot_filename']
article = snapshot / article_name
if not article.is_file() or not article_name.startswith('长文-'):
    raise SystemExit('ARCHIVE_MANIFEST=FAIL planned_article_missing_or_invalid')
if hashlib.sha256(article.read_bytes()).hexdigest() != source_sha:
    raise SystemExit('ARCHIVE_MANIFEST=FAIL source_snapshot_content_mismatch')
actual = sorted(path.name for path in snapshot.iterdir() if path.is_file() and path.name not in {'archive-manifest.json', 'snapshot-checksums.sha256'})
planned = sorted(item['snapshot_filename'] for item in assets)
if actual != planned:
    raise SystemExit('ARCHIVE_MANIFEST=FAIL snapshot_asset_set_differs_from_plan')
archive_id = hashlib.sha256(f'{snapshot.name}:{source_version}:{source_sha}'.encode()).hexdigest()
manifest = {
    'archive_id': archive_id,
    'source_version': source_version,
    'source_article_sha256': source_sha,
    'snapshot_article': article_name,
    'snapshot_article_sha256': source_sha,
    'archive_asset_plan_sha256': plan_sha,
    'archive_assets': assets,
}
(snapshot / 'archive-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'ARCHIVE_ASSET_PLAN=PASS assets={len(assets)} plan_sha256={plan_sha}')
PY
(
  cd "$SNAPSHOT_DIR"
  find . -maxdepth 1 -type f ! -name 'snapshot-checksums.sha256' -print | LC_ALL=C sort | while IFS= read -r file; do shasum -a 256 "$file"; done > snapshot-checksums.sha256
)
printf 'ARCHIVE_MANIFEST=PASS archive_id=%s\n' "$(python3 - "$SNAPSHOT_DIR/archive-manifest.json" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding='utf-8'))['archive_id'])
PY
)"
