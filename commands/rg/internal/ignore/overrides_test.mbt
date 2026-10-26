// Port of the unit tests in `ignore/src/overrides.rs`.

///|
const OV_ROOT : String = "/home/andrew/foo"

///|
fn ov(globs : Array[String]) -> @ignore.Override raise {
  let builder = @ignore.OverrideBuilder::new(OV_ROOT)
  for glob in globs {
    builder.add(glob) |> ignore
  }
  builder.build()
}

///|
test "overrides/empty" {
  let ov = ov([])
  assert_true(ov.matched("a.foo", false).is_none())
  assert_true(ov.matched("a", false).is_none())
  assert_true(ov.matched("", false).is_none())
}

///|
test "overrides/simple" {
  let ov = ov(["*.foo", "!*.bar"])
  assert_true(ov.matched("a.foo", false).is_whitelist())
  assert_true(ov.matched("a.foo", true).is_whitelist())
  assert_true(ov.matched("a.rs", false).is_ignore())
  assert_true(ov.matched("a.rs", true).is_none())
  assert_true(ov.matched("a.bar", false).is_ignore())
  assert_true(ov.matched("a.bar", true).is_ignore())
}

///|
test "overrides/only_ignores" {
  let ov = ov(["!*.bar"])
  assert_true(ov.matched("a.rs", false).is_none())
  assert_true(ov.matched("a.rs", true).is_none())
  assert_true(ov.matched("a.bar", false).is_ignore())
  assert_true(ov.matched("a.bar", true).is_ignore())
}

///|
test "overrides/precedence" {
  let ov = ov(["*.foo", "!*.bar.foo"])
  assert_true(ov.matched("a.foo", false).is_whitelist())
  assert_true(ov.matched("a.baz", false).is_ignore())
  assert_true(ov.matched("a.bar.foo", false).is_ignore())
}

///|
test "overrides/gitignore" {
  let ov = ov(["/foo", "bar/*.rs", "baz/**"])
  assert_true(ov.matched("bar/lib.rs", false).is_whitelist())
  assert_true(ov.matched("bar/wat/lib.rs", false).is_ignore())
  assert_true(ov.matched("wat/bar/lib.rs", false).is_ignore())
  assert_true(ov.matched("foo", false).is_whitelist())
  assert_true(ov.matched("wat/foo", false).is_ignore())
  assert_true(ov.matched("baz", false).is_ignore())
  assert_true(ov.matched("baz/a", false).is_whitelist())
  assert_true(ov.matched("baz/a/b", false).is_whitelist())
}

///|
test "overrides/allow_directories" {
  // This tests that directories are NOT ignored when they are unmatched.
  let ov = ov(["*.rs"])
  assert_true(ov.matched("foo.rs", false).is_whitelist())
  assert_true(ov.matched("foo.c", false).is_ignore())
  assert_true(ov.matched("foo", false).is_ignore())
  assert_true(ov.matched("foo", true).is_none())
  assert_true(ov.matched("src/foo.rs", false).is_whitelist())
  assert_true(ov.matched("src/foo.c", false).is_ignore())
  assert_true(ov.matched("src/foo", false).is_ignore())
  assert_true(ov.matched("src/foo", true).is_none())
}

///|
test "overrides/absolute_path" {
  let ov = ov(["!/bar"])
  assert_true(ov.matched("./foo/bar", false).is_none())
}

///|
test "overrides/case_insensitive" {
  let ov = @ignore.OverrideBuilder::new(OV_ROOT)
    .case_insensitive(true)
    .add("*.html")
    .build()
  assert_true(ov.matched("foo.html", false).is_whitelist())
  assert_true(ov.matched("foo.HTML", false).is_whitelist())
  assert_true(ov.matched("foo.htm", false).is_ignore())
  assert_true(ov.matched("foo.HTM", false).is_ignore())
}

///|
test "overrides/default_case_sensitive" {
  let ov = @ignore.OverrideBuilder::new(OV_ROOT).add("*.html").build()
  assert_true(ov.matched("foo.html", false).is_whitelist())
  assert_true(ov.matched("foo.HTML", false).is_ignore())
  assert_true(ov.matched("foo.htm", false).is_ignore())
  assert_true(ov.matched("foo.HTM", false).is_ignore())
}

///|
test "overrides/glob error rendering" {
  // Overrides do not allow unclosed classes by default.
  try @ignore.OverrideBuilder::new(OV_ROOT).add("[abc") |> ignore catch {
    err =>
      inspect(
        err,
        content="error parsing glob '[abc': unclosed character class; missing ']'",
      )
  } noraise {
    _ => fail("expected an error")
  }
  // ... but they can be enabled.
  let ov = @ignore.OverrideBuilder::new(OV_ROOT)
    .allow_unclosed_class(true)
    .add("[abc")
    .build()
  assert_true(ov.matched("[abc", false).is_whitelist())
}
