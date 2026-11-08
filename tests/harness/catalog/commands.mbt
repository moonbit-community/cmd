///|
fn contract(
  name : String,
  tier : CompatibilityTier,
  input : InputMode,
  output : OutputMode,
  capabilities : Array[Capability],
  options : Array[String],
  exit_codes~ : Array[Int32] = [0, 1, 2],
) -> CommandContract {
  let declared_options = options.copy()
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
    contract(
      "serve",
      Restricted,
      NoInput,
      LineStream,
      [FileRead, Network],
      ["host", "port"],
      exit_codes=[0, 1],
    ),
    // Typesetting is owned by an external MoonBit engine; this command owns
    // argument policy, local files/fonts/packages, diagnostics and byte streams.
    contract(
      "typst",
      Restricted,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      [
        "input", "format", "root", "creation-timestamp", "pretty", "jobs", "in",
        "field", "one", "ignore-system-fonts", "ignore-embedded-fonts", "pages",
        "ppi", "deps", "no-serve", "timings", "update", "completions",
      ],
    ),
    // Encoding emits complete groups before EOF; decoding retains whole input,
    // validates canonical tails and preserves determined failure-prefix bytes.
    contract("base32", Core, FileOrStdin, ByteStream, [FileRead], [
      "decode", "ignore-garbage", "wrap",
    ]),
    contract("cksum", Core, FileOrStdin, LineStream, [FileRead], [
      "algorithm", "length", "base64", "raw", "untagged", "tag", "binary", "text",
      "zero", "check", "ignore-missing", "quiet", "status", "strict", "warn",
    ]),
    // Incremental canonical decoding accepts EOF padding and adjacent padded
    // groups, committing determined bytes once even when later input fails.
    contract("base64", Core, FileOrStdin, ByteStream, [FileRead], [
      "decode", "ignore-garbage", "wrap",
    ]),
    contract("cat", Core, FileOrStdin, ByteStream, [FileRead], [
      "number", "number-nonblank", "show-all", "show-ends", "show-nonprinting", "show-tabs",
      "squeeze-blank", "unbuffered",
    ]),
    contract("comm", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "3", "check-order", "nocheck-order", "help", "output-delimiter",
      "total", "zero-terminated",
    ]),
    contract("cut", Core, FileOrStdin, LineStream, [FileRead], [
      "bytes", "characters", "complement", "delimiter", "fields", "only-delimited",
      "output-delimiter", "zero-terminated",
    ]),
    contract("false", Core, NoInput, LineStream, [], ["help", "version"]),
    contract("head", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "lines", "quiet", "verbose", "zero-terminated",
    ]),
    contract("join", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "after", "empty", "only", "output", "t", "check-order", "nocheck-order",
      "header", "help", "ignore-case", "zero-terminated",
    ]),
    // logs/-l is the project's JSONL mode; it is not an upstream jq option.
    // from-file/-f selects the first positional as a filter file; it is a flag.
    contract("jq", Core, StructuredInput, StructuredOutput, [FileRead], [
      "color-output", "monochrome-output", "compact-output", "exit-status", "from-file",
      "indent", "join-output", "logs", "null-input", "raw-input", "sort-keys", "slurp",
      "tab", "raw-output", "arg", "argjson",
    ]),
    contract("jqlog", Core, StructuredInput, StructuredOutput, [FileRead], [
      "file", "help",
    ]),
    contract("nl", Core, FileOrStdin, LineStream, [FileRead], [
      "body-numbering", "footer-numbering", "header-numbering", "line-increment",
      "join-blank-lines", "no-renumber", "number-format", "number-separator", "number-width",
      "section-delimiter", "starting-line-number",
    ]),
    contract("paste", Core, FileOrStdin, LineStream, [FileRead], [
      "delimiters", "help", "serial", "zero-terminated",
    ]),
    contract("printf", Core, NoInput, ByteStream, [], ["help"]),
    contract("sleep", Core, NoInput, LineStream, [], ["help", "version"]),
    // Numeric order compares exact decimal prefixes, including unique/check/merge.
    // Key indexing is shared per record; numeric field keys remain exact.
    contract("sort", Core, FileOrStdin, LineStream, [FileRead, FileWrite], [
      "batch-size", "buffer-size", "check", "check-quiet", "dictionary-order", "field-separator",
      "general-numeric-sort", "human-numeric-sort", "ignore-case", "ignore-leading-blanks",
      "ignore-nonprinting", "key", "merge", "month-sort", "numeric-sort", "output",
      "random-sort", "random-source", "reverse", "sort", "stable", "temporary-directory",
      "unique", "version-sort", "zero-terminated",
    ]),
    // Stream suffix storage follows selected bytes, including unfinished records.
    contract("tail", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "follow", "lines", "quiet", "sleep-interval", "verbose", "zero-terminated",
    ]),
    // Spool cleanup is required; a cleanup-only failure is observable.
    contract("tac", Core, FileOrStdin, ByteStream, [FileRead, FileWrite], [
      "before", "regex", "separator",
    ]),
    contract("tr", Core, OptionalStdin, ByteStream, [], [
      "complement", "delete", "squeeze-repeats", "truncate-set1",
    ]),
    contract("true", Core, NoInput, LineStream, [], ["help", "version"]),
    contract("uniq", Core, FileOrStdin, LineStream, [FileRead], [
      "all-repeated", "check-chars", "count", "group", "ignore-case", "repeated",
      "skip-chars", "skip-fields", "unique", "zero-terminated",
    ]),
    contract("unexpand", Core, FileOrStdin, ByteStream, [FileRead], [
      "all", "first-only", "tabs",
    ]),
    contract("unlink", Core, NoInput, LineStream, [FileWrite], []),
    contract("wc", Core, FileOrStdin, LineStream, [FileRead], [
      "bytes", "chars", "files0-from", "lines", "max-line-length", "total", "words",
    ]),
    // Usage errors are 1; runtime input/output/seek statuses remain distinct.
    // The little/ebcdic aliases and =VALUE syntax have explicit project contracts.
    contract(
      "xxd",
      Core,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      [
        "autoskip", "bits", "cols", "ebcdic", "little", "group", "include", "len",
        "name", "offset", "plain", "reverse", "revert", "seek", "upper",
      ],
      exit_codes=[0, 1, 2, 3, 4, 5, 255],
    ),
    contract("basename", Core, NoInput, LineStream, [], [
      "multiple", "suffix", "zero",
    ]),
    contract(
      "cmp",
      Core,
      FileOrStdin,
      LineStream,
      [FileRead],
      // Silent comparison stops at the first mismatch, before later reads.
      ["bytes", "ignore-initial", "silent", "verbose", "print-bytes"],
      exit_codes=[0, 1, 2],
    ),
    contract("dirname", Core, NoInput, LineStream, [], ["zero"]),
    // POSIXLY_CORRECT enables escapes and admits option parsing only after
    // initial -n; standalone metadata retains the project exception.
    contract("echo", Core, NoInput, ByteStream, [], [
      "enable-escapes", "disable-escapes", "help", "no-newline", "version",
    ]),
    contract("expand", Core, FileOrStdin, ByteStream, [FileRead], [
      "initial", "tabs",
    ]),
    // Stat snapshots precede names and child effects; actions obey expression
    // order. Size uses upward-rounded uint64 units, with K as a project alias.
    // Finite time windows and unavailable metadata retain explicit boundaries.
    contract(
      "find",
      Restricted,
      NoInput,
      LineStream,
      [FileRead, ProcessSpawn],
      [
        "expression-language", "amin", "atime", "cmin", "ctime", "mmin", "anewer",
        "cnewer", "newerXY", "used", "readable", "writable", "executable", "xtype",
      ],
    ),
    // grep, sed, csplit and expr share compiled C-byte BRE/ERE matching;
    // Capture backreferences and word assertions do not invoke a host engine.
    // Repeated nullable captures use GNU candidate and capture-register selection.
    // Candidate grep uses bounded byte DFAs for boolean records and eligible
    // span endpoints, preserving leftmost-longest selection and fallback rules.
    contract("grep", Core, FileOrStdin, LineStream, [FileRead], [
      "after-context", "before-context", "basic-regexp", "binary-files", "byte-offset",
      "context", "count", "exclude", "extended-regexp", "file", "files-with-matches",
      "files-without-match", "fixed-strings", "ignore-case", "include", "invert-match",
      "line-number", "line-regexp", "no-filename", "no-messages", "null-data", "only-matching",
      "quiet", "recursive", "regexp", "text", "with-filename", "word-regexp",
    ]),
    // no-dereference/-P and named layout/time aliases are project extensions;
    // quote names the GNU --quote-name behavior, also accepting --quote.
    contract("ls", Core, NoInput, LineStream, [FileRead], [
      "all", "almost-all", "classify", "directory", "recursive", "sort-time", "access-time",
      "change-time", "reverse", "sort-size", "dereference-command-line", "dereference",
      "no-dereference", "time", "columns", "across", "commas", "one", "width", "tabsize",
      "quoting-style", "escape", "literal", "quote", "hide-control-chars", "show-control-chars",
      "color",
    ]),
    contract("printenv", Core, NoInput, ByteStream, [], ["null"]),
    contract("pwd", Core, NoInput, LineStream, [FileRead], [
      "logical", "physical",
    ]),
    contract("seq", Core, NoInput, LineStream, [], [
      "equal-width", "format", "separator", "version",
    ]),
    contract("sha256sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "tag", "text",
      "warn", "zero",
    ]),
    // Standalone arity precedes expression parsing. Size follows metadata
    // without reading content; integers use signed-64-bit decimal with ASCII
    // edge whitespace. Unary -a remains a project extension.
    contract("test", Core, NoInput, LineStream, [FileRead], [
      "expression-language", "file-kinds", "access-checks", "size", "timestamps",
    ]),
    // One shared preflight precedes exclusive creation; overwrite flags stay boundary-only.
    contract("cp", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "archive", "force", "no-clobber", "no-target-directory", "no-preserve", "preserve",
      "recursive", "verbose", "interactive", "update", "update-mode", "backup", "backup-control",
      "suffix", "dereference-command-line", "dereference", "no-dereference",
    ]),
    // Numbered backups advance beyond the highest valid decimal sibling version.
    contract("ln", Extended, NoInput, LineStream, [FileWrite, SymbolicLink], [
      "force", "no-target-directory", "symbolic", "verbose", "interactive", "relative",
      "no-dereference-target", "target-directory", "backup", "backup-control", "suffix",
    ]),
    // Symbolic leaf permissions preserve platform creation semantics: sticky
    // creation requires a final permission adjustment on Darwin. New parents
    // lacking public write/search access report a partial-effect boundary;
    // these checks do not establish raw-mode parity. Windows -m preflights.
    contract("mkdir", Extended, NoInput, LineStream, [FileWrite], [
      "mode", "parents", "verbose",
    ]),
    contract("mktemp", Extended, NoInput, LineStream, [FileWrite], [
      "directory", "quiet", "suffix", "tmpdir",
    ]),
    // Timestamps describe entries, including dangling links, without dereferencing.
    // Windows Wasm link moves/backups reject until the host rename fix is verified.
    // A failed rollback reports its backup path alongside the original move failure.
    // Numbered backups retain gaps and existing versions; scan errors propagate.
    contract("mv", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "force", "no-clobber", "no-target-directory", "verbose", "interactive", "update",
      "update-mode", "backup", "backup-control", "suffix",
    ]),
    // Directory-link operands with trailing separators reject before traversal.
    contract("rm", Extended, OptionalStdin, LineStream, [FileWrite], [
      "dir", "force", "interactive", "preserve-root", "no-preserve-root", "recursive",
      "verbose",
    ]),
    // Project -I aliases ignore-fail-on-non-empty. Only actual failed removals
    // are classified; ignored failures stop parents and verbose records attempts.
    contract("rmdir", Extended, NoInput, LineStream, [FileWrite], [
      "ignore-fail-on-non-empty", "parents", "verbose",
    ]),
    contract("realpath", Core, NoInput, LineStream, [FileRead], [
      "canonicalize", "canonicalize-existing", "canonicalize-missing", "quiet", "relative-base",
      "relative-to", "strip", "no-symlinks", "zero",
    ]),
    contract("rev", Core, FileOrStdin, ByteStream, [FileRead], []),
    contract("tee", Extended, OptionalStdin, ByteStream, [FileWrite], [
      "append", "output-error",
    ]),
    // Links are named leaves; -d filters children, retaining explicit operands.
    // Link targets and sizes remain unavailable rather than inferred from referents.
    contract("tree", Core, NoInput, LineStream, [FileRead], [
      "all", "dirs-only", "full-path", "level", "noreport", "json", "html", "title",
      "pattern", "ignore", "matchdirs", "ignore-case", "prune", "filelimit", "size",
      "human-readable", "si", "du", "color", "no-color",
    ]),
    contract("touch", Extended, NoInput, LineStream, [FileWrite], [
      "access-time", "date", "modification-time", "no-create", "reference", "stamp",
      "time",
    ]),
    contract("chmod", Restricted, NoInput, LineStream, [PermissionMutation], [
      "recursive", "reference", "verbose", "symbolic-assignment",
    ]),
    // Explicit Cookie follows the jar as a separate field. Candidate CurlProfile
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
    // Response observers retain final Set-Cookie fields separately from storage.
    // Requests default to identity encoding and retain content-coded wire bytes.
    // Resumed 206 bodies must complete their declared Content-Range span.
    contract(
      "curl",
      Restricted,
      NoInput,
      ByteStream,
      [Network, FileWrite],
      [
        "connect-timeout", "data", "data-binary", "data-raw", "data-urlencode", "fail",
        "head", "header", "idle-timeout", "insecure", "location", "max-redirs", "max-time",
        "output", "proxy", "remote-header-name", "remote-name", "remove-on-error",
        "request", "retry", "retry-all-errors", "retry-connrefused", "retry-delay",
        "retry-max-time", "show-error", "silent", "upload-file", "user", "basic",
        "cookie", "cookie-jar",
      ],
      exit_codes=[0, 1, 2, 3, 5, 7, 18, 22, 23, 26, 28, 47, 52, 56, 60, 65],
    ),
    // Chdir retains filesystem parent traversal in every option spelling.
    contract(
      "env",
      Restricted,
      NoInput,
      LineStream,
      [ProcessSpawn],
      [
        "chdir", "ignore-environment", "null", "split-string", "unset", "help", "version",
      ],
      exit_codes=[0, 125, 126, 127],
    ),
    // Named/default export policy and secondary prerequisites retain GNU order.
    // File paths retain raw components; each -C resolves an existing directory.
    // Recipes expand before execution; each target constructs its environment once.
    // Shell argv, NUL-truncated captures and errors retain actual shell status.
    // Every file-test operand preserves the POSIX trailing-slash directory rule.
    // Inherited POSIX FIFO tokens are separate from local -j scheduling;
    // descriptor-pipe and Windows semaphore authentication reject explicitly.
    contract(
      "make",
      Restricted,
      NoInput,
      LineStream,
      [FileRead, ProcessSpawn],
      [
        "always-make", "directory", "file", "jobs", "keep-going", "just-print", "silent",
        "what-if",
      ],
    ),
    // Shared sessions implement arithmetic side effects, backticks, expanded
    // heredocs, loop levels, printf/test and actual stdout/stderr aliases.
    // File-size tests follow target metadata and reject unavailable sizes.
    // All file predicates and timestamp operands enforce POSIX directory suffixes.
    // Syntax rejects before command-list effects; complete EOF continuations run.
    // External output-transfer failures retain their error identity.
    // Descriptor import/closure and terminal job control remain boundaries.
    contract(
      "sh",
      Restricted,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite, ProcessSpawn],
      ["command", "stdin-script", "interactive"],
    ),
    contract(
      "timeout",
      Restricted,
      NoInput,
      LineStream,
      [ProcessSpawn, ProcessGroupCancellation],
      ["duration"],
      exit_codes=[0, 124, 125, 126, 127],
    ),
    // Explicit Cookie overrides jar fields across origins. Candidate WgetProfile
    // accepts calibrated header/chunk-data/trailer EOF, but other exhausted
    // receive retries use 4. A 416 does not open transfer output and succeeds;
    // explicit -O initialization remains a prior command effect.
    // a complete shorter known-length 200 preserves the prefix. Stdin is not retried.
    // Continued GET plus Content-Disposition discovers the filename with HEAD,
    // then uses that file's offset. The core API rejects a direct resumed switch.
    // Raw space/TAB/CR/LF/DEL in initial path/query uses uppercase percent escapes.
    // Redirect space/TAB uses %20/%09. Existing percent-encoded bytes remain.
    // Set-Cookie without '=' and nonnumeric Max-Age replacements preserve old cookies.
    // Positive decimal overflow below 32 digits expires the matching stored cookie.
    // Cookie ordering uses descending domain/path byte length, then name/value bytes.
    // Response observers retain final Set-Cookie fields separately from storage.
    // Multiple URL failures retain the lowest nonzero transfer exit code.
    contract(
      "wget",
      Restricted,
      NoInput,
      ByteStream,
      [Network, FileWrite],
      [
        "append-output", "body-data", "body-file", "connect-timeout", "continue",
        "content-disposition", "header", "input-file", "max-redirect", "method",
        "no-check-certificate", "no-proxy", "output-document", "output-file", "quiet",
        "read-timeout", "retry-connrefused", "retry-on-http-error", "timeout", "timestamping",
        "tries", "waitretry", "idle-timeout", "user", "password", "http-user", "http-password",
        "auth-no-challenge", "load-cookies", "save-cookies", "keep-session-cookies",
        "no-cookies",
      ],
      exit_codes=[0, 1, 2, 3, 4, 5, 7, 8],
    ),
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
      [
        "regexp", "file", "fixed-strings", "ignore-case", "smart-case", "word-regexp",
        "line-regexp", "invert-match", "only-matching", "replace", "line-number",
        "byte-offset", "count", "count-matches", "files", "files-with-matches", "files-without-match",
        "quiet", "max-count", "before-context", "after-context", "context", "glob",
        "iglob", "hidden", "no-ignore", "ignore-file", "type", "type-not", "type-add",
        "type-list", "follow", "max-depth", "sort", "sortr", "multiline", "multiline-dotall",
        "crlf", "null", "null-data", "text", "binary", "encoding", "json", "color",
        "colors", "heading", "with-filename", "no-filename", "pre", "pre-glob", "no-config",
      ],
      exit_codes=[0, 1, 2],
    ),
    contract("yes", Core, NoInput, ByteStream, [], []),
    contract(
      "fold",
      Core,
      FileOrStdin,
      ByteStream,
      [FileRead],
      ["bytes", "characters", "spaces", "width", "version"],
      exit_codes=[0, 1],
    ),
    contract(
      "od",
      Core,
      FileOrStdin,
      ByteStream,
      [FileRead],
      [
        "address-radix", "skip-bytes", "read-bytes", "format", "endian", "width",
        "output-duplicates", "named", "octal-byte", "character", "decimal", "int",
        "long", "octal", "signed", "hex", "strings", "traditional", "version",
      ],
      exit_codes=[0, 1],
    ),
    contract(
      "hexdump",
      Core,
      FileOrStdin,
      ByteStream,
      [FileRead],
      [
        "one-byte-octal", "one-byte-char", "canonical", "two-bytes-decimal", "two-bytes-octal",
        "two-bytes-hex", "one-byte-hex", "length", "skip", "no-squeezing", "format",
        "format-file", "color", "version",
      ],
      exit_codes=[0, 1],
    ),
    contract("md5sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "tag", "text",
      "warn", "zero",
    ]),
    contract("sha1sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "tag", "text",
      "warn", "zero",
    ]),
    contract("sha512sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "tag", "text",
      "warn", "zero",
    ]),
    // The workspace sed instruction machine adds hold, branches and multiline
    // cycles; in-place replacement remains a separate filesystem boundary.
    contract("sed", Core, FileOrStdin, ByteStream, [FileRead], [
      "expression", "file", "extended-regexp", "quiet", "silent", "in-place",
    ]),
    // Default diff alignment discards sparse repeated anchors before search;
    // normal/unified/context output retains the same supported option surface.
    contract(
      "diff",
      Core,
      FileOrStdin,
      LineStream,
      [FileRead],
      [
        "brief", "report-identical-files", "text", "unified", "context", "unified-lines",
        "context-lines", "label", "ignore-case", "ignore-all-space", "ignore-space-change",
        "ignore-blank-lines", "ignore-trailing-space", "strip-trailing-cr", "recursive",
        "new-file", "unidirectional-new-file",
      ],
      exit_codes=[0, 1, 2],
    ),
    contract(
      "patch",
      Extended,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      [
        "strip", "input", "output", "directory", "reverse", "dry-run", "quiet", "unified",
        "context", "batch", "fuzz", "reject-file", "no-backup-if-mismatch", "version",
      ],
      exit_codes=[0, 1, 2],
    ),
    // Filters share syntax, EOF continuation and output-failure session contracts.
    // File tests retain raw POSIX lookup and trailing-slash directory requirements.
    contract(
      "split",
      Restricted,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite, ProcessSpawn],
      [
        "bytes", "lines", "number", "line-bytes", "numeric-suffixes", "hex-suffixes",
        "suffix-length", "additional-suffix", "elide-empty-files", "filter",
      ],
    ),
    contract(
      "csplit",
      Extended,
      FileOrStdin,
      LineStream,
      [FileRead, FileWrite],
      [
        "elide-empty-files", "prefix", "quiet", "silent", "keep-files", "digits",
        "suffix-format", "suppress-matched",
      ],
    ),
    contract("expr", Core, NoInput, LineStream, [], ["expression-language"]),
    contract("fmt", Core, FileOrStdin, ByteStream, [FileRead], [
      "width", "goal", "split-only", "uniform-spacing", "crown-margin", "tagged-paragraph",
      "prefix",
    ]),
    // The gzip family streams input and output, including validation mode.
    contract("gzip", Extended, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet", "fast", "2", "3", "4",
      "5", "6", "7", "8", "best",
    ]),
    contract("gunzip", Extended, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet", "fast", "2", "3", "4",
      "5", "6", "7", "8", "best",
    ]),
    contract("zcat", Core, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet", "fast", "2", "3", "4",
      "5", "6", "7", "8", "best",
    ]),
    contract("strings", Core, FileOrStdin, LineStream, [FileRead], [
      "all", "bytes", "encoding", "octal", "print-file-name", "radix", "output-separator",
      "version",
    ]),
    contract("column", Core, FileOrStdin, LineStream, [FileRead, FileWrite], [
      "table", "separator", "output-separator", "output-width", "fillrows", "version",
    ]),
    contract(
      "which",
      Core,
      NoInput,
      LineStream,
      [FileRead],
      ["all", "silent", "version"],
      exit_codes=[0, 1, 2],
    ),
    contract("date", Core, NoInput, LineStream, [FileRead], [
      "utc", "date", "iso-8601", "rfc-email", "version",
    ]),
    // Complete batches may run before EOF; fatal statuses stop new dispatch.
    // Ordinary child exits and launch failures remain distinct; active children are awaited.
    contract(
      "xargs",
      Restricted,
      OptionalStdin,
      LineStream,
      [FileRead, ProcessSpawn],
      [
        "max-args", "max-lines", "max-chars", "eof", "no-run-if-empty", "null", "delimiter",
        "replace", "verbose", "show-limits", "interactive",
      ],
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
