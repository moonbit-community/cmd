///|
/// A world with a single source file, for rendering diagnostics.
struct DiagWorld {
  source : @syntax.Source
}

///|
impl @library.World for DiagWorld with fn library(_) {
  panic()
}

///|
impl @library.World for DiagWorld with fn main(self) {
  self.source.id()
}

///|
impl @library.World for DiagWorld with fn source(self, id) {
  if id == self.source.id() {
    self.source
  } else {
    raise @library.FileError::NotFound(id.vpath().get_without_slash())
  }
}

///|
impl @library.World for DiagWorld with fn file(self, id) {
  @utf8.encode(@library.World::source(self, id).text())
}

///|
impl @library.World for DiagWorld with fn today(_, _) {
  None
}

///|
impl @kit.DiagnosticWorld for DiagWorld with fn name(_, id) {
  id.vpath().get_without_slash()
}

///|
fn render(
  text : String,
  diags : Array[@library.SourceDiagnostic],
  format : @kit.DiagnosticFormat,
) -> String {
  let world : DiagWorld = { source: @syntax.Source::new(id("test.typ"), text), }
  let out = @kit.ColorWriter::new(false)
  @kit.emit_diagnostics(out, world, diags, format) catch {
    e => return e.to_string()
  }
  out.contents()
}

///|
test "diagnostics: single-line error with hints" {
  let file = id("test.typ")
  let diag = @library.SourceDiagnostic::error(
    @syntax.DiagSpan::from_range(file, 5, 8),
    "unknown variable: abc",
  )
  diag.hint("if you meant to display multiple letters as is, try adding spaces")
  diag.spanned_hint("defined here", @syntax.DiagSpan::from_range(file, 1, 4))
  inspect(
    render("#let abc =\t1\n", [diag], Human),
    content=(
      #|error: unknown variable: abc
      #|  ┌─ test.typ:1:5
      #|  │
      #|1 │ #let abc =  1
      #|  │  --- ^^^
      #|  │  │    
      #|  │  defined here
      #|  │
      #|  = hint: if you meant to display multiple letters as is, try adding spaces
      #|
      #|
    ),
  )
  inspect(
    render("#let abc =\t1\n", [diag], Short),
    content=(
      #|test.typ:1:5: error: unknown variable: abc
      #|
    ),
  )
}

///|
test "diagnostics: multi-line label and detached warning" {
  let file = id("test.typ")
  let err = @library.SourceDiagnostic::error(
    @syntax.DiagSpan::from_range(file, 1, 22),
    "expected content",
  )
  let warn = @library.SourceDiagnostic::warning(
    @syntax.DiagSpan::detached(),
    "something is off",
  )
  inspect(
    render("#table(\n  columns: 2,\n)\n", [err, warn], Human),
    content=(
      #|error: expected content
      #|  ┌─ test.typ:1:1
      #|  │  
      #|1 │   #table(
      #|  │ ╭──^
      #|2 │ │   columns: 2,
      #|3 │ │ )
      #|  │ ╰^
      #|
      #|warning: something is off
      #|
      #|
    ),
  )
}
