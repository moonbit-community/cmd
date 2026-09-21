# 0.2.0 命令语义保真候选实现

日期：2026-09-20。状态：本地候选，未发布。
宿主：macOS 26.5.2 / Darwin arm64。Native 与 Wasm 均在该宿主运行，
不能外推为 Linux/Windows 认证。原始发布版本的
[审计与证据](2026-09-19-command-fidelity-audit.md)保留不变。

## 依赖与实现基线

工具链与官方 version.json 核对后保持 moon/moonrun 0.1.20260915、
moonc/core 0.10.13+cbb11c36f。全部工作区模块统一 async 0.22.1 和 x 0.5.5，
moonjq 仍为 0.1.2。[完整解析树](2026-09-20-fidelity-evidence/dependency-tree.json)
确认没有残留旧版传递依赖。

依赖升级首先单独验证：Native 104/104、Wasm 91/91；
[升级阶段补丁](2026-09-20-fidelity-evidence/dependency-upgrade.patch)保留了行为修改前的状态。
新版取消模型下，fixture 清理先取消所有子进程，再在不可取消区域 wait。
所有项目实现和新增自动化均为 MoonBit；没有新增项目 C/Rust/JS/FFI，
没有调用宿主同名命令代替实现。测试用系统 ln/stat 构建和检查链接、权限，
宿主 curl/wget 仅作为 oracle。

## 实际调用结果

[Native 逐条结果](2026-09-20-fidelity-evidence/native.jsonl)与
[Wasm 逐条结果](2026-09-20-fidelity-evidence/wasm.jsonl)记录 argv、status、
stdout、stderr；对应可执行断言在 `tests/fidelity.mbtx`。

| 原审计问题 | 候选实测行为 |
| --- | --- |
| cp 同 inode 别名被截断 | 同路径、硬链接、已存在目标均非零拒绝；源/目标内容和链接身份保持；显式 `--no-preserve=mode` 新目标复制成功 |
| cp 新文件权限不正确 | 默认复制明确报告缺少 mode reader；不以错误权限宣布成功 |
| touch 写回内容模拟时间 | 已有文件非零拒绝，mtime/内容保持；创建、`-c` 缺失 no-op、前面成功操作在后续失败后保留 |
| 环境过滤与 locale 重写 | env 子进程保留任意变量；`LC_ALL=POSIX` 保持 POSIX；sh 局部变量不自动 export |
| grep 分隔符/BRE/-o | 无 context 不插入 `--`；默认 BRE；`-Eo 'a|aa'` 输出最长 `aa` |
| base64 / seq | `-w0` 无末尾 LF；`seq 3 1` 空输出；显式负步长仍输出倒序 |
| jq 单文档及 --arg 文本替换 | 连续 JSON、slurp/raw/null/exit、lexical shadowing 通过；后续解析失败保留早先输出并返回 4 |
| sh 错误成功 | 算术除零返回 2；赋值命令中的失败 substitution 返回非零；替换仅删末尾换行 |
| mkdir/chmod | `mkdir -p -m700` 普通 umask 下 parent=755、leaf=700；命令行 symlink chmod 修改目标 |
| make shell/-j | shell 函数得到 `one two`；并发 start 标记先于 finish，shared prerequisite 只执行一次；失败 prerequisite 阻止后续目标 |
| rm 额外策略 | `--no-preserve-root` 普通临时文件操作成功；最终 dot/dot-dot 仍按命令语义拒绝 |

普通 cp 与已有文件 touch 的拒绝是明确的功能收缩，不是完整上游行为。
解除条件见 [ADR-0004](../adr/0004-filesystem.md) 和
[上游缺口文档](../async-upstream-gaps.md)。

## 交互与网络

`commands/sh/interactive_probe.mbtx` 在 stdin 一直打开时逐轮验证 ENV、
PS1/PS2、变量、多行、read、前台 head、语法恢复、EOF。
[Native](2026-09-20-fidelity-evidence/repl-native.log) 和
[Wasm](2026-09-20-fidelity-evidence/repl-wasm.log)均通过。
公共 Session 的 feed/finish API 不要求输入 EOF 才执行完整命令。

`core/netops/verify_cli.mbtx` 使用纯 MoonBit loopback HTTP fixture，
每个后端完成 30 次与本地 oracle 相符的调用，以及 1 次明确拒绝的组合。
[Native 网络结果](2026-09-20-fidelity-evidence/network-native.log)、
[Wasm 网络结果](2026-09-20-fidelity-evidence/network-wasm.log)覆盖 Basic 请求、
Wget challenge、cookie 重复/重定向/保存加载、文件权限和 jar 写失败状态。
Oracle 为 Apple curl 8.7.1 与 GNU Wget 1.25.0，不能写成 Linux curl 8.22 认证。
curl 字面量 -b 跨主机仍发送；自定义 Cookie header 跨主机移除。
自定义 Cookie header 与匹配 jar 同时使用需重复请求字段，公开 Map 接口不能
表达，因此发送前拒绝。响应侧多个 Set-Cookie 已通过公开 cookies 数组支持。

## 回归与发布边界

最终全工作区结果：Native **132/132**，Wasm **119/119**；两后端 check/build
通过，Native compat 与 Wasm policy runner 通过。网络与 REPL 实际调用独立于
单元测试计数。没有以单元测试通过代替命令差分或交互验收。

全工作区检查与测试、兼容性 runner、Wasm 授权 runner 的最终结果见同目录
`check-*.log`、`test-*.log`、[compat.log](2026-09-20-fidelity-evidence/compat.log)
及 [policy.log](2026-09-20-fidelity-evidence/policy.log)。授权测试使用真正外部
命令测试进程拒绝；shell 内建 printf 不再被错误地要求具有 ProcessSpawn。
`moon fmt`、`moon info` 已运行；接口变化是 Session/capture、CookieJar/transfer
参数、精确 cp 选项与平台 EXDEV 分类。最后清理了新版工具链识别出的无用导入，
旧 jq raw 测试改为经过实际输入读取路径；`moon check --target all --deny-warn`
通过。最后受影响包的定向回归另通过 Native 15/15、Wasm 11/11。

所有 cli 模块已设为 0.2.0。发布候选清单
`tests/release_runner/candidate-0.2.0.json` 标记 candidate=true、published=false，
仅允许 validate，不能被当成已发布 MoonX 包调用。
`tests/release_runner/manifest.json` 仍固定历史 0.1.x 版本用于重放。
它引用冻结的 `published-0.1-base.json`，因此候选 fixture 修订不会改写历史含义。
工作区 oracle 的新建 cp 用例显式使用 `--no-preserve=mode`；已有目标 backup
用例继续保留，并验证上游成功、候选明确拒绝及内容不变，输出为 verified
rejection 而不是兼容通过。该 Linux oracle 分支尚待 CI 实跑。
smoke 未比较语义时输出 unverified_smoke 并使门禁非零；非零命令结果不再
自动要求整个 fixture 无副作用。differential 才比较 stdout/stderr 和最终文件。

本轮再次真实执行了旧版 `moonx cli/seq@0.1.5`、`cli/sh@0.1.7`、
`cli/env@0.1.4`：[结果](2026-09-20-fidelity-evidence/published-moonx.jsonl)
仍分别表现为自动倒序、算术失败但状态 0、help 状态 125。
这些结果证明候选与发布版本有区别，不代表候选发布验证完成。

当前宿主没有 Docker，因此未运行固定 GNU/Linux oracle，也未运行 Windows。
0.2.0 尚未发布，精确版本 MoonX release gate 必须在实际发布后执行。
没有将这三个门禁写成已通过。

## 复现

在仓库根目录串行执行 Moon 工作区命令，避免 `_build/.moon-lock` 冲突：

```text
moon check --target native
moon check --target wasm
moon test --target native
moon test --target wasm
moon build --target native --release
moon build --target wasm --release
moon run tests/fidelity.mbtx -- <absolute-root>/_build/native/release/build
moon run tests/fidelity.mbtx -- <absolute-root>/_build/wasm/release/build wasm
moon run commands/sh/interactive_probe.mbtx -- <absolute-root>/_build/native/release/build/cli/sh/sh.exe
moon run commands/sh/interactive_probe.mbtx -- moonrun <absolute-root>/_build/wasm/release/build/cli/sh/sh.wasm --
moon build --target native commands/curl commands/wget
moon build --target wasm commands/curl commands/wget
moon run core/netops/verify_cli.mbtx
CMD_NETWORK_BACKEND=wasm moon run core/netops/verify_cli.mbtx
moon run --target native tests/release_runner -- --manifest tests/release_runner/candidate-0.2.0.json --suite validate
```

后续范围仍由 [兼容表](../compatibility.md)、九份 canonical ADR 和
[上游反馈文档](../async-upstream-gaps.md)约束。高级终端/exec/job-control
需要公开接口；更完整的 grep、shell/make 语法、PSL/IDNA 则属于项目工作，
不能伪装成 async 的永久限制。
