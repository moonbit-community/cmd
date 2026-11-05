// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `query` command (upstream `typst-cli/src/query.rs`).

///|
/// A compiled document of any target (upstream `Box<dyn Output>`).
priv struct AnyOutput {
  introspector : @library.Introspector
}

///|
/// Compiles the main file for a target.
fn compile_target(
  world : &@library.World,
  target : Target,
) -> @library.Warned[Result[AnyOutput, Array[@library.SourceDiagnostic]]] {
  match target {
    Paged => {
      let w : @library.Warned[
        Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      {
        output: w.output.map(d => { introspector: d.introspector(), }),
        warnings: w.warnings,
      }
    }
    Html => {
      let w : @library.Warned[
        Result[@html.HtmlDocument, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      {
        output: w.output.map(d => {
          introspector: @library.Output::introspector(d),
        }),
        warnings: w.warnings,
      }
    }
    Bundle => {
      let w : @library.Warned[
        Result[@bundle.Bundle, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      {
        output: w.output.map(d => {
          introspector: @library.Output::introspector(d),
        }),
        warnings: w.warnings,
      }
    }
  }
}

///|
/// Execute a query command.
async fn query(command : QueryCommand) -> Unit {
  let world = SystemWorld::new(
    Some(command.input),
    command.world,
    command.process,
  ) catch {
    err => raise bail("\{err}")
  }

  // Reset everything and ensure that the main file is present.
  world.reset()
  (@library.World::source(world, @library.World::main(world)) |> ignore) catch {
    err => raise bail("\{err}")
  }
  let warned = compile_target(world, command.target)
  let warnings = warned.warnings.copy()

  // Add deprecation warning.
  warnings.push(deprecation_warning(command))
  match warned.output {
    // Retrieve and print query results.
    Ok(output) => {
      let data = retrieve(world, command, output.introspector)
      let serialized = format_query(data, command)
      print_out(serialized + "\n")
      print_diagnostics(world, [], warnings, command.process.diagnostic_format) catch {
        err => raise bail("failed to print diagnostics (\{err})")
      }
    }

    // Print diagnostics.
    Err(errors) => {
      set_failed()
      print_diagnostics(
        world,
        errors,
        warnings,
        command.process.diagnostic_format,
      ) catch {
        err => raise bail("failed to print diagnostics (\{err})")
      }
    }
  }
}

///|
/// Retrieve the matches for the selector.
fn retrieve(
  world : SystemWorld,
  command : QueryCommand,
  introspector : @library.Introspector,
) -> Array[@library.Content] raise HintedFailure {
  let library = @library.World::library(world)
  let engine : @library.Engine = {
    world: @library.TrackedWorld::new(world),
    library,
    introspector: @library.Introspector::empty(),
    traced: @library.Traced::new(),
    // TODO: propagate warnings
    sink: @library.Sink::new(),
    route: @library.Route::root(),
  }
  let value = @eval.eval_string(
    engine,
    @library.Context::none(),
    command.selector,
    @syntax.Span::detached(),
    Code,
    @library.Scope::new(),
  ) catch {
    @library.SourceError(errors) => {
      let message = StringBuilder()
      message.write_string("failed to evaluate selector")
      for i, error in errors {
        message.write_string(if i == 0 { ": " } else { ", " })
        message.write_string(error.message)
      }
      raise bail(message.to_string())
    }
  }
  let selector : @library.LocatableSelector = @library.FromValue::from_value(
    value,
  ) catch {
    @library.HintedError(err) => raise HintedFailure(err)
  }
  introspector.query(selector.0).to_owned()
}

///|
/// Format the query result in the output format.
fn format_query(
  elements : Array[@library.Content],
  command : QueryCommand,
) -> String raise HintedFailure {
  if command.one && elements.length() != 1 {
    raise bail("expected exactly one element, found \{elements.length()}")
  }
  let mapped : Array[@library.Value] = []
  for c in elements {
    match command.field {
      Some(field) =>
        try c.get_by_name(field) catch {
          _ => ()
        } noraise {
          value => mapped.push(value)
        }
      None => mapped.push(Content(c))
    }
  }
  if command.one {
    guard mapped.length() > 0 else {
      raise bail("no such field found for element")
    }
    serialize(mapped[0], command.format, command.pretty)
  } else {
    serialize(
      Array(@library.Arr::from_array(mapped)),
      command.format,
      command.pretty,
    )
  }
}

///|
/// Serialize data to the output format and convert the error to a string
/// (upstream `crate::serialize`).
fn serialize(
  data : @library.Value,
  format : SerializationFormat,
  pretty : Bool,
) -> String raise HintedFailure {
  match format {
    Json => @tjson.to_string(data.to_serde(true), pretty~)
    Yaml =>
      @yaml.to_string(data.to_serde(true)) catch {
        @yaml.YamlError(message~, ..) => raise bail(message)
      }
  }
}

///|
/// Rust's `shell_escape::escape` (Unix).
fn shell_escape(s : String) -> String {
  let allowed = (c : Char) => {
    (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c is ('-' | '_' | '=' | '/' | ',' | '.' | '+')
  }
  if s != "" && s.all(allowed) {
    return s
  }
  let es = StringBuilder()
  es.write_char('\'')
  for ch in s {
    match ch {
      '\'' | '!' => {
        es.write_string("'\\")
        es.write_char(ch)
        es.write_char('\'')
      }
      _ => es.write_char(ch)
    }
  }
  es.write_char('\'')
  es.to_string()
}

///|
/// Format the deprecation warning with the specific invocation of `typst
/// eval` needed to replace `typst query`.
fn deprecation_warning(command : QueryCommand) -> @library.SourceDiagnostic {
  let query = {
    let buf = StringBuilder()
    buf.write_string("query(\{command.selector})")
    let access = (field : String) => {
      if @syntax.is_ident(field) {
        ".\{field}"
      } else {
        ".at(\{@library.repr_str(field)})"
      }
    }
    match (command.one, command.field) {
      (false, None) => ()
      (false, Some(field)) => buf.write_string(".map(it => it\{access(field)})")
      (true, None) => buf.write_string(".first()")
      (true, Some(field)) => buf.write_string(".first()\{access(field)}")
    }
    shell_escape(buf.to_string())
  }
  let eval_command = match command.input {
    Path(path) => "typst eval \{query} --in \{path}"
    Stdin => "typst eval \{query}"
  }
  let diag = @library.SourceDiagnostic::warning(
    @syntax.DiagSpan::detached(),
    "the `typst query` subcommand is deprecated",
  )
  diag.hint("use `\{eval_command}` instead")
  diag
}
