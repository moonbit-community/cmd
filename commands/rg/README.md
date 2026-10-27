# rg

Search files recursively for MoonX.

```sh
moon run --target wasm --release commands/rg -- [OPTIONS] PATTERN PATH...
```

## Supported scope

Search explicit paths or stdin (-), with regex/Unicode matching, glob/ignore rules, encodings, context, replacement, counts, multiline and JSON output. --files lists paths.

## Options

| Option | Description |
| --- | --- |
| `-e PATTERN / -f FILE / -F` | Add patterns / read patterns / fixed-string search. |
| `-i / -s / -S` | Ignore case / respect case / smart case. |
| `-w / -x / -v` | Whole word / whole line / inverted matches. |
| `-n / -N / --column / -b` | Line numbers / no line numbers / columns / byte offsets. |
| `-A N / -B N / -C N` | After / before / surrounding context. |
| `-o / -r TEXT` | Only matches / replace matched text. |
| `-c / --count-matches / -l / --files-without-match` | Count lines / count matches / matching paths / nonmatching paths. |
| `-g GLOB / --iglob GLOB / --hidden / --no-ignore` | Filter paths and control hidden/ignored entries. |
| `-t TYPE / -T TYPE / --type-list` | Include / exclude file types / list types. |
| `-L / --max-depth=N` | Follow links / limit traversal depth. |
| `-a / --binary / -0 / --null-data` | Text / binary search / NUL path separators / NUL records. |
| `-U / --multiline-dotall / --encoding=NAME` | Multiline patterns / dot across lines / input encoding. |
| `--json / --files / --sort=KEY / --sortr=KEY` | JSON / list files / ascending or descending sorting. |
| `--color=WHEN / --heading / -H / -h` | Color / headings / include or suppress path labels. |
| `--pre=COMMAND / --pre-glob=GLOB` | Run an explicit preprocessor / select its inputs. |
| `-q / --no-messages / --stats` | Quiet / suppress diagnostics / statistics. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Search requires explicit paths or -; no-path searches are rejected. --files can default to the current directory.
- Compressed search (-z/--search-zip), PCRE2, --one-file-system and creation-time sorting are unsupported.
- Automatic terminal color/headings are off. Raw non-UTF-8 paths and redirected-output same-file exclusion are unsupported.
- Multiline and sorted modes may retain whole input or path lists.
- Unpublished candidate: excluded from this release. Examples run from the repository; no MoonX registry invocation is available.

## Examples

```sh
moon run --target wasm --release commands/rg -- -n 'pattern' notes.txt
moon run --target wasm --release commands/rg -- --hidden -g '*.mbt' 'pattern' .
moon run --target wasm --release commands/rg -- --files --sort path
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md)
