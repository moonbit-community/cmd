# Command migration audit based on actual published MoonX behavior

Date: 2026-09-19. Source baseline: 8b79e9bfd43c4d57ac615959cf21bf9e6c4c2668.
Language revision: 2026-10-11; historical results retained.

**Moving authorization to the caller is a sound responsibility change, but
independent semantic defects and feature gaps remain. Removing policy code alone
cannot fix them.** This is a MoonBit command subset, not a general replacement
for existing Unix commands. Reproduced cp data loss has highest urgency,
followed by incorrect successful output and changed environment inheritance.
No product code, published modules or test expectations changed in this audit;
only this report and evidence were added.

## Executed scope

- macOS 26.5.2 / Darwin arm64; moon 0.1.20260915, moonx 0.1.0; default Wasm.
- Existing published smoke: **47 commands, 94 cases, all passed**, using exact
  manifest coordinates.
- **136 targeted candidate calls:** text 33, filesystem 46, network/jq 23,
  process/language/availability 25, explicit policy comparisons 7, seq 2.
  Ordinary calls used moonx cli/<cmd>; one unpublished timeout availability probe
  is included. These counts are not coverage or compatibility percentages.
- After moonx -v cli/echo@latest registry-refresh refreshed the index, all 47
  unversioned coordinates matched the manifest: sh 0.1.7;
  echo/false/jqlog/seq/sleep/true 0.1.5; the other 40 at 0.1.4.
  Actual cached published Wasm assets have recorded SHA-256.
- Only seven policy comparisons supplied policy arguments. Filesystem fixtures
  were isolated and the temporary loopback HTTP server was closed afterward.
- Oracles were mainly macOS tools, plus GNU Wget 1.25.0, Apple jq 1.7.1 and
  curl 8.7.1. Fixed GNU/Linux Docker, Windows, Linux, PTY, long streams and public
  HTTPS were not tested. This is not complete GNU certification.

Evidence: [published results](2026-09-19-command-fidelity-evidence/release/summary.jsonl),
[resolution](2026-09-19-command-fidelity-evidence/process/inventory.jsonl),
[environment](2026-09-19-command-fidelity-evidence/environment.txt),
[asset hashes](2026-09-19-command-fidelity-evidence/assets.sha256).
Source explains published behavior; local builds do not substitute for it.

## Principal observations

| Problem | Call/input | MoonX | Oracle |
| --- | --- | --- | --- |
| **P1: cp clears its source** | Two hard links; cp alias-source.txt alias-dest.txt | **Status 0; both shrink from 17 bytes to zero** | Status 1; both retain 17 bytes |
| Environment inheritance changed | Parent CMD_AUDIT_MARKER=present; env /usr/bin/printenv CMD_AUDIT_MARKER | Status 1, empty; direct cli/printenv prints present | Child prints present, status 0 |
| grep ordinary output | alpha\nbeta\nalpha2\n; grep -n alpha | 1:alpha\n--\n3:alpha2\n, status 0 | 1:alpha\n3:alpha2\n, status 0 |
| grep default regex | aaa\na+\n; grep 'a+' | Both lines, status 0 | BRE matches only a+ |
| jq consecutive values | true\nfalse\n; jq -e . | Empty, status 5; second value fails parsing | Both values, final status 1 |
| jq slurp | 1\n2\n; jq -sc . | Empty, status 5 | [1,2]\n, status 0 |
| jq binding | jq -nr --arg name Moon '"hello \($name)"' | Undefined variable, status 5 | hello Moon\n, status 0 |
| Shell arithmetic false success | sh -c 'printf "%s\n" $((1+2))' | Newline only, process OSError, **status 0** | 3\n, status 0 |
| Shell glob missing | Existing Makefile.*; sh -c 'printf "%s\n" Makefile.*' | Literal Makefile.* | Matching filenames |
| Shell local variables exported | Assign CMD_INNER=private without export; read in child | Child sees private | Child cannot see it |
| make function discarded | Recipe uses $(shell printf computed) | Empty line, status 0 | computed |
| make accepts -j2 but serializes | Independent A sleeps before printing; B prints immediately | AB | Same-host GNU make BA; source discards jobs |
| cp permission mismatch | Source 0640, new destination | 0644 | 0640 |
| mkdir parent mode mismatch | mkdir -p -m 700 created/a | Parent and leaf 0700 | Parent 0755, leaf 0700 |

Evidence: [filesystem log](2026-09-19-command-fidelity-evidence/filesystem/followup.log),
[filesystem records](2026-09-19-command-fidelity-evidence/filesystem/results.jsonl),
[text bytes](2026-09-19-command-fidelity-evidence/text/results.json),
[network/jq](2026-09-19-command-fidelity-evidence/network/results.jsonl),
[jq follow-up](2026-09-19-command-fidelity-evidence/network/followup.jsonl),
[process/language](2026-09-19-command-fidelity-evidence/process/results.jsonl).
Text stdout uses hex; process/network records use JSON escapes.

Initial filesystem/network JSONL appending truncated records. Archived scripts
were corrected and records recovered from independent streams/status or raw
logs without choosing favorable reruns. Filesystem recovery checks are retained.
Process JSONL was similarly recovered from full logs and its script corrected.

## What policy changed

1. Without policy, cli/printenv reads the parent's marker.
2. Under the same conditions, cli/env, cli/sh, cli/xargs, find -exec and make
   recipes lose it. xargs returns 123 and make 2; find can still return 0 after
   an action evaluates false, so find status alone is insufficient.
3. Parent LC_ALL/LANG=en_US.UTF-8 become C/C inside cli/sh.
4. Explicit env.set supplies CMD_AUDIT_MARKER=policy-granted and authorizes
   /usr/bin/printenv. cli/printenv reads it, but cli/env and cli/sh discard it.
   Another explicitly authorized /usr/bin/printf child succeeds.
5. Deny policy causes runtime spawn denial: host authorization and internal
   filtering are distinct mechanisms.

See [seven policy comparisons](2026-09-19-command-fidelity-evidence/process/policy-results.jsonl)
and [allow policy](2026-09-19-command-fidelity-evidence/process/policy-allow.json).
Source agrees: core/process/process.mbt:26 copies a whitelist, line 37 forces
locale, line 52 selects WasmRestricted outside Native and around line 108,
inherit_env=false passes filtered environment to children. This duplicates
caller policy and changes ordinary semantics.

Not every policy identifier is a redundant gate. Restricted/catalog mainly
describes/tests capabilities. Unavailable permission/time/link/readlink
operations in core/platform reflect implementation boundaries. Changing false
to true or granting permission does not implement them. ADR-0002 already said
the harness owns policy; divergence occurred in shared filtering and restricted
language/filesystem contracts. This conclusion does not depend on retaining
the old positioning.

## Declared migration gaps

These operations actually failed independently of authorization:

| Operation | MoonX result |
| --- | --- |
| cp -p / -a | Status 1; portable profile cannot preserve metadata/links |
| cp -P symlink / existing symlink destination | Status 1; link handling rejected |
| ln source hardlink | Status 1; hard links unavailable |
| ls -l / grep -o | Status 2; unknown option |
| chmod u+x,g=u,o-rwx FILE | Status 2; only complete = assignments |
| touch -t / -r | Status 1; timestamp mutation unavailable |
| touch DIR / SYMLINK; chmod 600 SYMLINK | Status 1; native succeeds |
| Shell parameter default ${X:-fallback} / background & | Status 2; ordinary POSIX syntax |
| Shell exec | External executable lookup, status 127 |
| Shell read answer | Variable unchanged; later printf empty |
| curl -u / -b; wget --user/--password / --save-cookies | Parse status 2 |
| moonx cli/env --help | Status 125 |
| moonx cli/timeout 1 /usr/bin/printf ok | Module absent; status 255 |

Many were honest subset limits rather than broken promises, but unchanged
migration still makes them follow-ups. Explicit Authorization and URL userinfo
worked in the same fixture, establishing curl -u as a CLI gap. Consecutive JSON
is jq's basic protocol, not advanced --stream. Documented serial make -j still
lacks upstream concurrency.

base64 -w 0 produced aGVsbG8=\n; this was marked against GNU's no-newline
contract without a local GNU base64 comparison. seq 3 1 descended like macOS
seq; documentation noted the GNU difference. macOS agreement was not counted
as GNU differential success.

## Working subsets and test interpretation

Observed working cases include binary cat; selected basic cut/head/tail/paste/
join/tr/uniq/sort/wc; a sha256sum vector; printf format reuse; basic mv/rm/tee;
numeric chmod, ordinary-file touch and symlink creation; find type/name/boolean/
exec/size/mtime/prune; local curl/wget GET, relative redirects and HTTP statuses;
single-JSON jq map/select/reduce/update/negative indices/to_entries; tested shell
pipelines and $?.

These are useful but do not establish complete command contracts. All 94 smoke
passes do not refute counterexamples: release_runner/main.mbt:403 marks smoke
passed after status and optional strings/newlines, without subsequent oracle
bytes or snapshots. Successful calls do not uniformly compare final files.
cp status 0 does not prove source safety or modes; grep status 0 does not prove
bytes. GNU/Linux differential is separate, was not run and covers only selected
cases.

## Responsibilities and repair order

**When authorized by the caller and supported by the platform, preserve
argv/stdin, environment/cwd, stdout/stderr, status and filesystem/process effects.**
Describe limits through capabilities/upstream semantics; control and determinism
are not compatibility.

1. Fix incorrect success: same-inode cp truncation, then modes and grep/jq/sh
   output/status. realpath is not identity. Snapshot updates or project
   exceptions must not bless defects.
2. Remove secondary command policy. Preserve host authorization/errors and
   supplied environment, changing it only through env -i/-u, shell export and
   other original semantics. Tests supply LC_ALL=C.
3. Implement identity/mode/time/link adaptation. Minimal Wasm capability must
   not permanently remove features available on Native/future hosts.
4. Treat sh/make as language implementations. Prioritize glob, expansion,
   export, builtins, make functions and scheduling while labeling subsets.
   Authorizing children is distinct from delegating an entire implementation;
   the latter is not equivalent MoonBit migration.
5. Choose GNU/POSIX/upstream versions and compare released bytes/status/
   metadata/effects. Policy stays separate host integration. Rejection is
   unsupported behavior; incorrect success blocks release.

Evidence .mbtx files reproduce the audit using explicit /tmp/cmd-audit-20260919*
roots, which must exist and whose audit outputs are replaced. Filesystem
scripts rebuild only their fixtures. Archived logs remain readable without
/tmp. The historical smoke entrypoint is moon run --target native
tests/release_runner -- --manifest tests/release_runner/manifest.json --suite
smoke --report-dir /tmp/cmd-audit-rerun-release.
