# grep

Version **0.3.1** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

This version uses core 0.8.2's bounded flat byte DFA and required-literal
rejection for eligible boolean searches. A block filter skips complete records
only when the required literals are absent and inversion/context are disabled;
binary inspection and incomplete tails keep their existing paths. Counting
processes buffered records synchronously. Assertion-free, reference-free span
programs can precompute epsilon closures. Eligible `-o` searches use bounded
reverse/forward automata over byte views to select leftmost-longest spans.
Multiple patterns share fallback text conversion; each eligible pattern retains
a start bitmap for the current record. Span output advances synchronously until
its 64 KiB flush threshold, then resumes the same record. Single-literal counts
locate matching records directly when case/word/whole filters are absent and the
literal cannot cross a record delimiter. Word/whole filters, assertions, references and cache
exhaustion preserve existing matching rules. Cached state is owned by each
compiled record matcher.

Four or more nonempty fixed patterns can share a compiled literal set instead
of searching every pattern separately. Patterns of at least three bytes use
two-byte shifts; repeated failed verification can lazily switch to a byte-class
Aho-Corasick table. Shorter sets start with that table. Each compiled set caches
one construction attempt; budget exhaustion safely retains shifts without
rebuilding on later records. Every later search still starts with shifts so
sparse inputs can skip quickly. Compilation
is bounded by 4096 literal bytes and, for the automaton, 1024 states. Empty or
oversized sets and word/whole filters keep the existing path. Eligible counts
locate a matching record and skip its remaining hits. Long-record regex spans
also reuse proven self-looping suffixes within one immutable record, while
retaining leftmost-longest selection. See [ADR-0003](../../docs/adr/0003-streams.md#adaptive-literal-planner-2026-10-27)
for measured gains, rejected experiments and remaining performance gaps.

Search text using basic regular expressions by default, extended expressions
with `-E`, or fixed strings with `-F`; `-G` restores basic syntax. Options include
`-E`, `-F`, `-G`, `-o`, `-i`, `-v`, `-n`, `-b`, `-c`, `-l`, `-L`, `-q`,
`-H`, `-h`, `-x`, `-w`, `-e`, `-f`, and recursive `-r`. `-A/-B/-C` emit
context with GNU-style selected/context separators, while `-z` switches input
and output records to NUL. Recursive reads accept repeated `--include` and
`--exclude` basename patterns using portable `*` and `?` wildcards. `-R` aliases
the same traversal as `-r`; neither follows symbolic links during recursion.

Binary input defaults to GNU 3.12's `grep: NAME: binary file matches` stderr
notice;
`--binary-files=text` (or `-a`) searches and emits raw records, and
`--binary-files=without-match` skips binary inputs. `-s` suppresses file-read
diagnostics without hiding status 2. Matching, offsets, and record boundaries
use a byte-oriented C-locale profile without changing the process environment.
Input and output use bounded blocks. Records within a block are views; retained
storage grows with a cross-block record and requested context, rather than the
entire input. `-q` and `-l` stop reading when their result is determined.
Binary detection applies as chunks arrive, so text already emitted before a
later NUL remains visible. Complete records and a partial final record survive
a later input error; the error still produces status 2.
`-o` emits nonempty, nonoverlapping matches using leftmost-longest selection;
`-b -o` reports the offset of each match. No group separator is emitted without
context options. BRE/ERE patterns are compiled once by the shared C-byte
matcher, including pattern backreferences and directional/ordinary word
assertions. Each `-e` expression retains its own capture numbering. `-i` folds
C-byte literals, classes and backreferences while preserving assertion grammar.
Repeated nullable captures follow the tested GNU candidate and capture-register
selection, including counted repeats and references. See the
[workspace support record](../../docs/compatibility.md#published-matcher-and-sed-profiles).
Locale-sensitive collation and
multibyte case folding are not currently implemented. Exit statuses are 0 for a selected
line/file, 1 for no selection, and 2 for an error.

## Standalone metadata

Standalone `--version` prints exactly `grep 0.3.1` followed by one
newline. Standalone `--help` starts with `Usage: grep`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
