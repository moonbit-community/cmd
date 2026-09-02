# Pinned Upstream Oracle

This native MoonBit runner compares release-built command binaries with the
versions built by `image/Dockerfile`. Upstream executables are test-only; no
product package invokes or delegates to them.

The runner validates the machine contract before execution, creates separate
temporary working directories, writes hexadecimal stdin and fixture files,
and compares exit status, raw stdout, raw stderr, and the resulting file tree.
Text normalization is opt-in per field and requires a nonempty justification.

Validate the contract without Docker:

```text
moon run --target native tests/oracle -- \
  --manifest tests/fixtures/oracle/cases.json \
  --validate-only
```

The `pinned-upstream-oracle` CI job builds the image, records its content ID and
all tool versions, then runs the seeded differential cases under `umask 022`.
