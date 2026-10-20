# tac

Version **0.1.3** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write records in reverse order:

```sh
printf 'one\ntwo\n' | moonx cli/tac
printf 'a--b--' | moonx cli/tac -b -s --
```

`-s`/`--separator` selects a fixed separator and `-b`/`--before` places
separators before records. Standard input or one file is accepted. The
`-r`/`--regex` form and multiple input files are not implemented and are
rejected. These are command implementation gaps; multiple-file reading is
available, and a byte-oriented matcher can be implemented in MoonBit.

## Standalone metadata

Standalone `--version` prints exactly `tac 0.1.3` followed by one
newline. Standalone `--help` starts with `Usage: tac`, lists both
metadata options, and ends with a newline. Both write to stdout, leave stdin
unread, and exit with status 0. Exact-version publication and verification
remain recorded separately in the [support record](../../docs/compatibility.md).
