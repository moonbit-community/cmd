///|
/// Returns a default set of color specifications.
///
/// Additional color specifications can be added to the list returned. More
/// recently added specifications override previously added specifications.
pub fn default_color_specs() -> Array[UserColorSpec] {
  [
    { ty: Path, value: Fg(Magenta), },
    { ty: Line, value: Fg(Green), },
    { ty: Match, value: Fg(Red), },
    { ty: Match, value: Style(Bold), },
  ]
}

///|
/// An error that can occur when parsing color specifications.
pub(all) suberror ColorError {
  /// This occurs when an unrecognized output type is used.
  UnrecognizedOutType(String)
  /// This occurs when an unrecognized spec type is used.
  UnrecognizedSpecType(String)
  /// This occurs when an unrecognized color name is used. The first field
  /// is the invalid color, the second is the full error message.
  UnrecognizedColor(String, String)
  /// This occurs when an unrecognized style attribute is used.
  UnrecognizedStyle(String)
  /// This occurs when the format of a color specification is invalid.
  InvalidFormat(String)
} derive(Eq, Debug)

///|
fn ColorError::from_parse_error(err : @termcolor.ParseColorError) -> ColorError {
  UnrecognizedColor(err.invalid(), err.to_string())
}

///|
pub fn ColorError::to_string(self : ColorError) -> String {
  match self {
    UnrecognizedOutType(name) =>
      "unrecognized output type '\{name}'. Choose from: path, line, column, match, highlight."
    UnrecognizedSpecType(name) =>
      "unrecognized spec type '\{name}'. Choose from: fg, bg, style, none."
    UnrecognizedColor(_, msg) => msg
    UnrecognizedStyle(name) =>
      "unrecognized style attribute '\{name}'. Choose from: nobold, bold, nointense, intense, nounderline, underline, noitalic, italic."
    InvalidFormat(original) =>
      "invalid color spec format: '\{original}'. Valid format is '(path|line|column|match|highlight):(fg|bg|style):(value)'."
  }
}

///|
pub impl Show for ColorError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// A merged set of color specifications.
///
/// This set of color specifications represents the various color types that
/// are supported by the printers in this package. A set of color
/// specifications can be created from a sequence of `UserColorSpec`s.
pub struct ColorSpecs {
  priv path : @termcolor.ColorSpec
  priv line : @termcolor.ColorSpec
  priv column : @termcolor.ColorSpec
  priv matched : @termcolor.ColorSpec
  priv highlight : @termcolor.ColorSpec
} derive(Eq, Debug)

///|
/// A single color specification provided by the user.
///
/// The format of a spec is a triple `{type}:{attribute}:{value}` where
/// `{type}` is one of `path`, `line`, `column`, `match` or `highlight`,
/// `{attribute}` is one of `fg`, `bg`, `style` or `none` and `{value}` is
/// a color (for `fg`/`bg`) or a style instruction (`bold`, `nobold`,
/// `intense`, `nointense`, `underline`, `nounderline`, `italic`,
/// `noitalic`).
pub struct UserColorSpec {
  priv ty : OutType
  priv value : SpecValue
} derive(Eq, Debug)

///|
/// Convert this user provided color specification to a specification that
/// can be used with `termcolor`.
pub fn UserColorSpec::to_color_spec(
  self : UserColorSpec,
) -> @termcolor.ColorSpec {
  let spec = @termcolor.ColorSpec::new()
  self.value.merge_into(spec)
  spec
}

///|
priv enum SpecValue {
  None
  Fg(@termcolor.Color)
  Bg(@termcolor.Color)
  Style(Style)
} derive(Eq, Debug)

///|
priv enum OutType {
  Path
  Line
  Column
  Match
  Highlight
} derive(Eq, Debug)

///|
priv enum SpecType {
  Fg
  Bg
  Style
  None
}

///|
priv enum Style {
  Bold
  NoBold
  Intense
  NoIntense
  Underline
  NoUnderline
  Italic
  NoItalic
} derive(Eq, Debug)

///|
/// The default set of color specifications: no colors at all.
pub fn ColorSpecs::default() -> ColorSpecs {
  {
    path: @termcolor.ColorSpec::new(),
    line: @termcolor.ColorSpec::new(),
    column: @termcolor.ColorSpec::new(),
    matched: @termcolor.ColorSpec::new(),
    highlight: @termcolor.ColorSpec::new(),
  }
}

///|
/// Create color specifications from a list of user supplied
/// specifications.
pub fn ColorSpecs::new(specs : ArrayView[UserColorSpec]) -> ColorSpecs {
  let merged = ColorSpecs::default()
  for spec in specs {
    match spec.ty {
      Path => spec.value.merge_into(merged.path)
      Line => spec.value.merge_into(merged.line)
      Column => spec.value.merge_into(merged.column)
      Match => spec.value.merge_into(merged.matched)
      Highlight => spec.value.merge_into(merged.highlight)
    }
  }
  merged
}

///|
/// Create a default set of specifications that have color.
pub fn ColorSpecs::default_with_color() -> ColorSpecs {
  ColorSpecs::new(default_color_specs())
}

///|
/// Return the color specification for coloring file paths.
pub fn ColorSpecs::path(self : ColorSpecs) -> @termcolor.ColorSpec {
  self.path
}

///|
/// Return the color specification for coloring line numbers.
pub fn ColorSpecs::line(self : ColorSpecs) -> @termcolor.ColorSpec {
  self.line
}

///|
/// Return the color specification for coloring column numbers.
pub fn ColorSpecs::column(self : ColorSpecs) -> @termcolor.ColorSpec {
  self.column
}

///|
/// Return the color specification for coloring matched text.
pub fn ColorSpecs::matched(self : ColorSpecs) -> @termcolor.ColorSpec {
  self.matched
}

///|
/// Return the color specification for coloring entire line if there is a
/// matched text.
pub fn ColorSpecs::highlight(self : ColorSpecs) -> @termcolor.ColorSpec {
  self.highlight
}

///|
fn SpecValue::merge_into(
  self : SpecValue,
  cspec : @termcolor.ColorSpec,
) -> Unit {
  match self {
    None => cspec.clear()
    Fg(color) => cspec.set_fg(Some(color)) |> ignore
    Bg(color) => cspec.set_bg(Some(color)) |> ignore
    Style(style) =>
      match style {
        Bold => cspec.set_bold(true) |> ignore
        NoBold => cspec.set_bold(false) |> ignore
        Intense => cspec.set_intense(true) |> ignore
        NoIntense => cspec.set_intense(false) |> ignore
        Underline => cspec.set_underline(true) |> ignore
        NoUnderline => cspec.set_underline(false) |> ignore
        Italic => cspec.set_italic(true) |> ignore
        NoItalic => cspec.set_italic(false) |> ignore
      }
  }
}

///|
/// Parses a user color specification such as `path:fg:blue`.
pub fn UserColorSpec::parse(s : String) -> UserColorSpec raise ColorError {
  let pieces : Array[StringView] = s.split(":").collect()
  if pieces.length() <= 1 || pieces.length() > 3 {
    raise InvalidFormat(s)
  }
  let otype = parse_out_type(pieces[0])
  match parse_spec_type(pieces[1]) {
    None => { ty: otype, value: None, }
    Style => {
      if pieces.length() < 3 {
        raise InvalidFormat(s)
      }
      let style = parse_style(pieces[2])
      { ty: otype, value: Style(style), }
    }
    Fg => {
      if pieces.length() < 3 {
        raise InvalidFormat(s)
      }
      let color = @termcolor.Color::parse(pieces[2].to_owned()) catch {
        e => raise ColorError::from_parse_error(e)
      }
      { ty: otype, value: Fg(color), }
    }
    Bg => {
      if pieces.length() < 3 {
        raise InvalidFormat(s)
      }
      let color = @termcolor.Color::parse(pieces[2].to_owned()) catch {
        e => raise ColorError::from_parse_error(e)
      }
      { ty: otype, value: Bg(color), }
    }
  }
}

///|
fn parse_out_type(s : StringView) -> OutType raise ColorError {
  match s.to_lower() {
    "path" => Path
    "line" => Line
    "column" => Column
    "match" => Match
    "highlight" => Highlight
    _ => raise UnrecognizedOutType(s.to_owned())
  }
}

///|
fn parse_spec_type(s : StringView) -> SpecType raise ColorError {
  match s.to_lower() {
    "fg" => Fg
    "bg" => Bg
    "style" => Style
    "none" => None
    _ => raise UnrecognizedSpecType(s.to_owned())
  }
}

///|
fn parse_style(s : StringView) -> Style raise ColorError {
  match s.to_lower() {
    "bold" => Bold
    "nobold" => NoBold
    "intense" => Intense
    "nointense" => NoIntense
    "underline" => Underline
    "nounderline" => NoUnderline
    "italic" => Italic
    "noitalic" => NoItalic
    _ => raise UnrecognizedStyle(s.to_owned())
  }
}
