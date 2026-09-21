# JSON migration and release gate

Date: 2026-09-21. Version: 0.2.0, publication pending the remote gate.

The migration moves 240 independent invocations from compatibility functions
into the existing per-command JSON catalog. Exact duplicate contracts execute
once with old IDs retained as aliases. `assertion-map.json` maps every migrated
ID to its canonical case; `text-map.md` explains the text and failure effects.

The remaining nine compatibility groups cover catalog structure, environment
inheritance across commands, streaming round trips, parent/child command
composition, sleep cancellation, live tail follow, HTTP, HTTPS and proxies.
These need MoonBit functions. Independent catalog/help, stdin, shell, text,
filesystem and merge calls no longer have parallel assertion implementations.

| Old function / assertions | Retained IDs | Backends and observations |
| --- | --- | --- |
| catalog smoke and option boundaries | `compat-catalog-line-N` (original starting lines) | Native/Wasm; argv, bytes/status/diagnostic; all 48 commands have cases |
| redirected stdin prompt checks | `compat-stdin-COMMAND` | Native/Wasm; exact stdout, empty stderr and status |
| shell constructs and parser error | `compat-shell-line-N`, `compat-shell-array-boundary` | Native/Wasm; exact result, parser diagnostic and no internal error names |
| file copy / rename | `compat-filesystem-copy`, `compat-filesystem-rename` | Native/Wasm; status, streams, source/destination bytes/type/presence |
| recursive self-copy / current-directory removal | `compat-filesystem-nested-copy`, `compat-filesystem-rm-current-directory` | Native/Wasm; rejection and retained data |
| dash operand / recursive link removal | `compat-filesystem-rm-dash`, `compat-filesystem-remove-link` | Native/Wasm; parsing, deleted path, retained target; link case POSIX only |
| symbolic link creation / Windows capability boundary | `compat-filesystem-symbolic-link`, `compat-filesystem-windows-*-boundary` | Native/Wasm; target relation or explicit preserved-state rejection |
| comm/join/paste incremental merge | `compat-merge-*` | Native/Wasm; same fixtures and full output/status |
| non-following tail and invalid interval calls | `compat-tail-*` | Native/Wasm; input/output/status and diagnostic |
| 65,537-byte tr squeeze | `compat-chunk-squeeze` | Native/Wasm; full input, output and status |

The new JSON effect schema checks files explicitly, keeps binary data in hex,
and permits cwd and text substitutions without introducing a test language.
Runner regression tests reject missing/changed files, incorrect types,
unasserted metadata and lost unordered-output multiplicity. Boundary cases with
declared nonzero statuses check that exact status and every declared assertion.

Local package tests passed Native 155/155 and Wasm 126/126. The full portable
contract run passed 292 semantic contracts per backend; boundary and platform
skip counts remain separate in the copied JSONL reports. The nine retained
Native groups passed. A migration path typo was repaired without changing its
126 exit expectation. The shell stdin-name contract exposed `.wasm` in `$0`;
the implementation now treats `.wasm` consistently with its existing `.exe`
rule, with the choice recorded in ADR-0007.

The candidate release selector validates 47 packages and 380 cases; timeout
remains the documented local-only command. The previous 0.1.x manifest and
frozen base are preserved. Publication requires the new commit's Linux,
macOS and Windows checks, followed by core-first sequential publication and
exact 0.2.0 MoonX acceptance. Remote and publication results are added after
actual completion, not inferred from workflow configuration.

CI pins the validated 0.10.13+cbb11c36f binaries and core. The official manifest
now advertises 0.10.14; the separately documented pin prevents acceptance
variables from drifting. Case duration fields are actual invocation times;
there is no claimed build-time reduction from incomparable old measurements.

The first remote run, [35571034120](https://github.com/moonbit-community/cmd/actions/runs/35571034120),
found a Windows-only `rm` operand bug in both package backends: final `..`
was not detected after input slashes had become backslashes. The fix recognizes
both Windows separators while preserving literal POSIX backslashes. The same
test now explicitly covers both Windows forms and POSIX preservation; local
fsops tests pass 18/18 on each backend. This run is not a passing release gate.

The Linux fixed oracle found three command corrections: curl 8.22 joins literal
cookie operands with semicolon-space (the older macOS curl observation lacked
the space); GNU `ls -LF` retains `@` when dereferencing a dangling directory
entry fails; jq 1.8.2's invalid-argjson diagnostic includes help guidance. These
change implementation and exact expectations together with the oracle evidence.
The jq stderr was also compared byte-for-byte with the downloaded official
macOS jq 1.8.2 executable. Native/Wasm local network scenarios pass after the
cookie correction.

Driver corrections keep candidate-only boundary statuses out of the oracle
suite unless explicitly selected, run Linux containers under the fixture
owner's uid/gid so 0700 outputs can be observed, and normalize declared Windows
separators before substituting a fixture prefix. The latter fixes two Windows
contracts whose raw output was correct; their exact suffixes remain checked.
These corrections retain all semantic assertions and distinguish verifier
failures from product failures.

Run [35573226232](https://github.com/moonbit-community/cmd/actions/runs/35573226232)
passed macOS and both Windows contract backends, but exposed a Windows
interactive startup path error and a lifecycle cleanup stall. ENV now has
scalar expansion, and pipe handles outlive cancellation of their reader tasks.
The lifecycle scenario saves phase progress and CI bounds each scenario step.
The same run found that pinned curl 8.22.0 also removes literal `-b` cookies
on a cross-host redirect; the implementation and contract now follow it.
These changes require a new passing remote gate.

That run subsequently completed all Windows and macOS checks successfully,
including Native/Wasm continuous-input and cancellation scenarios. Linux
completed its portable suites, then the fixed GNU Wget 1.25.0 oracle exposed
the next network mismatch: explicit preemptive credentials apply across the
redirect destination. The shared transport now exposes command-specific Basic
credential scope, and network oracle comparisons retain all independent
round mismatches in one report with the exact request arguments and streams.
This is a product correction, not a reclassification of the failing case.
