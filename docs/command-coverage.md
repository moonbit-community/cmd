# 常见命令缺口与建议顺序

Updated: 2026-09-26

强制实现边界：所有命令包、共享库、测试 runner、fixture 和自动化必须使用
纯 MoonBit。宿主程序只能作为固定版本 oracle、测试观察器、CI 工具或诊断
采集器，不能作为 `cli/<cmd>` 的后备实现。缺少已发布公开 MoonBit API 时，
必须保留明确 boundary、ADR 和解除条件。

本次按目录、catalog、发布 manifest 和刷新后的 `cli/*` 注册表核对：
**59 个本地命令，47 个已发布 0.2.0，12 个本地未发布（base32、cksum、expand、mktemp、realpath、rev、tac、tree、unexpand、unlink、yes、timeout）**。
`cli/core` 是共享库，不计命令数量。已发布并不表示完整 GNU/POSIX 兼容；
每个命令的参数边界见 [支持记录](compatibility.md)。

基线清单包含 59 个常见缺口；本轮已实现其中 `base32`、`mktemp`、`realpath`、
`rev`、`tac`、`tree`、`unlink`、`yes`、`cksum`、`expand` 和 `unexpand`，因此下表列出当前剩余的 **48 个缺失候选**，不是“所有 Unix 命令”的统计。
基线取自 [GNU coreutils 9.11 命令分类](https://www.gnu.org/software/coreutils/manual/coreutils.html)，
加上开发中常用的文本、归档、进程工具及 [tree 上游](https://gitlab.com/OldManProgrammer/unix-tree)。
不把 shell 内建 `cd/read/export`、别名 `[`、Git、编译器和语言运行时计入。
此前这些候选都没有本仓库模块；本轮已迁移 `base32`、`mktemp`、`realpath`、`rev`、
`tac`、`tree`、`unlink`、`yes`、`cksum`、`expand` 和 `unexpand`，因此它们不再属于当前缺口。其余候选只是排期
建议，不把文档中的建议冒充已实施或已排期交付。

可重放的 [JSON 清单](reports/2026-09-21-api-probes/inventory.json) 和
[MoonBit 盘点程序](reports/2026-09-21-api-probes/inventory.mbtx) 保存具体集合；
“此前未规划”另由当前 README、ADR、支持记录及计划文件人工交叉核对，
不是仅凭目录不存在推断。历史审计中的提及不视为现行实施计划。

2026-09-26 起按 async 0.22.4 基线执行缺口补全。P0 命令按独立包逐项迁移；
只有在 README、help、catalog、兼容表和回归测试同步后，命令才会从缺口提升
为已验证子集。

本轮 P0 实施证据见
[`reports/2026-09-26-p0-command-completion.md`](reports/2026-09-26-p0-command-completion.md)。

| 类别 | 数量 | 缺失命令 |
| --- | ---: | --- |
| 文件与路径 | 9 | du、df、stat、readlink、install、truncate、split、csplit、link |
| 文本与表达式 | 11 | sed、awk、diff、patch、fold、fmt、od、hexdump、strings、column、expr |
| 编码、校验与归档 | 9 | md5sum、sha1sum、sha512sum、tar、gzip、gunzip、zcat、zip、unzip |
| 系统与执行 | 19 | date、uname、hostname、id、whoami、groups、ps、kill、watch、uptime、free、tty、stty、tput、clear、which、nproc、chown、chgrp |

## 建议优先补的开发缺项

**第一批已完成：tree、realpath、mktemp、yes、tac、rev、expand、unexpand、
base32、cksum、unlink。下一批候选：fold、od/hexdump、md5sum、sha1sum、sha512sum。**
这些命令有可实现的基础子集，不能统一归因于 async。`x/crypto` 已有 MD5、
SHA-1、SHA-512；二进制 IO、目录遍历、排他创建及 realpath 也已有公开入口。
仍需每项先确定上游参数、错误与字节合同，再补 CLI 差分。`mktemp` 必须
采用安全随机源与排他创建，不能把时间戳文件名当作完成。

**第二批：sed、diff/patch、split/csplit、expr、fmt、strings、column、
which、date、awk、gzip/gunzip/zcat、tar/zip/unzip。**
主要成本是解析、格式与算法，纯 MoonBit 可实现，不应列成永久上游阻塞。
其中 which 需定义 PATH/可执行性与 alias/function 边界；date 的 UTC 格式
子集和本地时区数据库/设置系统时钟分开；归档的内容编解码和权限、链接、
时间恢复分开验收，不能只解出内容就称完整 tar/unzip。gzip 格式已有官方
async 包可复用，但命令选项和错误行为仍需实现。

## tree 的具体起点

`tree` 当前已实现无链接 fixture 下的基础子集：默认树形输出、`-a/-d/-f/-L`、
`--noreport`、排序、统计、多根操作数与失败状态；用固定版本 tree 的
完整输出比较，覆盖空目录、隐藏项、深度边界、不可读目录和 Unicode 名称。
目录可读性与权限错误应逐项报告，而不是静默省略。

[上游手册](https://oldmanprogrammer.net/source.php?dir=projects%2Ftree%2Fdoc%2F%2Ftree.1)
明确默认输出包含符号链接目标，`-l` 会跟随目录链接。因此“能画树”不等于
完整默认语义。当前 readlink 缺口影响箭头目标；identity/mode/owner 缺口影响
链接环、跨文件系统、权限/属主显示。首版遇到无法保真的链接必须明确报错，
不能虚构目标、静默忽略或把 realpath 当原始链接文本。Native/Wasm 要分别
验证，并在包 README 中明确普通目录子集，不能先宣称全部 tree 已支持。

本轮已完成 tree 的普通目录子集；以上链接、元数据和完整报告是后续边界项。

## 需要拆分 API 边界的候选

| 命令 | 可实现部分与仍缺能力 |
| --- | --- |
| du | 遍历及 apparent-size 可以研究；默认磁盘占用、硬链接去重、跨设备边界需要 blocks/identity/device 元数据 |
| df | 需要文件系统容量、可用块和挂载点信息；不能用文件大小累加代替 |
| stat | kind/size/时间读取已有；完整 mode/uid/gid/nlink/identity 不足，必须逐格式字段声明 |
| readlink / link | realpath 不等于 readlink；symlink 不等于 hard link，当前无公开等价入口 |
| install / truncate | 内容与新建子集可研究；owner、mode 读取、时间保存、句柄截断仍有限制 |
| uname / hostname / id / whoami / groups / nproc | 平台枚举只给 OS 类别；不能把环境变量当成真实宿主身份、组或 CPU affinity；需额外公开查询接口或逐平台可靠来源 |
| ps / uptime / free | Linux procfs 可能有纯 MoonBit 专用子集；不能外推 macOS/Windows/Wasm，未完成对应实测 |
| tty / stty / tput / clear / watch | 文本及定时调度可以实现；真实 TTY、termios、终端数据库/窗口和信号需要分别解决，固定 ANSI 字符串不是通用终端兼容 |
| chown / chgrp | 缺 owner/group mutation 入口；由宿主决定是否授权，项目不追加授权政策 |
| kill / timeout | 需要可观察失败的信号发送及组语义；公开 cancellation handler 会吞掉 Native kill 的错误，不能冒充 kill 成功状态；timeout 仍只本地提供直接子进程子集 |

API 解除条件见 [缺口文档](async-upstream-gaps.md)。这些条件只限制对应操作，
不应该阻止纯算法、文本和普通目录功能进入正常开发队列。
