# Paused release and test-system closeout

Paused at the user's request on 2026-10-15. No package was uploaded and no
product version was changed during this session. Publication is authorized,
but the release gates below remain mandatory. Parallel agents are stopped.

## Saved source

- Repository: `/Users/winter/Documents/Moonbit/cmd`.
- Branch: `codex/test-system-closeout`.
- Last committed and pushed revision: `bd359d10c6f2aa4d530ea423a7b25733600ae27d`.
- Four tracked files remain modified: the CI workflow, test-system closeout
  report, lifecycle registry and lifecycle tests. The registry inventory and
  this handoff are new files. These changes are intentionally uncommitted.
- All earlier harness repairs are committed. Local diagnostics remain in
  `_build/verification/2026-10-14-closeout/`.

## Latest verification

[CI run 38711916498](https://github.com/moonbit-community/cmd/actions/runs/38711916498)
was still running when work stopped. macOS and Windows passed the package-test
stage (389 Native, 217 Wasm, two JavaScript and two WasmGC tests). Linux failed
one HTTP cleanup test; independent checks continued. This run is not final
acceptance. The already-dispatched CI was left running; no monitoring automation
was created.

The HTTP test now observes LISTEN ownership with a positive control and a real
HTTP request, followed by joined cleanup and an empty listener table. POSIX uses
`lsof -t`; Windows uses `Get-NetTCPConnection`. Missing observers and malformed
output fail. The first local implementation failed because `lsof -Fp` also emits
file-descriptor records; it was corrected to `-t`, but **the final correction has
not been compiled or tested**. The earlier all-target check passed before that
correction. Registry refresh, final info/format, focused tests and fresh CI are
still required. The workflow now installs/checks the POSIX observer explicitly.

## Publication decision and remaining work

The user confirmed that old packages, including `sh@0.2.0`, lack the unified
metadata behavior and authorized publication of the upgraded packages. Local
`moon whoami` with the required CLI account returned `Logged in as cli`.

Inventory work found changes affecting all 78 published commands. Shared core
also changed: the public gzip runner gained a parameter, checksum metadata
output changed, and the catalog exposes help/version. The proposed core version
is `0.6.0`; command versions should use the next unused patch coordinate. Public
registry observations are retained in `registry-inventory.json`; verify them
again before upload. Several commands still pin old core coordinates. Refresh
existing core dependencies to the new core, preserving commands that do not
depend on core. `timeout` remains local-only.

1. Finish and validate the pending listener observer repair; refresh registry.
2. Complete the per-package archive/source and version inventory. Update source
   versions, dependency pins, command documentation, compatibility record and
   generated candidate together. Keep historical manifests immutable.
3. Add exact standalone help/version published-contract cases for all 78
   commands. Existing workspace metadata probes do not prove published behavior;
   current selected JSON cases cover only part of the command set. The proposed
   generation helper was not completed. Preserve exact status/stdout/stderr;
   do not claim unread stdin from the existing closed-pipe runner.
4. Generate a command-by-command coverage declaration for the actual source
   changes, including core impact. Commit, collect clean exact-revision evidence
   and use `tests/coverage/push.mbtx` for the audited push. A larger test count
   alone does not pass this gate.
5. Require fresh Linux/macOS/Windows CI success, including Linux's sealed Docker
   oracle. Then publish core first and changed commands in lexical order, one
   at a time. Every upload needs `Server status: 200 OK` and exact registry
   verification before continuing.
6. Run exact MoonX smoke and semantic checks, freeze the published snapshot with
   verified receipts and evidence, update the release report and AGENTS baseline,
   then commit and push the records. No publication or closure claim is valid
   before these steps complete.

All local Moon and MoonX invocations must inherit
`MOON_HOME="$HOME/.moon-accounts/cli"` and keep the current PATH toolchain.
Serialize Moon commands. Agent-authored automation must remain pure MoonBit.
