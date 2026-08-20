---
name: xiyouji-chapter-longform
description: >
  《西游记》回目深度长文完整管线：接收用户指定回目，核验原文，建立叙事边界和候选篇目；用户选篇后完成定向研究、论题与策略设计、研究性初稿、正式长文、审核返修和不可变归档。
  Use when the user says “第X回怎么拆”“这一回能写几篇”“按第X回写长文”“把这一回做成系列文章”“写5000到7000字的西游深解”。
  For a pasted excerpt that only needs value assessment and angle selection, use `xiyouji-excerpt-angle-planner`.
---

# 《西游记》回目深度长文完整管线

## 职责边界

- 输入是一回完整、可核验的《西游记》原著，不是零散片段。
- 默认正式底本是人民文学出版社 2020 年版；在线文本、OCR 和搜索结果只作定位或线索。
- 最终文章默认按 5000-7000 个汉字的标准篇幅生产；经第 5 步锁定后，可使用 4000-8000 个汉字的条件例外档位。归档后默认生成 1 条公众号推荐语；其他平台标题、排版、节选、口播、分发文案或配图仍按需调用。
- 所有模块读取工作区资产卡和正式底本注册表；模块路径相对本 `SKILL.md` 所在的 Skill 根目录解析，工作产物路径相对用户配置的工作区根目录解析。

## 安装与运行根目录

- `SKILL_ROOT`：本 `SKILL.md` 所在目录。所有内部模块均从这里按相对路径读取。
- `WORKSPACE_ROOT`：用户项目目录，保存 `research/`、`drafts/`、`audits/`、`state/`、`published/` 和 `distribution/`。RC.2.2 只接受 `xiyouji-longform-workspace/v2`：配置必须引用 `references/正式底本卷册清单.tsv` 中的上、中、下三册正式 PDF，三册均须含本机路径、SHA-256 与 PDF 页数，并与正式底本注册表逐字匹配。
- 工作区根目录必须含 `xiyouji-longform-workspace.yaml`、`深解读资产卡.md`、`references/人民文学出版社2020年版-西游记-正式底本注册表.md`、`references/正式底本卷册清单.tsv`、`references/百回目录核验清单.tsv` 和 `references/百回导航索引.md`。`0A` 要求 100 条回目逐项匹配目录核验清单，且每条有相应卷册内的 PDF 范围、书内范围、目录页及 `NAVIGATION_CONFIRMED`。该状态只证明目录锚点、页码连续性和边界抽检；选定回目的首末页视觉复核必须在 0B 单独完成。
- 若工作区、正式底本、哈希、书目信息、注册表一致性或所需写权限不可用，写入 `HARD_STOP`，不得以在线文本、OCR、打包示例或其他机器路径代替。

## 唯一阶段枚举

`stage` 只允许以下值：`0A`、`0B`、`1`、`2`、`3`、`4`、`5`、`6`、`7`、`8`。

- `0A`：百回底本资产预检，一次性检查正式底本文件、哈希、书目信息和百回导航索引。
- `0B`：单回定位与范围核验，确认回目物理范围、卷册、页码和前后回边界。
- `1`：叙事边界图、问题发现池与拆篇候选。
- `2`：2A 研究执行与材料采集，2B 证据综合与研究准入。
- `3`：中心论题与解释边界。
- `4`：表达策略路由与策略卡。
- `5`：论证架构与写作大纲，形成完整文章设计包。
- `6`：研究性初稿。
- `7`：正式长文写作。
- `8`：审核、返修、复审、用户终稿与归档。

`0C` 是贯穿 1-8 的 `control_track.quote_ledger`，不是 `stage` 值。它维护候选待核、正式核验可用、不可用/已删除三态的逐节引文台账。核心直接引文在进入对应逻辑节前必须正式核验。台账状态和 Q 编号不是正文引文的替代物：审核器必须抽取正文实际引文，与台账登记的正式文本逐字比对；任何字词、否定词、方位词或关键标点不一致，都必须登记为 `QUOTE_TEXT_MISMATCH` 并阻断。

终态单独记录在 `terminal_outcome`：未设置、`NO_ELIGIBLE_ARTICLE`、`ARCHIVED`。`HARD_STOP` 是运行模式，不是终态。

## 全局运行状态

- `AUTO_RUN`：前置条件和质量门满足，主控自主推进。
- `USER_WAIT`：需要用户选择、确认范围/主轴，或确认最终版本。
- `HARD_STOP`：缺少必需输入、正式底本不可用、核心引文无法核验、版本冲突，或无法形成任何可负责判断。

交付事件 `DELIVERABLE_READY` 不等于 `USER_WAIT`。研究预览、论题候选、研究性初稿和正式初稿可以交付后继续自动推进，除非触发明确用户决策锁。

硬锁优先于用户锁。阶段转换必须先成功写入单篇流程状态卡，再生成心跳和对话状态摘要。

## 模块与交接

| 阶段 | 内部模块 | 正式交接物 | 默认人工关口 |
|---|---|---|---|
| 0A | `scripts/preflight-0a.sh`；`modules/xiyouji-segment-selector/SKILL.md` | 工作区级 `0A=PASSED` 记录：正式底本哈希、书目信息和百回导航索引 | 无；不通过即 `HARD_STOP` |
| 0B、1 | `modules/xiyouji-segment-selector/SKILL.md` | `research/第X回-拆篇方案.md` | 用户选篇；0 篇是合法终态 |
| 2 | `modules/xiyouji-research-collector/SKILL.md` | `research/第X回-篇号-主题-研究包.md` | 只有主轴/准入方案变化时等待 |
| 3-5 | `modules/xiyouji-angle-miner/SKILL.md` | `research/第X回-篇号-主题-文章设计包.md` | 普通论题、策略、大纲选择自动推进 |
| 6 | `modules/xiyouji-deep-explainer/SKILL.md` | `research/第X回-篇号-主题-研究性初稿.md` | 不逐节等待；核心冲突才暂停 |
| 7 | `modules/xiyouji-script-writer/SKILL.md` | `drafts/第X回-篇号-主题-正式初稿.md` | 不逐节等待；正式初稿完成后自动交审核 |
| 8 | `modules/xiyouji-auditor/SKILL.md`；归档后调用 `modules/xiyouji-publication-copy/SKILL.md` | `audits/`、`revisions/`、`published/`；归档后附属交付写入 `distribution/` | 审核通过后等待用户确认终稿；归档后推荐语自动交付 |

## 状态卡与共享资产

- 单篇状态卡：`state/第X回-篇号-主题-流程状态卡.md`。
- 跨篇总览：`深解读资产卡.md`，只保存唯一键、边界、当前状态指针和最近定稿快照。
- 研究导航库：`references/西游记-研究导航库.md`。
- 外部表达动作参考库：`references/表达动作参考库.md`。2A 或用户可提交候选；2B 核验出处、适用边界和限制；主控串行写入已批准条目；文章设计器只读调用动作、条件和误用风险；审核器复核引用/版权边界和退役状态。它不得成为当前文章的原文证据、研究结论或默认文风。
- 表达学习候选库：`references/表达学习候选库.md`，每篇终稿后即时复盘，三篇同策略后综合，试运行并经用户确认后才采用；发布资产反馈按 `application_scope` 与正文表达隔离。

- `0A` 必须先运行 `scripts/preflight-0a.sh <WORKSPACE_ROOT>` 并将 `0A_PREFLIGHT=PASS`、正式底本 SHA-256、注册表版本和索引哈希写入工作区记录；`0A` 不通过时不得生成任何 `0B` 或第 1 步资产。
- 第 7 步调用 `scripts/verify-length-gate.sh`，保存其报告；第 8 步重新调用同一脚本并比较源文件 SHA-256。
- 第 7 步与第 8 步都调用 `scripts/verify-quote-closure.py`，使用正式台账 TSV 与逐实例出现记录；出现记录必须包含 `location`、`q_id`、`body_literal`、`body_char_start`、`body_char_end`，且正文直接引文使用相邻 `【Q-ID】“原文”` 标记。任何非零返回都视为阻断。
- 用户确认后，主控必须先冻结 `revisions/第X回-篇号-主题-vN-归档资产计划.tsv`，再复制同一版本到 `published/第X回-篇号-主题/`，运行 `scripts/create-archive-manifest.sh <SNAPSHOT> <SOURCE_ARTICLE> <SOURCE_VERSION> <ASSET_PLAN_TSV>`。清单记录资产计划 SHA-256 与精确允许文件集合；计划外文件、泛名 `审核报告.md` 或当前正文不一致均失败关闭。随后复验 `snapshot-checksums.sha256` 并设为只读；`modules/xiyouji-publication-copy/SKILL.md` 只接受 `scripts/verify-publication-assets.sh` 验证通过的快照。1. `0A` 或 `0B` 无法完成时停止，不以在线文本替代正式底本。
2. 第 1 步必须先从原文发现问题，再用导航库提示研究路线。
3. 第 1 步允许输出 0-5 篇；一个候选不准入不等于整回 0 篇。
4. 未经用户选篇，不启动该篇完整研究。
5. 第 2 步按主张类型判断证据，不以 12-20 条材料或 5 条 A 级材料作为普遍硬门。
6. 2B 的 `ARTICLE_NOT_ADMITTED` 只作用于当前候选；只有第 1 步汇总全部问题卡后才能写入 `NO_ELIGIBLE_ARTICLE`。
7. 第 3→4→5 必须分别完成论题定位卡、表达策略卡和论证架构检查点；第 5 步才生成交给第 6 步的完整文章设计包。
8. 第 7 步不得无记录改变论题、边界、引文、材料角色、证据等级或断言强度。
9. 审核器只发现、分级、调度和验收问题，不直接改正文；主控生成 `revision-manifest` 并锁定唯一可写版本。
10. “审核通过，待用户确认”不等于用户终稿。用户确认后任何改动都建立新版本，不覆盖旧归档。
11. 只有用户明确指定、策略价值冲突或策略边界不稳时，策略选择才进入 `USER_WAIT`。
12. 所有终稿后用户修改先进入表达学习候选，不自动改写策略卡或全局规范。
13. 第 5 步必须锁定 `length_profile`：`STANDARD`、`COMPACT_EXCEPTION` 或 `EXPANDED_EXCEPTION`；第 7 步不得临时改标。
14. `STANDARD` 的默认正文范围为 5000-7000 个汉字；例外范围为 4000-8000 个汉字。少于 4000 或超过 8000 不得交付。
15. 正文汉字数从引言至结语统计；正文小标题和引文计入，主标题、元数据、参考材料和附录不计入；第 8 步审核器复算并以复算结果为准。
16. 4000-4999 或 7001-8000 只有在第 5 步锁定例外档位并写明理由，且第 8 步例外证据审核通过后才能交付。
17. 归档后公众号推荐语是默认附属交付物，写入 `distribution/`，不改变 `published/` 快照；标题优化、排版、节选和其他平台改编按需调用。
18. 所有发布资产只读不可变归档版本；平台标题、推荐语和改编稿不得反写正文、论题、边界或归档元数据。
19. 篇幅执行门是第 7 步的不可跳过硬门：正式初稿必须完成精确计数、范围判定、必要的补写/压缩和再次计数；`body_hanzi_count` 缺失、非整数、与正文复算不一致或不在已锁定档位范围内时，不得写入“正式初稿完成，待审核”，不得进入第 8 步。
20. 篇幅执行门的状态只能为 `NOT_STARTED`、`COUNTED`、`REWORK_REQUIRED`、`PASSED`、`BLOCKED`。只有 `PASSED` 才能推进阶段；`REWORK_REQUIRED` 必须回到第 7 步局部写作处理，绝不通过临时改写 `length_profile` 放行；低于 4000 或高于 8000 时进入 `BLOCKED`，按根因回退。
21. 文章设计包必须同时冻结 `scope_guard`：受限主题、允许的边界声明/旁参位置、禁止承载核心论证的位置。审核按主题在正文中的论证角色和位置判断，不能用单纯词面禁词判断越界；明确否定扩展的边界声明不算越界。
22. 篇幅门的计数对象必须是已经写盘的最终初稿文件；不得从草稿缓存、生成过程、交接文本或包含附录的临时文本推导 `body_hanzi_count`。正式初稿交审核前，主控必须对同一份最终文件执行两次独立复算（独立实现或独立命令），两次结果和交接字段必须完全一致；任何不一致均为 `COUNT_MISMATCH`，退回第 7 步。
24. `0A` 不得以待填写索引、零页码、在线文本、OCR 或其他机器路径放行；只能接受完整、所有物理页码均为正整数且不倒置、100 条 `NAVIGATION_CONFIRMED` 的导航索引及匹配的用户本机正式底本哈希和书目信息。`NAVIGATION_CONFIRMED` 仅限导航层面；每篇文章在进入研究和引文阶段前必须由 0B 保存该回首末边界的正式 PDF 视觉核验记录。
25. 计数门的通过依据是 `scripts/verify-length-gate.sh` 对写盘文件输出的 Python/Perl 结果、工具版本、正文范围和源 SHA-256；两次实现不一致为 `COUNT_MISMATCH`。
26. 每条直接引文必须有一条逐实例记录，字段为 `location`、`q_id`、`body_literal`；正式台账 TSV 字段为 `q_id`、`ledger_literal`。正文中的中文引号仅用于这些受控直接引文；每一个中文引号实例都必须有且只有一条匹配的出现记录，任何未登记、重复遗漏、字符串不等、标点不等或定位缺失均为 `QUOTE_TEXT_MISMATCH`。
27. 不可变归档必须有 `archive-manifest.json`、`snapshot-checksums.sha256` 和版本化归档资产计划。清单必须记录资产计划 SHA-256 与精确文件集合；泛名 `审核报告.md`、计划外文件或资产集合不一致时不得归档。推荐语中的 `asset_pointer` 必须精确等于归档清单中的文章指针；哈希或指针不一致时不得生成或交付发布资产。

## 执行门协议

### 篇幅执行门 `length_gate`

第 5 步锁定以下字段并交给第 7 步：

```yaml
length_gate:
  profile: STANDARD | COMPACT_EXCEPTION | EXPANDED_EXCEPTION
  min_hanzi: 5000 | 4000 | 7001
  max_hanzi: 7000 | 4999 | 8000
  count_scope: ## 引言 至 ## 结语完整章节
  count_method: Unicode CJK Unified Ideographs U+4E00-U+9FFF 逐字符复算；Python ord() + Perl ord() 双实现；忽略正文 ---，以交接标题截断
  status: NOT_STARTED | COUNTED | REWORK_REQUIRED | PASSED | BLOCKED
  count_attempt: 0
  last_count: null
  exception_reason: null
```

第 7 步必须执行：

1. 从 `## 引言` 标题开始，完整截取至 `## 结语` 章节结束；正文中的 Markdown 分隔线 `---` 不构成计数终点。计入正文小标题和直接引文；在结语之后，以最早出现的 `## 引用—主张映射`、`## 参考材料` 或 `## 交接信息` 标题作为正文终点，排除这些标题及其后内容、主标题和元数据。
2. 汉字集合固定为 Unicode CJK Unified Ideographs `U+4E00-U+9FFF`，逐字符判断 `0x4E00 <= ord(ch) <= 0x9FFF`。不得使用 `\p{Han}`、`\p{Script=Han}` 或语言运行库的宽泛 Han Script 属性，因为它们在运行库之间可能包含不同字符集合。
3. 将实际整数写回 `body_hanzi_count` 和 `length_gate.last_count`，并记录计数工具/版本与计数时间；不得写“待统计”“预估”或未经复算的手填数字。
4. 若计数低于档位下限或超过档位上限，将状态写为 `REWORK_REQUIRED`，回到第 7 步补写或压缩，递增 `count_attempt`，完成后重新计数。重新计数前不得交审核。
5. 若计数低于 4000 或超过 8000，状态写为 `BLOCKED`，记录 `length_failure_reason` 并按根因回退；不得靠改档位放行。
6. 只有整数计数落在已锁定档位范围内，且正文范围、计数方法和元数据三者一致，才能写 `status=PASSED` 并自动交第 8 步。
7. 在写入 `status=PASSED` 前，必须保存最终初稿，再对同一完整范围分别运行两种真正独立的逐字符实现：Python `ord()` 与 Perl `ord()`。两次结果、`body_hanzi_count` 和 `last_count` 必须完全一致；Awk、sed 或其他工具只负责截取而最终仍调用同一计数引擎时，不构成第二实现。任何不一致均写 `COUNT_MISMATCH` 并禁止交审核。

第 8 步只能复算并验收 `PASSED` 状态。若审核复算与第 7 步不一致，输出 `COUNT_MISMATCH`，退回第 7 步，不得直接修正数字或改变档位。

### 语义边界执行门 `scope_guard`

第 3-5 步在文章设计包中冻结：

```yaml
scope_guard:
  excluded_topics: []
  allowed_roles:
    - boundary_disclaimer
    - limited_comparison
    - source_note
  forbidden_roles:
    - title_claim
    - section_thesis
    - evidence_claim_mapping
    - conclusion_claim
  boundary_decision: PASS | REVIEW | BLOCKED
```

审核时逐项定位受限主题出现的位置和作用：允许“本文不扩展到安天大会”这类边界声明，允许明确标注为旁参的有限比较或来源说明；若受限主题承担标题承诺、章节主张、核心证据、引用—主张映射或结语结论，则为 `BLOCKED`。测试和静态扫描必须使用角色断言，不得把 `must_not_contain` 作为唯一判断。

## 归档后发布语料

- 用户确认终稿并建立 `published/` 快照后，主控在 `stage=8` 的 `post_archive.publication_copy` 子阶段调用 `xiyouji-publication-copy`。
- 该子模块内部生成 3 条候选，自动筛选 1 条 120 个可见字符以内的公众号推荐语；常规不进入 `USER_WAIT`。
- 输出写入 `distribution/第X回-篇号-主题/v版本/公众号推荐语.md`，状态写入状态卡的 `post_archive_outputs.publication_copy`。
- 正文保持 `terminal_outcome=ARCHIVED`；推荐语失败只更新附属交付状态，不回退正文流程。重跑不得修改既有分发文件：首条使用 `公众号推荐语.md`、`copy-v1`；后续更正或重跑必须新建 `公众号推荐语-copy-vN.md` 并写入递增的 `copy-vN`，随后冻结该文件与所属分发版本目录。
- 标题优化、公众号排版、公众号节选、小红书、口播和朋友圈改编必须由用户明确触发，并只读 `published/` 快照。

## 产物兼容

新文章按统一路径生成。历史文章通过 `asset_pointer` 和 M1 迁移说明引用原路径，不移动、不覆盖、不伪造缺失过程资产；历史发布资产按需在 `distribution/` 建立新分支。
