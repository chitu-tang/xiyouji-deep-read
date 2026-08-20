#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 8 ]; then
  echo "usage: $0 WORKSPACE_ROOT VOLUME_MANIFEST_TSV TITLE AUTHOR PUBLISHER EDITION ISBN SOURCE_SET_ID" >&2
  exit 64
fi

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
WORKSPACE_ROOT=$1
VOLUME_MANIFEST=$2
TITLE=$3
AUTHOR=$4
PUBLISHER=$5
EDITION=$6
ISBN=$7
SOURCE_SET_ID=$8
CONFIG="$WORKSPACE_ROOT/xiyouji-longform-workspace.yaml"

[ ! -e "$CONFIG" ] || { echo "refusing to overwrite existing workspace config: $CONFIG" >&2; exit 73; }
[ -f "$VOLUME_MANIFEST" ] || { echo "HARD_STOP: missing volume manifest: $VOLUME_MANIFEST" >&2; exit 66; }
for value in "$TITLE" "$AUTHOR" "$PUBLISHER" "$EDITION" "$ISBN" "$SOURCE_SET_ID"; do
  case "$value" in ''|待填|PENDING|*'{{'*|*'}}'*) echo 'HARD_STOP: complete bibliographic metadata is required' >&2; exit 65 ;; esac
done

python3 - "$VOLUME_MANIFEST" <<'PY'
from pathlib import Path
import csv
import hashlib
import subprocess
import sys
path = Path(sys.argv[1])
with path.open(encoding='utf-8', newline='') as f:
    rows = list(csv.DictReader(f, delimiter='\t'))
fields = ('volume', 'formal_source_path', 'formal_source_sha256', 'pdf_page_count', 'registry_row')
if len(rows) != 3 or not rows or tuple(rows[0].keys()) != fields or tuple(row['volume'] for row in rows) != ('上册', '中册', '下册'):
    raise SystemExit('HARD_STOP: volume manifest requires ordered 上册、中册、下册 and strict fields')
for row in rows:
    source = Path(row['formal_source_path'])
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != row['formal_source_sha256']:
        raise SystemExit(f'HARD_STOP: unreadable or mismatched formal source: {row["volume"]}')
    content_type = subprocess.check_output(['mdls', '-name', 'kMDItemContentType', str(source)], text=True)
    page_count = subprocess.check_output(['mdls', '-name', 'kMDItemNumberOfPages', str(source)], text=True).rsplit('=', 1)[1].strip()
    if 'com.adobe.pdf' not in content_type or page_count != row['pdf_page_count']:
        raise SystemExit(f'HARD_STOP: invalid formal PDF metadata: {row["volume"]}')
PY

mkdir -p "$WORKSPACE_ROOT"/{research,drafts,audits,revisions,state,published,distribution,references}
cp "$VOLUME_MANIFEST" "$WORKSPACE_ROOT/references/正式底本卷册清单.tsv"
cp "$SKILL_ROOT/templates/深解读资产卡-模板.md" "$WORKSPACE_ROOT/深解读资产卡.md"
for ref in 研究性长文-活人感规范.md 表达动作参考库.md 表达学习候选库.md 西游记-研究导航库.md; do
  cp "$SKILL_ROOT/references/$ref" "$WORKSPACE_ROOT/references/$ref"
done
{
  printf 'workspace_schema: xiyouji-longform-workspace/v2\n'
  printf 'formal_source_set_id: %s\n' "$SOURCE_SET_ID"
  printf 'formal_source_title: %s\nformal_source_author: %s\nformal_source_publisher: %s\nformal_source_edition: %s\nformal_source_isbn: %s\n' "$TITLE" "$AUTHOR" "$PUBLISHER" "$EDITION" "$ISBN"
  printf 'formal_source_registry: references/人民文学出版社2020年版-西游记-正式底本注册表.md\nformal_sources_file: references/正式底本卷册清单.tsv\n'
} > "$CONFIG"
{
  printf '# 《西游记》正式底本注册表\n\n'
  printf -- '- 书名：`%s`\n- 作者：`%s`\n- 出版社：`%s`\n- 版次：`%s`\n- ISBN：`%s`\n\n' "$TITLE" "$AUTHOR" "$PUBLISHER" "$EDITION" "$ISBN"
  printf '| 卷册 | 本地路径 | PDF 页数 | SHA-256 |\n|---|---|---:|---|\n'
  awk -F '\t' 'NR > 1 {printf "| %s | `%s` | %s | `%s` |\\n", $1, $2, $4, $3}' "$VOLUME_MANIFEST"
} > "$WORKSPACE_ROOT/references/人民文学出版社2020年版-西游记-正式底本注册表.md"
printf 'chapter\ttitle\tvolume\tbook_start_page\ttoc_pdf_page\ttoc_verification\n' > "$WORKSPACE_ROOT/references/百回目录核验清单.tsv"
printf '| 回次 | 回目 | 卷册 | PDF起页 | PDF止页 | 书内起页 | 书内止页 | 目录PDF页 | 导航证据等级 | 核验 |\n|---:|---|---|---:|---:|---:|---:|---:|---|---|\n' > "$WORKSPACE_ROOT/references/百回导航索引.md"
printf 'WORKSPACE_INIT=PASS schema=v2 formal_volumes=3 root=%s 0A_status=PENDING_REAL_NAVIGATION_EVIDENCE\n' "$WORKSPACE_ROOT"
