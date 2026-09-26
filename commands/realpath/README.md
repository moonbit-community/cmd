# realpath

Version **0.1.0** candidate behavior is documented here. The support record separates
workspace verification from published MoonX behavior.

Canonicalize one or more existing path operands using the released public
`async/fs.realpath` API:

```sh
moonx cli/realpath path/to/file
moonx cli/realpath -e path/to/file another/path
```

Supported options are `-e`/`--canonicalize-existing`, `-z`/`--zero`,
`--help`, and `--version`. The command defaults to the existing-only profile,
so `-e` documents and confirms the same strict behavior. Every operand must
resolve successfully; a missing operand path is diagnosed, successful earlier
operands remain on stdout, and the final status is 1. Output is newline
delimited unless `-z` is selected. Invalid or unsupported options exit with
status 2; a missing operand exits with status 1.

The profile does not implement `-m`/`--canonicalize-missing`, relative-base
rewriting, logical-vs-physical selection, or host `realpath` delegation.
Those forms remain outside the strict public MoonBit API subset. The command
does not alter the environment or enforce an authorization policy.
