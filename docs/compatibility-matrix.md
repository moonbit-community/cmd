# Command Compatibility Matrix

Date: 2026-09-02

This is the authoritative status of the full command inventory. `partial`
means the implementation is useful and tested locally but is not yet proven
equivalent to the upstream baseline. `exception` means a difference is
currently accepted only under the exception gate in
[ADR 0001](adr/0001-upstream-compatible-command-migration.md). No command is
marked `compatible` until its complete declared profile passes the oracle
runner on every applicable target.

The existing `tests/compat` result (`48/48`) is a repository smoke result. Its
`--gnu-diff` mode currently covers only `base64`, `cat`, `cut`, `head`,
`sha256sum`, `sort`, `tail`, and `tr`; it does not certify the rows below.

The target for each external command is the complete behavior documented by
its pinned baseline, not a hand-selected option subset. Work may ship in
measured stages, but the row remains `partial` until the complete target passes
or each remaining difference has passed the ADR exception gate.

## Inventory

| Command | Upstream baseline | Current status | Current spike finding | First compatibility slice |
| --- | --- | --- | --- | --- |
| `base64` | Coreutils 9.11 | partial | Basic encode/decode and wrapping are covered; full option grammar, invalid-input diagnostics, and all binary edge cases are not oracle-covered. | Complete GNU option and error matrix. |
| `basename` | Coreutils 9.11 | partial | Multiple names, suffix, and NUL output exist; all GNU operand and option forms are not compared. | Match operand grammar, `--`, suffix rules, and statuses. |
| `cat` | Coreutils 9.11 | partial | Byte streaming works; the implementation exposes only a small option surface versus GNU formatting flags. | Implement or explicitly reject every GNU option; preserve byte output. |
| `chmod` | Coreutils 9.11 | partial | Numeric modes and recursion exist; symbolic modes, `--reference`, symlink policy, and Windows behavior differ. | Probe pure MoonBit mode/symlink capabilities, then align native semantics. |
| `cmp` | Coreutils 9.11 | partial | Core comparison, silent/list/skip cases exist; GNU diagnostics and complete option forms need oracle coverage. | Compare all documented options and three-way statuses. |
| `comm` | Coreutils 9.11 | partial | Three-column merge and suppression flags exist; ordering checks, diagnostics, and locale cases are not complete. | Match sorted-input handling and byte diagnostics. |
| `cp` | Coreutils 9.11 | partial | Regular files and directory trees work; attributes, links, special files, and several overwrite modes are limited. | Implement common copy modes; spike metadata and link primitives. |
| `curl` | curl 8.22.0 | partial | HTTP(S) GET streaming, output, fail/silent, and idle timeout exist; redirects, headers, methods, uploads, multiple URLs, and curl statuses are incomplete. | Build the HTTP/HTTPS profile before other protocols. |
| `cut` | Coreutils 9.11 | partial | Character/field lists and basic delimiter behavior exist; full byte/character locale and diagnostic behavior need oracle cases. | Match list grammar, `-z`, multibyte, and errors. |
| `dirname` | Coreutils 9.11 | partial | Multiple operands and NUL output exist; complete POSIX/GNU path corner cases need comparison. | Differential-test roots, empty names, `--`, and separators. |
| `echo` | Coreutils 9.11 | partial | Common `-n`, `-e`, and `-E` behavior exists; option ambiguity and escape edge cases need upstream comparison. | Match GNU/POSIX mode selection and byte escapes. |
| `env` | Coreutils 9.11 | partial | Assignment/unset, direct child launch, and Native environment inheritance exist; option grammar, diagnostics, statuses, and Wasm classification remain incomplete. | Complete the environment/status oracle matrix. |
| `false` | Coreutils 9.11 | partial | Trivial status behavior is implemented; only smoke coverage exists. | Verify all argument/help/version forms and diagnostics. |
| `find` | GNU findutils 4.10.0 | partial | Read-only traversal, predicates, depth, and printing exist; `-exec`, `-delete`, links, timestamps, and expression details differ. | Implement and oracle-test the complete predicate/action grammar. |
| `grep` | GNU grep 3.12 | partial | Common regex/fixed, recursive, context, and status behavior exists; regex engine, binary, locale, and all option diagnostics need oracle coverage. | Differential-test pattern/file/locale/binary matrix. |
| `head` | Coreutils 9.11 | partial | Byte/line quotas and multiple-file headers exist; GNU option aliases, `-z`, diagnostics, and all count forms need coverage. | Complete count grammar and output headers. |
| `join` | Coreutils 9.11 | partial | Basic sorted join with selected fields exists; `-a`, `-v`, `-o`, `-e`, locale, and malformed-input behavior differ. | Match the declared join option profile or reject unsupported flags. |
| `jq` | jq 1.8.2 | partial | jq-compatible filters and selected flags exist; full filter language, modules, streaming, and diagnostics are not certified. | Compare the complete option, parser, evaluator, I/O, and status behavior. |
| `jqlog` | Imported `bobzhang/jqlog@0.1.0` snapshot | partial | There is no standard system command named `jqlog`; its original is the imported source at commit `06a529211343c773d30d2c3aa0231a2456665b7a`. | Differential-test the source snapshot and preserve its observable contract. |
| `ln` | Coreutils 9.11 | partial | Symbolic link creation exists on supported platforms; hard links, link metadata, and Windows capabilities are incomplete. | Spike hard-link/readlink APIs before accepting weakening. |
| `ls` | Coreutils 9.11 | partial | Deterministic one-per-line listing, hidden entries, recursion, and indicators exist; long/color/time/ownership formats differ. | Define a portable GNU-compatible output profile and metadata exceptions. |
| `make` | GNU Make 4.4.1 | partial | Dependency graph, variables, timestamps, and policy-visible recipes exist; Make language, includes, job control, built-ins, and diagnostics are incomplete. | Compare the complete documented language and command behavior. |
| `mkdir` | Coreutils 9.11 | partial | Parent creation, numeric mode, and verbose output exist; full mode/umask/error semantics need oracle coverage. | Match creation and permission behavior on native and Wasm. |
| `mv` | Coreutils 9.11 | partial | Atomic same-filesystem rename and common modes exist; cross-device fallback, links, attributes, and all diagnostics differ. | Implement portable common path, then spike `EXDEV`/metadata. |
| `nl` | Coreutils 9.11 | partial | Basic numbering styles, width, separator, and stdin exist; full section/page delimiters and GNU flags differ. | Match numbering grammar and all line classification rules. |
| `paste` | Coreutils 9.11 | partial | Parallel/serial merge and delimiter cycling exist; unlimited inputs, NUL delimiters, and error behavior need full cases. | Differential-test all file/stdin combinations. |
| `printenv` | Coreutils 9.11 | partial | Selected/all variables, NUL records, and Native visibility exist; option/status behavior and Wasm classification need oracle coverage. | Complete environment and option oracle cases. |
| `printf` | Coreutils 9.11 | partial | Broad formatting and escape support exists; exact GNU numeric, locale, invalid-format, and repeated-format behavior needs differential testing. | Use byte-for-byte formatting fixtures. |
| `pwd` | Coreutils 9.11 | partial | Logical/physical modes exist; environment, symlink, and failure semantics need native oracle coverage. | Match `PWD`, `-L`, `-P`, and diagnostics. |
| `rm` | Coreutils 9.11 | partial | Recursive, force, directory, and root protection exist; prompts, link handling, mount boundaries, and all options differ. | Match noninteractive profile; spike unsupported metadata/mount APIs. |
| `rmdir` | Coreutils 9.11 | partial | Empty removal, parents, verbose, and ignore-nonempty exist; complete diagnostics and path corner cases need coverage. | Differential-test parent pruning and failures. |
| `seq` | Coreutils 9.11 | partial | Decimal/exponent sequences, separators, and equal width exist; GNU formatting, invalid values, and locale need oracle comparison. | Match numeric grammar and formatting exactly. |
| `sh` | POSIX.1-2024 `sh` | partial | MoonBit parser/executor handles quoting, expansion, pipelines, redirections, and conditionals; command substitution, here-docs, background/compound forms differ. | Complete the POSIX.1-2024 shell language; do not claim Bash. |
| `sha256sum` | Coreutils 9.11 | partial | Digest, check, binary/text, and NUL output exist; full checksum grammar, warnings, and statuses need oracle coverage. | Match check-file parsing and failure precedence. |
| `sleep` | Coreutils 9.11 | partial | Fractional values and suffixes exist; GNU grammar, overflow, signals, and diagnostics need comparison. | Match duration parsing and cancellation behavior. |
| `sort` | Coreutils 9.11 | partial | Numeric/reverse/key/fold/unique behavior exists; whole-input design and many GNU keys, locale, memory, and temporary-file semantics differ. | Complete declared C-locale profile before external-sort work. |
| `tail` | Coreutils 9.11 | partial | Last/from line/byte and constant-memory reads exist; `-f`, `-F`, follow signals, headers, and diagnostics differ. | Match non-follow profile, then spike follow capability. |
| `tee` | Coreutils 9.11 | partial | Streaming stdout/file copy and append exist; signal handling, multiple-write failures, and status semantics need oracle cases. | Differential-test output failure and append behavior. |
| `test` | Coreutils 9.11 plus POSIX test | partial | String, integer, file, and boolean expressions exist; complete unary/binary operators and ambiguity rules differ. | Build an expression grammar oracle suite. |
| `timeout` | Coreutils 9.11 | exception | Local command only; process-group cancellation is unavailable, so `moonx cli/timeout` is not published. | Keep gated; revisit only after a pure portable primitive spike. |
| `touch` | Coreutils 9.11 | partial | Create/no-create and timestamp update exist; date/reference/access-modification flags and symlink behavior differ. | Match timestamp option grammar and link policy. |
| `tr` | Coreutils 9.11 | partial | Byte translation, delete, squeeze, complement, ranges, and classes exist; sets are limited to Latin-1 and full GNU classes/locale differ. | Complete C-locale byte profile or document a proven exception. |
| `true` | Coreutils 9.11 | partial | Trivial success behavior is implemented; only smoke coverage exists. | Verify all argument/help/version forms and diagnostics. |
| `uniq` | Coreutils 9.11 | partial | Adjacent filtering, counts, repeated/unique, and ignore-case exist; field/character skips, delimiters, locale, and diagnostics differ. | Match complete key-selection profile. |
| `wc` | Coreutils 9.11 | partial | Lines/words/bytes/chars and totals exist; alignment, `-L`, locale, invalid input, and diagnostics differ. | Match formatting and count semantics. |
| `wget` | GNU Wget 1.25.0 | partial | HTTP(S) streaming and basic output/quiet/logging exist; current code does not follow redirects, supports one URL only, and differs in naming, retries, statuses, and options. | Implement Wget HTTP/HTTPS profile and server-error status 8. |
| `xargs` | GNU findutils 4.10.0 | partial | Basic tokenization, null mode, max args, batching, and direct child launch exist; quoting, replacements, limits, statuses, and signals differ. | Match token grammar, batching limits, replacement, and child-status precedence. |
| `xxd` | Vim 9.1 `xxd` | partial | Plain/reverse/column/length modes exist; full Vim option grammar, formatting, offsets, and malformed-input behavior need oracle coverage. | Differential-test complete dump/reverse behavior against the pinned image build. |

## Cross-Cutting Findings

Focused probes found incompatibilities that affect more than one row:

| Finding | Affected commands | Required action |
| --- | --- | --- |
| The repository-added `reading standard input; send EOF to finish` message was not emitted by the original commands during an ordinary implicit stdin read. | `base64`, `cat`, `head`, `nl`, `paste`, `sha256sum`, `sh`, `sort`, `tail`, `tee`, `uniq`, `wc`, `xargs`, `xxd` | Resolved in Phase 1: the compatibility path now blocks silently; the old `cli/core` helper is a deprecated no-op. |
| Native child environments were filtered even though `@env.get_env_vars()` is available. | `env`, `printenv`, `sh`, `make`, `xargs` and commands launched by them | Resolved in the Phase 1 foundation: Native inherits ordinary variables; Wasm retains an explicit target-specific policy map. Command-specific statuses remain partial. |
| Option parsing is intentionally small in many packages, so common upstream flags currently fail before semantics are reached. | Most rows; confirmed examples include `cat -n`, `find -exec`, `join -a`, `ls -l`, `touch -r`, `xxd -s`, and `jq --sort-keys` | Generate the option inventory from pinned manuals and require one positive, negative, repetition, and `--` case per option group. |
| Several commands produce useful values but not upstream formatting or diagnostics. | Confirmed for `wc`; expected in `ls`, `seq`, `printf`, `sort`, and error paths throughout | Compare raw stdout/stderr bytes and status separately; no whitespace or diagnostic normalization unless justified by a fixture. |
| Parser/executor subsets reject standard language forms. | `sh` command substitution and here-docs; GNU Make include directives and language features | Treat language grammar and execution as compatibility surfaces, with fixture suites independent of CLI option tests. |
| Runtime APIs expose file bytes, kind, size, times, creation, append, rename, and symlink, but no verified portable hard-link, readlink, owner/group, special-file, or process-group primitive was found. | `chmod`, `cp`, `find`, `ln`, `ls`, `mv`, `rm`, `test`, `timeout`, `touch` | Run the capability spikes in the plan. Missing convenience APIs alone do not qualify as exceptions. |

## Status Rules

- `partial` is the starting state for every existing implementation, even when
  its README describes a useful subset.
- `compatible` requires the command's matrix cases, target profile, and
  side-effect checks to pass. A passing smoke test or a few manual examples is
  not enough.
- `exception` is allowed only after the pure-MoonBit designs and portability
  checks required by the ADR have been recorded. The existing `timeout` row is
  a pre-ADR publication gate and must be revalidated under that process before
  any compatibility release. Every exception must appear in `--help`, the
  command README, and this table.
- `jqlog` is measured against its imported source snapshot rather than a system
  utility. It counts as migrated only when that source contract passes.

## Coverage Gaps To Close First

1. Build the oracle harness and pin all versions and environment values.
2. Expand differential tests from the current eight Coreutils commands to the
   remaining Coreutils rows, then to findutils, grep, Wget, curl, shell, make,
   jq, and xxd.
3. Add local filesystem and HTTP fixture servers so tests do not depend on the
   public network.
4. Run native Linux, macOS, and Windows plus Wasm policy tests before changing
   a row to `compatible`.
