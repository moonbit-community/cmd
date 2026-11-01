# grep

Search text patterns for MoonX.

```sh
moonx cli/grep@0.3.3 [-EFGivnclLqHhxwrRbszo] [-A NUM] [-B NUM] [-C NUM] [--include=GLOB] [--exclude=GLOB] [--binary-files=TYPE] [-e PATTERN] [-f FILE] [PATTERN] [FILE...]
```

## Supported scope

Search files or stdin with basic/extended regular expressions or fixed strings, including context, counts and recursive traversal. Exit 0 for a match, 1 for no match and 2 for errors.

## Options

| Option | Description |
| --- | --- |
| `-E / -F / -G` | Extended regex / fixed strings / basic regex (default). |
| `-e PATTERN / -f FILE` | Add patterns directly / from a file. |
| `-i / -v / -x / -w` | Ignore ASCII case / invert / whole record / whole word. |
| `-n / -b / -o` | Show record numbers / byte offsets / nonempty matches. |
| `-c / -l / -L / -q` | Counts / matching filenames / nonmatching filenames / status only. |
| `-H / -h` | Always / never show filenames. |
| `-A N / -B N / -C N` | After / before / surrounding context. |
| `-r / -R` | Recurse without following links. |
| `--include=GLOB / --exclude=GLOB` | Filter recursive basenames using * and ?. |
| `-a / --binary-files=TYPE` | Binary policy: binary, text or without-match. |
| `-s` | Suppress file-read diagnostics. |
| `-z` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Limitations

The local development candidate halves the literal automaton's maximum integer table payload to 1,052,672 bytes. Eligible assertion-free regex searches can also skip proven DFA self-loop bytes in records of at least 256 bytes, with at most eight state-specific SIMD tables per matcher. Short records and expressions with a mandatory literal keep the scalar path. These are algorithmic limits, not a process-memory bound.

Eligible single-pattern regex counts aggregate complete records within each input block. Word/whole-record filters and unsupported expressions retain ordinary matching; DFA exhaustion reprocesses the entire block before any count is committed. Unterminated tails and binary handling keep their existing paths.

- Matching and case folding use C-byte rules; locale collation and multibyte case folding are unsupported.
- Recursive -r and -R do not follow symbolic links.
- Empty-pattern -v -c prints 0; GNU grep 3.12 emits no stdout in that case. Both exit 1.

## Examples

```sh
moonx cli/grep@0.3.3 -n 'TODO' notes.txt
moonx cli/grep@0.3.3 -r -F -e TODO -e FIXME src
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
