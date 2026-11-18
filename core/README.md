# cli/core

Shared MoonBit libraries for command parsing, byte streams, filesystem access,
HTTP transport and command-language execution.

## Usage

Declare a released cli/core dependency in your module and import the packages
you need. For example, import cli/core/cli as cli:

```moonbit
let options = [@cli.flag("verbose", short='v'), @cli.option("output", short='o')]
let args = @cli.parse(["-v", "-o", "result.txt", "input.txt"], options[:])
assert_eq(args.last_value("output"), Some("result.txt"))
assert_eq(args.operands, ["input.txt"])
```

## Packages

| Package | Purpose |
| --- | --- |
| cli | Option parsing and structured argument errors. |
| stream, tempio | Byte streams and temporary-file I/O. |
| fsops, fswalk, platform | Path/filesystem mechanisms, traversal and host capabilities. |
| bytesearch, bytere | Byte searching and the supported byte-regex engine. |
| numfmt, quoting | Numeric parsing/formatting and byte/path quoting. |
| checksum, checksum/cli | Digest algorithms and shared checksum command handling. |
| gzipops, gzipops/cli | Gzip streams and shared codec command handling. |
| [netops](netops/README.md) | Scoped HTTP transport, URL, IDNA and public-suffix mechanisms. |
| time_zone | Timezone selection, TZif/POSIX conversion and local-time validation. |
| process, shell | Child execution and the supported shell language. |

The generated `pkg.generated.mbti` in each package lists its current public
API. Command-specific argument policy, diagnostics and effects remain in the
owning command; there is no executable `moonx cli/core` entry.

## Notes

Compatible with the MoonBit 2026-11-17 toolchain.

- Product consumers target MoonX/Wasm and use released public MoonBit APIs.
  Host permissions and unavailable filesystem/process metadata remain explicit
  limits; these libraries do not delegate command implementations to host tools.
- Packages support Wasm only, except `platform` and `gzipops`, which also
  support Native for the test runner and benchmark-tool regressions.
- Internal package APIs can differ between releases. Use the interface for your
  selected dependency; command compatibility does not imply a stable internal
  source API.
- For current command support, see the
  [compatibility guide](../docs/compatibility.md). Release history belongs in
  [CHANGELOG](../CHANGELOG.md), and algorithm details in
  [docs/performance](../docs/performance/).
