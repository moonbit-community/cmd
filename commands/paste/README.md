# paste for moonx

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Merge corresponding lines of files:

```sh
moonx cli/paste -d, nums.txt letters.txt
moonx cli/paste -s -d, nums.txt   # serial: one output line per file
```

Options: `-d LIST` delimiter characters cycled between columns (default
TAB; `\b`, `\f`, `\n`, `\r`, `\t`, `\v`, `\0` for empty, and `\\` are
understood), `-s` serial
mode, and `-z` for NUL-delimited input and output records. Repeated `-`
operands consume successive records from the same stdin stream. An empty delimiter list selects one empty delimiter, while
a trailing unescaped backslash is rejected before any input is consumed.
Delimiter cycling is over raw bytes, matching `LC_ALL=C`.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.

## Standalone metadata

Standalone `--version` prints exactly `paste 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: paste`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
