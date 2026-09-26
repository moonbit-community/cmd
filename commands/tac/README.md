# tac

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Write records in reverse order:

```sh
printf 'one\ntwo\n' | moonx cli/tac
printf 'a--b--' | moonx cli/tac -b -s --
```

`-s`/`--separator` selects a fixed separator and `-b`/`--before` places
separators before records. Standard input or one file is accepted. The
`-r`/`--regex` form and multiple input files are rejected because the released
public APIs do not provide the required byte-oriented regex contract.
