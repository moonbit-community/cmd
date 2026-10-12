# Second command batch release 0.1.0

Date: 2026-10-11

This release publishes the sixteen pure MoonBit command packages completed in
the 2026-10-10 batch. The shared `cli/core` API changed for this batch and was
published first as `0.3.0`. Existing command versions were left unchanged.

The source commit is `008ce12` (`feat: add pure moonbit command batch`). The
required Linux, macOS and Windows checks passed in
[CI run 38091018897](https://github.com/moonbit-community/cmd/actions/runs/38091018897).
The source gate included Native and Wasm builds, workspace contracts and
scenarios, the Wasm policy boundary, and the Linux pinned oracle suite.

The exact registry coordinates were uploaded serially after the source gate:

```text
cli/core@0.3.0
cli/csplit@0.1.0
cli/diff@0.1.0
cli/expr@0.1.0
cli/fmt@0.1.0
cli/fold@0.1.0
cli/gunzip@0.1.0
cli/gzip@0.1.0
cli/hexdump@0.1.0
cli/md5sum@0.1.0
cli/od@0.1.0
cli/patch@0.1.0
cli/sed@0.1.0
cli/sha1sum@0.1.0
cli/sha512sum@0.1.0
cli/split@0.1.0
cli/zcat@0.1.0
```

Each upload returned `Server status: 200 OK`, and a subsequent
`MOON_HOME="$HOME/.moon-accounts/cli" moon view` confirmed the exact immutable
version before the next package was uploaded. `cli/core` was uploaded first;
the command packages followed lexical command-name order. The account used
for the upload was verified with `moon whoami` as `cli`.

The published consumer manifest is
[`tests/release_runner/published-2026-10-10.json`](../../../tests/release_runner/published-2026-10-10.json).
It contains 74 published command coordinates and 534 selected cases. Manifest
validation passed before the consumer run.

Exact MoonX smoke used the Native release runner, which invokes the published
Wasm packages rather than local artifacts:

```text
MOON_HOME="$HOME/.moon-accounts/cli" \
  ./_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe \
  --manifest tests/release_runner/published-2026-10-10.json \
  --suite smoke --report-dir test-reports/published-smoke-20261011
```

The first complete run produced 408 semantic passes, 81 availability passes,
22 verified boundaries and 3 platform skips. Its 20 failures were registry
transport timeouts while downloading newly published Wasm assets, including a
single case that reached the runner deadline during the same transport stall;
no command semantic mismatch was reported. After the package cache was warm,
the affected command selections were replayed serially:

```text
fold md5sum sed split csplit fmt zcat
```

The replay covered all 20 affected case IDs and passed 49 semantic and 5
boundary cases. Combining the original observations with those replacements,
the final unique result for all 534 selected cases is:

```text
428 semantic, 81 availability, 22 boundary, 3 platform skips, 0 failures
```

The replay report is retained at
`test-reports/published-smoke-retry-20261011`; the initial report and raw
stdout/stderr are retained at `test-reports/published-smoke-20261011`.
Availability remains a startup check and does not promote an untested option
to semantic compatibility. Boundary cases remain explicit unsupported-subset
decisions. The command profiles and their remaining limits are recorded in
[`docs/compatibility.md`](../../compatibility.md) and
the current API-boundary entries in [`docs/compatibility.md`](../../compatibility.md).

The earlier `published-0.1.1.json` manifest and its release report remain
frozen for historical replay.
