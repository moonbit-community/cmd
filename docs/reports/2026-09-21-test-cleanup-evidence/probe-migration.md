# Active probe assertion migration

Updated: 2026-09-21

This is a source-level assertion map, not a claim that a platform run passed.
The rows refer to the original probe line numbers before archival. The root
implementation report records actual executions. Both Native and Wasm run the
same retained CLI cases; the Native test driver launches the requested backend.
Package unit tests are additional coverage and do not replace these CLI cases.

`tests/fidelity.mbtx` uses `Harness::expect` to check status and complete stdout
(lines 70–82); each contract row below retains those two observations. The new
single-command contracts also assert stderr explicitly. Filesystem scenarios
apply on Linux/macOS and are skipped with a reason on Windows. Text, shell,
make and process cases are intended to run on all three hosts.

## Fidelity probe

| Original assertion location | Retained stable case ID | Backend | Retained observations / change |
| --- | --- | --- | --- |
| `tests/fidelity.mbtx:97` | `grep-no-context-separator` | Native + Wasm | Status 0, exact `a\na\n` stdout, empty stderr. |
| `:98` | `grep-basic-plus-literal` | Native + Wasm | BRE literal `+`, status and complete output. |
| `:99` | `grep-extended-longest-only` | Native + Wasm | ERE `-o` longest match, status and complete output. |
| `:100` | `base64-zero-wrap` | Native + Wasm | `-w0` bytes without trailing LF. |
| `:101–102` | `seq-descending-default`, `seq-descending-explicit` | Native + Wasm | Default positive step produces empty output; explicit negative step produces three lines. |
| `:103–109` | `jq-stream-framing` | Native + Wasm | Three top-level JSON values; exact compact output and status. |
| `:110` | `jq-slurp-stream` | Native + Wasm | Stream slurp, exact output/status. |
| `:111` | `jq-raw-slurp` | Native + Wasm | Raw slurp retains internal newlines. |
| `:112–117` | `jq-variable-scope` | Native + Wasm | AST variable shadowing, exact output/status. |
| `:118` | `jq-false-exit` | Native + Wasm | `false` output with status 1. |
| `:119` | `jq-partial-before-parse-error` | Native + Wasm | First value emitted before later parse failure; stdout `1\n`, status 4. |
| `:120–125` | `process-lifecycle` | Native + Wasm | Inherited environment value reaches a pure MoonBit helper. `/usr/bin/printenv` is replaced by the runner's environment helper. |
| `:126–133` | `process-lifecycle` | Native + Wasm | Both `LC_ALL=C` and `LC_ALL=POSIX` remain unchanged in the child; exact status/stdout/stderr. |
| `:134–141` | `process-lifecycle` | Native + Wasm | Local variable is absent before export and present afterward. The helper emits one LF for an absent value, so complete expected stdout is `\nsecret\n`; this fixture difference is explicit. |
| `:142–147` | `sh-command-substitution-trailing-newlines` | Native + Wasm | Only trailing LFs removed; trailing space retained. |
| `:148–150` | `sh-arithmetic-error-status` | Native + Wasm | Arithmetic expansion failure returns nonzero and produces no command stdout; diagnostic is asserted. |
| `:151` | `sh-substitution-failure-status` | Native + Wasm | Assignment substitution failure returns 1 and empty output. |
| `:156–159` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Existing-destination and same-path cp refuse, preserve source/destination contents, mode, mtime and fixture link groups. |
| `:160–184` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Hard-link fixture creation succeeds. Both ordinary cp and `--no-preserve=mode` refuse the alias. Contents and link groups remain; raw inode/link-count tuples are compared before/after within the same fixture only. This preserves the old macOS inode/link-count assertion and extends it to Linux. |
| `:185–191` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | New copy succeeds with empty stdout, identical content and mode matching a newly created 0666 control under the real umask. |
| `:192–195` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Existing touch refuses without changing content or mtime; atime is checked before reading contents as an additional assertion. |
| `:196–197` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | `touch -c` succeeds with empty stdout and leaves the path absent. |
| `:198` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Missing-file touch succeeds with empty stdout and creates the file. |
| `:199–202` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Earlier operand creation remains after a later unsupported existing-file operand; status nonzero and existing-file mtime unchanged. |
| `:203–213` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | `mkdir -p -m700` succeeds with empty stdout; leaf mode is 700 and parent matches a 0777 control under the same umask. The old hardcoded parent 755 assumed umask 022; the control preserves that result at 022 and supports other actual umasks. |
| `:214–221` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | Command-line symlink chmod succeeds with empty stdout and changes target mode to 600; recursive link exclusion is additional coverage. |
| `:222–226` | `make-ready-ack` | Native + Wasm | `$(shell ...)` collapses embedded newlines and strips the final newline; exact stdout `one two\n`, status 0, empty stderr. |
| `:227–235` | `make-ready-ack` | Native + Wasm | Shared dependency writes exactly one `S`, before both recipes report ready. Both ready markers must exist before either ACK is sent; neither done marker may exist then, and both must exist after success. This replaces sleep/order inference with a direct overlap barrier and retains single execution and completion assertions. |
| `:236–241` | `make-ready-ack` | Native + Wasm | Without `-k`, failed prerequisite returns 2, empty stdout, and never runs its parent recipe. A separate `-k` round additionally checks that an independent target completes. |
| `:242–244` | `filesystem-fidelity` | Native + Wasm; POSIX hosts | `rm --no-preserve-root` succeeds with empty stdout/stderr and removes the ordinary file. |

Single-command definitions are in `tests/cases/<command>.json`. Stateful
implementations are `tests/runner/scenarios.mbt`, `scenario_process.mbt` and
`scenario_filesystem.mbt`. The driver still invokes real built command
artifacts, never the command's internal function as a substitute.

## Interactive probe

Every assertion in `commands/sh/interactive_probe.mbtx` is retained under
`sh-interactive-session` in `tests/runner/scenarios.mbt`, on Native and Wasm:

| Original location | Retained observation |
| --- | --- |
| `:47–52` | Immediate PS1, persistent variable, `ENV` startup value, exact stdout and subsequent PS1 while stdin remains open. |
| `:53–59` | Two PS2 prompts for incomplete `if`, execution only when `fi` arrives, multiline output and PS1. |
| `:60–65` | `read` consumes the next input line; value and next prompt are exact. |
| `:66–69` | Foreground child receives exactly one following input line and exits; subsequent prompt appears. A pure MoonBit one-byte-at-a-time helper replaces `/usr/bin/head -n 1`. |
| `:70–74` | Exact syntax-error diagnostic followed by PS1, then successful command and next prompt. |
| `:75–78` | EOF leads to status 0 and no leftover stdout/stderr bytes. |

Persistent function/cwd state and explicit `exit 7` with no later execution are
additional assertions. Neither the old nor new probe claims TTY/raw-mode,
signal recovery, PTY or job-control coverage.

## Network probe

The candidate-side assertions in `core/netops/verify_cli.mbtx` map to
`network-auth-cookie` in `tests/runner/scenario_network.mbt`, on Native and Wasm.
The in-process loopback HTTP fixture is shared across rounds.

| Original location | Retained candidate observations |
| --- | --- |
| `:87–104`, common checks `:131–133` | curl Basic auth and explicit credentials overriding URL credentials; exact response stdout, status 0, empty stderr. |
| `:105–114`, common checks `:131–133` | Explicit and repeated `-b` cookies; exact Cookie header reflected in response. |
| `:115`, common checks `:131–133` | Set-Cookie retained through redirect. |
| `:116–117`, common checks `:131–133` | Explicit `-b` cookie survives cross-origin redirect while custom Cookie header is removed. |
| `:118–137` | wget waits for challenge, exactly two requests, first Authorization absent; successful response bytes/status. New case also checks the second Authorization value. |
| `:144–158` | Both commands save session jar; exact response/status/stderr and `sid` jar entry. |
| `:159–167` | Both commands reload the jar; exact response/status/stderr. |
| `:168–178` | curl combines jar and explicit cookie; exact combined header, response/status, additionally empty stderr. |
| `:179–189` | Unsupported jar plus custom Cookie header refuses with nonzero, empty stdout and documented diagnostic. New case also requires no HTTP request. This is a boundary subcheck, not evidence of upstream-compatible acceptance. |
| `:192–203` | Candidate jar mode is observed on Linux/macOS and compared with a newly created ordinary control file under the actual umask. See differential gap below. |
| `:211–225` | Jar write failure leaves successful transfer status/output/stderr unchanged; new check also requires the nonexistent-parent path to remain absent. |

Additional current cases cover cross-origin Authorization removal for both
commands, wget no-challenge credentials, cookie domain/path/expiry selection,
no-cookies mode and exclusion of session cookies from a wget jar by default.

**Oracle coverage is not interchangeable with these contracts.** The old
network probe also ran every normal invocation through the installed host
curl/wget (`candidate=false`, lines 125, 142 and 212), and on macOS compared
candidate jar mode directly with that host oracle (line 200). The new
`network-auth-cookie-oracle` scenario now runs the same request matrix through
the candidate and pinned Linux container, comparing complete stdout, stderr,
status and jar modes and retaining raw streams on failure. Unsupported header
combinations remain candidate-only boundary assertions. This closes the
source-level migration gap; Linux execution remains a CI gate because Docker
is unavailable locally. A candidate contract pass is not a differential pass.
Old unpinned host results remain historical evidence only.

The three probes were copied byte-for-byte into this directory's `repro/`
archive and removed from active source paths after both backend contracts
passed. Historical replay remains available. Use the registered driver for
current CI; final executions are listed in the implementation report.
