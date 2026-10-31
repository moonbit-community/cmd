# sh

Run shell scripts and sessions for MoonX.

```sh
moonx cli/sh@0.2.4 [-i] [-c SOURCE [NAME [ARG...]] | -s [ARG...] | FILE [ARG...]]
```

## Supported scope

The unreleased workspace accepts option parsing after `-s`, including `--`,
before assigning stdin-script positional parameters. Dedicated exact cases
cover both terminated and unterminated option lists.

Supports quoting, variables/exports, substitutions, pipelines, redirections, conditionals, loops, functions and common builtins. Stdin sessions execute complete commands before EOF.

## Options

| Option | Description |
| --- | --- |
| `-c SOURCE [NAME [ARG...]]` | Execute source text. |
| `FILE [ARG...]` | Execute a script file. |
| `-s [ARG...]` | Read commands from stdin. |
| `-i` | Enable explicit interactive prompts and ENV startup. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- This is a shell subset: no job control, background jobs, fd duplication, backticks, arithmetic assignment/increment/ternary, or full Bash/POSIX compatibility.
- No automatic TTY detection, line editing or recoverable Ctrl-C. exec/fg/bg/jobs/wait are rejected.
- Here-documents support literal bodies; builtin printf supports a smaller format set than cli/printf.

## Examples

```sh
moonx cli/sh@0.2.4 -c 'echo hello'
moonx cli/sh@0.2.4 script.sh
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0007-language.md)
