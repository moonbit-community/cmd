# Compatibility

This guide describes the current workspace's supported command behavior.
The workspace command modules use pure MoonBit on MoonX/Wasm.
Support means the documented profile, not complete GNU, POSIX or upstream parity.

All command packages declare Wasm as their only build target. Core packages
do the same except `platform` and `gzipops`, which retain Native support for
test-tool consumers. The execution tools under `tests` and `tools` remain Native.

## Terminal and signal queries

| Command | Supported behavior |
| --- | --- |
| [clear](../commands/clear/README.md) | Reads the directory-format ncurses database selected by TERM, TERMINFO or TERMINFO_DIRS. Redirected stdout receives the same bytes. Padding-dependent commands are rejected. Windows requires an explicitly installed directory database. |
| [tput](../commands/tput/README.md) | Supports boolean, numeric and byte-string capabilities, longname, clear and up to nine numeric parameters. Missing standard values retain ncurses status and output. Use -T for database dimensions. Live size, string parameters, terminal reinitialization and padding require additional terminal support. |
| [tty](../commands/tty/README.md) | A regular file, directory, pipe, socket or block device produces not a tty and status 1. Character devices require a terminal ioctl, and Windows descriptor queries require a public console API; these cases return status 2. |
| [kill](../commands/kill/README.md) | Uses the released async signal API for host signal numbers on Linux and macOS. Arbitrary PID signal delivery and other signal names are unsupported. |

The standalone `test -t` reports false for redirected POSIX standard descriptors. `stty` and interactive `watch` require Wasm terminal attribute, resize and lifecycle APIs.

## System information

| Command | Supported host observations |
| --- | --- |
| [uname](../commands/uname/README.md) | Linux reads kernel fields from procfs. `-o` emits the GNU operating-system label on Linux and macOS. macOS also supports the Darwin kernel name. Windows, machine architecture and the full `-a` form are unavailable. |
| [hostname](../commands/hostname/README.md) | Reads `/proc/sys/kernel/hostname` in the current namespace. Name changes, resolver-derived aliases and other operating systems are unsupported. |
| [id](../commands/id/README.md) | Linux reads real and effective IDs and supplementary groups from procfs. The default report resolves local account names. It requires matching real/effective groups and either POSIXLY_CORRECT or a kernel without SELinux/SMACK filesystems. Named-user and external directory lookups remain unsupported. |
| [whoami](../commands/whoami/README.md) | Reads process credentials from Linux procfs. Names must resolve from the first configured local files source in /etc/nsswitch.conf. External directory lookups and named operands are unsupported. |
| [groups](../commands/groups/README.md) | Reads process credentials from Linux procfs. Names must resolve from the first configured local files source in /etc/nsswitch.conf. External directory lookups and named operands are unsupported. |
| [uptime](../commands/uptime/README.md) | Reads the first value of /proc/uptime, including suspend time. Calendar boot time, load averages and logged-in user counts are outside this profile. |
| [free](../commands/free/README.md) | Uses a single /proc/meminfo snapshot with MemAvailable and SReclaimable. Reports kernel-wide RAM, including reclaimable slab, and swap. Values are independent of cgroup memory limits. |
| [ps](../commands/ps/README.md) | Reads one `/proc/PID/stat` record for each selection. No-heading fields include `comm`, `pid`, `ppid`, `pgid`, `sid`, `tpgid`, `state`, `nice` and `nlwp`. Repeat `-o FIELD=` or use comma-separated fields. Names must be printable ASCII. A missing process returns status 1 with empty output. |
| [nproc](../commands/nproc/README.md) | The default follows the current process affinity, OpenMP thread settings and the CPU quota hierarchy on a standard cgroup v2 mount. Realtime scheduling policies ignore quotas. --all counts configured CPU directories from sysfs. Nonstandard cgroup v2 mounts are rejected. |

## Workspace and published packages

The workspace targets MoonBit 1.0 RC1 (2026-11-26). The basename, date, dirname,
echo, false, printenv, printf, pwd, sleep, true and yes commands use the
standard library for asynchronous I/O. The base64, cat, column, comm, cut, fold,
head, join, nl, paste, rev, tr, uniq and wc drivers also use standard binary
streams. Base32, cmp, diff, expand, expr, fmt, hexdump, od, seq, strings,
unexpand, xxd, the checksum family and gzip/gunzip/zcat also use standard
async I/O. Grep, sed and sort use standard binary streams for records and rg uses
standard binary stdout. Binary output preserves arbitrary bytes. `env`, `timeout`, `xargs` and
external commands launched by `sh` use standard async child processes. Shell
redirections retain the parent-owned pipes until the child exits. Curl and wget
use standard async TCP and TLS through `cli/core/netops`. Serve exposes a
`moonbitlang/core/async/http` request handler.
Workspace commands use the RC1 runtime entry point and the shared byte-search
code uses the standard library's experimental SIMD package on Wasm.

Use `moonx cli/<command>` for published commands. `timeout` is local-only;
its README shows the repository invocation. Module versions come from
`moon.mod` and are reported by standalone `--version`.

Jq and jqlog use the shared `cli/jq/engine` value-filter API introduced in
cli/jq 0.2.10. Unversioned MoonX examples use the local registry index;
run `moon update` to refresh it, or append `@<version>` to pin a release.
The frozen [published inventory](../tests/release/latest.json) records the 81
published coordinates; it is independent of current workspace behavior.

The published coordinates were checked through MoonX on 2026-11-16. Complete
local macOS acceptance passed 3,890 checks with 40 declared platform skips and
no failures; 508 help/version and README checks covered exact and unversioned
calls. The core and jq engine public API examples also compiled and passed.
[Release PR #132](https://github.com/moonbit-community/cmd/pull/132) records the
development checks and three-platform publication gate, including the pinned
Linux upstream comparison. These checks cover the declared profile, not full
upstream parity or performance qualification. See [validation](../tests/README.md)
for reproduction and [CHANGELOG](../CHANGELOG.md) for dated release results.

## Command support

Each README contains practical examples and common options. Run `--help`
for the complete declared option surface; recognizing an option does not
necessarily mean its requested operation is available. The limits below
identify the principal refusals and platform differences.


| Command | Supported behavior | Limits |
| --- | --- | --- |
| [tar](../commands/tar/README.md) | GNU tar create, list, extract and stdout profiles for ustar and gzip. | UTF-8 names, regular files and directories, fixed archive metadata, new files only. |
| [zip](../commands/zip/README.md) | Info-ZIP recursive archive creation, stored entries and Deflate levels 1–9. | New archives, relative names, synthetic metadata. |
| [unzip](../commands/unzip/README.md) | Info-ZIP name listing, verification, stdout and named-directory extraction. | Exact selections, regular files and directories, no overwrite or metadata restoration. |
| [base32](../commands/base32/README.md) | RFC 4648 Base32 encoding and decoding; wrapping and garbage filtering. | Uppercase alphabet; decoding retains the whole input. |
| [base64](../commands/base64/README.md) | Streaming Base64 encoding and decoding; wrapping and garbage filtering. | Standard alphabet and canonical tail bits; malformed padding fails. |
| [basename](../commands/basename/README.md) | Lexical basename and literal suffix removal; multiple and NUL-separated output. | No filesystem lookup. |
| [cat](../commands/cat/README.md) | Streaming concatenation, line numbering and visible byte formatting. | Byte-oriented display; -u has no effect. |
| [chmod](../commands/chmod/README.md) | POSIX numeric modes and symbolic expressions with a known final regular-file mode. | Omitted classes, results depending on the old mode, reference modes and Windows remain unsupported. |
| [cksum](../commands/cksum/README.md) | POSIX CRC and selected digest families; modern digest manifests. | No legacy-algorithm manifest checks; raw output is single-input. |
| [cmp](../commands/cmp/README.md) | Byte comparison with skip/limit, quiet and list modes. | C-byte diagnostics. |
| [column](../commands/column/README.md) | Grid/table layout, C.UTF-8 cell widths, ANSI-aware table fields and temporary spooling. | No automatic terminal width or full util-linux grammar. |
| [comm](../commands/comm/README.md) | Three-column sorted comparison, order checks, custom delimiters and totals. | C and C.UTF-8 byte ordering. |
| [cp](../commands/cp/README.md) | New file/tree copies with --no-preserve=mode; explicit skip policies. | No mode-preserving, archive or existing-file replacement copies. |
| [csplit](../commands/csplit/README.md) | Numeric/regex splits, repeats, suffixes and fragment cleanup. | No overwrite; Windows path-name and temporary-storage boundaries. |
| [curl](../commands/curl/README.md) | HTTP(S), Basic auth, cookies, redirects, retry, upload and resume. | No other protocols/non-Basic auth; finite config/IRI/Cookie profile. |
| [cut](../commands/cut/README.md) | Byte/field selection, complement, delimiters and NUL records. | No multibyte character selection. |
| [date](../commands/date/README.md) | UTC/local formatting, ISO/epoch parsing, TZif and POSIX future rules. | Rejects DST gaps/folds; no clock setting or full relative-date grammar. |
| [diff](../commands/diff/README.md) | Normal/unified/context diffs, directory recursion and comparison filters. | Whole-input memory; device-metadata boundaries. |
| [dirname](../commands/dirname/README.md) | Lexical parent paths for multiple operands; NUL-separated output. | No physical path resolution. |
| [echo](../commands/echo/README.md) | Argument joining, byte escapes and POSIXLY_CORRECT behavior. | No ordinary -- terminator; metadata options are standalone-only. |
| [env](../commands/env/README.md) | Environment listing/replacement, unset, chdir and split-string child launch. | Launcher permissions and supported split grammar. |
| [expand](../commands/expand/README.md) | Tab expansion with fixed/custom stops and initial-only mode. | C-byte and C.UTF-8 cell positions. |
| [expr](../commands/expr/README.md) | Integer/string expressions and BRE matching/captures. | Finite expression grammar and C-byte semantics. |
| [false](../commands/false/README.md) | Silent status 1. | Standalone metadata options exit 0. |
| [find](../commands/find/README.md) | Traversal, name/path/type/size/time/access predicates and selected actions. | Limited action grammar and filesystem identity/owner metadata. |
| [fmt](../commands/fmt/README.md) | Paragraph reflow, goal/width, indentation, prefixes and spacing modes. | C-locale bytes. |
| [fold](../commands/fold/README.md) | Byte/control-column wrapping and whitespace breaks. | C-byte and C.UTF-8 scalar widths. |
| [grep](../commands/grep/README.md) | BRE/ERE/literal search, context, recursion and binary policies. | C-byte and C.UTF-8 scalar matching with original byte offsets. |
| [gunzip](../commands/gunzip/README.md) | Streaming multi-member gzip decompression and integrity checks. | Partial output on corruption; named-file metadata/replacement limits. |
| [gzip](../commands/gzip/README.md) | Streaming gzip levels 1–9 and checked multi-member decompression. | Named compression requires -nc; no saved metadata or file replacement. |
| [head](../commands/head/README.md) | Line/byte prefixes, negative counts, headers and NUL records. | Finite Int64 counts. |
| [hexdump](../commands/hexdump/README.md) | Canonical/custom dumps, offsets, duplicate suppression and colors. | Fixed numeric profile; forward stdin discard is an extension. |
| [join](../commands/join/README.md) | Field joins, unpaired rows, headers, output selection and order checks. | C and C.UTF-8 byte ordering, with ASCII uppercase keys for -i. |
| [jq](../commands/jq/README.md) | JSON filters, lexical functions, modules, shared input cursor and stream events. | Subset language; exact numeric ordering at or above 2^53 is not claimed. |
| [jqlog](../commands/jqlog/README.md) | JSONL filtering with compact results and per-line evaluation. | Skips invalid JSON; no module/input effects. |
| [ln](../commands/ln/README.md) | POSIX symbolic links, relative targets, replacement and backups. | No hard links or Windows creation. |
| [ls](../commands/ls/README.md) | Names, layouts, quoting, timestamps/size sorting and explicit colors. | No long/owner/inode/mode listings or automatic terminal color. |
| [make](../commands/make/README.md) | Dependencies, variables, recipes, parallel jobs and selected jobserver support. | Partial GNU make; host process/jobserver transport boundaries. |
| [md5sum](../commands/md5sum/README.md) | Streaming MD5 and checksum manifest verification. | Binary/text modes do not translate bytes. |
| [mkdir](../commands/mkdir/README.md) | Multiple directories, parents and supported POSIX leaf modes. | No Windows mode setting or complete umask/parent-mode parity. |
| [mktemp](../commands/mktemp/README.md) | Exclusive temporary files/directories with templates and suffixes. | No unsafe dry-run names. |
| [mv](../commands/mv/README.md) | Rename, --no-copy, overwrite/update selection and simple or numbered backups. A failed --no-copy rename retains the backup at its backup name. | No cross-filesystem fallback; Windows link restrictions; equal-time `-i` / `-u` use file identities on POSIX. |
| [nl](../commands/nl/README.md) | Page/section numbering, regex selection, width and separators. | Byte-oriented matching and delimiters. |
| [od](../commands/od/README.md) | Typed byte dumps, offsets, widths and limits. | Fixed Linux numeric profile; C locale. |
| [paste](../commands/paste/README.md) | Parallel/serial joining, delimiter cycles and NUL records. | Byte delimiters. |
| [patch](../commands/patch/README.md) | Unified/context hunks, offsets, fuzz, reverse, dry runs and replacement of default reject files. | Explicit reject output requires a new file. No existing-file rewriting, named --output or extended binary formats. |
| [printenv](../commands/printenv/README.md) | All or selected environment values; NUL output. | Launcher-visible environment only. |
| [printf](../commands/printf/README.md) | Format reuse, numeric conversions, byte escapes and shell quoting. | Fixed numeric/C-locale profile. |
| [pwd](../commands/pwd/README.md) | Physical or validated logical working-directory paths. | Invalid logical PWD falls back to the runtime directory. |
| [realpath](../commands/realpath/README.md) | Component-wise canonicalization, missing paths and relative output. | Physical link resolution depends on public host APIs. |
| [rev](../commands/rev/README.md) | ASCII line/NUL-record reversal. | Rejects non-ASCII; buffers one record. |
| [rg](../commands/rg/README.md) | Unicode regex, ignore/glob/type filters, preprocessing and JSON results. | Explicit input; no PCRE2/compressed search; single-threaded, no mmap. |
| [rm](../commands/rm/README.md) | File/tree removal, explicit prompts and root protection. | No implicit terminal-sensitive prompts; partial effects remain on failure. |
| [rmdir](../commands/rmdir/README.md) | Empty-directory removal and upward parent removal. | POSIX symlink and Windows junction behavior differ. |
| [sed](../commands/sed/README.md) | BRE/ERE substitution, addresses, hold space, branches and multiline editing. | No -i or full GNU grammar; script-dependent memory. |
| [seq](../commands/seq/README.md) | Numeric ranges, custom separators, equal width and printf formatting. | Fixed numeric profile and bounded precision/exponents. |
| [serve](../commands/serve/README.md) | Static GET/HEAD, index files, MIME types, persistent connections and public directory handlers. | Trusted stable roots; no TLS/ranges/listing or race-free confinement. |
| [sh](../commands/sh/README.md) | Persistent shell state, expansions, pipelines, control flow and builtins. | Partial shell grammar and descriptor/terminal/filesystem API boundaries. |
| [sha1sum](../commands/sha1sum/README.md) | Streaming SHA-1 and checksum manifest verification. | Binary/text modes do not translate bytes. |
| [sha256sum](../commands/sha256sum/README.md) | Streaming SHA-256 and checksum manifest verification. | Binary/text modes do not translate bytes. |
| [sha512sum](../commands/sha512sum/README.md) | Streaming SHA-512 and checksum manifest verification. | Binary/text modes do not translate bytes. |
| [sleep](../commands/sleep/README.md) | Summed fractional second/minute/hour/day delays. | Host signal parity is outside the supported profile. |
| [sort](../commands/sort/README.md) | Keyed sort, exact numeric order, stable ties, merge/check and external runs. | C/C.UTF-8 byte order, accounted buffer and output-identity limits. |
| [split](../commands/split/README.md) | Line/byte/record/chunk splitting, suffixes and shell filters. | No existing-output replacement; spooling and child permissions may apply. |
| [strings](../commands/strings/README.md) | Printable 7-bit/8-bit runs, minimum lengths, offsets and names. | No wide encodings, Unicode classes or object-section parsing. |
| [tac](../commands/tac/README.md) | Reverse records with fixed or regex separators. | Regex mode uses whole-input memory; stdin may need temporary storage. |
| [tail](../commands/tail/README.md) | Line/byte suffixes, start positions, headers, descriptor following and POSIX regular-file name following with `-F`. | Windows name following requires comparable file identities. |
| [tee](../commands/tee/README.md) | Multiple output sinks, append and explicit output-error policies. | Default SIGPIPE behavior is unavailable. |
| [test](../commands/test/README.md) | String/integer/file predicates, Boolean forms and POSIX `-ef` identity comparison. | Windows `-ef` and unavailable terminal, owner and mode predicates reject. |
| [timeout](../commands/timeout/README.md) | Local-only child deadline and exit-status mapping. | Unpublished; no process-group or signal-option profile. |
| [touch](../commands/touch/README.md) | Create missing files or skip them with -c. | No timestamp updates; existing files fail. |
| [tr](../commands/tr/README.md) | Byte translation, deletion, squeezing, complement and truncation. | C/C.UTF-8 byte classes. |
| [tree](../commands/tree/README.md) | Text/JSON/HTML trees, filtering, pruning, limits and supported sizes. | Link leaves; no target display/mode colors; platform size boundaries. |
| [true](../commands/true/README.md) | Silent status 0. | Standalone metadata options are handled separately. |
| [typst](../commands/typst/README.md) | Compilation/export, watch, eval/query, fonts, config and local templates. | Local packages, one thread, lexical paths; no network/self-update/HTML server. |
| [unexpand](../commands/unexpand/README.md) | Leading/all-blank tab conversion with custom stops. | C-byte and C.UTF-8 cell positions. |
| [uniq](../commands/uniq/README.md) | Adjacent deduplication, counts, groups and selected comparison fields. | No global deduplication; C-locale bytes. |
| [unlink](../commands/unlink/README.md) | One file or symlink removal. | No directories or multiple operands. |
| [wc](../commands/wc/README.md) | Counts, C/C.UTF-8 character and display widths, totals and NUL-separated file lists. | Stdin position boundary. |
| [wget](../commands/wget/README.md) | HTTP(S) downloads, Basic auth, cookies, config, retry and resume. | No FTP/mirroring/HSTS; stdin authentication replay unavailable. |
| [which](../commands/which/README.md) | PATH/direct executable lookup, all matches and quiet mode. | No shell aliases, functions or builtins. |
| [xargs](../commands/xargs/README.md) | Argument batching, replacement, delimiters, confirmation and concurrency. | Host argument transport and process permissions. |
| [xxd](../commands/xxd/README.md) | Hex/binary/C styles, EBCDIC, autoskip, seek and reverse conversion. | No backward stdin seek; existing-output identity/mode boundaries. |
| [yes](../commands/yes/README.md) | Repeated output until interruption or output failure. | No exact signal-status parity. |
| [zcat](../commands/zcat/README.md) | Gzip decompression to stdout across files and members. | Partial output can precede a corruption error. |

The unpublished serve candidate adds `cli/serve/static_files` for Wasm library
users. `Directory::Directory(path)` validates and stores one canonical root;
`Directory::serve` handles one request with optional route-relative URL path
mapping. Multiple instances may serve concurrently through one or several
caller-owned listeners, with independent path checks and preserved redirect
prefixes and queries. CLI arguments and single-directory serving are unchanged.

## Shared boundaries

- **Text and numbers:** most traditional text commands use C-locale byte
  semantics. This includes cut, tr and sort. For wc, fold, expand, unexpand and
  column, C.UTF-8 or C.utf8 in the first nonempty LC_ALL, LC_CTYPE or LANG
  selects Unicode 16.0 scalar widths with narrow ambiguous characters.
  Grep uses the same locale precedence and Unicode 18.0 character properties
  for C.UTF-8 matching. Sort, comm and join use byte collation in C and
  C.UTF-8. Regional language collations require additional locale data.
  The Unicode regex profile in rg and JSON string handling in jq are separate.
  Numeric tools with extended-precision formatting use the documented fixed
  Linux amd64 profile, not an arbitrary host ABI.
- **Filesystem:** `x/fs` offers optional file identity on POSIX and NTFS. Windows
  volume-type detection, raw mode, ownership, handle truncation, umask and
  timestamp setters remain unavailable for the operations below. Commands reject affected operations
  instead of inventing metadata. POSIX links and Windows junctions differ;
  macOS directory-size queries also have an explicit unsupported boundary.
- **I/O and effects:** earlier output and successful mutations can remain after
  a later failure. Decoding, transfers and multi-operand commands are not
  transactional. Failed writes are not replayed; where a write's effect is
  uncertain, reported committed bytes are a lower bound.
- **Memory:** streaming does not imply a fixed process-memory bound.
  Base32 decoding, diff, regex tac and multiline rg can retain complete input;
  jq slurp collects values; records, captures and scripts can also grow.
  External sorting and some splitting/layout modes need temporary storage.
- **Runtime:** launcher policy controls filesystem, network, environment and
  child-process access. Automatic terminal detection and exact signal/process
  group behavior are not universally available. Explicit output options avoid
  depending on terminal inference.

See the decisions for [streams and resources](adr/0003-streams.md),
[filesystem](adr/0004-filesystem.md), [HTTP transfers](adr/0005-transfer.md),
[processes](adr/0006-process.md), [languages](adr/0007-language.md) and
[data formats](adr/0008-data.md). Algorithm details belong in
[performance documentation](performance/), rather than this support inventory.

## Extensions and diagnostics

Standalone `--version` prints `<command> <package-version>` and a newline.
Standalone `--help` starts with `Usage: <command>`, includes both metadata
options and ends with a newline. Both use stdout, leave stdin unread and exit 0.
Other diagnostics and statuses remain command-specific: for example diff/cmp
use 0/1/2 for equal/different/error, grep/rg use 0/1/2 for
match/no-match/error, and false normally exits 1.

| Commands | Deliberate extensions or differences |
| --- | --- |
| cat | Combined long display aliases, --unbuffered and -h; -u has no effect. |
| comm, join | Named long aliases for existing short options, including comm --suppress-1/2/3 and join --field1/2. |
| od, strings | Additional long format names; strings --octal/-o. |
| ls, tree | Additional long layout/filter aliases; ls -P/--no-dereference. |
| sed, cp | sed --extended and cp --dereference-command-line. |
| base64, rmdir | base64 -D and rmdir -I. |
| echo | POSIXLY_CORRECT escape/initial -n rules, with the standalone metadata exception retained. |
| jq, jqlog | jq -l/--logs skips malformed JSON lines; jqlog is a separate JSONL adapter without jq CLI module/input effects. |
| hexdump, xxd | hexdump can discard forward stdin bytes; xxd accepts documented extended long spellings and the project metadata convention. |
| touch, test, which | touch timestamp aliases reject; test unary -a checks existence; which -s uses the project quiet-status profile. |
| curl, wget | --idle-timeout selects a body-inactivity deadline and is a project option. |

Internal metadata names such as update-mode or backup-control are not argv
spellings: use `--update=MODE` and `--backup=CONTROL`.
For jq, `-f` selects a positional filter filename; it does not consume an
attached value. Use `-f -- --arg input.json` or `-f ./--arg input.json`
when the filter filename begins with a dash.

Controlled diagnostics have exact assertions where appropriate. Host error
wording and some upstream punctuation/quoting are checked at the documented
category/effect level; universal GNU diagnostic identity is not claimed.
The independent expectations live in [cases](../tests/cases/) and the
module-owned regression fixtures.

<a id="rg-candidate"></a>

## rg profile

The current rg implementation provides Unicode regex search, ignore/glob/type
selection, encoding conversion, preprocessing and structured output.
Pass paths explicitly, or `-` for stdin. Effective PCRE2, compressed-search,
one-filesystem and byte-based DFA cache-limit requests reject. Compatibility
flags for threads and mmap do not enable parallel search or memory mapping.
Preprocessors require permission to launch children; multiline search can
retain the complete input.

Automatic color, hyperlinks, headings and line numbers are not inferred from
terminal state. Select supported explicit modes. The
[command README](../commands/rg/README.md) and
[runtime notes](../commands/rg/internal/sys/README.mbt.md) describe usage and
host-specific boundaries.

## Documentation generation

Command READMEs use the [shared template](readme_template.md).
`options.json` keeps the complete option declaration; optional
`readme_options` selects the common subset rendered into the two-column
README table. This selection does not change parsing or help output.
Run `metadata update` or `metadata check` through the
[development entry](../tools/README.md). Keep support notes grounded in source
and executable regressions; a generated table is not compatibility evidence.
