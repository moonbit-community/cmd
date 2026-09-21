# Text/data MoonX audit, 2026-09-19

Current checkout audited read-only: `/Users/winter/Documents/Moonbit/cmd`, HEAD `8b79e9bfd43c4d57ac615959cf21bf9e6c4c2668`.
All candidates were real unpinned `moonx cli/<command> ...` invocations, default Wasm.
`versions.txt` records verbose resolver output: jqlog resolved to 0.1.5; all other 19 commands resolved to 0.1.4. This means the local registry index resolution at this invocation, not an assertion about a newly refreshed registry.

## Counts

- 20 distinct commands, 33 cases: 28 exact byte/status matches, 5 differences.
- Basic cases: 19/20 match; grep differs even in an ordinary `grep -n alpha` case.
- Extra options/boundaries: 9/13 match.
- Four issue families: grep output separator, grep default regex dialect (two failing cases), grep missing `-o`, and base64 `-w 0` trailing newline.
- No product files changed. `git status --short` remained empty.

The tests compare stdout bytes and exit code, require empty stderr for these successful/no-match inputs, and retain candidate stdout, stderr, per-case JSON, and native oracle stdout/stderr. Except explicitly named byte contracts, the oracle is the local macOS utility under `LC_ALL=C`, not a pinned GNU/Linux oracle. This is not full utility compatibility certification.

## Findings

### grep inserts context separators without context options

Reproduce: `printf 'alpha\nbeta\nalpha2\n' | moonx cli/grep -n alpha`

Actual stdout: `1:alpha\n--\n3:alpha2\n`; status 0, empty stderr.
Local grep: `1:alpha\n3:alpha2\n`; status 0, empty stderr.

Source: `commands/grep/main.mbt:386-388` unconditionally emits `--` between separated selected record ranges; no check that context is active. This is a direct output behavior bug, independent of policy.

Evidence: `grep-basic.json`, `grep-basic.stdout`, `grep-basic.oracle.stdout`.

### grep defaults to extended-like regex instead of basic regex

Reproduce: `printf 'aaa\na+\n' | moonx cli/grep 'a+'`

Actual stdout: `aaa\na+\n`; native grep: `a+\n`. Both status 0, empty stderr.

Second reproduction: `printf 'ab\na(b)\n' | moonx cli/grep 'a\(b\)'`

Actual stdout: `a(b)\n`; native grep: `ab\n`. Both status 0, empty stderr.

Source: `commands/grep/main.mbt:179-196` passes nonfixed patterns directly to one `Regex` engine; `main.mbt:492-493` only differentiates fixed strings from all nonfixed modes. Default BRE and `-E` do not get distinct translation.

Evidence: `grep-basic-regex-plus.json`, `grep-basic-regex-group.json` and corresponding stdout/oracle files.

### grep -o is absent

Reproduce: `printf 'ab ac\n' | moonx cli/grep -o 'a.'`

Actual: empty stdout, stderr `grep: unknown short option: 'o'\n`, status 2.
Native grep: `ab\nac\n`, empty stderr, status 0.

Source: `commands/grep/main.mbt:413-441` has no only-matching option. This is an unsupported common option, separately classified from the two bugs above; the compatibility table does not explicitly promise `-o`.

### base64 -w 0 retains a newline

Reproduce: `printf hello | moonx cli/base64 -w 0`

Actual hex: `614756736247383d0a` (`aGVsbG8=\n`), status 0, empty stderr.
Expected explicit GNU no-wrap byte contract: `614756736247383d` (`aGVsbG8=`).

Source: `commands/base64/main.mbt:86-87` adds a final newline whenever any output was emitted and column is nonzero; it does not condition the final newline on wrapping being enabled. This particular case uses a stated GNU byte contract, not a local macOS `-w` comparison, because macOS option spelling differs.

## Passing coverage

Basic cases passed for base64 encoding; binary cat (NUL and invalid UTF-8 retained); cmp same-file; comm columns; cut delimiter fields; head/tail line slicing; join keys; jq raw field; jqlog invalid-line skipping plus JSON string output; nl numbering; paste; printf formatting; SHA256 abc known vector; numeric sort; tr translation; uniq counts; wc line count including final incomplete record; and xxd plain hex.

Extra cases passed for cat `-bn -s`, cmp different-file status 1, cut `-b`, grep no-match status 1, head `-n -1`, tail `-n +2`, jq `-e empty` status 4, printf format reuse, and tr class squeezing.

Run all cases with `moon run /tmp/cmd-audit-20260919-text/audit.mbtx`.
