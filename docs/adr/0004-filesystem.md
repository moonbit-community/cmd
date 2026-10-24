# ADR-0004: Maximum Strict Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-25

The pinned GNU coreutils 9.11 Linux run also establishes status 1 when an
interactive ln/mv overwrite is declined, including EOF. Preserve both paths,
continue other operands, and aggregate the failure. A no-clobber/update skip
remains a distinct successful no-op. Earlier golden status 0 was wrong;
real Native/Wasm and published regressions retain the corrected upstream status.
Revision: Retain the stage 0 Windows rename contract and add selected O8-O12 path, mode, prompt, size and display candidates with operation-specific public-API limits.

## D-stage patch candidate

The unpublished patch 0.2.0 candidate supports offset/fuzz selection, mixed
hunk results and new unified/context rejects. A failed hunk retains its input
region and allows later hunks; stdout and dry-run remain useful without unsafe
existing-file replacement. Batch mode selects a detected reverse explicitly.
Default interactive prompting remains outside this profile.

New reject files use exclusive creation and ordinary permission/umask rules.
Multiple files may share a reject handle owned by this invocation. An already
existing reject is refused before target/reject mutation because public file
identity and safe handle truncation are missing. Reopen that operation only
after released APIs and fixed GNU alias, collision, mode and partial-failure
regressions exist. The current rejection is `d-patch-existing-reject-boundary`;
the existing target, named-output and unsafe-header rejections remain.
These limits do not postpone offset, fuzz, partial success or new rejects.

Diff's directory profile reports FIFO/socket type differences without reading
them, and top-level readable operands retain stream comparison. Comparing
distinct character/block device numbers inside directories requires public
device metadata; path spelling or content must not impersonate that metadata.

## O2 sort output candidate

Ordinary sort creates a new named output before reading, retains an existing
target until every source is consumed, and then writes through a truncating
open. This preserves its inode/mode and supports input aliases without an
atomic replacement or guessed identity.

Streaming merge into a new output is supported. An existing merge output is
refused before mutation: without public same-file identity and opened-handle
truncation, the streaming path cannot establish GNU's distinct hard-link alias
and late-read-error effects. Tests retain the original output, including when
it is an input. Lift this restriction after those APIs, or another algorithm,
prove normal, alias, mode and late-failure effects on Native/Wasm against GNU.
It does not restrict ordinary sort output or merge to a new target/stdout.

## O8-O12 filesystem option candidates

Xxd creates new second-operand outputs exclusively and writes reverse offsets
through public positioned writes. Existing outputs reject before mutation:
without public file identity and the relevant opened-descriptor/mode operations,
the selected implementation cannot establish alias, content-preservation and
mode effects. Path canonicalization or hashes do not supply that identity.
Lift this boundary after those public operations and fixed-provider Native/Wasm
new/existing/alias/backpatch/failure-effect observations pass.

Realpath walks physical components while implementing default final-missing,
existing-only, missing-permitted, strip and relative-to/base rules. Lexical
`-m -s` needs no link API. An unresolved physical link target needs public
readlink; known existing canonical components can still use public realpath.
Only that unresolved link path rejects. Lift it with released readlink plus
dangling-link, dot/dotdot, missing/intermediate-component and error-order cases;
missing operands alone are not an API gap.
Windows physical modes expand existing 8.3 aliases using public `fs.realpath`;
lexical strip mode preserves the supplied spelling. The existing-file and
missing-component package regressions compare physical paths with that API.

Csplit rejects generated Windows names ending in a space or dot before input:
the ordinary public filesystem path currently creates a trimmed name instead.
The POSIX left-padding contract and Windows unchanged-files rejection have
separate case identities. Lift this exact-name restriction only after Native
and Wasm can create, read, enumerate and clean up the verbatim names reliably.

Mktemp uses the final X run, inferred or explicit suffix, GNU default template,
optional long tmpdir/required short directory selection and quiet failures.
Secure public randomness supplies unbiased alphanumeric names, and exclusive
file/directory creation with bounded collisions supplies ownership. Generated
scenarios compare name, content, type and POSIX mode relationships rather than
literal random stdout; Windows checks the supported effects without asserting
POSIX mode. No unsafe `-u` mode is added.

Mkdir compiles symbolic clauses and evaluates omitted-who rules across every
possible 0777 umask. Results independent of the unknown mask are supported;
truly mask-dependent results reject before creation. Unknown parent raw mode
and GNU's temporary owner-permission adjustments remain narrow limits, as do
unavailable Windows mode setters. An existing Windows `-p` no-op is supported.
Lift only the relevant limit after public umask/raw-mode/setter operations and
Native/Wasm leaf/parent/partial-effect observations exist.

Rm implements explicit per-entry and once prompts with a byte reader, GNU C
y/Y acceptance and option-order semantics. Once prompting uses original operand
count or recursive mode before traversal; iterative traversal preserves prompt
order. These prompts do not require terminal detection. Automatic write-protect
prompting still needs public terminal state and raw permission metadata; keep
that distinction explicit instead of disabling supportable `-i`/`-I` modes.

Ls implements selected C quoting, columns/across/commas, post-quote widths, tab
stops and explicit color. Type, suffix and link-target colors use public kind
metadata and preserve raw LS_COLORS bytes. Enabled su/sg/ca/ex/mh predicates
need raw mode, capabilities or link count for regular files; tw/ow/st need raw
directory mode. Only relevant enabled predicates reject. Effective execute
access does not establish GNU's any-execute-bit rule. Disable those selectors
to use supported colors; lift them with the specific released reader and exact
Native/Wasm predicate/color tests. `--color=auto` and its terminal aliases
remain rejected until a released terminal query establishes that decision.

Tree applies selected filters and postorder prune/disk-usage totals through an
iterative traversal, with iterative text/JSON/HTML renderers and bounded output
batches. Directory sizes use the actual public `file_size` result. Linux
Native/Wasm returned directory metadata and passed same-fixture immutable
provider comparisons; the observed macOS Native/Wasm backend returns Operation
not supported and has four platform-specific rejection contracts. Windows uses
the public result rather than a guessed platform size. The dynamic package
regression computes real fixture sizes and subtree/root totals; selected Linux
contracts assert stable output fragments while full backend/oracle snapshots
compare all bytes. No portable 4096-byte inode golden is asserted. Lift a
backend's size limit only when it supplies metadata and those dynamic tests pass.

Selected symbolic links still require readlink text; filtered-out links do not
trigger that boundary. Present tree mode-color selectors, even zero values,
require raw mode, and HTML regular-file color needs executable classification.
Omit unsupported selectors for ordinary type/suffix color, or lift the limit
with a public mode reader and independent text/HTML predicate observations.
HTML deliberately escapes unsafe names/title/URLs and uses the cli/tree page
metadata; fixed-provider safe HTML bodies are compared separately from that
documented page contract. Neither safe escaping nor retained generic errors is
a missing-API claim.

These are unpublished source candidates. Selected JSON and package regressions
retain the boundaries; required PR, actual-main and published-coordinate
acceptance remain separate.

## Stage 0: Windows link rename

Stage 0 publishes `cli/mv@0.2.3` with core 0.7.0 and async 0.22.5.
The [release report](../reports/2026-10-20-stage0-release/README.md) records independent Windows
Native/Wasm execution, exact published-host rejection and runtime identities.
The upstream
[Native implementation](https://github.com/moonbitlang/async/blob/11749dec32e2b4de8cc8a6101e18110019c29893/src/internal/event_loop/fs.c#L1504)
adds `FILE_FLAG_OPEN_REPARSE_POINT` when opening the source of a Windows rename,
so the operation addresses a symbolic link or junction itself. The
[Wasm implementation](https://github.com/moonbitlang/async/blob/11749dec32e2b4de8cc8a6101e18110019c29893/src/internal/event_loop/thread_pool.wasm.mbt#L434)
imports the rename job from the host. Updating the package does not update or
identify that host implementation.

The published `mv` therefore rejects Windows Wasm source symlink/junction moves
and destination-link backups before prompting or changing paths. No-clobber
and update-none skips remain available. `-u` timestamp-based link skips are not
claimed: the Wasm guard runs before timestamp lookup. Native uses the released fix; neither
that source inspection nor a macOS run proves Windows behavior. Explicit
`symbolic-link` fixtures use `force_symlink=true`, while Windows `junction`
fixtures use an existing directory and `force_symlink=false`. A fixed host
observer checks the Windows link type and target; tests also assert source,
destination, backup and referent contents. Missing privileges or observations
are infrastructure failures, not successful or skipped semantic evidence.

Interactive rejection scenarios hold stdin open without writing and require
exit within the observer deadline, no overwrite prompt and an unchanged complete
fixture. Separate rounds retain the currently allowed regular-source replacement
of a destination link without backup on both backends; Windows execution must
establish its actual effects. Native package fault injection observes a completed
link/junction backup before failing the commit, then checks restoration of the
link type, target and referent bytes. The corresponding Wasm test must reject
before the injection point. Actual Windows runs cover these assertions;
package fault injection does not establish a real CLI post-backup filesystem
failure or recovery.

Overwrite/update timestamp decisions now read the source and destination
entries with `follow_symlink=false`. A dangling source link remains movable;
the timestamp lookup must not fail merely because its referent is absent.
This uses the released public timestamp API and does not provide file identity.
Equal-time identity-dependent decisions retain their existing rejection.

Unlock the Wasm boundary only after identifying a released host containing the
fix and passing independent Windows Native/Wasm tests for file symlinks,
directory symlinks, junctions, backup paths and unchanged referents. The tests
and their current rejection evidence do not establish a fixed Wasm host.
Track that host-specific evidence in [issue #38](https://github.com/moonbit-community/cmd/issues/38),
a child of the broader [filesystem issue #10](https://github.com/moonbit-community/cmd/issues/10).
The published baseline remains the coordinates in the
[support record](../compatibility.md). The other 75 command coordinates
remain unchanged by this partial publication.

The 0.22.5 public fs interface adds no identity, mode reader, handle truncate,
timestamp setter, hard-link or readlink API. The metadata and inode boundaries
below still apply. References to 0.22.4 in the retained decisions describe
their original verification baseline, not a new acceptance result.

## Target and decision

The retained ls link/time corrections must also be released as `cli/ls@0.2.1`:
the old 0.2.0 coordinate fails the new time-order contracts. Follow command-line
links with `-H`, all selected links with `-L`, and preserve the documented `-P`
extension. `-u/-c/--time` imply time ordering unless an explicit `-S/-t` selects
sorting; retain GNU 9.11 tie, dangling-link and precedence contracts. Reject
metadata-dependent long listings and unsupported directory-size sorting instead
of inventing values. Public mode/owner/link APIs plus differential fixtures are
the conditions for expanding that subset. Passing local source tests never
substitutes for rerunning the exact published coordinate.

The 2026-10-11 second review (issue #25, coreutils 9.11) requires the last ln
`-f/-i` selector to win. For mv, canonical parent paths identify the same entry
before prompting/backups; ordinary rename must remove the source entry. A
hard-link no-op therefore fails with both names intact. Never delete the source
again to force the postcondition: a concurrent actor may have recreated it.

Public async 0.22.4 has no file identity read before the operation. An equal-mtime
target with interactive or older-only update selection cannot be distinguished
from a hard-link alias before a prompt/skip. Refuse that ambiguous case explicitly,
including separate files with matching times; no-clobber/update-none remain valid
skips. Timestamp equality is not treated as proof of identity. Rejected alternatives
are success on an unverified alias, guessing identity from content/time, private
runtime access and host mv delegation. The compatibility cost is conservative
refusal for that equal-time subset and a reported error if concurrent source
recreation defeats the rename postcondition. Public identity/handle metadata plus
Native/Wasm hard-link, symlink, backup, interaction and race tests can lift the
restriction. JSON regressions retain source bytes, mode, link relations and backup
absence; Linux fixed GNU is the independent oracle, Windows contracts are separate.

Implement each backend's maximum correct subset. Public async 0.22.4 lacks identity, mode reads and handle truncation. Default cp therefore fails instead of creating wrong permissions. GNU --no-preserve=mode supports new destinations with 0666/0777 subject to umask; existing regular-file overwrite is rejected. No-clobber/update no-ops remain. Touch creates missing files and implements -c for missing operands; existing timestamp updates fail without content writes. Numeric chmod follows command-line symlinks and skips recursively encountered symlinks. mkdir -p -m applies the requested mode only to the leaf. Exotic umasks requiring temporary owner permissions remain uncertified.

Public `fs.realpath` supplies existing-target canonicalization. The O10
candidate above adds supportable missing-path and lexical operations without
inventing an unresolved symlink target. Public directory traversal does not
provide readlink, raw mode or inode identity; tree's selected profile must
state only the operations for which those values are actually necessary.
Mktemp uses secure public randomness plus exclusive CreateNew/mkdir retries;
it never uses timestamps or rename as an ownership claim.

Tests request metadata dimensions explicitly. Shared snapshots collect metadata
before content, use host `stat`/`readlink` only as test observers on POSIX, and
compare hard-link equivalence within each fixture rather than raw inode values
across independent directories. Timestamp assertions use fixed values or
before/after relationships. Required missing observers produce infrastructure
failure; platform-inapplicable cases are explicit skips. Neither is a semantic
pass. This observation capability does not expand product command APIs.

## Alternatives and compatibility cost

The original patch profile applied exact unified/context hunks to stdout or in a
dry run, and supported unambiguous creation/deletion. The D candidate above
extends matching and reject handling. Existing-file replacement
and named `-o` output refuse because GNU patch preserves source mode. Unlike cp,
patch may replace the target inode: rename itself is available. Reject direct
truncate/write because it mutates hard-link aliases, and reject default-mode
temporary replacement because it loses source permissions. The compatibility
cost is that ordinary `patch < change.diff` cannot update an existing file yet.
Evidence: [2026-10-10 inode/mode observation](../reports/2026-10-10-patch-file-semantics.md),
async 0.22.4 public fs interface and exact-hunk contract cases. Reopen ordinary
writeback after public mode metadata and fixed GNU mode/link regressions pass.

split/csplit use exclusive creation for new outputs and refuse collisions.
They do not emulate existing-target truncation with rename or infer identity
from spelling. This limits repeated splitting into existing names; public
handle identity/truncation and same-file alias tests are the unlock condition.
Ordinary partial output/cleanup behavior remains separately tested.

Reject realpath as inode identity, temporary rename as inode-preserving overwrite, content rewrites as touch, internal imports and own FFI. This intentionally contracts the old false-success surface. POSIX EXDEV is now classifiable via async.platform, but correct mv fallback still requires mode/link/timestamp preservation.

The 2026-09-21 public API recheck found a possible Linux Native procfs route,
not a portable fd API. Unix Native exposes OS fd, Windows exposes HANDLE and
Wasm an opaque host handle. Keep this route experimental until fdinfo/mountinfo
identity, bind mounts, path replacement, permission changes and missing procfs
are tested together. It does not recover source mode. The compatibility cost
remains refusal of existing-file copies; no content/lock/access heuristic is
accepted as identity or metadata. See the [recheck](../reports/2026-09-21-public-api-recheck.md).

## Versions and evidence

Recheck: async 0.22.4, x 0.5.5, moonjq 0.1.2; moon 0.1.20260920,
moonc 0.10.14+7d59c7ec9. Original release evidence retains its earlier baseline.
The unified filesystem scenarios retain the former standalone fidelity probe's
same-file/hard-link source preservation, new-file copy, unchanged mtime/content
on touch rejection, parent/leaf permissions and chmod symlink assertions. Their
reports identify the tested backend and observed dimensions. Linux pinned
oracle validation remains a separate gate from local macOS results. The
support record distinguishes public from internal capabilities.
Historical results remain in [the audit](../reports/2026-09-19-command-fidelity-audit.md).
Candidate runtime results are recorded separately from published versions.

## Migrated filesystem profiles

Target: preserve upstream path effects and fail without destructive guesses.
The table records current workspace profiles and their public-API boundaries.
Historical migration evidence uses async 0.22.4 on MoonBit 2026-09-20 and the
0.1.1/0.1.0 release reports; current cases are in `tests/cases/<command>.json`.
Every row retains the pure MoonBit boundary; host observers never implement it.

| Commands | Choice and reason | Rejected alternative / compatibility cost | Evidence and unlock condition |
| --- | --- | --- | --- |
| realpath | Public resolution for physically resolvable paths; lexical `-m/-s`, relative-to/base, quiet and ordered operands have selected contracts. | Lexical normalization does not establish physical link resolution. Unresolvable link targets retain the documented readlink boundary. | `realpath.json` and O10 package tests cover missing paths, dot/dotdot, relative bases and link refusals. Lift physical-path restrictions only with the missing public API and same-fixture link evidence. |
| tree | Iterative traversal/postorder totals and C-locale text, JSON/HTML, filters, pruning, file limits and explicit color. Directory size uses actual per-platform API results. | Original link text and metadata-dependent output retain their API boundaries; HTML follows the documented project profile. macOS directory-size refusal is not a Linux restriction. | `tree.json`, rendering/package tests, Linux directory-size observations and the current support record. Add link/metadata output only with the required public API and upstream observations. |
| mktemp | Public randomness, exclusive creation/retry, default and explicit template/suffix rules, `-p/-t`, quiet and selected environment precedence. | No predictable names or exists-then-create race. POSIX 0600/0700 observations do not establish Windows owner/ACL parity; `-u` remains outside the selected profile. | `mktemp.json` and generated-name scenarios check reported path, type, emptiness, creation count and applicable private mode. Extend owner/ACL claims only with real platform APIs and observations. |
| unlink | Preflight exactly one operand, then remove a non-directory name without following symlinks. | Reject the previous multiple-removal extension: extra operands return 1 before any unlink. This intentionally removes non-GNU behavior; no ownership API is required. | Coreutils 9.11 plus two untouched files, single file, -- dash-name and directory-target symlink regressions. No pending API gate for ordinary unlink; widen only to upstream behavior with side-effect evidence. |
| split, csplit | Exclusive new pieces and selected suffix/chunk/filter options. Split streams independent distributions and spools total-dependent input; csplit supports suffix formats and suppressed matches. | Do not truncate collisions or remove pre-existing files during cleanup. Csplit's input-sized retention is addressed separately by R; suffix/counter and observable-cancel limits remain explicit. | Their current JSON/package and filter/collision/cleanup fixtures. R supplies paged csplit offsets and large-input observations; existing-name overwrite still requires the handle identity/truncation gate above. |
| patch | Offset/fuzz matching, ordered partial hunks, rejects, stdout/dry-run and explicit create/delete follow the selected D profile. Existing pathname and named-output replacement remain unavailable. | Replacing an inode does not preserve unknown source mode; unguarded in-place writes can modify aliases. Reject existing reject-file destinations before writes. | Current hunk/reject/mixed-effect cases and ADR-0009. Public mode plus safe replacement and GNU hard-link/mode fixtures are required to unlock existing-file writeback. |

## Revisit when

Reopen when released public handle identity/mode, truncate, time setters and link APIs support the required semantics. Validate Native/Wasm independently; missing public identity does not mean Wasm hosts have no inode capability.
