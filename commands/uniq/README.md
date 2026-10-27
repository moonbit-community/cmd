# uniq

Filter adjacent duplicate records for MoonX.

```sh
moonx cli/uniq@0.2.4 [-cduDiz] [--all-repeated[=METHOD]] [--group[=METHOD]] [-f FIELDS] [-s CHARS] [-w CHARS] [FILE]
```

## Supported scope

Read a file or stdin and compare adjacent records. Sort first for global deduplication; output is written to stdout.

## Options

| Option | Description |
| --- | --- |
| `-c / -d / -u` | Count occurrences / repeated records only / singletons only. |
| `-i` | Ignore ASCII case. |
| `-f, --skip-fields=N / -s, --skip-chars=N` | Skip fields, then bytes before comparing. |
| `-w, --check-chars=N` | Limit compared bytes. |
| `-D, --all-repeated[=METHOD]` | Print all duplicates; none, prepend or separate separators. |
| `--group[=METHOD]` | Print all groups; separate (default), prepend, append or both. |
| `-z, --zero-terminated` | Use NUL-delimited records. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Comparison and case folding use C-byte rules.
- --group conflicts with -c/-d/-D/-u; -c conflicts with -D.

## Examples

```sh
printf 'a\na\nb\n' | moonx cli/uniq@0.2.4 -c
moonx cli/uniq@0.2.4 -d sorted.txt
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
