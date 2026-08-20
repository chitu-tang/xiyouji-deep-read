# GitHub 迁移记录：RC.2.4

- 目标仓库：`chitu-tang/xiyouji-deep-read`
- 迁移版本：`xiyouji-chapter-longform RC.2.4`
- 迁移性质：在 GitHub 仓库中迭代回目深度解读 Skill；不涉及 `chitu-tang/xiyouji-interpret`。
- 本记录只描述工程迁移，不代表人民文学出版社 2020 年版三卷 PDF 已随仓库分发。

## 保留的仓库资产

- `knowledge-base/`：既有回目索引、原文定位材料、评点、研究材料和框架资料。
- `style-guide.md`、`forbidden-words.md`：既有表达与禁忌材料，供兼容性参考。
- `sub-skills/`：迁移前的研究/写作/审校提示，作为历史参考保留；RC.2.4 主管线不再依赖它们。
- `tools/doubao_web_search.py`：既有可选联网检索适配器，密钥仍只从环境变量读取。

## RC.2.4 成为权威管线

- 根目录 `SKILL.md` 已替换为 RC.2.4 主控规范。
- `modules/` 提供 0A、0B、研究、设计、写作、审计和归档后的分发交接规则。
- `scripts/` 提供三卷正式底本注册、0A 预检、双实现篇幅门、逐实例引文闭合、资产计划归档、分发验证、冷安装和 ZIP 卫生回归。
- `references/` 与 `templates/` 提供 RC.2.4 的研究导航、表达边界、资产卡和归档资产计划模板。
- 远程仓库不包含 PDF、用户工作区、文章快照、发布资产或任何本机绝对路径。正式 PDF 必须由运行方在本机注册，并由 0A/0B 独立核验。

## 兼容性边界

`knowledge-base/original-text/` 是仓库既有的定位与研究材料，不得替代人民文学出版社 2020 年版三卷 PDF 的正式引文核验。在线文本、OCR、知识库内容和搜索结果只能用于定位或研究线索；正式文章的直接引文必须通过运行方自己的正式底本和 0C 引文台账闭合。

## 验证

在仓库根目录执行：

```bash
bash scripts/verify-release.sh
bash scripts/test-gates.sh
bash scripts/test-release.sh
```

`test-release.sh` 会在临时目录执行冷安装与干净 ZIP 回归。ZIP 不得包含 `._*`、`.DS_Store`、`__MACOSX`、`__pycache__` 或 `*.pyc`。
