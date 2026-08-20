#!/usr/bin/env bash
set -euo pipefail

SKILL_ROOT=$(CDPATH= cd -P -- "$(dirname -- "$0")/.." && pwd -P)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/xiyouji-skill-release.XXXXXX")
trap 'printf "RELEASE_TEST_SANDBOX_RETAINED=%s\\n" "$TMP_ROOT"' EXIT
INSTALL_PARENT="$TMP_ROOT/installed"
mkdir -p "$INSTALL_PARENT"
cp -R "$SKILL_ROOT" "$INSTALL_PARENT/xiyouji-chapter-longform"
INSTALLED="$INSTALL_PARENT/xiyouji-chapter-longform"
ZIP="$TMP_ROOT/rebuilt-release.zip"

bash "$INSTALLED/scripts/verify-release.sh"
bash "$INSTALLED/scripts/build-release-zip.sh" "$ZIP"
if unzip -Z1 "$ZIP" | grep -Eq '(^|/)\._|(^|/)\.DS_Store$|(^|/)__MACOSX(/|$)|(^|/)__pycache__(/|$)|\.pyc$'; then
  echo 'RELEASE_REGRESSION=FAIL macos_metadata_or_bytecode_was_packaged' >&2
  exit 65
fi
python3 - "$ZIP" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    invalid = [info.filename for info in archive.infolist() if any(ord(char) > 127 for char in info.filename) and not info.flag_bits & 0x800]
if invalid:
    raise SystemExit('RELEASE_REGRESSION=FAIL non_utf8_filename_entries=' + ','.join(invalid))
PY
printf 'volume\tformal_source_path\tformal_source_sha256\tpdf_page_count\tregistry_row\n上册\t/not/a/pdf\t0000000000000000000000000000000000000000000000000000000000000000\t1\tfixture\n' > "$TMP_ROOT/one-volume.tsv"
if bash "$INSTALLED/scripts/init-workspace.sh" "$TMP_ROOT/v2-init" "$TMP_ROOT/one-volume.tsv" "《西游记》" "吴承恩" "人民文学出版社" "2020年版" "978-7-02-015043-4" "fixture" >/dev/null 2>&1; then
  echo 'RELEASE_REGRESSION=FAIL one_volume_initializer_input_was_accepted' >&2
  exit 65
fi
mkdir -p "$TMP_ROOT/legacy-workspace"/{references,research,drafts,audits,revisions,state,published,distribution}
printf '# asset card\n' > "$TMP_ROOT/legacy-workspace/深解读资产卡.md"
printf 'workspace_schema: xiyouji-longform-workspace/v1\nformal_source_path: /not/a/pdf\n' > "$TMP_ROOT/legacy-workspace/xiyouji-longform-workspace.yaml"
printf '# incomplete registry\n' > "$TMP_ROOT/legacy-workspace/references/人民文学出版社2020年版-西游记-正式底本注册表.md"
printf '| 回次 | 回目 | 卷册 | PDF起页 | PDF止页 | 书内起页 | 书内止页 | 核验 |\n' > "$TMP_ROOT/legacy-workspace/references/百回导航索引.md"
if bash "$INSTALLED/scripts/preflight-0a.sh" "$TMP_ROOT/legacy-workspace" >/dev/null 2>&1; then
  echo 'RELEASE_REGRESSION=FAIL legacy_single_source_workspace_was_accepted' >&2
  exit 65
fi
printf 'fixture article\n' > "$TMP_ROOT/archive-source.md"
mkdir "$TMP_ROOT/archive-snapshot"
cp "$TMP_ROOT/archive-source.md" "$TMP_ROOT/archive-snapshot/长文-夹具.md"
printf 'snapshot_filename\trole\tversion_status\n长文-夹具.md\tarticle\tcurrent\n' > "$TMP_ROOT/archive-assets.tsv"
bash "$INSTALLED/scripts/create-archive-manifest.sh" "$TMP_ROOT/archive-snapshot" "$TMP_ROOT/archive-source.md" v0.1 "$TMP_ROOT/archive-assets.tsv"
bash "$INSTALLED/scripts/verify-archive-manifest.sh" "$TMP_ROOT/archive-snapshot" "$TMP_ROOT/archive-source.md"
printf 'snapshot_filename\trole\tversion_status\n长文-夹具.md\tarticle\tcurrent\n审核报告.md\treview\thistorical_superseded\n' > "$TMP_ROOT/generic-audit-assets.tsv"
if bash "$INSTALLED/scripts/create-archive-manifest.sh" "$TMP_ROOT/archive-snapshot" "$TMP_ROOT/archive-source.md" v0.1 "$TMP_ROOT/generic-audit-assets.tsv" >/dev/null 2>&1; then
  echo 'RELEASE_REGRESSION=FAIL planned_generic_audit_was_accepted' >&2
  exit 65
fi
printf 'legacy audit\n' > "$TMP_ROOT/archive-snapshot/审核报告.md"
if bash "$INSTALLED/scripts/create-archive-manifest.sh" "$TMP_ROOT/archive-snapshot" "$TMP_ROOT/archive-source.md" v0.1 "$TMP_ROOT/archive-assets.tsv" >/dev/null 2>&1; then
  echo 'RELEASE_REGRESSION=FAIL unplanned_generic_audit_was_accepted' >&2
  exit 65
fi
printf 'RELEASE_REGRESSION=PASS cold_install=PASS clean_zip=PASS utf8_filename_entries=PASS v2_initializer_one_volume=REJECTED legacy_single_source=REJECTED synthetic_navigation_without_pdf_identity=REJECTED archive_asset_plan_planned_generic_audit=DETECTED archive_asset_plan_unplanned_generic_audit=DETECTED sandbox=%s\n' "$TMP_ROOT"
