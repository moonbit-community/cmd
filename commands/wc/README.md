# wc

Count input records and bytes for MoonX.

```sh
moonx cli/wc@0.2.5 [-lwcmL] [--files0-from=FILE] [--total=WHEN] [FILE...]
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
- Multi-counter stdin output uses a minimum field width of seven, including
  regular-file redirection. GNU may derive a smaller width from the input
  descriptor's physical file size, so exact regular-stdin column alignment is
  not supported. The released `moonbitlang/async@0.22.5` API exposes
  [`Input::fd`](https://mooncakes.io/docs/moonbitlang/async/stdio), but no public
  query for that borrowed descriptor's kind and size. Lifting this limitation
  requires a released public metadata API that neither consumes, reopens nor
  closes stdin, followed by regular-file, pipe, empty-input and pre-positioned
  input validation. Named-file widths already use public size metadata.

## Examples

```sh
moonx cli/wc@0.2.5 -l notes.txt
printf 'one two\nthree\n' | moonx cli/wc@0.2.5
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
