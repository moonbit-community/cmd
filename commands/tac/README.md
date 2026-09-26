# tac

The published `cli/tac@0.1.0` package reverses records from standard input or one file and writes
the result byte-for-byte. The default separator is newline. `-s STRING` uses a
fixed UTF-8 separator and `-b` places separators before records.

The `-r`/`--regex` mode is explicitly rejected. Released public MoonBit APIs
do not provide the required byte-oriented regular-expression contract, so the
command does not pretend to support GNU regular separators. Multiple input
files are also rejected in this first implementation.

The support record in `docs/compatibility.md` separates local Native/Wasm
verification from published MoonX behavior.
