# Command fidelity repair — in progress

Started 2026-10-11 from `f48398d6d7d4ca20d45bce22e107962612513c73`, on
`codex/command-fidelity-repair`. This report is not release acceptance.

The user authorized issue creation, repair, second review, three-platform CI,
serial publication of changed packages and exact-version MoonX acceptance.
Unrelated feature expansion remains deferred. Historical release reports and
published manifests are preserved.

## Issue mapping

| Tracking ID | Issue |
| --- | --- |
| jq conversions / string slices | [#4](https://github.com/moonbit-community/cmd/issues/4) |
| F01 strings | [#5](https://github.com/moonbit-community/cmd/issues/5) |
| F02 which | [#6](https://github.com/moonbit-community/cmd/issues/6) |
| F03 column | [#7](https://github.com/moonbit-community/cmd/issues/7) |
| F04 date | [#8](https://github.com/moonbit-community/cmd/issues/8) |
| F19 unlink | [#9](https://github.com/moonbit-community/cmd/issues/9) |
| F05 filesystem APIs | [#10](https://github.com/moonbit-community/cmd/issues/10) |
| F06 gzip algorithms | [#11](https://github.com/moonbit-community/cmd/issues/11) |
| F07 sed / regex | [#12](https://github.com/moonbit-community/cmd/issues/12) |
| F08 accepted-operation evidence | [#13](https://github.com/moonbit-community/cmd/issues/13) |
| F09 unpublished curl/wget fixes | [#14](https://github.com/moonbit-community/cmd/issues/14) |
| F10 diff/patch | [#15](https://github.com/moonbit-community/cmd/issues/15) |
| F11 sh/make | [#16](https://github.com/moonbit-community/cmd/issues/16) |
| F12 memory / limits | [#17](https://github.com/moonbit-community/cmd/issues/17) |
| F13 common options | [#18](https://github.com/moonbit-community/cmd/issues/18) |
| F14 network / JSON expansion | [#19](https://github.com/moonbit-community/cmd/issues/19) |
| F15 terminal / process APIs | [#20](https://github.com/moonbit-community/cmd/issues/20) |
| F16 locale / platform text | [#21](https://github.com/moonbit-community/cmd/issues/21) |
| F17 diagnostics / extensions | [#22](https://github.com/moonbit-community/cmd/issues/22) |
| F18 missing commands | [#23](https://github.com/moonbit-community/cmd/issues/23) |
| ln/mv second-review errors | [#25](https://github.com/moonbit-community/cmd/issues/25) |

## Working evidence

- Moon/moonrun 0.1.20260920, moonc 0.10.14+7d59c7ec9; async 0.22.4,
  x 0.5.5. Released moonjq 0.2.0 fixes `tostring` and `tojson`, but an isolated
  call still produced null for a string slice. The shared public-AST adapter
  lowers string slicing through Unicode scalar arrays; no host jq delegation.
- Fixed local oracles: coreutils 9.11, binutils 2.44, util-linux 2.40. Binutils
  archive SHA-256: `ce2017e059d63e67ddb9240e9d4ec49c2893605035cd60e92ad53177f4377237`.
  Linux Docker adds strings and column to the pinned oracle image.
- First focused package run: 15 tests passed. First Native CLI run: 92 semantic
  passes, 5 boundary passes, 1 Windows-only skip. These are interim checks.
- Date differential: 35 calls across UTC, Shanghai, New York, Dublin, Lord Howe,
  POSIX DST and fractional-hour zones; epoch fractions and 2038/2050 dates
  matched coreutils 9.11 after preserving GMT abbreviations at zero offset.
- New CLI regressions currently cover strings encoding/radix/TAB/offsets,
  column formatting, which executable access, unlink operand preflight,
  timezone/epoch behavior and jq/jqlog filters. Old incorrect expected outputs
  were corrected against the upstream results; no failed behavior was relabeled
  as a semantic pass.

## Second review and regression scope

The second pass exercised the commands again against independent upstreams,
reviewed all 79 package help/README surfaces, and checked the repair paths and
their failure cases. It found and corrected empty/dot PATH spelling and duplicate
PATH results, zero-offset GMT abbreviation loss, date-only input and generic
internal date errors, and the diff version output. The timezone decoder now
checks both TZif blocks, indices and truncation; the 64-bit test deliberately
uses a conflicting 32-bit compatibility block and a transition after 2038.
Additional pinned comparisons corrected signed-year padding and table ANSI
width accounting. These have explicit portable CLI and package regressions.

Shared JSON regressions include 68 long-option alias contracts across 33
commands and exact byte/status/side-effect assertions for the repaired behavior.
Curl/wget auth, custom Cookie headers, redirect cookies, path/domain matching
and cross-host credentials now have shared HTTP fixture contracts that also run
through release_runner and exact MoonX. Stateful network and shell/lifecycle
scenarios remain additional gates. A stress assertion crosses seq's former
10,000,000-record cap without allocating a second expected-output buffer. The
initial unbuffered seq exceeded the 120-second test deadline; the public 64 KiB
BufferedWriter correction completed the stress suite in 3.139 seconds with all
10,000,001 records and the final output suffix checked.

Local macOS package results: Native **246/246**, Wasm **215/215**, JS and
Wasm-GC **2/2** each. Native and Wasm CLI contracts each produced **592 semantic
passes** in the first complete pass; the final Native/Wasm pass has **594**
semantic passes each with zero failures, including signed-year and ANSI-width
regressions. Boundaries and platform exclusions are separate.
The candidate manifest selects **841** cases across **78** exact command
coordinates. Every current command retains its tests; no old assertion was
deleted to get the repair through.

These figures describe executed subsets and regression paths, not a proof of
every input/option combination or complete GNU/POSIX compatibility. Unimplemented
features remain in issues #10–#23; availability and explicit refusal never count
as semantic parity. Historical 554-case release evidence remains unchanged.

At this initial checkpoint, Linux/macOS/Windows CI, publication and exact MoonX
acceptance were pending. Later gates and uploads are recorded below.

The filesystem follow-up additionally reproduced ln's ignored last `-f` and
mv's same-path false success against coreutils 9.11. These fixes add `ln/mv@0.2.1`
to the release set. Shared contracts exercise overwrite ordering, backup suffixes,
target directories, no-dereference, same-path/update/no-clobber and hard-link
effects. ADR-0004 records the precise equal-time interactive/update identity gate;
that refusal is a boundary result, not an upstream pass.

First remote run `38115930687` passed macOS. Windows exposed invalid-filename
probing of inline POSIX TZ rules; the parser now recognizes that form before
filesystem lookup. Linux exposed the oracle entrypoint overriding fixture TZ
and the runners forwarding host-expanded paths into containers. Both were
corrected while keeping the failing assertions. Two new ls alias cases were
also wrongly marked GNU differential: GNU does not accept those existing project
long spellings, so their local contracts remain while retained `-u/-c` cases
continue to check upstream parity. This run is failure evidence, not a release gate.

The updated candidate passed **613 semantic contracts per backend** locally,
including the 18 added positive filesystem regressions and the new inline DST
timezone case. The equal-time mv case adds one explicit boundary contract.

Reviewing the release path found that `oracle: true` contracts returned before
the oracle comparison. Differential release runs now honor that marker and
require both the contract and pinned comparison; smoke retains golden contracts.
Classification regressions cover smoke, differential and boundary selection.
The release gate will exercise the marked cases through actual MoonX on Linux.

Runs `38117528667` and `38118162089` passed macOS/Windows but exposed two Linux
oracle disagreements: declined ln/mv interactive prompts return 1 in coreutils
9.11. The candidate now distinguishes declines from successful no-clobber skips,
preserves the prompt and files, and continues other operands. Both corrected
contracts and additional EOF variants pass on Native/Wasm (25 selected semantic
passes each). The two HTTPS cases use the fixed certificate fixture on POSIX
hosts and are skipped on Windows, where the native TLS fixture is unavailable.
These failed remote runs remain evidence and are not release acceptance.

At the user's request, all Chinese Markdown prose and the 19 new F-series issue
titles/bodies were translated into English. Issue #25 was already English.
Historical reports retain dates, measurements and limitations, with language
revision notes; a historical erroneous seq/GNU statement is explicitly identified
as superseded. AGENTS.md now requires English documentation and issue content.

## Publication and final acceptance

Source commit `b11ade8fab0a7fb4c95051e051cdafd90515da94` passed [CI 38119870855](https://github.com/moonbit-community/cmd/actions/runs/38119870855) on Linux/macOS/Windows. Final local Native and Wasm contracts each passed **615** semantic cases. The published selection is **841** cases across **78** command coordinates; HTTPS uses the fixed POSIX certificate fixture and is skipped only on Windows.

This repair publishes `cli/core@0.5.0`, `column/date/diff/strings/which@0.1.1`, `unlink@0.1.2`, and `curl/jq/jqlog/ln/mv/seq/wget@0.2.1`. Unchanged commands retain their existing coordinates. Every upload returned `Server status: 200 OK` and exact registry metadata was verified before advancing. Core was first, then commands in lexical order. The first column packaging check stopped before upload because the local registry index lacked the just-published core; `moon update` resolved it, and core was not republished.

All 78 selected command asset caches were moved to a recoverable local backup before published acceptance, forcing fresh downloads. The release runner now starts the fixed HTTPS fixture used by the workspace runner, expands `${HTTPS_BASE}` for candidate and oracle invocations, and records the POSIX-only Windows boundary. Receipts and reports are under `test-reports/fidelity-repair`.

Published-consumer review found that ls link/time source corrections had not been
released in `cli/ls@0.2.0`; five time-order contracts failed. `cli/ls@0.2.1` is
therefore an additional required upload after its three-platform source gate.
Release case directories now append a case-sensitive ID encoding, preventing
`strings -e b/B` and `-e l/L` evidence from colliding on case-insensitive hosts.
Both TLS contracts passed locally on Native, Wasm and exact published curl/wget.
The new 841-case selection remains subject to full final MoonX acceptance.
