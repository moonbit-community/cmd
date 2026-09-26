# cksum for moonx

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Compute the POSIX CRC-32 checksum and byte count:

```sh
printf 'hello' | moonx cli/cksum
moonx cli/cksum input.bin
```

With no operand, or with `-`, standard input is read. Multiple operands are
processed in order; later file failures do not hide earlier results and produce
an eventual nonzero status. `--help` and `--version` are available. GNU
alternate algorithms and tagged output are outside this profile.
