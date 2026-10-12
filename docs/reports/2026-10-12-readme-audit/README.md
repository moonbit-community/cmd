# Published MoonX README audit

Date: 2026-10-12

This audit checked the exact published coordinates in
`tests/release_runner/published-2026-10-11-repair.json`. The primary command was
run with the local account environment:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" \
_build/native/release/build/mooxCLI/cmd-tests/release_runner/release_runner.exe \
  --manifest tests/release_runner/published-2026-10-11-repair.json \
  --suite smoke --report-dir /tmp/moonx-audit-2026-10-12 --jobs 1
```

The 78 published packages selected 841 cases: 616 semantic passes, 185
availability passes, 36 explicit boundaries and 4 platform skips. There were
no failed cases. Availability is recorded separately from semantic support and
does not promote an option to the support matrix.

The pure-MoonBit probe in `probe.mbtx` then invoked `--help` and `--version` on
every exact package coordinate and saved raw output under the ignored
`test-reports/readme-audit-2026-10-12/` directory. All packages except `sh`
accepted `--help`; `sh` deliberately reports that the option is unsupported.
Thirty-three packages accepted `--version`; the remaining 45 reject that token.
No package README claims version support for a package that rejects it.

Additional direct MoonX probes covered `mktemp` file and directory creation,
`realpath -e`, byte-oriented `rev` and `tac`, recursive `tree`, bounded `yes`,
`join --check-order`, and `nl -n rz`. Their observed outputs and statuses are
the basis for the corresponding README and support-record wording.

To repeat the help/version probe:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" \
moon run --target native docs/reports/2026-10-12-readme-audit/probe.mbtx
```

This report is evidence for documentation accuracy. It is not a claim of full
GNU/POSIX compatibility or complete coverage of every option.

## Workspace candidate metadata

After the published audit, the workspace added one metadata contract to every
command. The pure-MoonBit regression
`tests/metadata/verify.mbtx` invokes each Native and Wasm command
with `--help` and `--version`, and compares exit status, stderr, final newline,
usage prefix, metadata lines, and the exact package-version token. The
2026-10-12 run passed **79/79** commands on each backend. The version line is
`<command> <package-version>` followed by one newline. This candidate result
does not alter the frozen published-coordinate observations above; it becomes release
evidence only after the corresponding package versions and manifests are
prepared and the exact MoonX consumer checks pass.

The complete local command contract suite subsequently passed with 617 semantic
passes and no failures on each of Native and Wasm. Raw reports are in
`/tmp/cmd-metadata-native-contract-v3` and `/tmp/cmd-metadata-wasm-contract-v3`.
The 21 preserved metadata cases also passed through exact published MoonX
coordinates, with no skips or failures; their raw report is
`/tmp/cmd-published-metadata-replay-2026-10-12`. This verifies historical
replay, not publication of the new workspace output format.
