///|
test "make parser expands variables and merges rule dependencies" {
  let database : Database = {
    variables: Map([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "NAME = output\n$(NAME): first\n$(NAME): second\n\tprintf $@:$<:$^\n", database,
  )
  debug_inspect(database.default_target, content="Some(\"output\")")
  guard database.rules.get("output") is Some(rule) else {
    fail("missing parsed rule")
  }
  debug_inspect(rule.dependencies, content="[\"first\", \"second\"]")
  debug_inspect(rule.recipes, content="[\"printf $@:$<:$^\"]")
}

///|
test "make parser marks phony targets declared before their rule" {
  let database : Database = {
    variables: Map([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(".PHONY: clean\nclean:\n\techo clean\n", database)
  guard database.rules.get("clean") is Some(rule) else {
    fail("missing phony rule")
  }
  assert_true(rule.phony)
  debug_inspect(rule.recipes, content="[\"echo clean\"]")
}
