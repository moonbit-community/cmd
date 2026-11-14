///|
pub(all) suberror CompileError {
  Undefined(String, String, Int32, String)
}

///|
pub fn Env::validate(self : Env, expr : Expr) -> Unit raise CompileError {
  validate_expr(expr, self, 0)
}

///|
fn validate_expr(
  expr : Expr,
  scope : Env,
  position : Int32,
) -> Unit raise CompileError {
  match expr {
    At(inner, offset) => validate_expr(inner, scope, offset)
    Variable(name) =>
      if scope.get(name) is None {
        raise Undefined(
          "$\{name} is not defined",
          "$" + name,
          position,
          scope.source,
        )
      }
    Pipe(FunctionDef(name, params, body), rest) =>
      validate_expr(rest, scope.set_function(name, body, params), position)
    FunctionDef(_, _, _) => ()
    As(source, name, body) => {
      validate_expr(source, scope, position)
      validate_expr(body, scope.set(name, null), position)
    }
    Reduce(source, name, initial, update) => {
      validate_expr(source, scope, position)
      validate_expr(initial, scope, position)
      validate_expr(update, scope.set(name, null), position)
    }
    Foreach(source, name, initial, update, extract) => {
      validate_expr(source, scope, position)
      validate_expr(initial, scope, position)
      let inner = scope.set(name, null)
      validate_expr(update, inner, position)
      if extract is Some(expr) {
        validate_expr(expr, inner, position)
      }
    }
    BuiltinCall(name, args, body) =>
      if scope.has_function(name, args.length()) {
        validate_call(name, args, scope, position)
      } else {
        validate_expr(body, scope, position)
      }
    FunctionCall(name, args) => validate_call(name, args, scope, position)
    _ =>
      for child in expr.children() {
        validate_expr(child, scope, position)
      }
  }
}

///|
fn validate_call(
  name : String,
  args : Array[Expr],
  scope : Env,
  position : Int32,
) -> Unit raise CompileError {
  for arg in args {
    validate_expr(arg, scope, position)
  }
  if args.is_empty() && scope.filters.get(name) is Some((body, caller)) {
    validate_expr(body, caller, position)
    return
  }
  if scope.functions.get(function_key(name, args.length())) is Some(closure) {
    if closure.checking.val {
      return
    }
    closure.checking.val = true
    defer {
      closure.checking.val = false
    }
    let mut inner = closure.scope.with_closure(closure.name, closure)
    for i, parameter in closure.params {
      if parameter.has_prefix("$") {
        inner = inner.set(parameter[1:].to_owned(), null)
      } else {
        inner = inner.with_filter(parameter, args[i], scope)
      }
    }
    validate_expr(closure.body, inner, position)
    return
  }
  if args.is_empty() &&
    [
      "input", "inputs", "input_filename", "input_line_number", "modulemeta", "error",
    ].contains(name) {
    return
  }
  if name == "error" && args.length() == 1 {
    return
  }
  raise Undefined(
    "\{name}/\{args.length()} is not defined",
    name,
    position,
    scope.source,
  )
}

///|
fn Expr::children(self : Expr) -> Array[Expr] {
  match self {
    Pipe(a, b) | Comma(a, b) | Operation(a, _, b) | IfThenElse(a, b, _) =>
      match self {
        IfThenElse(_, _, c) => [a, b, c]
        _ => [a, b]
      }
    ObjectConstruct(pairs) =>
      pairs
      .iter()
      .flat_map(pair => {
        [
          pair.0,
          ..match pair.1 {
            Some(value) => [value]
            None => []
          },
        ].iter()
      })
      .collect()
    StringInterpolation(parts) => parts.filter_map(part => part.1)
    ArrayConstruct(inner) =>
      match inner {
        Some(inner) => [inner]
        None => []
      }
    TryCatch(a, b) =>
      [
        a,
        ..match b {
          Some(b) => [b]
          None => []
        },
      ]
    Optional(a)
    | Map(a)
    | Select(a)
    | SortBy(a)
    | UniqueBy(a)
    | GroupBy(a)
    | MinBy(a)
    | MaxBy(a)
    | Contains(a)
    | Inside(a)
    | In(a)
    | WithEntries(a)
    | MapValues(a)
    | FirstGen(a)
    | LastGen(a)
    | Repeat(a)
    | IndicesOf(a)
    | IndexOf(a)
    | Walk(a)
    | Path(a)
    | RIndex(a)
    | PathsWithFilter(a)
    | GetPath(a)
    | DelPaths(a)
    | Limit(_, a)
    | Pow(a) => [a]
    RangeFromTo(a, b)
    | AnyGen(a, b)
    | AllGen(a, b)
    | RecurseWith(a, b)
    | Update(a, b)
    | Assign(a, b)
    | Alternative(a, b)
    | AddAssign(a, b)
    | SubAssign(a, b)
    | MulAssign(a, b)
    | DivAssign(a, b)
    | ModAssign(a, b)
    | AltAssign(a, b)
    | SetPath(a, b)
    | Until(a, b)
    | While(a, b) => [a, b]
    RangeWithStep(a, b, c) => [a, b, c]
    _ => []
  }
}
