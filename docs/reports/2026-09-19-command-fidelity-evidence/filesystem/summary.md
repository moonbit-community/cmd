# Filesystem/path audit, 2026-09-19

Ran 46 paired behavior cases across 15 commands using unpinned `moonx cli/<cmd>` with no policy argument, versus macOS native commands, under separate safe temporary directories. `moonx -v cli/cp --version` independently resolved `cli/cp@0.1.4` (the command itself does not implement `--version`). No repository source edits or repository builds/tests.

Authoritative original evidence: `runner.log`, `followup.log`, and individual `<case>-<side>.stdout` and `.stderr` files preserve the original runs. `native/` and `moon/` retain fixtures and side effects.

Structured evidence: `results.json` and `results.jsonl` contain 124 recovered records: 92 behavior invocations (46 native/Moon pairs) plus 32 native side-effect inspections (16 pairs). The original JSONL writer accidentally used `append=true` with the default truncating create mode; its file initially retained only the final record. Both harnesses now explicitly use `create_mode=@fs.OpenOrCreate`. `restore-evidence.mbtx` rebuilt the structured records from the complete original logs and argv in the harnesses, verifying every stdout/stderr against its original per-case file, uniqueness, completeness, 46 behavior pairs and 15 distinct commands. No behavior case was rerun. `evidence-validation.txt` records the successful checks. Each recovered record identifies its original log in `recovered_from`.

Scope: 34 initial behavior cases plus 12 followups = 46 native/Moon paired cases. Classifying exit/result/side effects, accepting only temporary-root differences, expected time differences, and unspecified find traversal order: 30 matched, 16 differed. These are selected probes, not a general compatibility percentage. All 15 commands had at least one meaningful behavior probe.

## Confirmed data-loss defect

`cp-hard-alias`: native `ln alias-source.txt alias-dest.txt` creates two names for the same 17-byte inode in both trees. Native `cp alias-source.txt alias-dest.txt` exits 1 and keeps both files at 17 bytes. `moonx cli/cp alias-source.txt alias-dest.txt` exits 0 with empty stdout/stderr and truncates that shared inode to 0 bytes, destroying source and destination contents. `cp-hard-alias-before`, `cp-hard-alias-stat-after`, and `cp-hard-alias-after` preserve inode/size/content evidence. Wasm inode was 71634524, link count 2, size changed 17 -> 0.

Source corroboration: `core/fsops/fsops.mbt:241` and `:297` only compare realpath strings to decide same file; hard-link aliases have distinct canonical paths. `:250-256` opens the destination with CreateOrTruncate before copying from the source descriptor, emptying the inode before reading.

## Other mismatches (15 cases)

| Cases | Actual Moon result | Native result |
|---|---|---|
| cp-basic, cp-link-default | exit 0, new copy mode 0644 from source 0640 | exit 0, new copy mode 0640 |
| cp-preserve (`cp -p`), cp-archive (`cp -a`) | exit 1, metadata/link preservation unavailable | exit 0, metadata and links preserved |
| cp-link-physical (`cp -P`) | exit 1, symbolic-link sources unsupported | exit 0, creates symlink |
| cp-dest-link | exit 1, refuses symlink destination, target unchanged | exit 0, writes through destination symlink |
| mkdir-mode (`mkdir -p -m 700 created/a`) | both parent `created` and leaf `a` mode 0700 | parent 0755, leaf 0700 |
| ln-hard | exit 1, hard links unavailable; suggests -s | exit 0, inode link count 2 |
| ls-long (`ls -l`) | exit 2, unknown short option l | exit 0, long metadata listing |
| chmod-symbolic (`u+x,g=u,o-rwx`) | exit 2, symbolic mode must use = | exit 0, changes 0600 -> 0770 |
| chmod-link | exit 1, opaque `cli/chmod.ChmodError.ChmodError` | exit 0, changes symlink target permissions |
| touch-set-time, touch-reference | exit 1, timestamp setter unavailable; output files absent | exit 0, requested timestamp 1577905445 |
| touch-dir, touch-link | exit 1, refuses non-regular file or symlink | exit 0, updates timestamps |

These are common BSD/POSIX command semantics, not GNU-only switches. `cp -a` is also supported by this macOS native cp and the tested `moonx` parser recognizes it before explicitly rejecting preservation. Hard-link data loss and successful cp/mkdir permission changes are semantic defects even when CLI exit codes are 0.

## Successful probes (30)

`cp-self` rejected same literal file without modifying it; `mv-basic`, `mv-no-clobber`; `rm-link`, `rm-force-missing`, `rm-recursive`; `rmdir-parents`, `rmdir-simple`; `mkdir-simple`; `ln-sym`; `ls-one`; six find cases (`-type/-name`, grouped OR, `-exec ... ;`, `-size +1c`, `-mtime -1`, `-prune`); `chmod-octal`, complete symbolic assignment `u=rw,g=r,o=`; `touch-no-create`, ordinary existing regular-file touch (retains contents and updates mtime); `tee-basic`, `tee-append`; `pwd-basic`; `basename-suffix`; `dirname-trailing`; four test cases (`-f`, false numeric relation, `-L`, compound `-a`).

Find's traversal order differs (Moon sorts siblings), but selected path sets and exits match. No blanket defect is claimed from that unspecified ordering. Successful scenarios do not prove untested switches or full command parity.

## Relevant implementation pointers

- `core/fsops/fsops.mbt:227-257`: copies bytes, does not carry source permission bits; hard-link alias detection absent.
- `commands/cp/main.mbt:210`: explicit rejection of metadata/symlink preservation.
- `commands/mkdir/main.mbt:71`: same requested permission sent through recursive mkdir, affecting parents.
- `commands/chmod/main.mbt:42-102`: symbolic parser only accepts complete explicit `=` assignments for u/g/o.
- `commands/chmod/main.mbt:112`: refuses symbolic links.
- `commands/touch/main.mbt:33-43`: explicit refusal of timestamp-setting flags; `:69` onward rewrites last byte to emulate touching an existing regular file; refuses symlinks/non-regular files.
- `commands/ln/main.mbt:133`: hard-link refusal.

Interpretation: ordinary no-policy published calls already impose command-layer limitations. Removing or delegating policy configuration alone will not restore native semantics. At least file identity/stat permission APIs, timestamp setters, link operations and command argument semantics need implementation changes. This is a behavioral compatibility audit, not a security scan.
