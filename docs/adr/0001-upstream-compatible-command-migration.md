# ADR 0001: Upstream-Compatible Command Migration

Date: 2026-09-02

Status: Accepted

## Context

The repository currently implements 48 local commands and publishes 47 through
MoonX. Its existing compatibility document correctly describes a controlled
dialect, not complete GNU compatibility. That is useful for a policy-first
runtime, but it does not meet the product goal: a developer should be able to
use the original command syntax and receive the original command experience
without learning a MoonBit-specific dialect.

The `wget` redirect probe demonstrates the distinction. The current command
performs a real HTTP request, yet reports success for a 302 response and writes
an empty file rather than fetching the redirected resource. It is functional
as a fetch primitive but not compatible with GNU Wget.

`wget`, `curl`, `jq`, `make`, `sh`, and `xxd` are not GNU Coreutils programs.
They therefore need their own upstream baselines; "Coreutils compatible" alone
cannot establish compatibility for the full command inventory.

## Decision

Adopt **upstream-compatible migration** as the product contract.

A command is called compatible only for the exact upstream version, platform
profile, locale, and option surface recorded in the compatibility matrix. The
compatibility claim covers command spelling and argument grammar, stdin/stdout/
stderr bytes, exit status, filesystem side effects, and relevant timing or
interactive behavior. Passing a smoke test is insufficient.

The project will use the following initial upstream baselines:

| Command family | Baseline |
| --- | --- |
| Core utility commands | GNU Coreutils 9.11 under `LC_ALL=C` |
| `cmp` | GNU Diffutils 3.12 under `LC_ALL=C` |
| `find`, `xargs` | GNU findutils 4.10.0 |
| `grep` | GNU grep 3.12 |
| `wget` | GNU Wget 1.25.0 |
| `curl` | curl 8.22.0 |
| `sh` | POSIX.1-2024 Shell Command Language, not Bash-specific behavior |
| `make` | GNU Make 4.4.1 |
| `jq` | jq 1.8.2 |
| `xxd` | Vim 9.1 `xxd` (exact patch build pinned in the oracle image) |
| `jqlog` | Imported `bobzhang/jqlog@0.1.0` source snapshot at commit `06a529211343c773d30d2c3aa0231a2456665b7a` |

The exact references and oracle-environment rules are maintained in
[the pinned baseline record](../upstream-baselines.md). The primary manuals are
[Coreutils](https://www.gnu.org/software/coreutils/manual/coreutils.html),
[findutils](https://www.gnu.org/software/findutils/manual/html_mono/find.html),
[grep](https://www.gnu.org/software/grep/manual/grep.html),
[Wget](https://www.gnu.org/software/wget/manual/wget.html),
[curl](https://curl.se/docs/manpage.html),
[POSIX.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html),
[GNU Make](https://www.gnu.org/software/make/manual/make.html),
[jq](https://jqlang.org/manual/v1.8/), and
[Vim `xxd`](https://vimhelp.org/xxd.txt.html).

## Compatibility Policy

1. Do not advertise a command as fully compatible while its matrix row has
   unimplemented standard behavior.
2. Do not accept an upstream option and silently ignore or reinterpret it.
   Implement it, reject it with the upstream-style diagnostic and status, or
   record a documented platform exception.
3. Preserve upstream defaults before adding MoonBit-specific convenience
   behavior. Repository-added prompts, progress meters, or flags must not
   change the default compatibility path. In particular, an implicit stdin
   read remains silently blocking unless the pinned upstream command itself
   prints a prompt.
4. Use upstream exit statuses where they are part of scripts' contracts.
   Examples include Wget's server-error status 8 and curl `-f` status 22.
5. A portable capability boundary is not hidden. Wasm policy denials and any
   proven pure-MoonBit limitation receive an actionable diagnostic, a help
   entry, README coverage, and a matrix exception.
6. A semantic weakening is admissible only after a recorded spike attempts,
   in order, the public MoonBit APIs, a direct/composed pure-MoonBit design, a
   suitable pure-MoonBit dependency, and target-conditioned pure-MoonBit code.
   The spike must include a minimal reproducer, upstream differential output,
   native/Wasm impact, and no-side-effect failure behavior.
7. The repository remains pure MoonBit at the product boundary. No new C,
   C++, shell, native stub, FFI shim, or host-command delegation is permitted.
   Upstream commands may run only in tests as oracles.
8. New compatibility work lands in small command-family changes, each with
   oracle fixtures and a rollback point. There is no flag-day rewrite.

## Architecture

Keep command packages as thin command-specific adapters. Place shared
semantics in small, focused core packages only where two or more commands need
the same behavior:

```text
core/cli       command-specific grammar helpers and common diagnostics
core/platform  terminal and portable capability detection
core/fsops     file naming, overwrite, metadata, and safe mutation helpers
core/stream    byte/line streaming and output formatting helpers
core/netops    HTTP transfer, redirect, retry, progress, and transfer errors
core/process   process and environment behavior
tests/oracle   upstream fixture runner and command compatibility matrix
commands/*     option mapping and command-specific policy
```

This is intentionally not a universal abstraction layer. A helper is added
only when it owns a shared upstream rule and has direct tests. `wget` and
`curl`, for example, share transport mechanics but retain different defaults:
Wget follows redirects by default; curl does so only with `-L`.

## Consequences

Positive consequences:

- Developers can reuse existing shell knowledge and scripts within the declared
  profile.
- Documentation becomes an exception ledger rather than a replacement manual.
- Pure-MoonBit constraints are explicit and testable.
- The project gains a durable regression suite instead of one-off compatibility
  examples.

Costs and constraints:

- The current 0.1.x dialect is not a sufficient release claim. Compatibility
  changes that alter accepted options, output, or exit statuses require a new
  minor version line rather than mutating published behavior in place.
- Full curl compatibility is a larger program than HTTP GET support. Only the
  verified HTTP/HTTPS profile may be promised until dedicated pure-MoonBit
  protocol spikes resolve the remaining protocol families.
- `sh` has no single "original" implementation. POSIX shell is the portable
  baseline; Bash extensions are separate, explicit work.
- `moonx cli/<command>` still has a launcher prefix. Providing a bare command
  name would require a separately designed installation or shim product and is
  not implied by semantic compatibility.

## Rejected Alternatives

### Continue documenting a controlled dialect

Rejected because it leaves developers to learn command-specific deviations and
does not satisfy migration without rewrites.

### Delegate to host commands

Rejected because it violates the pure-MoonBit requirement, defeats Wasm policy
visibility, and makes results depend on the host installation.

### Claim broad GNU compatibility while supporting only common flags

Rejected because command-line scripts depend on exit codes, file behavior,
defaults, and diagnostics as well as option names.

### Implement every upstream feature before testing

Rejected because it prevents feedback and leaves no defensible rollback point.
The matrix-driven implementation plan provides incremental compatibility
profiles without overstating them.

## Exit Criteria

This ADR is considered implemented for a command only when its matrix row is
complete, its local oracle tests run under the declared baseline, its native
and Wasm behaviors are classified, and every remaining exception satisfies the
policy above. The detailed steps are in
[the execution plan](../upstream-compatibility-plan.md).
