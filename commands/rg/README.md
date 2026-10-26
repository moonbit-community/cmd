# cli/rg

Version **0.1.0**, unpublished candidate. A pure MoonBit recursive search command
delivered as Wasm through MoonX. The fixed import is rg.mbt 0.2.0 revision
`2727c25819b00ddd1a0e9b24f9cb683931d64edf`; the semantic reference is ripgrep
`3fce3b5bb0236da2df6d99672afb8a719642eca7`.

```text
rg -n 'pattern' path/to/file
rg --hidden -g '*.mbt' 'pattern' .
rg -i 'pattern' -
rg --files --sort path
```

Use explicit paths or `-` for stdin in search mode. Released public MoonBit APIs
cannot identify stdin's type: an ambiguous no-path search exits 2 with a diagnostic.
`--files` retains its default current-directory traversal. Standalone `--help`
and `--version` exit 0 before configuration or input initialization. Version
output is exactly `rg 0.1.0` followed by a newline.

The imported regex/Unicode, glob/ignore, encoding, context, replacement, counting,
binary/text, multiline, JSON, sorting, type and user-selected `--pre` machinery
is retained inside this module. Ordinary reads, traversal, reader/sink calls and
output are asynchronous and incremental. Multiline and sorted modes retain their
original whole-input or sorted-path storage requirements. `--pre` runs the named
user program with the file as an argument and stdin, preserving cwd/environment;
it consumes stdout incrementally and drains stderr concurrently. It belongs to
the restricted command tier because it can spawn a user-selected program.

**Compressed search is deferred.** An effective `-z`/`--search-zip` exits 2 before
opening input. `--no-search-zip` and a later `--pre` preserve parser precedence.
The former decoder work, fixtures, tests and integration source are retained
only in Git history; see the [support record](../../docs/compatibility.md#rg-candidate).
This candidate has no decoder dependency and performs no implicit
system decompression. Compression files without `-z` follow ordinary byte-search
semantics, as in upstream rg.

The original single-threaded execution, lack of real mmap and lack of PCRE2
remain. Terminal auto-detection is unavailable, so automatic color/headings are
off; explicit output controls work. Device/inode identity, descriptor identity,
readlink, creation time and raw non-UTF-8 paths are unavailable publicly.
`--one-file-system` and creation-time sorting reject. Canonical paths detect
followed directory loops; redirected-output same-file exclusion cannot be proven.
Paths are represented with the runtime's String API.
Windows operands and canonical paths are normalized for the internal lexical
matcher while retaining their drive and UNC prefixes. See the
[support record](../../docs/compatibility.md#rg-candidate) and
[architecture decisions](../../docs/adr/README.md) for precise acceptance and
unlock conditions. This is a command migration, with no compatibility promise
for the former `moonbit-community/rg/*` library APIs.

Local development uses `MOON_HOME="$HOME/.moon-accounts/cli" moon ...` with the
current PATH toolchain. Product code and maintenance automation are pure MoonBit;
host reference tools are observation only. Performance acceptance is deferred.
No registry publication or published MoonX acceptance is claimed.
