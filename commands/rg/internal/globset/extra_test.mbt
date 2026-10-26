// Additional tests (not ported from Rust) covering error messages and the
// MoonBit-specific glob set strategies.

///|
fn glob_error(pat : String) -> @globset.GlobError raise {
  try @globset.Glob::new(pat) catch {
    err => err
  } noraise {
    _ => fail("expected \{pat} to fail")
  }
}

///|
test "error display" {
  inspect(
    glob_error("[z-a]"),
    content="error parsing glob '[z-a]': invalid range; 'z' > 'a'",
  )
  inspect(
    glob_error("["),
    content="error parsing glob '[': unclosed character class; missing ']'",
  )
  inspect(
    glob_error("{a"),
    content="error parsing glob '{a': unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)",
  )
  inspect(
    glob_error("a}"),
    content="error parsing glob 'a}': unopened alternate group; missing '{' (maybe escape '}' with '[}]'?)",
  )
  inspect(glob_error("a\\"), content="error parsing glob 'a\\': dangling '\\'")
  let err = glob_error("[z-a]")
  assert_eq(err.glob(), Some("[z-a]"))
  assert_eq(err.kind(), @globset.InvalidRange('z', 'a'))
}

///|
test "glob accessors" {
  let glob = @globset.Glob::new("src/**/*.rs")
  inspect(glob, content="src/**/*.rs")
  assert_eq(glob.glob(), "src/**/*.rs")
  inspect(glob.regex(), content="(?-u)^src(?:/|/.*/).*\\.rs$")
  debug_inspect(glob, content="Glob(\"src/**/*.rs\")")
  assert_eq(glob.compile_matcher().glob(), glob)
  assert_true(glob == @globset.Glob::new("src/**/*.rs"))
  assert_false(
    glob ==
    @globset.GlobBuilder::new("src/**/*.rs").case_insensitive(true).build(),
  )
}

///|
test "glob set with many regex globs" {
  // Enough regex-strategy globs to span several chunks.
  let globs = []
  for i in 0..<100 {
    globs.push("dir\{i}/*/x\{i}?")
  }
  let set = build_glob_set(globs)
  assert_eq(set.len(), 100)
  assert_eq(set.matches("dir42/a/x42z"), [42])
  assert_eq(set.matches("dir7/a/b/x7_"), [7])
  assert_eq(set.matches("dir99/q/x99!"), [99])
  assert_eq(set.matches("dir42/a/x43z"), [])
  assert_true(set.is_match("dir0/a/x0a"))
  assert_false(set.is_match("dir100/a/x100a"))
  assert_false(set.matches_all("dir0/a/x0a"))
  let into = [1, 2, 3]
  set.matches_into("dir1/a/x1a", into)
  assert_eq(into, [1])
}

///|
test "glob set mixing strategies" {
  let set = @globset.GlobSet::new([
    @globset.Glob::new("**/*.rs"), // 0: extension
    @globset.Glob::new("**/Cargo.toml"), // 1: basename literal
    @globset.Glob::new("src/lib.rs"), // 2: literal
    @globset.Glob::new("target/**"), // 3: prefix
    @globset.Glob::new("**/foo/bar"), // 4: suffix (component)
    @globset.Glob::new("src/*.rs"), // 5: required extension
    @globset.Glob::new("*/m?in.rs"), // 6: required extension
    @globset.Glob::new("{a,b}/c"), // 7: regex
    @globset.GlobBuilder::new("README*").case_insensitive(true).build(), // 8: regex
    @globset.Glob::new("target/**"), // 9: prefix (duplicate)
  ])
  assert_eq(set.matches("src/lib.rs"), [0, 2, 5])
  assert_eq(set.matches("x/main.rs"), [0, 6])
  assert_eq(set.matches("a/b/Cargo.toml"), [1])
  assert_eq(set.matches("Cargo.toml"), [1])
  assert_eq(set.matches("target/debug/x"), [3, 9])
  assert_eq(set.matches("foo/bar"), [4])
  assert_eq(set.matches("x/foo/bar"), [4])
  assert_eq(set.matches("xfoo/bar"), [])
  assert_eq(set.matches("b/c"), [7])
  assert_eq(set.matches("readme.md"), [8])
  assert_eq(set.matches("other"), [])
}

///|
test "regex set flags do not leak between globs" {
  let globs = [
    @globset.GlobBuilder::new("x{a,b}").case_insensitive(true).build(),
  ]
  for i in 0..<40 {
    globs.push(@globset.Glob::new("y\{i}{a,b}"))
  }
  let set = @globset.GlobSet::new(globs)
  assert_eq(set.matches("XA"), [0])
  assert_eq(set.matches("y3a"), [4])
  assert_eq(set.matches("Y3a"), [])
  assert_false(set.is_match("Y3A"))
  assert_true(set.is_match("xB"))
}

///|
test "candidate from non-UTF-8 bytes" {
  let set = build_glob_set(["*.txt", "a?b", "**/x\u{2603}y"])
  let c = @globset.Candidate::from_bytes(b"\xff\xfe.txt")
  assert_eq(set.matches_candidate(c), [0])
  let c = @globset.Candidate::from_bytes(b"a\xffb")
  assert_eq(set.matches_candidate(c), [1])
  assert_eq(set.matches("dir/x\u{2603}y"), [2])
  // `?` matches a single byte, not a single codepoint.
  assert_eq(set.matches("a\u{2603}b"), [])
  debug_inspect(
    @globset.Candidate::new("foo/bar.rs"),
    content=(
      #|{ path: "foo/bar.rs", basename: "bar.rs", ext: ".rs" }
    ),
  )
}
