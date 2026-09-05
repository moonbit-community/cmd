///|
async test "make parser expands variables and merges rule dependencies" {
  let database : Database = {
    variables: Map([]),
    command_line_variables: Map([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "NAME = output\n$(NAME): first\n$(NAME): second\n\tprintf $@:$<:$^\n", database,
    ".", 0,
  )
  debug_inspect(database.default_target, content="Some(\"output\")")
  guard database.rules.get("output") is Some(rule) else {
    fail("missing parsed rule")
  }
  debug_inspect(rule.dependencies, content="[\"first\", \"second\"]")
  debug_inspect(rule.recipes, content="[\"printf $@:$<:$^\"]")
}

///|
async test "make parser marks phony targets declared before their rule" {
  let database : Database = {
    variables: Map([]),
    command_line_variables: Map([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(".PHONY: clean\nclean:\n\techo clean\n", database, ".", 0)
  guard database.rules.get("clean") is Some(rule) else {
    fail("missing phony rule")
  }
  assert_true(rule.phony)
  debug_inspect(rule.recipes, content="[\"echo clean\"]")
}

///|
async test "make conditionals select one rule and pattern dependencies use stems" {
  let database : Database = {
    variables: Map([]),
    command_line_variables: Map([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "MODE = yes\nifeq ($(MODE),yes)\nall: ready\n\techo yes\nelse\nall:\n\techo no\nendif\n%.o: %.c\n\techo $* $<\nfoo.o: %.o: %.c\n\techo $*\n",
    database, ".", 0,
  )
  guard database.rules.get("all") is Some(all) else {
    fail("missing conditional rule")
  }
  assert_eq(all.dependencies, ["ready"])
  guard database.rules.get("%.o") is Some(pattern) else {
    fail("missing pattern rule")
  }
  assert_eq(pattern.dependencies, ["%.c"])
  guard database.rules.get("foo.o") is Some(static_pattern) else {
    fail("missing static pattern rule")
  }
  assert_eq(static_pattern.dependencies, ["foo.c"])
  assert_eq(static_pattern.stem, Some("foo"))
  assert_true(positive_job_count("2"))
  assert_false(positive_job_count("0"))
  assert_false(positive_job_count("all"))
}
