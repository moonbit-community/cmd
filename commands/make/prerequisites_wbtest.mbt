///|
fn secondary_database() -> Database {
  {
    cwd: ".",
    variables: Map([]),
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
    secondary_expansion: false,
    invocation_level: 0,
    serial_children: false,
  }
}

///|
async test "secondary prerequisites use late variables nested automatic names and deferred shell" {
  let database = secondary_database()
  parse_makefile(
    ".SECONDEXPANSION:\nLIST = first\nall_DEPS = leaf\nall: $$(LIST) $$($$@_DEPS) $$(shell printf extra)\nLIST = second\n",
    database, ".", 0,
  )
  assert_eq(resolve_prerequisites(database.rules["all"], database), [
    "second", "leaf", "extra",
  ])
  assert_eq(database.default_target, Some("all"))
}

///|
async test "secondary automatic variables follow GNU make 4.4.1 dependency chain ordering" {
  for
    (source, expected) in [
      (
        ".SECONDEXPANSION:\nall: a $$< $$^ $$+\n\tprintf all\nall: b $$< $$^ $$+\n",
        "a b a a a",
      ),
      (
        ".SECONDEXPANSION:\nall: a b $$< $$^ $$+\nall: c d $$< $$^ $$+\nall: e f $$< $$^ $$+\n\tprintf all\n",
        "e f a b e e f e f c d e e f a b e f a b e e f e f",
      ),
      ("all: first\n\tprintf all\nall: second\n", "first second"),
      (
        "all: a\nall: b\n\tprintf old\nall: c\nall: d\n\tprintf new\n", "d b a c",
      ),
    ] {
    let database = secondary_database()
    parse_makefile(source, database, ".", 0)
    assert_eq(
      resolve_prerequisites(database.rules["all"], database).join(" "),
      expected,
    )
  }
}

///|
async test "secondary expansion is enabled only for subsequent declarations" {
  let database = secondary_database()
  parse_makefile(
    "early: $$(NAME)\n.SECONDEXPANSION:\nlate: $$(NAME)\nNAME = leaf\n", database,
    ".", 0,
  )
  assert_eq(resolve_prerequisites(database.rules["early"], database), [
    "$(NAME)",
  ])
  assert_eq(resolve_prerequisites(database.rules["late"], database), ["leaf"])
}

///|
async test "secondary static and implicit pattern rules expose the actual stem" {
  let database = secondary_database()
  parse_makefile(
    ".SECONDEXPANSION:\nfoo.o: %.o: $$*.c\n%.out: $$*.in\n", database, ".", 0,
  )
  assert_eq(resolve_prerequisites(database.rules["foo.o"], database), ["foo.c"])
  let pattern = instantiate_pattern(database.rules["%.out"], "bar.out").unwrap()
  assert_eq(resolve_prerequisites(pattern, database), ["bar.in"])
  parse_makefile("foo.obj: %.obj: %%.c\n%.bin: %%.c\n", database, ".", 0)
  assert_eq(resolve_prerequisites(database.rules["foo.obj"], database), [
    "foo%.c",
  ])
  let multiple = instantiate_pattern(database.rules["%.bin"], "foo.bin").unwrap()
  assert_eq(resolve_prerequisites(multiple, database), ["foo%.c"])
}

///|
async test "automatic variable modifiers need parentheses and caret removes duplicates" {
  let automatic = automatic_variables("dir/output", None, ["a", "b", "a"])
  assert_eq(
    expand("$@D|$(@D)|$(@F)|$^|$+", {}, automatic, 0),
    "dir/outputD|dir|output|a b|a b a",
  )
}
