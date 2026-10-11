# New toolchain and pure MoonBit alternative-path validation

Date: 2026-09-21
Language revision: 2026-10-11; historical results retained.

The local host was macOS, with moon/moonrun 0.1.20260920 and moonc
0.10.14+7d59c7ec9. All local Moon/MoonX calls retained the PATH toolchain and
explicit `MOON_HOME="$HOME/.moon-accounts/cli"`. This report describes then
unpublished workspace changes; it does not rewrite 0.2.0 release evidence.

## Dependencies and warnings

Registry refresh succeeded. At the time, async 0.22.1, x 0.5.5 and moonjq 0.1.2
remained the latest stable releases; versions were not artificially incremented.
Dependency declarations matched across 50 workspace modules.
The [complete jq tree](dependency-tree.txt) resolved transitive async/x to those
same versions. Versions, checksums and timestamps are in
[inventory.json](inventory.json).

The compiler required explicit trait-method promotion: 74 public extend
declarations preserved previously implicit methods, and 84 blackbox package
qualifiers were corrected. Warnings were not disabled. Generated interfaces
now show explicit signatures. Behavior changes added CustomCookieMode and
TransferOptions fields; constructors default to SeparateFields and remove
explicit Cookie across origins, while wget enables cross-origin forwarding.
Downstream TransferOptions struct literals need the new fields; versioning
requires API review before release. Nothing was published in this round.

## Measured alternatives

| Path | Observation | Decision |
| --- | --- | --- |
| Two public HTTP header layers | Raw TCP contains two independent Cookie fields in the same order as macOS curl 8.7.1. | Implement explicit curl header plus jar while retaining transport, timeouts and TLS. |
| Wget custom Cookie | Wget 1.25.0 sends only the explicit field, overriding automatic Cookie, and forwards it across origins. | Separate mode/forwarding switch; jars still store response cookies. Curl removes the explicit field across origins. |
| Unwrap cancellation handler as kill | Host kill rejects a nonexistent PID; Native hard_cancel returns Unit. | Reject this substitute because it loses failure status; add upstream feedback. |
| Linux Native procfs identity/truncate | macOS provides no Linux runtime evidence; Wasm handles are not OS fds. | Retain an experimental direction and prerequisites, without enabling product overwrite. |

Raw probes and output are in this directory. The
[public API recheck](../2026-09-21-public-api-recheck.md) records source locations,
rejected substitutes and unlock conditions. The first two paths have product
regressions; old rejection is not counted as parity. Metadata, TTY, recoverable
signals, exec and job-control gaps remain.

## Local validation

| Check | Result |
| --- | --- |
| `moon check --target all --deny-warn` | Passed, zero warnings |
| `moon test --target native --deny-warn` | 160/160 |
| `moon test --target wasm --deny-warn` | 130/130 |
| Native/Wasm release build `--deny-warn` | Both passed |
| Native/Wasm stateful scenarios | 5/5 each: filesystem, interactive shell, lifecycle, network, make |
| Selected curl/wget single-call contracts | 2/2 per backend; network semantics also exercised in stateful scenarios |
| `moon info`, `moon fmt` | Serialized; interface differences reviewed |

Core network tests observe complete Cookie fields in both modes for initial,
same-origin and cross-origin requests. Real CLI scenarios check streams, status
and jars. Linux pinned-oracle and three-platform CI gates remain required;
editing CI configuration alone does not pass them.

A later cross-origin probe confirmed that Wget retains explicit Cookie while
curl removes it. After correction, netops passed 15/15 on both backends, as did
real network CLI scenarios, release builds and strict all-target checks.
Additional evidence uses `cross-cookie-*` / `*-cross-cookie-*` names; the
initial full records above remain intact. Both Cookie behaviors were added to
the existing Linux pinned-oracle scenario.

## Common-command inventory

At the time there were 48 local commands, 47 published and local-only timeout.
Of 59 explicitly selected missing common commands, 57 had no active plan and
two had been explicitly excluded. The [inventory and tree-first proposal](../../command-coverage.md)
retain counting rules and per-command capability boundaries. Unimplemented
does not mean impossible in pure MoonBit.
