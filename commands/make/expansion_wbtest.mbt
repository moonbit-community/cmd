///|
async test "computed export names use one resolved name for both assignment and environment" {
  let database = secondary_database()
  parse_makefile("NAME=QA31_EXPORTED\nexport $(NAME)=ok\n", database, ".", 0)
  assert_eq(expand("$(QA31_EXPORTED)", database.variables, {}, 0), "ok")
  assert_eq(command_environment(database).get("QA31_EXPORTED"), Some("ok"))
  parse_makefile("unexport $(NAME)\n", database, ".", 0)
  assert_eq(command_environment(database).get("QA31_EXPORTED"), None)
}

///|
async test "shell function recognition preserves whitespace and trailing escaped spaces" {
  let variables : Map[String, Variable] = {
    "shell": { value: "collision", immediate: true, },
  }
  assert_eq(expand("$(shell exit 7)", variables, {}, 0), "")
  assert_eq(
    expand(
      "<$(shell )>|<$(shell)>|<$(shell\t)>|$(.SHELLSTATUS)",
      variables,
      {},
      0,
    ),
    "<>|<collision>|<>|7",
  )
  assert_eq(expand("$(shell printf a\\ )", variables, {}, 0), "a ")
  assert_eq(expand("$( shell printf changed)", variables, {}, 0), "")
  assert_eq(expand("$(shell printf 'a\\000b\\n')", variables, {}, 0), "a")
}

///|
async test "exported variables see recipe automatic variables" {
  let database = secondary_database()
  parse_makefile(
    "export TARGET=$@\nexport FIRST=$<\nall: leaf\n", database, ".", 0,
  )
  let actual = command_environment(
    database,
    automatic=automatic_variables("all", None, ["leaf"]),
  )
  assert_eq(actual.get("TARGET"), Some("all"))
  assert_eq(actual.get("FIRST"), Some("leaf"))
  assert_eq(actual.get("MAKELEVEL"), Some("1"))
}

///|
async test "exported shell recursion falls back only to the original environment" {
  for (original, expected) in [({ "HI": "seed" }, "inner:seed"), ({}, "inner:")] {
    let variables : Map[String, Variable] = {
      "HI": { value: "$(shell printf 'inner:%s' \"$$HI\")", immediate: false, },
    }
    let state = Expansion::new(original~)
    assert_eq(
      lookup_variable("HI", variables, {}, 0, exported=Set(["HI"]), state~),
      expected,
    )
    assert_eq(state.active.length(), 0)
    assert_eq(state.environment_depth, 0)
  }
}

///|
async test "ordinary recursive variables fail without poisoning later expansion" {
  let variables : Map[String, Variable] = {
    "A": { value: "$(B)", immediate: false, },
    "B": { value: "$(A)", immediate: false, },
  }
  let state = Expansion::new(original={ "A": "not-a-fallback" })
  try expand("$(A)", variables, {}, 0, state~) catch {
    MakeError(message) =>
      assert_eq(message, "recursive variable 'A' references itself")
    err => raise err
  } noraise {
    _ => fail("ordinary recursion was accepted")
  }
  assert_eq(state.active.length(), 0)
  variables["B"] = { value: "recovered", immediate: true, }
  assert_eq(expand("$(A)", variables, {}, 0, state~), "recovered")
}

///|
async test "empty shell expansion preserves status and shell assignment retains recursive value" {
  let variables : Map[String, Variable] = Map([])
  assert_eq(expand("$(shell exit 7)", variables, {}, 0), "")
  assert_eq(expand("$(shell )$(shell \t )", variables, {}, 0), "")
  assert_eq(expand("$(.SHELLSTATUS)", variables, {}, 0), "7")
  let database : Database = {
    cwd: ".",
    variables,
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
    secondary_expansion: false,
    invocation_level: 0,
    serial_children: false,
  }
  parse_makefile(
    "VALUE != printf 'a\\nb\\n\\n'; exit 3\nSAVED := $(.SHELLSTATUS)\nREF != printf '$$(LATER)'\nLATER = late\n",
    database, ".", 0,
  )
  assert_eq(expand("$(VALUE)|$(SAVED)|$(REF)", variables, {}, 0), "a b |3|late")
}
