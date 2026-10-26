// Port of the unit tests in `ignore/src/types.rs` and
// `ignore/src/default_types.rs`.

///|
fn types() -> Array[String] {
  [
    "html:*.html", "html:*.htm", "rust:*.rs", "js:*.js", "py:*.py", "python:*.py",
    "foo:*.{rs,foo}", "combo:include:html,rust",
  ]
}

///|
fn check_matched(
  tys : Array[String],
  sel : Array[String],
  selnot : Array[String],
  path : String,
  matched : Bool,
) -> Unit raise {
  let btypes = @ignore.TypesBuilder::new()
  for tydef in tys {
    btypes.add_def(tydef)
  }
  for s in sel {
    btypes.select(s) |> ignore
  }
  for s in selnot {
    btypes.negate(s) |> ignore
  }
  let types = btypes.build()
  let mat = types.matched(path, false)
  assert_eq(matched, !mat.is_ignore())
}

///|
test "types/match" {
  check_matched(types(), ["rust"], [], "lib.rs", true)
  check_matched(types(), ["html"], [], "index.html", true)
  check_matched(types(), ["html"], [], "index.htm", true)
  check_matched(types(), ["html", "rust"], [], "main.rs", true)
  check_matched(types(), [], [], "index.html", true)
  check_matched(types(), [], ["rust"], "index.html", true)
  check_matched(types(), ["foo"], ["rust"], "main.foo", true)
  check_matched(types(), ["combo"], [], "index.html", true)
  check_matched(types(), ["combo"], [], "lib.rs", true)
  check_matched(types(), ["py"], [], "main.py", true)
  check_matched(types(), ["python"], [], "main.py", true)
}

///|
test "types/matchnot" {
  check_matched(types(), ["rust"], [], "index.html", false)
  check_matched(types(), [], ["rust"], "main.rs", false)
  check_matched(types(), ["foo"], ["rust"], "main.rs", false)
  check_matched(types(), ["rust"], ["foo"], "main.rs", false)
  check_matched(types(), ["rust"], ["foo"], "main.foo", false)
  check_matched(types(), ["combo"], [], "leftpad.js", false)
  check_matched(types(), ["py"], [], "index.html", false)
  check_matched(types(), ["python"], [], "doc.md", false)
}

///|
test "types/test_invalid_defs" {
  let btypes = @ignore.TypesBuilder::new()
  for tydef in types() {
    btypes.add_def(tydef)
  }
  // Preserve the original definitions for later comparison.
  let original_defs = btypes.definitions()
  let bad_defs = [
    // Reference to type that does not exist
    "combo:include:html,qwerty",
    // Bad format
     "combo:foobar:html,rust", "",
  ]
  for def in bad_defs {
    let res = try btypes.add_def(def) catch {
      _ => false
    } noraise {
      _ => true
    }
    assert_true(!res)
    // Ensure that nothing changed, even if some of the includes were valid.
    assert_eq(btypes.definitions(), original_defs)
  }
}

///|
test "types/module docs examples" {
  let builder = @ignore.TypesBuilder::new()
  builder.add_defaults().select("rust") |> ignore
  let matcher = builder.build()
  assert_true(matcher.matched("foo.rs", false).is_whitelist())
  assert_true(matcher.matched("foo.c", false).is_ignore())
  let builder = @ignore.TypesBuilder::new()
  builder.add_defaults().negate("c") |> ignore
  let matcher = builder.build()
  assert_true(matcher.matched("foo.rs", false).is_none())
  assert_true(matcher.matched("foo.c", false).is_ignore())
  let builder = @ignore.TypesBuilder::new()
  builder.add_defaults() |> ignore
  builder.add("foo", "*.foo")
  // Another way of adding a file type definition.
  // This is useful when accepting input from an end user.
  builder.add_def("bar:*.bar")
  // Note: we only select `foo`, not `bar`.
  builder.select("foo") |> ignore
  let matcher = builder.build()
  assert_true(matcher.matched("x.foo", false).is_whitelist())
  // This is ignored because we only selected the `foo` file type.
  assert_true(matcher.matched("x.bar", false).is_ignore())
  let builder = @ignore.TypesBuilder::new()
  builder.add_defaults() |> ignore
  builder.add("foo", "*.foo")
  builder.add_def("bar:include:foo,cpp")
  builder.select("bar") |> ignore
  let matcher = builder.build()
  assert_true(matcher.matched("x.foo", false).is_whitelist())
  assert_true(matcher.matched("y.cpp", false).is_whitelist())
}

///|
test "types/errors" {
  let builder = @ignore.TypesBuilder::new()
  builder.select("nope") |> ignore
  try builder.build() |> ignore catch {
    err => inspect(err, content="unrecognized file type: nope")
  } noraise {
    _ => fail("expected an error")
  }
  try @ignore.TypesBuilder::new().add_def("a-b:*.x") catch {
    err =>
      inspect(
        err,
        content="invalid definition (format is type:glob, e.g., html:*.html)",
      )
  } noraise {
    _ => fail("expected an error")
  }
  let builder = @ignore.TypesBuilder::new()
  builder.add_def("bad:*.{a")
  builder.select("bad") |> ignore
  try builder.build() |> ignore catch {
    err =>
      inspect(
        err,
        content="error parsing glob '*.{a': unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)",
      )
  } noraise {
    _ => fail("expected an error")
  }
  // Unicode letters and numbers are allowed in names.
  @ignore.TypesBuilder::new().add("été2", "*.x")
}

///|
test "types/definitions are sorted" {
  let builder = @ignore.TypesBuilder::new()
  builder.add_def("zz:*.b")
  builder.add_def("zz:*.a")
  builder.add_def("Ab:*.x")
  builder.add_def("aa:*.y")
  let defs = builder.definitions()
  debug_inspect(
    defs.map(d => d.name()),
    content=(
      #|["Ab", "aa", "zz"]
    ),
  )
  debug_inspect(
    defs[2].globs(),
    content=(
      #|<ArrayView: ["*.a", "*.b"]>
    ),
  )
  let types = builder.select("zz").build()
  match types.matched("x.a", false) {
    Whitelist(glob) =>
      inspect(glob.file_type_def().unwrap().name(), content="zz")
    _ => fail("expected a whitelist match")
  }
  match types.matched("x.y", false) {
    Ignore(glob) => assert_true(glob.file_type_def() is None)
    _ => fail("expected an ignore match")
  }
}

///|
test "default_types/default_types_are_sorted" {
  let builder = @ignore.TypesBuilder::new()
  builder.add_defaults() |> ignore
  let defs = builder.definitions()
  assert_true(defs.length() > 200)
  // Spot check a few definitions.
  let rust = defs.iter().find_first(d => d.name() == "rust").unwrap()
  debug_inspect(
    rust.globs(),
    content=(
      #|<ArrayView: ["*.rs"]>
    ),
  )
  let c = defs.iter().find_first(d => d.name() == "c").unwrap()
  debug_inspect(
    c.globs(),
    content=(
      #|<ArrayView: ["*.[chH]", "*.[chH].in", "*.cats"]>
    ),
  )
}
