///|
/// Hyperlink configuration.
///
/// This configuration specifies both the hyperlink format and the
/// environment for interpolating a subset of variables.
pub struct HyperlinkConfig {
  priv env : HyperlinkEnvironment
  priv format : HyperlinkFormat
}

///|
/// Returns a new hyperlink config from the given environment and format.
pub fn HyperlinkConfig::new(
  env : HyperlinkEnvironment,
  format : HyperlinkFormat,
) -> HyperlinkConfig {
  { env, format, }
}

///|
/// The default hyperlink config, which disables hyperlinks.
pub fn HyperlinkConfig::default() -> HyperlinkConfig {
  { env: HyperlinkEnvironment::new(), format: HyperlinkFormat::empty(), }
}

///|
/// Returns the hyperlink environment in this configuration.
pub fn HyperlinkConfig::environment(
  self : HyperlinkConfig,
) -> HyperlinkEnvironment {
  self.env
}

///|
/// Returns the hyperlink format in this configuration.
pub fn HyperlinkConfig::format(self : HyperlinkConfig) -> HyperlinkFormat {
  self.format
}

///|
/// A hyperlink format with variables.
///
/// This can be created by parsing a string using `HyperlinkFormat::parse`.
/// The empty format is valid and corresponds to disabling hyperlinks.
pub struct HyperlinkFormat {
  priv parts : Array[Part]
  priv is_line_dependent : Bool
} derive(Eq, Debug)

///|
/// Creates an empty hyperlink format.
pub fn HyperlinkFormat::empty() -> HyperlinkFormat {
  { parts: [], is_line_dependent: false, }
}

///|
/// Returns true if this format is empty.
pub fn HyperlinkFormat::is_empty(self : HyperlinkFormat) -> Bool {
  self.parts.is_empty()
}

///|
/// Creates a `HyperlinkConfig` from this format and the environment given.
pub fn HyperlinkFormat::into_config(
  self : HyperlinkFormat,
  env : HyperlinkEnvironment,
) -> HyperlinkConfig {
  HyperlinkConfig::new(env, self)
}

///|
/// Returns true if this format is line dependent (contains `{line}`).
pub fn HyperlinkFormat::is_line_dependent(self : HyperlinkFormat) -> Bool {
  self.is_line_dependent
}

///|
priv enum ParseState {
  Verbatim
  VerbatimCloseVariable
  OpenVariable
  InVariable
}

///|
/// Parses a hyperlink format (or the name of an alias, e.g. `vscode`).
pub fn HyperlinkFormat::parse(
  s : String,
) -> HyperlinkFormat raise HyperlinkFormatError {
  let builder = FormatBuilder::new()
  let input = match HyperlinkAlias::find(s) {
    Some(al) => al.format
    None => s
  }
  let name = StringBuilder()
  let mut state = Verbatim
  for ch in input {
    state = match state {
      Verbatim =>
        if ch == '{' {
          OpenVariable
        } else if ch == '}' {
          VerbatimCloseVariable
        } else {
          builder.append_char(ch)
          Verbatim
        }
      VerbatimCloseVariable =>
        if ch == '}' {
          builder.append_char('}')
          Verbatim
        } else {
          raise HyperlinkFormatError(InvalidCloseVariable)
        }
      OpenVariable =>
        if ch == '{' {
          builder.append_char('{')
          Verbatim
        } else {
          name.reset()
          if ch == '}' {
            builder.append_var(name.to_string())
            Verbatim
          } else {
            name.write_char(ch)
            InVariable
          }
        }
      InVariable =>
        if ch == '}' {
          builder.append_var(name.to_string())
          Verbatim
        } else {
          name.write_char(ch)
          InVariable
        }
    }
  }
  match state {
    Verbatim => builder.build()
    VerbatimCloseVariable => raise HyperlinkFormatError(InvalidCloseVariable)
    OpenVariable | InVariable => raise HyperlinkFormatError(UnclosedVariable)
  }
}

///|
pub impl Show for HyperlinkFormat with fn output(self, logger) {
  for part in self.parts {
    Show::output(part, logger)
  }
}

///|
/// Formats this hyperlink format back into its string form (with any alias
/// expanded).
pub fn HyperlinkFormat::to_string(self : HyperlinkFormat) -> String {
  let sb = StringBuilder()
  Show::output(self, sb)
  sb.to_string()
}

///|
/// An alias for a hyperlink format.
pub struct HyperlinkAlias {
  priv name : String
  priv description : String
  priv format : String
  priv display_priority : Int32?
} derive(Debug)

///|
/// Returns the name of the alias.
pub fn HyperlinkAlias::name(self : HyperlinkAlias) -> String {
  self.name
}

///|
/// Returns a very short description of this hyperlink alias.
pub fn HyperlinkAlias::description(self : HyperlinkAlias) -> String {
  self.description
}

///|
/// Returns the display priority of this alias (lower values first).
pub fn HyperlinkAlias::display_priority(self : HyperlinkAlias) -> Int32? {
  self.display_priority
}

///|
/// Returns the format string of this alias.
pub fn HyperlinkAlias::format(self : HyperlinkAlias) -> String {
  self.format
}

///|
fn HyperlinkAlias::find(name : String) -> HyperlinkAlias? {
  for al in hyperlink_pattern_aliases {
    if al.name == name {
      return Some(al)
    }
  }
  None
}

///|
/// Returns all available hyperlink aliases, sorted by name.
pub fn hyperlink_aliases() -> Array[HyperlinkAlias] {
  hyperlink_pattern_aliases.copy()
}

///|
/// A static environment for hyperlink interpolation.
///
/// This environment permits setting the values of variables used in
/// hyperlink interpolation that are not expected to change for the lifetime
/// of a program (`{host}` and `{wslprefix}`).
///
/// Unlike the Rust implementation, this port does not touch the file
/// system. Instead, the function used to turn a printed path into an
/// absolute, canonical path (Rust uses `Path::canonicalize`) is provided via
/// `HyperlinkEnvironment::canonicalize`. When no such function is set, only
/// paths that are already absolute (start with `/`) get hyperlinks, and they
/// are used verbatim.
pub struct HyperlinkEnvironment {
  priv mut host : String?
  priv mut wsl_prefix : String?
  priv mut canonicalize : (async (String) -> String?)?
}

///|
/// Create a new empty hyperlink environment.
pub fn HyperlinkEnvironment::new() -> HyperlinkEnvironment {
  { host: None, wsl_prefix: None, canonicalize: None, }
}

///|
/// Set the `{host}` variable, which fills in any hostname components of a
/// hyperlink.
pub fn HyperlinkEnvironment::host(
  self : HyperlinkEnvironment,
  host : String?,
) -> HyperlinkEnvironment {
  self.host = host
  self
}

///|
/// Set the `{wslprefix}` variable, which contains the WSL prefix to use
/// to open files in the Windows file explorer.
pub fn HyperlinkEnvironment::wsl_prefix(
  self : HyperlinkEnvironment,
  wsl_prefix : String?,
) -> HyperlinkEnvironment {
  self.wsl_prefix = wsl_prefix
  self
}

///|
/// Set the function used to canonicalize a path before turning it into a
/// hyperlink. It should return `None` if canonicalization fails.
pub fn HyperlinkEnvironment::canonicalize(
  self : HyperlinkEnvironment,
  f : (async (String) -> String?)?,
) -> HyperlinkEnvironment {
  self.canonicalize = f
  self
}

///|
/// Returns the `{host}` value, if set.
pub fn HyperlinkEnvironment::get_host(self : HyperlinkEnvironment) -> String? {
  self.host
}

///|
/// Returns the `{wslprefix}` value, if set.
pub fn HyperlinkEnvironment::get_wsl_prefix(
  self : HyperlinkEnvironment,
) -> String? {
  self.wsl_prefix
}

///|
/// The kind of a hyperlink format error.
pub(all) enum HyperlinkFormatErrorKind {
  /// This occurs when there are zero variables in the format.
  NoVariables
  /// This occurs when the {path} variable is missing.
  NoPathVariable
  /// This occurs when the {line} variable is missing, while the {column}
  /// variable is present.
  NoLineVariable
  /// This occurs when an unknown variable is used.
  InvalidVariable(String)
  /// The format doesn't start with a valid scheme.
  InvalidScheme
  /// This occurs when an unopened variable is found.
  InvalidCloseVariable
  /// This occurs when an unclosed variable is found.
  UnclosedVariable
} derive(Eq, Debug)

///|
/// An error that can occur when parsing a hyperlink format.
pub(all) suberror HyperlinkFormatError {
  HyperlinkFormatError(HyperlinkFormatErrorKind)
} derive(Eq, Debug)

///|
pub fn HyperlinkFormatError::kind(
  self : HyperlinkFormatError,
) -> HyperlinkFormatErrorKind {
  let HyperlinkFormatError(kind) = self
  kind
}

///|
pub fn HyperlinkFormatError::to_string(self : HyperlinkFormatError) -> String {
  match self.kind() {
    NoVariables => {
      let aliases = hyperlink_aliases()
      // Stable insertion sort by display priority.
      let key = (a : HyperlinkAlias) => {
        match a.display_priority {
          Some(p) => p
          None => 32767
        }
      }
      for i in 1..<aliases.length() {
        let mut j = i
        while j > 0 && key(aliases[j - 1]) > key(aliases[j]) {
          let t = aliases[j - 1]
          aliases[j - 1] = aliases[j]
          aliases[j] = t
          j -= 1
        }
      }
      let names = aliases.map(a => a.name).join(", ")
      "at least a {path} variable is required in a hyperlink format, or otherwise use a valid alias: \{names}"
    }
    NoPathVariable => "the {path} variable is required in a hyperlink format"
    NoLineVariable =>
      "the hyperlink format contains a {column} variable, but no {line} variable is present"
    InvalidVariable(name) =>
      "invalid hyperlink format variable: '\{name}', choose from: path, line, column, host, wslprefix"
    InvalidScheme =>
      "the hyperlink format must start with a valid URL scheme, i.e., [0-9A-Za-z+-.]+:"
    InvalidCloseVariable =>
      "unopened variable: found '}' without a corresponding '{' preceding it"
    UnclosedVariable =>
      "unclosed variable: found '{' without a corresponding '}' following it"
  }
}

///|
pub impl Show for HyperlinkFormatError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// A builder for `HyperlinkFormat`.
priv struct FormatBuilder {
  parts : Array[Part]
}

///|
fn FormatBuilder::new() -> FormatBuilder {
  { parts: [], }
}

///|
fn FormatBuilder::append_slice(
  self : FormatBuilder,
  text : String,
) -> FormatBuilder {
  match self.parts.last() {
    Some(Text(contents)) =>
      self.parts[self.parts.length() - 1] = Text(contents + text)
    _ => if !text.is_empty() { self.parts.push(Text(text)) }
  }
  self
}

///|
fn FormatBuilder::append_char(self : FormatBuilder, ch : Char) -> Unit {
  self.append_slice(ch.to_string()) |> ignore
}

///|
fn FormatBuilder::append_var(
  self : FormatBuilder,
  name : String,
) -> Unit raise HyperlinkFormatError {
  let part = match name {
    "host" => Host
    "wslprefix" => WSLPrefix
    "path" => Path
    "line" => Line
    "column" => Column
    unknown => raise HyperlinkFormatError(InvalidVariable(unknown))
  }
  self.parts.push(part)
}

///|
fn FormatBuilder::build(
  self : FormatBuilder,
) -> HyperlinkFormat raise HyperlinkFormatError {
  self.validate()
  { parts: self.parts.copy(), is_line_dependent: self.parts.contains(Line), }
}

///|
fn FormatBuilder::validate(
  self : FormatBuilder,
) -> Unit raise HyperlinkFormatError {
  // An empty format is fine. It just means hyperlink support is disabled.
  if self.parts.is_empty() {
    return
  }
  // If all parts are just text, then there are no variables. It's likely a
  // reference to an invalid alias.
  if self.parts.iter().all(p => p is Text(_)) {
    raise HyperlinkFormatError(NoVariables)
  }
  // Even if we have other variables, no path variable means the hyperlink
  // can't possibly work the way it is intended.
  if !self.parts.contains(Path) {
    raise HyperlinkFormatError(NoPathVariable)
  }
  // If the {column} variable is used, then we also need a {line} variable
  // or else {column} can't possibly work.
  if self.parts.contains(Column) && !self.parts.contains(Line) {
    raise HyperlinkFormatError(NoLineVariable)
  }
  self.validate_scheme()
}

///|
fn FormatBuilder::validate_scheme(
  self : FormatBuilder,
) -> Unit raise HyperlinkFormatError {
  guard self.parts.get(0) is Some(Text(part)) else {
    raise HyperlinkFormatError(InvalidScheme)
  }
  guard part.find(":") is Some(colon) else {
    raise HyperlinkFormatError(InvalidScheme)
  }
  if colon == 0 {
    raise HyperlinkFormatError(InvalidScheme)
  }
  for i in 0..<colon {
    let c = part[i]
    let ok = (c >= '0' && c <= '9') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= 'a' && c <= 'z') ||
      c == '+' ||
      c == '-' ||
      c == '.'
    if !ok {
      raise HyperlinkFormatError(InvalidScheme)
    }
  }
}

///|
/// A hyperlink format part.
priv enum Part {
  /// Static text. Can include invariant values such as the hostname.
  Text(String)
  /// Placeholder for the host name.
  Host
  /// Placeholder for a WSL path prefix.
  WSLPrefix
  /// Placeholder for the file path.
  Path
  /// Placeholder for the line number.
  Line
  /// Placeholder for the column number.
  Column
} derive(Eq, Debug)

///|
fn Part::interpolate_to(
  self : Part,
  env : HyperlinkEnvironment,
  values : Values,
  dest : @termcolor.ByteVec,
) -> Unit {
  match self {
    Text(text) => dest.extend_string(text)
    Host => if env.host is Some(h) { dest.extend_string(h) }
    WSLPrefix => if env.wsl_prefix is Some(p) { dest.extend_string(p) }
    Path => dest.extend_bytes(values.path.bytes)
    Line => {
      let line = match values.line {
        Some(n) => n
        None => 1L
      }
      dest.extend_string(line.to_string())
    }
    Column => {
      let column = match values.column {
        Some(n) => n
        None => 1L
      }
      dest.extend_string(column.to_string())
    }
  }
}

///|
impl Show for Part with fn output(self, logger) {
  match self {
    Text(text) => logger.write_string(text)
    Host => logger.write_string("{host}")
    WSLPrefix => logger.write_string("{wslprefix}")
    Path => logger.write_string("{path}")
    Line => logger.write_string("{line}")
    Column => logger.write_string("{column}")
  }
}

///|
/// The values to replace the format variables with.
priv struct Values {
  path : HyperlinkPath
  line : Int64?
  column : Int64?
}

///|
fn Values::new(path : HyperlinkPath) -> Values {
  { path, line: None, column: None, }
}

///|
/// An interpolator for hyperlink formats.
priv struct Interpolator {
  config : HyperlinkConfig
  buf : @termcolor.ByteVec
}

///|
fn Interpolator::new(config : HyperlinkConfig) -> Interpolator {
  { config, buf: @termcolor.ByteVec::new(), }
}

///|
/// Start interpolation with the given values by writing a hyperlink to
/// `wtr`. Subsequent writes to `wtr`, until `finish` is called, are the
/// label for the hyperlink.
async fn Interpolator::begin(
  self : Interpolator,
  values : Values,
  wtr : &@termcolor.WriteColor,
) -> Bool {
  if self.config.format.is_empty() ||
    !wtr.supports_hyperlinks() ||
    !wtr.supports_color() {
    return false
  }
  self.buf.clear()
  for part in self.config.format.parts {
    part.interpolate_to(self.config.env, values, self.buf)
  }
  let spec = @termcolor.HyperlinkSpec::open(self.buf.to_bytes())
  wtr.set_hyperlink(spec)
  true
}

///|
/// Writes the correct escape sequences to `wtr` to close any extant
/// hyperlink, marking the end of a hyperlink's label. `active` is the
/// status returned by `begin`.
async fn Interpolator::finish(
  _self : Interpolator,
  active : Bool,
  wtr : &@termcolor.WriteColor,
) -> Unit {
  if !active {
    return
  }
  wtr.set_hyperlink(@termcolor.HyperlinkSpec::close())
}

///|
/// Represents the `{path}` part of a hyperlink (percent encoded).
priv struct HyperlinkPath {
  bytes : Bytes
}

///|
/// Returns a hyperlink path from a file path. The path is canonicalized
/// with the environment's `canonicalize` function (when absent, only
/// absolute paths are accepted, verbatim). Returns `None` if the path could
/// not be turned into an absolute path.
async fn HyperlinkPath::from_path(
  original_path : String,
  env : HyperlinkEnvironment,
) -> HyperlinkPath? {
  let path = match env.canonicalize {
    Some(f) =>
      match f(original_path) {
        Some(p) => p
        None => return None
      }
    None => original_path
  }
  if !path.has_prefix("/") {
    return None
  }
  let bytes = @termcolor.ByteVec::new()
  bytes.extend_bytes(@osstr.encode(path))
  Some(HyperlinkPath::encode(bytes.storage(), 0, bytes.length()))
}

///|
/// Percent-encodes a path.
fn HyperlinkPath::encode(
  input : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> HyperlinkPath {
  let hex = b"0123456789ABCDEF"
  let result = @termcolor.ByteVec::new(capacity=end - start)
  for i in start..<end {
    let byte = input[i]
    match byte {
      b'0'..<=b'9'
      | b'A'..<=b'Z'
      | b'a'..<=b'z'
      | b'/'
      | b':'
      | b'-'
      | b'.'
      | b'_'
      | b'~'
      | b'\x80'..<=b'\xFF' => result.push(byte)
      _ => {
        result.push(b'%')
        result.push(hex[(byte >> 4).to_int()])
        result.push(hex[(byte & b'\x0F').to_int()])
      }
    }
  }
  { bytes: result.to_bytes(), }
}
