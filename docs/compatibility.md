# Compatibility Contract

This document defines the supported `mooxCLI/cmd` command dialect. It is a
contract for the repository's tests and release gate, not a claim of complete
GNU Coreutils compatibility.

## Dialect

- The baseline is the POSIX command model plus the options recorded in the
  private MoonBit command catalog.
- GNU extensions are supported only when listed by a command's README and
  catalog entry.
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
separate error categories. CLI syntax errors use exit status 2 where the
command has adopted the common parser. Runtime and I/O failures use status 1
unless a command documents another status.

`find`, `test`, `printf`, `sh`, and `make` retain their command-specific
grammars.

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

Every package retains the public coordinate `mooxCLI/cmd/<command>` and
declares native and Wasm targets. The catalog and parser are private packages;
this work does not add a public MoonBit library API.

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
stdin, stdout, and stderr. Environment inheritance is disabled by default. The
Wasm host applies its process policy at the spawn boundary; process groups are
not a policy inheritance or sandbox boundary.

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

## Validation

`tests/compat` is a native MoonBit executable. It starts all 48 release
binaries directly without a shell, compares byte output, normalizes only
diagnostic line endings and temporary paths, and checks edge cases at the
64 KiB chunk boundary. `--gnu-diff` compares the explicitly compatible subset
to GNU tools under `LC_ALL=C` on Linux. `--stress` adds 1, 16, and 64 MiB
single-line inputs plus a million-line case.

`tests/policy` is a native MoonBit executable. It runs Wasm commands under
deny and narrow allow policies, validates catalog admission, and verifies that
denied filesystem operations leave no side effects.

The Markdown Cram files remain compatibility examples and migration
provenance. CI does not execute Markdown or repository shell scripts.

Disk exhaustion and forced partial filesystem writes require harness fault
injection and are not simulated by the normal repository test job.
