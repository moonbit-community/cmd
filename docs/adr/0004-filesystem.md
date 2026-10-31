# ADR-0004: Maximum Correct Filesystem Subset

Status: Accepted
Date: 2026-09-05
Updated: 2026-10-31

## Decision

Implement each operation's correct subset through released public MoonBit APIs.
Do not infer inode identity from canonical paths, timestamps or content; do not
use rename as inode-preserving overwrite or rewrite content to simulate touch.
Public async 0.22.5 still lacks the identity, raw mode, handle truncation,
timestamp-setting, hard-link and readlink operations needed by the boundaries
below. Host observers and private runtime interfaces do not expand product APIs.

## Mutation and identity boundaries

Correction on 2026-10-31: the initial Darwin diagnosis for
`mkdir -m u+s,g+s,a+t leaf` compared a restricted-sandbox native GNU probe
(mode01777) with an unsandboxed Wasm run (mode05777). That comparison did not
establish a product incompatibility. A fresh unsandboxed fixed native GNU
coreutils 9.11 probe under the same winter:wheel conditions also created05777,
matching the unchanged product. No product permission mask or behavior change
is justified by the earlier result. Preserve the original observations with
this correction rather than relabeling them as valid parity evidence.

The Darwin regression now requires setuid and sticky together (mode05000,
mask05000). Group-dependent setgid and ordinary rwx bits remain outside this
finite assertion. The requested07000 Linux mask remains Linux-only and needs
actual Linux execution. Special-bit comparisons must launch both programs in
the same process security context and verify that the observer context permits
native setuid changes; a sandbox that strips or denies them is a fixture
precondition failure, not a different product golden. The same-context local
diagnostic covers numeric and symbolic modes under inherited and primary-group
parents. It does not modify published expectations or establish immutable-oracle
parity. General mode/identity limitations below remain unchanged.

The same unrestricted paired diagnostic exposed a separate `mkdir -m +t`
difference under both parent groups: GNU produced01777 while the old Wasm
artifact produced01755. This is a real creation-stage difference. Darwin's
[`mkdir` implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/vfs/vfs_syscalls.c#L9840-L9858)
passes only regular access bits to directory creation, so GNU must reapply
the requested sticky bit and the full symbolic mode after creation. Linux
retains sticky during creation and leaves the unrequested group/other write
bits restricted. The command's pure mode plan now takes this creation
capability from the public async platform value. This preserves the Linux
result1755 and selects the independently observed Darwin result1777, without
a special setuid/setgid mask. Numeric modes, clause ordering, error ordering
and existing-parent handling retain their existing paths. Focused private
capability tests and separate Linux/macOS CLI expectations must execute before
acceptance; the original published expectations remain frozen.

| Operation | Supported behavior and deliberate limit | Condition for expansion |
| --- | --- | --- |
| cp | New destinations with --no-preserve=mode use ordinary umask rules. Default preservation and existing-file overwrite refuse; no-clobber/update skips remain. | Public mode/identity and handle operations, with alias, mode and partial-effect tests |
| mv | Rename entries; preserve backups and ordered prompt/update effects. Do not delete a remaining source to manufacture success after a hard-link no-op. EXDEV has no copy/delete fallback. | Identity and metadata-preserving fallback with link, mode, time and race tests |
| mv equal timestamps | Interactive/older-only ambiguous cases refuse; timestamp equality is not identity. No-clobber/update-none skips remain valid. | Public identity with same-file and distinct-equal-time cases |
| touch | Create missing files; -c skips missing files. Existing timestamp updates refuse without content changes. | Public timestamp setter and preserved-content observations |
| patch | Offset/fuzz, mixed hunk results, new rejects, stdout/dry-run and selected create/delete. Existing-file or named-output replacement refuses because source mode cannot be preserved. Existing reject paths also refuse before mutation. | Mode-preserving replacement and safe reject identity/truncation, with GNU alias and failure effects |
| sort output | Ordinary sort consumes inputs before truncating an existing target, preserving inode/mode. Streaming merge supports stdout/new files but refuses an existing output. | Safe identity/truncation or an algorithm proving alias and late-read-error behavior |
| split/csplit | Exclusively create new pieces; never truncate collisions or remove pre-existing names during cleanup. | Handle identity/truncation and same-file alias evidence |
| xxd output | Exclusively create new outputs and use positioned writes for reverse offsets. Existing outputs refuse. | Public identity/handle/mode operations with backpatch and failure-effect tests |

Interactive ln/mv overwrite refusal, including EOF, is status 1; preserve paths,
continue remaining operands and aggregate failure. No-clobber/update skips are
separate successful no-ops. The last ln -f/-i selector wins. Mv timestamp
decisions inspect entries without following symlinks, so dangling sources do
not fail merely because their referents are absent.

### Windows link rename

Windows Wasm source symlink/junction moves and destination-link backups reject
before prompting or mutation. The async Native fix does not establish a fixed
Wasm host. No-clobber/update-none skips remain; timestamp-based link skips are
not claimed. Regular-source replacement of a destination link without backup
has separate allowed-path regressions.

Lift this boundary only after identifying a released fixed host and exercising
file/directory symlinks, junctions, backups and unchanged referents on Windows.
Missing privileges or link observers are infrastructure failures. See
[issue #38](https://github.com/moonbit-community/cmd/issues/38).

## Paths, modes and display

| Area | Current choice and limitation |
| --- | --- |
| realpath | Physical resolution uses public realpath; lexical -m/-s and relative-to/base rules are implemented. Only unresolved physical link targets require readlink. Windows physical modes expand existing 8.3 aliases; lexical modes preserve spelling. |
| rg | Normalize Windows internal path separators while retaining drive boundaries. Canonical ancestor paths detect followed loops. Reject --one-file-system without device identity; redirected-stdout identity, raw invalid-UTF-8 paths and missing creation times remain unavailable. Do not invent dev/ino zero. |
| mkdir/chmod | Numeric chmod follows operand links and skips recursively encountered links. Mkdir applies leaf modes and evaluates symbolic omitted-who clauses over possible umasks, accepting mask-independent results. Unknown parent mode, temporary owner adjustments and unavailable Windows setters remain narrow limits. |
| rm | Explicit -i/-I prompting uses a byte reader and original operand-count/recursive rules. Automatic write-protect prompting still requires terminal state and raw permissions. |
| ls | Selected quoting, layouts, time/link ordering and explicit type/suffix colors are implemented. Enabled su/sg/ca/ex/mh and tw/ow/st predicates require their actual metadata. Effective execute access is not an any-execute-bit test; automatic color needs terminal detection. |
| tree | Iterative traversal, postorder totals and text/JSON/HTML rendering use actual metadata. MacOS directory-size queries can reject while Linux succeeds. Selected link text and mode-dependent colors retain API limits; filtered-out links do not trigger them. HTML escaping and project page metadata are intentional. |
| mktemp | Secure public randomness and exclusive creation with bounded collision retries establish ownership. Templates/suffixes and selected directory precedence are supported; no unsafe -u or inferred Windows ACL parity. |
| csplit names | Windows names ending in dot/space reject before input until verbatim create/read/enumerate/cleanup works. POSIX padding remains supported. |
| diff directories | Report FIFO/socket kinds without reading them. Distinct character/block device numbers require public device metadata. |
| unlink | Exactly one operand is preflighted before unlink; extra operands cause no deletion. Directory symlinks are removed as names. |

These are operation-specific constraints, not a general ban on filesystem
work. Missing paths are not inherently an API gap, and POSIX executable access
for which already uses a public API. A procfs experiment is not a portable
identity implementation. Do not add host-command or FFI workarounds.

## Verification and reconsideration

Compare link relationships within fixtures rather than raw inode numbers
across roots. Observe metadata before reads that may change atime; use fixed
timestamps or before/after relationships. Required missing observers fail.
Keep positive operations, conservative rejections and partial effects distinct.

Reopen each boundary only when its required public capability or sound
algorithm exists and applicable Wasm-host, alias, mode, error-order and pinned
upstream tests pass. Current profiles are in [compatibility.md](../compatibility.md).
Implementations and regressions: [fsops](../../core/fsops/),
[mv](../../commands/mv/), [patch](../../commands/patch/),
[sort](../../commands/sort/), [rg sys](../../commands/rg/internal/sys/),
[filesystem scenarios](../../tests/runner/scenario_filesystem.mbt).
