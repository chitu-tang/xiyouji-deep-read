# RC.2.4 GitHub 迁移验收记录

- 目标仓库：`chitu-tang/xiyouji-deep-read`
- 迁移版本：`xiyouji-chapter-longform RC.2.4`
- 迁移状态：`ENGINEERING_MIGRATION_VALIDATED`
- 适用范围：仓库内的回目深度解读 Skill 工程；不涉及 `xiyouji-interpret`。

## 迁移内容

- 根目录 `SKILL.md` 切换为 RC.2.4 主控规范。
- 新增 `modules/`、`scripts/`、`references/` 和 RC.2.4 模板。
- 保留既有 `knowledge-base/`、`style-guide.md`、`forbidden-words.md` 和 `sub-skills/`；旧 `sub-skills/` 已标明为历史参考，不再作为主管线。
- `knowledge-base/original-text/` 的说明已明确：其中材料只能用于定位和研究线索，不能替代人民文学出版社 2020 年版三卷正式 PDF 的直接引文核验。
- 未复制正式 PDF、用户工作区、文章快照、发布分发资产、本机绝对路径或 API 密钥。

## 已验证门禁

在仓库根目录执行并通过：

```text
RELEASE_VERIFY=PASS schema=v2 formal_volumes=3 navigation_contract=PASS quote_identity=PASS archive_asset_plan=PASS
GATE_REGRESSION=PASS length_boundaries=PASS divergent_counters=DETECTED quote_swapped_id_false_span_duplicate_untagged_unrelated_bracket=DETECTED
RELEASE_REGRESSION=PASS cold_install=PASS clean_zip=PASS utf8_filename_entries=PASS v2_initializer_one_volume=REJECTED legacy_single_source=REJECTED synthetic_navigation_without_pdf_identity=REJECTED archive_asset_plan_planned_generic_audit=DETECTED archive_asset_plan_unplanned_generic_audit=DETECTED
```

上述 `DETECTED` 项是对抗性回归按预期捕获恶意或错误输入，不是失败状态。

## 正式底本边界

仓库本身不声明拥有或分发三卷正式 PDF。运行方必须在本机注册上册、中册、下册的路径、SHA-256、页数和书目信息，先通过 0A，再对选定回目单独完成 0B；在线文本、OCR、搜索结果和仓库知识库只能作定位或线索。

## 发布边界

本记录证明 GitHub 仓库内的迁移工程通过验证，不等同于任何具体文章快照、外部内容平台发布或 GitHub Release。文章归档和分发仍必须在独立工作区内按 RC.2.4 的资产计划与只读规则执行。
