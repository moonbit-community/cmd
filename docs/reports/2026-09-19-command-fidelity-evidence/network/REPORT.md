# cli/curl、cli/wget、cli/jq 发布版调用审计

日期：2026-09-19。仓库解释基于 HEAD `8b79e9b`，未修改产品源码。

所有被测程序都实际通过 `moonx cli/<cmd> ...` 调用，未传 `--experimental-policy`。`moonx -v` 确认本地 registry index 把三个命令解析到 `0.1.4`，执行缓存的 Wasm asset；没有查询 `@latest`，因此此报告不声称远端 registry 全局最新。对照为本机 curl 8.7.1、GNU Wget 1.25.0、jq 1.7.1-apple。

网络请求只访问探针创建的 `127.0.0.1` HTTP fixture。所有代理变量在子进程中置空、`NO_PROXY=*`。fixture 在主探针结束时取消并关闭。主探针 20 个案例；源码揭示 jq 输入解析与参数替换问题后追加 3 个针对性案例。23 个案例里，14 个 stdout 和退出状态与本机原生命令一致，9 个存在功能差异；其中 curl HTTP 404 的退出码同为 22，但 stderr 文案不同，因此 stdout/stderr/status 全部字节相同的是 13 个。此统计描述选中样例，不表示命令覆盖率。

## 主要发现

1. **jq 正常 JSON 输入序列不兼容，`-s` 也不能正确收集多个值。** 输入 `true\nfalse\n` 调用 `moonx cli/jq -e .` 返回 5、stdout 为空、报 `Invalid character 'f' at line 2, column 0`；原生 jq 输出两行并返回 1。输入 `1 2 {"a":3}\n` 调用 `moonx cli/jq -c .` 返回 5；原生输出三个值并返回 0。输入 `1\n2\n` 调用 `moonx cli/jq -sc .` 返回 5；原生输出 `[1,2]\n`。这些不是 `--stream` 特性，而是 jq 日常默认输入语义。源码原因：`commands/jq/main_native.mbt:312` 对整个 stdin/file 调用一次 `@json.parse(input)`；slurp 分支 `:454` 同样把每个文件整体解析为单一 JSON。证据 `18-*`、`19-*`、`21-*`。

2. **jq `--arg` 只是查询文本替换，不能保持真正变量绑定语义。** `moonx cli/jq -nr --arg name Moon '"hello \($name)"'` 返回 5，报未定义变量；原生输出 `hello Moon\n`。`moonx cli/jq -nc --arg x outer '"inner" as $x | $x'` 返回 3，报 `Expected variable after 'as'`；原生输出 `"inner"\n`。源码 `commands/jq/main_native.mbt:54` 的 `substitute_arguments` 跳过字符串内替换（`:73`），又把字符串外的局部绑定变量名称替换成 JSON 字面量（`:81`）；`:415` 将替换后的文本交给 evaluator。证据 `22-*`、`23-*`。

3. **curl/wget 的常用认证和 cookie 参数是未实现，不是 runtime policy 拒绝。** `moonx cli/curl -sS -u u:p URL/auth` 和 `-b sid=one URL/cookie` 均在参数解析时报 unknown short option，状态 2；原生 curl 分别返回 `auth-ok\n`、`sid=one\n`，状态 0。`moonx cli/wget -qO- --user=u --password=p URL/auth`、`--save-cookies FILE URL/cookie` 均报 unknown option、状态 2；原生 wget 状态 0。源码参数表分别位于 `commands/curl/options.mbt:211`、`commands/wget/options.mbt:150`。文档在 `docs/compatibility.md:107`、`:145` 已明确排除 auth/cookie state，因此这是已声明的兼容性缺口，仍意味着旧命令行不能原样迁移。证据 `04-*`、`05-*`、`10-*`、`11-*`。

4. **这些限制不等同于禁止认证或连接。** 同一 fixture、同一不带 policy 的 moonx 调用中，curl `-H 'Authorization: Basic dTpw'` 和 URL `http://u:p@127.0.0.1:PORT/auth` 都返回 `auth-ok\n`、状态 0，和原生一致。源码 `core/netops/transfer.mbt:170` 会从 URL userinfo 生成 Basic Authorization。无需放宽 policy 就能请求成功；缺失的是命令行功能和语义。证据 `06-*`、`12-*`。

## 已通过的实际语义

- curl GET、`-L` 相对重定向、`-f` 404 退出码 22、显式 Authorization header、URL userinfo Basic Auth。
- wget GET、默认相对重定向、404 退出码 8。
- jq `map(. + 1)`、`.[] | select(. > 1)`、`reduce .[] as $x (0; . + $x)`、`.items |= map(. + 1)`、负数组下标、`to_entries | map(.value)`，均为单个 JSON 输入。

## 复现及证据

运行 `moon run /tmp/cmd-audit-20260919/network/probe.mbtx` 可重建本地 HTTP fixture 并重跑 20 案例；运行 `moon run /tmp/cmd-audit-20260919/network/jq-followup.mbtx` 重跑 3 个 jq 追加案例。主探针会替换主结果，追加探针会 append `followup.jsonl`；若要保留本次结果，请先复制整个证据目录。

最初两个 JSONL 因探针把 append=true 与默认 CreateOrTruncate 组合使用，实际只保留末条记录；每次执行独立保存的 .stdout、.stderr、.status 不受影响。已将探针改为 create_mode=@fs.OpenOrCreate, append=true，并使用 recover-evidence.mbtx 从保留的 156 个原始输出文件恢复完整 JSONL，没有重跑被测命令或新增案例。完整 argv、stdin 根据原探针案例定义恢复；动态 HTTP 地址读取当次保留的 fixture-url.txt。每条恢复记录都包含明确的 provenance 和来源文件路径。

恢复后的 results.jsonl 含 46 条调用（6 条版本/解析记录和 20 组对照），followup.jsonl 含 6 条调用（3 组对照）。原来只剩末条的文件保留为 results.jsonl.truncated-original、followup.jsonl.truncated-original。recovery-summary.json 保存恢复计数与从原始输出重新计算的比较统计，均通过脚本断言。MANIFEST.txt 列出可归档证据文件，不含 _build 缓存。

*-resolution.stderr 保存 moonx 解析版本和实际 asset 路径；*-version.stdout 保存 oracle 版本。当前 fixture URL 只供记录，探针已关闭监听；重跑会分配新端口。

本审计没有验证公网 HTTPS、TLS证书、HTTP/2、并发、跨平台，也没有把 README 的兼容声明当成已完成验证。`jq -l` 是额外日志模式且允许跳过无效行，不能以它存在推导默认 jq 输入序列已兼容。
