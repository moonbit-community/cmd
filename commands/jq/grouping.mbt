///|
// Canonical object order and safe numeric representations give equal keys the
// same full JSON encoding. Unsafe numeric precision remains the evaluator's
// existing boundary; original large-number representations are not rounded.
fn grouping_key_normalizer() -> @ast.Expr {
  let object : @ast.Expr = Pipe(
    ToEntries,
    Pipe(SortBy(Key("key")), FromEntries),
  )
  let number : @ast.Expr = IfThenElse(
    Operation(Abs, LessThan, Literal(Number(9007199254740992.0))),
    Operation(Identity, Add, Literal(Number(0.0))),
    Identity,
  )
  Walk(
    IfThenElse(
      Operation(Type, Equal, Literal(String("object"))),
      object,
      IfThenElse(
        Operation(Type, Equal, Literal(String("number"))),
        number,
        Identity,
      ),
    ),
  )
}

///|
// Evaluate the original key stream once for each member, before introducing
// any private binding. Group a flat full encoding instead of depth-limited
// debug keys, retain encounter order within groups, then sort the groups by
// their semantic keys. This avoids sorting members or repeated array append.
fn lower_grouping(key : @ast.Expr) -> @ast.Expr {
  let binding = "__cli_group_keys"
  let keys : @ast.Expr = Variable(binding)
  let decorated : @ast.Expr = Map(
    As(
      Pipe(ArrayConstruct(Some(key)), grouping_key_normalizer()),
      binding,
      ObjectConstruct([
        (Literal(String("keys")), Some(keys)),
        (Literal(String("encoded")), Some(Pipe(keys, ToJsonString))),
        (Literal(String("value")), Some(Identity)),
      ]),
    ),
  )
  let grouped : @ast.Expr = Pipe(
    decorated,
    Pipe(
      GroupBy(Key("encoded")),
      Pipe(SortBy(Pipe(Index([0]), Key("keys"))), Map(Map(Key("value")))),
    ),
  )
  IfThenElse(
    Operation(Type, Equal, Literal(String("array"))),
    grouped,
    GroupBy(Literal(Null)),
  )
}
