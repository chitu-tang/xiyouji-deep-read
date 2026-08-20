#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "usage: $0 ARTICLE_FILE PROFILE [REPORT_FILE]" >&2
  exit 64
fi

ARTICLE=$1
PROFILE=$2
REPORT=${3:-}
[ -f "$ARTICLE" ] || { echo "COUNT_MISMATCH: article file is unavailable" >&2; exit 66; }
case "$PROFILE" in STANDARD) MIN=5000; MAX=7000 ;; COMPACT_EXCEPTION) MIN=4000; MAX=4999 ;; EXPANDED_EXCEPTION) MIN=7001; MAX=8000 ;; *) echo "COUNT_MISMATCH: invalid profile=$PROFILE" >&2; exit 64 ;; esac

PYTHON_RESULT=$(python3 - "$ARTICLE" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding='utf-8')
start = s.find('## 引言')
if start < 0:
    raise SystemExit('missing body start')
ends = [s.find(marker, start) for marker in ('## 引用—主张映射', '## 参考材料', '## 交接信息')]
ends = [end for end in ends if end >= 0]
if not ends:
    raise SystemExit('missing body end')
body = s[start:min(ends)]
print(sum(0x4E00 <= ord(ch) <= 0x9FFF for ch in body))
PY
)
PERL_RESULT=$(perl -CSDA - "$ARTICLE" <<'PL'
use strict; use warnings;
my $path = shift;
open my $fh, '<:encoding(UTF-8)', $path or die $!;
local $/; my $s = <$fh>;
$s =~ /(## 引言.*?)(?=## 引用—主张映射|## 参考材料|## 交接信息)/s or die "missing body scope\n";
my $body = $1;
my $count = 0; $count++ while $body =~ /[\x{4E00}-\x{9FFF}]/g;
print "$count\n";
PL
)
if [ -n "${VERIFY_LENGTH_GATE_TEST_PERL_OVERRIDE:-}" ]; then PERL_RESULT=$VERIFY_LENGTH_GATE_TEST_PERL_OVERRIDE; fi
SHA256=$(shasum -a 256 "$ARTICLE" | awk '{print $1}')
PYTHON_VERSION=$(python3 --version 2>&1)
PERL_VERSION=$(perl -e 'print $^V')
STATUS=PASSED
REASON=none
if [ "$PYTHON_RESULT" != "$PERL_RESULT" ]; then STATUS=COUNT_MISMATCH; REASON=independent_implementations_disagree
elif [ "$PYTHON_RESULT" -lt 4000 ] || [ "$PYTHON_RESULT" -gt 8000 ]; then STATUS=BLOCKED; REASON=outside_absolute_4000_8000_range
elif [ "$PYTHON_RESULT" -lt "$MIN" ] || [ "$PYTHON_RESULT" -gt "$MAX" ]; then STATUS=REWORK_REQUIRED; REASON=outside_locked_profile_range
fi
RESULT="length_gate.status=$STATUS
length_gate.profile=$PROFILE
source_sha256=$SHA256
count_scope=## 引言 through the earliest post-conclusion mapping/reference/handoff heading
python_ord_u4e00_u9fff=$PYTHON_RESULT ($PYTHON_VERSION)
perl_ord_u4e00_u9fff=$PERL_RESULT ($PERL_VERSION)
reason=$REASON"
printf '%b\n' "$RESULT"
if [ -n "$REPORT" ]; then printf '%b\n' "$RESULT" > "$REPORT"; fi
[ "$STATUS" = PASSED ] || exit 65
