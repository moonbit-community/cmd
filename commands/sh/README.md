# sh

Run shell scripts and sessions for MoonX.

Published: `cli/sh@0.2.8`, using `cli/core@0.9.4`.
Exact-coordinate acceptance and earlier release evidence are recorded in the
[changelog](../../CHANGELOG.md#2026-11-08).

```sh
moonx cli/sh@0.2.8 [-i] [-c SOURCE [NAME [ARG...]] | -s [ARG...] | FILE [ARG...]]
```

## Supported scope

Unmatched reserved words, missing logical operands and empty required compound
lists report syntax errors before that command list executes. Quoted words and
arguments remain ordinary text; empty case arms and an empty script are valid.
At EOF, a complete continued command executes; unfinished quotes or compound
syntax still reject with their specific parse error. Unexpected child stdout/stderr transfer errors propagate
without replaying writes or executing subsequent commands; closed pipes retain
the existing status 141 contract. Launch failures identify
the command and use status 127 for missing commands or 126 for other OS errors.

This version accepts option parsing after `-s`, including `--`,
before assigning stdin-script positional parameters. Dedicated exact cases
cover both terminated and unterminated option lists.

Supports quoting, variables/exports, substitutions, pipelines, redirections, conditionals, loops, functions and common builtins. Stdin sessions execute complete commands before EOF.

- Arithmetic includes assignments, compound assignments, short-circuit logic,
  conditional expressions and prefix/postfix increments. Increments are a project
  extension beyond the fixed Dash oracle. Earlier expansion side effects remain
  visible if a later operation fails.
- Backticks and `$()` isolate state, preserve status and trim trailing newlines.
  Nested case/function syntax and fragmented interactive input share the parser.
- Unquoted here-documents expand variables, arithmetic and substitutions without
  field splitting or globbing; quoted delimiters keep literal bodies. `<<-`
  removes leading tabs. Redirection target expansion precedes ordered file opens.
- Stdout/stderr copies such as `2>&1`, `1>&2`, `2<&1` and `1<&2` alias the real
  stream, including external child output. `break`/`continue` support levels.
- Builtin printf supports integer, binary64 floating, string/byte conversions,
  flags, widths/precisions, format reuse and `%b`. Numeric diagnostics preserve
  converted prefixes. Its fixed Linux Dash profile uses an 8192-byte buffer.
  Builtin test supports finite argument-count precedence, checked signed decimal
  integers, strings and available file/access/time predicates. `==` is a project
  extension. Ordinary file lookup errors become false predicates without
  swallowing cancellation. `test -s` follows the final target and queries its
  size without opening it; unavailable target sizes produce status 2.

## Options

| Option | Description |
| --- | --- |
| `-c SOURCE [NAME [ARG...]]` | Execute source text. |
| `FILE [ARG...]` | Execute a script file. |
| `-s [ARG...]` | Read commands from stdin. |
| `-i` | Enable explicit interactive prompts and ENV startup. |
| `--help` / `--version` | Show help / package version. |

## Limitations

File predicates pass paths unchanged to the host filesystem. Ordinary Windows
paths in this profile normalize `component/..` before lookup; POSIX requires the
component to exist as a directory. Windows device paths have separate rules.
The Windows profile has a separate native file observer and CLI regression.
Size predicates first validate the original path before resolving links. These
separate queries do not promise an atomic identity snapshot. The current macOS
public API cannot measure directory sizes; both directories and links to them
therefore produce an explicit size-capability error, including under `!`, `-a`
and `-o`. Linux directory sizes remain supported.
On POSIX, a trailing slash requires a directory even when a host query
permissively returns a regular symlink target.

- This is a finite shell subset; background jobs and complete Bash/POSIX grammar
  are not claimed.
- No automatic TTY detection, line editing or recoverable Ctrl-C. exec/fg/bg/jobs/wait are rejected.
- Descriptor numbers above 2, descriptor closure and access-direction changes
  need public descriptor APIs and reject explicitly. Standard stream aliases do
  not establish arbitrary descriptor inheritance.
- Test identity/ownership/mode-bit/terminal predicates need public metadata or
  terminal APIs and reject. Invalid UTF-8 substitution captures reject; raw
  printf output remains byte-oriented. Width/precision is bounded at 1,000,000.
- GNU printf `%q`, long-double ABI parity and non-C locale behavior are outside
  the builtin profile. Terminal and descriptor unlock conditions are in ADR-0007.

## Examples

```sh
moonx cli/sh@0.2.8 -c 'echo hello'
moonx cli/sh@0.2.8 script.sh
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
