# tac

Version **0.1.1** behavior is documented here. The
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
