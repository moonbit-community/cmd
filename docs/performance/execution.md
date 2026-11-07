# Traversal, Batching and Execution

## Find: observe only what the expression needs

[walk_find](../../commands/find/walk.mbt) traverses an explicit stack and derives
metadata requirements from the expression. Each directory visit starts `Unread`;
`names()` transitions to `Read(names)` or `Failed` only when descent or an
evaluated emptiness predicate needs enumeration. The result is reused within
that visit. Short-circuited predicates, pruned directories and depth limits do
not trigger an unnecessary directory read.

A postorder visit creates fresh observation state after child effects, so
emptiness does not reuse the earlier pre-descent listing. Sorted children and
pending paths still occupy memory proportional to traversal state; this is not
constant-memory traversal. Shared [fswalk](../../core/fswalk/) owns directory
handle lifetime and requested metadata, while each command owns ordering and
link policy. Rg's ignore walker retains its separate matching rules.

[FindBatch](../../commands/find/batch.mbt) runs completed `-exec ... +` batches
during traversal instead of retaining all paths until EOF. Its UTF-8 argv-byte
accounting is shared with xargs through [core/process](../../core/process/).
The shared mechanism counts bytes; it does not own either command's grammar,
termination rules or exit aggregation.

## Xargs: one producer and bounded child slots

The current path is [stream input](../../commands/xargs/stream_input.mbt) and
[delimiter parsing](../../commands/xargs/delimited.mbt), then
[BatchReader](../../commands/xargs/batches.mbt), then the
[scheduler](../../commands/xargs/main.mbt).

Tokenization retains only an incomplete item and its parsing state. Complete
literal items decode from borrowed chunk views; spanning items accumulate owned
bytes. BatchReader applies argument, line and UTF-8 byte budgets incrementally
and keeps an overflow group for the next batch. An indivisible oversized group
rejects rather than being silently split. Quote, delimiter, replacement and
end-marker modes retain their own semantics.

The scheduler holds at most the configured number of running children and
reuses each free slot immediately. It does not wait for a whole wave to finish.
Confirmation is serial and uses an independent channel; diagnostics share its
serialized writer. Fatal child outcomes stop production while existing children
finish. Later input failure may follow earlier child effects.

`ChildOutcome` separates ordinary exit from launch failure. Ordinary 126/127
exits contribute aggregate status 123 and allow later batches; actual launch
failures preserve the command's 126/127 behavior. The adapter returns failures
through the scheduler so active children are still awaited. These are
direct-child guarantees, not descendant-tree or exec semantics.

Storage depends on the unfinished item, current/pending batch and active child
arguments. A byte budget does not prove a process RSS bound. Keep process limits
and cancellation semantics in [ADR-0006](../adr/0006-process.md).

## Shell interpretation and make scheduling

[Session.feed](../../core/shell/session.mbt) retains incomplete input, then
[lexer](../../core/shell/lexer.mbt) and [parser](../../core/shell/parser.mbt)
construct executable jobs. Arithmetic/word expansion precedes ordered
redirection opens; [executor](../../core/shell/executor.mbt) applies temporary
assignments and runs builtins or actual child processes. Substitutions copy
context and capture bytes; external stdout/stderr aliases use one process pipe
through [streams](../../core/shell/streams.mbt). Textual captures decode only
after collection, so storage grows with captured output rather than pipe size.
EOF reparses a pending continued line; complete jobs execute once while unfinished
grammar rejects. Reserved words and required compound lists are checked before
the command list runs. External launch errors are classified at the launch call;
unexpected stdout/stderr pump failures keep their error type across task groups
and command substitution and stop later commands. The explicit closed-pipe path
retains its status 141 contract.

Substitution closing candidates are parsed with the same contextual grammar
as scripts, including case patterns and incomplete function headers. This
reparses prefixes and allocates token/AST storage; it is a correctness decision,
not a throughput optimization. An incremental parser may replace it only while
preserving nested substitution, case, quote, comment and here-document cases.
[Printf](../../core/shell/printf.mbt) retains at most an 8192-byte output buffer
between conversions; individual formatted fields can be larger and width/precision
is bounded at 1,000,000. Buffer allocation state is separate from occupancy to
preserve warning order at exact boundaries. Empty conversions do not warm it.

Make resolves [secondary prerequisites](../../commands/make/prerequisites.mbt)
before [planning the dependency graph](../../commands/make/scheduler.mbt).
The graph retains target/dependency tasks and schedules each shared target once.
The [recipe adapter](../../commands/make/recipes.mbt) expands every recipe for a
target before executing its first command. Its environment is evaluated lazily
once per target; empty/colon/dry-run lines avoid export side effects. These phases
hold a mutex; child execution does not. `$?` uses a single pre-recipe snapshot,
including virtual -W timestamps. Fatal variable expansion prevents queued targets
from starting even under `-k`; ordinary recipe failures retain keep-going policy.

[Export policy](../../commands/make/exports.mbt) separates explicit decisions,
initial environment/command-line origin and default export. Shell-valued recursive
exports use the original environment; names are snapshotted before evaluation
because `.SHELLSTATUS` can mutate the variable map. Make's private
[argument construction](../../commands/make/shell_source.mbt) evaluates selectors
before constructing an environment and preserves GNU's direct-argv versus shell
handling of LF and continuation. It retains O(source plus argv bytes), and quoted
argv is interpreted by the pure MoonBit shell. No-command calls skip the
environment entirely. [Capture](../../commands/make/shell_capture.mbt) retains
stdout bytes, truncates at the first NUL and decodes only that prefix; its storage
still grows with total captured output. Actual shell-language errors retain their
status and prior output, while nonlanguage transfer errors propagate.
The [FIFO jobserver](../../commands/make/jobserver.mbt) has one implicit slot and
borrows exact bytes for additional work. A mutex admits one reader at a time;
racing implicit-slot acquisition prevents waiting forever for a token after a
local task completes. Both completed acquisitions are accounted for before
execution. Token cleanup is protected from cancellation and never retries a
possibly submitted failed return.

These changes have correctness receipts rather than performance acceptance.
The common [case registry](../../tests/cases/index.json) binds shell sessions,
merged streams, printf boundaries, recursive make and real FIFO observations.
The Linux GNU-server bridge proves protocol interoperability through shared FIFO
authentication, not an operating-system parent relationship. Definitions and
ready/ack timing observations do not establish throughput or constant-memory use.

## Copy and filesystem operations

Cp reuses [fsops](../../core/fsops/) preflight and exclusive-copy mechanisms with
a reusable 64 KiB block. Capability checks and ordered prompt/update effects
precede mutation where required. Existing-file overwrite, preservation, alias
identity and cross-device move remain the explicit
[filesystem boundaries](../adr/0004-filesystem.md).

The historical 128/256 KiB copy-buffer trials did not qualify all controls;
a reader-owned-buffer trial changed too many artifacts without full coverage.
No larger buffer is adopted solely because one large-file median improves.
Reopen this work only with a measured bottleneck and complete small/file/tree
coverage for every changed artifact.

The `c4ea779` cumulative local macOS run qualifies all three cp rows. Large-file
candidate/baseline cross-window drift is 1.66%/1.26% after temporary/cache cleanup
and ending Storage Management scanning. Earlier identical-artifact A/A and
old/new failures remain failed. This demonstrates a stable later comparison,
not a unique causal diagnosis or a need for another copy algorithm.

Ln and test now have genuine-fixture, startup-inclusive operation rows.
Their latency is not byte throughput. Positive symbolic-link timing requires
host support; missing privilege and rejection tests remain separate.

## Verification routes and remaining uncertainty

Keep independent open-producer, blocked-child/replenishment, fatal interruption,
launch-failure wait, UTF-8 budget, prune/depth and postorder mutation regressions
beside their owning packages and in the common CLI registry. Use `real-find-*`,
`real-xargs-*`, `real-cp-*`, `real-ln-*` and `real-test-*` in the
[single timing inventory](../../tests/benchmark/real.json).

The latest full comparison still fails xargs options stability, despite earlier
scoped passes; its result must not be reclassified as a speedup. Accepted small
UnicodeData costs and their lifecycle rationale remain in
[ADR-0003](../adr/0003-streams.md#known-limits-and-tradeoffs). Future scheduling
work must retain real child/producer synchronization, not infer concurrency
from sleep duration or replace failed windows with unchanged retries.
