#!/usr/bin/env bash
set -euo pipefail

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/xiyouji-skill-gates.XXXXXX")
trap 'printf "GATE_TEST_SANDBOX_RETAINED=%s\\n" "$TMP_ROOT"' EXIT

make_article() {
  local output=$1 total=$2 appendix=${3:-0}
  python3 - "$output" "$total" "$appendix" <<'PY'
from pathlib import Path
import sys
out, total, appendix = Path(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3])
body = '甲' * (total - 4)
out.write_text('## 引言\n' + body + '\n---\n## 结语\n\n## 引用—主张映射\n' + '乙' * appendix + '\n', encoding='utf-8')
PY
}

make_article "$TMP_ROOT/lower.md" 5000 250
bash "$SKILL_ROOT/scripts/verify-length-gate.sh" "$TMP_ROOT/lower.md" STANDARD
make_article "$TMP_ROOT/upper.md" 7000
bash "$SKILL_ROOT/scripts/verify-length-gate.sh" "$TMP_ROOT/upper.md" STANDARD
make_article "$TMP_ROOT/rework.md" 4999
if bash "$SKILL_ROOT/scripts/verify-length-gate.sh" "$TMP_ROOT/rework.md" STANDARD >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL standard_4999_was_accepted' >&2; exit 65
fi
if VERIFY_LENGTH_GATE_TEST_PERL_OVERRIDE=1 bash "$SKILL_ROOT/scripts/verify-length-gate.sh" "$TMP_ROOT/lower.md" STANDARD >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL divergent_counters_were_accepted' >&2; exit 65
fi

ARTICLE="$TMP_ROOT/quote-article.md"
LEDGER="$TMP_ROOT/quote-ledger.tsv"
OCCURRENCES="$TMP_ROOT/quote-occurrences.tsv"
cat > "$ARTICLE" <<'EOF'
## 引言

他说：【Q01】“东行三步。”

## 结语

收束。

## 引用—主张映射
EOF
printf 'q_id\tledger_literal\nQ01\t东行三步。\nQ02\t西行三步。\n' > "$LEDGER"
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ01\t东行三步。\t16\t21\n' > "$OCCURRENCES"
python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES"
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ02\t西行三步。\t16\t21\n' > "$OCCURRENCES"
if python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES" >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL swapped_q_id_was_accepted' >&2; exit 65
fi
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ01\t东行三步。\t15\t20\n' > "$OCCURRENCES"
if python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES" >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL false_location_span_was_accepted' >&2; exit 65
fi
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ01\t东行三步。\t16\t21\n第二节\tQ01\t东行三步。\t16\t21\n' > "$OCCURRENCES"
if python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES" >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL duplicate_quote_instance_was_accepted' >&2; exit 65
fi
python3 - "$ARTICLE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(path.read_text(encoding='utf-8').replace('【Q01】“东行三步。”', '“东行三步。”'), encoding='utf-8')
PY
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ01\t东行三步。\t10\t15\n' > "$OCCURRENCES"
if python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES" >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL untagged_quote_was_accepted' >&2; exit 65
fi
cat > "$ARTICLE" <<'EOF'
## 引言

他说：【Q01】“东行三步。” 旁注：【注】“未登记引文。”

## 结语

收束。

## 引用—主张映射
EOF
printf 'location\tq_id\tbody_literal\tbody_char_start\tbody_char_end\n第一节\tQ01\t东行三步。\t16\t21\n' > "$OCCURRENCES"
if python3 "$SKILL_ROOT/scripts/verify-quote-closure.py" "$ARTICLE" "$LEDGER" "$OCCURRENCES" >/dev/null 2>&1; then
  echo 'GATE_TEST=FAIL unrelated_bracket_quote_was_accepted' >&2; exit 65
fi

printf 'GATE_REGRESSION=PASS length_boundaries=PASS divergent_counters=DETECTED quote_swapped_id_false_span_duplicate_untagged_unrelated_bracket=DETECTED sandbox=%s\n' "$TMP_ROOT"
