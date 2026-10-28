# Shared-foundation performance protection

`protection.json` registers shared-boundary invariants and complete-process
release-Wasm workloads. `protect.mbtx` compares **all 80 command artifacts**
against an immutable baseline and refuses a changed command without profiles.
It freezes candidate artifacts, source, SHA-256 identities, toolchain and
registry before running every registered workload. Byte-identical commands
outside the registry need no new timing claim.

Run from the repository root with the current PATH toolchain:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon build --target wasm --release
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/explore.mbtx -- /absolute/new-fixtures unused prepare unused 9
MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/benchmark/protect.mbtx -- /absolute/new-fixtures /absolute/frozen-baseline-cli /absolute/new-evidence
```

The baseline directory contains `<command>/<command>.wasm` for every command.
Build it from a saved source snapshot **before** editing shared production code.
Do not benchmark while builds, tests or other benchmarks are running. Use a new
evidence directory per identified change; never overwrite a failed window.
Fixture preparation requires a new directory, including a new search tree.

Each workload has one warmup and nine alternating old/new pairs in each of two
windows. Every measured invocation includes input, output and exit under the
same 20-second deadline. Exit status, stderr and complete output must match.
There is no MoonX measurement, startup subtraction, sample filtering or automatic
retry. Both sides require MAD/median <=5% in each window and between-window
median difference divided by their mean <=10%. The 5% slowdown review boundary
records the accepted shared-foundation tradeoff; it does not relax stability.
Every row has its own verdict, without averaging away losses.

Compare each adopted phase with its preceding passing phase, then compare the
final candidate cumulatively with the starting artifacts. Report 3–5% losses
individually; reject or revise a qualified loss above 5%. For every recorded
window the declared profile, actual arguments and expected status/diagnostic
must agree. Only the dynamically assigned loopback port of the two local HTTP
fixtures is normalized; raw invocations remain in the reports.

The architecture profiles add local HTTP transfers, shell/make/filter execution,
gzip streams, directory traversal, long rg records at 8/20/32/64 MiB, and
literal-only long-record counting. `ln-symbolic-validation` exercises the
capability/argument failure path and requires its exact diagnostic; it is not
a filesystem throughput claim. Ordinary profiles still require empty stderr.

The timing verdict is only one part of acceptance. Run the Wasm unit/functional
suites, then separately inspect peak RSS and temporary cleanup. This local tool
does not run CI, publish packages or establish upstream parity. Profiles are
representative, not exhaustive tests of every option. Add workloads when a new
fast path or affected command is introduced.

The existing `sort-spill-8m` baseline exceeded the deadline at `-S 1M`. Its failed
artifact remains evidence; it cannot enter the passing old/new timing set.
Validate its repair separately with the same deadline and compare candidate
bytes against default-budget baseline sort. Report that result as a repair,
without an invented speed ratio or a longer acceptance deadline.
