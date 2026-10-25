# touch

Version **0.2.2** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Create missing files with `0666 & ~umask`. `-c`/`--no-create` succeeds without
creating a missing file. Existing operands, including with `-c`, fail explicitly:
async 0.22.5 has
no public timestamp setter. The command never writes file contents to fake
timestamp updates. Operands are processed in order; earlier successful creates
remain when a later operand fails.

`-a`, `-m`, `-d`, `-r`, `-t`, and `--time` are recognized but fail before mutation:
the portable API cannot select or assign arbitrary access/modification times.
These public API limits apply to both Native and Wasm; see the
filesystem decision record in [ADR-0004](../../docs/adr/0004-filesystem.md).

## Standalone metadata

Standalone `--version` prints exactly `touch 0.2.2` followed by one
newline. Standalone `--help` starts with `Usage: touch`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
