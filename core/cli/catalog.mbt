///|
fn contract(
  name : String,
  tier : CompatibilityTier,
  input : InputMode,
  output : OutputMode,
  capabilities : Array[Capability],
  options : Array[String],
  exit_codes? : Array[Int] = [0, 1, 2],
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
pub fn command_catalog() -> Array[CommandContract] {
  [
    contract("base32", Core, FileOrStdin, ByteStream, [FileRead], [
      "decode", "ignore-garbage", "wrap",
    ]),
    contract("cksum", Core, FileOrStdin, LineStream, [FileRead], [
      "help", "version",
    ]),
    contract("base64", Core, FileOrStdin, ByteStream, [FileRead], [
      "decode", "ignore-garbage", "wrap",
    ]),
    contract("cat", Core, FileOrStdin, ByteStream, [FileRead], [
      "number", "number-nonblank", "show-all", "show-ends", "show-nonprinting", "show-tabs",
      "squeeze-blank", "unbuffered",
    ]),
    contract("comm", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "3", "check-order", "nocheck-order", "help", "zero-terminated",
    ]),
    contract("cut", Core, FileOrStdin, LineStream, [FileRead], [
      "bytes", "characters", "delimiter", "fields", "only-delimited", "zero-terminated",
    ]),
    contract("false", Core, NoInput, LineStream, [], ["help", "version"]),
    contract("head", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "lines", "quiet", "verbose", "zero-terminated",
    ]),
    contract("join", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "after", "empty", "only", "output", "t", "check-order", "nocheck-order",
      "help", "zero-terminated",
    ]),
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
    contract("sort", Core, FileOrStdin, LineStream, [FileRead], [
      "check", "check-quiet", "dictionary-order", "field-separator", "general-numeric-sort",
      "human-numeric-sort", "ignore-case", "ignore-leading-blanks", "ignore-nonprinting",
      "key", "month-sort", "numeric-sort", "random-sort", "reverse", "unique", "version-sort",
      "zero-terminated",
    ]),
    contract("tail", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "follow", "lines", "quiet", "sleep-interval", "verbose",
    ]),
    contract("tac", Core, FileOrStdin, ByteStream, [FileRead], [
      "before", "separator",
    ]),
    contract("tr", Core, OptionalStdin, ByteStream, [], [
      "complement", "delete", "squeeze-repeats", "truncate-set1",
    ]),
    contract("true", Core, NoInput, LineStream, [], ["help", "version"]),
    contract("uniq", Core, FileOrStdin, LineStream, [FileRead], [
      "check-chars", "count", "ignore-case", "repeated", "skip-chars", "skip-fields",
      "unique", "zero-terminated",
    ]),
    contract("unexpand", Core, FileOrStdin, ByteStream, [FileRead], [
      "all", "first-only", "tabs",
    ]),
    contract("unlink", Core, NoInput, LineStream, [FileWrite], []),
    contract("wc", Core, FileOrStdin, LineStream, [FileRead], [
      "bytes", "chars", "files0-from", "lines", "max-line-length", "words",
    ]),
    contract("xxd", Core, FileOrStdin, ByteStream, [FileRead], [
      "cols", "include", "len", "plain", "revert", "seek",
    ]),
    contract("basename", Core, NoInput, LineStream, [], [
      "multiple", "suffix", "zero",
    ]),
    contract(
      "cmp",
      Core,
      FileOrStdin,
      LineStream,
      [FileRead],
      ["bytes", "ignore-initial", "silent", "verbose"],
      exit_codes=[0, 1, 2],
    ),
    contract("dirname", Core, NoInput, LineStream, [], ["zero"]),
    contract("echo", Core, NoInput, ByteStream, [], [
      "enable-escapes", "disable-escapes", "help", "no-newline", "version",
    ]),
    contract("expand", Core, FileOrStdin, ByteStream, [FileRead], [
      "initial", "tabs",
    ]),
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
    contract("grep", Core, FileOrStdin, LineStream, [FileRead], [
      "after-context", "before-context", "basic-regexp", "binary-files", "byte-offset",
      "context", "count", "exclude", "extended-regexp", "file", "files-with-matches",
      "files-without-match", "fixed-strings", "ignore-case", "include", "invert-match",
      "line-number", "line-regexp", "no-filename", "no-messages", "null-data", "only-matching",
      "quiet", "recursive", "regexp", "text", "with-filename", "word-regexp",
    ]),
    contract("ls", Core, NoInput, LineStream, [FileRead], [
      "all", "almost-all", "classify", "directory", "recursive", "sort-time", "access-time",
      "change-time", "reverse", "sort-size", "dereference-command-line", "dereference",
      "no-dereference", "time",
    ]),
    contract("printenv", Core, NoInput, ByteStream, [], ["null"]),
    contract("pwd", Core, NoInput, LineStream, [FileRead], [
      "logical", "physical",
    ]),
    contract("seq", Core, NoInput, LineStream, [], [
      "equal-width", "separator", "version",
    ]),
    contract("sha256sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "text", "warn",
      "zero",
    ]),
    contract("test", Core, NoInput, LineStream, [FileRead], [
      "expression-language", "file-kinds", "access-checks", "size", "timestamps",
    ]),
    contract("cp", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "archive", "force", "no-clobber", "no-target-directory", "no-preserve", "preserve",
      "recursive", "verbose", "interactive", "update", "update-mode", "backup", "backup-control",
      "suffix", "dereference-command-line", "dereference", "no-dereference",
    ]),
    contract("ln", Extended, NoInput, LineStream, [FileWrite, SymbolicLink], [
      "force", "no-target-directory", "symbolic", "verbose", "interactive", "relative",
      "no-dereference-target", "target-directory", "backup", "backup-control", "suffix",
    ]),
    contract("mkdir", Extended, NoInput, LineStream, [FileWrite], [
      "mode", "parents", "verbose",
    ]),
    contract("mktemp", Extended, NoInput, LineStream, [FileWrite], ["directory"]),
    contract("mv", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "force", "no-clobber", "no-target-directory", "verbose", "interactive", "update",
      "update-mode", "backup", "backup-control", "suffix",
    ]),
    contract("rm", Extended, NoInput, LineStream, [FileWrite], [
      "dir", "force", "preserve-root", "no-preserve-root", "recursive", "verbose",
    ]),
    contract("rmdir", Extended, NoInput, LineStream, [FileWrite], [
      "ignore-fail-on-non-empty", "parents", "verbose",
    ]),
    contract("realpath", Core, NoInput, LineStream, [FileRead], [
      "canonicalize-existing", "zero",
    ]),
    contract("rev", Core, FileOrStdin, ByteStream, [FileRead], []),
    contract("tee", Extended, OptionalStdin, ByteStream, [FileWrite], ["append"]),
    contract("tree", Core, NoInput, LineStream, [FileRead], [
      "all", "dirs-only", "full-path", "level", "noreport",
    ]),
    contract("touch", Extended, NoInput, LineStream, [FileWrite], [
      "access-time", "date", "modification-time", "no-create", "reference", "stamp",
      "time",
    ]),
    contract("chmod", Restricted, NoInput, LineStream, [PermissionMutation], [
      "recursive", "reference", "verbose", "symbolic-assignment",
    ]),
    // header + cookie: explicit Cookie follows the jar as a separate field.
    contract("curl", Restricted, NoInput, ByteStream, [Network, FileWrite], [
      "connect-timeout", "data", "data-binary", "data-raw", "data-urlencode", "fail",
      "head", "header", "idle-timeout", "insecure", "location", "max-redirs", "max-time",
      "output", "proxy", "remote-header-name", "remote-name", "remove-on-error",
      "request", "retry", "retry-all-errors", "retry-connrefused", "retry-delay",
      "retry-max-time", "show-error", "silent", "upload-file", "user", "basic", "cookie",
      "cookie-jar",
    ]),
    contract(
      "env",
      Restricted,
      NoInput,
      LineStream,
      [ProcessSpawn],
      ["chdir", "ignore-environment", "null", "unset", "help", "version"],
      exit_codes=[0, 125, 126, 127],
    ),
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
    // header + load-cookies: explicit Cookie overrides jar fields across origins.
    contract("wget", Restricted, NoInput, ByteStream, [Network, FileWrite], [
      "append-output", "body-data", "body-file", "connect-timeout", "continue", "content-disposition",
      "header", "input-file", "max-redirect", "method", "no-check-certificate", "no-proxy",
      "output-document", "output-file", "quiet", "read-timeout", "retry-connrefused",
      "retry-on-http-error", "timeout", "timestamping", "tries", "waitretry", "idle-timeout",
      "user", "password", "http-user", "http-password", "auth-no-challenge", "load-cookies",
      "save-cookies", "keep-session-cookies", "no-cookies",
    ]),
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
        "long", "octal", "signed", "hex", "version",
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
        "two-bytes-hex", "one-byte-hex", "length", "skip", "no-squeezing", "version",
      ],
      exit_codes=[0, 1],
    ),
    contract("md5sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "text", "warn",
      "zero",
    ]),
    contract("sha1sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "text", "warn",
      "zero",
    ]),
    contract("sha512sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "ignore-missing", "quiet", "status", "strict", "text", "warn",
      "zero",
    ]),
    contract("sed", Core, FileOrStdin, ByteStream, [FileRead], [
      "expression", "file", "extended-regexp", "quiet", "silent", "in-place",
    ]),
    contract(
      "diff",
      Core,
      FileOrStdin,
      LineStream,
      [FileRead],
      [
        "brief", "report-identical-files", "text", "unified", "context", "unified-lines",
        "context-lines", "label",
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
        "context", "batch", "fuzz", "no-backup-if-mismatch", "version",
      ],
      exit_codes=[0, 1, 2],
    ),
    contract(
      "split",
      Extended,
      FileOrStdin,
      ByteStream,
      [FileRead, FileWrite],
      [
        "bytes", "lines", "numeric-suffixes", "suffix-length", "additional-suffix",
      ],
    ),
    contract(
      "csplit",
      Extended,
      FileOrStdin,
      LineStream,
      [FileRead, FileWrite],
      ["elide-empty-files", "prefix", "quiet", "silent", "keep-files", "digits"],
    ),
    contract("expr", Core, NoInput, LineStream, [], ["expression-language"]),
    contract("fmt", Core, FileOrStdin, ByteStream, [FileRead], [
      "width", "goal", "split-only", "uniform-spacing",
    ]),
    contract("gzip", Extended, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet",
    ]),
    contract("gunzip", Extended, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet",
    ]),
    contract("zcat", Core, FileOrStdin, ByteStream, [FileRead], [
      "stdout", "decompress", "test", "no-name", "quiet",
    ]),
    contract("strings", Core, FileOrStdin, LineStream, [FileRead], [
      "all", "bytes", "encoding", "octal", "print-file-name", "radix", "version",
    ]),
    contract("column", Core, FileOrStdin, LineStream, [FileRead], [
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
    contract(
      "xargs",
      Restricted,
      OptionalStdin,
      LineStream,
      [ProcessSpawn],
      ["max-args", "no-run-if-empty", "null", "replace", "verbose"],
      exit_codes=[0, 1, 123, 124, 125, 126, 127],
    ),
  ]
}

///|
pub fn find_contract(name : String) -> CommandContract? {
  for item in command_catalog() {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn process_group_cancellation_available() -> Bool {
  false
}

///|
pub fn releasable(contract : CommandContract) -> Bool {
  !contract.capabilities.contains(ProcessGroupCancellation) ||
  process_group_cancellation_available()
}
