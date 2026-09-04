# Unified command test runner

`cmd-test-runner` is the only black-box test entry point for this repository.
It has three explicit suites:

- `compat` runs the native command contract and boundary tests.
- `policy` runs controlled-security cases against pre-built Wasm artifacts via
  `moonrun --policy`.
- `oracle` runs the strict differential cases against the pinned upstream
  container.

The runner never builds command packages. CI or a developer performs one
native release build and, when policy tests are requested, one Wasm release
build, then passes the artifact roots to the runner. Missing artifacts are a
hard error so a test cannot accidentally validate a stale or implicitly built
binary.

The P2/P3 profile adds strict C-locale differential cases for `grep`, `env`,
`sort`, `uniq`, `wc`, and `head`, plus the retained `tail -F` rejection. The
manifest currently contains 117 semantic cases, including the P5 shell grammar
and status fixtures. Binary/NUL and parser-heavy
checks are grouped in the native suite, while file/cwd/process authorization is
exercised only by the Wasm policy suite.

Validate the manifest without building or starting a command:

```text
moon run --target native tests/runner -- \
  --manifest tests/fixtures/runner/cases.json \
  --validate-only
```

Run the native compatibility suite:

```text
moon run --target native tests/runner -- \
  --manifest tests/fixtures/runner/cases.json \
  --native-root _build/native/release/build \
  --suite compat
```

Run policy checks against Wasm artifacts:

```text
moon run --target native tests/runner -- \
  --manifest tests/fixtures/runner/cases.json \
  --wasm-root _build/wasm/release/build \
  --suite policy
```

The differential suite additionally needs Docker and the image built from
`image/`. HTTP and HTTPS cases use repository-owned local fixtures; no public
network endpoint is part of the contract. `--gnu-diff` and `--stress` are
opt-in extensions of the native compatibility suite.

Package-level MoonBit unit and white-box tests remain next to their packages.
The former `tests/cram`, `tests/compat`, `tests/policy`, and `tests/oracle`
black-box entry points are intentionally not supported.
