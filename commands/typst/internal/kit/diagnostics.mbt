// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// Diagnostic pretty-printing (upstream `typst_kit::diagnostics`).

///|
/// Extends the `World` for diagnostic printing.
pub(open) trait DiagnosticWorld: @library.World {
  /// Formats a file ID for user-facing display.
  ///
  /// In the CLI, this formats as a path relative to the working directory.
  fn name(Self, @syntax.FileId) -> String
}

///|
/// Which format to use for diagnostics.
#derive(Eq, Debug)
pub(all) enum DiagnosticFormat {
  /// Displays a richly formatted message showing the source code and
  /// context.
  Human
  /// Displays a short single-line diagnostic.
  Short
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagnosticFormat with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend DiagnosticFormat with @debug.Debug::{to_repr}

///|
/// Emits diagnostic messages to a writable, colorized output.
pub fn emit_diagnostics(
  dest : ColorWriter,
  world : &DiagnosticWorld,
  diagnostics : Array[@library.SourceDiagnostic],
  format : DiagnosticFormat,
) -> Unit raise FilesError {
  let files : WorldFiles = { world, sources: {}, }
  let config = {
    ..Config::default(),
    tab_width: 2,
    display_style: if format == Short {
      Short
    } else {
      Rich
    },
  }
  for diagnostic in diagnostics {
    let severity : Severity = match diagnostic.severity {
      Error => Error
      Warning => Warning
    }
    let notes = diagnostic.hints
      .filter(s => s.span.is_detached())
      .map(s => "hint: \{s.v}")
    let labels = []
    if diagnostic.span.id() is Some(id) &&
      files.range(diagnostic.span) is Some((start, end)) {
      labels.push(Label::primary(id, start, end))
    }
    for hint in diagnostic.hints {
      guard hint.span.id() is Some(id) else { continue }
      guard files.range(hint.span) is Some((start, end)) else { continue }
      labels.push(Label::secondary(id, start, end).with_message(hint.v))
    }
    let diag : Diagnostic = {
      severity,
      message: diagnostic.message,
      labels,
      notes,
    }
    emit(dest, config, files, diag)

    // Stacktrace-like helper diagnostics.
    if format == Human {
      let mut traced = false
      for point in diagnostic.trace {
        emit_trace(dest, files, point)
        traced = true
      }
      if traced {
        dest.write_char('\n')
      }
    }
  }
}

///|
/// Emits a tracepoint.
fn emit_trace(
  dest : ColorWriter,
  files : WorldFiles,
  point : @syntax.Spanned[@library.Tracepoint],
) -> Unit raise FilesError {
  let span = @syntax.DiagSpan::from_span(point.span)
  guard span.id() is Some(id) else { return }
  guard files.range(span) is Some((start, end)) else { return }
  let lines = Files::lines(files, id)
  let name = Files::name(files, id)
  let line_index = Files::line_index(files, id, start)
  let line = Files::line_number(files, id, line_index)
  let column = Files::column_number(files, id, line_index, start)
  let text = slice_bytes(lines, lines.text(), start, end)

  // Displays what kind of tracepoint we have and where.
  dest.write("  \{point.v} at ")
  dest.set_color(ColorSpec::new().with_underline())
  dest.write("\{name}:\{line}:\{column}")
  dest.reset()
  dest.write_char('\n')

  // Displays the context in the source in a single line.
  let text_lines = rust_lines(text)
  dest.write("    ")
  dest.set_color(ColorSpec::new().with_fg(Ansi256(248)))
  if text_lines.length() > 0 {
    dest.write(text_lines[0])
  }
  if text_lines.length() > 1 {
    let last = text_lines[text_lines.length() - 1]
    let mut last_char : Char? = None
    for c in last {
      last_char = Some(c)
    }
    if last_char is Some(c) && !@unicode.is_whitespace(c) {
      // If the traced source text is multi-line, try to display it with
      // inner ellipses followed by the last character.
      dest.write("…")
      dest.write_char(c)
    }
  }
  dest.reset()
  dest.write_char('\n')
}

///|
/// Provides file contents and metadata to the renderer.
priv struct WorldFiles {
  world : &DiagnosticWorld
  sources : Map[@syntax.FileId, @syntax.Source]
}

///|
/// Determine the byte range of a span, also remembering the source file
/// for future line / column lookups.
fn WorldFiles::range(
  self : WorldFiles,
  span : @syntax.DiagSpan,
) -> (Int32, Int32)? {
  match span.get() {
    Detached => None
    Number(id~, num~, sub_range~) => {
      let source = @library.World::source(self.world, id) catch {
        _ => return None
      }
      let range = source.range(num, sub_range)
      if !self.sources.contains(id) {
        self.sources[id] = source
      }
      range
    }
    Range(start~, end~, ..) => Some((start, end))
  }
}

///|
/// Lookup line metadata for a file by id. If a source file was remembered,
/// it will be used. Otherwise, we load as a file as compute line metadata.
fn WorldFiles::get_lines(
  self : WorldFiles,
  id : @syntax.FileId,
) -> @syntax.Lines raise FilesError {
  match self.sources.get(id) {
    Some(source) => source.lines()
    None => {
      let file = @library.World::file(self.world, id) catch {
        @library.FileError::NotFound(_) => raise FileMissing
        other => raise Io(other.to_string())
      }
      let text = @utf8.decode(file) catch {
        _ => raise Io(@library.FileError::InvalidUtf8.to_string())
      }
      @syntax.Lines::new(text)
    }
  }
}

///|
impl Files for WorldFiles with fn name(self, id) {
  self.world.name(id)
}

///|
impl Files for WorldFiles with fn lines(self, id) {
  self.get_lines(id)
}

///|
impl Files for WorldFiles with fn line_index(self, id, given) {
  let lines = self.get_lines(id)
  match lines.byte_to_line(given) {
    Some(index) => index
    None => raise IndexTooLarge(given, lines.len_bytes())
  }
}

///|
impl Files for WorldFiles with fn line_range(self, id, given) {
  let lines = self.get_lines(id)
  match lines.line_to_range(given) {
    Some(range) => range
    None => raise LineTooLarge(given, lines.len_lines())
  }
}

///|
impl Files for WorldFiles with fn column_number(self, id, _, given) {
  let lines = self.get_lines(id)
  match lines.byte_to_column(given) {
    Some(column) => column
    None => {
      let max = lines.len_bytes()
      if given <= max {
        raise InvalidCharBoundary(given)
      } else {
        raise IndexTooLarge(given, max)
      }
    }
  }
}
