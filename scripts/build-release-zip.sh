#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_ZIP" >&2
  exit 64
fi

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
PARENT=$(dirname "$SKILL_ROOT")
BASE=$(basename "$SKILL_ROOT")
OUTPUT=$1
case "$OUTPUT" in
  /*) ;;
  *) OUTPUT="$PWD/$OUTPUT" ;;
esac
[ ! -e "$OUTPUT" ] || { echo "refusing to overwrite existing archive: $OUTPUT" >&2; exit 73; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required to build a release archive" >&2; exit 69; }

python3 - "$SKILL_ROOT" "$OUTPUT" <<'PY'
from pathlib import Path
import os
import stat
import sys
import zipfile

root = Path(sys.argv[1])
output = Path(sys.argv[2])
prefix = root.name
excluded_names = {'.DS_Store', '__MACOSX', '__pycache__'}
entries = []
for path in root.rglob('*'):
    relative = path.relative_to(root)
    if any(part in excluded_names or part.startswith('._') for part in relative.parts):
        continue
    if path.suffix == '.pyc':
        continue
    if path.is_symlink():
        raise SystemExit(f'refusing to package symbolic link: {path}')
    if path.is_file():
        entries.append(path)
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(entries):
        entry = f'{prefix}/{path.relative_to(root).as_posix()}'
        metadata = path.stat()
        info = zipfile.ZipInfo(entry, tuple(__import__('time').localtime(metadata.st_mtime)[:6]))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.flag_bits |= 0x800  # UTF-8 filename flag for Chinese asset paths.
        info.create_system = 3
        info.external_attr = ((stat.S_IFREG | stat.S_IMODE(metadata.st_mode)) << 16)
        archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
PY
if unzip -Z1 "$OUTPUT" | grep -Eq '(^|/)\._|(^|/)\.DS_Store$|(^|/)__MACOSX(/|$)|(^|/)__pycache__(/|$)|\.pyc$'; then
  echo "release archive contains excluded metadata or bytecode" >&2
  exit 65
fi
python3 - "$OUTPUT" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    invalid = [info.filename for info in archive.infolist() if any(ord(char) > 127 for char in info.filename) and not info.flag_bits & 0x800]
if invalid:
    raise SystemExit('release archive contains non-UTF-8 filename entries: ' + ', '.join(invalid))
PY
printf 'RELEASE_ARCHIVE_BUILD=PASS output=%s utf8_filenames=PASS\n' "$OUTPUT"
