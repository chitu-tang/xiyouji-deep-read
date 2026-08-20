#!/usr/bin/env bash
set -euo pipefail

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
required=(
  SKILL.md README.md RC-VALIDATION.md templates/深解读资产卡-模板.md templates/正式底本注册表-模板.md templates/归档资产计划-模板.tsv
  references/研究性长文-活人感规范.md references/表达动作参考库.md references/表达学习候选库.md references/西游记-研究导航库.md
  scripts/build-release-zip.sh scripts/init-workspace.sh scripts/verify-workspace.sh scripts/preflight-0a.sh scripts/verify-length-gate.sh
  scripts/verify-quote-closure.py scripts/create-archive-manifest.sh scripts/verify-archive-manifest.sh scripts/verify-release.sh scripts/verify-publication-assets.sh scripts/test-release.sh scripts/test-gates.sh
  modules/xiyouji-segment-selector/SKILL.md modules/xiyouji-research-collector/SKILL.md modules/xiyouji-angle-miner/SKILL.md modules/xiyouji-deep-explainer/SKILL.md modules/xiyouji-script-writer/SKILL.md modules/xiyouji-auditor/SKILL.md modules/xiyouji-publication-copy/SKILL.md
)
for rel in "${required[@]}"; do
  [ -f "$SKILL_ROOT/$rel" ] || { echo "RELEASE_VERIFY=FAIL missing=$rel" >&2; exit 66; }
done
if grep -R -n --exclude=verify-release.sh '/Users/' "$SKILL_ROOT" >/dev/null 2>&1; then
  echo 'RELEASE_VERIFY=FAIL machine_specific_absolute_path_found' >&2
  exit 65
fi
NAME=$(awk '/^name: / {print $2; exit}' "$SKILL_ROOT/SKILL.md")
[ "$NAME" = "xiyouji-chapter-longform" ] || { echo "RELEASE_VERIFY=FAIL invalid_name=$NAME" >&2; exit 65; }
for contract in 'xiyouji-longform-workspace/v2' 'formal_source_set_id' 'formal_sources_file' '正式底本卷册清单.tsv' '百回目录核验清单.tsv' 'body_char_start' 'body_char_end' 'archive_asset_plan_sha256'; do
  grep -R -Fq "$contract" "$SKILL_ROOT" || { echo "RELEASE_VERIFY=FAIL contract_missing=$contract" >&2; exit 65; }
done
if find "$SKILL_ROOT" -type d -name '__pycache__' -o -type f -name '*.pyc' | grep -q .; then
  echo 'RELEASE_VERIFY=FAIL generated_python_bytecode_found' >&2
  exit 65
fi
if find "$SKILL_ROOT" \( -name '._*' -o -name '.DS_Store' -o -name '__MACOSX' \) -print | grep -q .; then
  echo 'RELEASE_VERIFY=FAIL machine_metadata_found' >&2
  exit 65
fi
python3 - "$SKILL_ROOT/scripts/verify-quote-closure.py" <<'PY'
import ast
import sys
from pathlib import Path
ast.parse(Path(sys.argv[1]).read_text(encoding='utf-8'))
PY
for script in "$SKILL_ROOT"/scripts/*.sh; do
  bash -n "$script"
done
printf 'RELEASE_VERIFY=PASS schema=v2 formal_volumes=3 navigation_contract=PASS quote_identity=PASS archive_asset_plan=PASS\n'
