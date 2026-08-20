---
name: xiyouji-script-writer
description: 《西游记》深度长文正式写作器：依据研究性初稿包和已锁定的文章设计包，连续完成标准或条件例外篇幅的正式初稿。
---

# 《西游记》正式写作器（第 7 步）

## 必读输入

- 单篇状态卡；
- 拆篇条目；
- 第 2 步研究交付包；
- 第 5 步文章设计包；
- 第 6 步研究性初稿包；
- 0C 引文台账；
- 正式底本注册表；
- `references/研究性长文-活人感规范.md`；
- `references/表达动作参考库.md`（只读）。

## 写作规则

- 严格执行第 5 步锁定的 `length_profile`：`STANDARD` 为 5000-7000 个汉字，`COMPACT_EXCEPTION` 为 4000-4999，`EXPANDED_EXCEPTION` 为 7001-8000；不得以重复解释凑字数，也不得在第 7 步临时改标。
- 正文先呈现文本锚点、动作或叙事顺序，再给解释；首次出现术语要转译。
- 研究责任线检查证据、归因、断言、异说和边界；读者表达线检查入口、材料可见度、节奏、策略执行和故事回收。
- 外部表达参考只转译表达动作，不复制句子、作者口吻或个人经历。
- 用户此前的语气、深度、细节和学术密度反馈写入稿件元数据；用户终稿修改另进入表达学习候选库。

## 执行节奏

1. 7A 预检和引用—主张清单；同时读取第 5 步锁定的 `length_gate` 与 `scope_guard`，缺失即 `HARD_STOP`。
2. 7B 按章节任务连续完成全文；每节只做内部自检，不例行暂停。
3. 7C 全文整合后，对已经写盘的唯一正式稿运行 `scripts/verify-length-gate.sh <ARTICLE> <PROFILE> <COUNT_REPORT>`。报告必须记录源文件 SHA-256、正文边界、Python `ord()` 与 Perl `ord()` 结果、工具版本和状态；不得用缓存或附录计数代替。
4. 7D 仅当两个独立计数一致时，将报告中的实际数值写回 `body_hanzi_count`、`last_count` 和 `count_attempt`。超出锁定档位但仍在 4000-8000 时为 `REWORK_REQUIRED`；低于 4000 或高于 8000 时为 `BLOCKED`；实现不一致为 `COUNT_MISMATCH`。三种情形均不得交审核。
5. 在正文、正式台账 TSV 与逐实例出现记录准备完成后，运行 `scripts/verify-quote-closure.py <ARTICLE> <LEDGER_TSV> <OCCURRENCES_TSV>`。每条记录必须含稳定位置、Q 编号和正文实际字符串；脚本必须为 `PASS`。
6. 只有 `length_gate.status=PASSED`、计数报告源 SHA-256 与正式稿一致、引文闭合脚本通过、`body_hanzi_count` 为实际整数、范围和方法字段完整且 `scope_guard.boundary_decision` 不为 `BLOCKED`，才生成“正式初稿完成，待审核”和交接报告。

如果发现核心证据、论题、范围、材料角色、断言强度、主导策略或已锁定篇幅档位需要变化，停止写作并提交回退请求。局部语气、段落和节奏修改可在当前版本内处理，但必须记录变更摘要。正文汉字统计从 `## 引言` 开始，完整包含 `## 结语` 章节；正文中的 `---` 不截断计数。以结语之后最早出现的 `## 引用—主张映射`、`## 参考材料` 或 `## 交接信息` 为终点；正文小标题和引文计入，其余元数据、映射、参考材料和附录不计入。计数不得写“待统计”“预估”或其他非最终值。

## 输出

`drafts/第X回-篇号-主题-正式初稿.md`，包含正文、工作/审核标题、版本、原文范围、`length_profile`、`length_gate`、`body_hanzi_count`、`count_scope`、`count_method`、`count_attempt`、例外理由、`scope_guard`、引文数量、引用—主张映射、研究性初稿版本、变更摘要、未决项和状态“正式初稿完成，待审核”。

同时写入 `drafts/第X回-篇号-主题-计数报告.md` 与 `drafts/第X回-篇号-主题-直接引文出现记录.tsv`。后者固定字段为 `location`、`q_id`、`body_literal`，并与 `research/第X回-篇号-主题-正式底本引文核验卡.tsv` 的 `q_id`、`ledger_literal` 逐实例闭合。

`length_gate.status` 未达到 `PASSED` 时，输出必须标明“篇幅执行门未通过，待返工”，不得生成审核交接，也不得把 `body_hanzi_count` 留为“待统计”。第 7 步完成后，且仅在执行门通过时，自动交第 8 步审核，不以用户逐节确认作为前置条件。
