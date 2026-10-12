# touch

Version **0.2.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Create missing files with `0666 & ~umask`. `-c`/`--no-create` succeeds without
creating a missing file. Existing operands, including with `-c`, fail explicitly:
async 0.22.4 has
no public timestamp setter. The command never writes file contents to fake
timestamp updates. Operands are processed in order; earlier successful creates
remain when a later operand fails.

`-a`, `-m`, `-d`, `-r`, `-t`, and `--time` are recognized but fail before mutation:
the portable API cannot select or assign arbitrary access/modification times.
These public API limits apply to both Native and Wasm; see the
filesystem decision record in [ADR-0004](../../docs/adr/0004-filesystem.md).

The unreleased workspace adds standalone `--version`, which prints the command
name and package version and exits successfully without reading input.
Use `--help` to display usage.
