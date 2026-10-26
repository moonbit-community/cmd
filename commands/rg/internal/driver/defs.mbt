///|
/// Parses an unsigned integer like Rust's `str::parse::<u64>()`.
fn parse_u64(s : String) -> UInt64 raise RgError {
  let chars : Array[Char] = s.iter().collect()
  let mut i = 0
  if chars.length() > 0 && chars[0] == '+' {
    i = 1
  }
  if i >= chars.length() {
    raise RgError(
      if chars.length() == 0 {
        "cannot parse integer from empty string"
      } else {
        "invalid digit found in string"
      },
    )
  }
  let max = 0xFFFFFFFFFFFFFFFFUL
  let mut v : UInt64 = 0
  while i < chars.length() {
    let c = chars[i]
    if c < '0' || c > '9' {
      raise RgError("invalid digit found in string")
    }
    let d = (c.to_int() - '0'.to_int()).to_uint64()
    // Like Rust's integer parsing, report overflow as soon as it happens
    // (even if an invalid digit follows).
    if v > (max - d) / 10 {
      raise RgError("number too large to fit in target type")
    }
    v = v * 10 + d
    i += 1
  }
  v
}

///|
fn convert_u64(v : String) -> UInt64 raise RgError {
  with_context("value is not a valid number", () => parse_u64(v))
}

///|
/// Converts to a `usize`-like `Int`, clamping huge values.
fn convert_usize(v : String) -> Int32 raise RgError {
  let n = convert_u64(v)
  if n > 0x7FFFFFFFUL {
    0x7FFFFFFF
  } else {
    n.to_int()
  }
}

///|
fn convert_human_readable_u64(v : String) -> UInt64 raise RgError {
  with_context("invalid size", () => {
    @cli.parse_human_readable_size(v) catch {
      e => raise RgError(e.to_string())
    }
  })
}

///|
fn sort_kind(v : String) -> SortModeKind? raise RgError {
  match v {
    "none" => None
    "path" => Some(Path)
    "modified" => Some(LastModified)
    "accessed" => Some(LastAccessed)
    "created" => Some(Created)
    unk => raise RgError("choice '\{unk}' is unrecognized")
  }
}

///|
fn check_indexing_allowed() -> Unit raise RgError {
  raise RgError(INDEXING_NOT_SUPPORTED)
}

///|
/// Flags whose values must be valid UTF-8.
let utf8_flags : Array[String] = [
  "after-context", "before-context", "color", "colors", "context", "dfa-size-limit",
  "encoding", "engine", "generate", "glob", "hyperlink-format", "iglob", "max-columns",
  "max-count", "max-depth", "max-filesize", "path-separator", "pre-glob", "regex-size-limit",
  "regexp", "replace", "sort", "sortr", "threads", "type", "type-add", "type-clear",
  "type-not",
]

///|
/// Applies a flag's value to the low level arguments, mirroring each
/// flag's `update` method in ripgrep's `defs.rs`.
fn update_flag(
  flag : FlagDef,
  v : FlagValue,
  args : LowArgs,
) -> Unit raise RgError {
  // Like ripgrep's `convert::str`/`convert::string`, these flags reject
  // values that aren't valid UTF-8 (other values are OS strings).
  if v is Value(value) &&
    utf8_flags.contains(flag.name_long) &&
    @osstr.has_escapes(value) {
    raise RgError("value is not valid UTF-8")
  }
  match flag.name_long {
    "regexp" => args.patterns.push(Regexp(v.unwrap_value()))
    "file" => args.patterns.push(File(v.unwrap_value()))
    "after-context" =>
      args.context = args.context.set_after(convert_usize(v.unwrap_value()))
    "before-context" =>
      args.context = args.context.set_before(convert_usize(v.unwrap_value()))
    "binary" =>
      args.binary = if v.unwrap_switch() { SearchAndSuppress } else { Auto }
    "block-buffered" =>
      args.buffer = if v.unwrap_switch() { Block } else { Auto }
    "byte-offset" => args.byte_offset = v.unwrap_switch()
    "case-sensitive" => args.case = Sensitive
    "color" =>
      args.color = match v.unwrap_value() {
        "never" => Never
        "auto" => Auto
        "always" => Always
        "ansi" => Ansi
        unk => raise RgError("choice '\{unk}' is unrecognized")
      }
    "colors" => {
      let spec = v.unwrap_value()
      validate_color_spec(spec)
      args.colors.push(spec)
    }
    "column" => args.column = Some(v.unwrap_switch())
    "context" =>
      args.context = args.context.set_both(convert_usize(v.unwrap_value()))
    "context-separator" =>
      args.context_separator = match v {
        Switch(true) => abort("flag can only be disabled")
        Switch(false) => None
        Value(s) => Some(@cli.unescape(s))
      }
    "count" => args.mode = args.mode.updated(Search(Count))
    "count-matches" => args.mode = args.mode.updated(Search(CountMatches))
    "crlf" => {
      args.crlf = v.unwrap_switch()
      if args.crlf {
        args.null_data = false
      }
    }
    "debug" => args.logging = Some(Debug)
    "dfa-size-limit" =>
      args.dfa_size_limit = Some(convert_human_readable_u64(v.unwrap_value()))
    "encoding" =>
      match v {
        Value(label) =>
          args.encoding = match label {
            "auto" => Auto
            "none" => Disabled
            _ =>
              Specific(
                @searcher.Encoding::new(label) catch {
                  e => raise RgError(e.to_string())
                },
              )
          }
        Switch(true) => abort("--encoding must accept a value")
        Switch(false) => args.encoding = Auto
      }
    "engine" => {
      let s = v.unwrap_value()
      args.engine = match s {
        "default" => Default
        "pcre2" => PCRE2
        "auto" => Auto
        _ => raise RgError("unrecognized regex engine '\{s}'")
      }
    }
    "field-context-separator" =>
      args.field_context_separator = @cli.unescape(v.unwrap_value())
    "field-match-separator" =>
      args.field_match_separator = @cli.unescape(v.unwrap_value())
    "files" => args.mode = args.mode.updated(Files)
    "files-with-matches" =>
      args.mode = args.mode.updated(Search(FilesWithMatches))
    "files-without-match" =>
      args.mode = args.mode.updated(Search(FilesWithoutMatch))
    "fixed-strings" => args.fixed_strings = v.unwrap_switch()
    "follow" => args.follow = v.unwrap_switch()
    "generate" => {
      let genmode = match v.unwrap_value() {
        "man" => GenerateMode::Man
        "complete-bash" => CompleteBash
        "complete-zsh" => CompleteZsh
        "complete-fish" => CompleteFish
        "complete-powershell" => CompletePowerShell
        unk => raise RgError("choice '\{unk}' is unrecognized")
      }
      args.mode = args.mode.updated(Generate(genmode))
    }
    "glob" => args.globs.push(v.unwrap_value())
    "glob-case-insensitive" => args.glob_case_insensitive = v.unwrap_switch()
    "heading" => args.heading = Some(v.unwrap_switch())
    "help" => ()
    "hidden" => args.hidden = v.unwrap_switch()
    "hostname-bin" => {
      let path = v.unwrap_value()
      args.hostname_bin = if path.is_empty() { None } else { Some(path) }
    }
    "hyperlink-format" => {
      let s = v.unwrap_value()
      with_context("invalid hyperlink format", () => {
        validate_hyperlink_format(s)
      })
      args.hyperlink_format = s
    }
    "iglob" => args.iglobs.push(v.unwrap_value())
    "ignore-case" => args.case = Insensitive
    "ignore-file" => args.ignore_file.push(v.unwrap_value())
    "ignore-file-case-insensitive" =>
      args.ignore_file_case_insensitive = v.unwrap_switch()
    "include-zero" => args.include_zero = v.unwrap_switch()
    "index" => {
      check_indexing_allowed()
      args.index += 1
      if args.index > 2 {
        raise RgError("-X/--index may be given at most twice")
      }
    }
    "x-crud" => {
      check_indexing_allowed()
      args.mode = args.mode.updated(Index(Crud))
    }
    "x-force" => {
      check_indexing_allowed()
      args.index_force = true
    }
    "x-path" => {
      check_indexing_allowed()
      args.index_path = Some(v.unwrap_value())
    }
    "invert-match" => args.invert_match = v.unwrap_switch()
    "json" =>
      if v.unwrap_switch() {
        args.mode = args.mode.updated(Search(JSON))
      } else if args.mode is Search(JSON) {
        args.mode = args.mode.updated(Search(Standard))
      }
    "line-buffered" => args.buffer = if v.unwrap_switch() { Line } else { Auto }
    "line-number" => args.line_number = Some(true)
    "no-line-number" => args.line_number = Some(false)
    "line-regexp" => args.boundary = Some(Line)
    "max-columns" => {
      let max = convert_u64(v.unwrap_value())
      args.max_columns = if max == 0 { None } else { Some(max) }
    }
    "max-columns-preview" => args.max_columns_preview = v.unwrap_switch()
    "max-count" => args.max_count = Some(convert_u64(v.unwrap_value()))
    "max-depth" => args.max_depth = Some(convert_usize(v.unwrap_value()))
    "max-filesize" =>
      args.max_filesize = Some(convert_human_readable_u64(v.unwrap_value()))
    "mmap" => args.mmap = if v.unwrap_switch() { AlwaysTryMmap } else { Never }
    "multiline" => {
      args.multiline = v.unwrap_switch()
      if args.multiline {
        args.stop_on_nonmatch = false
      }
    }
    "multiline-dotall" => args.multiline_dotall = v.unwrap_switch()
    "no-config" => args.no_config = true
    "no-ignore" => {
      let yes = v.unwrap_switch()
      args.no_ignore_dot = yes
      args.no_ignore_exclude = yes
      args.no_ignore_global = yes
      args.no_ignore_parent = yes
      args.no_ignore_vcs = yes
    }
    "no-ignore-dot" => args.no_ignore_dot = v.unwrap_switch()
    "no-ignore-exclude" => args.no_ignore_exclude = v.unwrap_switch()
    "no-ignore-files" => args.no_ignore_files = v.unwrap_switch()
    "no-ignore-global" => args.no_ignore_global = v.unwrap_switch()
    "no-ignore-messages" => args.no_ignore_messages = v.unwrap_switch()
    "no-ignore-parent" => args.no_ignore_parent = v.unwrap_switch()
    "no-ignore-vcs" => args.no_ignore_vcs = v.unwrap_switch()
    "no-messages" => args.no_messages = v.unwrap_switch()
    "no-require-git" => args.no_require_git = v.unwrap_switch()
    "no-unicode" => args.no_unicode = v.unwrap_switch()
    "null" => args.null = true
    "null-data" => {
      args.crlf = false
      args.null_data = true
    }
    "one-file-system" => args.one_file_system = v.unwrap_switch()
    "only-matching" => args.only_matching = true
    "path-separator" => {
      let s = v.unwrap_value()
      let raw = @cli.unescape(s)
      args.path_separator = if raw.length() == 0 {
        None
      } else if raw.length() == 1 {
        Some(raw[0])
      } else {
        raise RgError(
          "A path separator must be exactly one byte, but the given separator is \{raw.length()} bytes: \{s}\nIn some shells on Windows '/' is automatically expanded. Use '//' instead.",
        )
      }
    }
    "passthru" => args.context = Passthru
    "pcre2" => args.engine = if v.unwrap_switch() { PCRE2 } else { Default }
    "pcre2-version" => args.special = Some(VersionPCRE2)
    "pre" =>
      match v {
        Value(path) => {
          args.pre = if path.is_empty() { None } else { Some(path) }
          if args.pre is Some(_) {
            args.search_zip = false
          }
        }
        Switch(_) => args.pre = None
      }
    "pre-glob" => args.pre_glob.push(v.unwrap_value())
    "pretty" => {
      args.color = Always
      args.heading = Some(true)
      args.line_number = Some(true)
    }
    "quiet" => args.quiet = true
    "regex-size-limit" =>
      args.regex_size_limit = Some(convert_human_readable_u64(v.unwrap_value()))
    "replace" => args.replace = Some(@utf8.encode(v.unwrap_value()))
    "search-zip" =>
      args.search_zip = if v.unwrap_switch() {
        args.pre = None
        true
      } else {
        false
      }
    "smart-case" => args.case = Smart
    "sort" =>
      args.sort = match sort_kind(v.unwrap_value()) {
        None => None
        Some(kind) => Some({ reverse: false, kind, })
      }
    "sortr" =>
      args.sort = match sort_kind(v.unwrap_value()) {
        None => None
        Some(kind) => Some({ reverse: true, kind, })
      }
    "stats" => args.stats = v.unwrap_switch()
    "stop-on-nonmatch" => {
      args.stop_on_nonmatch = true
      args.multiline = false
    }
    "text" => args.binary = if v.unwrap_switch() { AsText } else { Auto }
    "threads" => {
      let threads = convert_usize(v.unwrap_value())
      args.threads = if threads == 0 { None } else { Some(threads) }
    }
    "trace" => args.logging = Some(Trace)
    "trim" => args.trim = v.unwrap_switch()
    "type" => args.type_changes.push(Select(v.unwrap_value()))
    "type-not" => args.type_changes.push(Negate(v.unwrap_value()))
    "type-add" => args.type_changes.push(Add(v.unwrap_value()))
    "type-clear" => args.type_changes.push(Clear(v.unwrap_value()))
    "type-list" => args.mode = args.mode.updated(Types)
    "unrestricted" => {
      args.unrestricted += 1
      if args.unrestricted > 3 {
        raise RgError("flag can only be repeated up to 3 times")
      }
      let name = match args.unrestricted {
        1 => "no-ignore"
        2 => "hidden"
        _ => "binary"
      }
      update_flag(lookup_flag(name).unwrap(), Switch(true), args)
    }
    "version" => ()
    "vimgrep" => args.vimgrep = true
    "with-filename" => args.with_filename = Some(true)
    "no-filename" => args.with_filename = Some(false)
    "word-regexp" => args.boundary = Some(Word)
    "auto-hybrid-regex" =>
      args.engine = if v.unwrap_switch() { Auto } else { Default }
    "no-pcre2-unicode" => args.no_unicode = v.unwrap_switch()
    "sort-files" =>
      args.sort = if v.unwrap_switch() {
        Some({ reverse: false, kind: Path, })
      } else {
        None
      }
    other => abort("unhandled flag --\{other}")
  }
}

///|
/// Returns the first flag that doesn't support indexing, if any is set.
fn LowArgs::indexing_unsupported_flag(self : LowArgs) -> String? {
  if self.mode is Search(FilesWithoutMatch) {
    return Some("files-without-match")
  }
  if self.binary is AsText {
    return Some("binary")
  }
  if !(self.encoding is Auto) {
    return Some("encoding")
  }
  if self.engine is PCRE2 {
    return Some("engine")
  }
  if self.follow {
    return Some("follow")
  }
  if !self.globs.is_empty() {
    return Some("glob")
  }
  if self.hidden {
    return Some("hidden")
  }
  if !self.iglobs.is_empty() {
    return Some("glob")
  }
  if !self.ignore_file.is_empty() {
    return Some("ignore-file")
  }
  None
}
