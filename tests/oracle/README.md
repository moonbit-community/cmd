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
Phase 2 HTTP cases start a deterministic MoonBit fixture server on the Linux
host and give only those containers host networking; every other oracle case
keeps `--network none`. `${HTTP_BASE}` manifest arguments are expanded by the
runner, so no test depends on a public website.

The Phase 2 HTTPS cases use the repository's test-only self-signed certificate
and an OpenSSL fixture process on the Linux CI host. OpenSSL is an oracle test
dependency only; no product package invokes it. `${HTTPS_BASE}` is expanded in
the same way as the HTTP fixture address.

The current manifest has 66 cases: four Phase 0 seeds, seventeen Phase 2 HTTP
cases, thirty Phase 3 text/data/path cases, eight Phase 4 filesystem cases, and
seven Phase 5 process/language cases. `jqlog` remains outside the container
suite until its pinned source snapshot is built as the oracle executable.
