///|
priv enum Layout {
  Lines
  Columns
  Across
  Commas
} derive(Eq)

///|
priv enum QuoteStyle {
  Literal
  Shell
  ShellAlways
  ShellEscape
  ShellEscapeAlways
  CQuote
  CMaybe
  Escape
  Locale
} derive(Eq)

///|
fn quote_style(value : String) -> QuoteStyle? {
  match value {
    "literal" => Some(Literal)
    "shell" => Some(Shell)
    "shell-always" => Some(ShellAlways)
    "shell-escape" => Some(ShellEscape)
    "shell-escape-always" => Some(ShellEscapeAlways)
    "c" | "clocale" => Some(CQuote)
    "c-maybe" => Some(CMaybe)
    "escape" => Some(Escape)
    "locale" => Some(Locale)
    _ => {
      let candidates = [
        "literal", "shell", "shell-always", "shell-escape", "shell-escape-always",
        "c", "c-maybe", "escape", "locale", "clocale",
      ].filter(style => style.has_prefix(value))
      if candidates.length() == 1 {
        quote_style(candidates[0])
      } else {
        None
      }
    }
  }
}

///|
fn invalid_display_option(parsed : @cli.ParsedArgs) -> (String, Int32)? {
  let counts : Map[String, Int32] = Map([])
  for key in parsed.order {
    if !["width", "tabsize", "quoting-style", "color"].contains(key) {
      continue
    }
    let index = counts.get(key).unwrap_or(0)
    counts[key] = index + 1
    let value = parsed.values(key)[index]
    if key == "width" || key == "tabsize" {
      let number = parse_dimension(value)
      let range = key == "tabsize" &&
        (
          number is Some((_, true)) ||
          (number is Some((n, _)) && n > 9223372036854775807UL)
        )
      if number is None || range {
        let what = if key == "width" { "line width" } else { "tab size" }
        return Some(
          (
            "ls: invalid " +
            what +
            ": " +
            @quoting.locale_quote(@utf8.encode(value)[:]) +
            (if range { ": Value too large for defined data type" } else { "" }) +
            "\n",
            2,
          ),
        )
      }
    } else if (key == "quoting-style" && quote_style(value) is None) ||
      (
        key == "color" &&
        ![
          "always", "yes", "force", "never", "no", "none", "auto", "tty", "if-tty",
        ].contains(value)
      ) {
      let valid = if key == "quoting-style" {
        "  - 'literal'\n  - 'shell'\n  - 'shell-always'\n  - 'shell-escape'\n  - 'shell-escape-always'\n  - 'c'\n  - 'c-maybe'\n  - 'escape'\n  - 'locale'\n  - 'clocale'\n"
      } else {
        "  - 'always', 'yes', 'force'\n  - 'never', 'no', 'none'\n  - 'auto', 'tty', 'if-tty'\n"
      }
      let ambiguous = key == "quoting-style" &&
        [
          "literal", "shell", "shell-always", "shell-escape", "shell-escape-always",
          "c", "c-maybe", "escape", "locale", "clocale",
        ].any(name => name.has_prefix(value))
      return Some(
        (
          (if ambiguous {
            "ls: ambiguous argument "
          } else {
            "ls: invalid argument "
          }) +
          @quoting.locale_quote(@utf8.encode(value)[:]) +
          " for '--" +
          key +
          "'\nValid arguments are:\n" +
          valid +
          "Try 'ls --help' for more information.\n",
          1,
        ),
      )
    }
  }
  None
}

///|
fn c_escape(bytes : BytesView, quotes : Bool, extra~ : String = "") -> String {
  let out = StringBuilder()
  if quotes {
    out.write_char('"')
  }
  for byte in bytes {
    let escaped = match byte {
      7 => Some('a')
      8 => Some('b')
      9 => Some('t')
      10 => Some('n')
      11 => Some('v')
      12 => Some('f')
      13 => Some('r')
      b'\\' => Some('\\')
      b'"' if quotes => Some('"')
      b' ' if !quotes => Some(' ')
      _ =>
        if !quotes && extra.contains(byte.to_int().unsafe_to_char().to_string()) {
          Some(byte.to_int().unsafe_to_char())
        } else {
          None
        }
    }
    match escaped {
      Some(c) => {
        out.write_char('\\')
        out.write_char(c)
      }
      None => {
        let code = byte.to_int()
        if byte >= 32 && byte < 127 {
          out.write_char(code.unsafe_to_char())
        } else {
          out.write_char('\\')
          out.write_char((48 + code / 64).unsafe_to_char())
          out.write_char((48 + code / 8 % 8).unsafe_to_char())
          out.write_char((48 + code % 8).unsafe_to_char())
        }
      }
    }
  }
  if quotes {
    out.write_char('"')
  }
  out.to_string()
}

///|
fn shell_literal(name : String, force : Bool) -> String {
  let bytes = @utf8.encode(name)
  let mut quote = force || bytes.is_empty()
  let mut apostrophe = false
  let mut double_compatible = true
  for index, byte in bytes {
    if byte == b'\'' {
      apostrophe = true
    }
    if !(byte
      is (b'0'..<=b'9'
      | b'A'..<=b'Z'
      | b'a'..<=b'z'
      | b'%'
      | b'+'
      | b','
      | b'-'
      | b'.'
      | b'/'
      | b':'
      | b']'
      | b'_'
      | b'@'
      | b' '
      | b'\'')) {
      double_compatible = false
    }
    if byte
      is (b' '
      | b'\t'
      | b'\n'
      | b'\r'
      | b'\''
      | b'"'
      | b'$'
      | b'`'
      | b'\\'
      | b'&'
      | b';'
      | b'|'
      | b'<'
      | b'='
      | b'>'
      | b'('
      | b')'
      | b'['
      | b'?'
      | b'*') ||
      (index == 0 && byte is (b'#' | b'~')) ||
      (bytes.length() == 1 && byte is (b'{' | b'}')) {
      quote = true
    }
  }
  if !quote {
    name
  } else if apostrophe && double_compatible {
    "\"" + name + "\""
  } else {
    "'" + name.replace_all(old="'", new="'\\''") + "'"
  }
}

///|
fn quote_name(
  name : String,
  style : QuoteStyle,
  hide : Bool,
  extra~ : String = "",
) -> (String, Int32, Bool) {
  let bytes = @utf8.encode(name)
  let special = bytes
    .iter()
    .any(byte => extra.contains(byte.to_int().unsafe_to_char().to_string()))
  let mut quoted = true
  let text = match style {
    Literal => {
      quoted = false
      name
    }
    Shell | ShellAlways => {
      let result = shell_literal(name, style == ShellAlways || special)
      quoted = result != name
      result
    }
    ShellEscape | ShellEscapeAlways => {
      let result = @quoting.shell_escape(
        bytes[:],
        force=style == ShellEscapeAlways || special,
      )
      quoted = result != name
      result
    }
    CQuote => c_escape(bytes[:], true)
    CMaybe => {
      let need = special ||
        bytes.iter().any(b => b < 32 || b >= 127 || b == b'"')
      quoted = need
      if need {
        c_escape(bytes[:], true)
      } else {
        name
      }
    }
    Escape => {
      quoted = false
      c_escape(bytes[:], false, extra~)
    }
    Locale => @quoting.locale_quote(bytes[:])
  }
  let encoded = @utf8.encode(text)
  let mut width = 0
  if hide {
    let out = StringBuilder()
    for byte in encoded {
      if byte >= 32 && byte < 127 {
        out.write_char(byte.to_int().unsafe_to_char())
      } else {
        out.write_char('?')
      }
    }
    (out.to_string(), encoded.length(), quoted)
  } else {
    for byte in encoded {
      if byte >= 32 && byte < 127 {
        width += 1
      }
    }
    (text, width, quoted)
  }
}

///|
// A line width above PTRDIFF_MAX means unlimited in the fixed GNU profile.
fn parse_dimension(value : String) -> (UInt64, Bool)? {
  let bytes = @utf8.encode(value)
  let mut index = 0
  while index < bytes.length() &&
        bytes[index] is (b' ' | b'\t' | b'\n' | b'\r' | 11 | 12) {
    index += 1
  }
  if index < bytes.length() && bytes[index] == b'+' {
    index += 1
  }
  guard index < bytes.length() && bytes[index] != b'-' else { return None }
  let mut base = 10UL
  if bytes[index] == b'0' {
    base = 8UL
    if index + 1 < bytes.length() && bytes[index + 1] is (b'x' | b'X') {
      base = 16UL
      index += 2
    }
  }
  let start = index
  let mut result = 0UL
  let mut overflow = false
  while index < bytes.length() {
    let digit = match bytes[index] {
      b'0'..<=b'9' as b => b.to_int() - 48
      b'a'..<=b'f' as b => b.to_int() - 87
      b'A'..<=b'F' as b => b.to_int() - 55
      _ => return None
    }
    guard digit.to_uint64() < base else { return None }
    if result > (18446744073709551615UL - digit.to_uint64()) / base {
      overflow = true
    }
    result = result * base + digit.to_uint64()
    index += 1
  }
  if index == start {
    None
  } else {
    Some((result, overflow))
  }
}

///|
fn dimension(
  parsed : @cli.ParsedArgs,
  option : String,
  env : String,
  default : UInt64,
  needed : Bool,
) -> (UInt64, String?) raise @cli.CliError {
  if parsed.last_value(option) is Some(value) {
    let result = parse_dimension(value)
    let good = result is Some((_, false))
    if option == "width" && result is Some((number, overflow)) {
      return (
        if overflow || number > 9223372036854775807UL {
          0UL
        } else {
          number
        },
        None,
      )
    }
    if good && result is Some((number, _)) && number <= 9223372036854775807UL {
      return (number, None)
    }
    raise @cli.CliError(
      kind=InvalidValue,
      option=value,
      message=if option == "width" {
        "invalid line width"
      } else {
        "invalid tab size"
      },
    )
  }
  if needed &&
    @env.get_env_var(env) is Some(value) &&
    (env != "COLUMNS" || value != "") {
    if parse_dimension(value) is Some((number, overflow)) {
      if option == "width" {
        return (
          if overflow || number > 9223372036854775807UL {
            0UL
          } else {
            number
          },
          None,
        )
      }
      if !overflow {
        return (number, None)
      }
    }
    let what = if option == "width" { "width" } else { "tab size" }
    return (
      default,
      Some(
        "ls: ignoring invalid \{what} in environment variable \{env}: " +
        @quoting.locale_quote(@utf8.encode(value)[:]) +
        "\n",
      ),
    )
  }
  (default, None)
}

///|
priv struct DisplayName {
  text : String
  width : Int32
  color : Bytes?
  suffix : String
  pad : Bool
}

///|
fn column_widths(
  names : Array[DisplayName],
  columns : Int32,
  down : Bool,
) -> Array[Int32] {
  let widths = Array::make(columns, 3)
  let rows = (names.length() + columns - 1) / columns
  for index, name in names {
    let col = if down { index / rows } else { index % columns }
    widths[col] = widths[col].max(
      name.width + (if col == columns - 1 { 0 } else { 2 }),
    )
  }
  widths
}

///|
fn indent(
  out : @buffer.Buffer,
  from : Int32,
  to : Int32,
  tabs : UInt64,
) -> Unit {
  let mut position = from
  while position < to {
    if tabs != 0UL && to.to_uint64() / tabs > (position + 1).to_uint64() / tabs {
      out.write_byte(b'\t')
      position += (tabs - position.to_uint64() % tabs).to_int()
    } else {
      out.write_byte(b' ')
      position += 1
    }
  }
}

///|
async fn write_layout(
  names : Array[DisplayName],
  options : LsOptions,
  palette : Palette?,
  used : Ref[Bool],
  emit : async (Bytes) -> Unit,
) -> Unit {
  if names.is_empty() {
    return
  }
  let out = @buffer.Buffer()
  let flush = async fn() {
    if !out.is_empty() {
      emit(out.to_bytes())
      out.reset()
    }
  }
  let put_color = (palette : Palette, sequence : Bytes) => {
    if !used.val {
      used.val = true
      out.write_bytes(color_reset(palette)[:])
    }
    out.write_bytes(sequence[:])
  }
  let write_name = (index : Int32, position : Int32) => {
    let name = names[index]
    let mut colored = false
    if palette is Some(palette) {
      if active(palette, "no") {
        put_color(palette, color_sequence(palette, palette.codes["no"]))
      }
    }
    if name.pad {
      out.write_byte(b' ')
    }
    if palette is Some(palette) {
      if name.color is Some(sequence) {
        if active(palette, "no") {
          put_color(palette, palette.codes["lc"] + palette.codes["rc"])
        }
        put_color(palette, color_sequence(palette, sequence))
        colored = true
      }
    }
    out.write_string_utf8(name.text)
    if palette is Some(palette) && (colored || active(palette, "no")) {
      put_color(palette, color_reset(palette))
      let length = @utf8.encode(name.text).length() +
        (if name.pad { 1 } else { 0 })
      if options.width > 0 &&
        length > 0 &&
        position.to_int64() / options.width !=
        (position + length - 1).to_int64() / options.width {
        put_color(palette, palette.codes.get("cl").unwrap_or(b""))
      }
    }
    out.write_string_utf8(name.suffix)
  }
  if options.layout == Lines {
    for index = 0; index < names.length(); index = index + 1 {
      write_name(index, 0)
      out.write_byte(b'\n')
      if out.length() >= 65536 {
        flush()
      }
    }
  } else if options.layout == Commas {
    let mut position = 0
    for index, name in names {
      if index > 0 {
        out.write_byte(b',')
        if options.width == 0 ||
          (position + name.width + 2).to_int64() < options.width {
          out.write_byte(b' ')
          position += 2
        } else {
          out.write_byte(b'\n')
          position = 0
        }
      }
      write_name(index, position)
      position += name.width
      if out.length() >= 65536 {
        flush()
      }
    }
    out.write_byte(b'\n')
  } else if options.width == 0 {
    let mut position = 0
    for index, name in names {
      if index > 0 {
        out.write_bytes(b"  ")
        position += 2
      }
      write_name(index, position)
      position += name.width
      if out.length() >= 65536 {
        flush()
      }
    }
    out.write_byte(b'\n')
  } else {
    let down = options.layout == Columns
    let maximum = options.width / 3L +
      (if options.width % 3L != 0L { 1L } else { 0L })
    let mut columns = names.length().to_int64().min(maximum).to_int().max(1)
    let mut widths = column_widths(names, columns, down)
    while columns > 1 &&
          widths.fold(init=0L, (sum, width) => sum + width.to_int64()) >=
          options.width {
      columns -= 1
      widths = column_widths(names, columns, down)
    }
    let rows = (names.length() + columns - 1) / columns
    for row = 0; row < rows; row = row + 1 {
      let mut position = 0
      for col = 0; col < columns; col = col + 1 {
        let index = if down { col * rows + row } else { row * columns + col }
        if index >= names.length() {
          break
        }
        write_name(index, position)
        let next = if down { index + rows } else { index + 1 }
        if col + 1 < columns && next < names.length() {
          indent(
            out,
            position + names[index].width,
            position + widths[col],
            options.tabsize,
          )
          position += widths[col]
        }
        if out.length() >= 65536 {
          flush()
        }
      }
      out.write_byte(b'\n')
      if out.length() >= 65536 {
        flush()
      }
    }
  }
  flush()
}
