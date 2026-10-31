///|
// Capturing the complete key stream once and using the original array index
// as a final key makes equal-key member order independent of sort stability.
fn lower_sorting(key : @ast.Expr) -> @ast.Expr {
  let binding = "__cli_sort_keys"
  let decorated : @ast.Expr = Pipe(
    ToEntries,
    Map(
      As(
        Pipe(Key("value"), ArrayConstruct(Some(key))),
        binding,
        ObjectConstruct([
          (Literal(String("keys")), Some(Variable(binding))),
          (Literal(String("index")), Some(Key("key"))),
          (Literal(String("value")), Some(Key("value"))),
        ]),
      ),
    ),
  )
  let sorted : @ast.Expr = Pipe(
    decorated,
    Pipe(
      SortBy(ArrayConstruct(Some(Comma(Key("keys"), Key("index"))))),
      Map(Key("value")),
    ),
  )
  IfThenElse(
    Operation(Type, Equal, Literal(String("array"))),
    sorted,
    SortBy(Literal(Null)),
  )
}
