// Port of the unit tests in `ignore/src/gitignore.rs`.

///|
fn gi_from_str(root : String, s : String) -> Gitignore {
  let builder = GitignoreBuilder::new(root)
  (builder.add_str(None, s) |> ignore) catch {
    e => abort(e.to_string())
  }
  builder.build() catch {
    e => abort(e.to_string())
  }
}

///|
const ROOT : String = "/home/foobar/rust/rg"

///|
test "gitignore/ig1" {
  let gi = gi_from_str(ROOT, "months")
  assert_true(gi.matched("months", false).is_ignore())
}

///|
test "gitignore/ig2" {
  let gi = gi_from_str(ROOT, "*.lock")
  assert_true(gi.matched("Cargo.lock", false).is_ignore())
}

///|
test "gitignore/ig3" {
  let gi = gi_from_str(ROOT, "*.rs")
  assert_true(gi.matched("src/main.rs", false).is_ignore())
}

///|
test "gitignore/ig4" {
  let gi = gi_from_str(ROOT, "src/*.rs")
  assert_true(gi.matched("src/main.rs", false).is_ignore())
}

///|
test "gitignore/ig5" {
  let gi = gi_from_str(ROOT, "/*.c")
  assert_true(gi.matched("cat-file.c", false).is_ignore())
}

///|
test "gitignore/ig6" {
  let gi = gi_from_str(ROOT, "/src/*.rs")
  assert_true(gi.matched("src/main.rs", false).is_ignore())
}

///|
test "gitignore/ig7" {
  let gi = gi_from_str(ROOT, "!src/main.rs\n*.rs")
  assert_true(gi.matched("src/main.rs", false).is_ignore())
}

///|
test "gitignore/ig8" {
  let gi = gi_from_str(ROOT, "foo/")
  assert_true(gi.matched("foo", true).is_ignore())
}

///|
test "gitignore/ig9" {
  let gi = gi_from_str(ROOT, "**/foo")
  assert_true(gi.matched("foo", false).is_ignore())
}

///|
test "gitignore/ig10" {
  let gi = gi_from_str(ROOT, "**/foo")
  assert_true(gi.matched("src/foo", false).is_ignore())
}

///|
test "gitignore/ig11" {
  let gi = gi_from_str(ROOT, "**/foo/**")
  assert_true(gi.matched("src/foo/bar", false).is_ignore())
}

///|
test "gitignore/ig12" {
  let gi = gi_from_str(ROOT, "**/foo/**")
  assert_true(gi.matched("wat/src/foo/bar/baz", false).is_ignore())
}

///|
test "gitignore/ig13" {
  let gi = gi_from_str(ROOT, "**/foo/bar")
  assert_true(gi.matched("foo/bar", false).is_ignore())
}

///|
test "gitignore/ig14" {
  let gi = gi_from_str(ROOT, "**/foo/bar")
  assert_true(gi.matched("src/foo/bar", false).is_ignore())
}

///|
test "gitignore/ig15" {
  let gi = gi_from_str(ROOT, "abc/**")
  assert_true(gi.matched("abc/x", false).is_ignore())
}

///|
test "gitignore/ig16" {
  let gi = gi_from_str(ROOT, "abc/**")
  assert_true(gi.matched("abc/x/y", false).is_ignore())
}

///|
test "gitignore/ig17" {
  let gi = gi_from_str(ROOT, "abc/**")
  assert_true(gi.matched("abc/x/y/z", false).is_ignore())
}

///|
test "gitignore/ig18" {
  let gi = gi_from_str(ROOT, "a/**/b")
  assert_true(gi.matched("a/b", false).is_ignore())
}

///|
test "gitignore/ig19" {
  let gi = gi_from_str(ROOT, "a/**/b")
  assert_true(gi.matched("a/x/b", false).is_ignore())
}

///|
test "gitignore/ig20" {
  let gi = gi_from_str(ROOT, "a/**/b")
  assert_true(gi.matched("a/x/y/b", false).is_ignore())
}

///|
test "gitignore/ig21" {
  let gi = gi_from_str(ROOT, "\\!xy")
  assert_true(gi.matched("!xy", false).is_ignore())
}

///|
test "gitignore/ig22" {
  let gi = gi_from_str(ROOT, "\\#foo")
  assert_true(gi.matched("#foo", false).is_ignore())
}

///|
test "gitignore/ig23" {
  let gi = gi_from_str(ROOT, "foo")
  assert_true(gi.matched("./foo", false).is_ignore())
}

///|
test "gitignore/ig24" {
  let gi = gi_from_str(ROOT, "target")
  assert_true(gi.matched("grep/target", false).is_ignore())
}

///|
test "gitignore/ig25" {
  let gi = gi_from_str(ROOT, "Cargo.lock")
  assert_true(gi.matched("./tabwriter-bin/Cargo.lock", false).is_ignore())
}

///|
test "gitignore/ig26" {
  let gi = gi_from_str(ROOT, "/foo/bar/baz")
  assert_true(gi.matched("./foo/bar/baz", false).is_ignore())
}

///|
test "gitignore/ig27" {
  let gi = gi_from_str(ROOT, "foo/")
  assert_true(gi.matched("xyz/foo", true).is_ignore())
}

///|
test "gitignore/ig28" {
  let gi = gi_from_str("./src", "/llvm/")
  assert_true(gi.matched("./src/llvm", true).is_ignore())
}

///|
test "gitignore/ig29" {
  let gi = gi_from_str(ROOT, "node_modules/ ")
  assert_true(gi.matched("node_modules", true).is_ignore())
}

///|
test "gitignore/ig30" {
  let gi = gi_from_str(ROOT, "**/")
  assert_true(gi.matched("foo/bar", true).is_ignore())
}

///|
test "gitignore/ig31" {
  let gi = gi_from_str(ROOT, "path1/*")
  assert_true(gi.matched("path1/foo", false).is_ignore())
}

///|
test "gitignore/ig32" {
  let gi = gi_from_str(ROOT, ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig33" {
  let gi = gi_from_str("./", ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig34" {
  let gi = gi_from_str(".", ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig35" {
  let gi = gi_from_str("./.", ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig36" {
  let gi = gi_from_str("././", ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig37" {
  let gi = gi_from_str("././.", ".a/b")
  assert_true(gi.matched(".a/b", false).is_ignore())
}

///|
test "gitignore/ig38" {
  let gi = gi_from_str(ROOT, "\\[")
  assert_true(gi.matched("[", false).is_ignore())
}

///|
test "gitignore/ig39" {
  let gi = gi_from_str(ROOT, "\\?")
  assert_true(gi.matched("?", false).is_ignore())
}

///|
test "gitignore/ig40" {
  let gi = gi_from_str(ROOT, "\\*")
  assert_true(gi.matched("*", false).is_ignore())
}

///|
test "gitignore/ig41" {
  let gi = gi_from_str(ROOT, "\\a")
  assert_true(gi.matched("a", false).is_ignore())
}

///|
test "gitignore/ig42" {
  let gi = gi_from_str(ROOT, "s*.rs")
  assert_true(gi.matched("sfoo.rs", false).is_ignore())
}

///|
test "gitignore/ig43" {
  let gi = gi_from_str(ROOT, "**")
  assert_true(gi.matched("foo.rs", false).is_ignore())
}

///|
test "gitignore/ig44" {
  let gi = gi_from_str(ROOT, "**/**/*")
  assert_true(gi.matched("a/foo.rs", false).is_ignore())
}

///|
test "gitignore/ignot1" {
  let gi = gi_from_str(ROOT, "amonths")
  assert_true(!gi.matched("months", false).is_ignore())
}

///|
test "gitignore/ignot2" {
  let gi = gi_from_str(ROOT, "monthsa")
  assert_true(!gi.matched("months", false).is_ignore())
}

///|
test "gitignore/ignot3" {
  let gi = gi_from_str(ROOT, "/src/*.rs")
  assert_true(!gi.matched("src/grep/src/main.rs", false).is_ignore())
}

///|
test "gitignore/ignot4" {
  let gi = gi_from_str(ROOT, "/*.c")
  assert_true(!gi.matched("mozilla-sha1/sha1.c", false).is_ignore())
}

///|
test "gitignore/ignot5" {
  let gi = gi_from_str(ROOT, "/src/*.rs")
  assert_true(!gi.matched("src/grep/src/main.rs", false).is_ignore())
}

///|
test "gitignore/ignot6" {
  let gi = gi_from_str(ROOT, "*.rs\n!src/main.rs")
  assert_true(!gi.matched("src/main.rs", false).is_ignore())
}

///|
test "gitignore/ignot7" {
  let gi = gi_from_str(ROOT, "foo/")
  assert_true(!gi.matched("foo", false).is_ignore())
}

///|
test "gitignore/ignot8" {
  let gi = gi_from_str(ROOT, "**/foo/**")
  assert_true(!gi.matched("wat/src/afoo/bar/baz", false).is_ignore())
}

///|
test "gitignore/ignot9" {
  let gi = gi_from_str(ROOT, "**/foo/**")
  assert_true(!gi.matched("wat/src/fooa/bar/baz", false).is_ignore())
}

///|
test "gitignore/ignot10" {
  let gi = gi_from_str(ROOT, "**/foo/bar")
  assert_true(!gi.matched("foo/src/bar", false).is_ignore())
}

///|
test "gitignore/ignot11" {
  let gi = gi_from_str(ROOT, "#foo")
  assert_true(!gi.matched("#foo", false).is_ignore())
}

///|
test "gitignore/ignot12" {
  let gi = gi_from_str(ROOT, "\n\n\n")
  assert_true(!gi.matched("foo", false).is_ignore())
}

///|
test "gitignore/ignot13" {
  let gi = gi_from_str(ROOT, "foo/**")
  assert_true(!gi.matched("foo", true).is_ignore())
}

///|
test "gitignore/ignot14" {
  let gi = gi_from_str("./third_party/protobuf", "m4/ltoptions.m4")
  assert_true(
    !gi
    .matched(
      "./third_party/protobuf/csharp/src/packages/repositories.config", false,
    )
    .is_ignore(),
  )
}

///|
test "gitignore/ignot15" {
  let gi = gi_from_str(ROOT, "!/bar")
  assert_true(!gi.matched("foo/bar", false).is_ignore())
}

///|
test "gitignore/ignot16" {
  let gi = gi_from_str(ROOT, "*\n!**/")
  assert_true(!gi.matched("foo", true).is_ignore())
}

///|
test "gitignore/ignot17" {
  let gi = gi_from_str(ROOT, "src/*.rs")
  assert_true(!gi.matched("src/grep/src/main.rs", false).is_ignore())
}

///|
test "gitignore/ignot18" {
  let gi = gi_from_str(ROOT, "path1/*")
  assert_true(!gi.matched("path2/path1/foo", false).is_ignore())
}

///|
test "gitignore/ignot19" {
  let gi = gi_from_str(ROOT, "s*.rs")
  assert_true(!gi.matched("src/foo.rs", false).is_ignore())
}

///|
test "gitignore/cs1" {
  let gi = gi_from_str(ROOT, "*.html")
  assert_true(gi.matched("foo.html", false).is_ignore())
}

///|
test "gitignore/cs2" {
  let gi = gi_from_str(ROOT, "*.html")
  assert_true(!gi.matched("foo.HTML", false).is_ignore())
}

///|
test "gitignore/cs3" {
  let gi = gi_from_str(ROOT, "*.html")
  assert_true(!gi.matched("foo.htm", false).is_ignore())
}

///|
test "gitignore/cs4" {
  let gi = gi_from_str(ROOT, "*.html")
  assert_true(!gi.matched("foo.HTM", false).is_ignore())
}

///|
test "gitignore/parse_excludes_file1" {
  let data = b"[core]\nexcludesFile = /foo/bar"
  let got = parse_excludes_file(data).unwrap()
  assert_eq(got, "/foo/bar")
}

///|
test "gitignore/parse_excludes_file2" {
  let data = b"[core]\nexcludesFile = ~/foo/bar"
  let got = parse_excludes_file(data).unwrap()
  assert_eq(got, expand_tilde("~/foo/bar"))
}

///|
test "gitignore/parse_excludes_file3" {
  let data = b"[core]\nexcludeFile = /foo/bar"
  assert_true(parse_excludes_file(data) is None)
}

///|
test "gitignore/parse_excludes_file4" {
  let data = b"[core]\nexcludesFile = \"~/foo/bar\""
  let got = parse_excludes_file(data)
  assert_eq(got.unwrap(), expand_tilde("~/foo/bar"))
}

///|
test "gitignore/parse_excludes_file5" {
  let data = b"[core]\nexcludesFile = \" \"~/foo/bar \" \""
  assert_true(parse_excludes_file(data) is None)
}

///|
// See: https://github.com/BurntSushi/ripgrep/issues/106
test "gitignore/regression_106" {
  gi_from_str("/", " ") |> ignore
}

///|
test "gitignore/case_insensitive" {
  let gi = GitignoreBuilder::new(ROOT)
    .case_insensitive(true)
    .add_str(None, "*.html")
    .build()
  assert_true(gi.matched("foo.html", false).is_ignore())
  assert_true(gi.matched("foo.HTML", false).is_ignore())
  assert_true(!gi.matched("foo.htm", false).is_ignore())
  assert_true(!gi.matched("foo.HTM", false).is_ignore())
}
