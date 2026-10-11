# patch file identity and permission observation

Date: 2026-10-10. Observer: macOS `/usr/bin/patch`, `/usr/bin/stat`.
These are host observations, not GNU/Linux certification.

The fixture starts with `input` containing `old\n`, permission `0751`, and
`alias` hard-linked to `input`. A unified hunk replaces `old` with `new`.

| Observation | input | alias |
| --- | --- | --- |
| Before patch | inode 74701153, mode 751, `old\n` | inode 74701153, mode 751, `old\n` |
| After `patch -s -i change.diff` | inode 74701157, mode 751, `new\n` | inode 74701153, mode 751, `old\n` |

The host patch replaces the path's inode and preserves the original mode.
Writing the patched bytes through the original pathname would instead modify
the hard-link alias. Replacing through a new temporary file without restoring
permissions would change the mode.

A second observation used `patch -s -R -o output -i change.diff`: the new
`output` file had inode 74702686 and mode 751, matching the source permissions.
Consequently named `-o` output also requires a public source mode reader.

Released `moonbitlang/async@0.22.4` exposes `fs.rename`, `fs.chmod`, and
exclusive creation, but `src/fs/pkg.generated.mbti` has no public mode reader.
This restricts candidate `cli/patch@0.1.0` to exact unified/context application
with `--dry-run`, stdout output (`-o -`), `/dev/null` creation and deletion.
Existing-file updates and named output are rejected before target content is
read or any output file is modified. No host command implements the product.

Unlock condition: a released public mode reader with correct permission bits,
followed by Native/Wasm regressions for replacement, hard links, symlinks,
permissions, partial hunk failures, and fixed GNU/Linux patch comparison.
Fuzz, offset search and reject files are project implementation work, not
async gaps. This candidate explicitly uses exact hunks and reports mismatch
without producing partial output for the mismatching file.

Reproduction fixture:

```diff
--- input
+++ input
@@ -1 +1 @@
-old
+new
```

Observation commands (host testing only):

```sh
ln input alias
chmod 751 input
stat -f '%N inode=%i mode=%Lp' input alias
patch -s -i change.diff
stat -f '%N inode=%i mode=%Lp' input alias
cat input alias
patch -s -R -o output -i change.diff
stat -f '%N inode=%i mode=%Lp' input output
```
