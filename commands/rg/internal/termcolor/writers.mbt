///|
/// Satisfies `WriteColor` but ignores all color/hyperlink settings.
pub struct NoColor {
  priv wtr : &Write
}

///|
/// Create a new writer that satisfies `WriteColor` but drops all color
/// information.
pub fn NoColor::new(wtr : &Write) -> NoColor {
  { wtr, }
}

///|
/// Returns the underlying writer.
pub fn NoColor::get_ref(self : NoColor) -> &Write {
  self.wtr
}

///|
pub impl Write for NoColor with fn write_slice(self, buf, start, end) {
  self.wtr.write_slice(buf, start, end)
}

///|
pub impl Write for NoColor with fn write_bytes(self, bytes) {
  self.wtr.write_bytes(bytes)
}

///|
pub impl Write for NoColor with fn flush(self) {
  self.wtr.flush()
}

///|
pub impl WriteColor for NoColor with fn supports_color(_self) {
  false
}

///|
pub impl WriteColor for NoColor with fn supports_hyperlinks(_self) {
  false
}

///|
pub impl WriteColor for NoColor with fn set_color(_self, _spec) {
  ()
}

///|
pub impl WriteColor for NoColor with fn set_hyperlink(_self, _link) {
  ()
}

///|
pub impl WriteColor for NoColor with fn reset(_self) {
  ()
}

///|
pub impl WriteColor for NoColor with fn is_synchronous(_self) {
  false
}

///|
/// Satisfies `WriteColor` using standard ANSI escape sequences.
pub struct Ansi {
  priv wtr : &Write
}

///|
/// Create a new writer that satisfies `WriteColor` using standard ANSI
/// escape sequences.
pub fn Ansi::new(wtr : &Write) -> Ansi {
  { wtr, }
}

///|
/// Returns the underlying writer.
pub fn Ansi::get_ref(self : Ansi) -> &Write {
  self.wtr
}

///|
pub impl Write for Ansi with fn write_slice(self, buf, start, end) {
  self.wtr.write_slice(buf, start, end)
}

///|
pub impl Write for Ansi with fn write_bytes(self, bytes) {
  self.wtr.write_bytes(bytes)
}

///|
pub impl Write for Ansi with fn flush(self) {
  self.wtr.flush()
}

///|
pub impl WriteColor for Ansi with fn supports_color(_self) {
  true
}

///|
pub impl WriteColor for Ansi with fn supports_hyperlinks(_self) {
  true
}

///|
pub impl WriteColor for Ansi with fn set_color(self, spec) {
  ansi_set_color(self.wtr, spec)
}

///|
pub impl WriteColor for Ansi with fn set_hyperlink(self, link) {
  ansi_set_hyperlink(self.wtr, link)
}

///|
pub impl WriteColor for Ansi with fn reset(self) {
  ansi_reset(self.wtr)
}

///|
pub impl WriteColor for Ansi with fn is_synchronous(_self) {
  false
}

///|
async fn ansi_write_str(wtr : &Write, s : String) -> Unit {
  let n = s.length()
  let buf = FixedArray::make(n, b'\x00')
  for i in 0..<n {
    buf[i] = s[i].to_byte()
  }
  wtr.write_slice(buf, 0, n)
}

///|
async fn ansi_reset(wtr : &Write) -> Unit {
  ansi_write_str(wtr, "\u{1B}[0m")
}

///|
async fn ansi_set_hyperlink(wtr : &Write, link : HyperlinkSpec) -> Unit {
  ansi_write_str(wtr, "\u{1B}]8;;")
  if link.uri is Some(uri) {
    wtr.write_bytes(uri)
  }
  ansi_write_str(wtr, "\u{1B}\\")
}

///|
async fn ansi_set_color(wtr : &Write, spec : ColorSpec) -> Unit {
  if spec.reset {
    ansi_reset(wtr)
  }
  if spec.bold {
    ansi_write_str(wtr, "\u{1B}[1m")
  }
  if spec.dimmed {
    ansi_write_str(wtr, "\u{1B}[2m")
  }
  if spec.italic {
    ansi_write_str(wtr, "\u{1B}[3m")
  }
  if spec.underline {
    ansi_write_str(wtr, "\u{1B}[4m")
  }
  if spec.strikethrough {
    ansi_write_str(wtr, "\u{1B}[9m")
  }
  if spec.fg_color is Some(c) {
    ansi_write_color(wtr, true, c, spec.intense)
  }
  if spec.bg_color is Some(c) {
    ansi_write_color(wtr, false, c, spec.intense)
  }
}

///|
/// Formats a variable ANSI code like termcolor's `write_var_ansi_code!`:
/// numbers are printed without leading zeros and joined by `;`, terminated
/// by `m`.
fn ansi_var_code(pre : String, codes : Array[Byte]) -> String {
  let sb = StringBuilder()
  sb.write_string(pre)
  for i, code in codes {
    if i > 0 {
      sb.write_char(';')
    }
    sb.write_string(code.to_int().to_string())
  }
  sb.write_char('m')
  sb.to_string()
}

///|
async fn ansi_write_color(
  wtr : &Write,
  fg : Bool,
  c : Color,
  intense : Bool,
) -> Unit {
  let normal = (code : String) => {
    if fg {
      "\u{1B}[3\{code}m"
    } else {
      "\u{1B}[4\{code}m"
    }
  }
  let bright = (code : String) => {
    if fg {
      "\u{1B}[38;5;\{code}m"
    } else {
      "\u{1B}[48;5;\{code}m"
    }
  }
  let custom256 = (n : Byte) => {
    ansi_var_code(if fg { "\u{1B}[38;5;" } else { "\u{1B}[48;5;" }, [n])
  }
  let custom_rgb = (r : Byte, g : Byte, b : Byte) => {
    ansi_var_code(if fg { "\u{1B}[38;2;" } else { "\u{1B}[48;2;" }, [r, g, b])
  }
  let s = if intense {
    match c {
      Black => bright("8")
      Blue => bright("12")
      Green => bright("10")
      Red => bright("9")
      Cyan => bright("14")
      Magenta => bright("13")
      Yellow => bright("11")
      White => bright("15")
      Ansi256(n) => custom256(n)
      Rgb(r, g, b) => custom_rgb(r, g, b)
    }
  } else {
    match c {
      Black => normal("0")
      Blue => normal("4")
      Green => normal("2")
      Red => normal("1")
      Cyan => normal("6")
      Magenta => normal("5")
      Yellow => normal("3")
      White => normal("7")
      Ansi256(n) => custom256(n)
      Rgb(r, g, b) => custom_rgb(r, g, b)
    }
  }
  ansi_write_str(wtr, s)
}

///|
/// An in-memory buffer that supports colors, like termcolor's `Buffer`.
///
/// A buffer either uses ANSI escape sequences for colors (`Buffer::ansi`)
/// or ignores colors entirely (`Buffer::no_color`).
pub struct Buffer {
  priv bytes : ByteVec
  priv ansi : Bool
}

///|
/// Create a buffer that drops all color information.
pub fn Buffer::no_color() -> Buffer {
  { bytes: ByteVec::new(), ansi: false, }
}

///|
/// Create a buffer that uses ANSI escape sequences.
pub fn Buffer::ansi() -> Buffer {
  { bytes: ByteVec::new(), ansi: true, }
}

///|
pub fn Buffer::is_empty(self : Buffer) -> Bool {
  self.bytes.is_empty()
}

///|
pub fn Buffer::len(self : Buffer) -> Int32 {
  self.bytes.length()
}

///|
pub fn Buffer::clear(self : Buffer) -> Unit {
  self.bytes.clear()
}

///|
/// Returns a copy of the buffer contents.
pub fn Buffer::to_bytes(self : Buffer) -> Bytes {
  self.bytes.to_bytes()
}

///|
/// Returns the underlying byte vector.
pub fn Buffer::as_vec(self : Buffer) -> ByteVec {
  self.bytes
}

///|
pub impl Write for Buffer with fn write_slice(self, buf, start, end) {
  self.bytes.extend_slice(buf, start, end)
}

///|
pub impl Write for Buffer with fn write_bytes(self, bytes) {
  self.bytes.extend_bytes(bytes)
}

///|
pub impl WriteColor for Buffer with fn supports_color(self) {
  self.ansi
}

///|
pub impl WriteColor for Buffer with fn supports_hyperlinks(self) {
  self.ansi
}

///|
pub impl WriteColor for Buffer with fn set_color(self, spec) {
  if self.ansi {
    ansi_set_color(self.bytes, spec)
  }
}

///|
pub impl WriteColor for Buffer with fn set_hyperlink(self, link) {
  if self.ansi {
    ansi_set_hyperlink(self.bytes, link)
  }
}

///|
pub impl WriteColor for Buffer with fn reset(self) {
  if self.ansi {
    ansi_reset(self.bytes)
  }
}

///|
/// Whether to use colors or not, mirroring termcolor's `ColorChoice`.
pub(all) enum ColorChoice {
  /// Try very hard to emit colors.
  Always
  /// Like Always, but on Windows, use ANSI escape sequences.
  AlwaysAnsi
  /// Try to use colors, but don't force the issue.
  Auto
  /// Never emit colors.
  Never
} derive(Eq, Debug)

///|
/// An error that occurs when parsing a `ColorChoice` fails.
pub(all) suberror ColorChoiceParseError {
  ColorChoiceParseError(String)
} derive(Eq, Debug)

///|
pub fn ColorChoiceParseError::to_string(self : ColorChoiceParseError) -> String {
  let ColorChoiceParseError(unknown) = self
  "unrecognized color choice '\{unknown}': valid choices are: always, always-ansi, never, auto"
}

///|
pub impl Show for ColorChoiceParseError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn ColorChoice::default() -> ColorChoice {
  Auto
}

///|
/// Parses `always`, `always-ansi`, `never` or `auto` (ASCII
/// case-insensitively).
pub fn ColorChoice::parse(
  s : String,
) -> ColorChoice raise ColorChoiceParseError {
  let lower = s.to_lower()
  match lower {
    "always" => Always
    "always-ansi" => AlwaysAnsi
    "never" => Never
    "auto" => Auto
    _ => raise ColorChoiceParseError(lower)
  }
}

///|
/// Returns true if we should attempt to write colored output. The
/// environment is passed in explicitly: `term` is the value of the `TERM`
/// environment variable (if set) and `no_color` is whether `NO_COLOR` is
/// set. This follows termcolor's non-Windows logic.
pub fn ColorChoice::should_attempt_color(
  self : ColorChoice,
  term : String?,
  no_color : Bool,
) -> Bool {
  match self {
    Always | AlwaysAnsi => true
    Never => false
    Auto =>
      match term {
        None => false
        Some("dumb") => false
        Some(_) => !no_color
      }
  }
}
