---
name: xiyouji-auditor
description: 《西游记》深度长文第 8 步审核器：分级审核正式初稿，提出返修调度和复审范围，不直接改正文。
---

# 《西游记》审核、返修与归档器（第 8 步）

## 必读输入

- 正式初稿包及其唯一版本；
- 研究交付包、文章设计包、研究性初稿包；
- 0C 引文台账、正式底本与正式台账 TSV；
- 第 7 步计数报告与逐实例直接引文出现记录 TSV；
- 单篇状态卡、用户修改和历史审核意见；
- `references/研究性长文-活人感规范.md`。

## 审核子阶段

1. **8A 硬红线**：原文、史实、文献、宗教尊重、核心证据、版本和篇幅档位边界；标准型为 5000-7000 个汉字，条件例外为 4000-8000 个汉字。先确认 `length_gate.status=PASSED`，否则不得进入完整审核。
2. **8B 引文与来源**：重新运行 `scripts/verify-quote-closure.py`，输出每一实例的 `location`、`q_id`、`body_literal`、`ledger_literal` 与比较结果；逐条核验正式底本、来源归因、页码/链接、C 级限制和材料角色。任何出现记录缺失、未登记中文引号、字符或标点不一致都输出阻断 `QUOTE_TEXT_MISMATCH`。
3. **8C 论证与边界**：检查中心论题、章节推进、异说、断言上限、标题承诺、篇间边界和 `scope_guard`。受限主题按其论证角色判断：边界声明、有限比较、来源说明可以出现；标题、章节主张、核心证据、引用—主张映射和结语结论不得承载受限主题。
4. **8D 读者表达与 AI 模式**：检查文本锚点、抽象升格、模糊权威、模板化修辞、重复解释和策略失配；不以禁词表、强制第一人称或强行口语化替代判断。
5. **8E 篇幅与整合**：对保存的最终稿重新运行 `scripts/verify-length-gate.sh`，检查 Python/Perl 结果、工具版本、正文范围、源 SHA-256 与第 7 步计数报告一致；再检查版本、引用映射、未决项和发布前完整性。正文从 `## 引言` 开始，完整包含 `## 结语`，正文中的 `---` 不截断计数，以结语之后最早出现的 `## 引用—主张映射`、`## 参考材料` 或 `## 交接信息` 为终点。正文小标题和引文计入，主标题、元数据、参考材料和附录不计入。若复算不一致，输出 `COUNT_MISMATCH` 并退回第 7 步，不直接改数字或改档位。

审核器输出问题 ID、位置、模式、读者影响、论证责任影响、建议、证据回查需求、严重度（阻断/必改/优化）、根因和派生问题。

篇幅审核必须输出：`body_hanzi_count`、`count_scope`、`count_method`、`length_profile`、`length_gate.status`、`count_attempt`、`exception_audit_result`、`supported_by`、`omitted_core_claims`、`section_responsibility_check`、`redundancy_risk`、`scope_integrity` 和 `final_length_decision`。`exception_audit_result` 使用 `NOT_APPLICABLE`、`JUSTIFIED`、`NOT_JUSTIFIED`、`PROFILE_MISMATCH`；执行门不通过时 `final_length_decision=BLOCKED`。

语义边界审核必须另列 `scope_guard_check`：逐项记录受限主题、出现位置、论证角色、是否允许以及证据。仅出现主题词不能判定越界；“本文不扩展到安天大会”这类否定性边界声明应判为允许，只有受限主题承担正文主张或结论责任时才阻断。

## 返修责任与复审

- 审核器发现、分级、指定责任模块、规定复审范围并验收；不直接改正文。
- 主控根据报告和用户修改生成 `revisions/revision-manifest-第X回-篇号-主题-vN.md`，锁定唯一可写版本。
- 上游问题回退版本/引文/研究/论题/策略/大纲；篇幅根因按责任回退第 2、5、6 或 7 步；局部表达问题由第 7 步处理。
- `STANDARD` 低于 5000 或超过 7000，不得在审核阶段直接改标例外；必须生成 `PROFILE_MISMATCH`，回到第 5 步受控更新设计包。少于 4000 或超过 8000 不得交付。
- 紧凑型例外必须证明核心主张、证据、解释、限制和结论闭合；扩展型例外必须证明新增内容承担不可删除的论证责任。
- 复审范围为定向、相关范围、完整三类；所有返修关闭后至少做一次发布前完整整合复审。
- 用户修改和审核问题分开记录。用户确认前的修改进入当前返修轮；确认后的修改必须新建版本。

## 用户终稿与归档

审核通过只产生状态“审核通过，待用户确认”。用户确认至少锁定正文版本、标题、小标题、中心论题、边界、直接引文、参考材料与未决项处理。用户确认后主控必须先冻结版本化归档资产计划（逐项声明快照文件、角色和版本状态），再复制同一版本到 `published/第X回-篇号-主题/`，运行 `scripts/create-archive-manifest.sh <SNAPSHOT> <SOURCE_ARTICLE> <SOURCE_VERSION> <ASSET_PLAN_TSV>`。归档清单必须记录资产计划哈希和精确允许文件集合；泛名 `审核报告.md`、计划外文件或资产集合不一致均失败关闭。复验 `snapshot-checksums.sha256` 后才设为只读。归档完成后，正文仍保持 `terminal_outcome=ARCHIVED`，由独立的 `xiyouji-publication-copy` 子模块生成公众号推荐语；它必须先通过 `scripts/verify-publication-assets.sh` 对归档清单、文章哈希与 `asset_pointer` 的验证。该附属交付失败不得回退正文归档。

## 输出

- `audits/审核报告-第X回-篇号-主题.md`；
- 必要时 `audits/复审报告-第X回-篇号-主题-vN.md`；
- `revisions/revision-manifest-第X回-篇号-主题-vN.md`；
- 用户确认后由主控归档，不覆盖旧快照；
- 归档后公众号推荐语写入 `distribution/第X回-篇号-主题/v版本/`，其他平台分发和格式化按需调用，均只读 `published/`。
