///|
priv struct JsonInput {
  parser : StreamInput
}

///|
fn JsonInput::new(reader : &@io.Reader) -> JsonInput {
  { parser: StreamInput::new(reader), }
}

///|
async fn JsonInput::next(self : JsonInput) -> Json? {
  self.parser.next_json()
}

///|
fn compile_query(
  query : String,
  arguments : Map[String, String],
) -> @ast.Expr raise {
  let mut expr = parse_filter(query)
  for name, value in arguments {
    expr = @ast.Expr::As(@parser.parse(value), name, expr)
  }
  expr
}

///|
/// Compile a jq filter through command-owned AST adaptations for string
/// slicing and stable grouping of complete key streams.
fn parse_filter(source : String) -> @ast.Expr raise {
  lower(@parser.parse(source))
}

///|
async fn StreamInput::read(
  self : StreamInput,
  emit : async (Json) -> Unit,
  errors~ : Bool = false,
) -> Unit {
  while self.next_event(errors~) is Some(value) {
    emit(value)
  }
}
