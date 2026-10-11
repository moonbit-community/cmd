# Common-command gaps and implementation order

Updated: 2026-10-11

All command packages, shared libraries, test runners, fixtures and automation
must use pure MoonBit. Host programs may serve as pinned oracles, test observers,
CI tools or diagnostics, never fallback implementations of `cli/<cmd>`.
Missing released public APIs require explicit boundaries, ADRs and unlock
conditions.

The directory/catalog/manifest/registry inventory contains **79 local commands,
78 published and local-only timeout**. Before the fidelity repair, published
versions were 47 at 0.2.0, 11 at 0.1.1 and 20 at 0.1.0; core was 0.4.0.
The in-progress repair changes existing package versions, not these counts.
Core is a library and is excluded. Publication does not imply complete GNU/POSIX
compatibility; per-command limits are in the [support record](compatibility.md).

Of 59 selected common gaps, **31/59 (52.5%)** now have published modules:
the first 11 (`base32, mktemp, realpath, rev, tac, tree, unlink, yes, cksum,
expand, unexpand`), the 16-command 2026-10-10 batch, and `strings, column,
which, date`. **28 candidates still lack modules**; missing options inside
existing modules are counted separately.

The inventory draws on [GNU coreutils 9.11 categories](https://www.gnu.org/software/coreutils/manual/coreutils.html),
common development text/archive/process tools and [tree upstream](https://gitlab.com/OldManProgrammer/unix-tree).
Shell builtins cd/read/export, the [ alias, Git, compilers and language runtimes
are excluded. Suggestions below do not constitute implemented or scheduled
delivery.

The historical [JSON inventory](reports/2026-09-21-api-probes/inventory.json)
and [MoonBit collector](reports/2026-09-21-api-probes/inventory.mbtx) preserve
the original sets. Previously unplanned status was cross-checked against README,
ADRs, support records and plans, not inferred solely from missing directories.
A mention in an old audit is not an active implementation plan.

Gap implementation began on 2026-09-26 with async 0.22.4. Each independent P0
package becomes a verified subset only after README, help, catalog, compatibility
and regressions agree. See [P0 evidence](reports/2026-09-26-p0-command-completion.md).

| Category | Count | Missing commands |
| --- | ---: | --- |
| Files and paths | 7 | du, df, stat, readlink, install, truncate, link |
| Text and expressions | 1 | awk |
| Encoding, checksums and archives | 3 | tar, zip, unzip |
| System and execution | 17 | uname, hostname, id, whoami, groups, ps, kill, watch, uptime, free, tty, stty, tput, clear, nproc, chown, chgrp |

## Algorithmic priorities

The first 11-command batch is published. The second published batch started at
0.1.0: fold, od/hexdump, md5sum, sha1sum, sha512sum, sed, diff/patch,
split/csplit, expr, fmt and gzip/gunzip/zcat. These have implementable basic
subsets and must not all be attributed to async limitations. x/crypto already
provides MD5/SHA-1/SHA-512; public APIs expose binary I/O, directory traversal,
exclusive creation and realpath. Each still requires chosen upstream options,
errors and byte contracts with actual CLI comparison. mktemp requires secure
randomness and exclusive creation, not timestamp-derived names.

Next algorithmic/data-source candidates are **awk and tar/zip/unzip**.
strings/column/which/date were published at 0.1.0; their discovered defects and
the remaining work across 79 commands are in the [prioritized register](command-followups.md).
Parsing, formats and algorithms are pure MoonBit work, not permanent upstream
blocks. Define awk grammar, fields and execution semantics. Separate date's
formatting/timezone database work from setting the clock. Archive codecs and
restoration of mode, links and timestamps need independent acceptance; recovered
contents alone do not establish complete tar/unzip. Official async gzip helpers
can be reused, but CLI options and failures remain project responsibilities.

## Tree subset

The implemented no-symlink subset covers default tree output, -a/-d/-f/-L,
--noreport, sorting, counts, multiple roots and failures. Full-output comparisons
with pinned tree cover empty directories, hidden entries, depth boundaries,
unreadable directories and Unicode names. Report access/permission errors rather
than silently omitting entries.

The [upstream manual](https://oldmanprogrammer.net/source.php?dir=projects%2Ftree%2Fdoc%2F%2Ftree.1)
includes symlink targets by default and follows directory links with -l.
Drawing a tree is therefore not complete default semantics. Missing readlink
affects target arrows; identity/mode/owner affect loop/device checks and metadata
display. Unsupported links must fail explicitly without invented targets, silent
omission or realpath masquerading as link text. Verify Native/Wasm separately
and describe the ordinary-directory subset in README. Links, metadata and
complete reporting remain follow-ups.

## Candidates requiring separate API boundaries

| Command | Implementable portion and missing capability |
| --- | --- |
| du | Traversal/apparent size are researchable; default allocated usage, hard-link deduplication and device boundaries need blocks/identity/device metadata. |
| df | Requires filesystem capacity, available blocks and mounts; summing file sizes is not equivalent. |
| stat | Kind/size/timestamps exist; declare format fields individually because full mode/uid/gid/nlink/identity are missing. |
| readlink / link | realpath is not readlink; symlink is not a hard link. No public equivalent currently exists. |
| install / truncate | Content/new-file subsets are researchable; owner, source mode, timestamp preservation and handle truncation remain limited. |
| uname / hostname / id / whoami / groups / nproc | OS enumeration does not provide host identity/groups/CPU affinity. Environment variables are not authoritative; require public queries or validated platform sources. |
| ps / uptime / free | Linux procfs may support a dedicated pure MoonBit subset; no corresponding runtime evidence yet, and it cannot certify macOS/Windows/Wasm. |
| tty / stty / tput / clear / watch | Text/scheduling are implementable. TTY, termios, terminal database/window and signals need independent solutions; fixed ANSI strings are not universal terminal compatibility. |
| chown / chgrp | Missing owner/group mutation API; host owns authorization, with no additional command policy. |
| kill / timeout | Need observable signal failures and group semantics. Cancellation handlers discard Native kill errors and cannot establish kill success; timeout remains a local direct-child subset. |

[API unlock conditions](async-upstream-gaps.md) constrain the specific operations,
not unrelated algorithms, text processing or ordinary-directory functionality.
