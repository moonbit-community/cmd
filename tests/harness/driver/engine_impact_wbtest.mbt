///|
test "jq module changes select its jqlog engine consumer" {
  let commands = ["jq", "jqlog", "sort"]
  for
    path in [
      "commands/jq/engine/filter.mbt", "commands/jq/internal/ast/evaluator.mbt",
      "commands/jq/internal/filter/moon.pkg", "commands/jq/moon.mod",
    ] {
    assert_eq(
      oracle_impact(Some([path]), commands, []).2,
      ["jq", "jqlog"],
      msg=path,
    )
  }
  assert_eq(
    oracle_impact(Some(["commands/jqlog/internal/driver/main.mbt"]), commands, []).2,
    ["jqlog"],
  )
  assert_eq(
    oracle_impact(Some(["commands/jq/README.md"]), commands, []).0,
    "none",
  )
}
