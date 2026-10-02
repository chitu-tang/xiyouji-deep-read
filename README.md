# 《西游记》回目深度长文 Skill

当前版本 RC.2.4（2026-10-02 起生产运行）。这是可迁移的发布包，不包含《西游记》PDF、用户文章、研究资产或任何本机绝对路径。发布版文件校验单见 `release-checksums.sha256`；仓库内 `README.md` 与 `RC-VALIDATION.md` 为 GitHub 适配变体，不在校验单对应范围内。

## 安装

从本仓库克隆后，将仓库根目录作为 `xiyouji-chapter-longform` Skill 根目录使用；不要把 `knowledge-base/` 或用户工作区复制进其他 Skill。内部模块由主控从 `modules/` 相对读取。

```bash
git clone https://github.com/chitu-tang/xiyouji-deep-read.git xiyouji-chapter-longform
cd xiyouji-chapter-longform
```

创建工作区并注册你有权访问的正式底本。初始化参数包含必填书目信息；它们会同时写入工作区配置与正式底本注册表，后续 0A 会比较二者：

```bash
./scripts/init-workspace.sh \
  /path/to/workspace \
  /path/to/正式底本卷册清单.tsv \
  "《西游记》" "吴承恩" "人民文学出版社" "2020年版" "你的ISBN" "你的正式底本集ID"
./scripts/verify-workspace.sh /path/to/workspace
```

`正式底本卷册清单.tsv` 必须使用严格表头，并按上册、中册、下册排序；每行均须提供可访问 PDF 的路径、SHA-256、页数和注册表行号：

```tsv
volume	formal_source_path	formal_source_sha256	pdf_page_count	registry_row
上册	/path/to/西游记上册.pdf	<sha256>	<page-count>	上册
中册	/path/to/西游记中册.pdf	<sha256>	<page-count>	中册
下册	/path/to/西游记下册.pdf	<sha256>	<page-count>	下册
```

初始化会创建工作目录、引用模板、正式底本注册表和 `xiyouji-longform-workspace.yaml`。正式 PDF 只保留在你的本机路径，不会被复制进 Skill 或工作区。

## 构建发布包

在验收通过的目录外构建 ZIP。脚本拒绝覆盖既有文件，并排除 `._*`、`__MACOSX/`、`__pycache__/` 和 `*.pyc` 元数据：

```bash
./scripts/build-release-zip.sh /path/to/xiyouji-chapter-longform-rc.zip
(
  cd /path/to
  shasum -a 256 xiyouji-chapter-longform-rc.zip > xiyouji-chapter-longform-rc.zip.sha256
  shasum -a 256 -c xiyouji-chapter-longform-rc.zip.sha256
)
```

## 发布前验收

```bash
./scripts/verify-release.sh
./scripts/test-gates.sh
./scripts/test-release.sh
```

`test-gates.sh` 覆盖正式底本 0A、双实现篇幅边界、计数分歧和引文异文；`test-release.sh` 在临时目录执行冷启动、书目信息绑定、归档资产计划、分发与篡改回归。两者都会保留临时沙箱路径，由运行方按本机策略清理。

## 分发资产版本

首条公众号推荐语使用 `公众号推荐语.md`，元数据为 `copy-v1`。同一归档版本如需更正或重跑，必须保留 `copy-v1`，改写为新文件 `公众号推荐语-copy-vN.md`，并将元数据递增为 `copy-vN`。每个分发版本目录冻结后不得覆盖。

## 运行边界

- 工作区缺少正式 PDF、哈希不一致、书目信息不完整或注册表与配置不一致时，主控必须进入 `HARD_STOP`。
- OCR、在线文本和打包示例仅可作导航，不可替代正式底本直接引文核验。
- 归档必须有版本化归档资产计划 TSV（如 `revisions/第X回-篇号-主题-vN-归档资产计划.tsv`），逐项声明快照文件、角色和版本状态。`create-archive-manifest.sh` 将其哈希和受准资产写入清单，拒绝计划外文件与泛名 `审核报告.md`；复验时快照文件集合必须与清单完全相同。
