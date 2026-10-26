// Tests ported from globset/src/lib.rs (mod tests) and the crate docs.

///|
fn build_glob_set(globs : Array[String]) -> @globset.GlobSet raise {
  let builder = @globset.GlobSetBuilder::new()
  for glob in globs {
    builder.add(@globset.Glob::new(glob)) |> ignore
  }
  builder.build()
}

///|
test "set_works" {
  let set = build_glob_set(["src/**/*.rs", "*.c", "src/lib.rs"])
  assert_true(set.is_match("foo.c"))
  assert_true(set.is_match("src/foo.c"))
  assert_false(set.is_match("foo.rs"))
  assert_false(set.is_match("tests/foo.rs"))
  assert_true(set.is_match("src/foo.rs"))
  assert_true(set.is_match("src/grep/src/main.rs"))
  assert_false(set.matches_all("src/lib.rs"))
  assert_false(set.matches_all("src/a/b.c"))
  let matches = set.matches("src/lib.rs")
  assert_eq(2, matches.length())
  assert_eq(0, matches[0])
  assert_eq(2, matches[1])
}

///|
test "empty_set_works" {
  let set = @globset.GlobSetBuilder::new().build()
  assert_false(set.is_match(""))
  assert_false(set.is_match("a"))
  assert_true(set.matches_all("a"))
}

///|
test "matches_all_literals" {
  let set = build_glob_set(["abc", "def"])
  assert_false(set.matches_all("abc"))
  assert_false(set.matches_all("def"))
  let set = build_glob_set(["abc"])
  assert_true(set.matches_all("abc"))
}

///|
test "matches_all_basename_literals" {
  let set = build_glob_set(["**/abc", "**/a.c"])
  assert_false(set.matches_all("foo/abc"))
  assert_false(set.matches_all("foo/a.c"))
  let set = build_glob_set(["**/a.c"])
  assert_true(set.matches_all("foo/a.c"))
}

///|
test "matches_all_extensions" {
  let set = build_glob_set(["**/*.rs", "**/*.c"])
  assert_false(set.matches_all("foo/a.rs"))
  assert_false(set.matches_all("foo/a.c"))
  let set = build_glob_set(["**/*.rs", "*.rs"])
  assert_true(set.matches_all("foo/a.rs"))
}

///|
test "matches_all_required_extensions" {
  let set = build_glob_set(["*.rs", "**/m*.rs", "a/*.rs"])
  assert_true(set.matches_all("a/main.rs"))
  assert_false(set.matches_all("main.rs"))
  assert_false(set.matches_all("a/lib.rs"))
}

///|
test "matches_all_prefix" {
  let set = build_glob_set(["a*", "ab*", "ab/c*"])
  assert_true(set.matches_all("ab/c/def"))
  assert_true(set.matches_all("ab/cd"))
  assert_false(set.matches_all("abc"))
  assert_false(set.matches_all("ab/x"))
  assert_false(set.matches_all("a"))
}

///|
test "matches_all_suffix" {
  let set = build_glob_set(["*.rs", "*s", "*/main.rs"])
  assert_true(set.matches_all("a/b/c/main.rs"))
  assert_false(set.matches_all("foo.rs"))
  assert_false(set.matches_all("as"))
}

///|
test "matches_all_regex" {
  let set = @globset.GlobSet::new([
    @globset.GlobBuilder::new("c*").case_insensitive(true).build(),
    @globset.Glob::new("*{rs,c}"),
  ])
  assert_true(set.matches_all("c/main.rs"))
  assert_true(set.matches_all("C/main.c"))
  assert_false(set.matches_all("Ca"))
  assert_false(set.matches_all("foo.c"))
}

///|
test "default_set_is_empty_works" {
  let set : @globset.GlobSet = Default::default()
  assert_false(set.is_match(""))
  assert_false(set.is_match("a"))
}

///|
test "escape" {
  assert_eq("foo", @globset.escape("foo"))
  assert_eq("foo[*]", @globset.escape("foo*"))
  assert_eq("[[][]]", @globset.escape("[]"))
  assert_eq("[*][?]", @globset.escape("*?"))
  assert_eq("src/[*][*]/[*].rs", @globset.escape("src/**/*.rs"))
  assert_eq("bar[[]ab[]]baz", @globset.escape("bar[ab]baz"))
  assert_eq("bar[[]!![]]!baz", @globset.escape("bar[!!]!baz"))
}

///|
/// This tests that regex matching doesn't "remember" the results of
/// previous searches. That is, if any memory is reused from a previous
/// search, then it should be cleared first.
test "set_does_not_remember" {
  let builder = @globset.GlobSetBuilder::new()
  builder.add(@globset.Glob::new("*foo*")) |> ignore
  builder.add(@globset.Glob::new("*bar*")) |> ignore
  builder.add(@globset.Glob::new("*quux*")) |> ignore
  let set = builder.build()
  let matches = set.matches("ZfooZquuxZ")
  assert_eq(2, matches.length())
  assert_eq(0, matches[0])
  assert_eq(2, matches[1])
  let matches = set.matches("nada")
  assert_eq(0, matches.length())
}

///|
test "debug" {
  let builder = @globset.GlobSetBuilder::new()
  builder.add(@globset.Glob::new("*foo*")) |> ignore
  builder.add(@globset.Glob::new("*bar*")) |> ignore
  builder.add(@globset.Glob::new("*quux*")) |> ignore
  // Rust: GlobSetBuilder { pats: [Glob("*foo*"), Glob("*bar*"), Glob("*quux*")] }
  debug_inspect(
    builder,
    content=(
      #|{ pats: [Glob("*foo*"), Glob("*bar*"), Glob("*quux*")] }
    ),
  )
}

///|
test "doc: one glob" {
  let glob = @globset.Glob::new("*.rs").compile_matcher()
  assert_true(glob.is_match("foo.rs"))
  assert_true(glob.is_match("foo/bar.rs"))
  assert_false(glob.is_match("Cargo.toml"))
}

///|
test "doc: configuring a glob matcher" {
  let glob = @globset.GlobBuilder::new("*.rs")
    .literal_separator(true)
    .build()
    .compile_matcher()
  assert_true(glob.is_match("foo.rs"))
  assert_false(glob.is_match("foo/bar.rs")) // no longer matches
  assert_false(glob.is_match("Cargo.toml"))
}

///|
test "doc: match multiple globs at once" {
  let builder = @globset.GlobSetBuilder::new()
  // A GlobBuilder can be used to configure each glob's match semantics
  // independently.
  builder.add(@globset.Glob::new("*.rs")) |> ignore
  builder.add(@globset.Glob::new("src/lib.rs")) |> ignore
  builder.add(@globset.Glob::new("src/**/foo.rs")) |> ignore
  let set = builder.build()
  assert_eq(set.matches("src/bar/baz/foo.rs"), [0, 2])
}

///|
test "doc: matches_all" {
  let builder = @globset.GlobSetBuilder::new()
  builder.add(@globset.Glob::new("src/*")) |> ignore
  builder.add(@globset.Glob::new("**/*.rs")) |> ignore
  let set = builder.build()
  assert_true(set.matches_all("src/foo.rs"))
  assert_false(set.matches_all("src/bar.c"))
  assert_false(set.matches_all("test.rs"))
}
