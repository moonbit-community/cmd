# ADR-0004: Maximum Correct Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-11-07

## Decision

Implement each operation's correct subset through released public MoonBit APIs.
Do not infer inode identity from paths, timestamps or content, use rename as
inode-preserving overwrite, or rewrite content to simulate touch. Public async
0.22.5 lacks the identity, raw mode, handle truncation, timestamp-setting,
hard-link and readlink operations required by the boundaries below. Host
observers, private APIs and FFI do not expand the product's capabilities.

## Mutation and identity boundaries

| Operation | Supported behavior and deliberate limit | Condition for expansion |
| --- | --- | --- |
| cp | New destinations with --no-preserve=mode follow umask. Default preservation and existing-file overwrite refuse; no-clobber/update skips remain. | Public mode, identity and handle operations; alias and partial-effect tests |
| mv | Rename entries with ordered backup/prompt/update effects. Do not delete a remaining source to manufacture success; EXDEV has no copy/delete fallback. Ambiguous equal-time interactive/older-only cases refuse. | Identity and metadata-preserving fallback; link, time, mode and race tests |
| touch | Create missing files; -c skips missing files. Existing timestamp updates refuse without changing content. | Public timestamp setter and preserved-content observations |
| patch | Offset/fuzz, mixed hunk results, new rejects, stdout/dry-run and selected create/delete. Existing target, named-output and reject replacement refuse. | Mode-preserving replacement and safe reject identity/truncation |
| sort output | Ordinary sort consumes inputs before truncating an existing target, preserving inode/mode. Streaming merge refuses an existing output. | Safe identity/truncation or a sound alias/late-read-error algorithm |
| split/csplit | Exclusively create pieces; never truncate collisions or remove pre-existing names. | Handle identity/truncation and alias evidence |
| xxd output | Exclusively create outputs; positioned reverse writes are supported. Existing outputs refuse. | Identity/handle/mode operations and backpatch failure tests |

Rm inspects the final entry without trailing separators before recursion.
A symlink there rejects with status 1, including force mode, preserving link
and target. Concurrent pathname replacement remains a handle-relative identity
limit. Final dot/dot-dot and root protection follow [ADR-0002](0002-policy.md).

Interactive ln/mv overwrite refusal, including EOF, returns failure, preserves
paths and continues remaining operands. No-clobber/update skips are successful
no-ops. The last ln -f/-i selector wins. Mv timestamp decisions do not follow
symlinks, including dangling entries.

Windows Wasm source symlink/junction moves and destination-link backups reject
before prompting or mutation. No-clobber/update-none skips remain; regular
sources replacing destination links without backup have separate positive
tests. Lift the restriction only with a released fixed Wasm host and actual
link, junction, backup and referent tests; a Native fix is insufficient.
Missing link privileges/observers fail the fixture. See
[issue #38](https://github.com/moonbit-community/cmd/issues/38).

## Paths, modes and display

| Area | Current choice and limitation |
| --- | --- |
| realpath | Public physical resolution; lexical -m/-s and relative-to/base rules. Windows physical modes expand existing 8.3 aliases; lexical modes preserve spelling. Unresolved link targets need readlink. |
| rg | Normalize internal Windows separators, retain drive boundaries and detect followed loops through canonical ancestors. Device identity, redirected-stdout identity, raw invalid-UTF-8 paths and missing creation times remain limits; no invented dev/ino zero. |
| mkdir/chmod | Numeric chmod follows operand links and skips recursively encountered links. Mkdir applies leaf modes and accepts mask-independent omitted-who results. Parent-mode, temporary-owner and unavailable Windows setter cases remain narrow limits. |
| rm | Explicit -i/-I uses original operand-count/recursive rules and a byte reader. Automatic write-protect prompting needs terminal state and raw permissions. |
| ls | Selected layouts, quoting, ordering and explicit colors use actual metadata. Execute access does not substitute for mode bits; automatic color needs terminal detection. |
| tree | Iterative traversal and postorder totals use actual metadata. Links are named leaves, never traversed, and count as files; -d selects actual child directories while retaining explicit operands. JSON preserves link type and HTML link color. Target text and selected-link sizes remain unavailable; filtered-out links do not trigger size rejection. macOS directory-size queries may reject. |
| mktemp | Secure public randomness, exclusive creation and bounded collision retries establish ownership. No unsafe -u or inferred Windows ACL parity. |
| csplit names | Windows trailing dot/space names reject until verbatim creation, reading, enumeration and cleanup work. POSIX padding remains supported. |
| diff directories | Report FIFO/socket kinds without reading them. Distinct device numbers require public metadata. |
| unlink | Preflight exactly one operand before deletion; directory symlinks are removed as names. |

Mkdir's symbolic creation plan accounts for platform sticky-bit capability:
the selected Darwin +t result is 01777, Linux 01755. Do not add a compensating
setuid/setgid mask. Special-bit comparisons require the same process security
context and an observer permitted to change those bits. The earlier
restricted-versus-unrestricted Darwin comparison was invalid; the
[historical correction](https://github.com/moonbit-community/cmd/blob/c4ea7795b0eb6e6fd6d0dffa0e7709809569bbb1/docs/adr/0004-filesystem.md#mutation-and-identity-boundaries)
preserves its scope. Group-dependent setgid evidence remains platform-specific.

Tree's name-only link profile resolves issue #74 without fabricating readlink
text or replacing it with realpath. Dangling and cyclic links remain displayable.
Size requests reject selected links before querying their referents, and
`ln=target` color requests reject instead of following the target. Reopen target
display and link-size support only with released public APIs and exact link,
dangling-target and no-follow tests. The CLI contracts in `tests/cases/tree.json`
and private traversal tests in `commands/tree/symlink_wbtest.mbt` own this scope.

## Verification and reconsideration

Use relational link/metadata assertions, fixed timestamps and observations
before reads that can change atime. Missing required observers fail. Keep
positive operations, conservative rejections and partial effects distinct.

Reopen a boundary only with its public capability or a sound algorithm and
applicable Wasm-host, alias, mode, error-order and pinned-oracle tests.
[Compatibility](../compatibility.md) owns command support details.
Implementation and regressions: [fsops](../../core/fsops/),
[filesystem scenarios](../../tests/scenarios/scenario_filesystem.mbt).
