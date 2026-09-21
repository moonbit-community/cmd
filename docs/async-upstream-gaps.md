# MoonBit async 公开能力缺口反馈

Updated: 2026-09-21（新工具链复核；移除 Cookie 组合的错误阻塞归因）。刷新注册表后复核正式发布的 `moonbitlang/async 0.22.1`、
`moonbitlang/x 0.5.5`、`moonjq 0.1.2`；工具链为 moon/moonrun
`0.1.20260920`、moonc/core `0.10.14+7d59c7ec9`。三个依赖仍为最新正式版；
moonjq 的传递依赖解析到相同 async/x 版本，没有残留旧版本。
未将 upstream main 的未发布代码算作可用能力。

本表供上游讨论 API 语义；建议的 API 名称不是当前已存在的接口。
Native/Wasm 的“缺失”指公开 MoonBit API，不能据此推断 OS 或 Wasm
宿主没有底层能力。源码路径均相对 `.mooncakes/moonbitlang/async/src/`。
本轮结果与已发布 0.2.0 的三平台验收分开记录，见
[公开接口复查](reports/2026-09-21-public-api-recheck.md)；不将旧版 CI
或 macOS 结果冒充新工具链的 Linux/Windows 验收。

| 优先级 | 能力 | Native / Wasm 公开状态 | 分类与影响 |
| --- | --- | --- | --- |
| P0 | 文件 identity、句柄元数据、句柄截断 | 两者均无公开 identity/mode/truncate；句柄已有 kind/size/时间读取 | identity 内部已有但未公开；cp 无法安全保持已有 inode 的覆盖语义 |
| P1 | mode、所有者、link count、时间戳设置 | 两者均缺完整公共接口；已有路径 chmod | 元数据读取需扩展，setter 尚无可用实现；cp/mv/ls/chmod/touch |
| P1 | hard link、readlink、必要的句柄权限操作 | 两者均无公开接口；symlink 已有 | ln、cp/mv 链接保持；不能把 symlink 的存在当 readlink/hardlink 已支持 |
| P1 | isatty、终端属性与窗口大小 | 两者无公开终端 API；stdio fd 不是 isatty | sh 真实交互检测、raw mode、编辑、补全、resize |
| P1 | 可恢复信号订阅 | 仅全局取消信号配置 | sh Ctrl-C 后继续下一轮不能保证 |
| P2 | exec、进程组、前台终端归属、停止/继续事件、PTY | 两者无满足语义的公开 API | exec、fg/bg、job control、终端子进程、完整 timeout |

## P0：identity 与基于同一句柄的操作

目标：打开 source 和 destination 后比较稳定 identity；确认不同文件后，
在同一 destination 句柄上截断并写入，保留已有 inode 和硬链接关系。
新文件还需要 source mode，并遵循 umask。

公开证据：`fs/pkg.generated.mbti` 的 `File` 有 kind、size、时间、
position、seek、read/write，没有 identity、metadata/mode 或 truncate。
`File::fd` 已公开，但 Unix Native 是 OS fd，Windows 是 HANDLE，Wasm
是 opaque UInt64 host handle；不能把后者当 Linux `/proc/self/fd` 编号。
`CreateOrTruncate` 是打开时截断，发生在调用者能够比较 identity 之前。
内部证据：`internal/event_loop` 定义并使用 `FileIdentity`，watch 使用该类型；
Native statx/fstatx 路径和 Wasm 相关宿主导入已经存在。
因此准确分类是“identity 内部已有但未公开”，不是“Wasm 没有 inode”。

最小行为复现由 workspace runner 的 `filesystem-fidelity` 场景驱动：创建 source，
用测试 fixture 的系统 ln 建立硬链接 alias，执行候选 `cp source alias`，
再检查两个路径的内容。实现本身不调用系统 cp/ln。
旧发布包曾返回 0 并把 17 字节源文件变成 0 字节，见原审计。
候选 Native/Wasm 均非零拒绝，内容保持；`cp --no-preserve=mode source new`
在两后端复制成功。拒绝是暂时的严格子集，不是完成 GNU cp 覆盖语义。

建议：公开不透明、可比较的 `FileIdentity`；`File.metadata()` 返回
identity/mode/kind/size；`File.truncate(length)` 操作已打开对象。
明确 identity 的设备/卷作用域、生命周期、nofollow、race 和权限失败语义。
解除条件：有这些正式发布接口，且 same-file/hardlink、竞争替换、普通覆盖、
新文件权限、已有 inode 保留的测试全部通过。路径 realpath 或临时文件 rename
不能替代该条件。决策见 ADR-0004。

**替代路径复查**：Linux Native 可考虑从 `fdinfo` 的 inode/mount ID 与
`mountinfo` 的设备号获得 identity，再从 `/proc/self/fd/<fd>` 重开持有对象。
这不是跨后端方案，也仍缺普通 cp 的源 mode。当前 macOS 没有 procfs，
未验证 Linux bind mount、路径替换与权限失败，所以未开放覆盖；完整探针
验收条件和拒绝原因见公开接口复查报告。不能用 `(mnt_id, ino)` 代替
`(device, ino)`，也不采用 realpath、内容相等或 advisory lock 伪造 identity。

## P1：元数据、时间、链接和权限

公开证据：`fs/pkg.generated.mbti` 有路径/句柄 atime、mtime、ctime 读取，
路径 chmod、symlink、rename，没有公开 mode/uid/gid/nlink 读取、utime、
readlink、hardlink 或句柄 chmod。`x/fs` 也没有补齐这些语义。
`can_read/write/execute` 只能判断当前凭据访问权，不能还原 mode；realpath
会丢失相对链接原文且不能保留断链目标，不能代替 readlink。Windows chmod
属于“入口公开、运行时不支持”，与缺少公开入口分别记录。

最小复现：`filesystem-fidelity` 创建文件，记录 mtime 和 bytes，执行
`touch existing`，验证非零且两者保持；`touch new` 和 `touch -c absent`
成功。Native/Wasm 结果相同。其目的在于证明当前候选没有伪造更新时间，
不能把该拒绝当成上游已有 timestamp setter 的运行错误。

预期接口：明确 atime/mtime 的 Now、Omit、指定纳秒值和 follow_symlink，
提供 path 与 handle 两类设置；metadata 返回权限/类型/链接计数/身份；
hard_link 和 read_link 不隐式转成内容复制；句柄 chmod 不重新按路径解析。
ctime 的更新由宿主文件系统决定，不应提供随意写 ctime 的伪接口。

兼容性代价：普通 cp 的源权限、cp -p/-a、mv 跨设备保真、ls 长格式、
增量 chmod、touch 已有文件及 ln 硬链接仍受影响。解除条件是对应公开能力
正式发布，并分别完成权限、时间精度、链接关系和失败副作用的差分验证。

EXDEV 已不再是绝对 blocker：`@async.platform` 区分真实 Linux/MacOS/Windows，
POSIX `OSError(18, ...)` 可分类。候选 `core/platform.is_cross_device_error`
已实现 POSIX 分类。Windows 错误域未经运行验证，不把 POSIX errno 套过去。
即使能识别 EXDEV，也不能在缺少 mode/link/time 保持时宣布 mv fallback 正确。

## P1：基础交互之后的终端与信号

`stdio/pkg.generated.mbti` 公开 Input/Output 和 fd，未公开 isatty、
termios/raw、窗口尺寸或事件。`signal/pkg.generated.mbti` 只有
`set_global_cancellation_signals`，信号为 INT/TERM/HUP/BREAK。
字符设备可能是 `/dev/null`，不能代替 TTY 检测；fd 值也不是终端 API。

最小可运行复现：`sh-interactive-session` 保持子进程 stdin
打开，逐轮等待 stderr 提示符和 stdout，发送多行、read、纯 MoonBit 前台读行进程、语法错误
和 EOF。Native/Wasm 已通过。这证明行式 REPL 可实现，不能归入上游 blocker。
高级终端能力的验证方法是用真实终端检查属性/窗口变化与 Ctrl-C 后下一轮；
目前没有公开订阅接口，所以未声称该验收通过，也不通过构造函数名制造运行失败。

建议公开 `isatty(stream)`、终端属性读取/恢复、作用域化 raw mode、窗口大小和
变化事件。信号订阅应允许把 SIGINT 交给前台任务，在 shell 主会话未取消的
情况下等待/清理并继续。必须定义订阅与全局取消处理器的优先级和恢复语义。
`handle_cancellation` 能执行取消清理，但不能撤销当前任务取消；仅增加 catch
不能实现恢复。解除条件是正式公开 API 和真实终端的交互验收通过。

## P2：进程替换与作业控制

公开证据：`process/pkg.generated.mbti` 提供 spawn、collect_output、wait、
取消处理与管道，缺 exec、set/get process group、terminal foreground group、
stopped/continued wait events 和 PTY。Native 有底层 fd 并不等于已公开这些 API。

最小复现：候选 `sh -c 'exec printf x'` 明确拒绝，不把 exec 当可执行文件，
也不 spawn+wait 伪造 PID、信号、退出和文件描述符继承语义。基础命令调用和管道
仍可使用公开 process API。没有终端分组接口时不声称 fg/bg 验收通过。

建议 API 需分别表达 replace-current-process、建立/加入进程组、组信号、
前台终端归属、wait Exit/Stopped/Continued 和 PTY master/slave 的关闭规则。
定义取消作用域与 wait/reap 所有权，避免 kill 后遗留 zombie 或 pipe drain 挂起。
额外复查了公开 `CancellationHandler` 的函数值：Native `hard_cancel()`
内部会调用 kill，但丢弃其返回值。macOS
[负向探针](reports/2026-09-21-api-probes/cancellation-is-not-kill.mbtx) 中，
宿主确认不存在的 PID 在这个接口仍正常返回 Unit。`graceful_cancel` 还会
在延迟后升级 SIGKILL，并不是单次信号发送。因此不能据此实现保真的 kill；
建议新增带 OSError/权限/不存在反馈的 `send_signal`，不能把“内部已调用 kill”
写成“完整 kill 命令可用”，也不能反过来说完全没有信号发送的底层能力。
解除条件：Native/Wasm 各自具备完整公开链条，并验证直接子进程、后代、停止恢复、
终端 Ctrl-C 和取消后回收，不能仅靠一个 PID 的消失判定通过。

## 不应向 async 归因的项目工作

**已解除：curl 自定义 Cookie + jar**。此前仅检查单个 Map，漏看了公开
`Client(headers=...)` 与 `Client::request(extra_headers=...)` 两层独立参数。
async 0.22.1 会先发 client 字段、再发 request 字段。纯 MoonBit raw TCP
[探针](reports/2026-09-21-api-probes/http-header-layers.mbtx) 实测两个独立
Cookie 字段，与 macOS curl 8.7.1 同序；Wget 1.25.0 则只发送显式字段，
且跨源重定向继续发送显式字段，curl 会移除它。该区别另有 raw TCP 探针。
当前工作区已实现两种命令各自的行为，覆盖原始字节、同源/跨源重定向和真实
CLI，0.2.0 已发布包不包含此修正。没有拼接 CRLF、导入 internal、替换 HTTP
栈或加入 FFI。此组合不再作为上游 blocker。

**仍缺通用表达能力**：两层 Map 不能表达任意数量、任意顺序的重复字段，
所以不能从这个修复推断所有重复 `-H` 已保真。建议 ordered header list
仍有价值，但只适用于这部分剩余表达限制。响应侧 `Response.cookies` 已
保留多个 Set-Cookie。PSL/IDNA/cookie-prefix 规则仍属于项目实现工作。

Shell 解析、引号/分词/glob、JSON 输入分帧与 AST 变量绑定、cookie 管理、
make DAG 调度都已列入项目实现。grep 全部 GNU BRE/ERE 扩展、shell 完整
printf/test、反引号、算术赋值等剩余语法属于项目或正则/解释器适配范围。
不能用本表把可实现功能永久排除。

宿主拒绝是第三类结果：同一已公开操作在明确授权策略下运行，若被拒绝，
记录策略、原始错误与状态；这既不是缺公开 API，也不是缺底层运行时。
候选仅使用官方依赖提供的底层运行时，无项目自有 C/Rust/JS/FFI。
