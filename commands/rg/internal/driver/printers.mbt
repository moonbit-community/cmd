///|
/// The printer used for a search.
pub enum Printer {
  Standard(@printer.Standard)
  Summary(@printer.Summary)
  JSON(@printer.JSON)
}

///|
fn Printer::get_mut(self : Printer) -> &@termcolor.WriteColor {
  match self {
    Standard(p) => p.get_mut()
    Summary(p) => p.get_mut()
    JSON(p) => p.get_mut()
  }
}

///|
/// Builds stdout according to the color and buffering settings.
fn ExecutionPlan::stdout(self : ExecutionPlan) -> &@termcolor.WriteColor {
  let line_buffered = match self.output.buffer {
    Auto => self.output.is_terminal_stdout
    Line => true
    Block => false
  }
  let wtr = StdoutWriter::new(line_buffered)
  let use_color = match self.output.color {
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
fn ExecutionPlan::path_printer(
  self : ExecutionPlan,
  wtr : &@termcolor.WriteColor,
) -> @printer.PathPrinter {
  @printer.PathPrinter::new(
    wtr,
    colors=self.output.colors,
    hyperlink=self.output.hyperlink_config,
    separator=self.output.path_separator,
    terminator=self.output.path_terminator.unwrap_or(b'\n'),
  )
}

///|
fn ExecutionPlan::printer(
  self : ExecutionPlan,
  search_mode : SearchMode,
  wtr : &@termcolor.WriteColor,
) -> Printer {
  let summary_kind : @printer.SummaryKind = if self.output.quiet {
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
fn ExecutionPlan::printer_json(
  self : ExecutionPlan,
  wtr : &@termcolor.WriteColor,
) -> @printer.JSON {
  @printer.JSON::new(wtr, replacement=self.output.replace, clock=@sys.now_nanos)
}

///|
fn ExecutionPlan::printer_standard(
  self : ExecutionPlan,
  wtr : &@termcolor.WriteColor,
) -> @printer.Standard {
  @printer.Standard::new(
    wtr,
    byte_offset=self.output.byte_offset,
    colors=self.output.colors,
    column=self.output.column,
    heading=self.output.heading,
    hyperlink=self.output.hyperlink_config,
    max_columns_preview=self.output.max_columns_preview,
    max_columns=self.output.max_columns.map(saturate_i64),
    only_matching=self.output.only_matching,
    path=self.output.with_filename,
    path_terminator=self.output.path_terminator,
    per_match_one_line=true,
    per_match=self.output.vimgrep,
    replacement=self.output.replace,
    separator_context=self.output.context_separator,
    separator_field_context=self.output.field_context_separator,
    separator_field_match=self.output.field_match_separator,
    separator_path=self.output.path_separator,
    stats=self.output.stats,
    trim_ascii=self.output.trim,
    separator_search=self.output.file_separator,
    clock=@sys.now_nanos,
  )
}

///|
fn ExecutionPlan::printer_summary(
  self : ExecutionPlan,
  wtr : &@termcolor.WriteColor,
  kind : @printer.SummaryKind,
) -> @printer.Summary {
  @printer.Summary::new(
    wtr,
    colors=self.output.colors,
    exclude_zero=!self.output.include_zero,
    hyperlink=self.output.hyperlink_config,
    kind~,
    path=self.output.with_filename,
    path_terminator=self.output.path_terminator,
    separator_field=b":",
    separator_path=self.output.path_separator,
    stats=self.output.stats,
    clock=@sys.now_nanos,
  )
}
