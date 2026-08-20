#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 SNAPSHOT_DIR DISTRIBUTION_VERSION_DIR" >&2
  exit 64
fi

SNAPSHOT_DIR=$1
DISTRIBUTION_DIR=$2
SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
bash "$SKILL_ROOT/scripts/verify-archive-manifest.sh" "$SNAPSHOT_DIR"
for required in "$SNAPSHOT_DIR/snapshot-checksums.sha256" "$DISTRIBUTION_DIR/distribution-checksums.sha256"; do
  [ -f "$required" ] || { echo "PUBLICATION_VERIFY=FAIL missing=$required" >&2; exit 66; }
done

(
  cd "$SNAPSHOT_DIR"
  shasum -a 256 -c snapshot-checksums.sha256 >/dev/null
)
(
  cd "$DISTRIBUTION_DIR"
  shasum -a 256 -c distribution-checksums.sha256 >/dev/null
)

for root in "$SNAPSHOT_DIR" "$DISTRIBUTION_DIR"; do
  while IFS= read -r -d '' path; do
    if [ -w "$path" ]; then
      echo "PUBLICATION_VERIFY=FAIL writable_after_freeze=$path" >&2
      exit 65
    fi
  done < <(find "$root" -print0)
done

python3 - "$SNAPSHOT_DIR" "$DISTRIBUTION_DIR" <<'PY'
from pathlib import Path
import hashlib
import json
import re
import sys

snapshot = Path(sys.argv[1]).resolve()
distribution = Path(sys.argv[2]).resolve()
manifest_path = snapshot / 'archive-manifest.json'
if not manifest_path.is_file():
    raise SystemExit('PUBLICATION_VERIFY=FAIL missing_archive_manifest')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
for field in ('archive_id', 'source_version', 'source_article_sha256', 'snapshot_article', 'snapshot_article_sha256'):
    if not manifest.get(field):
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL invalid_archive_manifest_field={field}')
article = snapshot / manifest['snapshot_article']
if not article.is_file() or hashlib.sha256(article.read_bytes()).hexdigest() != manifest['snapshot_article_sha256']:
    raise SystemExit('PUBLICATION_VERIFY=FAIL archive_article_hash_mismatch')
expected_pointer = f'published/{snapshot.name}/{manifest["snapshot_article"]}'
copy_files = sorted(distribution.glob('公众号推荐语*.md'))
if not copy_files:
    raise SystemExit('PUBLICATION_VERIFY=FAIL no_publication_copy')
versions = []
for path in copy_files:
    text = path.read_text(encoding='utf-8')
    match = re.search(r'^- `copy_version`：`copy-v(\d+)`$', text, re.M)
    if not match:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL missing_copy_version={path.name}')
    version = int(match.group(1))
    expected = '公众号推荐语.md' if version == 1 else f'公众号推荐语-copy-v{version}.md'
    if path.name != expected:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL version_filename_mismatch={path.name}')
    if version in versions:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL duplicate_copy_version=copy-v{version}')
    versions.append(version)
    if f'- `asset_pointer`：`{expected_pointer}`' not in text:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL stale_or_invalid_asset_pointer={path.name}')
    if '- `review_result`：`PASS`' not in text:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL copy_not_passed={path.name}')
    body = re.search(r'^## 推荐语\n\n(.*?)\n\n## 质量审核', text, re.M | re.S)
    if not body:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL missing_recommendation_body={path.name}')
    visible = len(''.join(body.group(1).split()))
    if visible > 120:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL copy_too_long={path.name}:{visible}')
    declared = re.search(r'^- 可见字符数：(\d+)。$', text, re.M)
    if not declared or int(declared.group(1)) != visible:
        raise SystemExit(f'PUBLICATION_VERIFY=FAIL visible_count_mismatch={path.name}:{visible}')

if sorted(versions) != list(range(1, max(versions) + 1)):
    raise SystemExit('PUBLICATION_VERIFY=FAIL copy_version_gap')
print(f'PUBLICATION_VERIFY=PASS snapshot={snapshot.name} copy_versions={len(versions)}')
PY
