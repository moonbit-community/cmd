# Pure MoonBit Command Compatibility Spike

Date: 2026-09-02

## Question

Can all 48 commands in this repository converge on their original upstream
behavior using pure MoonBit, without calling host commands or adding C, C++,
shell, native stubs, or FFI? Which current differences are implementation gaps,
and which require a deeper portable-runtime spike before a semantic weakening
can be considered?

## Scope

The audit covers every command directory, not only `wget` and `curl`.

| Baseline family | Commands |
| --- | --- |
| GNU Coreutils 9.11 | `base64`, `basename`, `cat`, `chmod`, `comm`, `cp`, `cut`, `dirname`, `echo`, `env`, `false`, `head`, `join`, `ln`, `ls`, `mkdir`, `mv`, `nl`, `paste`, `printenv`, `printf`, `pwd`, `rm`, `rmdir`, `seq`, `sha256sum`, `sleep`, `sort`, `tail`, `tee`, `test`, `timeout`, `touch`, `tr`, `true`, `uniq`, `wc` |
| GNU Diffutils 3.12 | `cmp` |
| GNU findutils 4.10.0 | `find`, `xargs` |
| GNU grep 3.12 | `grep` |
| GNU Wget 1.25.0 | `wget` |
| curl 8.22.0 | `curl` |
| POSIX.1-2024 Shell Command Language | `sh` |
| GNU Make 4.4.1 | `make` |
| jq 1.8.2 | `jq` |
| Vim 9.1 `xxd` | `xxd` |
| Imported source snapshot | `jqlog` from `bobzhang/jqlog@0.1.0`, commit `06a529211343c773d30d2c3aa0231a2456665b7a` |

There are 48 local commands and 47 MoonX commands. `timeout` is local-only
because its process-group requirement is currently capability-gated.

## Method

This spike used the installed toolchain and current source rather than assumed
MoonBit APIs:

1. Enumerated all command packages, catalog option declarations, READMEs, and
   explicit unsupported branches.
2. Inspected public APIs with `moon ide doc` and, where needed, the pinned
   MoonBit dependency source.
3. Ran repository tests and the current compatibility/policy runners.
4. Ran focused host-versus-candidate probes for options, formatting,
   environment inheritance, shell/Make language forms, and HTTP redirects.
5. Classified gaps as implementable, requiring a dedicated spike, or already
   proven unavailable. No new product implementation was added during this
   planning spike.

The full per-command result is recorded in the
[command compatibility matrix](../compatibility-matrix.md).

## Evidence

| Check | Result | Consequence |
| --- | --- | --- |
| `moon test --target native` | 33 tests passed. | Current unit tests are green, but test success is not an upstream conformance result. |
| Native `tests/compat` with `--gnu-diff` | The runner reported 48 commands, but performs real host comparisons for only `base64`, `cat`, `cut`, `head`, `sha256sum`, `sort`, `tail`, and `tr`. It does not verify the host tool version. | The existing `48/48` wording is a smoke result, not proof that any complete command is compatible. |
| `tests/policy` | The policy suite passed. | Wasm authority checks remain useful, but policy compliance and command compatibility are separate gates. |
| `moon ide doc` for `@http`, `@fs`, `@process`, and `@env` | Public pure-MoonBit APIs provide HTTP streaming and methods, file bytes/kind/size/times/create/append/rename/symlink, direct child execution/cancellation, and environment enumeration. | Most current gaps are implementable work rather than a reason to weaken semantics. |
| Public API search for hard links, readlink, ownership, special-file creation, portable tty handles, locale services, and process groups | No verified portable public primitive was found in the pinned dependencies. | These are capability-spike candidates, not yet permanent exceptions. |
| Live Wget redirect probe | The MoonBit command returned success for a `302 Location` response and created a zero-byte output instead of following the redirect. | Current Wget behavior is observably incompatible; redirect handling is feasible in `core/netops`. |

## Representative Mismatches

These probes are examples, not the complete oracle suite:

| Probe | Current behavior | Baseline behavior |
| --- | --- | --- |
| Implicit terminal stdin for 14 recently changed commands | Prints `reading standard input; send EOF to finish`. | The corresponding original commands silently wait for input; the extra stderr line is incompatible. |
| `wc` default output | Emits unpadded counts such as `1 2 4`. | GNU `wc` aligns the count columns. |
| `cat -n` | Rejected at spike time; implemented in the Phase 3 slice. | GNU `cat` numbers output lines. |
| `find . -maxdepth 0 -exec true \;` | Rejected at spike time; one-child `;` execution is implemented in the Phase 3 slice. | GNU `find` executes the action. |
| `join -a 1 FILE1 FILE2` | Rejected at spike time; `-a`/`-v`/`-e`/`-o` are implemented in the Phase 3 slice. | GNU `join` emits unpairable lines from the selected input. |
| `ls -l` | Rejects long format. | GNU `ls` prints the documented metadata format. |
| `touch -r REF FILE` | Now rejects before mutation with the Phase 4 capability diagnostic. | GNU `touch` copies the reference time. |
| `xxd -s 1 FILE` | Rejected at spike time; positive forward/reverse offsets are implemented in the Phase 3 slice. | Vim `xxd` starts at the requested offset. |
| `jq --sort-keys .` | Rejects the option. | jq accepts the long option. |
| Native `env` with an inherited variable | The current child environment policy can omit the variable. | GNU `env` inherits the environment unless explicitly cleared or changed. |
| POSIX command substitution in `sh` | The current parser/executor rejects the form. | POSIX `sh` evaluates command substitution. |
| GNU Make `include` | Rejected at spike time; relative `include`/`-include`/`sinclude` are implemented in the Phase 5 slice. | GNU Make loads the included makefile. |

The examples confirm a repository-wide pattern: many implementations provide a
useful core operation, but their option grammar, defaults, output bytes,
diagnostics, statuses, language grammar, or side effects remain narrower than
the originals.

## Pure MoonBit Feasibility

| Area | Assessment | Required response |
| --- | --- | --- |
| Argument parsing, byte/line streaming, formatting, diagnostics, and exit statuses | Feasible in pure MoonBit. | Implement command-specific upstream grammar and compare stdout, stderr, and status independently. |
| HTTP/HTTPS for Wget and curl | Feasible. The runtime exposes streaming requests, headers, methods, body writers, proxy and TLS trust configuration. | Build shared transport mechanics in `core/netops`, retaining different Wget/curl policies. |
| Relative redirects | Feasible although the runtime resolver is private. | Implement and test a small repository-owned RFC 3986 resolver and redirect state machine. |
| Native environment inheritance | Feasible through `@env.get_env_vars()`. | Remove the current native filtering difference; keep Wasm policy behavior explicit. |
| Shell, Make, jq, grep, and find languages | Large but not proven blocked. | Implement grammar/evaluator features incrementally against generated and hand-written oracle fixtures. Size alone is not an exception. |
| File metadata, hard links, readlink, ownership, and special files | Some required portable primitives are not yet verified. | Try public APIs, composition from existing pure-MoonBit APIs, pure-MoonBit dependencies, and target-conditioned MoonBit implementations before proposing an exception. |
| Terminal detection on Windows | Not proven. Current code returns false because no portable `isatty` API was found. | Probe character-device paths and handle metadata on real Windows CI without native glue. If detection remains impossible, suppress nonessential terminal decoration rather than corrupting redirected output. |
| Locale-aware collation and character classes | No portable locale service was identified. | Complete `LC_ALL=C` behavior first, then spike pure-MoonBit locale tables and platform data access before narrowing the claim. |
| Process-group termination for GNU `timeout` | Direct child cancellation exists, but no process-group primitive was found. | Keep `timeout` local-only and partial while testing target-conditioned pure-MoonBit designs; do not bypass the gate with C or a host utility. |
| curl protocols outside HTTP/HTTPS | The installed package does not supply them, but that does not prove pure-MoonBit implementations impossible. | Run one protocol spike per family, including DNS/socket/TLS requirements, before recording an exception. |

## Spike Conclusion

The repository can pursue upstream-compatible migration in pure MoonBit. The
present evidence does **not** justify a general semantic weakening. It shows:

- no command is currently certified across its complete pinned baseline;
- most observed differences are ordinary implementation and test gaps;
- a smaller set of platform capabilities needs dedicated spikes;
- `timeout` is the only already gated publication exception, and even it must
  remain open for future pure-MoonBit runtime improvements;
- the 14-command stdin hint must be removed from the compatibility path because
  it changes upstream stderr behavior rather than improving compatibility.

## Exception Investigation Protocol

A proposed weakening is admissible only after a command-specific spike records
all of the following attempts:

1. public MoonBit and pinned dependency APIs, verified with `moon ide doc`;
2. composition or direct algorithm/protocol implementation in pure MoonBit;
3. a suitable pure-MoonBit dependency and a target-conditioned pure-MoonBit
   implementation for native/Wasm where portability differs;
4. minimal reproductions on Linux, macOS, Windows, and Wasm where applicable;
5. comparison with the pinned upstream oracle, including status and side
   effects, plus an explanation of why approximation would be unsafe.

If all routes fail, the command must reject the unsupported operation before
partial side effects and document the exact limitation in `--help`, README, and
the matrix. Unsupported behavior may not be silently ignored or approximated.

## Decision Output

The resulting policy is accepted in
[ADR 0001](../adr/0001-upstream-compatible-command-migration.md). The ordered,
testable work is in the
[upstream compatibility execution plan](../upstream-compatibility-plan.md).
