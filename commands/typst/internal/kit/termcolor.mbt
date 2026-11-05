// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// Colored terminal output (the parts of `termcolor` 1.4 that the CLI and
// `codespan-reporting` use): a buffered writer that emits ANSI escape
// sequences when colors are enabled.

///|
/// A terminal color (`termcolor::Color`).
#derive(Eq, Debug)
pub(all) enum Color {
  Black
  Blue
  Green
  Red
  Cyan
  Magenta
  Yellow
  White
  Ansi256(Int32)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Color with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Color with @debug.Debug::{to_repr}

///|
/// A color specification (`termcolor::ColorSpec`).
#derive(Eq, Debug)
pub(all) struct ColorSpec {
  fg : Color?
  bold : Bool
  intense : Bool
  underline : Bool
  dimmed : Bool
  reset : Bool
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorSpec with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend ColorSpec with @debug.Debug::{to_repr}

///|
/// A new color specification (`ColorSpec::new`: no color, reset on).
pub fn ColorSpec::new() -> ColorSpec {
  {
    fg: None,
    bold: false,
    intense: false,
    underline: false,
    dimmed: false,
    reset: true,
  }
}

///|
/// Sets the foreground color.
pub fn ColorSpec::with_fg(self : ColorSpec, fg : Color) -> ColorSpec {
  { ..self, fg: Some(fg), }
}

///|
/// Sets bold.
pub fn ColorSpec::with_bold(self : ColorSpec) -> ColorSpec {
  { ..self, bold: true, }
}

///|
/// Sets intense.
pub fn ColorSpec::with_intense(self : ColorSpec) -> ColorSpec {
  { ..self, intense: true, }
}

///|
/// Sets underline.
pub fn ColorSpec::with_underline(self : ColorSpec) -> ColorSpec {
  { ..self, underline: true, }
}

///|
/// Sets dimmed.
pub fn ColorSpec::with_dimmed(self : ColorSpec) -> ColorSpec {
  { ..self, dimmed: true, }
}

///|
/// A buffered output that may be colored (`termcolor::WriteColor`).
pub struct ColorWriter {
  priv buf : StringBuilder
  priv color : Bool
}

///|
/// Creates a writer; `color` enables ANSI escape sequences.
pub fn ColorWriter::new(color : Bool) -> ColorWriter {
  { buf: StringBuilder(), color, }
}

///|
/// Whether colors are emitted.
pub fn ColorWriter::supports_color(self : ColorWriter) -> Bool {
  self.color
}

///|
/// Writes text.
pub fn ColorWriter::write(self : ColorWriter, text : String) -> Unit {
  self.buf.write_string(text)
}

///|
/// Writes a character.
pub fn ColorWriter::write_char(self : ColorWriter, c : Char) -> Unit {
  self.buf.write_char(c)
}

///|
/// Writes text and a newline.
pub fn ColorWriter::writeln(self : ColorWriter, text : String) -> Unit {
  self.buf.write_string(text)
  self.buf.write_char('\n')
}

///|
/// Sets the color (`Ansi::set_color`).
pub fn ColorWriter::set_color(self : ColorWriter, spec : ColorSpec) -> Unit {
  if !self.color {
    return
  }
  if spec.reset {
    self.reset()
  }
  if spec.bold {
    self.buf.write_string("\u{1B}[1m")
  }
  if spec.dimmed {
    self.buf.write_string("\u{1B}[2m")
  }
  if spec.underline {
    self.buf.write_string("\u{1B}[4m")
  }
  if spec.fg is Some(c) {
    self.write_color(c, spec.intense)
  }
}

///|
fn ColorWriter::write_color(
  self : ColorWriter,
  c : Color,
  intense : Bool,
) -> Unit {
  let code = if intense {
    match c {
      Black => "38;5;8"
      Blue => "38;5;12"
      Green => "38;5;10"
      Red => "38;5;9"
      Cyan => "38;5;14"
      Magenta => "38;5;13"
      Yellow => "38;5;11"
      White => "38;5;15"
      Ansi256(n) => "38;5;\{n}"
    }
  } else {
    match c {
      Black => "30"
      Blue => "34"
      Green => "32"
      Red => "31"
      Cyan => "36"
      Magenta => "35"
      Yellow => "33"
      White => "37"
      Ansi256(n) => "38;5;\{n}"
    }
  }
  self.buf.write_string("\u{1B}[\{code}m")
}

///|
/// Resets the color (`Ansi::reset`).
pub fn ColorWriter::reset(self : ColorWriter) -> Unit {
  if self.color {
    self.buf.write_string("\u{1B}[0m")
  }
}

///|
/// The text written so far.
pub fn ColorWriter::contents(self : ColorWriter) -> String {
  self.buf.to_string()
}

///|
/// Takes the text written so far, clearing the buffer.
pub fn ColorWriter::take(self : ColorWriter) -> String {
  let s = self.buf.to_string()
  self.buf.reset()
  s
}

///|
/// Whether the environment allows colors (`ColorChoice::Auto`'s
/// `env_allows_color`).
pub fn env_allows_color() -> Bool {
  match @platform.env_var("TERM") {
    None => if @platform.os() != Windows { return false }
    Some("dumb") => return false
    Some(_) => ()
  }
  @platform.env_var("NO_COLOR") is None
}
