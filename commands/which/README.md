# which

Version **0.1.0** behavior is documented here. The
[support record](../../docs/compatibility.md) separates local verification from
published MoonX behavior; `moonx` examples use registry releases.

Resolve command names against the caller's `PATH`:

```sh
moonx cli/which sh
moonx cli/which -a sh
```

`-a`/`--all` prints every matching regular file, and `-s`/`--silent` suppresses
output while retaining the status. An operand containing a path separator is
checked directly. This release checks regular-file presence, so it can report
a non-executable file as a match. That is a known fidelity defect: public
`can_execute` is available on POSIX and needs to be integrated. Windows
executable lookup, shell aliases and functions are not claimed. See the
[follow-up record](../../docs/command-followups.md) for the correction scope.
