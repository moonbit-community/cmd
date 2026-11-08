# test

Development candidate: `cli/test@0.2.4`. Publication is separate;
[latest.json](../../tests/release/latest.json) records the uploaded coordinates.

Evaluate conditions for MoonX.

```sh
moonx cli/test@0.2.4 EXPRESSION
```

## Supported scope

Evaluate string/integer comparisons and file type, access, size and timestamp predicates. Exit 0 for true, 1 for false and 2 for errors.

Standalone one-through-four-argument rules precede recursive expression
parsing. For example, `test -e` and `test !` test nonempty strings, while
`test -e = -e` compares two literal operands. Standalone `--help` and
`--version` retain the project's metadata contract.

File predicates follow targets except `-L`/`-h`. On POSIX a trailing slash
requires a directory, including through links. `-s` reads target metadata
without opening unreadable files or special files. Ordinary lookup failures
are false; unavailable metadata is an error. `-N` compares modification with
access time. `-nt` is true for an existing left operand and missing right;
`-ot` is true for a missing left operand and existing right. Both missing or
equal timestamps are false. Timestamp nanoseconds are retained.

Unary `-a PATH` is a retained project alias for `-e`, separate from binary
boolean `-a`; GNU coreutils 9.11 does not accept that unary alias.

## Options

| Option | Description |
| --- | --- |
| `-n / -z STRING` | Test nonempty / empty strings. |
| `= / != / -eq / -ne / -gt / -ge / -lt / -le` | Compare strings or integers. |
| `-e / -f / -d / -L / -h / -p / -S / -b / -c` | Test existence or file type. |
| `-r / -w / -x / -s / -N` | Test access, nonempty size or modification since access. |
| `-nt / -ot` | Compare file modification times. |
| `! / -a / -o / ( )` | Negate or combine expressions. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Terminal -t, permission-bit/owner predicates and same-file -ef are unsupported.
- On macOS, unavailable directory-size metadata makes `-s` exit 2, including through a directory link. It is not treated as an empty file.
- Access predicates use public filesystem checks; raw permission bits, ACL equivalence and differing real/effective identities are not established. Integer operands are signed 64-bit decimal, allowing an optional sign and surrounding ASCII whitespace. Leading zeroes remain decimal; radix prefixes, separators and internal whitespace reject. Complete GNU grammar and diagnostic-byte parity are not claimed.

## Examples

```sh
moonx cli/test@0.2.4 -f notes.txt
moonx cli/test@0.2.4 3 -gt 2
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0004-filesystem.md)
