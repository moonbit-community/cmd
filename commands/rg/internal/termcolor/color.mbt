///|
/// The set of available colors for the terminal foreground/background.
///
/// The `Ansi256` and `Rgb` colors only work in terminals that support them.
pub(all) enum Color {
  Black
  Blue
  Green
  Red
  Cyan
  Magenta
  Yellow
  White
  Ansi256(Byte)
  Rgb(Byte, Byte, Byte)
} derive(Eq, Debug)

///|
/// The kind of a color parse error.
pub(all) enum ParseColorErrorKind {
  InvalidName
  InvalidAnsi256
  InvalidRgb
} derive(Eq, Debug)

///|
/// An error from parsing an invalid color specification.
pub(all) suberror ParseColorError {
  ParseColorError(kind~ : ParseColorErrorKind, given~ : String)
} derive(Eq, Debug)

///|
/// Return the string that couldn't be parsed as a valid color.
pub fn ParseColorError::invalid(self : ParseColorError) -> String {
  let ParseColorError(given~, ..) = self
  given
}

///|
/// Return the kind of this error.
pub fn ParseColorError::kind(self : ParseColorError) -> ParseColorErrorKind {
  let ParseColorError(kind~, ..) = self
  kind
}

///|
/// Formats the error message exactly like termcolor's `Display` impl.
pub fn ParseColorError::to_string(self : ParseColorError) -> String {
  let ParseColorError(kind~, given~) = self
  match kind {
    InvalidName =>
      "unrecognized color name '\{given}'. Choose from: black, blue, green, red, cyan, magenta, yellow, white"
    InvalidAnsi256 =>
      "unrecognized ansi256 color number, should be '[0-255]' (or a hex number), but is '\{given}'"
    InvalidRgb =>
      "unrecognized RGB color triple, should be '[0-255],[0-255],[0-255]' (or a hex triple), but is '\{given}'"
  }
}

///|
pub impl Show for ParseColorError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Parses a color name (`black`, `blue`, ...), an ANSI 256 color number
/// (decimal or `0x`-prefixed hex) or an RGB triple `r,g,b`.
pub fn Color::parse(s : String) -> Color raise ParseColorError {
  match s.to_lower() {
    "black" => Black
    "blue" => Blue
    "green" => Green
    "red" => Red
    "cyan" => Cyan
    "magenta" => Magenta
    "yellow" => Yellow
    "white" => White
    _ => color_from_str_numeric(s)
  }
}

///|
/// Mimics Rust's `u8::from_str_radix`: an optional leading `+` followed by
/// at least one digit in the given radix, with a value no larger than 255.
fn parse_u8_radix(s : StringView, radix : Int32) -> Byte? {
  let mut i = 0
  if s.length() > 0 && s[0] == '+' {
    i = 1
  }
  if i >= s.length() {
    return None
  }
  let mut n = 0
  while i < s.length() {
    let c = s[i].to_int()
    let d = if c >= '0' && c <= '9' {
      c - '0'
    } else if c >= 'a' && c <= 'z' {
      c - 'a' + 10
    } else if c >= 'A' && c <= 'Z' {
      c - 'A' + 10
    } else {
      return None
    }
    if d >= radix {
      return None
    }
    n = n * radix + d
    if n > 255 {
      return None
    }
    i += 1
  }
  Some(n.to_byte())
}

///|
fn parse_color_number(s : StringView) -> Byte? {
  if s.has_prefix("0x") {
    parse_u8_radix(s[2:], 16)
  } else {
    parse_u8_radix(s, 10)
  }
}

///|
fn is_hex_digit_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

///|
fn color_from_str_numeric(s : String) -> Color raise ParseColorError {
  let codes : Array[StringView] = s.split(",").collect()
  if codes.length() == 1 {
    match parse_color_number(codes[0]) {
      Some(n) => Ansi256(n)
      None =>
        if s.iter().all(is_hex_digit_char) {
          raise ParseColorError(kind=InvalidAnsi256, given=s)
        } else {
          raise ParseColorError(kind=InvalidName, given=s)
        }
    }
  } else if codes.length() == 3 {
    let v : Array[Byte] = []
    for code in codes {
      match parse_color_number(code) {
        Some(n) => v.push(n)
        None => raise ParseColorError(kind=InvalidRgb, given=s)
      }
    }
    Rgb(v[0], v[1], v[2])
  } else if s.contains(",") {
    raise ParseColorError(kind=InvalidRgb, given=s)
  } else {
    raise ParseColorError(kind=InvalidName, given=s)
  }
}

///|
/// A color specification: foreground/background colors and styles.
///
/// The default specification has no colors or styles set, but has `reset`
/// enabled, which means a reset escape is emitted before applying it.
pub struct ColorSpec {
  priv mut fg_color : Color?
  priv mut bg_color : Color?
  priv mut bold : Bool
  priv mut intense : Bool
  priv mut underline : Bool
  priv mut dimmed : Bool
  priv mut italic : Bool
  priv mut reset : Bool
  priv mut strikethrough : Bool
} derive(Eq, Debug)

///|
/// Create a new color specification that has no colors or styles.
pub fn ColorSpec::new() -> ColorSpec {
  {
    fg_color: None,
    bg_color: None,
    bold: false,
    intense: false,
    underline: false,
    dimmed: false,
    italic: false,
    reset: true,
    strikethrough: false,
  }
}

///|
/// Returns an independent copy of this specification.
pub fn ColorSpec::clone(self : ColorSpec) -> ColorSpec {
  { ..self, }
}

///|
pub fn ColorSpec::fg(self : ColorSpec) -> Color? {
  self.fg_color
}

///|
pub fn ColorSpec::set_fg(self : ColorSpec, color : Color?) -> ColorSpec {
  self.fg_color = color
  self
}

///|
pub fn ColorSpec::bg(self : ColorSpec) -> Color? {
  self.bg_color
}

///|
pub fn ColorSpec::set_bg(self : ColorSpec, color : Color?) -> ColorSpec {
  self.bg_color = color
  self
}

///|
pub fn ColorSpec::bold(self : ColorSpec) -> Bool {
  self.bold
}

///|
pub fn ColorSpec::set_bold(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.bold = yes
  self
}

///|
pub fn ColorSpec::dimmed(self : ColorSpec) -> Bool {
  self.dimmed
}

///|
pub fn ColorSpec::set_dimmed(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.dimmed = yes
  self
}

///|
pub fn ColorSpec::italic(self : ColorSpec) -> Bool {
  self.italic
}

///|
pub fn ColorSpec::set_italic(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.italic = yes
  self
}

///|
pub fn ColorSpec::underline(self : ColorSpec) -> Bool {
  self.underline
}

///|
pub fn ColorSpec::set_underline(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.underline = yes
  self
}

///|
pub fn ColorSpec::strikethrough(self : ColorSpec) -> Bool {
  self.strikethrough
}

///|
pub fn ColorSpec::set_strikethrough(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.strikethrough = yes
  self
}

///|
/// Whether a reset escape sequence is emitted before this spec is applied.
pub fn ColorSpec::reset(self : ColorSpec) -> Bool {
  self.reset
}

///|
pub fn ColorSpec::set_reset(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.reset = yes
  self
}

///|
/// Whether the "intense" (bright) variants of colors are used.
pub fn ColorSpec::intense(self : ColorSpec) -> Bool {
  self.intense
}

///|
pub fn ColorSpec::set_intense(self : ColorSpec, yes : Bool) -> ColorSpec {
  self.intense = yes
  self
}

///|
/// Returns true if this spec has no colors or styles set.
pub fn ColorSpec::is_none(self : ColorSpec) -> Bool {
  self.fg_color is None &&
  self.bg_color is None &&
  !self.bold &&
  !self.underline &&
  !self.dimmed &&
  !self.italic &&
  !self.intense &&
  !self.strikethrough
}

///|
/// Clears this color specification so that it has no color/style settings.
pub fn ColorSpec::clear(self : ColorSpec) -> Unit {
  self.fg_color = None
  self.bg_color = None
  self.bold = false
  self.underline = false
  self.intense = false
  self.dimmed = false
  self.italic = false
  self.strikethrough = false
}

///|
/// A hyperlink specification. `uri` is `None` to close a hyperlink.
pub struct HyperlinkSpec {
  uri : Bytes?
} derive(Eq, Debug)

///|
/// Creates a new hyperlink specification that opens a link to `uri`.
pub fn HyperlinkSpec::open(uri : Bytes) -> HyperlinkSpec {
  { uri: Some(uri), }
}

///|
/// Creates a hyperlink specification representing no hyperlink.
pub fn HyperlinkSpec::close() -> HyperlinkSpec {
  { uri: None, }
}

///|
pub fn HyperlinkSpec::uri(self : HyperlinkSpec) -> Bytes? {
  self.uri
}
