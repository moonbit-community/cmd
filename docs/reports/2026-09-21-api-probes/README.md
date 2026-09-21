# 新工具链与纯 MoonBit 替代路径验证

Date: 2026-09-21

本轮本地宿主为 macOS，moon/moonrun 0.1.20260920、moonc
0.10.14+7d59c7ec9。所有本地 Moon/MoonX 调用保留 PATH 工具链，显式使用
`MOON_HOME="$HOME/.moon-accounts/cli"`。本报告描述未发布工作区变更，
不修改 0.2.0 发布证据。

## 依赖和 warning

注册表刷新成功。async 0.22.1、x 0.5.5、moonjq 0.1.2 仍是最新正式版，
所以没有人为增加版本号。50 个工作区模块的依赖声明一致；
[完整 jq 依赖树](dependency-tree.txt) 确认 moonjq 的传递依赖也解析到
相同 async/x，没有旧版残留。注册表版本、checksum 和发布时间见
[inventory.json](inventory.json)。

新版编译器要求显式 trait 方法提升：增加 74 条公开 extend 声明，保留
原来隐式可调用的方法；修复 84 处黑盒测试包限定名。未关闭 warning。
接口检查中这些方法变成显式签名；行为改动新增 CustomCookieMode 和
TransferOptions 的配置字段，构造函数默认 SeparateFields，显式 Cookie
不跨源转发；wget 单独开启跨源转发。直接用
struct literal 构造 TransferOptions 的下游需要补字段，发布前须按 API
变更审查版本；本轮没有发布。

## 替代路径的实测结果

| 路径 | 实测 | 处理 |
| --- | --- | --- |
| HTTP 双层公开 headers | 原始 TCP 请求有两个独立 Cookie；macOS curl 8.7.1 同序 | 已实现 curl 显式字段 + jar，保留传输栈、超时与 TLS |
| Wget 自定义 Cookie | Wget 1.25.0 只发显式字段，覆盖自动 Cookie，并跨源转发显式字段 | 独立模式及转发开关实现，jar 仍存响应 Cookie；curl 跨源移除显式字段 |
| 解包 cancellation handler 作 kill | 宿主 kill 拒绝不存在 PID；Native hard_cancel 返回 Unit | 因丢失错误状态而不采用，新增上游反馈要求 |
| Linux Native procfs identity/truncate | 当前 macOS 无法提供 Linux 运行证据；Wasm handle 非 OS fd | 保留实验方向及验收前置条件，不开放产品覆盖 |

原始探针及输出在本目录；[公开 API 复查](../2026-09-21-public-api-recheck.md)
记录源码入口、错误替代方案和解除条件。前两项进入产品回归，不把旧拒绝
当成兼容成功；其余元数据、TTY、信号恢复与 exec/job control 缺口保留。

## 本地验证

| 检查 | 结果 |
| --- | --- |
| `moon check --target all --deny-warn` | 通过，零 warning |
| `moon test --target native --deny-warn` | 160/160 |
| `moon test --target wasm --deny-warn` | 130/130 |
| Native/Wasm release build `--deny-warn` | 都通过 |
| Native/Wasm 持续场景 | 各 5/5：文件系统、交互 shell、生命周期、网络、make |
| curl/wget 选中单次合同 | 各后端 2/2；网络语义另在持续场景中实际调用 |
| `moon info`、`moon fmt` | 串行完成，接口差异已检查 |

网络 core 测试观察两种 Cookie 模式在初始请求、同源重定向和跨源重定向的
完整 Cookie 字段；真实 CLI 场景检查 stdout/stderr/状态和 jar。Linux 固定
oracle 与三平台 CI 沿用现有门禁，CI 配置更新本身不代表验收通过。

后续跨源探针确认 Wget 还会保留显式 Cookie，curl 则移除。修正后重新通过
两后端 netops 15/15、两后端真实网络 CLI 场景、release 构建与全目标严格
检查，新增证据使用 `cross-cookie-*` / `*-cross-cookie-*` 文件名；上述初次
全量记录保持不变。两项 Cookie 行为均已接入既有 Linux 固定 oracle 场景。

## 常见命令盘点

本地 48 个，已发布 47 个，本地未发布 timeout。明确选定的 59 个常见
缺失候选中，57 个此前无现行实施计划，2 个此前明确排除。
[完整清单与 tree 优先方案](../../command-coverage.md) 保留统计口径和
逐项能力边界；没有把“未开发”改写成“纯 MoonBit 不可能实现”。
