# cksum for moonx

`cli/cksum@0.2.0` computes the POSIX CRC-32 checksum and byte count for
standard input or each file operand. Its output is:

```text
CHECKSUM BYTES FILE
```

With no operand, or with `-`, input is read from standard input. Multiple
operands are processed in order; an unreadable operand is reported to stderr,
the remaining operands are still attempted, and the command exits with status
1. The checksum is computed as the CRC-32 polynomial `0x04c11db7` over the
input, followed by the low-order bytes of the input length, and then bitwise
complemented.

`--help` and `--version` are supported. GNU alternate algorithms (`-o`),
tagged output, and other non-POSIX extensions are outside this release and are
rejected as unsupported options with status 2. The implementation is pure
MoonBit and uses public async Reader/File APIs on Native and Wasm.
