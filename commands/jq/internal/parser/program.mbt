///|
pub(all) struct Dependency {
  path : String
  binding : String?
  data : Bool
  metadata : Json
}

///|
pub(all) struct Program {
  metadata : Json
  dependencies : Array[Dependency]
  body : @ast.Expr
}

///|
pub fn parse_program(source : String, library~ : Bool = false) -> Program raise {
  let (tokens, positions, interpolations) = lex_positions(source)
  let parser = Parser::new(tokens)
  parser.positions = positions
  parser.interpolations = interpolations
  let mut metadata : Json = Json::object(Map([]))
  if parser.current() == Some(TIdentifier("module")) {
    parser.advance()
    metadata = parser.parse_metadata()
    parser.expect(TSemicolon)
  }
  let dependencies : Array[Dependency] = []
  while parser.current() is Some(TIdentifier("import" | "include" as keyword)) {
    parser.advance()
    guard parser.current() is Some(TString(path)) else {
      raise InvalidSyntax("Expected a module path string")
    }
    parser.advance()
    let mut data = false
    let binding = if keyword == "import" {
      parser.expect(TAs)
      let name = match parser.current() {
        Some(TIdentifier(name)) => name
        Some(TVariable(name)) => {
          data = true
          name
        }
        _ => raise InvalidSyntax("Expected an import binding")
      }
      parser.advance()
      Some(name)
    } else {
      None
    }
    let metadata = if parser.current() == Some(TLBrace) {
      parser.parse_metadata()
    } else {
      Json::object(Map([]))
    }
    parser.expect(TSemicolon)
    dependencies.push({ path, binding, data, metadata, })
  }
  let definitions : Array[@ast.Expr] = []
  while parser.current() == Some(TDef) {
    definitions.push(parser.parse_function_def())
  }
  let body = if library {
    guard parser.current() == Some(TEof) else {
      raise InvalidSyntax("A module may contain only imports and definitions")
    }
    @ast.Expr::Identity
  } else {
    parser.parse_pipe()
  }
  parser.expect(TEof)
  {
    metadata,
    dependencies,
    body: definitions
    .rev()
    .fold(init=body, (body, definition) => @ast.Expr::Pipe(definition, body)),
  }
}

///|
fn Parser::parse_metadata(self : Parser) -> Json raise ParseError {
  let expr = self.parse_primary()
  guard constant_metadata(expr) else {
    raise InvalidSyntax("Module metadata must be constant")
  }
  let values = @ast.eval(expr, null).collect() catch {
    _ => raise InvalidSyntax("Module metadata must be a constant object")
  }
  guard values is [Object(_) as value] else {
    raise InvalidSyntax("Module metadata must be an object")
  }
  value
}

///|
// Admit only finite constant-folding syntax before invoking the evaluator.
fn constant_metadata(expr : @ast.Expr, array_items~ : Bool = false) -> Bool {
  match expr {
    At(inner, _) => constant_metadata(inner, array_items~)
    Literal(Number(number)) => number >= 0 && (number != 0 || 1.0 / number > 0)
    Literal(_) => true
    ArrayConstruct(None) => true
    ArrayConstruct(Some(items)) => constant_metadata(items, array_items=true)
    Comma(left, right) =>
      array_items &&
      constant_metadata(left, array_items=true) &&
      constant_metadata(right, array_items=true)
    ObjectConstruct(fields) =>
      fields.all(pair => {
        constant_metadata(pair.0) &&
        pair.1 is Some(value) &&
        constant_metadata(value)
      })
    Operation(left, operator, right) =>
      !(operator is (And | Or)) &&
      constant_metadata(left) &&
      constant_metadata(right)
    _ => false
  }
}
