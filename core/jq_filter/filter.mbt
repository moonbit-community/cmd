///|
/// Compile a jq filter with Unicode-scalar string slicing. moonjq 0.2.0
/// evaluates Slice only for arrays; lower string slices through its public AST.
pub fn parse(source : String) -> @ast.Expr raise {
  lower(@moonjq.parse(source).expr)
}

///|
fn lower(expr : @ast.Expr) -> @ast.Expr {
  match expr {
    Slice(start, end) => {
      let string_type : @ast.Expr = Operation(
        Type,
        Equal,
        Literal(String("string")),
      )
      let sequence_type : @ast.Expr = Operation(
        Operation(Type, Equal, Literal(String("array"))),
        Or,
        Operation(Type, Equal, Literal(String("null"))),
      )
      IfThenElse(
        string_type,
        Pipe(Explode, Pipe(Slice(start, end), Implode)),
        IfThenElse(sequence_type, expr, Explode),
      )
    }
    Pipe(a, b) => Pipe(lower(a), lower(b))
    Comma(a, b) => Comma(lower(a), lower(b))
    Optional(a) => Optional(lower(a))
    ArrayConstruct(a) => ArrayConstruct(a.map(lower))
    ObjectConstruct(fields) =>
      ObjectConstruct(fields.map(pair => (lower(pair.0), pair.1.map(lower))))
    Operation(a, op, b) => Operation(lower(a), op, lower(b))
    Map(a) => Map(lower(a))
    Select(a) => Select(lower(a))
    SortBy(a) => SortBy(lower(a))
    UniqueBy(a) => UniqueBy(lower(a))
    GroupBy(a) => GroupBy(lower(a))
    MinBy(a) => MinBy(lower(a))
    MaxBy(a) => MaxBy(lower(a))
    Contains(a) => Contains(lower(a))
    Inside(a) => Inside(lower(a))
    In(a) => In(lower(a))
    WithEntries(a) => WithEntries(lower(a))
    MapValues(a) => MapValues(lower(a))
    RangeFromTo(a, b) => RangeFromTo(lower(a), lower(b))
    RangeWithStep(a, b, c) => RangeWithStep(lower(a), lower(b), lower(c))
    FirstGen(a) => FirstGen(lower(a))
    LastGen(a) => LastGen(lower(a))
    Repeat(a) => Repeat(lower(a))
    IndicesOf(a) => IndicesOf(lower(a))
    IndexOf(a) => IndexOf(lower(a))
    AnyGen(a, b) => AnyGen(lower(a), lower(b))
    AllGen(a, b) => AllGen(lower(a), lower(b))
    IfThenElse(a, b, c) => IfThenElse(lower(a), lower(b), lower(c))
    TryCatch(a, b) => TryCatch(lower(a), b.map(lower))
    As(a, name, b) => As(lower(a), name, lower(b))
    Reduce(a, name, b, c) => Reduce(lower(a), name, lower(b), lower(c))
    Foreach(a, name, b, c, d) =>
      Foreach(lower(a), name, lower(b), lower(c), d.map(lower))
    RecurseWith(a, b) => RecurseWith(lower(a), lower(b))
    Walk(a) => Walk(lower(a))
    // Assignment/path operands describe locations, not value evaluation.
    Update(path, value) => Update(path, lower(value))
    Assign(path, value) => Assign(path, lower(value))
    AddAssign(path, value) => AddAssign(path, lower(value))
    SubAssign(path, value) => SubAssign(path, lower(value))
    MulAssign(path, value) => MulAssign(path, lower(value))
    DivAssign(path, value) => DivAssign(path, lower(value))
    ModAssign(path, value) => ModAssign(path, lower(value))
    AltAssign(path, value) => AltAssign(path, lower(value))
    Alternative(a, b) => Alternative(lower(a), lower(b))
    StringInterpolation(parts) =>
      StringInterpolation(parts.map(pair => (pair.0, pair.1.map(lower))))
    FunctionDef(name, parameters, body) =>
      FunctionDef(name, parameters, lower(body))
    FunctionCall(name, args) => FunctionCall(name, args.map(lower))
    RIndex(a) => RIndex(lower(a))
    PathsWithFilter(a) => PathsWithFilter(lower(a))
    GetPath(a) => GetPath(lower(a))
    SetPath(a, b) => SetPath(lower(a), lower(b))
    DelPaths(a) => DelPaths(lower(a))
    Limit(n, a) => Limit(n, lower(a))
    Until(a, b) => Until(lower(a), lower(b))
    While(a, b) => While(lower(a), lower(b))
    Pow(a) => Pow(lower(a))
    _ => expr
  }
}
