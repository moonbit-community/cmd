# Published-version Runner 基线

Date: 2026-09-06

## Runner

`tests/release_runner` 是 Native 目标编译的纯 MoonBit 发布消费者测试器。它
从 `manifest.json` 读取精确的 `cli/<cmd>@<version>`，通过 MoonBit process API
启动 `moonx`，在独立夹具副本中采集 stdout、stderr、退出状态和文件快照，并
可使用固定 Docker oracle 做差分。

`timeout` 保持 local-only，因此发布清单覆盖 47 个命令。当前清单复用统一
runner 的稳定基础 case，并附加 P0 回归 case；发布新版本时必须同步修改清单
版本与参数覆盖。

## 分类与门禁

Runner 区分资产不存在、注册表传输、候选失败、oracle 失败、语义差异、意外
副作用、超时和 Runner 基础设施失败。资产或基础设施失败不会被跳过。

本地 manifest validation 已通过：47 packages、94 cases（71 个统一基础 case、
23 个 P0/release-specific case）。其中 HTTP case 共享单个纯 MoonBit loopback
fixture；HTTPS case 仍未选择。`0.1.4` 已发布资产以及 P0 修复版本均已进入
发布验证；受影响版本为 `echo/false/jqlog/seq/sleep/true@0.1.5` 和
`sh@0.1.6`。

首次完整 smoke 已完成 94 个 case，其中 71 个通过、23 个因 Mooncakes
注册表读取超时分类为 `registry_transport`；没有 `asset_unavailable`、
`semantic_mismatch` 或 `unexpected_side_effect`。`sh@0.1.6` 的 `-s`
位置参数回归已通过。注册表传输结果需由远端跨平台 smoke 重试确认，严格
差分仍以 Linux pinned oracle 为准。

本机已实际调用 `moonx cli/echo@0.1.5 --version`，结果为明确的
`Prebuilt wasm asset does not exist`（状态 255），因此没有把未发布资产误报为
命令语义失败。本机未安装 Docker，pinned-oracle differential 只能在 Linux CI
执行；该环境限制不影响 manifest/Runner 编译验证。
