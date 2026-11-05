// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `eval` command (upstream `typst-cli/src/eval.rs`).

///|
/// Evaluate an input expression, potentially as a query over an existing
/// document.
async fn eval(command : EvalCommand) -> Unit {
  let world = SystemWorld::new(command.in_, command.world, command.process) catch {
    err => raise bail("\{err}")
  }

  // Reset everything and ensure that the main file is present.
  world.reset()
  (@library.World::source(world, @library.World::main(world)) |> ignore) catch {
    err => raise bail("\{err}")
  }

  // Compile the main file and get the introspector.
  let warned = compile_target(world, command.target)
  let warnings = warned.warnings.copy()
  match warned.output {
    // The target compiled successfully, continue with evaluating the input
    // expression.
    Ok(output) => {
      let expr_world : ExpressionWorld = {
        world,
        expression: @utf8.encode(command.expression),
      }
      let sink = @library.Sink::new()
      let eval_result = try
        evaluate_expression(
          command.expression,
          sink,
          expr_world,
          output.introspector,
        )
      catch {
        @library.SourceError(errors) => Err(errors)
      } noraise {
        value => Ok(value)
      }
      let errors = match eval_result {
        Err(errors) => {
          set_failed()
          errors
        }
        Ok(value) => {
          print_eval_result(value, command.format, command.pretty)
          []
        }
      }
      // Collect additional warnings from evaluating the expression.
      warnings.append(sink.warnings)
      print_diagnostics(
        expr_world,
        errors,
        warnings,
        command.process.diagnostic_format,
      ) catch {
        err => raise bail("failed to print diagnostics (\{err})")
      }
    }

    // The target failed, print its diagnostics.
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
/// Evaluate the input expression in code mode and with no scope.
fn evaluate_expression(
  expression : String,
  sink : @library.Sink,
  world : ExpressionWorld,
  introspector : @library.Introspector,
) -> @library.Value raise @library.SourceError {
  // Map spans to ranges in the string.
  let library = @library.World::library(world)
  let engine : @library.Engine = {
    world: @library.TrackedWorld::new(world),
    library,
    introspector,
    traced: @library.Traced::new(),
    sink,
    route: @library.Route::root(),
  }
  @eval.eval_string_mapped(
    engine,
    @library.Context::new(styles=@library.StyleChain::new(library.styles)),
    expression,
    expression_id,
    Code,
    @library.Scope::new(),
  )
}

///|
/// Prints the output value of `typst eval`.
async fn print_eval_result(
  value : @library.Value,
  format : EvalSerializationFormat,
  pretty : Bool,
) -> Unit {
  match format {
    Json => print_out(serialize(value, Json, pretty) + "\n")
    Yaml => print_out(serialize(value, Yaml, pretty) + "\n")
    Raw => {
      let bytes = match value {
        Str(string) => @utf8.encode(string)
        Bytes(bytes) => bytes.as_slice()
        _ =>
          raise HintedFailure(
            @library.HintedString::new(
              "cannot print \{value.ty()} in raw format",
            ).with_hint("`--format=raw` only supports strings and bytes"),
          )
      }
      write_raw_stdout(bytes) catch {
        err =>
          raise bail(
            "failed to write eval output: \{@platform.rust_debug(err)}",
          )
      }
    }
  }
}

///|
/// Static [`FileId`] for an input expression. This allows giving accurate
/// ranges to diagnostics when evaluating the expression.
let expression_id : @syntax.FileId = @syntax.FileId::unique(
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new("<input-expression>") catch {
      _ => panic()
    },
  ),
)

///|
/// A world wrapper that allows us to print accurate diagnostics for an
/// input expression.
priv struct ExpressionWorld {
  world : SystemWorld
  expression : Bytes
}

///|
impl @kit.DiagnosticWorld for ExpressionWorld with fn name(self, id) {
  if id == expression_id {
    "<input-expression>"
  } else {
    @kit.DiagnosticWorld::name(self.world, id)
  }
}

///|
impl @library.World for ExpressionWorld with fn library(self) {
  @library.World::library(self.world)
}

///|
impl @library.World for ExpressionWorld with fn book(self) {
  @library.World::book(self.world)
}

///|
impl @library.World for ExpressionWorld with fn main(self) {
  @library.World::main(self.world)
}

///|
impl @library.World for ExpressionWorld with fn source(self, id) {
  @library.World::source(self.world, id)
}

///|
impl @library.World for ExpressionWorld with fn file(self, id) {
  if id == expression_id {
    self.expression
  } else {
    @library.World::file(self.world, id)
  }
}

///|
impl @library.World for ExpressionWorld with fn font(self, index) {
  @library.World::font(self.world, index)
}

///|
impl @library.World for ExpressionWorld with fn today(self, offset) {
  @library.World::today(self.world, offset)
}

///|
/// Writes bytes like `stdout().lock().write_all(..)` on Rust's line-buffered
/// stdout (`LineWriter` with a 1024-byte buffer): everything up to the last
/// newline is written and flushed, a shorter remainder stays buffered (it is
/// flushed at exit, ignoring errors), a remainder that does not fit into the
/// buffer is written directly.
async fn write_raw_stdout(bytes : Bytes) -> Unit raise @platform.IoError {
  let mut last_newline = -1
  for i in 0..<bytes.length() {
    if bytes[i] == b'\n' {
      last_newline = i
    }
  }
  let head = bytes[:last_newline + 1].to_owned()
  let tail = bytes[last_newline + 1:].to_owned()
  if head.length() > 0 {
    @platform.write_stdout(head)
  }
  if tail.length() >= 1024 {
    @platform.write_stdout(tail)
  } else if tail.length() > 0 {
    @platform.write_stdout_buffered(tail)
  }
}
