# 2026-10-11 command follow-up audit

Scope: documentation/decision closure before merging the implementation branch.
Source observed: `73507f63e0a6c6eb5fb4ce0a7008a8e45cbd694f` (no product edits in
this audit). Host: macOS arm64. Toolchain: moon/moonrun 0.1.20260920,
moonc 0.10.14+7d59c7ec9; workspace async 0.22.4, x 0.5.5, moonjq 0.1.2.
The four observed registry packages are exactly `cli/<cmd>@0.1.0`.

The [pure MoonBit probe](probe.mbtx) records 24 calls, eight each through
prebuilt Native, prebuilt Wasm and exact MoonX. All calls inherit the CLI
account's MOON_HOME; fixtures set LC_ALL=C and TZ=Asia/Shanghai. The raw
[observations](observations.jsonl) preserve stdout, stderr and status; input
bytes use MoonBit's escaped Bytes JSON representation. The probe asserts that
public can_execute and the installed macOS which reject a mode-0644 file;
it records the candidate defect without turning that result into a desired
regression expectation.

Reproduce from the repository root after building Native/Wasm release artifacts:

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run docs/reports/2026-10-11-command-followups/probe.mbtx
```

| Invocation/input | Observed in all three entrypoints | Consequence |
| --- | --- | --- |
| which `-s <0644 regular file>` | Status 0 | False executable match; public access check already returns false |
| column, `a\nb\nc\nd\n` | Unchanged input, status 0 | Default columnation is absent |
| column `-t`, `a b\ncc d\n` | `a  b\ncc d`, no final LF | Existing contract omits an upstream output property |
| date `-d @0 '+%H:%M %z'`, TZ=Asia/Shanghai | `00:00 +0000\n`, status 0 | Caller timezone is ignored without `-u` |
| strings `-t d`, `abcd\0` | Status 2, invalid radix | GNU decimal radix is wrongly rejected |
| strings `-e b`, `abcd\0` | `abcd\n`, status 0 | GNU UTF-16 big-endian selector is reinterpreted as byte scanning |
| strings `-e s`, `abcd\0` | Status 2, unsupported encoding | GNU default single-byte selector is rejected |
| strings, `ab\tcd\0` | Empty output, status 0 | TAB incorrectly terminates the printable sequence |

These are implementation observations, not a new pinned GNU/Linux differential
pass. The installed `/usr/bin/which` check is specifically macOS evidence.
Upstream comparison contracts come from primary sources:

- [GNU binutils strings manual](https://sourceware.org/binutils/docs/binutils/strings.html):
  radix d/o/x, encoding s/S/b/l/B/L, TAB inclusion and explicit file prefixes.
- [util-linux 2.41 column manual source](https://github.com/util-linux/util-linux/blob/v2.41/text-utils/column.1.adoc):
  default columnation, table mode, output separators and width handling.
- [GNU coreutils 9.11 manual source](https://github.com/coreutils/coreutils/blob/v9.11/doc/coreutils.texi):
  date timezone selection and unlink's single-operand contract.

The new findings do not erase the earlier release's 554 selected observations:
447 contract/semantic, 81 availability, 23 boundary, 3 macOS skips. They show
that that selection did not cover these meanings. Historical reports and
published manifests remain unchanged. Current compatibility rows now explicitly
say `known deviations`; no new release or product repair occurred here.

The [79-command prioritized inventory](../../command-followups.md) separates
these defects from unavailable APIs, implementable features and insufficient
validation. [ADR coverage](../../adr/README.md#recent-command-decision-coverage)
maps all 31 recent additions to canonical records with alternatives and unlock
conditions. No GitHub issues were created; the user is reviewing the priorities.
