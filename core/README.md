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

For standard async I/O, use `stream.ChunkReader` for bounded reads and the
`from_binary` constructors on `RecordReader`, `LineScanner` and `BlockWriter`.
Record views retain their bytes across subsequent reads. The checksum and
gzip codecs accept standard binary readers and writers.

## Packages

| Package | Purpose |
| --- | --- |
| cli | Option parsing and structured argument errors. |
| stream, tempio | Bounded binary reads, record scanning, buffered output and temporary-file I/O. |
| fsops, fswalk, platform | Path/filesystem mechanisms, traversal and host capabilities. |
| bytesearch, bytere | Byte searching and the supported byte-regex engine. |
| textwidth | Incremental UTF-8 decoding, scalar cell widths and horizontal blanks for C.UTF-8. |
| numfmt, quoting | Numeric parsing/formatting and byte/path quoting. |
| checksum, checksum/cli | Digest algorithms and shared checksum command handling. |
| gzipops, gzipops/cli | Gzip streams and shared codec command handling. |
| [netops](netops/README.md) | HTTP transport over standard async TCP and TLS, URL, IDNA and public-suffix mechanisms. |
| time_zone | Timezone selection, TZif/POSIX conversion and local-time validation. |
| process, shell | Standard async child processes, redirection and the supported shell language. |

The generated `pkg.generated.mbti` in each package lists its current public
API. Command-specific argument policy, diagnostics and effects remain in the
owning command; there is no executable `moonx cli/core` entry.

## Notes

Build from source with the MoonBit 1.0 RC1 toolchain.

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
