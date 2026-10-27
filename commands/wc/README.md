# wc

Count input records and bytes for MoonX.

```sh
moonx cli/wc@0.2.4 [-lwcmL] [--files0-from=FILE] [--total=WHEN] [FILE...]
```

## Supported scope

Read files or stdin and count lines, words and bytes by default. Supports selected counters and aggregate totals.

## Options

| Option | Description |
| --- | --- |
| `-l, --lines` | Count newline bytes. |
| `-w, --words` | Count C-byte words. |
| `-c, --bytes / -m, --chars` | Count bytes; both are identical in this profile. |
| `-L, --max-line-length` | Report maximum C-profile display width. |
| `--files0-from=FILE` | Read NUL-delimited filenames; - selects stdin. |
| `--total=WHEN` | Select auto (default), always, never or only. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Unicode character counting and other locale profiles are unsupported.
- --files0-from cannot be combined with positional files.

## Examples

```sh
moonx cli/wc@0.2.4 -l notes.txt
printf 'one two\nthree\n' | moonx cli/wc@0.2.4
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
