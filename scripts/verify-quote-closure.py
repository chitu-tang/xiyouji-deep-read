#!/usr/bin/env python3
import csv
from pathlib import Path
import re
import sys

if len(sys.argv) != 4:
    raise SystemExit('usage: verify-quote-closure.py ARTICLE_FILE LEDGER_TSV OCCURRENCES_TSV')
article_path, ledger_path, occurrences_path = map(Path, sys.argv[1:])
for path in (article_path, ledger_path, occurrences_path):
    if not path.is_file():
        raise SystemExit(f'QUOTE_TEXT_MISMATCH: missing input {path}')

article = article_path.read_text(encoding='utf-8')
start = article.find('## 引言')
ends = [article.find(marker, start) for marker in ('## 引用—主张映射', '## 参考材料', '## 交接信息')]
ends = [end for end in ends if end >= 0]
if start < 0 or not ends:
    raise SystemExit('QUOTE_TEXT_MISMATCH: unable to determine article body scope')
body = article[start:min(ends)]

with ledger_path.open(encoding='utf-8', newline='') as f:
    ledger_rows = list(csv.DictReader(f, delimiter='\t'))
if not ledger_rows or tuple(ledger_rows[0].keys()) != ('q_id', 'ledger_literal'):
    raise SystemExit('QUOTE_TEXT_MISMATCH: invalid quote ledger TSV schema')
ledger = {row['q_id']: row['ledger_literal'] for row in ledger_rows}
if len(ledger) != len(ledger_rows) or any(not q_id or not literal for q_id, literal in ledger.items()):
    raise SystemExit('QUOTE_TEXT_MISMATCH: invalid quote ledger TSV')

with occurrences_path.open(encoding='utf-8', newline='') as f:
    occurrence_rows = list(csv.DictReader(f, delimiter='\t'))
expected_columns = ('location', 'q_id', 'body_literal', 'body_char_start', 'body_char_end')
if not occurrence_rows or tuple(occurrence_rows[0].keys()) != expected_columns:
    raise SystemExit('QUOTE_TEXT_MISMATCH: invalid occurrence TSV schema')

# Every direct quote must carry an immediately preceding Q identifier. Offsets are
# zero-based character offsets inside the body scope, making each occurrence auditable.
actual = []
for match in re.finditer(r'【([A-Z][A-Z0-9-]+)】“([^”]+)”', body):
    q_id, literal = match.groups()
    actual.append((q_id, literal, match.start(2), match.end(2)))
all_quotes = [(match.start(1), match.end(1), match.group(1)) for match in re.finditer(r'“([^”]+)”', body)]
tagged_quote_spans = {(start - 1, end + 1, literal) for _, literal, start, end in actual}
if {(start - 1, end + 1, literal) for start, end, literal in all_quotes} != tagged_quote_spans:
    raise SystemExit('QUOTE_TEXT_MISMATCH: every direct quotation requires one adjacent valid Q identifier')

recorded = []
for line_number, row in enumerate(occurrence_rows, start=2):
    try:
        start_offset, end_offset = int(row['body_char_start']), int(row['body_char_end'])
    except ValueError:
        raise SystemExit(f'QUOTE_TEXT_MISMATCH: invalid character offsets at occurrence row {line_number}')
    q_id, literal, location = row['q_id'], row['body_literal'], row['location']
    if not location or q_id not in ledger or literal != ledger[q_id]:
        raise SystemExit(f'QUOTE_TEXT_MISMATCH: invalid ledger binding at occurrence row {line_number}')
    if start_offset < 0 or end_offset <= start_offset or body[start_offset:end_offset] != literal:
        raise SystemExit(f'QUOTE_TEXT_MISMATCH: invalid body span at occurrence row {line_number}')
    marker_prefix = f'【{q_id}】“'
    marker = f'{marker_prefix}{literal}”'
    if start_offset < len(marker_prefix) or body[start_offset - len(marker_prefix):end_offset + 1] != marker:
        raise SystemExit(f'QUOTE_TEXT_MISMATCH: q_id is not adjacent to quote instance at occurrence row {line_number}')
    recorded.append((q_id, literal, start_offset, end_offset))

if len(set(recorded)) != len(recorded):
    raise SystemExit('QUOTE_TEXT_MISMATCH: duplicate occurrence identity')
if sorted(actual) != sorted(recorded):
    raise SystemExit('QUOTE_TEXT_MISMATCH: article quote instances do not exactly match recorded spans/Q IDs')
print(f'QUOTE_CLOSURE=PASS occurrences={len(actual)} ledger_entries={len(ledger)}')
