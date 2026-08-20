#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: $0 SNAPSHOT_DIR [SOURCE_ARTICLE]" >&2
  exit 64
fi

SNAPSHOT_DIR=$1
SOURCE_ARTICLE=${2:-}
MANIFEST="$SNAPSHOT_DIR/archive-manifest.json"
CHECKSUMS="$SNAPSHOT_DIR/snapshot-checksums.sha256"
[ -f "$MANIFEST" ] && [ -f "$CHECKSUMS" ] || { echo "ARCHIVE_VERIFY=FAIL missing_manifest_or_checksums" >&2; exit 66; }
(
  cd "$SNAPSHOT_DIR"
  shasum -a 256 -c snapshot-checksums.sha256 >/dev/null
)
python3 - "$MANIFEST" "$SNAPSHOT_DIR" "$SOURCE_ARTICLE" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

manifest_path = Path(sys.argv[1])
snapshot = Path(sys.argv[2])
source_arg = sys.argv[3]
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
required = ('archive_id', 'source_version', 'source_article_sha256', 'snapshot_article', 'snapshot_article_sha256', 'archive_asset_plan_sha256', 'archive_assets')
if any(not manifest.get(field) for field in required):
    raise SystemExit('ARCHIVE_VERIFY=FAIL invalid_manifest')
assets = manifest['archive_assets']
if not isinstance(assets, list) or not assets:
    raise SystemExit('ARCHIVE_VERIFY=FAIL invalid_archive_assets')
expected = []
for item in assets:
    if not isinstance(item, dict) or tuple(item.keys()) != ('snapshot_filename', 'role', 'version_status'):
        raise SystemExit('ARCHIVE_VERIFY=FAIL invalid_archive_asset_entry')
    name = item['snapshot_filename']
    if not name or Path(name).name != name or name == '审核报告.md':
        raise SystemExit('ARCHIVE_VERIFY=FAIL ambiguous_or_invalid_archive_asset_filename')
    expected.append(name)
if len(set(expected)) != len(expected):
    raise SystemExit('ARCHIVE_VERIFY=FAIL duplicate_archive_asset')
actual = sorted(path.name for path in snapshot.iterdir() if path.is_file() and path.name not in {'archive-manifest.json', 'snapshot-checksums.sha256'})
if sorted(expected) != actual:
    raise SystemExit('ARCHIVE_VERIFY=FAIL snapshot_asset_set_differs_from_manifest')
article_entries = [item for item in assets if item['role'] == 'article' and item['version_status'] == 'current']
if len(article_entries) != 1 or article_entries[0]['snapshot_filename'] != manifest['snapshot_article']:
    raise SystemExit('ARCHIVE_VERIFY=FAIL invalid_current_article_entry')
article = snapshot / manifest['snapshot_article']
if not article.is_file() or hashlib.sha256(article.read_bytes()).hexdigest() != manifest['snapshot_article_sha256']:
    raise SystemExit('ARCHIVE_VERIFY=FAIL snapshot_article_hash_mismatch')
if source_arg:
    source = Path(source_arg)
    if not source.is_file():
        raise SystemExit('ARCHIVE_VERIFY=FAIL source_article_missing')
    if hashlib.sha256(source.read_bytes()).hexdigest() != manifest['source_article_sha256']:
        raise SystemExit('ARCHIVE_VERIFY=FAIL source_article_hash_mismatch')
print('ARCHIVE_VERIFY=PASS archive_id=' + manifest['archive_id'] + ' asset_plan=PASS assets=' + str(len(assets)))
PY
