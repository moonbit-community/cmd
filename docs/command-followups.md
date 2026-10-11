# 命令兼容缺口与后续决策

Updated: 2026-10-11

本表覆盖 **79 个本地命令（78 个已发布，timeout 仅本地）**。F01–F19 已建立
issues #5–#23；jq 的既有 issue #4 一并进入当前修复。具体映射、候选实现和
尚未完成的发布门禁见[修复记录](reports/2026-10-11-fidelity-repair/README.md)。
本表的原始偏差描述对应已发布版本，不代表修复候选已经发布。新迁移的 31 个
命令均已映射到 [canonical ADR](adr/README.md#recent-command-decision-coverage)。
版本：首批 11 个 0.1.1，后续 20 个 0.1.0，原有 47 个 0.2.0；共享 core 0.4.0。
工作区基线为 MoonBit 2026-09-20、async 0.22.4、x 0.5.5、moonjq 0.1.2。
这里没有重新宣布这些依赖是当前 registry 最新版本。

范围是当前源码、README、help、支持记录与已知常见上游参数。不是逐一穷举
GNU/curl/jq 的所有历史或平台选项；未列出的选项不因此获得认证。
**“已实现但验证不足”不等于“不支持”，“明确拒绝”不等于兼容通过。**
无新缺陷的命令保留在表中，不为凑数虚构功能缺口。

## 建议提 issue 的顺序

P0：已有常用请求被错误解释或成功输出不保真；P1：日常主流程、正确性门禁；
P2：高价值功能/效率扩展；P3：低优先级细节或独立新命令排期。
这套优先级用于项目工作，与上游 API 文档中的接口优先级分开。

| 顺序 / ID | 优先级与建议标题 | 归因与预先选定的方向 | 关闭条件 |
| --- | --- | --- | --- |
| F01 | P0：修正 strings 的 radix/encoding 与默认字节合同 | 项目错误。`-t d` 应为十进制；`-e b` 不能当单字节，未实现宽编码应拒绝而非执行错误模式。修复默认 TAB、offset padding、`-o/-t` 优先级及多文件前缀。 | 固定 binutils 对照，Native/Wasm/精确 MoonX 对 flags、TAB、UTF-16、前缀、状态逐字节验收；替换错误合同预期时注明 upstream 依据。 |
| F02 | P0：which 必须验证可执行访问权 | 项目错误。公开 `can_execute` 已存在，先修 POSIX 非可执行文件误命中、路径分隔符及错误分类；Windows 单独定义 PATHEXT 和大小写查找，不能把任意普通文件当命令。 | 0644/0755、链接、空 PATH 项、含反斜杠 POSIX 名称、不可访问目录与 Windows 可执行名查找；普通文件不再错误成功。 |
| F03 | P0：恢复 column 默认列排版和 -t 输出合同 | 项目错误。无 `-t` 当前原样复制；`-t` 丢末尾 LF、以单空格为默认分隔并逐文件独立成表。宽度显式配置、字段分隔/空字段均可纯 MoonBit 完成。 | 固定 util-linux 的无参数、`-t/-s/-o`、多文件、空行、最后 LF、非法字节对照；自动 TTY 宽度单独保留 API 门禁。 |
| F04 | P1：date 的 TZ、输入和格式语义 | 项目工作。保留显式 `-u`；复用公开 x/time、TZif 能力实现已知 TZ/offset，无法解析应报错，不能默认忽略调用者 TZ。相对日期、额外格式字段另分子项；设置时钟仍为 API 缺口。 | 非 UTC/DST、缺少 zoneinfo、负数/小数 epoch、格式字段/修饰符与选项冲突固定 oracle；当前 UTC 默认偏差关闭。 |
| F19 | P1：unlink 多余参数必须在删除前拒绝 | 项目偏差。当前多操作数逐个删除，GNU 接受恰好一个。采用命令保真方向，先校验参数数量；不再把额外删除当便利扩展。 | 两个真实 fixture 的 extra-operand 调用返回非零且均保持；单文件、symlink 和按参数拒绝的 CLI 合同独立验收。 |
| F05 | P1：公开文件 identity/mode/truncate/time/link 能力及接入 | 真正上游接口门禁；按能力拆子项。影响 cp 默认/覆盖、touch、ln 硬链接、chmod、ls、tree、tail -F、mv 跨设备、patch/sed/gzip 写回。保留各自不同的 inode 合同。 | 正式发布 API + Native/Wasm 文件内容、权限、链接关系、时间和失败副作用差分；不以临时 rename 替代 cp 覆盖。 |
| F06 | P1：gzip 实现实际压缩与流式解码 | 项目算法。当前 stored blocks 有 gzip 格式但通常变大；实现 LZ/Huffman 和级别策略，随后减少解码对整个压缩输入的缓冲。 | 独立 gzip 互通、CRC/多 member/部分输出不退化；可压缩语料有实际压缩效果，记录压缩比、吞吐与内存。 |
| F07 | P1：sed 与共享 BRE/ERE 的常用语法 | 项目算法。分开推进 hold space、分支/分组、多行/插入追加命令与 backreference/word assertions；共享 matcher 可服务 expr、csplit、tac、nl。`sed -i` 独立依赖 F05。 | 固定 GNU 脚本、最长匹配/捕获、空匹配、部分输出、非法脚本及长行复杂度；不能仅通过解析即宣布支持。 |
| F08 | P1：补已接受文件/进程操作的证据 | 验证债务。优先 ln 目标/覆盖、mv interactive/backup/update、find 时间/access、test 特殊文件与时间比较、mkdir 异常 umask。源码接受不算完整验证。 | Linux 全 POSIX 元数据 oracle + Windows 对应合同；每个适用维度有观察结果，无法观测为 infra/skip，不降级成 pass。 |
| F09 | P1：单独交付尚未发布的已有命令修正 | 发布债务。curl/wget 自定义 Cookie 修正在工作区/新 core 中，但已发布 cli/curl、cli/wget@0.2.0 未包含。保留旧坐标，不因本轮分支合并宣称已发布。 | 已获用户授权，本修复轮只更迭受影响包；要求三平台 gate、串行发布和精确版本 wire/CLI 回归后关闭。 |
| F10 | P2：diff/patch 完整工作流 | diff 目录/空白模式、最短编辑等价解与内存属于项目工作；patch fuzz/offset/.rej/部分成功也属项目工作。写回权限受 F05 限制，不混为同一问题。 | 固定 GNU diffutils/patch 的多文件、多 hunk 混合成功、offset/fuzz、rejection 文件和 inode/mode；stdout/dry-run 保持可用。 |
| F11 | P2：sh 解释器与 make 语言补齐 | 项目工作。sh 算术赋值/++/?:、反引号、here-doc 展开、fd 重定向、循环层数、内建 printf/test；make 变量/export 递归、secondary expansion 等。持续行式会话已经可用。 | 按语法逐项 oracle，失败前输出/状态、管道作用域和会话恢复；jobserver 需另定继承与协议合同，不借 -j 并发冒称兼容。 |
| F12 | P2：大型输入、计数上限和流式处理 | 项目资源选择。split/csplit、sort、tac/rev、diff、column/strings、gzip decoder 的缓存及数值上限；seq 人为输出上限也需复核。先固定内存预算、失败副作用，再流式/外部排序。 | 大输入/超限/中断的时间内存证据与字节等价；取消测试侧额度限制和产品语义的混淆。 |
| F13 | P2：常用纯算法参数和路径选项 | 项目工作。cut complement/output delimiter、uniq 分组、seq 格式、sort 输出/merge/stable、split chunk/filter、fmt margins、od 浮点、hexdump format、cksum/tag 等；rev/tac 多文件不依赖上游 API。 | 按命令拆小 issue，支持/冲突/错误副作用一起验收；readlink 相关 path 模式另经 F05，不能全部按字符串消去处理。 |
| F14 | P2：网络与 JSON 扩展 | PSL/IDNA、cookie-prefix、Wget challenge cache/replay、HTTP 配置/更多认证，以及 jq 模块/--stream 属项目或公共 evaluator 集成；任意重复头需要 ordered headers，HTTP/2 要独立核对传输能力。 | 固定 wire fixture + 命令 oracle；响应、凭据域、cookie jar 和失败行为一起测，禁止代理到宿主 curl/jq。 |
| F15 | P2：真实终端、可恢复信号、exec/进程组 | 真正公共接口门禁：isatty/termios/resize/信号订阅/PTY/exec/组及状态事件。影响 sh 高级交互、jq 自动颜色、test -t、timeout 发布、tee -i/yes 信号语义。 | 正式 API + 真实终端和后代生命周期测试。行式 Session、固定 ANSI 输出与直接子进程取消均不能替代。 |
| F16 | P2：locale、显示宽度与平台文本模式 | 项目数据/算法及平台合同。先保留 C-byte 边界，不改调用者 locale。统一宽字符/组合字符/排序规则，避免各命令自建不同半实现。 | 原始字节、UTF-8 非法序列、locale 数据版本、宽度/大小写/排序差分和 Windows 文本模式独立证据。 |
| F17 | P3：诊断字节与项目扩展治理 | 命令原样迁移优先。ls -P、jq -l、rmdir -I 等扩展明确标注，不能当 GNU 参数。剩余诊断/别名逐项补；unlink 的副作用另提至 F19。 | 扩展有明确名称/帮助/合同；通用诊断不掩盖状态与效果。 |
| F18 | P3：其余 28 个未建模块的命令 | 单独的新命令路线，见 command-coverage；awk/归档等算法可先行，stat/du/df/身份/终端按公共能力拆分。 | 每个新模块先确定 upstream、子集、拒绝条件、README/ADR/CLI 合同；不把本轮 79 个包的选项清单和新包排期混计。 |

当前优先修复已有功能错误和 README/help 含义不一致，其余扩展留在 issues；
其中 F05 与 F15 需要上游协作，其余不应统一等待 async。ID 保持稳定，
表格按优先级排列，因此补充的 F19 位于 P1 区域。

## 全部命令逐项记录

每行命令名链接当前 README；对应源文件及 `tests/cases/<cmd>.json` 可进一步
核对。分类：**缺陷**（已有含义有偏差）、**项目**（可在项目补）、**API**
（正式公开能力缺口）、**验证**（已接受但未充分认证）、**平台**（需单独合同）。
F 编号对应上述优先队列；一行可涉及多个原因。没有独立高优先项时标为维护。

| 命令 | 当前不支持、偏差或待补证据 | 分类 / 优先队列 | ADR |
| --- | --- | --- | --- |
| [base32](../commands/base32/README.md) | 已覆盖常用 `-d/-i/-w`；本次未发现额外标准参数阻塞。非标准 alphabet 不作为 GNU 缺陷凑数；locale 诊断未全比对。 | 维护 / F16–17 | 0003、0008 |
| [base64](../commands/base64/README.md) | 常用 decode/ignore/wrap 已有；非标准 alphabet 不在基线，完整诊断未认证。 | 维护 / F17 | 0003、0008 |
| [basename](../commands/basename/README.md) | 常用多操作数/suffix/NUL 已有；多字节路径 locale 与平台极端形式待证据。 | 验证、平台 / F16 | 0003 |
| [cat](../commands/cat/README.md) | 常见格式 flags 已有，`-u` 是兼容 no-op；本次无新独立缺口。 | 维护 | 0003 |
| [chmod](../commands/chmod/README.md) | 增量/省略类别、权限复制、`X/s/t`、`--reference`；符号赋值只接受全类别闭合形式。命令行目录 symlink 的递归只改目标自身；Windows mutation 不可用。 | API、验证、平台 / F05、F08 | 0004 |
| [cksum](../commands/cksum/README.md) | 仅 POSIX CRC+长度；GNU 算法选择、check/tag 等模式未补。 | 项目 / F13 | 0008 |
| [cmp](../commands/cmp/README.md) | `-s/-l/-n/-i` 已有；`-b/--print-bytes` 等额外显示及完整诊断待补。 | 项目、验证 / F13、F17 | 0003 |
| [column](../commands/column/README.md) | 默认 copy-through；`-t` 缺 LF、单空格约定、多文件独立表；完整 util-linux 表格/字段/输出宽度、display-width 均未补。 | **缺陷**、项目、API / F03、F15–16 | 0003 |
| [comm](../commands/comm/README.md) | 自定义输出 delimiter、`--total`；非 C collation 未实现。 | 项目 / F13、F16 | 0003 |
| [cp](../commands/cp/README.md) | 默认复制、所有已有 regular-file 覆盖、`-a/-p/--preserve` 拒绝；只支持 `--no-preserve=mode` 新建。`-f/-i/backup` 接受不代表覆盖已实现。 | API / F05 | 0004、0009 |
| [csplit](../commands/csplit/README.md) | 已有输出拒绝；自定义 suffix、`--suppress-matched`、BRE backrefs/word assertions/非 ASCII pattern；整输入缓存。 | API、项目 / F05、F07、F12–13 | 0004、0008–0009 |
| [curl](../commands/curl/README.md) | 非 HTTP、HTTP/2、config、非 Basic/交互密码、PSL/IDNA/raw Set-Cookie/prefix、任意有序重复头；工作区 Cookie 修正未进入 0.2.0。 | 项目、API、发布 / F09、F14 | 0005 |
| [cut](../commands/cut/README.md) | `--complement`、`--output-delimiter`；`-c` 当前同 byte；空 delimiter 拒绝。 | 项目 / F13、F16 | 0003 |
| [date](../commands/date/README.md) | 忽略调用者 TZ，默认/无 `-u` 仍 UTC；relative date、小数 epoch、更多格式/修饰符、`-f/-r` 等未实现；设置时钟缺 API。 | **偏差**、项目、API / F04 | 0008 |
| [diff](../commands/diff/README.md) | 目录递归、空白/大小写模式；等价编辑序列的精确 hunk、很大差异输入内存待补。 | 项目、验证 / F10、F12 | 0008 |
| [dirname](../commands/dirname/README.md) | 多操作数和 NUL 已有；多字节/平台边界未全认证。 | 验证 / F16 | 0003 |
| [echo](../commands/echo/README.md) | GNU `POSIXLY_CORRECT` 环境选择未声明兼容；选项歧义保留且已说明。 | 项目 / F17 | 0002–0003 |
| [env](../commands/env/README.md) | `-S/--split-string`、argv0 及信号相关扩展不在当前 `-i/-u/-0/-C` 子集；子进程 launch ≠ exec 替换。 | 项目、API / F13、F15 | 0002、0006 |
| [expand](../commands/expand/README.md) | 非 C display-width；GNU 相对/重复 tab-stop 扩展需逐形式复核。 | 项目、验证 / F13、F16 | 0003 |
| [expr](../commands/expr/README.md) | pattern backrefs/word assertions、locale 字符操作；BigInt 算术已实现，不属数值上游阻塞。 | 项目 / F07、F16 | 0008 |
| [false](../commands/false/README.md) | 本次无新功能缺口；保留 metadata/参数歧义合同。 | 维护 | 0001、0009 |
| [find](../commands/find/README.md) | 不跟随链接；owner/inode/nlink/link-target predicates、完整表达式/动作组合缺失；birth/literal time selector 不在 `-newerXY` 范围。已有 time/access/特殊文件需补证据。 | API、项目、验证 / F05、F08 | 0004、0006 |
| [fmt](../commands/fmt/README.md) | `-c` crown、`-t` tagged、`-p` prefix；非 C 宽度与全部段落选择未认证。 | 项目、验证 / F13、F16 | 0003 |
| [fold](../commands/fold/README.md) | 已有 byte/control-column/spaces；非 C 多字节计数和 display-width。 | 项目 / F16 | 0003 |
| [grep](../commands/grep/README.md) | Backrefs/更多 GNU regex、非 C classes/case fold；`-P` 不在当前引擎，长行最坏性能待量化。 | 项目 / F07、F12、F16 | 0003、0008 |
| [gunzip](../commands/gunzip/README.md) | 非 `-c` named replacement、恢复元数据；其他压缩格式、force/pass-through、递归/listing；compressed input 全缓存。 | API、项目 / F05–06、F12 | 0004、0008–0009 |
| [gzip](../commands/gzip/README.md) | Stored blocks，尚无真正压缩级别；named compression 要 `-cn`，原地替换/元数据、递归/listing/force 未实现。 | 项目、API / F05–06 | 0004、0008–0009 |
| [head](../commands/head/README.md) | 计数受 signed Int64 限制；超大后缀/无界记录的资源行为须按预算测，不以解析成功认证。 | 验证 / F12 | 0003 |
| [hexdump](../commands/hexdump/README.md) | `-e/-f` 自定义格式、color directives；stdin skip 拒绝；默认 little-endian 平台边界。 | 项目、API、平台 / F13 | 0003 |
| [join](../commands/join/README.md) | ignore-case/header/完整 output-format 扩展待补；非 C collation/诊断未认证。 | 项目、验证 / F13、F16 | 0003 |
| [jq](../commands/jq/README.md) | `--stream`、模块及完整 evaluator/diagnostics；自动 TTY 颜色缺 isatty。显式 `-C/-M` 已有，不能再列成 blocker。 | 项目、API / F14–15 | 0008 |
| [jqlog](../commands/jqlog/README.md) | 独立 JSONL 合同，跳过非法行是其设计；继承 moonjq evaluator 范围，不按系统 jq 全参数计缺口。 | 项目 / F14 | 0008 |
| [ln](../commands/ln/README.md) | Hard link 不可用；symlink 仅 POSIX；target/interactive/backup/overwrite 组合已接受但差分不足。 | API、验证、平台 / F05、F08 | 0004 |
| [ls](../commands/ls/README.md) | 长格式/owner/mode/inode/nlink/blocks、目录 size sort；color/多列/quoting 等布局可独立实现。`-P` 是项目扩展。 | API、项目 / F05、F13、F15–17 | 0003–0004 |
| [make](../commands/make/README.md) | 完整 GNU grammar/builtins、secondary expansion、jobserver；裸 export/unexport、shell-function export recursion 未补。 | 项目、平台 / F11 | 0006–0007 |
| [md5sum](../commands/md5sum/README.md) | BSD tagged/`--tag`、Windows text translation；`-z` verification 非当前合同。 | 项目、平台 / F13、F16 | 0008 |
| [mkdir](../commands/mkdir/README.md) | Symbolic modes；异常 umask 需临时 owner write/search 权限；Windows mode 语义未认证。 | 项目、验证、平台 / F08、F13 | 0004 |
| [mktemp](../commands/mktemp/README.md) | 当前只 trailing-X 模板及 `-d`；`-p`、suffix/模板扩展/quiet 等；owner 与 Windows modes 未认证。 | 项目、平台 / F13 | 0004 |
| [mv](../commands/mv/README.md) | EXDEV copy-delete 缺元数据保持；已有 interactive/backup/suffix/其余 update 组合和 Windows 错误分类待证据。 | API、验证 / F05、F08 | 0004、0009 |
| [nl](../commands/nl/README.md) | `pBRE` 编号选择尚拒绝；C-byte regex 部分可用共享 matcher 补，不应把全部归为 locale 阻塞。 | 项目 / F07、F16 | 0003、0008 |
| [od](../commands/od/README.md) | Float types、字符串提取、传统 offset operands；默认 little-endian 而非任意主机 endian。 | 项目、平台 / F13 | 0003 |
| [paste](../commands/paste/README.md) | 主用 `-s/-d/-z` 已有；非法 delimiter 完整诊断及非 C 行为未全比对。 | 验证 / F16–17 | 0003 |
| [patch](../commands/patch/README.md) | 普通现有文件写回/named `-o` 缺 mode；fuzz、offset、`.rej`、mixed-success、binary/rename/mode patch、interactive 未实现。 | API、项目 / F05、F10 | 0004、0009 |
| [printenv](../commands/printenv/README.md) | 无新参数 blocker；只能观察宿主提供的环境，宿主授权拒绝不是实现缺失。 | 维护 / 平台 | 0002 |
| [printf](../commands/printf/README.md) | 文档之外的转换（如 hex float/quoting）与 locale 数字格式未声明；所有诊断字节未全比对。Shell 内建范围另计。 | 项目、验证 / F11、F13、F16 | 0003、0007 |
| [pwd](../commands/pwd/README.md) | `-L/-P` 已有；cwd、逻辑路径依赖宿主合同，无新已知参数 blocker。 | 维护 / 平台 | 0002、0004 |
| [realpath](../commands/realpath/README.md) | 仅 existing；GNU 默认允许 final missing 的行为、`-m`、`--relative-to/base`、`-s` 未补。词法模式可实现，symlink-aware missing 模式需另证。 | 项目、API / F05、F13 | 0004 |
| [rev](../commands/rev/README.md) | 多文件拒绝、整输入缓存、非 C 字符反转未补。 | 项目 / F12–13、F16 | 0003 |
| [rm](../commands/rm/README.md) | `-i/-I` 未实现；完整 device-boundary/扩展 root flags 不在当前范围；真实 root 删除不在测试承诺中。 | 项目、API、验证 / F05、F13 | 0004、0009 |
| [rmdir](../commands/rmdir/README.md) | 常用行为已有；完整 path diagnostics 未认证。`-I` 为当前额外短拼写，不能当 GNU 标准参数。 | 验证 / F17 | 0004、0009 |
| [sed](../commands/sed/README.md) | `-i`、hold space、branches/groups、multiline、append/insert/change 等；pattern backrefs/word assertions、locale。 | 项目、API / F05、F07 | 0004、0008–0009 |
| [seq](../commands/seq/README.md) | `-f` 未实现；precision/output 数量存在项目上限，需同步帮助/文档并评估流式解除。默认 +1 已修复。 | 项目 / F12–13 | 0003、0009 |
| [sh](../commands/sh/README.md) | 算术赋值/++/?:、反引号、fd duplication、here-doc 展开、多层 break/continue、完整 builtins；exec/fg/bg/jobs/wait、高级终端未开放。 | 项目、API / F11、F15 | 0006–0007 |
| [sha1sum](../commands/sha1sum/README.md) | 同 md5sum：tagged records、Windows text mode。 | 项目、平台 / F13、F16 | 0008 |
| [sha256sum](../commands/sha256sum/README.md) | Tagged/binary manifest 扩展及完整 warnings 待补；与新 hash 公共合同去重需先保持现有行为。 | 项目、验证 / F13 | 0008 |
| [sha512sum](../commands/sha512sum/README.md) | 同 md5sum：tagged records、Windows text mode。 | 项目、平台 / F13、F16 | 0008 |
| [sleep](../commands/sleep/README.md) | Signal/cancellation parity 未认证；duration 精度/上限属运行时合同，不是无限范围。 | API、验证 / F15 | 0006 |
| [sort](../commands/sort/README.md) | `-R` 当前以无 seed 合同拒绝；随机算法本可实现。输出文件、merge/stable 额外模式、外部排序、locale 未补。 | 项目 / F12–13、F16 | 0003 |
| [split](../commands/split/README.md) | 已有输出拒绝；`-n` chunk、`-C` line-byte、filter、numeric start、hex suffix；整输入缓存、Int32 count/1024 suffix bounds。 | API、项目 / F05、F12–13 | 0004、0009 |
| [strings](../commands/strings/README.md) | `-t d/-e s` 错误拒绝，`-e b` 错误单字节、TAB 与前缀/offset 格式；wide/Unicode/object sections/自定义分隔等未补。 | **缺陷**、项目 / F01、F12–13、F16 | 0003 |
| [tac](../commands/tac/README.md) | Regex separator、多文件拒绝；整输入缓存。多文件不依赖 regex，字节 matcher 可在项目实现。 | 项目 / F07、F12–13 | 0003 |
| [tail](../commands/tail/README.md) | `-F`/name-follow 与 rotation reopen 缺 identity；其余 GNU pid/retry/record 选项不在当前子集。 | API、项目 / F05、F13 | 0003–0004 |
| [tee](../commands/tee/README.md) | `-i`、`-p/--output-error` 等信号/错误选择不在当前 append 子集；pipe 错误状态需明确。 | 项目、API、验证 / F13、F15 | 0003、0006 |
| [test](../commands/test/README.md) | `-t`、mode/owner、`-ef` 缺 API；已实现时间/特殊文件与完整参数歧义仍需独立 probes。 | API、验证 / F05、F08、F15 | 0004、0007 |
| [timeout](../commands/timeout/README.md) | 未发布；无 process groups、signal selection、kill-after、foreground、preserve-status 完整合同；仅 owned direct child。 | API / F15 | 0006 |
| [touch](../commands/touch/README.md) | 已有文件更新时间、`-a/-m/-d/-r/-t/--time` 拒绝；只创建缺失文件和 `-c` missing no-op。 | API / F05 | 0004、0009 |
| [tr](../commands/tr/README.md) | C-byte sets/转换已有；locale 字符/分类数据未实现。 | 项目 / F16 | 0003 |
| [tree](../commands/tree/README.md) | 遇 symlink 拒绝；follow/link text、owner/mode/device、JSON/HTML/filters/colors/更多报告未补，其中输出格式并不依赖 readlink。 | API、项目 / F05、F13、F16 | 0004 |
| [true](../commands/true/README.md) | 本次无新功能缺口；metadata 版本合同保留。 | 维护 | 0001 |
| [unexpand](../commands/unexpand/README.md) | 相对/重复 tab-stop 形式需逐项核对；非 C display-width。 | 项目、验证 / F13、F16 | 0003 |
| [uniq](../commands/uniq/README.md) | `-D/--all-repeated`、`--group` 等分组模式；locale collation。 | 项目 / F13、F16 | 0003 |
| [unlink](../commands/unlink/README.md) | 当前多个操作数会顺序删除，GNU 应先因 extra operand 拒绝；项目扩展需改为保真参数检查。目录拒绝不属缺陷。 | **偏差** / F19 | 0004、0009 |
| [wc](../commands/wc/README.md) | `--total` 策略与完整 locale/display-width；`-m` 固定 UTF-8 与 caller locale 的关系需明确。 | 项目、验证 / F13、F16 | 0003 |
| [wget](../commands/wget/README.md) | 递归镜像/FTP/非 Basic/HSTS、timestamp restore、PSL/IDNA、stdin challenge replay、跨 port/URL auth cache；Cookie 修正未入已发布 0.2.0。 | 项目、API、发布 / F05、F09、F14 | 0005 |
| [which](../commands/which/README.md) | 普通文件误判可执行；POSIX 反斜杠视为分隔符；Windows PATHEXT、alias/function/lookup 扩展尚无合同。 | **缺陷**、平台 / F02 | 0006 |
| [xargs](../commands/xargs/README.md) | 当前有 bounded `-P`、token/batch/replacement；任意 delimiter、交互提示、完整 GNU 调度/locale 扩展未补，进程组取消不由 direct-child API 保证。 | 项目、API / F13、F15–16 | 0002、0006 |
| [xxd](../commands/xxd/README.md) | Negative/end-relative seek 拒绝；更多 bit/endian/group/case 等格式、输出文件语义未在当前参数集；reverse 稀疏输出有分配上限。 | 项目、验证 / F12–13 | 0003 |
| [yes](../commands/yes/README.md) | 普通 producer/pipe closure 已测；精确 SIGPIPE 状态/诊断与 terminal 交互未认证。 | 验证、API / F15 | 0006 |
| [zcat](../commands/zcat/README.md) | 只 gzip；其他格式、suffix searching、force/pass-through；compressed input 全缓存。 | 项目 / F06、F12–13 | 0008–0009 |

## 证据与使用方法

- 原始支持与版本：[compatibility](compatibility.md)；未建模块：[28 个缺口](command-coverage.md)。
- 新发现的 Native/Wasm/精确 MoonX 调用：[本轮复现与输出](reports/2026-10-11-command-followups/README.md)。
- 真正公共 API 缺口与建议语义：[async-upstream-gaps](async-upstream-gaps.md)。
- 31 个新增包的决定、放弃方案、兼容代价、证据和解除条件：[ADR 索引](adr/README.md)。

现有 554-case 发布验收只对所选合同、availability 和 boundary 有效；上述
新发现未被旧用例覆盖，原报告不重写，当前支持记录明确加注偏差。
后续 issue 应引用稳定的 F 编号，再拆具体命令/接口；修复完成必须带实际结果，
不能仅凭“加了选项”或“升级了 async”关闭。
