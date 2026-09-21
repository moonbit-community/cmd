# 命令原样迁移审计：以 MoonX 发布命令的实际结果为准

日期：2026-09-19。源码基线：`8b79e9bfd43c4d57ac615959cf21bf9e6c4c2668`。

**结论：把授权策略交给上层，是合理的职责调整；但当前实现离“命令原样迁移”还有独立的语义缺陷和功能缺口。只删除 policy 相关逻辑不能解决这些问题。** 当前成果可以描述为 MoonBit 实现的命令子集，尚不适合整体替换现有 Unix 命令。优先级最高的是已经复现的 `cp` 数据丢失，其次是成功退出却输出错误的命令，以及环境继承被主动改变。

本次没有修改产品实现、发布模块或刷新测试预期。新增内容只有本报告和审计证据。

## 实际检查范围

- macOS 26.5.2、Darwin arm64；`moon 0.1.20260915`，`moonx 0.1.0`；候选使用默认 Wasm。
- 实际运行现有 published smoke：**47 个发布命令、94 个用例，全部通过**。候选是 manifest 中固定版本的 `moonx cli/<cmd>@<version>`。
- 另做 **136 个针对性候选调用**：文本 33、文件系统 46、网络/jq 23、进程/语言/可用性 25、显式 policy 对照 7、seq 对照 2。普通调用使用用户要求的 `moonx cli/<cmd> ...`；其中包含一次未发布的 `cli/timeout` 可用性探针。这个数量不是覆盖率或兼容率。
- 执行 `moonx -v cli/echo@latest registry-refresh` 刷新 registry index 后，再逐一核对 47 个无版本坐标：全部与 release manifest 一致。`sh=0.1.7`；`echo/false/jqlog/seq/sleep/true=0.1.5`；其余 40 个为 `0.1.4`。均实际使用缓存发布 Wasm；证据中保存了 SHA-256。
- 除 7 个 policy 对照，调用均不传 policy。文件操作仅使用隔离临时目录；网络仅访问本次创建的回环 HTTP fixture，结束后关闭。
- 原生对照主要是 macOS 工具；另外使用 GNU Wget 1.25.0、Apple jq 1.7.1、curl 8.7.1。没有运行固定 GNU/Linux Docker oracle，也未验证 Windows、Linux、PTY、长流或公网 HTTPS。本次不能声称完整 GNU 兼容认证。

汇总入口：[原始发布结果](2026-09-19-command-fidelity-evidence/release/summary.jsonl)、[版本解析](2026-09-19-command-fidelity-evidence/process/inventory.jsonl)、[环境](2026-09-19-command-fidelity-evidence/environment.txt)、[发布资产摘要](2026-09-19-command-fidelity-evidence/assets.sha256)。源码用于解释发布行为，不把本地编译结果冒充发布结果。

## 最重要的实际发现

| 优先级与问题 | 实际调用和输入 | MoonX 结果 | 对照结果 |
| --- | --- | --- | --- |
| **P1：cp 清空源文件** | 源和目标为同一文件的两个硬链接；`moonx cli/cp alias-source.txt alias-dest.txt` | **退出 0；两处从 17 字节同时变成 0 字节** | 原生 cp 退出 1；两处保留 17 字节 |
| 环境继承被改写 | 父进程设置 `CMD_AUDIT_MARKER=present`；`moonx cli/env /usr/bin/printenv CMD_AUDIT_MARKER` | 退出 1，无输出；直接 `moonx cli/printenv CMD_AUDIT_MARKER` 能输出 `present` | 原生 env 子进程输出 `present`，退出 0 |
| grep 普通输出错误 | 输入 `alpha\nbeta\nalpha2\n`；`moonx cli/grep -n alpha` | `1:alpha\n--\n3:alpha2\n`，退出 0 | `1:alpha\n3:alpha2\n`，退出 0 |
| grep 默认正则错误 | 输入 `aaa\na+\n`；`moonx cli/grep 'a+'` | 输出两行，退出 0 | 默认基本正则只输出 `a+` |
| jq 默认多值输入失败 | 输入 `true\nfalse\n`；`moonx cli/jq -e .` | 无输出，退出 5，解析第二个值失败 | 输出两个值，最终退出 1 |
| jq slurp 失败 | 输入 `1\n2\n`；`moonx cli/jq -sc .` | 无输出，退出 5 | `[1,2]\n`，退出 0 |
| jq 参数绑定错误 | `moonx cli/jq -nr --arg name Moon '"hello \($name)"'` | Undefined variable，退出 5 | `hello Moon\n`，退出 0 |
| sh 算术展开错误且成功退出 | `moonx cli/sh -c 'printf "%s\n" $((1+2))'` | 只输出换行，stderr 有 process OSError，**退出 0** | 输出 `3\n`，退出 0 |
| sh 没有路径展开 | 工作目录有 `Makefile.*`；`moonx cli/sh -c 'printf "%s\n" Makefile.*'` | 输出字面量 `Makefile.*` | 输出匹配的文件名 |
| sh 局部变量自动导出 | shell 中赋值 `CMD_INNER=private`，不 export，再启动子 shell 读取它 | 子进程读到 `private` | 子进程读不到该变量 |
| make 函数被吞掉 | recipe 使用 `$(shell printf computed)` | 输出空行，退出 0 | 输出 `computed` |
| make 接受 -j2 却顺序运行 | 两个独立目标 A/B；A 先 sleep 再打印，B 立即打印 | 输出 `AB` | 同机 GNU make 输出 `BA`；代码也未保存 jobs 值 |
| cp 成功但改变权限 | 源权限 0640，复制到不存在的目标 | 新文件 0644 | 新文件 0640 |
| mkdir 中间目录权限改变 | `moonx cli/mkdir -p -m 700 created/a` | 父目录和叶目录都为 0700 | 父目录 0755，叶目录 0700 |

证据分别见 [文件操作日志](2026-09-19-command-fidelity-evidence/filesystem/followup.log)、[文件操作完整记录](2026-09-19-command-fidelity-evidence/filesystem/results.jsonl)、[文本字节结果](2026-09-19-command-fidelity-evidence/text/results.json)、[网络/jq 结果](2026-09-19-command-fidelity-evidence/network/results.jsonl)、[jq 追加结果](2026-09-19-command-fidelity-evidence/network/followup.jsonl)、[进程/语言结果](2026-09-19-command-fidelity-evidence/process/results.jsonl)。文本结果中的 stdout 为十六进制；进程和网络结果为 JSON 转义字符串。

文件系统和网络探针最初的 JSONL append 写法会截断已有记录；最终归档已经修复该写法并从各例独立 stdout/stderr、status 或原始日志恢复完整记录，未据此重复挑选测试结果。文件系统保留恢复校验记录。进程组同样使用完整 stdout 日志恢复 JSONL，并修正了复跑脚本。

## policy 到底干扰了什么

最直接的证据是同一运行时中的对照，而不是文档措辞：

1. 不传 policy 时，`cli/printenv` 读得到父进程的标记变量。
2. 同样条件下，`cli/env`、`cli/sh`、`cli/xargs`、`find -exec`、make recipe 的继承变量都丢失。xargs 例返回 123，make 例返回 2；find 的动作返回假时自身仍可退出 0，因此不能只看 find 的最终状态。
3. 父进程设为 `en_US.UTF-8` 的 `LC_ALL/LANG`，在 `cli/sh` 内变成 `C/C`。
4. 显式 policy 用 `env.set` 提供 `CMD_AUDIT_MARKER=policy-granted`，并允许相应 `/usr/bin/printenv` 子进程。`cli/printenv` 仍能读到；`cli/env` 和 `cli/sh` 仍丢弃它。另一个明确获准的 `/usr/bin/printf` 子进程可以正常运行。
5. deny policy 下，子进程启动被 runtime 拒绝。这证实了宿主授权边界与命令内部过滤是两个不同机制。

完整证据：[7 个 policy 对照](2026-09-19-command-fidelity-evidence/process/policy-results.jsonl)、[允许策略](2026-09-19-command-fidelity-evidence/process/policy-allow.json)。

源码与结果吻合：`core/process/process.mbt:26` 按白名单复制变量，`:37` 强制 locale，`:52` 在非 Native 目标选择 `WasmRestricted`。`core/process/process.mbt:108` 一带再以 `inherit_env=false` 把过滤后的环境交给子进程。这一层确实承担了上层已经能够承担的策略决策，并且影响了普通命令语义。

但不能把所有出现 policy 字样的代码都当成多余授权层。`core/cli` 的 Restricted/catalog 主要描述与测试能力，不是每次普通调用前的总开关。`core/platform` 中权限读取、时间设置、硬链接、readlink 等被固定为不可用，反映的是当前适配实现的能力边界；仅把 false 改成 true 或放宽上层授权，并不会实现缺失的底层操作。原样迁移还需要这些操作及对应的命令语义。

`docs/adr/0002-policy.md` 原本已经明确“harness owns policy”。实际偏离发生在共享环境过滤和为了受控子集而收缩的语言、文件系统契约。此次结论不依赖继续沿用旧设计定位。

## 已声明但仍妨碍原样迁移的功能缺口

下列操作本次均实际失败，不是因为未获得 policy 授权：

| 操作 | MoonX 实际结果 |
| --- | --- |
| `cp -p`、`cp -a` | 退出 1，portable filesystem profile 无法保留元数据/链接 |
| `cp -P` 复制符号链接；复制到已有符号链接目标 | 退出 1，拒绝相应链接处理 |
| `ln source hardlink` | 退出 1，硬链接不可用 |
| `ls -l`、`grep -o` | 退出 2，未知选项 |
| `chmod u+x,g=u,o-rwx FILE` | 退出 2，只支持完整 `=` 赋值 |
| `touch -t`、`touch -r` | 退出 1，时间设置不可用 |
| `touch DIR`、`touch SYMLINK`、`chmod 600 SYMLINK` | 退出 1；原生对照成功 |
| `sh` 的 `${X:-fallback}`、后台 `&` | 退出 2；都是普通 POSIX shell 场景，不是 Bash 专有语法 |
| `sh` 的 `exec` | 被当作外部程序查找，退出 127 |
| `sh` 的 `read answer` | 未更新 shell 变量，后续 printf 输出空值 |
| curl `-u`、`-b`；wget `--user/--password`、`--save-cookies` | 参数解析退出 2 |
| `moonx cli/env --help` | 退出 125 |
| `moonx cli/timeout 1 /usr/bin/printf ok` | registry 无此模块，moonx 退出 255 |

其中多个限制在 support record 中诚实记录为子集边界。这不等于已有承诺被违反，但在“原样迁移”这个新目标下，仍然必须进入待完成清单。

同一个 HTTP fixture 中，curl 显式 Authorization header 和 URL userinfo 都认证成功，所以 `-u` 的失败是 CLI 功能缺失。默认 `jq` 多 JSON 值输入是基本输入协议，不能归到高级 `--stream` 功能。`make -j` 的顺序执行虽已有文档说明，也不具有原命令的并行语义。

另外，`base64 -w 0` 实际输出 `aGVsbG8=\n`；文本组按 GNU 不换行字节契约将其列为差异，但此例没有本机 GNU base64 对照。`seq 3 1` 本次与 macOS seq 一样输出降序；项目文档记录了它与 GNU 的默认行为差异，本次没有把 macOS 一致误报为 GNU 差分通过。

## 已经可用的部分和测试解释

实测正常的场景包括 cat 二进制字节保留，cut/head/tail/paste/join/tr/uniq/sort/wc 的所测基本处理，sha256sum 已知向量，printf 格式复用，mv/rm/tee 的基本操作，数值 chmod、普通文件 touch、符号链接创建，以及 find 的类型、名称、布尔表达式、exec、size、mtime、prune。curl/wget 的本地 GET、相对重定向、HTTP 错误退出码有效；jq 单 JSON 上的 map/select/reduce/update/负下标/to_entries 有效；sh 的所测管道及 `$?` 有效。

所以已有移植成果有保留价值。问题在于这些成功不能推导整条命令的常规契约已经完整。

94 个 published smoke 全通过也没有抵消上述反例。`tests/release_runner/main.mbt:403` 在 smoke 模式下检查退出状态、可选字符串/换行条件等后直接记 passed，不进入后面的 oracle 字节和快照差分；成功用例也不统一比较最终文件状态。因此“cp 返回 0”不能证明源文件安全、权限正确，“grep 返回 0”不能证明输出字节正确。固定 GNU/Linux differential 是另一个模式，本次未运行；其结论也只覆盖被选中的用例。

## 建议的职责边界和处理顺序

目标可以落成一句可验收的契约：**在上层已经允许且平台能够执行的条件下，保留原命令的 argv/stdin、环境与 cwd 语义、stdout/stderr、退出状态及文件/进程副作用。** 支持边界以能力事实和上游规范表述，不能以“可控”“确定性”替代兼容性。

1. **先修成功路径的错误。** 首先是 cp 同 inode 截断；随后是权限、grep、jq、sh 等输出/状态问题。文件身份不能用 realpath 字符串相等替代。不能用更新 snapshot 或新增项目特例接受偏差。
2. **移走命令层的二次策略决策。** 保留 host API 的授权结果和错误传递；继承运行时实际提供的环境，命令自身仅按 env `-i/-u`、shell export 等原有语义改变它。用于测试可重复性的 `LC_ALL=C` 应由测试调用方设置。
3. **补齐平台适配。** 文件身份和 mode 读取、时间设置、链接等缺口需要实际实现；不应因 Wasm 最小能力集而永久删去 Native 或未来 host 可以支持的原生命令功能。命令算法与 host 操作接口仍有价值。
4. **重新安排 sh/make 的范围。** 它们是语言实现，成本远大于普通工具。先补日常 POSIX/GNU 语义，包括 glob、参数/算术展开、变量导出、常见内建、make 函数和并行调度；未完成期间明确为子集。上层沙箱可以决定宿主子进程的权限，但借用宿主程序实现整条命令是另一项产品选择，不能冒充 MoonBit 已完成同等移植。
5. **验收改为上游行为驱动。** 先确定各命令的 GNU/POSIX/其他上游版本，发布产物做字节、退出码、元数据和副作用差分；policy suite 保留为独立宿主集成检查。明确拒绝属于未支持，成功但错误应阻断相应发布。

最小复跑入口是证据目录中的 `.mbtx` 文件；脚本使用明确 `/tmp/cmd-audit-20260919*` 输出根，需要先建目录，重跑会覆盖该根中的审计输出，文件系统脚本只重建自己的 fixture。完整日志和聚合结果已在仓库中留档，无需依赖临时目录即可查看本次证据。现有发布 smoke 的复跑命令为：

```text
moon run --target native tests/release_runner -- --manifest tests/release_runner/manifest.json --suite smoke --report-dir /tmp/cmd-audit-rerun-release
```
