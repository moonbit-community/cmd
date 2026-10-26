///|
/// The printer used for a search.
pub enum Printer {
  Standard(@printer.Standard)
  Summary(@printer.Summary)
  JSON(@printer.JSON)
}

///|
pub fn Printer::get_mut(self : Printer) -> &@termcolor.WriteColor {
  match self {
    Standard(p) => p.get_mut()
    Summary(p) => p.get_mut()
    JSON(p) => p.get_mut()
  }
}

///|
/// Builds stdout according to the color and buffering settings.
pub fn HiArgs::stdout(self : HiArgs) -> &@termcolor.WriteColor {
  let line_buffered = match self.buffer {
    Auto => self.is_terminal_stdout
    Line => true
    Block => false
  }
  let wtr = StdoutWriter::new(1, line_buffered)
  let use_color = match self.color {
    Never => false
    Ansi | Always => true
    Auto => {
      // Like termcolor: auto means color only if TERM isn't "dumb" and
      // NO_COLOR is unset. (Auto here already implies a terminal.)
      let term = @sys.env_var("TERM")
      let no_color = @sys.env_var("NO_COLOR")
      match (term, no_color) {
        (_, Some(_)) => false
        (Some("dumb"), _) | (None, _) => false
        _ => true
      }
    }
  }
  if use_color {
    (@termcolor.Ansi::new(wtr) : &@termcolor.WriteColor)
  } else {
    (@termcolor.NoColor::new(wtr) : &@termcolor.WriteColor)
  }
}

///|
fn HiArgs::path_printer_builder(self : HiArgs) -> @printer.PathPrinterBuilder {
  @printer.PathPrinterBuilder::new()
  .color_specs(self.colors)
  .hyperlink(self.hyperlink_config)
  .separator(self.path_separator)
  .terminator(self.path_terminator.unwrap_or(b'\n'))
}

///|
pub fn HiArgs::printer(
  self : HiArgs,
  search_mode : SearchMode,
  wtr : &@termcolor.WriteColor,
) -> Printer {
  let summary_kind : @printer.SummaryKind = if self.quiet {
    match search_mode {
      FilesWithoutMatch => QuietWithoutMatch
      _ => QuietWithMatch
    }
  } else {
    match search_mode {
      FilesWithMatches => PathWithMatch
      FilesWithoutMatch => PathWithoutMatch
      Count => Count
      CountMatches => CountMatches
      JSON => return JSON(self.printer_json(wtr))
      Standard => return Standard(self.printer_standard(wtr))
    }
  }
  Summary(self.printer_summary(wtr, summary_kind))
}

///|
fn HiArgs::printer_json(
  self : HiArgs,
  wtr : &@termcolor.WriteColor,
) -> @printer.JSON {
  @printer.JSONBuilder::new()
  .pretty(false)
  .always_begin_end(false)
  .replacement(self.replace)
  .clock(@sys.now_nanos)
  .build(wtr)
}

///|
fn HiArgs::printer_standard(
  self : HiArgs,
  wtr : &@termcolor.WriteColor,
) -> @printer.Standard {
  @printer.StandardBuilder::new()
  .byte_offset(self.byte_offset)
  .color_specs(self.colors)
  .column(self.column)
  .heading(self.heading)
  .hyperlink(self.hyperlink_config)
  .max_columns_preview(self.max_columns_preview)
  .max_columns(self.max_columns.map(saturate_i64))
  .only_matching(self.only_matching)
  .path(self.with_filename)
  .path_terminator(self.path_terminator)
  .per_match_one_line(true)
  .per_match(self.vimgrep)
  .replacement(self.replace)
  .separator_context(self.context_separator)
  .separator_field_context(self.field_context_separator)
  .separator_field_match(self.field_match_separator)
  .separator_path(self.path_separator)
  .stats(self.stats is Some(_))
  .trim_ascii(self.trim)
  .separator_search(self.file_separator)
  .clock(@sys.now_nanos)
  .build(wtr)
}

///|
fn HiArgs::printer_summary(
  self : HiArgs,
  wtr : &@termcolor.WriteColor,
  kind : @printer.SummaryKind,
) -> @printer.Summary {
  @printer.SummaryBuilder::new()
  .color_specs(self.colors)
  .exclude_zero(!self.include_zero)
  .hyperlink(self.hyperlink_config)
  .kind(kind)
  .path(self.with_filename)
  .path_terminator(self.path_terminator)
  .separator_field(b":")
  .separator_path(self.path_separator)
  .stats(self.stats is Some(_))
  .clock(@sys.now_nanos)
  .build(wtr)
}
