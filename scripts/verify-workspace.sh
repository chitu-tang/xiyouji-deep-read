#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 WORKSPACE_ROOT" >&2
  exit 64
fi

WORKSPACE_ROOT=$1
CONFIG="$WORKSPACE_ROOT/xiyouji-longform-workspace.yaml"
REGISTRY="$WORKSPACE_ROOT/references/人民文学出版社2020年版-西游记-正式底本注册表.md"
VOLUMES="$WORKSPACE_ROOT/references/正式底本卷册清单.tsv"

for required in "$CONFIG" "$REGISTRY" "$VOLUMES" "$WORKSPACE_ROOT/深解读资产卡.md"; do
  [ -f "$required" ] || { echo "HARD_STOP: missing required workspace asset: $required" >&2; exit 66; }
done
for dir in research drafts audits revisions state published distribution references; do
  [ -d "$WORKSPACE_ROOT/$dir" ] || { echo "HARD_STOP: missing workspace directory: $dir" >&2; exit 66; }
done

config_value() {
  local key=$1
  awk -v key="$key" 'index($0, key ": ") == 1 {print substr($0, length(key) + 3); exit}' "$CONFIG"
}
valid_value() {
  case "$1" in
    ''|待填|PENDING|*'{{'*|*'}}'*) return 1 ;;
    *) return 0 ;;
  esac
}

SCHEMA=$(config_value workspace_schema)
[ "$SCHEMA" = "xiyouji-longform-workspace/v2" ] || { echo "HARD_STOP: unsupported workspace schema" >&2; exit 65; }
for key in formal_source_set_id formal_source_title formal_source_author formal_source_publisher formal_source_edition formal_source_isbn formal_source_registry formal_sources_file; do
  value=$(config_value "$key")
  valid_value "$value" || { echo "HARD_STOP: incomplete formal-source configuration: $key" >&2; exit 65; }
done
[ "$(config_value formal_source_registry)" = "references/人民文学出版社2020年版-西游记-正式底本注册表.md" ] || { echo "HARD_STOP: unexpected formal-source registry path" >&2; exit 65; }
[ "$(config_value formal_sources_file)" = "references/正式底本卷册清单.tsv" ] || { echo "HARD_STOP: unexpected formal-source volume manifest path" >&2; exit 65; }

python3 - "$CONFIG" "$REGISTRY" "$VOLUMES" <<'PY'
from pathlib import Path
import csv
import hashlib
import subprocess
import sys

config_path, registry_path, volumes_path = map(Path, sys.argv[1:])
config = {}
for line in config_path.read_text(encoding='utf-8').splitlines():
    if ': ' in line and not line.startswith((' ', '\t', '#')):
        key, value = line.split(': ', 1)
        config[key] = value
required = ('formal_source_title', 'formal_source_author', 'formal_source_publisher', 'formal_source_edition', 'formal_source_isbn')
for key in required:
    value = config.get(key, '')
    if not value or value in {'待填', 'PENDING'} or '{{' in value or '}}' in value:
        raise SystemExit(f'HARD_STOP: invalid bibliographic configuration: {key}')
registry = registry_path.read_text(encoding='utf-8')
for key, label in (('formal_source_title', '书名'), ('formal_source_author', '作者'), ('formal_source_publisher', '出版社'), ('formal_source_edition', '版次'), ('formal_source_isbn', 'ISBN')):
    literal = f'- {label}：`{config[key]}`'
    if literal not in registry:
        raise SystemExit(f'HARD_STOP: registry metadata mismatch: {key}')
with volumes_path.open(encoding='utf-8', newline='') as f:
    rows = list(csv.DictReader(f, delimiter='\t'))
expected_fields = ('volume', 'formal_source_path', 'formal_source_sha256', 'pdf_page_count', 'registry_row')
if len(rows) != 3 or tuple(rows[0].keys()) != expected_fields:
    raise SystemExit('HARD_STOP: formal volume manifest must contain exactly three strict TSV columns/rows')
expected_volumes = ('上册', '中册', '下册')
if tuple(row['volume'] for row in rows) != expected_volumes:
    raise SystemExit('HARD_STOP: formal volume manifest must be ordered 上册、中册、下册')
for row in rows:
    path = Path(row['formal_source_path'])
    if not path.is_file():
        raise SystemExit(f'HARD_STOP: formal source unavailable: {path}')
    if len(row['formal_source_sha256']) != 64 or any(c not in '0123456789abcdef' for c in row['formal_source_sha256']):
        raise SystemExit(f'HARD_STOP: invalid formal source SHA-256: {row["volume"]}')
    if hashlib.sha256(path.read_bytes()).hexdigest() != row['formal_source_sha256']:
        raise SystemExit(f'HARD_STOP: formal source SHA-256 mismatch: {row["volume"]}')
    try:
        declared_pages = int(row['pdf_page_count'])
    except ValueError:
        raise SystemExit(f'HARD_STOP: invalid declared PDF page count: {row["volume"]}')
    content_type = subprocess.check_output(['mdls', '-name', 'kMDItemContentType', str(path)], text=True).strip()
    if 'com.adobe.pdf' not in content_type:
        raise SystemExit(f'HARD_STOP: formal source is not a PDF: {row["volume"]}')
    page_line = subprocess.check_output(['mdls', '-name', 'kMDItemNumberOfPages', str(path)], text=True).strip()
    actual_pages = int(page_line.rsplit('=', 1)[1].strip())
    if actual_pages != declared_pages:
        raise SystemExit(f'HARD_STOP: PDF page-count mismatch: {row["volume"]}: expected={declared_pages} actual={actual_pages}')
    registry_literal = f'| {row["volume"]} | `{row["formal_source_path"]}` | {row["pdf_page_count"]} | `{row["formal_source_sha256"]}` |'
    if registry_literal not in registry:
        raise SystemExit(f'HARD_STOP: registry volume row mismatch: {row["volume"]}')
print('WORKSPACE_VERIFY=PASS schema=v2 formal_volumes=3 pdf_identity=PASS bibliography=PASS')
PY
