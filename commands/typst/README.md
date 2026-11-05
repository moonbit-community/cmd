# typst

Compile and inspect Typst documents for MoonX.

Version: `cli/typst@0.1.0`, using `moonbitlang/typst@0.1.10`.
The repository's [release inventory](../../tests/release/latest.json) records
accepted coordinates and their independent expected cases.

```sh
moonx cli/typst@0.1.0 COMMAND [OPTIONS]
```

## Supported scope

Compile `.typ` files to PDF, PNG, SVG, HTML or bundles; watch dependencies and
recompile; evaluate expressions; query document elements; list fonts; inspect
configuration; initialize locally installed templates. Inputs may come from
files or stdin (`-`). PDF/PNG and raw evaluation output support binary stdout.
Exit 0 on success, 2 for invalid CLI syntax and 1 for compilation or I/O failure.

## Options

| Option | Description |
| --- | --- |
| `compile / c` | Compile a document to a file or stdout. |
| `watch / w` | Recompile when document dependencies change. |
| `eval EXPR / query INPUT SELECTOR` | Evaluate code / query document elements. |
| `fonts / info / init TEMPLATE` | List fonts / show configuration / use a local template. |
| `--format=FORMAT` | Select an export or evaluation format. |
| `--root=DIR / --input KEY=VALUE` | Set the project root / document inputs. |
| `--font-path=DIR / --ignore-system-fonts / --ignore-embedded-fonts` | Configure font discovery. |
| `--package-path=DIR / --package-cache-path=DIR` | Configure local package locations. |
| `--pages=RANGES / --ppi=N` | Select pages / set PNG resolution. |
| `--creation-timestamp=SECONDS` | Fix document creation time. |
| `--deps=PATH / --deps-format=FORMAT` | Write document dependencies. |
| `--in=INPUT / --pretty / --field=NAME / --one` | Configure evaluation context or query output. |
| `--no-serve / --no-fullscreen` | Disable the watch server / terminal clearing. |
| `--help` / `--version` | Show help / package version. |

Use `help COMMAND` for the complete options of each subcommand.

## Limitations

- Packages and templates must be installed locally. Network downloads,
  self-update, shell completion generation, viewer opening, performance traces
  and the HTML watch HTTP server are unsupported; HTML watch needs `--no-serve`.
- HTML export requires `--features html`. `query` retains its deprecation warning.
- Compilation is single-threaded; `--jobs` does not start workers. Watch performs
  full recompilations. Files, stdin, font data and exported documents may be
  retained in memory; no bounded-memory or performance claim is made.
- Canonicalization is lexical and file identity is path-based. Symbolic-link
  identity, containment and target replacement detection are not guaranteed.
  Terminal detection is unavailable; local time defaults to UTC.
- The command's version identifies this package, independently of its external
  engine. Raw evaluation output follows the migrated source and is unavailable
  in the official Typst 0.15.1 comparison binary. Focused regression coverage
  does not establish full Rust Typst parity.

## Examples

```sh
moonx cli/typst@0.1.0 compile input.typ output.pdf
moonx cli/typst@0.1.0 compile --ignore-system-fonts --pages=1 input.typ output.svg
moonx cli/typst@0.1.0 watch input.typ output.pdf
moonx cli/typst@0.1.0 eval '1 + 2'
```

The CLI and private kit adaptation derive from `moonbitlang/typst.mbt` at
`5fcffcf09cb1aeed0c00237aaac4a66b4a466c65` (Apache-2.0; see LICENSE and NOTICE).
The typesetting engine remains external. This pure MoonBit Wasm command uses
public MoonBit APIs and does not invoke an installed Typst executable.

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0003-streams.md#typst-command-adaptation)
