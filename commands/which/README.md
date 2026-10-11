# which

Version **0.1.1**. See the [support record](../../docs/compatibility.md) for release evidence.

Find executable files using the caller's `PATH`:

```sh
moonx cli/which sh
moonx cli/which -a sh
moonx cli/which -s ./tool
```

`-a`/`--all` prints all matching executable regular files. Without it,
only the first match is printed. `-s`/`--silent` suppresses both normal
and missing-command output; status is 1 if any operand is missing.
Path operands are checked directly. POSIX requires executable access and
treats backslash as a filename character. Empty PATH entries mean the
current directory.

Windows uses semicolon-separated PATH and PATHEXT (default
`.COM;.EXE;.BAT;.CMD`) to resolve executable suffixes. Files are inspected,
never launched during lookup. Shell aliases and functions are outside
this command's scope. `--help` and `--version` are available.
