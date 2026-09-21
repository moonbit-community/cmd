# 测试体系审计与清理建议

日期：2026-09-21。对象：当前未发布的 0.2.0 工作区，包括本轮尚未提交的实现。
本次完成 README 同步、测试结构审计和针对 runner 的实际调用复核；没有删除测试、重构 runner 或缩减 CI。以下重组方案均为建议。

## 结论

维护负担主要集中在重复的黑盒基础设施、分散的行为定义和按历史阶段堆积的集成测试。现有 48 个命令只有 132 个 MoonBit 测试声明，单凭数量没有证据认为单元测试过多。清理应优先统一执行和判定逻辑，同时补上当前门禁漏掉的高价值场景。

本机只完成 macOS 上的静态审计及定向发布入口复核，没有重新跑完整回归、Linux Docker 或 Windows，也没有测量 CI 墙钟时间。下文“重复执行”有调用链证据，“节省多少时间”仍需 CI 数据。

## 当前组成

| 层 | 当前规模与位置 | 作用和边界 |
| --- | --- | --- |
| MoonBit 包测试 | commands/core/tests 下 29 个测试文件，132 个 `test` / `async test` 声明 | 包括算法、解析、公开接口及部分进程集成；声明数不是各后端执行数 |
| 工作区 runner | `compat.mbt` 3,886 行；`main.mbt` 994 行；`policy.mbt` 1,040 行 | compat 硬编码；oracle 读取 JSON；policy 验证宿主授权 |
| 活跃 oracle 数据 | `tests/fixtures/runner/cases.json` 1,923 行、176 cases、48 commands | 并非 compat 的单一数据源，也不是全部新增回归的索引 |
| 发布 runner | 非测试 `.mbt` 合计 1,533 行 | 精确 MoonX 版本、单独的 schema/fixture/快照/HTTP/报告实现 |
| 发布清单 | 历史及候选各 47 包；候选选择 94 cases | 0.2.0 仅 validate；旧版用独立冻结 base 保持可重放 |
| 独立探针 | fidelity 247 行、REPL 84 行、HTTP 232 行 | 覆盖关键新行为，但没有被当前 workflow 调用 |
| 宿主策略 | 9 个 policy JSON | 独立检验允许/拒绝，不能代替命令语义认证 |

计数来自当前文件的 `rg`、`wc -l` 和 JSON 读取。历史报告中的脚本、日志和冻结发布 fixture 不按活跃测试重复计算。

## 优先修正的判定和覆盖问题

1. **发布 smoke 目前必然把未做差分的正常调用当失败。**
   定向执行 `moonx cli/true@0.1.5` 对应 case 后，runner 输出 `unverified_smoke`，最终退出 1。不是包执行失败。源码是 `release_runner/main.mbt` 的 389 行分类和 601 行汇总；workflow 却仍把 smoke 作为三平台定时门禁。应将“调用成功但语义未验证”和“语义匹配”分别记录；availability smoke 可按自身有限断言成功，release gate 必须要求差分/明确合同。不能再用统一 passed 将二者混同。

   本次实测结果保存在 [smoke.log](2026-09-21-test-system-evidence/smoke.log)，复现驱动为 [probe.mbtx](2026-09-21-test-system-evidence/probe.mbtx)。它在 `/tmp` 生成只选择 true 的历史清单，不改仓库发布清单。先执行 `moon build --target native --release`，再从仓库根目录执行 `moon run docs/reports/2026-09-21-test-system-evidence/probe.mbtx --target native`。该驱动包含 macOS ls 对照，断言的是审计时存在的问题；修复后应更新审计结论，而非把问题保持为产品合同。

2. **“文件系统快照相同”覆盖不足。**
   `runner/main.mbt:266` 和 `release_runner/fixtures.mbt:114` 都只保存路径、kind、普通文件内容。符号链接统一记录空内容；mode、时间戳和 hard-link identity 均未纳入。两条 symlink 指向不同位置、权限不同但字节相同，都可能逃过通用快照。`fidelity.mbtx` 已有部分 macOS stat 与链接关系断言，应迁入常规验收。缺少公开 API 的测量可在测试侧使用固定宿主 oracle；实现仍保持纯 MoonBit。测量不可用时记录该维度未验证，不能默认为相同。

3. **新增行为的完整进程回归没有进入 CI。**
   workflow 不调用 `fidelity.mbtx`、`interactive_probe.mbtx` 或 `verify_cli.mbtx`。包测试有 shell Session、CookieJar、make 调度覆盖，但不能证明真实 stdin 持续打开时的提示符、前台子进程输入交接和 CLI 参数到 HTTP 请求的完整路径。当前 `policy` 只覆盖选定 Wasm 场景，`oracle` 候选侧则只运行 Native。

4. **发布的选项覆盖账目可包含未执行用例。**
   `release_runner/manifest.mbt:271` 在整个 `base.cases + extra_cases` 中查 coverage；执行入口却使用 `selected_cases`。因此一个未选中的 base case 也能满足选项覆盖。`supported_options=[]` 又使多数命令的覆盖检查为空。建议覆盖校验基于实际选择集，并区分“case 已定义”“当前平台执行”“语义断言通过”。候选 validate 只能证明结构/版本符合约束，不能证明 94 个 case 已运行。

5. **contract 模式的验证强度不统一。**
   `main.mbt:400` 在状态和可选 token/newline/forbidden 字段通过后直接返回，跳过 oracle 和文件快照。例如 sh 的公开错误 case 只要求状态 2 且不出现两个内部字符串，完全空的 stderr 也可通过；jqlog 文件 case 只要求 stdout 包含 `1`。保留品牌差异合同有必要，但稳定输出应比较完整字节；文件型合同应显式声明副作用断言。校验器应拒绝名为语义合同却没有相应行为断言的用例。

6. **文档核对发现真实的行为漏测。**
   本地 Native 候选执行 `ls -H -1 link`（link 指向含 inside 文件的目录）得到 `link\n`、状态 0；本机 `/bin/ls` 得到 `inside\n`、状态 0，见同一份实测日志。这是 `commands/ls/main.mbt:270` 缺少命令行链接跟随分支造成的项目缺陷。本次将 README 改为如实说明，尚未修改该行为；不能因既有测试全绿而声称没有已知语义偏差。它也不是固定 GNU/Linux oracle 的认证结果。另补齐了 make 的帮助文本 `-j/-k/-W`，实际 `moon run commands/make --target native -- --help` 已确认输出。

## 可清理的维护负担

| 证据 | 建议 | 需要保留的区别 |
| --- | --- | --- |
| CI 先跑 compat，再跑 compat --gnu-diff；`run_compat_suite` 末尾才追加 9 个 GNU 比较入口 | Linux 一次 compat 带 GNU 扩展，或把 GNU 扩展改成独立可选组 | 固定 Docker oracle 与宿主 GNU 的版本证据不同，不能互相冒充 |
| 两个 runner 各有 hex 解码、路径校验、fixture、快照、normalization、受控环境和 HTTP 服务 | 先将语义相同的实现移到现有 tests/testkit，再保留两个轻量入口 | MoonX 注册表故障与本地 artifact 故障仍分开分类；不要为“一个入口”堆 mode flags |
| compat 里混放 `phase345`、`p2_p3`、`p5`、`p9`，HTTP 段超过千行 | 同包内按 text/filesystem/process/shell/network 分文件，再按 command/case 可选择运行 | 拆文件本身不节省执行时间；无需因拆文件增加新 MoonBit package |
| base64 -w0 同时出现在单元、compat 和 fidelity；make 并发事件脚本同时出现在包测试和 fidelity | 在同一层、同一入口、同一断言的重复可合并；算法边界留包测试，CLI wiring 留一个真实进程 case | 不按名字或输入相似直接删：单元和进程、Native 和 Wasm 是不同失效面 |
| 自写 compat/JSON/release extras/探针各维护一部分参数行为 | 活跃命令合同按命令集中，发布版本清单引用稳定 case ID | 历史 `published-0.1-base.json` 是冻结证据，应保留或显式归档，不能改为跟随当前行为 |
| testkit 无统一 timeout；workspace oracle 无单 case timeout；make 并发依赖 100ms sleep | 测试 helper 支持 deadline、关闭/取消/wait；并发用 ready/ack 屏障证明重叠 | timeout 是故障边界，不用更长 sleep 掩盖调度问题；真实持续会话仍需专门驱动 |
| make 测试在 Windows `return`；部分 mode/inode 断言只在 MacOS 分支执行 | 场景报告显式记录 skipped/unsupported，列出缺失观察维度 | 不能把“测试函数返回成功”当作 Windows 并发或 Linux metadata 验证 |

不要优先删除 malformed bytes、部分输出/写入、同 inode、取消回收、持续 stdin、失败传播测试。它们防护的是之前真实出现或改动直接涉及的失效模式。历史审计证据也不应作为瘦身对象。

## 成熟项目提供的可借鉴做法

以下为 2026-09-21 查阅的官方仓库/文档，借鉴组织方法，不引入 Rust/Go 测试运行时。

| 项目 | 当前实现做法 | 对本项目的建议 |
| --- | --- | --- |
| [Rust uutils/coreutils 测试指南](https://github.com/uutils/coreutils/blob/main/DEVELOPMENT.md) 与 [入口源码](https://github.com/uutils/coreutils/blob/main/tests/tests.rs) | 测试按 utility 组织；允许只运行指定命令；自身测试和 GNU 上游测试分别运行；支持替换被测 binary 入口 | 按命令选择、共享启动适配器，把自身回归与 oracle 保留为不同证据 |
| [Go cmd/go script tests](https://go.dev/src/cmd/go/testdata/script/README) | 一个场景带自己的文件 fixture；独立临时工作目录；可单场景筛选；失败显示最近阶段，支持保留工作目录 | 一个 case 内收拢输入/断言/fixture，提供 `--case` 和失败现场保留；普通文本用可读内容，NUL/非法 UTF-8 才用 hex |
| [Rust ripgrep 测试入口](https://github.com/BurntSushi/ripgrep/blob/master/tests/tests.rs) 与 [公共 helper](https://github.com/BurntSushi/ripgrep/blob/master/tests/util.rs) | 按 binary/json/multiline/feature/regression 组织；共用临时目录与命令对象，入口支持跨平台 runner | 网络、交互、多轮状态用 MoonBit 场景函数，共用启动/清理/诊断；不强行塞进复杂 JSON DSL |

Go 的脚本不是通过系统 shell 执行，但为此重写一门 testscript 语言会给本仓库增加解析器和语义维护负担。当前阶段保留简单数据 case 与纯 MoonBit 场景函数更合适。

## 建议的收敛结构

保留三类测试：包内逻辑/API 测试；单次命令输入输出与副作用合同；需要多轮交互或生命周期的场景。共用小型 testkit 和启动适配器，让同一命令 case 能选择 Native artifact、Wasm artifact 或精确 MoonX 版本。Oracle 是期望行为的来源，policy 是宿主集成场景，二者不再复制整套命令定义。

| 工作顺序 | 具体交付 | 完成判据 |
| --- | --- | --- |
| 1. 判定与可见性 | 修正 smoke 分类；选项覆盖只计算选中 case；按 case 输出 status/耗时/skip/失败原因；接入三类独立探针 | 既不把未验证当通过，也不把正常调用当失败；已有关键行为进入 CI |
| 2. 低风险去重 | 共用 fixture/snapshot/timeout/report，拆分 compat 文件；消除 Linux 重复 compat 调用 | 每个旧断言有去向；变更前后同平台 case 结果一致，必要差异有解释 |
| 3. 收拢活跃合同 | 按命令管理 case；支持 command/case 过滤；静态 fixture 可读化；发布清单主要保留坐标和选择集 | 不再为同一 CLI 修复修改多份活跃合同；冻结旧版结果仍可重放 |
| 4. 根据测量调整频率 | 收集至少一组当前 CI 的编译/执行/失败重跑时间；复用同平台构建产物 | 先证明耗时来源，再考虑 stress/完整平台矩阵的频率，不先削减平台覆盖 |

可以移除的是重复机制和同层重复断言，而不是先设定删除百分比。第一批重构可集中在 testkit、compat 文件拆分和 Linux 双跑，避免同时改变用例内容、判定规则及发布流程。

## README 同步规则

本轮已核对命令包 README 的候选版本、支持参数和限制，修正历史 Wasm 页眉、环境白名单表述及新增语义遗漏；测试及根 README 也已改为真实入口和覆盖范围。以后每次支持面变化应一起核对：命令 README、实际 `--help`、共享 catalog、canonical compatibility 和受影响的测试。涉及取舍再更新原编号 ADR。历史报告保持当时结论，并由新报告解释变化。

README 应直接说明当前包行为；canonical 文档负责完整证据与平台边界，不能用“仅供参考”掩盖包内过时说明。候选功能与已发布 MoonX 版本必须显式区分。
