///|
async test "default exports retain explicit decisions across global toggles" {
  let database = secondary_database()
  parse_makefile(
    "BEFORE=before\nexport\nAFTER=after\nunexport HIDDEN\nHIDDEN=hidden\nexport KEPT=kept\n",
    database, ".", 0,
  )
  let exported = command_environment(database)
  assert_eq(exported.get("BEFORE"), Some("before"))
  assert_eq(exported.get("AFTER"), Some("after"))
  assert_eq(exported.get("HIDDEN"), None)
  assert_eq(exported.get("KEPT"), Some("kept"))
  parse_makefile("unexport\n", database, ".", 0)
  let unexported = command_environment(database)
  assert_eq(unexported.get("BEFORE"), None)
  assert_eq(unexported.get("AFTER"), None)
  assert_eq(unexported.get("HIDDEN"), None)
  assert_eq(unexported.get("KEPT"), Some("kept"))
  parse_makefile("export\n", database, ".", 0)
  assert_eq(command_environment(database).get("HIDDEN"), None)
}

///|
async test "named export and unexport create empty variables before conditional assignment" {
  let database = secondary_database()
  parse_makefile(
    "export EMPTY\nunexport HIDDEN\nEMPTY ?= wrong\nHIDDEN ?= wrong\nexport VISIBLE=old\nunexport VISIBLE:=new\n",
    database, ".", 0,
  )
  assert_eq(
    expand("<$(EMPTY)>|<$(HIDDEN)>|$(VISIBLE)", database.variables, {}, 0),
    "<>|<>|new",
  )
  let environment = command_environment(database)
  assert_eq(environment.get("EMPTY"), Some(""))
  assert_eq(environment.get("HIDDEN"), None)
  assert_eq(environment.get("VISIBLE"), None)
}

///|
async test "export keywords preserve variable names rule names and computed empty lists" {
  let database = secondary_database()
  parse_makefile(
    "export = before\nexport export = after\nunexport unexport=local\nexport\tunexport\nLOCAL=hidden\nEMPTY=\nexport $(EMPTY)\nexport:\n\t@printf target\nall: export\n",
    database, ".", 0,
  )
  assert_eq(database.variables["export"].value, "after")
  assert_eq(database.variables["unexport"].value, "local")
  let environment = command_environment(database)
  assert_eq(environment.get("export"), Some("after"))
  assert_eq(environment.get("unexport"), Some("local"))
  assert_eq(environment.get("LOCAL"), None)
  assert_true(database.rules.contains("export"))
  for separator in ["\t", "\r", "\u000b", "\u000c"] {
    parse_makefile("export" + separator + "LOCAL\n", database, ".", 0)
    assert_eq(command_environment(database).get("LOCAL"), Some("hidden"))
    parse_makefile("unexport" + separator + "LOCAL\n", database, ".", 0)
    assert_eq(command_environment(database).get("LOCAL"), None)
  }
}

///|
async test "default export names and builtins differ from explicit or inherited names" {
  let database = secondary_database()
  for name in ["A", "_A0", "0A", "A.B", "A-B", "é", "BUILTIN", "INHERITED"] {
    database.variables[name] = { value: name, immediate: true, }
  }
  database.exported.defaults.add("BUILTIN")
  database.exported.add("INHERITED")
  parse_makefile("export\n", database, ".", 0)
  let environment = command_environment(database)
  for name in ["A", "_A0", "INHERITED"] {
    assert_eq(environment.get(name), Some(name))
  }
  for name in ["0A", "A.B", "A-B", "é", "BUILTIN"] {
    assert_eq(environment.get(name), None)
  }
  parse_makefile("export 0A A.B A-B é BUILTIN\nunexport\n", database, ".", 0)
  let explicit = command_environment(database)
  for name in ["0A", "A.B", "A-B", "é", "BUILTIN", "INHERITED"] {
    assert_eq(explicit.get(name), Some(name))
  }
  assert_eq(explicit.get("A"), None)
}

///|
async test "export-all target applies after parsing while explicit unexport still wins" {
  let database = secondary_database()
  parse_makefile(
    ".EXPORT_ALL_VARIABLES:\nVALUE=visible\nunexport HIDDEN=hidden\nOBSERVED := $(shell printf '%s' \"$$VALUE\")\nunexport\nall:\n\t@printf ok\n",
    database, ".", 0,
  )
  assert_eq(database.variables["OBSERVED"].value, "")
  assert_eq(command_environment(database).get("VALUE"), None)
  database.exported.finish_reading()
  let environment = command_environment(database)
  assert_eq(environment.get("VALUE"), Some("visible"))
  assert_eq(environment.get("HIDDEN"), None)
  assert_eq(database.default_target, Some("all"))
}

///|
async test "default-exported shell recursion uses the original environment" {
  for (original, expected) in [({ "HI": "seed" }, "inner:seed"), ({}, "inner:")] {
    let variables : Map[String, Variable] = {
      "HI": { value: "$(shell printf 'inner:%s' \"$$HI\")", immediate: false, },
    }
    let exported = ExportPolicy::new([])
    exported.all = true
    let state = Expansion::new(original~)
    assert_eq(
      lookup_variable("HI", variables, {}, 0, exported~, state~),
      expected,
    )
    assert_eq(state.active.length(), 0)
    assert_eq(state.environment_depth, 0)
  }
}

///|
async test "assignment export modifiers use the final flag while name lists remain literal" {
  let database = secondary_database()
  parse_makefile(
    "export export F=one\nexport unexport X=two\nunexport export Y=three\nexport export X\n",
    database, ".", 0,
  )
  assert_eq(database.variables["F"].value, "one")
  assert_eq(database.variables["X"].value, "two")
  assert_eq(database.variables["Y"].value, "three")
  assert_eq(database.variables["export"].value, "")
  let environment = command_environment(database)
  assert_eq(environment.get("F"), Some("one"))
  assert_eq(environment.get("X"), Some("two"))
  assert_eq(environment.get("Y"), Some("three"))
  assert_eq(environment.get("export"), Some(""))
  assert_false(database.variables.contains("F=one"))
}

///|
async test "unsupported assignment modifiers reject before creating environment entries" {
  for source in ["export override X=value", "unexport private X=value"] {
    let database = secondary_database()
    try parse_makefile(source + "\n", database, ".", 0) catch {
      MakeError(message) => assert_true(message.contains("assignment modifier"))
      error => raise error
    } noraise {
      _ => fail("unsupported modifier was silently treated as a name list")
    }
    assert_false(database.variables.contains("X=value"))
    assert_false(database.variables.contains("X"))
  }
}

///|
async test "bare export directives recognize all six GNU whitespace characters" {
  for space in [" ", "\t", "\r", "\u000b", "\u000c"] {
    let database = secondary_database()
    parse_makefile("VALUE=visible\nexport" + space + "\n", database, ".", 0)
    assert_eq(command_environment(database).get("VALUE"), Some("visible"))
    parse_makefile("unexport" + space + "\n", database, ".", 0)
    assert_eq(command_environment(database).get("VALUE"), None)
  }
}

///|
async test "complete assignments precede export modifiers with nonblank whitespace" {
  for space in ["\r", "\u000b", "\u000c"] {
    let database = secondary_database()
    parse_makefile("export" + space + "VALUE=hello\n", database, ".", 0)
    assert_eq(database.variables["export" + space + "VALUE"].value, "hello")
    assert_false(database.variables.contains(space + "VALUE"))
    assert_false(database.variables.contains("VALUE"))
    parse_makefile(space + "export\nLOCAL=visible\n", database, ".", 0)
    assert_eq(command_environment(database).get("LOCAL"), Some("visible"))
    parse_makefile(space + "unexport\n", database, ".", 0)
    assert_eq(command_environment(database).get("LOCAL"), None)
  }
}
