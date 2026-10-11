# 文件系统、终端与进程公开 API 复核

Date: 2026-09-21

本记录复核已下载的正式发布包 `moonbitlang/async 0.22.1`、
`moonbitlang/x 0.5.5`，并检查当前工具链标准库的公开接口。
工具链升级为 moon/moonrun `0.1.20260920`、moonc
`0.10.14+7d59c7ec9`。这里只记录接口研究及可验证方向，不把源码推断
写成新的命令兼容验收结果；现有 0.2.0 的运行证据另见发布报告。

## 复核结论

`File::fd` **已经公开**，但不能由此推出各后端都能调用 OS 的任意 fd
操作。`types/types.mbt` 明确区分：Unix Native 是 OS `Int` fd，Windows
Native 是不透明 HANDLE，Wasm 是宿主资源的不透明 `UInt64` handle。
仓库中的 `pkg.generated.mbti` 是生成它的平台的接口快照，不能仅凭其中的
`Int` 推断 Wasm 表示。`raw_fd` 包还明确只支持 Native；其公开能力只是
接管 fd、读写及关闭，没有 stat、truncate、ioctl 或 exec。

| 目标 | 当前公开入口 | 本次结论 |
| --- | --- | --- |
| identity | `File::fd`，文件种类、长度、时间 | identity 已存在于 async 内部，但没有公开提取入口；Linux Native 的 procfs 是一个有条件的研究方向，见下节 |
| mode / owner / nlink | 路径 `chmod`、`can_read/write/execute` | access 查询只回答当前凭据能否访问，不能还原 owner/group/other、setid、sticky 或 ACL；不能用来保真复制 mode |
| 已打开对象的 truncate | 打开时的 `TruncateExisting` / `CreateOrTruncate` | 没有句柄 truncate；按原路径重新打开有竞争问题，Linux Native 的 procfs fd 路径需要单独验证 |
| 时间戳设置 | `atime/mtime/ctime` 读取 | 没有 setter；写回原字节、空写或读文件都不能表达指定时间、Now/Omit 与 follow/no-follow 语义 |
| readlink | `realpath`、`symlink` | realpath 返回解析后的绝对终点，会丢失相对目标原文，并且无法等价处理断链和链接环 |
| hard link | `symlink`、`rename` | 两者都不创建第二个指向相同 inode 的名字；复制内容也不等价 |
| isatty / termios / resize | stdio fd、Native `raw_fd` | 没有 ioctl / termios / isatty；字符设备判定、`TERM`、`/dev/tty` 可打开不能证明特定 stdin/stdout 是终端 |
| 可恢复 SIGINT | 全局取消信号集合、task 取消处理 | 可以选择全局取消信号，不能订阅并把 SIGINT 只送给当前前台任务；取消清理不撤销已取消任务 |
| exec / job control | spawn、wait、直接子进程取消 | 没有进程替换、进程组、前台终端归属、停止/继续事件或 PTY；spawn+wait 无法保持 PID 和信号语义 |

这里的“没有”指这些已发布包的公开接口，并不是在断言 OS 或 Wasm 宿主
没有底层能力。Windows 路径 `chmod` 是另一个类别：函数公开存在，但其
发布源码明确说明 Windows 上不支持并返回错误。

## Linux Native procfs：值得验证，但还不能作为已实现能力

Linux 官方文档公开了 `/proc/self/fdinfo/<fd>` 的 `ino`、`mnt_id`，以及
`/proc/self/mountinfo` 的 mount ID 与 `major:minor`。因此纯 MoonBit
通过 `File::fd` 和 `read_file` 读取并解析这些文本，有机会取得打开对象的
`(st_dev, inode)`；不能简单使用 `(mnt_id, inode)`，因为 bind mount
可能让同一文件拥有不同 mount ID。[Linux procfs 文档](https://docs.kernel.org/filesystems/proc.html)

`/proc/self/fd/<fd>` 指向已打开文件，而不是重新按原文件名寻找对象。
这提供了在持有句柄时重新打开同一对象的研究方向；它仍会重新检查访问权限，
并要求 procfs 可用和可访问。[Linux proc_pid_fd 手册](https://man7.org/linux/man-pages/man5/proc_pid_fd.5.html)

建议最小探针应当全部由 MoonBit 驱动，并至少验证：

1. 同一路径的两次打开、硬链接 alias、不同文件的 identity 分类。
2. bind mount 上同一 inode 的别名；不能把 mount ID 当 device ID。
3. 打开 destination 后，把其路径移走并放入另一个文件，再从 fd 路径
   截断；验证只有原来的打开对象及其硬链接发生变化，替代路径不变。
4. procfs 缺失、权限拒绝、fdinfo 缺字段或 mountinfo 找不到对应 mount 时，
   在任何写入前拒绝。
5. 单独验证 Native；**不能把 Wasm 的不透明资源 handle 插进 procfs 路径**。

如果上述证据成立，最多先开放 Linux Native 中具有明确入口条件的覆盖
子集；普通 `cp` 新文件所需的源 mode、preserve time/owner/link 等仍未解决。
本次本机为 macOS，且 `docker info` 的观察结果是 `command not found`；
因此没有在本记录中把该 Linux 方向标成实测可用，也没有据此放宽产品边界。

## 已排除的替代方案

- **以 advisory lock 代替 identity**：锁冲突也可能来自其他进程，锁语义还随
  OS 和文件系统变化；`try_lock` 的 Bool 不构成无歧义的文件身份。即使某个
  fixture 上能区分 alias，也不足以普遍保证安全覆盖。
- **缓冲 source 后再截断**：可减少某种内容损坏，但仍会把 `cp file alias`
  的应失败行为改成成功；没有补齐 identity 和权限语义。
- **通过修改 chmod 探测原 mode**：这是会改变待观察对象的操作，不能可靠恢复
  原权限、ctime、ACL 等状态；`can_read/write/execute` 也不是 mode 位读取。
- **realpath 冒充 readlink 或 identity**：丢失链接文本，并不能识别硬链接。
- **`protect_from_cancel` 包住整个 REPL**：这是取消屏蔽，不是新的可恢复信号
  订阅 API，不能据此保证每次 Ctrl-C 都能终止当前命令并恢复下一轮。
- **重新调用 async 的隐藏 main 入口**：`integration.mbt` 明确说明
  `run_async_main` 是工具链集成入口、不要直接调用；其 SIGINT 路径还会重新以
  信号终止进程。它不属于可供产品依赖的公开会话恢复 API。
- **导入 `internal/event_loop` 或自写 FFI**：违反本项目依赖公开 API 与
  无项目自有 FFI 的边界；即使编译可达也不作为本轮解法。
- **解包公开 `CancellationHandler` 实现 kill**：接口确实能调用 Native
  kill，但返回 Unit，`process/unix.c:144` 丢弃错误。macOS 的
  [实际探针](2026-09-21-api-probes/cancellation-is-not-kill.mbtx) 确认宿主
  `kill -0` 拒绝不存在 PID，而 hard_cancel 正常返回。缺少失败反馈和任意
  单次信号语义，不能实现可靠的命令状态；graceful_cancel 的升级 SIGKILL
  也不能冒充一次 TERM。这个替代路径已验证并因语义不符而不采用。

## 可复核的发布源码位置

以下路径相对 `.mooncakes/moonbitlang/async/src/`，版本为 `0.22.1`：

| 文件 | 证据 |
| --- | --- |
| `fs/pkg.generated.mbti:10`、`:80` | 路径及 File 的完整公开方法；有 fd、锁、随机位置读写，无 metadata/set-times/truncate |
| `fs/file.mbt:109` | `open` 接口；内部 open 返回的 identity 在这里被舍弃 |
| `internal/event_loop/fs.mbt:17`、`:35` | 内部 `FileIdentity { dev_id, file_id }`，open 同时获取 identity |
| `types/types.mbt:16` | Wasm opaque handle / Windows HANDLE / Unix fd 的不同表示 |
| `raw_fd/moon.pkg`、`raw_fd/pkg.generated.mbti` | Native-only，公开操作为读写及关闭 |
| `fs/utils.mbt:82`、`:121`、`:148` | access 查询、realpath 语义，以及 Windows chmod 不支持说明 |
| `stdio/pkg.generated.mbti` | 输入输出 fd 和 Reader/Writer；没有终端控制 |
| `signal/pkg.generated.mbti`、`async.mbt:50` | 全局取消配置；handle_cancellation 不清除取消 |
| `process/pkg.generated.mbti` | spawn/wait/cancel 及重定向；没有 exec 和作业控制 |
| `integration.mbt:16`、`integration.wasm.mbt:18` | 隐藏工具链入口收到全局信号后终止进程 |

`moonbitlang/x 0.5.5` 的 `fs/pkg.generated.mbti` 只有基本目录和整文件 IO，
`sys/pkg.generated.mbti` 只有退出及已弃用的环境/argv 接口；标准库公开接口中
也没有补齐上述 OS 操作。源码中的 Native `.c` 和 Wasm host import 只用于
判断能力所在层次，没有引入项目自身 FFI。
