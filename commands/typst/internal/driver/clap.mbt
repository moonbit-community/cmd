// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// A small command line parser in the style of `clap` (which upstream
// typst-cli uses): long and short options, `--opt=value` / `--opt value` /
// `-oVALUE` / `-o value`, flags, options with optional values (that
// require `=`), environment variable fallbacks, value delimiters, `--` and
// positional arguments. Errors and help are formatted like clap's (the
// wording of clap's messages is approximated; they are not Typst messages).

///|
/// How an argument takes values.
priv enum ArgKind {
  /// A flag without a value (counted).
  Flag
  /// An option with a value.
  Value
  /// An option whose value is optional and must be attached with `=`
  /// (`num_args = 0..=1, require_equals = true`); a bare occurrence takes
  /// `missing` as its value.
  OptionalValue(String)
  /// An option declared with a `default_missing_value` but without
  /// `num_args = 0..=1` (upstream's `--color`): clap checks the number of
  /// values before it applies that default, so the value is required and
  /// the option parses like `Value`.
  LooseValue
}

///|
/// How an empty value (`--opt ''`, `--opt=` or an empty environment
/// variable) is treated, like clap's value parsers.
priv enum EmptyMode {
  /// Rejected ("a value is required ... but none was supplied"), like
  /// clap's `PathBufValueParser` and `ValueEnum` parsers.
  Required
  /// Passed to the option's own parser.
  Pass
}

///|
/// An option or flag.
priv struct ArgSpec {
  id : String
  long : String
  short : Char?
  kind : ArgKind
  env : String?
  delimiter : Char?
  value_name : String
  help : String
  possible : Array[String]
  hidden : Bool
  empty : EmptyMode
  /// The option's value parser, run when a value is consumed.
  validate : ((String) -> Unit raise CliError)?
  /// Whether the option may occur multiple times (`ArgAction::Append`).
  multiple : Bool
}

///|
fn flag(
  id : String,
  short? : Char,
  env? : String,
  hidden~ : Bool = false,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short,
    kind: Flag,
    env,
    delimiter: None,
    value_name: "",
    help,
    possible: [],
    hidden,
    empty: Required,
    validate: None,
    multiple: false,
  }
}

///|
fn opt(
  id : String,
  value_name : String,
  short? : Char,
  env? : String,
  delimiter? : Char,
  possible~ : Array[String] = [],
  hidden~ : Bool = false,
  empty~ : EmptyMode = Required,
  validate? : (String) -> Unit raise CliError,
  multiple~ : Bool = false,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short,
    kind: Value,
    env,
    delimiter,
    value_name,
    help,
    possible,
    hidden,
    empty,
    validate,
    multiple,
  }
}

///|
fn opt_optional(
  id : String,
  value_name : String,
  missing : String,
  possible~ : Array[String] = [],
  empty~ : EmptyMode = Required,
  hidden~ : Bool = false,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short: None,
    kind: OptionalValue(missing),
    env: None,
    delimiter: None,
    value_name,
    help,
    possible,
    hidden,
    empty,
    validate: None,
    multiple: false,
  }
}

///|
/// A positional argument.
priv struct PosSpec {
  name : String
  required : Bool
  help : String
  /// The positional's value parser, run when the value is consumed.
  validate : ((String) -> Unit raise CliError)?
}

///|
/// A command: its options and positional arguments.
priv struct CommandSpec {
  /// The subcommand name (empty for the main command), to look up its help.
  key : String
  /// The full command path for usage lines (e.g. `typst compile`).
  path : String
  about : String
  args : Array[ArgSpec]
  positionals : Array[PosSpec]
  /// Subcommands: name, aliases, about.
  subcommands : Array[(String, Array[String], String, Bool)]
}

///|
/// The result of parsing.
priv struct Matches {
  values : Map[String, Array[String]]
  counts : Map[String, Int32]
  positionals : Array[String]
  /// The subcommand name and its remaining arguments.
  subcommand : (String, Array[String])?
  /// The parse state, for values pending until after a subcommand.
  state : ParseState
}

///|
/// Parses the values that are pending after a subcommand (clap does this
/// after parsing the subcommand's arguments).
fn Matches::resolve_pending(self : Matches) -> Unit raise CliError {
  self.state.resolve_pending()
  self.state.apply_env()
}

///|
fn Matches::value(self : Matches, id : String) -> String? {
  match self.values.get(id) {
    Some(values) if values.length() > 0 => Some(values[values.length() - 1])
    _ => None
  }
}

///|
fn Matches::all(self : Matches, id : String) -> Array[String] {
  self.values.get(id).unwrap_or([])
}

///|
fn Matches::flag(self : Matches, id : String) -> Bool {
  self.counts.get(id).unwrap_or(0) > 0
}

///|
fn Matches::positional(self : Matches, i : Int32) -> String? {
  if i < self.positionals.length() {
    Some(self.positionals[i])
  } else {
    None
  }
}

///|
/// A command line error (clap's `Error`): the message and whether it is
/// help or version output (printed to stdout with exit code 0).
priv suberror CliError {
  /// A usage error: message (without `error: `) and usage line.
  Usage(String, String)
  /// An invalid value error (no usage line).
  Invalid(String)
  /// Help or version text to print to stdout.
  Display(String)
  /// No subcommand was given (clap's
  /// `DisplayHelpOnMissingArgumentOrSubcommand`).
  MissingSubcommand
}

///|
fn CommandSpec::usage(self : CommandSpec) -> String {
  // The usage line of the upstream help.
  if help_text(self.key, false) is Some(text) {
    for line in text.split("\n") {
      if line.has_prefix("Usage: ") {
        return line[7:].to_owned()
      }
    }
  }
  let buf = StringBuilder()
  buf.write_string(self.path)
  if self.args.length() > 0 {
    buf.write_string(" [OPTIONS]")
  }
  for pos in self.positionals {
    if pos.required {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  if self.subcommands.length() > 0 {
    buf.write_string(" <COMMAND>")
  }
  buf.to_string()
}

///|
fn ArgSpec::display(self : ArgSpec) -> String {
  match self.kind {
    Flag => "--\{self.long}"
    Value | LooseValue => "--\{self.long} <\{self.value_name}>"
    OptionalValue(_) => "--\{self.long}[=<\{self.value_name}>]"
  }
}

///|
/// The usage line with only the required arguments (clap's required usage,
/// shown when arguments are missing). `output_required` marks `[OUTPUT]` as
/// required (for input from stdin).
fn CommandSpec::required_usage(
  self : CommandSpec,
  output_required~ : Bool = false,
) -> String {
  let buf = StringBuilder()
  buf.write_string(self.path)
  for pos in self.positionals {
    if pos.required || (output_required && pos.name == "OUTPUT") {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  buf.to_string()
}

///|
/// The upstream help text of a command (see `help_gen.mbt`).
fn help_text(key : String, long : Bool) -> String? {
  for entry in help_texts[:] {
    if entry.0 == key && entry.1 == long {
      return Some(entry.2 + "\n")
    }
  }
  None
}

///|
/// The help of a command: upstream's text, or a rendering of the spec.
fn CommandSpec::help(self : CommandSpec, long~ : Bool = true) -> String {
  if self.key == "" {
    return command_help + "\n"
  }
  match help_text(self.key, long) {
    Some(text) => text
    None => self.render_help()
  }
}

///|
/// Renders the help of a command.
fn CommandSpec::render_help(self : CommandSpec) -> String {
  let buf = StringBuilder()
  if self.about != "" {
    buf.write_string("\{self.about}\n\n")
  }
  buf.write_string("Usage: \{self.usage()}\n")
  if self.subcommands.length() > 0 {
    buf.write_string("\nCommands:\n")
    let mut width = 4
    for sub in self.subcommands {
      if !sub.3 && sub.0.length() > width {
        width = sub.0.length()
      }
    }
    for sub in self.subcommands {
      if sub.3 {
        continue
      }
      let (name, aliases, about, _) = sub
      buf.write_string("  \{name}")
      buf.write_string(" ".repeat(width - name.length() + 2))
      buf.write_string(about)
      if aliases.length() > 0 {
        buf.write_string(" [aliases: \{aliases.join(", ")}]")
      }
      buf.write_char('\n')
    }
    buf.write_string("  help")
    buf.write_string(" ".repeat(width - 4 + 2))
    buf.write_string(
      "Print this message or the help of the given subcommand(s)\n",
    )
  }
  if self.positionals.length() > 0 {
    buf.write_string("\nArguments:\n")
    for pos in self.positionals {
      let name = if pos.required { "<\{pos.name}>" } else { "[\{pos.name}]" }
      buf.write_string("  \{name}\n          \{pos.help}\n\n")
    }
  }
  buf.write_string("\nOptions:\n")
  for arg in self.args {
    if arg.hidden {
      continue
    }
    let short = match arg.short {
      Some(c) => "-\{c}, "
      None => ""
    }
    buf.write_string("  \{short}\{arg.display()}\n          \{arg.help}\n")
    if arg.possible.length() > 0 {
      buf.write_string(
        "          \n          [possible values: \{arg.possible.join(", ")}]\n",
      )
    }
    if arg.env is Some(env) {
      buf.write_string("          \n          [env: \{env}=]\n")
    }
    buf.write_char('\n')
  }
  buf.write_string(
    "  -h, --help\n          Print help (see a summary with '-h')\n",
  )
  if self.subcommands.length() > 0 {
    buf.write_string("\n  -V, --version\n          Print version\n")
  }
  buf.to_string()
}

///|
/// Parses arguments for a command. Subcommand dispatch stops at the first
/// positional when the command has subcommands.
///
/// Like clap, a separate option value (`--opt value`) is only parsed when the
/// next known option or positional is processed, at the end of the
/// arguments or, for a value given before a subcommand, after the
/// subcommand's arguments were parsed (`Matches::resolve_pending`). Unknown
/// options are reported before pending values are parsed.
fn CommandSpec::parse(
  self : CommandSpec,
  argv : Array[String],
) -> Matches raise CliError {
  let state : ParseState = {
    spec: self,
    values: Map([]),
    counts: Map([]),
    occurrences: Map([]),
    used: [],
    pending: [],
  }
  let positionals = []
  let mut subcommand = None
  let mut i = 0
  let mut only_positional = false
  let unexpected = (arg : String, long : Bool) => {
    let tip = if self.positionals.is_empty() {
      ""
    } else {
      "\n\n  tip: to pass '\{arg}' as a value, use '-- \{arg}'"
    }
    // clap shows the usage of the used arguments for unknown long options
    // and the generic usage for unknown short options.
    let usage = if long {
      self.smart_usage(state.used_ids(), positionals.length())
    } else {
      self.usage()
    }
    Usage("unexpected argument '\{arg}' found\{tip}", usage)
  }
  let find_long = (name : String) => self.args.search_by(a => a.long == name)
  let find_short = (c : Char) => self.args.search_by(a => a.short == Some(c))
  let separate_value = () => {
    if i < argv.length() && !(argv[i].has_prefix("-") && argv[i] != "-") {
      let value = argv[i]
      i += 1
      Some(value)
    } else {
      None
    }
  }
  while i < argv.length() {
    let arg = argv[i]
    i += 1
    if only_positional || arg == "-" || !arg.has_prefix("-") {
      if self.subcommands.length() > 0 && !only_positional {
        let known = arg == "help" ||
          self.subcommands.any(s => s.0 == arg || s.1.contains(arg))
        if !known {
          raise Usage("unrecognized subcommand '\{arg}'", self.usage())
        }
        subcommand = Some((arg, argv[i:].to_owned()))
        break
      }
      state.resolve_pending()
      // Excess positionals are rejected when consumed.
      if positionals.length() >= self.positionals.length() {
        raise Usage("unexpected argument '\{arg}' found", self.usage())
      }
      if self.positionals[positionals.length()].validate is Some(validate) {
        validate(arg)
      }
      positionals.push(arg)
      continue
    }
    if arg == "--" {
      state.resolve_pending()
      only_positional = true
      continue
    }
    if arg.has_prefix("--") {
      let body = arg[2:].to_owned()
      let (name, attached) = match body.find("=") {
        Some(eq) => (body[:eq].to_owned(), Some(body[eq + 1:].to_owned()))
        None => (body, None)
      }
      if name == "help" || (name == "version" && self.subcommands.length() > 0) {
        state.resolve_pending()
        if attached is Some(value) {
          state.used.push(name)
          raise Usage(
            "unexpected value '\{value}' for '--\{name}' found; no more were expected",
            self.smart_usage(state.used_ids(), positionals.length()),
          )
        }
        if name == "help" {
          raise Display(self.help(long=true))
        }
        raise Display(version_line() + "\n")
      }
      guard find_long(name) is Some(index) else { raise unexpected(arg, true) }
      state.resolve_pending()
      let spec = self.args[index]
      match spec.kind {
        Flag => {
          if attached is Some(value) {
            state.start(spec)
            raise Usage(
              "unexpected value '\{value}' for '\{spec.display()}' found; no more were expected",
              self.smart_usage(state.used_ids(), positionals.length()),
            )
          }
          state.flag(spec)
        }
        OptionalValue(missing) =>
          state.occurrence(spec, Some(attached.unwrap_or(missing)), true)
        LooseValue | Value =>
          match attached {
            Some(value) => state.occurrence(spec, Some(value), true)
            None => state.occurrence(spec, separate_value(), false)
          }
      }
      continue
    }
    // Short options.
    let chars = arg[1:].to_owned().to_array()
    let mut k = 0
    while k < chars.length() {
      let c = chars[k]
      k += 1
      if c == 'h' {
        state.resolve_pending()
        raise Display(self.help(long=false))
      }
      if c == 'V' && self.subcommands.length() > 0 {
        state.resolve_pending()
        raise Display(version_line() + "\n")
      }
      guard find_short(c) is Some(index) else {
        raise unexpected("-\{c}", false)
      }
      state.resolve_pending()
      let spec = self.args[index]
      match spec.kind {
        Flag | OptionalValue(_) | LooseValue => state.flag(spec)
        Value => {
          let rest = String::from_array(chars[k:])
          if rest.has_prefix("=") {
            state.occurrence(spec, Some(rest[1:].to_owned()), true)
          } else if rest != "" {
            state.occurrence(spec, Some(rest), true)
          } else {
            state.occurrence(spec, separate_value(), false)
          }
          break
        }
      }
    }
  }
  if subcommand is None {
    state.resolve_pending()
  }

  // Environment variable fallbacks (for a command with a subcommand, after
  // the subcommand's arguments were parsed, like pending values).
  if subcommand is None {
    state.apply_env()
  }
  if positionals.length() > self.positionals.length() {
    raise Usage(
      "unexpected argument '\{positionals[self.positionals.length()]}' found",
      self.usage(),
    )
  }
  {
    values: state.values,
    counts: state.counts,
    positionals,
    subcommand,
    state,
  }
}

///|
/// The state of parsing a command's arguments.
priv struct ParseState {
  spec : CommandSpec
  values : Map[String, Array[String]]
  counts : Map[String, Int32]
  /// How often each option occurred.
  occurrences : Map[String, Int32]
  /// The options in the order of their first occurrence.
  used : Array[String]
  /// Separate values (or their absence) that are not parsed yet.
  pending : Array[(ArgSpec, String?)]
}

///|
/// The options that count as used for clap's usage: present with a value
/// (a repeated single-value option restarts and is not present until its
/// new value is parsed).
fn ParseState::used_ids(self : ParseState) -> Array[String] {
  self.used.filter(id => {
    match self.pending.iter().find_first(p => p.0.id == id) {
      Some((spec, value)) =>
        value is Some(_) &&
        (spec.multiple || self.occurrences.get(id).unwrap_or(0) <= 1)
      None => true
    }
  })
}

///|
/// Records an occurrence of an option.
fn ParseState::start(self : ParseState, spec : ArgSpec) -> Unit {
  let n = self.occurrences.get(spec.id).unwrap_or(0) + 1
  self.occurrences[spec.id] = n
  if !self.used.contains(spec.id) {
    self.used.push(spec.id)
  }
}

///|
/// The error for a repeated single-value option.
fn ParseState::check_repeat(
  self : ParseState,
  spec : ArgSpec,
) -> Unit raise CliError {
  if !spec.multiple && self.values.contains(spec.id) {
    raise Usage(
      "the argument '\{spec.display()}' cannot be used multiple times",
      self.spec.usage(),
    )
  }
}

///|
/// A flag occurrence.
fn ParseState::flag(self : ParseState, spec : ArgSpec) -> Unit raise CliError {
  self.start(spec)
  if self.counts.contains(spec.id) {
    raise Usage(
      "the argument '\{spec.display()}' cannot be used multiple times",
      self.spec.usage(),
    )
  }
  self.counts[spec.id] = 1
}

///|
/// An option occurrence: an attached value is parsed immediately, a
/// separate one (or its absence) when pending values are resolved.
fn ParseState::occurrence(
  self : ParseState,
  spec : ArgSpec,
  value : String?,
  attached : Bool,
) -> Unit raise CliError {
  self.start(spec)
  if attached {
    self.check_repeat(spec)
    self.push_values(spec, value.unwrap())
  } else {
    self.pending.push((spec, value))
  }
}

///|
/// Parses the pending values.
fn ParseState::resolve_pending(self : ParseState) -> Unit raise CliError {
  let pending = self.pending.copy()
  self.pending.clear()
  for entry in pending {
    let (spec, value) = entry
    guard value is Some(value) else {
      raise Invalid(
        "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
      )
    }
    self.check_repeat(spec)
    self.push_values(spec, value)
  }
}

///|
/// Parses and records a value (split at the option's delimiter).
fn ParseState::push_values(
  self : ParseState,
  spec : ArgSpec,
  value : String,
) -> Unit raise CliError {
  match spec.delimiter {
    Some(d) =>
      for part in value.split(d.to_string()) {
        self.push_value(spec, part.to_owned())
      }
    None => self.push_value(spec, value)
  }
}

///|
/// Parses and records a single value (clap's value parser).
fn ParseState::push_value(
  self : ParseState,
  spec : ArgSpec,
  value : String,
) -> Unit raise CliError {
  if value == "" && spec.empty is Required {
    raise Invalid(
      "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
    )
  }
  if spec.validate is Some(validate) {
    validate(value)
  }
  if spec.possible.length() > 0 && !spec.possible.contains(value) {
    raise Invalid(
      "invalid value '\{value}' for '\{spec.display()}'\n  [possible values: \{spec.possible.join(", ")}]",
    )
  }
  match self.values.get(spec.id) {
    Some(list) => list.push(value)
    None => self.values[spec.id] = [value]
  }
}

///|
/// The possible values line of an error (empty if there are none).
fn possible_values(spec : ArgSpec) -> String {
  if spec.possible.is_empty() {
    ""
  } else {
    "\n  [possible values: \{spec.possible.join(", ")}]"
  }
}

///|
/// Raises a missing-argument error.
fn missing(spec : CommandSpec, name : String) -> CliError {
  Usage(
    "the following required arguments were not provided:\n  <\{name}>",
    spec.required_usage(),
  )
}

///|
/// clap's usage for errors once arguments were used: the used options (in
/// the order of their first occurrence) and the positionals (required or
/// given ones as `<NAME>`, others as `[NAME]`).
fn CommandSpec::smart_usage(
  self : CommandSpec,
  used : Array[String],
  num_positionals : Int32,
) -> String {
  if used.is_empty() && num_positionals == 0 {
    return self.usage()
  }
  let buf = StringBuilder()
  buf.write_string(self.path)
  for id in used {
    if self.args.iter().find_first(a => a.id == id) is Some(arg) {
      buf.write_string(" \{arg.display()}")
    } else if id == "help" || id == "version" {
      buf.write_string(" --\{id}")
    }
  }
  for i, pos in self.positionals {
    if pos.required || i < num_positionals {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  if self.subcommands.length() > 0 {
    buf.write_string(" <COMMAND>")
  }
  buf.to_string()
}

///|
/// Applies the environment variable fallbacks of the options.
fn ParseState::apply_env(self : ParseState) -> Unit raise CliError {
  for spec in self.spec.args {
    guard spec.env is Some(env) else { continue }
    guard @platform.env_var(env) is Some(value) else { continue }
    match spec.kind {
      Flag =>
        if !self.counts.contains(spec.id) {
          // clap's `BoolValueParser`.
          match value {
            "true" => self.counts[spec.id] = 1
            "false" => ()
            "" =>
              raise Invalid(
                "a value is required for '\{spec.display()}' but none was supplied\n  [possible values: true, false]",
              )
            _ =>
              raise Invalid(
                "invalid value '\{value}' for '\{spec.display()}'\n  [possible values: true, false]",
              )
          }
        }
      _ =>
        if !self.values.contains(spec.id) &&
          !self.pending.any(p => p.0.id == spec.id) {
          self.push_values(spec, value)
        }
    }
  }
}
