# Final audit and archival report

- Review date: 2026-09-05
- Scope: generated interfaces, Wasm execution, differential evidence, CI, and
  documentation consistency after P9
- Status: complete

## Generated interfaces

The repository now retains only the compiler-standard `pkg.generated.mbti` in
each tracked package. The stray untracked `pkg.generated 2.mbti` files were
removed. No generated interface was edited by hand; `moon info` remains the
source of truth.

## Local verification

The final audit used fresh release roots so an older artifact could not hide a
source change:

```text
moon check --target all --deny-warn
moon test --target all
moon build --target native --release --deny-warn --target-dir _build/p9-native-verify
moon build --target wasm --release --deny-warn --target-dir _build/p9-wasm-verify
runner --suite compat --gnu-diff
runner --suite policy
runner --validate-only
moon info
git diff --check
```

The package tests passed with Native `100/100` and Wasm `91/91`; JS and
Wasm-GC have no test entry. The fresh native runner reported `compat` success,
including the local GNU differential hook. The fresh Wasm root passed the
policy suite and the direct P9 smoke described in the P9 report. Docker is not
installed locally, so the pinned upstream container remains a remote-only
oracle gate.

## Remote cross-platform reconciliation

The final remote run for the P9 delivery passed all applicable jobs:

- Ubuntu 24.04: check, tests, Native/Wasm release builds, compatibility,
  GNU differential, policy, generated interfaces, and format;
- macOS 15: the same cross-platform checks (GNU differential is correctly
  skipped outside Linux);
- Windows 2025: check, tests, both release targets, compatibility, policy,
  generated interfaces, and format;
- pinned upstream oracle: manifest validation, pinned image, and all oracle
  comparisons;
- scheduled stress: skipped because the run was not a scheduled/manual stress
  invocation.

The archival documentation-only follow-up was also checked by the same matrix.
The authoritative final run is
[33964497821](https://github.com/moonbit-community/cmd/actions/runs/33964497821)
for commit `5f3429a`.

## Documentation consistency

The support record and package READMEs were compared against the actual command
sources and test evidence. They now use `subset verified` for bounded measured
profiles, `restricted` where Wasm policy is part of the contract, and explicit
boundaries for unsupported options. Historical execution details moved to this
directory; no live document is allowed to duplicate the support matrix.

The final architecture remains the nine canonical ADRs. Reports link to ADRs
for decisions and avoid restating them as new policy. The old phase plan was
deleted only after its stage ledger and evidence were preserved here.
