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
  { name, tier, input, output, exit_codes, capabilities, options, }
}

///|
pub fn command_catalog() -> Array[CommandContract] {
  [
    contract("base64", Core, FileOrStdin, ByteStream, [FileRead], [
      "decode", "ignore-garbage", "wrap",
    ]),
    contract("cat", Core, FileOrStdin, ByteStream, [FileRead], [
      "number", "number-nonblank", "show-all", "show-ends", "show-nonprinting", "show-tabs",
      "squeeze-blank",
    ]),
    contract("comm", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "3", "help",
    ]),
    contract("cut", Core, FileOrStdin, LineStream, [FileRead], [
      "characters", "delimiter", "fields", "only-delimited",
    ]),
    contract("false", Core, NoInput, LineStream, [], []),
    contract("head", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "lines", "quiet", "verbose", "zero-terminated",
    ]),
    contract("join", Core, FileOrStdin, LineStream, [FileRead], [
      "1", "2", "after", "empty", "only", "output", "t", "help",
    ]),
    contract("jq", Core, StructuredInput, StructuredOutput, [FileRead], [
      "compact-output", "exit-status", "from-file", "indent", "join-output", "logs",
      "null-input", "raw-input", "sort-keys", "slurp", "tab", "raw-output", "arg",
      "argjson",
    ]),
    contract("jqlog", Core, StructuredInput, StructuredOutput, [FileRead], [
      "file", "help",
    ]),
    contract("nl", Core, FileOrStdin, LineStream, [FileRead], [
      "body-numbering", "number-separator", "number-width",
    ]),
    contract("paste", Core, FileOrStdin, LineStream, [FileRead], [
      "delimiters", "serial",
    ]),
    contract("printf", Core, NoInput, ByteStream, [], ["help"]),
    contract("sleep", Core, NoInput, LineStream, [], ["help"]),
    contract("sort", Core, FileOrStdin, LineStream, [FileRead], [
      "check", "check-quiet", "dictionary-order", "field-separator", "general-numeric-sort",
      "human-numeric-sort", "ignore-case", "ignore-leading-blanks", "ignore-nonprinting",
      "key", "month-sort", "numeric-sort", "random-sort", "reverse", "unique", "version-sort",
      "zero-terminated",
    ]),
    contract("tail", Core, FileOrStdin, ByteStream, [FileRead], [
      "bytes", "follow", "lines", "quiet", "sleep-interval", "verbose",
    ]),
    contract("tr", Core, OptionalStdin, ByteStream, [], [
      "delete", "squeeze-repeats",
    ]),
    contract("true", Core, NoInput, LineStream, [], []),
    contract("uniq", Core, FileOrStdin, LineStream, [FileRead], [
      "check-chars", "count", "ignore-case", "repeated", "skip-chars", "skip-fields",
      "unique", "zero-terminated",
    ]),
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
      "enable-escapes", "disable-escapes", "no-newline",
    ]),
    contract(
      "find",
      Restricted,
      NoInput,
      LineStream,
      [FileRead, ProcessSpawn],
      ["expression-language"],
    ),
    contract("grep", Core, FileOrStdin, LineStream, [FileRead], [
      "after-context", "before-context", "binary-files", "byte-offset", "context",
      "count", "exclude", "extended-regexp", "file", "files-with-matches", "files-without-match",
      "fixed-strings", "ignore-case", "include", "invert-match", "line-number", "line-regexp",
      "no-filename", "no-messages", "null-data", "quiet", "recursive", "regexp",
      "text", "with-filename", "word-regexp",
    ]),
    contract("ls", Core, NoInput, LineStream, [FileRead], [
      "all", "almost-all", "classify", "directory", "recursive",
    ]),
    contract("printenv", Core, NoInput, ByteStream, [], ["null"]),
    contract("pwd", Core, NoInput, LineStream, [FileRead], [
      "logical", "physical",
    ]),
    contract("seq", Core, NoInput, LineStream, [], ["equal-width", "separator"]),
    contract("sha256sum", Core, FileOrStdin, LineStream, [FileRead], [
      "binary", "check", "text", "zero",
    ]),
    contract("test", Core, NoInput, LineStream, [FileRead], [
      "expression-language",
    ]),
    contract("cp", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "archive", "force", "no-clobber", "no-target-directory", "preserve", "recursive",
      "verbose",
    ]),
    contract("ln", Extended, NoInput, LineStream, [FileWrite, SymbolicLink], [
      "force", "no-target-directory", "symbolic", "verbose",
    ]),
    contract("mkdir", Extended, NoInput, LineStream, [FileWrite], [
      "mode", "parents", "verbose",
    ]),
    contract("mv", Extended, NoInput, LineStream, [FileRead, FileWrite], [
      "force", "no-clobber", "no-target-directory", "verbose",
    ]),
    contract("rm", Extended, NoInput, LineStream, [FileWrite], [
      "dir", "force", "preserve-root", "recursive", "verbose",
    ]),
    contract("rmdir", Extended, NoInput, LineStream, [FileWrite], [
      "ignore-fail-on-non-empty", "parents", "verbose",
    ]),
    contract("tee", Extended, OptionalStdin, ByteStream, [FileWrite], ["append"]),
    contract("touch", Extended, NoInput, LineStream, [FileWrite], [
      "access-time", "date", "modification-time", "no-create", "reference", "stamp",
      "time",
    ]),
    contract("chmod", Restricted, NoInput, LineStream, [PermissionMutation], [
      "recursive", "reference", "verbose",
    ]),
    contract("curl", Restricted, NoInput, ByteStream, [Network, FileWrite], [
      "connect-timeout", "data", "data-binary", "data-raw", "data-urlencode", "fail",
      "head", "header", "idle-timeout", "insecure", "location", "max-redirs", "max-time",
      "output", "proxy", "remote-header-name", "remote-name", "remove-on-error",
      "request", "retry", "retry-all-errors", "retry-connrefused", "retry-delay",
      "retry-max-time", "show-error", "silent", "upload-file",
    ]),
    contract(
      "env",
      Restricted,
      NoInput,
      LineStream,
      [ProcessSpawn],
      ["chdir", "ignore-environment", "null", "unset"],
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
      ["command", "stdin-script"],
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
    contract("wget", Restricted, NoInput, ByteStream, [Network, FileWrite], [
      "append-output", "body-data", "body-file", "connect-timeout", "continue", "content-disposition",
      "header", "input-file", "max-redirect", "method", "no-check-certificate", "no-proxy",
      "output-document", "output-file", "quiet", "read-timeout", "retry-connrefused",
      "retry-on-http-error", "timeout", "timestamping", "tries", "waitretry", "idle-timeout",
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
