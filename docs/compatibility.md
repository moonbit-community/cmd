# Compatibility Contract

The repository-wide migration status is tracked in the
[command compatibility matrix](compatibility-matrix.md), and its external
oracle versions and environment are fixed in
[upstream baselines](upstream-baselines.md). This document remains the
portable runtime and policy contract; it is not evidence that every command
already matches its upstream implementation.

This document records the current interim runtime and policy profile for
`cmd`. It is a contract for repository safety tests, not a claim of complete
upstream compatibility. The required end state, pinned baselines, and work
order are defined by the [upstream compatibility matrix](compatibility-matrix.md),
[spike](spikes/2026-09-02-pure-moonbit-command-compatibility.md), and
[ADR 0001](adr/0001-upstream-compatible-command-migration.md).

## Current Interim Profile

- The current implementation exposes the options recorded in the MoonBit
  command catalog. This is an implementation inventory, not the final upstream
  option contract.
- GNU/POSIX extensions remain incomplete until their matrix rows pass the
  pinned oracle cases.
- Text classification and ordering use C-locale ASCII rules. Commands that
  operate on binary or line data preserve arbitrary bytes, including NUL and
  invalid UTF-8.
- Command output and repository-owned diagnostics use LF. CRLF input is
  accepted as bytes; line-oriented commands split on LF and retain CR as data
  unless the command documents otherwise.
- `sort` and `jq` intentionally retain whole-input behavior. Resource limits
  for them are imposed by the calling harness.

## Argument grammar

Commands using the common private parser accept:

- `--` to end option parsing;
- a standalone `-` as an operand;
- clustered short flags such as `-av`;
- attached short values such as `-ofile`;
- long values such as `--output=file`;
- repeated options when their option specification allows repetition.

Unknown options, missing values, unexpected flag values, duplicate
non-repeatable options, invalid numeric values, and missing operands are
separate parser categories. Rendering and exit status remain command-owned
because the pinned upstream families do not share one universal syntax-error
status. The process layer shares only the established 126 (not invokable) and
127 (not found) launch outcomes used by `env`, `xargs`, and `timeout`.

The common parser contains only generic flag/value token mechanics; every
command supplies its own `OptionSpec` grammar. It covers the ordinary grammar
for 34 commands. `echo`, `env`,
`find`, `jqlog`, `make`, `printf`, `seq`, `sh`, `sleep`, `test`, `timeout`, and
`xargs` retain command-specific grammars because their operands may be
option-shaped, parsing stops at a command or expression boundary, or the
command embeds its own language. `true` and `false` have no option grammar.

## Inventory

The private catalog contains exactly 48 commands.

Core, 32 commands:

```text
base64 basename cat cmp comm cut dirname echo false find grep head join jq
jqlog ls nl paste printenv printf pwd seq sha256sum sleep sort tail test tr
true uniq wc xxd
```

Extended filesystem mutation, 8 commands:

```text
cp ln mkdir mv rm rmdir tee touch
```

Restricted authority, 8 commands:

```text
chmod curl env make sh timeout wget xargs
```

Each command is implemented as a separate executable module under
`cli/<command>` and declares native and Wasm targets. Shared implementation
packages live under `cli/core`, including the catalog and parser used by the
command modules.

Local release builds contain all 48 commands. The Mooncakes registry currently
contains 47 command modules. `timeout` is the only local-only command: its
`ProcessGroupCancellation` compatibility gate prevents publication, and
`moonx cli/timeout` is therefore not a supported invocation.

## Platform behavior

Input paths accept the native separator. Windows also accepts `/` at the
filesystem helper boundary. Generated paths use the native separator.
Normalization covers relative components, roots, Windows drive roots, and UNC
roots. Windows path safety comparisons are case-insensitive.

Recursive copy and removal inspect entries with `follow_symlink=false`.
Copying a symbolic-link source or copying a directory into itself is rejected.
Recursive removal removes a link itself and does not traverse its target.
Removing a filesystem root, the current working directory, or an ancestor of
the current working directory is always rejected.

The portable MoonBit runtime does not expose every native operation:

- symbolic-link creation is an unsupported capability on Windows;
- permission mutation is an unsupported capability on Windows;
- cross-device `rename` does not fall back to copy-and-delete;
- unsupported special-file operations fail instead of being emulated.

Unsupported operations return nonzero status and a diagnostic containing
`unsupported capability`. They do not depend on WSL, MSYS2, Git Bash, a POSIX
shell, or an FFI helper.

## Process boundary

Restricted child processes are described by private MoonBit `ChildSpec` and
`ExecutionContext` values. Each launch explicitly supplies cwd, environment,
stdin, stdout, and stderr. On Native targets the default context copies the
complete parent environment, matching the inheritance expected by `env`, `sh`,
`make`, `xargs`, and their children. `env -i` still starts from an empty map and
then applies requested assignments. On Wasm targets the default context keeps
the explicit execution-variable allowlist and forces `LANG=C` and `LC_ALL=C`;
the Wasm host then applies its process policy at the spawn boundary. Process
groups are not a policy inheritance or sandbox boundary.

MoonBit async runtime `0.21.0` can cancel a direct child PID on Unix and
Windows, but it does not expose a portable process group or Windows Job Object
primitive. `sh`, `make`, and `xargs` require direct-child semantics: they wait
for and reap the directly owned child, preserve its status, and terminate it
when execution is cancelled. Ordinary foreground descendants continue to
receive terminal-generated signals through the inherited foreground process
group. Detached, daemonized, regrouped, or background descendants are not
guaranteed to terminate; process groups would only improve this on a
best-effort basis and would not provide complete containment.

`timeout` differs because the supported GNU-compatible behavior still expects
process-group signalling by default. It therefore retains the
`ProcessGroupCancellation` compatibility gate. This capability denotes
best-effort group signalling, not an inescapable security boundary. This
repository will not add C, C++, shell, or FFI code to bypass the gate. Harness
CPU, memory, wall-clock, process-count, and sandbox enforcement remains outside
the command implementation.

## Streaming and limits

`wc`, `tr`, `base64`, `nl`, `cut`, `uniq`, and `xxd` process bounded byte
chunks. `comm` merges two line streams, `paste` retains one line per input, and
`join` retains only the current equal-key runs needed for its Cartesian
product.

The repository does not impose whole-input limits on `xargs`, `sh`, or
`make`; CPU, memory, wall-clock time, process count, and output volume belong
to the harness. The remaining structural limits are:

- `xargs` keeps one child argv batch below 64 KiB to avoid OS argv failures;
- `make` variable expansion is limited to 64 recursive expansions;
- numeric and formatting commands reject values that exceed their internal
  integer representation;
- user-requested counts such as `head -n`, `xxd -l`, or `find -maxdepth` are
  semantic limits rather than resource guards.

Implicit stdin now blocks silently, including for a terminal, unless the
pinned upstream command itself defines a prompt. Explicit `-` operands,
pipelines, and file redirections are also byte-clean. Dynamic terminal feedback
must opt into the shared terminal policy and is suppressed unless the selected
stream is proven to be a character device.

The Phase 2 `curl` and `wget` HTTP/HTTPS path streams request and response
bodies and resets its inactivity timer after every successful chunk. Wget maps
`-T`/`--timeout`, `--connect-timeout`, and `--read-timeout`; curl maps
`--connect-timeout` and `-m`/`--max-time`. The compatibility slice also keeps
the repository `--idle-timeout SECONDS` spelling as an explicit extension for
inactivity fault injection. That extension is not an upstream compatibility
claim and is catalogued as an extension rather than an upstream option.
Default Wget and curl timing now uses their long upstream defaults instead of
the former repository-wide 30-second default.

Wget follows HTTP redirects by default; curl follows them only with `-L`.
Every hop closes its client, relative `Location` values use the repository's
tested RFC 3986 resolver, loops and limits fail, and authorization, proxy
authorization, and cookie headers are stripped when the origin changes. Both
commands remain `partial` in the matrix until their complete upstream command
surfaces—not only this HTTP/HTTPS slice—pass the pinned oracle.

The native compatibility runner also exercises a pure-MoonBit CONNECT relay
and a repository self-signed TLS fixture. The latter proves default certificate
rejection and the explicit curl `-k`/Wget `--no-check-certificate` opt-outs on
Unix; Windows still receives the all-target compile gate while an equivalent
deterministic TLS-server fixture remains pending there.

## Validation

`tests/compat` is a native MoonBit executable. It starts all 48 local release
binaries directly without a shell, compares byte output, normalizes only
diagnostic line endings and temporary paths, and checks edge cases at the
64 KiB chunk boundary. `--gnu-diff` currently compares only eight commands to
the host GNU tools under `LC_ALL=C`; it is not a complete compatibility gate.
The pinned multi-version oracle runner described in the plan must replace that
subset check. `--stress` adds 1, 16, and 64 MiB
single-line inputs plus a million-line case.

`tests/policy` is a native MoonBit executable. It runs Wasm commands under
deny and narrow allow policies, validates catalog admission, and verifies that
denied filesystem operations leave no side effects.

The Markdown Cram files remain compatibility examples and migration
provenance. CI does not execute Markdown or repository shell scripts.

Disk exhaustion and forced partial filesystem writes require harness fault
injection and are not simulated by the normal repository test job.
