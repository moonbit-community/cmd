# 0.2.0 command fidelity candidate

Date: 2026-09-20. Status at the time: local candidate, unpublished.
Host: macOS 26.5.2 / Darwin arm64. Both Native and Wasm ran on this host;
these results do not certify Linux or Windows. The original
[audit and evidence](2026-09-19-command-fidelity-audit.md) remain historical records.
Language revision: 2026-10-11; results and historical limitations retained.

## Dependencies and implementation

The toolchain was checked against official version.json and remained
moon/moonrun 0.1.20260915 and moonc/core 0.10.13+cbb11c36f. Workspace modules
were aligned to async 0.22.1 and x 0.5.5; moonjq remained 0.1.2.
The [resolved tree](2026-09-20-fidelity-evidence/dependency-tree.json) contained
no old transitive dependencies.

The dependency upgrade was validated separately: Native 104/104 and Wasm 91/91.
The [upgrade patch](2026-09-20-fidelity-evidence/dependency-upgrade.patch)
preserves the state before behavior changes. Under the new cancellation model,
fixture cleanup cancels all children before waiting in an uncancelable region.
All implementation and new automation use MoonBit, with no project C/Rust/JS/FFI
or delegation to host commands. Host ln/stat construct and observe links and
permissions for tests; curl/wget serve only as oracles.

## Actual calls

[Native](2026-09-20-fidelity-evidence/native.jsonl) and
[Wasm](2026-09-20-fidelity-evidence/wasm.jsonl) records contain argv, status,
stdout and stderr. Executable assertions were in `tests/fidelity.mbtx`.

| Original finding | Observed candidate behavior |
| --- | --- |
| cp truncates same-inode aliases | Same path, hard links and existing targets reject nonzero; contents and identity remain intact. Explicit `--no-preserve=mode` copies to a new target. |
| Incorrect new-file cp permissions | Default copying reports the missing mode reader instead of succeeding with incorrect permissions. |
| touch rewrites contents to simulate timestamps | Existing files reject nonzero without changing content/mtime. Creation and missing-file `-c` no-op work; earlier successes survive a later operand failure. |
| Environment filtering and locale rewriting | env children retain arbitrary variables and `LC_ALL=POSIX`; shell-local variables are not automatically exported. |
| grep separators/BRE/-o | No `--` separator without context; BRE is the default; `-Eo 'a|aa'` selects longest `aa`. |
| base64 / seq | `-w0` has no final LF; `seq 3 1` is empty; explicit negative steps still descend. |
| jq single-document parsing / textual --arg replacement | Consecutive JSON, slurp/raw/null/exit and lexical shadowing pass; later parse failure preserves earlier output and returns 4. |
| Shell false success | Arithmetic division by zero returns 2; failed substitution in an assignment returns nonzero; substitution removes only trailing newlines. |
| mkdir/chmod | Under ordinary umask, `mkdir -p -m700` creates parent 755 and leaf 700; command-line symlink chmod affects its target. |
| make shell/-j | shell expansion yields `one two`; overlapping start markers precede completion, shared prerequisites execute once, failed prerequisites prevent dependent targets. |
| Extra rm policy | `--no-preserve-root` works on ordinary temporary files; final dot/dot-dot components still reject according to command semantics. |

Ordinary cp and touch on existing files are explicit reductions in capability,
not complete upstream behavior. Unlock conditions are in
[ADR-0004](../adr/0004-filesystem.md) and [API gaps](../async-upstream-gaps.md).

## Interaction and networking

`commands/sh/interactive_probe.mbtx` keeps stdin open while exercising ENV,
PS1/PS2, variables, multiline input, read, foreground head, syntax recovery and EOF.
[Native](2026-09-20-fidelity-evidence/repl-native.log) and
[Wasm](2026-09-20-fidelity-evidence/repl-wasm.log) passed.
Public Session feed/finish executes complete commands without waiting for EOF.

`core/netops/verify_cli.mbtx` uses a pure MoonBit loopback HTTP fixture. Per backend,
30 calls matched local oracles and one combination was explicitly rejected.
[Native](2026-09-20-fidelity-evidence/network-native.log) and
[Wasm](2026-09-20-fidelity-evidence/network-wasm.log) cover Basic requests, Wget
challenge, cookie duplicates/redirects/load/save, permissions and jar-write
failure. Oracles were Apple curl 8.7.1 and GNU Wget 1.25.0, not Linux curl 8.22.
Curl literal -b cookies cross host boundaries; explicit Cookie headers are
removed across hosts. At this stage, an explicit header plus a matching jar
was rejected before sending because duplicate request fields were believed
unrepresentable through the public Map. Multiple response Set-Cookie fields
were supported through the public cookies array. Later API rechecks supersede
the request-header limitation, not these historical observations.

## Regression and release boundaries

Final workspace results were Native **132/132**, Wasm **119/119**, passing
check/build for both, Native compat and Wasm policy. Network and REPL calls are
separate from unit-test counts; unit passes do not replace differential or
interactive acceptance.

Final outputs are in `check-*.log`, `test-*.log`,
[compat.log](2026-09-20-fidelity-evidence/compat.log) and
[policy.log](2026-09-20-fidelity-evidence/policy.log). Authorization tests use
real external commands for process denial; shell builtin printf is no longer
incorrectly required to have ProcessSpawn. `moon fmt` and `moon info` ran.
Interface changes cover Session/capture, CookieJar/transfer parameters, precise
cp options and platform EXDEV classification. Unused imports identified by the
new compiler were removed; old jq raw tests now use actual input reading.
`moon check --target all --deny-warn` passed, followed by affected-package
Native 15/15 and Wasm 11/11 regressions.

All cli modules were set to 0.2.0. The preparation manifest
`tests/release_runner/candidate-0.2.0.json` has candidate=true/published=false
and permits validation only, not published MoonX execution.
`manifest.json` stays pinned to historical 0.1.x and the frozen
`published-0.1-base.json`; candidate fixture changes do not rewrite that record.
The new-target cp oracle case explicitly uses `--no-preserve=mode`.
Existing-target backup cases retain upstream success versus explicit candidate
rejection with unchanged contents, classified as verified rejection rather than
parity. That Linux oracle path still awaited CI execution.

At this historical stage, uncompared smoke was classified unverified_smoke and
failed the gate; later runner repairs supersede that classification. A command's
nonzero status no longer universally requires an unchanged fixture.
Differential checks compare both streams and final files.

Old published `moonx cli/seq@0.1.5`, `cli/sh@0.1.7` and `cli/env@0.1.4`
were [actually rerun](2026-09-20-fidelity-evidence/published-moonx.jsonl):
automatic descending output, arithmetic failure with status 0 and help status
125 remained. These distinguish candidates from published versions; they do
not constitute candidate release acceptance.

Docker was unavailable locally, so fixed GNU/Linux and Windows checks had not
run. 0.2.0 remained unpublished; exact MoonX acceptance required actual
publication. None of these three outstanding gates was claimed as passed.

## Historical reproduction

Serialize workspace operations to avoid `_build/.moon-lock` conflicts.
For current local execution, prefix every Moon command with
`MOON_HOME="$HOME/.moon-accounts/cli"`; retain the PATH toolchain.
These paths describe the historical layout:

```text
moon check --target native
moon check --target wasm
moon test --target native
moon test --target wasm
moon build --target native --release
moon build --target wasm --release
moon run tests/fidelity.mbtx -- <absolute-root>/_build/native/release/build
moon run tests/fidelity.mbtx -- <absolute-root>/_build/wasm/release/build wasm
moon run commands/sh/interactive_probe.mbtx -- <absolute-root>/_build/native/release/build/cli/sh/sh.exe
moon run commands/sh/interactive_probe.mbtx -- moonrun <absolute-root>/_build/wasm/release/build/cli/sh/sh.wasm --
moon build --target native commands/curl commands/wget
moon build --target wasm commands/curl commands/wget
moon run core/netops/verify_cli.mbtx
CMD_NETWORK_BACKEND=wasm moon run core/netops/verify_cli.mbtx
moon run --target native tests/release_runner -- --manifest tests/release_runner/candidate-0.2.0.json --suite validate
```

The [compatibility table](../compatibility.md), nine canonical ADRs and
[upstream feedback](../async-upstream-gaps.md) define follow-up scope.
Advanced terminals, exec and job control require public APIs; fuller grep,
shell/make syntax and PSL/IDNA are project work, not permanent async limitations.
