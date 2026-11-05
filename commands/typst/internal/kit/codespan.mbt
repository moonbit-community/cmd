// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// A port of the terminal renderer of `codespan-reporting` 0.11.1 (which
// typst-kit's diagnostics use): `term::emit` with the `Rich` and `Short`
// display styles, `term::views` and `term::renderer`.
//
// Byte indices are UTF-8 based, like upstream.

///|
/// A severity level for diagnostic messages
/// (`codespan_reporting::diagnostic::Severity`).
#derive(Eq, Debug)
pub(all) enum Severity {
  Bug
  Error
  Warning
  Note
  Help
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Severity with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Severity with @debug.Debug::{to_repr}

///|
/// The style of a label (`LabelStyle`). Ordered like upstream's derived
/// `PartialOrd`: `Primary < Secondary`.
#derive(Eq, Debug)
pub(all) enum LabelStyle {
  Primary
  Secondary
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LabelStyle with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend LabelStyle with @debug.Debug::{to_repr}

///|
fn LabelStyle::ord(self : LabelStyle) -> Int32 {
  match self {
    Primary => 0
    Secondary => 1
  }
}

///|
/// A label describing an underlined region of code associated with a
/// diagnostic.
pub(all) struct Label {
  style : LabelStyle
  file_id : @syntax.FileId
  /// The UTF-8 byte range in the file.
  start : Int32
  end : Int32
  message : String
}

///|
/// Create a new label with a style of `LabelStyle::Primary`.
pub fn Label::primary(
  file_id : @syntax.FileId,
  start : Int32,
  end : Int32,
) -> Label {
  { style: Primary, file_id, start, end, message: "", }
}

///|
/// Create a new label with a style of `LabelStyle::Secondary`.
pub fn Label::secondary(
  file_id : @syntax.FileId,
  start : Int32,
  end : Int32,
) -> Label {
  { style: Secondary, file_id, start, end, message: "", }
}

///|
/// Add a message to the diagnostic.
pub fn Label::with_message(self : Label, message : String) -> Label {
  { ..self, message, }
}

///|
/// Represents a diagnostic message that can provide information like
/// errors and warnings to the user.
pub(all) struct Diagnostic {
  severity : Severity
  message : String
  labels : Array[Label]
  notes : Array[String]
}

///|
/// How a diagnostic is displayed (`term::DisplayStyle`).
#derive(Eq, Debug)
pub(all) enum DisplayStyle {
  Rich
  Short
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DisplayStyle with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DisplayStyle with @debug.Debug::{to_repr}

///|
/// Configures how a diagnostic is rendered (`term::Config`).
pub(all) struct Config {
  display_style : DisplayStyle
  tab_width : Int32
  start_context_lines : Int32
  end_context_lines : Int32
}

///|
/// The default configuration.
pub fn Config::default() -> Config {
  {
    display_style: Rich,
    tab_width: 4,
    start_context_lines: 3,
    end_context_lines: 1,
  }
}

///|
/// An error from the [`Files`] of a diagnostic
/// (`codespan_reporting::files::Error`).
pub(all) suberror FilesError {
  FileMissing
  IndexTooLarge(Int32, Int32)
  LineTooLarge(Int32, Int32)
  ColumnTooLarge(Int32, Int32)
  InvalidCharBoundary(Int32)
  Io(String)
}

///|
pub impl Show for FilesError with fn output(self, logger) {
  match self {
    FileMissing => logger.write_string("file missing")
    IndexTooLarge(given, max) =>
      logger.write_string("invalid index \{given}, maximum index is \{max}")
    LineTooLarge(given, max) =>
      logger.write_string("invalid line \{given}, maximum line is \{max}")
    ColumnTooLarge(given, max) =>
      logger.write_string("invalid column \{given}, maximum column \{max}")
    InvalidCharBoundary(_) =>
      logger.write_string("index is not a code point boundary")
    Io(err) => logger.write_string(err)
  }
}

///|
pub extend FilesError with Show::{to_string, output}

///|
/// A minimal interface for accessing source files when rendering
/// diagnostics (`codespan_reporting::files::Files`).
pub(open) trait Files {
  /// The user-facing name of a file.
  fn name(Self, @syntax.FileId) -> String raise FilesError
  /// The lines of a file.
  fn lines(Self, @syntax.FileId) -> @syntax.Lines raise FilesError
  /// The index of the line at the given byte index.
  fn line_index(Self, @syntax.FileId, Int32) -> Int32 raise FilesError
  /// The user-facing line number at the given line index.
  fn line_number(Self, @syntax.FileId, Int32) -> Int32 raise FilesError = _
  /// The user-facing column number at the given line index and byte index.
  fn column_number(Self, @syntax.FileId, Int32, Int32) -> Int32 raise FilesError
  /// The byte range of line in the source of the file.
  fn line_range(Self, @syntax.FileId, Int32) -> (Int32, Int32) raise FilesError
}

///|
impl Files with fn line_number(_self, _id, line_index) {
  line_index + 1
}

///|
/// A user-facing location in a source file.
priv struct Location {
  line_number : Int32
  column_number : Int32
}

///|
/// Convenience method for returning line and column number at the given
/// byte index in the file.
fn location(
  files : &Files,
  id : @syntax.FileId,
  byte_index : Int32,
) -> Location raise FilesError {
  let line_index = files.line_index(id, byte_index)
  {
    line_number: files.line_number(id, line_index),
    column_number: files.column_number(id, line_index, byte_index),
  }
}

///|
/// Emit a diagnostic using the given writer, context, config, and files
/// (`term::emit`).
pub fn emit(
  writer : ColorWriter,
  config : Config,
  files : &Files,
  diagnostic : Diagnostic,
) -> Unit raise FilesError {
  let renderer : Renderer = { writer, config, }
  match config.display_style {
    Rich => render_rich(diagnostic, config, files, renderer)
    Short => render_short(diagnostic, files, renderer)
  }
}

// ---------------------------------------------------------------------------
// Views (`term::views`).

///|
fn count_digits(n : Int32) -> Int32 {
  let mut n = n
  let mut count = 0
  while n != 0 {
    count += 1
    n /= 10
  }
  count
}

///|
/// A single-line label: style, byte range in the line, message.
priv struct SingleLabel {
  style : LabelStyle
  start : Int32
  end : Int32
  message : String
}

///|
priv enum MultiLabel {
  /// Multi-line label top: the byte index of the start of the label.
  Top(Int32)
  /// Left vertical labels for multi-line labels.
  Left
  /// Multi-line label bottom: the byte index of the end of the label and
  /// its message.
  Bottom(Int32, String)
}

///|
priv struct MultiLabelEntry {
  index : Int32
  style : LabelStyle
  label : MultiLabel
}

///|
priv struct Line {
  number : Int32
  start : Int32
  end : Int32
  single_labels : Array[SingleLabel]
  multi_labels : Array[MultiLabelEntry]
  mut must_render : Bool
}

///|
priv struct LabeledFile {
  file_id : @syntax.FileId
  mut start : Int32
  name : String
  mut location : Location
  mut num_multi_labels : Int32
  lines : Map[Int32, Line]
  mut max_label_style : LabelStyle
}

///|
fn LabeledFile::get_or_insert_line(
  self : LabeledFile,
  line_index : Int32,
  line_range : (Int32, Int32),
  line_number : Int32,
) -> Line {
  match self.lines.get(line_index) {
    Some(line) => line
    None => {
      let line : Line = {
        start: line_range.0,
        end: line_range.1,
        number: line_number,
        single_labels: [],
        multi_labels: [],
        // This has to be false by default so we know if it must be rendered
        // by another condition already.
        must_render: false,
      }
      self.lines[line_index] = line
      line
    }
  }
}

///|
/// The line indices of a labeled file in ascending order (upstream uses a
/// `BTreeMap`).
fn LabeledFile::sorted_lines(self : LabeledFile) -> Array[(Int32, Line)] {
  let out = self.lines.to_array()
  out.sort_by((a, b) => a.0.compare(b.0))
  out
}

///|
/// Rust's `slice::binary_search_by` (the algorithm of Rust 1.92).
fn[T] binary_search_by(xs : Array[T], f : (T) -> Int32) -> Int32 {
  let mut size = xs.length()
  if size == 0 {
    return 0
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    let cmp = f(xs[mid])
    base = if cmp > 0 { base } else { mid }
    size -= half
  }
  let cmp = f(xs[base])
  if cmp == 0 {
    base
  } else {
    base + (if cmp < 0 { 1 } else { 0 })
  }
}

///|
/// Output a richly formatted diagnostic, with source code previews
/// (`RichDiagnostic::render`).
fn render_rich(
  diagnostic : Diagnostic,
  config : Config,
  files : &Files,
  renderer : Renderer,
) -> Unit raise FilesError {
  let labeled_files : Array[LabeledFile] = []
  // Keep track of the outer padding to use when rendering the snippets of
  // source code.
  let mut outer_padding = 0

  // Group labels by file
  for label in diagnostic.labels {
    let start_line_index = files.line_index(label.file_id, label.start)
    let start_line_number = files.line_number(label.file_id, start_line_index)
    let start_line_range = files.line_range(label.file_id, start_line_index)
    let end_line_index = files.line_index(label.file_id, label.end)
    let end_line_number = files.line_number(label.file_id, end_line_index)
    let end_line_range = files.line_range(label.file_id, end_line_index)
    outer_padding = @cmp.maximum(outer_padding, count_digits(start_line_number))
    outer_padding = @cmp.maximum(outer_padding, count_digits(end_line_number))

    // NOTE: This could be made more efficient by using an associative data
    // structure like a hashmap or B-tree, but we use a vector to preserve
    // the order that unique files appear in the list of labels.
    let labeled_file = match
      labeled_files.search_by(f => f.file_id == label.file_id) {
      Some(i) => {
        let labeled_file = labeled_files[i]
        // another diagnostic also referenced this file
        if labeled_file.max_label_style.ord() > label.style.ord() ||
          (
            labeled_file.max_label_style == label.style &&
            labeled_file.start > label.start
          ) {
          // this label has a higher style or has the same style but starts
          // earlier
          labeled_file.start = label.start
          labeled_file.location = location(files, label.file_id, label.start)
          labeled_file.max_label_style = label.style
        }
        labeled_file
      }
      None => {
        // no other diagnostic referenced this file yet
        let labeled_file : LabeledFile = {
          file_id: label.file_id,
          start: label.start,
          name: files.name(label.file_id),
          location: location(files, label.file_id, label.start),
          num_multi_labels: 0,
          lines: {},
          max_label_style: label.style,
        }
        labeled_files.push(labeled_file)
        labeled_file
      }
    }
    if start_line_index == end_line_index {
      // Single line
      let label_start = label.start - start_line_range.0
      // Ensure that we print at least one caret, even when we have a
      // zero-length source range.
      let label_end = @cmp.maximum(
        label.end - start_line_range.0,
        label_start + 1,
      )
      let line = labeled_file.get_or_insert_line(
        start_line_index, start_line_range, start_line_number,
      )

      // Ensure that the single line labels are lexicographically sorted by
      // the range of source code that they cover.
      let index = binary_search_by(line.single_labels, l => {
        let c = l.start.compare(label_start)
        if c != 0 {
          c
        } else {
          l.end.compare(label_end)
        }
      })
      line.single_labels.insert(index, {
        style: label.style,
        start: label_start,
        end: label_end,
        message: label.message,
      })

      // If this line is not rendered, the SingleLabel is not visible.
      line.must_render = true
    } else {
      // Multiple lines
      let label_index = labeled_file.num_multi_labels
      labeled_file.num_multi_labels += 1

      // First labeled line
      let label_start = label.start - start_line_range.0
      let start_line = labeled_file.get_or_insert_line(
        start_line_index, start_line_range, start_line_number,
      )
      start_line.multi_labels.push({
        index: label_index,
        style: label.style,
        label: Top(label_start),
      })

      // The first line has to be rendered so the start of the label is
      // visible.
      start_line.must_render = true

      // Marked lines
      for line_index in (start_line_index + 1)..<end_line_index {
        let line_range = files.line_range(label.file_id, line_index)
        let line_number = files.line_number(label.file_id, line_index)
        outer_padding = @cmp.maximum(outer_padding, count_digits(line_number))
        let line = labeled_file.get_or_insert_line(
          line_index, line_range, line_number,
        )
        line.multi_labels.push({
          index: label_index,
          style: label.style,
          label: Left,
        })

        // The line should be rendered to match the configuration of how much
        // context to show.
        line.must_render = line.must_render ||
          // Is this line part of the context after the start of the label?
          line_index - start_line_index <= config.start_context_lines ||
          // Is this line part of the context before the end of the label?
          end_line_index - line_index <= config.end_context_lines
      }

      // Last labeled line
      let label_end = label.end - end_line_range.0
      let end_line = labeled_file.get_or_insert_line(
        end_line_index, end_line_range, end_line_number,
      )
      end_line.multi_labels.push({
        index: label_index,
        style: label.style,
        label: Bottom(label_end, label.message),
      })

      // The last line has to be rendered so the end of the label is
      // visible.
      end_line.must_render = true
    }
  }

  // Header and message
  renderer.render_header(None, diagnostic.severity, diagnostic.message)

  // Source snippets
  for file_index, labeled_file in labeled_files {
    let lines = files.lines(labeled_file.file_id)
    let source = lines.text()

    // Top left border and locus.
    if !labeled_file.lines.is_empty() {
      renderer.render_snippet_start(
        outer_padding,
        labeled_file.name,
        labeled_file.location,
      )
      renderer.render_snippet_empty(
        outer_padding,
        diagnostic.severity,
        labeled_file.num_multi_labels,
        [],
      )
    }
    let all_lines = labeled_file.sorted_lines()
    let rendered = all_lines.filter(entry => entry.1.must_render)
    for i, entry in rendered {
      let (line_index, line) = entry
      renderer.render_snippet_source(
        outer_padding,
        line.number,
        slice_bytes(lines, source, line.start, line.end),
        diagnostic.severity,
        line.single_labels,
        labeled_file.num_multi_labels,
        line.multi_labels,
      )

      // Check to see if we need to render any intermediate stuff before
      // rendering the next line.
      if i + 1 < rendered.length() {
        let next_line_index = rendered[i + 1].0
        let diff = next_line_index - line_index
        if diff == 1 {
          // Consecutive lines
          ()
        } else if diff == 2 {
          // One line between the current line and the next line
          let file_id = labeled_file.file_id
          // This line was not intended to be rendered initially. To render
          // the line right, we have to get back the original labels.
          let labels = match labeled_file.lines.get(line_index + 1) {
            Some(line) => line.multi_labels
            None => []
          }
          let (s, e) = files.line_range(file_id, line_index + 1)
          renderer.render_snippet_source(
            outer_padding,
            files.line_number(file_id, line_index + 1),
            slice_bytes(lines, source, s, e),
            diagnostic.severity,
            [],
            labeled_file.num_multi_labels,
            labels,
          )
        } else {
          // More than one line between the current line and the next line.
          renderer.render_snippet_break(
            outer_padding,
            diagnostic.severity,
            labeled_file.num_multi_labels,
            line.multi_labels,
          )
        }
      }
    }

    // Check to see if we should render a trailing border after the final
    // line of the snippet.
    if file_index + 1 == labeled_files.length() && diagnostic.notes.is_empty() {
      // We don't render a border if we are at the final newline without
      // trailing notes, because it would end up looking too spaced-out in
      // combination with the final new line.
      ()
    } else {
      // Render the trailing snippet border.
      renderer.render_snippet_empty(
        outer_padding,
        diagnostic.severity,
        labeled_file.num_multi_labels,
        [],
      )
    }
  }

  // Additional notes
  for note in diagnostic.notes {
    renderer.render_snippet_note(outer_padding, note)
  }
  renderer.render_empty()
}

///|
/// The text of a UTF-8 byte range of a file.
fn slice_bytes(
  lines : @syntax.Lines,
  source : String,
  start : Int32,
  end : Int32,
) -> String {
  let a = lines.byte_to_utf16(start).unwrap_or(source.length())
  let b = lines.byte_to_utf16(end).unwrap_or(source.length())
  source.unsafe_substring(start=a, end=b)
}

///|
/// Output a short diagnostic, with a line number, severity, and message
/// (`ShortDiagnostic::render` without notes).
fn render_short(
  diagnostic : Diagnostic,
  files : &Files,
  renderer : Renderer,
) -> Unit raise FilesError {
  // Located headers
  let mut primary_labels_encountered = 0
  for label in diagnostic.labels {
    if label.style != Primary {
      continue
    }
    primary_labels_encountered += 1
    renderer.render_header(
      Some(
        (files.name(label.file_id), location(files, label.file_id, label.start)),
      ),
      diagnostic.severity,
      diagnostic.message,
    )
  }

  // Fallback to printing a non-located header if no primary labels were
  // encountered
  if primary_labels_encountered == 0 {
    renderer.render_header(None, diagnostic.severity, diagnostic.message)
  }
}

// ---------------------------------------------------------------------------
// Renderer (`term::renderer`).

///|
/// A renderer of display list entries.
priv struct Renderer {
  writer : ColorWriter
  config : Config
}

///|
/// The blue of the default styles (cyan on Windows, where blue is hard to
/// see).
fn blue() -> Color {
  if @platform.os() == Windows {
    Cyan
  } else {
    Blue
  }
}

///|
fn header_style(severity : Severity) -> ColorSpec {
  let header = ColorSpec::new().with_bold().with_intense()
  match severity {
    Bug => header.with_fg(Red)
    Error => header.with_fg(Red)
    Warning => header.with_fg(Yellow)
    Note => header.with_fg(Green)
    Help => header.with_fg(Cyan)
  }
}

///|
fn header_message_style() -> ColorSpec {
  ColorSpec::new().with_bold().with_intense()
}

///|
fn label_style(severity : Severity, style : LabelStyle) -> ColorSpec {
  match (style, severity) {
    (Primary, Bug) => ColorSpec::new().with_fg(Red)
    (Primary, Error) => ColorSpec::new().with_fg(Red)
    (Primary, Warning) => ColorSpec::new().with_fg(Yellow)
    (Primary, Note) => ColorSpec::new().with_fg(Green)
    (Primary, Help) => ColorSpec::new().with_fg(Cyan)
    (Secondary, _) => ColorSpec::new().with_fg(blue())
  }
}

///|
fn blue_style() -> ColorSpec {
  ColorSpec::new().with_fg(blue())
}

///|
fn Renderer::write(self : Renderer, s : String) -> Unit {
  self.writer.write(s)
}

///|
fn Renderer::write_char(self : Renderer, c : Char) -> Unit {
  self.writer.write_char(c)
}

///|
fn Renderer::writeln(self : Renderer) -> Unit {
  self.writer.write_char('\n')
}

///|
/// Diagnostic header, with severity, code, and message.
fn Renderer::render_header(
  self : Renderer,
  locus : (String, Location)?,
  severity : Severity,
  message : String,
) -> Unit {
  if locus is Some(locus) {
    self.snippet_locus(locus.0, locus.1)
    self.write(": ")
  }
  self.writer.set_color(header_style(severity))
  self.write(
    match severity {
      Bug => "bug"
      Error => "error"
      Warning => "warning"
      Help => "help"
      Note => "note"
    },
  )
  self.writer.set_color(header_message_style())
  self.write(": \{message}")
  self.writer.reset()
  self.writeln()
}

///|
/// Empty line.
fn Renderer::render_empty(self : Renderer) -> Unit {
  self.writeln()
}

///|
/// Top left border and locus.
fn Renderer::render_snippet_start(
  self : Renderer,
  outer_padding : Int32,
  name : String,
  location : Location,
) -> Unit {
  self.outer_gutter(outer_padding)
  self.writer.set_color(blue_style())
  self.write("┌─")
  self.writer.reset()
  self.write(" ")
  self.snippet_locus(name, location)
  self.writeln()
}

///|
/// The UTF-8 byte indices and characters of a string.
fn char_indices(s : String) -> Array[(Int32, Char)] {
  let out = []
  let mut byte = 0
  for c in s {
    out.push((byte, c))
    byte += utf8_char_len(c)
  }
  out
}

///|
fn utf8_char_len(c : Char) -> Int32 {
  let c = c.to_int()
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
/// The byte index and display width of a character.
priv struct Metrics {
  byte_index : Int32
  unicode_width : Int32
}

///|
fn Renderer::char_metrics(
  self : Renderer,
  chars : Array[(Int32, Char)],
) -> Array[(Metrics, Char)] {
  let tab_width = self.config.tab_width
  let mut unicode_column = 0
  chars.map(entry => {
    let (byte_index, ch) = entry
    let unicode_width = if ch == '\t' {
      if tab_width == 0 {
        // Guard divide-by-zero
        0
      } else {
        tab_width - unicode_column % tab_width
      }
    } else {
      @unicode.char_width(ch).unwrap_or(0)
    }
    unicode_column += unicode_width
    ({ byte_index, unicode_width, }, ch)
  })
}

///|
fn is_overlapping(s0 : Int32, e0 : Int32, s1 : Int32, e1 : Int32) -> Bool {
  let start = @cmp.maximum(s0, s1)
  let end = @cmp.minimum(e0, e1)
  start < end
}

///|
fn label_priority_key(style : LabelStyle) -> Int32 {
  match style {
    Secondary => 0
    Primary => 1
  }
}

///|
/// The style with the highest priority (`max_by_key` returns the last
/// maximum).
fn max_style(styles : Array[LabelStyle]) -> LabelStyle? {
  let mut best : LabelStyle? = None
  for style in styles {
    match best {
      Some(b) if label_priority_key(style) < label_priority_key(b) => ()
      _ => best = Some(style)
    }
  }
  best
}

///|
/// The hanging labels: those with messages that are not the trailing
/// label.
fn hanging_labels(
  single_labels : Array[SingleLabel],
  trailing_label : Int32?,
) -> Array[SingleLabel] {
  let out = []
  for i, label in single_labels {
    if label.message != "" && trailing_label != Some(i) {
      out.push(label)
    }
  }
  out
}

///|
/// The byte length of the leading whitespace of a string.
fn leading_whitespace_len(chars : Array[(Int32, Char)], len : Int32) -> Int32 {
  for entry in chars {
    if !@unicode.is_whitespace(entry.1) {
      return entry.0
    }
  }
  len
}

///|
/// A line of source code.
fn Renderer::render_snippet_source(
  self : Renderer,
  outer_padding : Int32,
  line_number : Int32,
  source : String,
  severity : Severity,
  single_labels : Array[SingleLabel],
  num_multi_labels : Int32,
  multi_labels : Array[MultiLabelEntry],
) -> Unit {
  // Trim trailing newlines, linefeeds, and null chars from source, if they
  // exist.
  let mut end = source.length()
  while end > 0 {
    let c = source.code_unit_at(end - 1)
    if c == '\n' || c == '\r' || c == '\u{0}' {
      end -= 1
    } else {
      break
    }
  }
  let source = source.unsafe_substring(start=0, end~)
  let chars = char_indices(source)
  let source_len = @syntax.utf8_len(source)
  let leading_ws = leading_whitespace_len(chars, source_len)

  // Write source line
  // Write outer gutter (with line number) and border
  {
    self.outer_gutter_number(line_number, outer_padding)
    self.border_left()

    // Write inner gutter (with multi-line continuations on the left if
    // necessary)
    let mut iter = 0
    for label_column in 0..<num_multi_labels {
      if iter < multi_labels.length() &&
        multi_labels[iter].index == label_column {
        let entry = multi_labels[iter]
        match entry.label {
          Top(start) if start <= leading_ws =>
            self.label_multi_top_left(severity, entry.style)
          Top(_) => self.inner_gutter_space()
          Left | Bottom(_, _) =>
            self.label_multi_left(severity, entry.style, None)
        }
        iter += 1
      } else {
        self.inner_gutter_space()
      }
    }

    // Write source text
    self.write(" ")
    let mut in_primary = false
    for entry in self.char_metrics(chars) {
      let (metrics, ch) = entry
      let col_start = metrics.byte_index
      let col_end = metrics.byte_index + utf8_char_len(ch)
      let is_primary = single_labels
        .iter()
        .any(l => {
          l.style == Primary &&
          is_overlapping(l.start, l.end, col_start, col_end)
        }) ||
        multi_labels
        .iter()
        .any(m => {
          m.style == Primary &&
          (match m.label {
            Top(start) => col_start >= start
            Left => true
            Bottom(start, _) => col_end <= start
          })
        })
      if is_primary && !in_primary {
        self.writer.set_color(label_style(severity, Primary))
        in_primary = true
      } else if !is_primary && in_primary {
        self.writer.reset()
        in_primary = false
      }
      if ch == '\t' {
        for _ in 0..<metrics.unicode_width {
          self.write(" ")
        }
      } else {
        self.write_char(ch)
      }
    }
    if in_primary {
      self.writer.reset()
    }
    self.writeln()
  }

  // Write single labels underneath source
  if !single_labels.is_empty() {
    // Our plan is as follows:
    //
    // 1. Do an initial scan to find:
    //    - The number of non-empty messages.
    //    - The right-most start and end positions of labels.
    //    - A candidate for a trailing label (where the label's message is
    //      printed to the left of the caret).
    // 2. Check if the trailing label candidate overlaps another label - if
    //    so we print it underneath the carets with the other labels.
    // 3. Print a line of carets, and (possibly) the trailing message to the
    //    left.
    // 4. Print vertical lines pointing to the carets, and the messages for
    //    those carets.

    // The number of messages to print.
    let mut num_messages = 0
    // The right-most start position, eg:
    let mut max_label_start = 0
    // The right-most end position, eg:
    let mut max_label_end = 0
    // A trailing message, eg:
    let mut trailing_label : Int32? = None
    for label_index, label in single_labels {
      if label.message != "" {
        num_messages += 1
      }
      max_label_start = @cmp.maximum(max_label_start, label.start)
      max_label_end = @cmp.maximum(max_label_end, label.end)
      // This is a candidate for the trailing label, so let's record it.
      if label.end == max_label_end {
        if label.message == "" {
          trailing_label = None
        } else {
          trailing_label = Some(label_index)
        }
      }
    }
    if trailing_label is Some(trailing_label_index) {
      let trailing = single_labels[trailing_label_index]
      // Check to see if the trailing label candidate overlaps any of the
      // other labels on the current line.
      let mut overlaps = false
      for label_index, label in single_labels {
        if label_index != trailing_label_index &&
          is_overlapping(trailing.start, trailing.end, label.start, label.end) {
          overlaps = true
        }
      }
      if overlaps {
        // If it does, we'll instead want to render it below the carets
        // along with the other hanging labels.
        trailing_label = None
      }
    }

    // Write a line of carets
    self.outer_gutter(outer_padding)
    self.border_left()
    self.inner_gutter(severity, num_multi_labels, multi_labels)
    self.write(" ")
    let mut previous_label_style : LabelStyle? = None
    let metrics = self.char_metrics(chars)
    // Use a placeholder metrics so the caret is rendered at the end of the
    // line, for zero-length labels at the end of a line.
    metrics.push(({ byte_index: source_len, unicode_width: 1, }, '\u{0}'))
    for entry in metrics {
      let (metrics, ch) = entry
      let col_start = metrics.byte_index
      let col_end = metrics.byte_index + utf8_char_len(ch)
      let current_label_style = max_style(
        single_labels
        .filter(l => is_overlapping(l.start, l.end, col_start, col_end))
        .map(l => l.style),
      )

      // Update style if it has changed
      if previous_label_style != current_label_style {
        match current_label_style {
          None => self.writer.reset()
          Some(style) => self.writer.set_color(label_style(severity, style))
        }
      }
      let caret_ch = match current_label_style {
        Some(Primary) => Some('^')
        Some(Secondary) => Some('-')
        None if metrics.byte_index < max_label_end => Some(' ')
        None => None
      }
      if caret_ch is Some(caret_ch) {
        // FIXME: improve rendering of carets between character boundaries
        for _ in 0..<metrics.unicode_width {
          self.write_char(caret_ch)
        }
      }
      previous_label_style = current_label_style
    }
    // Reset style if it was previously set
    if previous_label_style is Some(_) {
      self.writer.reset()
    }
    // Write first trailing label message
    if trailing_label is Some(i) {
      let label = single_labels[i]
      self.write(" ")
      self.writer.set_color(label_style(severity, label.style))
      self.write(label.message)
      self.writer.reset()
    }
    self.writeln()

    // Write hanging labels pointing to carets
    let trailing_count = if trailing_label is Some(_) { 1 } else { 0 }
    if num_messages > trailing_count {
      // Write first set of vertical lines before hanging labels
      self.outer_gutter(outer_padding)
      self.border_left()
      self.inner_gutter(severity, num_multi_labels, multi_labels)
      self.write(" ")
      self.caret_pointers(
        severity, max_label_start, single_labels, trailing_label, chars,
      )
      self.writeln()

      // Write hanging labels pointing to carets
      let hanging = hanging_labels(single_labels, trailing_label)
      for k = hanging.length() - 1; k >= 0; k = k - 1 {
        let label = hanging[k]
        self.outer_gutter(outer_padding)
        self.border_left()
        self.inner_gutter(severity, num_multi_labels, multi_labels)
        self.write(" ")
        self.caret_pointers(
          severity,
          max_label_start,
          single_labels,
          trailing_label,
          chars.filter(entry => entry.0 < label.start),
        )
        self.writer.set_color(label_style(severity, label.style))
        self.write(label.message)
        self.writer.reset()
        self.writeln()
      }
    }
  }

  // Write top or bottom label carets underneath source
  for multi_label_index, entry in multi_labels {
    let (style, range, bottom_message) = match entry.label {
      Left => continue // no label caret needed
      // no label caret needed if this can be started in front of the line
      Top(start) if start <= leading_ws => continue
      Top(range) => (entry.style, range, None)
      Bottom(range, message) => (entry.style, range, Some(message))
    }
    self.outer_gutter(outer_padding)
    self.border_left()

    // Write inner gutter.
    //
    // This always fills up to `num_multi_labels`, so that the underlines
    // can be aligned with the source line.
    let mut underline : (LabelStyle, Bool)? = None
    let mut iter = 0
    for label_column in 0..<num_multi_labels {
      if iter < multi_labels.length() &&
        multi_labels[iter].index == label_column {
        let i = iter
        let other = multi_labels[iter]
        let ul = underline.map(u => u.0)
        match other.label {
          Left => self.label_multi_left(severity, other.style, ul)
          Top(_) if multi_label_index > i =>
            self.label_multi_left(severity, other.style, ul)
          Bottom(_, _) if multi_label_index < i =>
            self.label_multi_left(severity, other.style, ul)
          Top(_) if multi_label_index == i => {
            underline = Some((other.style, true))
            self.label_multi_top_left(severity, style)
          }
          Bottom(_, _) if multi_label_index == i => {
            underline = Some((other.style, false))
            self.label_multi_bottom_left(severity, style)
          }
          Top(_) | Bottom(_, _) => self.inner_gutter_column(severity, underline)
        }
        iter += 1
      } else {
        self.inner_gutter_column(severity, underline)
      }
    }

    // Finish the top or bottom caret
    match bottom_message {
      None => self.label_multi_top_caret(severity, style, chars, range)
      Some(message) =>
        self.label_multi_bottom_caret(severity, style, chars, range, message)
    }
  }
}

///|
/// An empty source line, for providing additional whitespace to source
/// snippets.
fn Renderer::render_snippet_empty(
  self : Renderer,
  outer_padding : Int32,
  severity : Severity,
  num_multi_labels : Int32,
  multi_labels : Array[MultiLabelEntry],
) -> Unit {
  self.outer_gutter(outer_padding)
  self.border_left()
  self.inner_gutter(severity, num_multi_labels, multi_labels)
  self.writeln()
}

///|
/// A broken source line, for labeling skipped sections of source.
fn Renderer::render_snippet_break(
  self : Renderer,
  outer_padding : Int32,
  severity : Severity,
  num_multi_labels : Int32,
  multi_labels : Array[MultiLabelEntry],
) -> Unit {
  self.outer_gutter(outer_padding)
  self.border_left_break()
  self.inner_gutter(severity, num_multi_labels, multi_labels)
  self.writeln()
}

///|
/// Additional notes.
fn Renderer::render_snippet_note(
  self : Renderer,
  outer_padding : Int32,
  message : String,
) -> Unit {
  for note_line_index, line in rust_lines(message) {
    self.outer_gutter(outer_padding)
    if note_line_index == 0 {
      self.writer.set_color(blue_style())
      self.write("=")
      self.writer.reset()
    } else {
      self.write(" ")
    }
    self.write(" \{line}")
    self.writeln()
  }
}

///|
/// Rust's `str::lines`: split at `\n` (removing a preceding `\r`), without
/// a final empty line.
fn rust_lines(s : String) -> Array[String] {
  let out = []
  let mut start = 0
  for i in 0..<s.length() {
    if s.code_unit_at(i) == '\n' {
      let mut end = i
      if end > start && s.code_unit_at(end - 1) == '\r' {
        end -= 1
      }
      out.push(s.unsafe_substring(start~, end~))
      start = i + 1
    }
  }
  if start < s.length() {
    let mut end = s.length()
    if end > start && s.code_unit_at(end - 1) == '\r' {
      end -= 1
    }
    out.push(s.unsafe_substring(start~, end~))
  }
  out
}

///|
/// Location focus.
fn Renderer::snippet_locus(
  self : Renderer,
  name : String,
  location : Location,
) -> Unit {
  self.write("\{name}:\{location.line_number}:\{location.column_number}")
}

///|
/// The outer gutter of a source line.
fn Renderer::outer_gutter(self : Renderer, outer_padding : Int32) -> Unit {
  self.write(" ".repeat(outer_padding))
  self.write(" ")
}

///|
/// The outer gutter of a source line, with line number.
fn Renderer::outer_gutter_number(
  self : Renderer,
  line_number : Int32,
  outer_padding : Int32,
) -> Unit {
  self.writer.set_color(blue_style())
  let number = line_number.to_string()
  if number.length() < outer_padding {
    self.write(" ".repeat(outer_padding - number.length()))
  }
  self.write(number)
  self.writer.reset()
  self.write(" ")
}

///|
/// The left-hand border of a source line.
fn Renderer::border_left(self : Renderer) -> Unit {
  self.writer.set_color(blue_style())
  self.write("│")
  self.writer.reset()
}

///|
/// The broken left-hand border of a source line.
fn Renderer::border_left_break(self : Renderer) -> Unit {
  self.writer.set_color(blue_style())
  self.write("·")
  self.writer.reset()
}

///|
/// Write vertical lines pointing to carets.
fn Renderer::caret_pointers(
  self : Renderer,
  severity : Severity,
  max_label_start : Int32,
  single_labels : Array[SingleLabel],
  trailing_label : Int32?,
  chars : Array[(Int32, Char)],
) -> Unit {
  let hanging = hanging_labels(single_labels, trailing_label)
  for entry in self.char_metrics(chars) {
    let (metrics, ch) = entry
    let col_start = metrics.byte_index
    let col_end = metrics.byte_index + utf8_char_len(ch)
    let style = max_style(
      hanging
      .filter(l => l.start >= col_start && l.start < col_end)
      .map(l => l.style),
    )
    let mut spaces = match style {
      None => metrics.unicode_width
      Some(style) => {
        self.writer.set_color(label_style(severity, style))
        self.write("│")
        self.writer.reset()
        metrics.unicode_width - 1
      }
    }
    // Only print padding if we are before the end of the last single line
    // caret
    if metrics.byte_index <= max_label_start {
      while spaces > 0 {
        self.write(" ")
        spaces -= 1
      }
    }
  }
}

///|
/// The left of a multi-line label.
fn Renderer::label_multi_left(
  self : Renderer,
  severity : Severity,
  style : LabelStyle,
  underline : LabelStyle?,
) -> Unit {
  match underline {
    None => self.write(" ")
    // Continue an underline horizontally
    Some(ul) => {
      self.writer.set_color(label_style(severity, ul))
      self.write("─")
      self.writer.reset()
    }
  }
  self.writer.set_color(label_style(severity, style))
  self.write("│")
  self.writer.reset()
}

///|
/// The top-left of a multi-line label.
fn Renderer::label_multi_top_left(
  self : Renderer,
  severity : Severity,
  style : LabelStyle,
) -> Unit {
  self.write(" ")
  self.writer.set_color(label_style(severity, style))
  self.write("╭")
  self.writer.reset()
}

///|
/// The bottom left of a multi-line label.
fn Renderer::label_multi_bottom_left(
  self : Renderer,
  severity : Severity,
  style : LabelStyle,
) -> Unit {
  self.write(" ")
  self.writer.set_color(label_style(severity, style))
  self.write("╰")
  self.writer.reset()
}

///|
/// Multi-line label top.
fn Renderer::label_multi_top_caret(
  self : Renderer,
  severity : Severity,
  style : LabelStyle,
  chars : Array[(Int32, Char)],
  start : Int32,
) -> Unit {
  self.writer.set_color(label_style(severity, style))
  for entry in self.char_metrics(chars) {
    let (metrics, _) = entry
    if metrics.byte_index >= start + 1 {
      break
    }
    // FIXME: improve rendering of carets between character boundaries
    for _ in 0..<metrics.unicode_width {
      self.write("─")
    }
  }
  let caret_start = match style {
    Primary => '^'
    Secondary => '\''
  }
  self.write_char(caret_start)
  self.writer.reset()
  self.writeln()
}

///|
/// Multi-line label bottom, with a message.
fn Renderer::label_multi_bottom_caret(
  self : Renderer,
  severity : Severity,
  style : LabelStyle,
  chars : Array[(Int32, Char)],
  start : Int32,
  message : String,
) -> Unit {
  self.writer.set_color(label_style(severity, style))
  for entry in self.char_metrics(chars) {
    let (metrics, _) = entry
    if metrics.byte_index >= start {
      break
    }
    // FIXME: improve rendering of carets between character boundaries
    for _ in 0..<metrics.unicode_width {
      self.write("─")
    }
  }
  let caret_end = match style {
    Primary => '^'
    Secondary => '\''
  }
  self.write_char(caret_end)
  if message != "" {
    self.write(" \{message}")
  }
  self.writer.reset()
  self.writeln()
}

///|
/// Writes an empty gutter space, or continues an underline horizontally.
fn Renderer::inner_gutter_column(
  self : Renderer,
  severity : Severity,
  underline : (LabelStyle, Bool)?,
) -> Unit {
  match underline {
    None => self.inner_gutter_space()
    Some((style, _top)) => {
      self.writer.set_color(label_style(severity, style))
      self.write("──")
      self.writer.reset()
    }
  }
}

///|
/// Writes an empty gutter space.
fn Renderer::inner_gutter_space(self : Renderer) -> Unit {
  self.write("  ")
}

///|
/// Writes an inner gutter, with the left lines if necessary.
fn Renderer::inner_gutter(
  self : Renderer,
  severity : Severity,
  num_multi_labels : Int32,
  multi_labels : Array[MultiLabelEntry],
) -> Unit {
  let mut iter = 0
  for label_column in 0..<num_multi_labels {
    if iter < multi_labels.length() && multi_labels[iter].index == label_column {
      let entry = multi_labels[iter]
      match entry.label {
        Left | Bottom(_, _) =>
          self.label_multi_left(severity, entry.style, None)
        Top(_) => self.inner_gutter_space()
      }
      iter += 1
    } else {
      self.inner_gutter_space()
    }
  }
}
