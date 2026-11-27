///|
fn contract(
  name : String,
  tier : CompatibilityTier,
  input : InputMode,
  output : OutputMode,
  capabilities : Array[Capability],
  exit_codes~ : Array[Int32] = [0, 1, 2],
) -> CommandContract {
  let declared_options = command_options(name)
  if !declared_options.contains("help") {
    declared_options.push("help")
  }
  if !declared_options.contains("version") {
    declared_options.push("version")
  }
  {
    name,
    tier,
    input,
    output,
    exit_codes,
    capabilities,
    options: declared_options,
  }
}

///|
// Options are stable semantic coverage identifiers, not an accepted-argv grammar.
// For example update-mode/backup-control, no-dereference-target, check-quiet and
// unified-lines/context-lines describe public option behavior through command
// adapters, but their raw long spellings are private. Public/project aliases and
// diagnostic contracts are recorded in docs/compatibility.md and CLI cases.
pub fn commands() -> Array[CommandContract] {
  [
    contract("serve", Restricted, NoInput, LineStream, [FileRead, Network], exit_codes=[
      0, 1,
    ]),
    // Typesetting is owned by an external MoonBit engine; this command owns
    // argument policy, local files/fonts/packages, diagnostics and byte streams.
    contract("typst", Restricted, FileOrStdin, ByteStream, [FileRead, FileWrite]),
    // Encoding emits complete groups before EOF; decoding retains whole input,
    // validates canonical tails and preserves determined failure-prefix bytes.
    contract("base32", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("cksum", Core, FileOrStdin, LineStream, [FileRead]),
    // Incremental canonical decoding accepts EOF padding and adjacent padded
    // groups, committing determined bytes once even when later input fails.
    contract("base64", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("cat", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("comm", Core, FileOrStdin, LineStream, [FileRead]),
    contract("cut", Core, FileOrStdin, LineStream, [FileRead]),
    contract("false", Core, NoInput, LineStream, []),
    contract("head", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("join", Core, FileOrStdin, LineStream, [FileRead]),
    // logs/-l is the project's JSONL mode; it is not an upstream jq option.
    // from-file/-f selects the first positional as a filter file; it is a flag.
    contract("jq", Core, StructuredInput, StructuredOutput, [FileRead]),
    // Shares jq value-filter semantics; JSONL admission and per-line output stay local.
    // Module loading and the shared input cursor are jq CLI effects, not jqlog options.
    contract("jqlog", Core, StructuredInput, StructuredOutput, [FileRead]),
    contract("nl", Core, FileOrStdin, LineStream, [FileRead]),
    contract("paste", Core, FileOrStdin, LineStream, [FileRead]),
    contract("printf", Core, NoInput, ByteStream, []),
    contract("sleep", Core, NoInput, LineStream, []),
    // Numeric order compares exact decimal prefixes, including unique/check/merge.
    // Key indexing is shared per record; numeric field keys remain exact.
    contract("sort", Core, FileOrStdin, LineStream, [FileRead, FileWrite]),
    // Stream suffix storage follows selected bytes, including unfinished records.
    contract("tail", Core, FileOrStdin, ByteStream, [FileRead]),
    // Spool cleanup is required; a cleanup-only failure is observable.
    contract("tac", Core, FileOrStdin, ByteStream, [FileRead, FileWrite]),
    contract("tr", Core, OptionalStdin, ByteStream, []),
    contract("true", Core, NoInput, LineStream, []),
    contract("uniq", Core, FileOrStdin, LineStream, [FileRead]),
    contract("unexpand", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("unlink", Core, NoInput, LineStream, [FileWrite]),
    contract("wc", Core, FileOrStdin, LineStream, [FileRead]),
    // Usage errors are 1; runtime input/output/seek statuses remain distinct.
    // The little/ebcdic aliases and =VALUE syntax have explicit project contracts.
    contract("xxd", Core, FileOrStdin, ByteStream, [FileRead, FileWrite], exit_codes=[
      0, 1, 2, 3, 4, 5, 255,
    ]),
    contract("basename", Core, NoInput, LineStream, []),
    contract("cmp", Core, FileOrStdin, LineStream, [FileRead], exit_codes=[
      0, 1, 2,
    ]),
    contract("dirname", Core, NoInput, LineStream, []),
    // POSIXLY_CORRECT enables escapes and admits option parsing only after
    // initial -n; standalone metadata retains the project exception.
    contract("echo", Core, NoInput, ByteStream, []),
    contract("expand", Core, FileOrStdin, ByteStream, [FileRead]),
    // Stat snapshots precede names and child effects; actions obey expression
    // order. Size uses upward-rounded uint64 units, with K as a project alias.
    // Finite time windows and unavailable metadata retain explicit boundaries.
    contract("find", Restricted, NoInput, LineStream, [FileRead, ProcessSpawn]),
    // grep, sed, csplit and expr share compiled C-byte BRE/ERE matching;
    // Capture backreferences and word assertions do not invoke a host engine.
    // Repeated nullable captures use GNU candidate and capture-register selection.
    // Candidate grep uses bounded byte DFAs for boolean records and eligible
    // span endpoints, preserving leftmost-longest selection and fallback rules.
    contract("grep", Core, FileOrStdin, LineStream, [FileRead]),
    // no-dereference/-P and named layout/time aliases are project extensions;
    // quote names the GNU --quote-name behavior, also accepting --quote.
    contract("ls", Core, NoInput, LineStream, [FileRead]),
    contract("printenv", Core, NoInput, ByteStream, []),
    contract("pwd", Core, NoInput, LineStream, [FileRead]),
    contract("seq", Core, NoInput, LineStream, []),
    contract("sha256sum", Core, FileOrStdin, LineStream, [FileRead]),
    // Standalone arity precedes expression parsing. Size follows metadata
    // without reading content; integers use signed-64-bit decimal with ASCII
    // edge whitespace. Unary -a remains a project extension.
    contract("test", Core, NoInput, LineStream, [FileRead]),
    // One shared preflight precedes exclusive creation; overwrite flags stay boundary-only.
    contract("cp", Extended, NoInput, LineStream, [FileRead, FileWrite]),
    // Numbered backups advance beyond the highest valid decimal sibling version.
    // Failed backup recovery retains the creation error and both recovery paths.
    contract("ln", Extended, NoInput, LineStream, [FileWrite, SymbolicLink]),
    // Symbolic leaf permissions preserve platform creation semantics: sticky
    // creation requires a final permission adjustment on Darwin. New parents
    // lacking public write/search access report a partial-effect boundary;
    // these checks do not establish raw-mode parity. Windows -m preflights.
    contract("mkdir", Extended, NoInput, LineStream, [FileWrite]),
    contract("mktemp", Extended, NoInput, LineStream, [FileWrite]),
    // Timestamps describe entries, including dangling links, without dereferencing.
    // Windows Wasm link moves/backups reject until the host rename fix is verified.
    // A failed rollback reports its backup path alongside the original move failure.
    // Numbered backups retain gaps and existing versions; scan errors propagate.
    contract("mv", Extended, NoInput, LineStream, [FileRead, FileWrite]),
    // Directory-link operands with trailing separators reject before traversal.
    contract("rm", Extended, OptionalStdin, LineStream, [FileWrite]),
    // Project -I aliases ignore-fail-on-non-empty. Only actual failed removals
    // are classified; ignored failures stop parents and verbose records attempts.
    contract("rmdir", Extended, NoInput, LineStream, [FileWrite]),
    contract("realpath", Core, NoInput, LineStream, [FileRead]),
    contract("rev", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("tee", Extended, OptionalStdin, ByteStream, [FileWrite]),
    // Links are named leaves; -d filters children, retaining explicit operands.
    // Link targets and sizes remain unavailable rather than inferred from referents.
    contract("tree", Core, NoInput, LineStream, [FileRead]),
    contract("touch", Extended, NoInput, LineStream, [FileWrite]),
    contract("chmod", Restricted, NoInput, LineStream, [PermissionMutation]),
    // Explicit Cookie follows the jar as a separate field. Candidate curl policy
    // maps partial bodies/receive/empty replies to 18/56/52. Accepted 200 header
    // EOF retains known framing checks. Ordinary lazy file output buffers
    // 4096 bytes; an earlier body failure survives a secondary final-flush failure.
    // Accepted retries reset opened regular files before the next request;
    // remove-on-error cleans up only after final failure. A valid -OJ name on
    // 2xx/3xx creates exclusively before body delivery and stays fixed across retries.
    // Other response statuses keep ordinary URL-derived output selection.
    // Path-based reset does not establish descriptor/inode identity under races.
    // A redirect requiring consumed stdin to rewind fails with 65; a separate
    // retry-all attempt may instead upload the now-empty input. Show-error
    // retains each failed attempt's diagnostic even after retry success.
    // Generated Cookie fields reject invalid headers before request writes.
    // Initial raw space/TAB/CR/LF/DEL in path/query rejects before connection (3).
    // Redirect spaces use path %20/query +; TAB uses %09. Encoded bytes remain.
    // Set-Cookie without '=' is ignored; nonnumeric Max-Age deletes its stored cookie.
    // Positive decimal overflow keeps the replacement under a 400-day lifetime cap.
    // Cookie ordering uses descending path/domain/name byte length, then creation.
    // Candidate prefix checks use normalized paths and final host-only scope.
    // Header cookie pairs and attributes trim ASCII OWS before identity checks.
    // Secure contexts are HTTPS or exact localhost/127.0.0.1/::1. Insecure
    // overlays cannot replace live Secure cookies; identity includes host-only.
    // Complete pinned ICANN/PRIVATE suffix rules constrain response and imported
    // cookies; accepted exact suffix responses become host-only.
    // UTF-8 locales select pinned Unicode 15 URL IDNA and whole-host fallback.
    // Canonical hosts govern transport, credential origins, cookies and NO_PROXY.
    // Cookie Domain normalization and complete jar grammar remain open.
    // Saved domains retain case; matching, identity and overlays fold ASCII case.
    // Saved Domain dots are not duplicated; newest creation saves first.
    // File inputs reload per URL/retry; response cookies take precedence.
    // Expired response records survive until lookup, import cleanup or saving.
    // Jars save per operand, including fixed Curl header text on stdout.
    // Completed HTTP bodies precede retry selection; 522/524 are Curl statuses.
    // Custom request fields retain repetition and argument order. Response
    // observers retain all final fields in wire order, separately from storage.
    // Multiple request Content-Length fields reject before request bytes.
    // Requests default to identity encoding and retain content-coded wire bytes.
    // Resumed 206 bodies must complete their declared Content-Range span.
    contract("curl", Restricted, NoInput, ByteStream, [Network, FileWrite], exit_codes=[
      0, 1, 2, 3, 5, 7, 8, 18, 22, 23, 26, 28, 47, 52, 56, 60, 65, 100,
    ]),
    // Chdir retains filesystem parent traversal in every option spelling.
    contract("env", Restricted, NoInput, LineStream, [ProcessSpawn], exit_codes=[
      0, 125, 126, 127,
    ]),
    // Named/default export policy and secondary prerequisites retain GNU order.
    // File paths retain raw components; each -C resolves an existing directory.
    // Recipes expand before execution; each target constructs its environment once.
    // Shell argv, NUL-truncated captures and errors retain actual shell status.
    // Every file-test operand preserves the POSIX trailing-slash directory rule.
    // Inherited POSIX FIFO tokens are separate from local -j scheduling;
    // descriptor-pipe and Windows semaphore authentication reject explicitly.
    contract("make", Restricted, NoInput, LineStream, [FileRead, ProcessSpawn]),
    // Shared sessions implement arithmetic side effects, backticks, expanded
    // heredocs, loop levels, printf/test and actual stdout/stderr aliases.
    // File-size tests follow target metadata and reject unavailable sizes.
    // All file predicates and timestamp operands enforce POSIX directory suffixes.
    // Syntax rejects before command-list effects; complete EOF continuations run.
    // External output-transfer failures retain their error identity.
    // Descriptor import/closure and terminal job control remain boundaries.
    contract("sh", Restricted, FileOrStdin, ByteStream, [
      FileRead,
      FileWrite,
      ProcessSpawn,
    ]),
    contract(
      "timeout",
      Restricted,
      NoInput,
      LineStream,
      [ProcessSpawn, ProcessGroupCancellation],
      exit_codes=[0, 124, 125, 126, 127],
    ),
    // Explicit Cookie overrides jar fields across origins. Candidate wget policy
    // accepts calibrated header/chunk-data/trailer EOF, but other exhausted
    // receive retries use 4. A 416 does not open transfer output and succeeds;
    // explicit -O initialization remains a prior command effect.
    // a complete shorter known-length 200 preserves the prefix. Stdin is not retried.
    // Continued GET plus Content-Disposition discovers the filename with HEAD,
    // then uses that file's offset. The core API rejects a direct resumed switch.
    // Raw space/TAB/CR/LF/DEL in initial path/query uses uppercase percent escapes.
    // Redirect space/TAB uses %20/%09. Existing percent-encoded bytes remain.
    // Set-Cookie without '=' or a valid numeric prefix preserves old cookies.
    // Wget accepts decimal/hex floating prefixes; exactly -1 rejects Max-Age.
    // Expires keeps four ordered C-locale formats, UTC normalization and the 69 pivot.
    // GMT/signed-digit suffixes are accepted without applying timezone offsets.
    // Floating zero deletes, while nonzero stale replacements retain domain chains.
    // Overflow follows the fixed Linux/amd64 profile; saved digits round via binary64.
    // Complete pinned ICANN/PRIVATE rules constrain ASCII response domains/hosts.
    // Non-ASCII input uses fixed non-NLS Wget's label/byte-length fallback.
    // Dot-stripped admission does not rewrite the stored Domain key.
    // Exact suffix scope and imported-file admission retain Wget's dialect.
    // Host-only nondefault ports participate in cookie identity and jar reload.
    // Lookup excludes single-label parent chains and hosts above 32 labels.
    // Jar TRUE flags are case-sensitive; HttpOnly comments are ignored. Quoted
    // parameters, assigned Secure and sticky deletion retain Wget's extractor.
    // Rejected domains discard the matching key only after request-path validation.
    // Cookie paths use raw prefixes; missing Path retains the directory's trailing slash.
    // Explicit UTF-8 input selects pinned URL IDNA; failed conversion retains
    // the raw decoded host. Legacy encodings and full IRI retry remain open.
    // Mapped colons are bracketed in Host; the scheme's default port is omitted.
    // Cookie ordering uses descending domain/path byte length, then name/value bytes.
    // Prefixes remain ordinary names; Secure sends require HTTPS. Curl's
    // loopback exception and admission/overlay checks do not apply to Wget.
    // Same-name request fields keep the last value. Response observers retain
    // all final fields in wire order. Basic challenge lists preserve quoted commas.
    // Multiple URL failures retain the lowest nonzero transfer exit code.
    // All HTTP 401 responses map to 6. Optional credential fields retain URL
    // and HTTP-option precedence; global Basic challenges cache by hostname.
    // URL credentials use per-hop challenges and do not enter the global cache.
    // Attached authentication booleans retain value and literal-operand order.
    // The passive_ftp configuration boolean validates but has no HTTP effect.
    contract("wget", Restricted, NoInput, ByteStream, [Network, FileWrite], exit_codes=[
      0, 1, 2, 3, 4, 5, 6, 7, 8,
    ]),
    // Explicit paths or '-' are required when stdin kind cannot be detected.
    // Compression is deferred; preprocessing remains user-selected authority.
    // DFA byte budgets and indexing reject explicitly; neither is a supported option.
    // Eligible text record counts stream long records; other search modes keep
    // their allocation boundaries and release exceptional buffers after each reader.
    contract(
      "rg",
      Restricted,
      FileOrStdin,
      LineStream,
      [FileRead, ProcessSpawn],
      exit_codes=[0, 1, 2],
    ),
    contract("yes", Core, NoInput, ByteStream, []),
    contract("fold", Core, FileOrStdin, ByteStream, [FileRead], exit_codes=[
      0, 1,
    ]),
    contract("od", Core, FileOrStdin, ByteStream, [FileRead], exit_codes=[0, 1]),
    contract("hexdump", Core, FileOrStdin, ByteStream, [FileRead], exit_codes=[
      0, 1,
    ]),
    contract("md5sum", Core, FileOrStdin, LineStream, [FileRead]),
    contract("sha1sum", Core, FileOrStdin, LineStream, [FileRead]),
    contract("sha512sum", Core, FileOrStdin, LineStream, [FileRead]),
    // The workspace sed instruction machine adds hold, branches and multiline
    // cycles; in-place replacement remains a separate filesystem boundary.
    contract("sed", Core, FileOrStdin, ByteStream, [FileRead]),
    // Default diff alignment discards sparse repeated anchors before search;
    // normal/unified/context output retains the same supported option surface.
    contract("diff", Core, FileOrStdin, LineStream, [FileRead], exit_codes=[
      0, 1, 2,
    ]),
    contract(
      "patch",
      Extended,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      exit_codes=[0, 1, 2],
    ),
    // Filters share syntax, EOF continuation and output-failure session contracts.
    // File tests retain raw POSIX lookup and trailing-slash directory requirements.
    contract("split", Restricted, FileOrStdin, ByteStream, [
      FileRead,
      FileWrite,
      ProcessSpawn,
    ]),
    contract("csplit", Extended, FileOrStdin, LineStream, [FileRead, FileWrite]),
    contract("expr", Core, NoInput, LineStream, []),
    contract("fmt", Core, FileOrStdin, ByteStream, [FileRead]),
    // The gzip family streams input and output, including validation mode.
    contract("gzip", Extended, FileOrStdin, ByteStream, [FileRead]),
    contract("tar", Extended, FileOrStdin, ByteStream, [FileRead, FileWrite], exit_codes=[
      0, 2,
    ]),
    contract(
      "zip",
      Extended,
      OptionalStdin,
      ByteStream,
      [FileRead, FileWrite],
      exit_codes=[0, 1],
    ),
    contract(
      "unzip",
      Extended,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      exit_codes=[0, 1],
    ),
    contract("gunzip", Extended, FileOrStdin, ByteStream, [FileRead]),
    contract("zcat", Core, FileOrStdin, ByteStream, [FileRead]),
    contract("strings", Core, FileOrStdin, LineStream, [FileRead]),
    contract("column", Core, FileOrStdin, LineStream, [FileRead, FileWrite]),
    contract("which", Core, NoInput, LineStream, [FileRead], exit_codes=[
      0, 1, 2,
    ]),
    contract("date", Core, NoInput, LineStream, [FileRead]),
    // Complete batches may run before EOF; fatal statuses stop new dispatch.
    // Ordinary child exits and launch failures remain distinct; active children are awaited.
    contract(
      "xargs",
      Restricted,
      OptionalStdin,
      LineStream,
      [FileRead, ProcessSpawn],
      exit_codes=[0, 1, 2, 123, 124, 125, 126, 127],
    ),
  ]
}

///|
pub fn find(name : String) -> CommandContract? {
  for item in commands() {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn releasable(contract : CommandContract) -> Bool {
  !contract.capabilities.contains(ProcessGroupCancellation)
}
