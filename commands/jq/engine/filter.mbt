///|
/// A compiled value filter. Parsing and evaluation state stay private to jq.
pub struct Filter {
  priv expression : @ast.Expr
}

///|
/// Compile a filter for supplied JSON values. Module loading is a jq CLI effect
/// and is unavailable through this interface. Lexical references are checked
/// before any input is evaluated.
///
/// ```mbt check
/// test {
///   let filter = @engine.compile("def twice(x): x + x; twice(.n)")
///   assert_eq(filter.apply({ "n": 3 }), [6])
/// }
/// ```
pub fn compile(source : String) -> Filter raise {
  let program = @parser.parse_program(source)
  guard program.dependencies.is_empty() else {
    raise @ast.EvalError(
      "Module loading is unavailable for a supplied JSON value",
    )
  }
  let expression = @filter.lower(program.body)
  @ast.Env::new().validate(expression)
  { expression, }
}

///|
/// Evaluate one value in a fresh scope. Results are returned only after the
/// complete evaluation succeeds, so a failed log record cannot emit a prefix.
/// Input and module requests fail explicitly; this API never performs I/O.
pub fn Filter::apply(self : Filter, input : Json) -> Array[Json] raise {
  let values : Array[Json] = []
  for stream = @ast.evaluate(self.expression, input, @ast.Env::new()) {
    match stream.step() {
      Done => break values
      Yield(value, next) => {
        values.push(value)
        continue next
      }
      Request(request, advance) => {
        let name = match request {
          Input => "input/inputs"
          InputFilename => "input_filename"
          InputLineNumber => "input_line_number"
          ModuleMetadata(_) => "modulemeta"
        }
        continue advance(
            Err(
              @ast.EvalError("\{name} is unavailable for a supplied JSON value"),
            ),
          )
      }
      Failed(error) => raise error
      Continue(_) => abort("step must resolve continuations")
    }
  }
}
