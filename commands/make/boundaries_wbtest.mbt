///|
async test "unsupported lazy functions reject before expanding side-effect arguments" {
  let root = @fs.tmpdir(prefix="make-function-boundary-")
  defer @fs.rmdir(root, recursive=true)
  for name in ["if", "or", "and", "foreach", "error", "eval", "file"] {
    try
      expand(
        "$(" + name + " yes,$(shell printf wrong >marker))",
        {},
        {},
        0,
        cwd=root,
      )
    catch {
      MakeError(message) =>
        assert_true(message.contains("outside the supported make profile"))
      error => raise error
    } noraise {
      _ => fail("unsupported GNU function was accepted")
    }
    assert_false(@fs.exists(root + "/marker"))
  }
  assert_eq(expand("$(unknown plain name)", {}, {}, 0), "")
  assert_eq(
    expand("$(if)", { "if": { value: "variable", immediate: true, } }, {}, 0),
    "variable",
  )
  for space in [" ", "\t", "\r", "\n", "\u000b", "\u000c"] {
    try
      expand(
        "$(if" + space + "yes,ok,$(shell printf wrong >marker))",
        {},
        {},
        0,
        cwd=root,
      )
    catch {
      MakeError(message) => assert_true(message.contains("GNU function 'if'"))
      error => raise error
    } noraise {
      _ => fail("GNU function whitespace boundary was ignored")
    }
    assert_false(@fs.exists(root + "/marker"))
    assert_eq(expand("$(shell" + space + "printf ok)", {}, {}, 0), "ok")
  }
}

///|
async test "explicit shell selectors and special rules fail instead of running another profile" {
  for
    source in [
      "SHELL=/not-an-interpreter\nall:\n\t@printf wrong\n", ".SHELLFLAGS=-e -c\nall:\n\t@false; printf wrong\n",
      "all::\n\t@printf wrong\n", "a b &:\n\t@printf wrong\n", ".ONESHELL:\nall:\n\t@printf wrong\n",
      "all: | order\n\t@printf wrong\n", "lib.a(member):\n\t@printf wrong\n", "all: VALUE=wrong\n\t@printf wrong\n",
    ] {
    let database = secondary_database()
    try parse_makefile(source, database, ".", 0) catch {
      MakeError(_) => ()
      error => raise error
    } noraise {
      _ => fail("unsupported control was accepted: " + source)
    }
  }
  let database = secondary_database()
  parse_makefile("SHELL=/bin/sh\n.SHELLFLAGS=-c\nall:\n", database, ".", 0)
}

///|
async test "inline recipes retain hash bytes and delimit only outside complete expansions" {
  let database = secondary_database()
  parse_makefile("all: ; @printf '%s' '#literal'\n", database, ".", 0)
  assert_eq(database.rules["all"].recipes, [" @printf '%s' '#literal'"])
  let database = secondary_database()
  parse_makefile(
    "all: $(shell (printf old); printf ' new'); @printf '%s' '$+'\n", database, ".",
    0,
  )
  assert_eq(resolve_prerequisites(database.rules["all"], database), [
    "old", "new",
  ])
  assert_eq(database.rules["all"].recipes, [" @printf '%s' '$+'"])
  let database = secondary_database()
  parse_makefile("X=hello\nall: ; @printf '%s' '$(X)=ok'\n", database, ".", 0)
  assert_eq(database.rules["all"].recipes, [" @printf '%s' '$(X)=ok'"])
}

///|
async test "rule punctuation inside shell references is not an outer separator" {
  let database = secondary_database()
  parse_makefile(
    "$(shell printf all; :): $(shell printf old | cat)\n\t@printf '%s' '$+'\n", database,
    ".", 0,
  )
  assert_eq(resolve_prerequisites(database.rules["all"], database), ["old"])
  let database = secondary_database()
  parse_makefile("all: $(shell (printf old); printf '=x')\n", database, ".", 0)
  assert_eq(resolve_prerequisites(database.rules["all"], database), ["old=x"])
}
