// Port of the unit tests in `ignore/src/walk.rs` (native only: they need a
// writable scratch directory with symlinks and file removal).

///|
fn sorted(paths : Array[String]) -> Array[String] {
  let paths = paths.copy()
  paths.sort_by(compare_utf8)
  paths
}

///|
fn rel(prefix : String, path : String) -> String {
  match path_strip_prefix(path, prefix) {
    Some(p) => p
    None => abort("\{path} is not under \{prefix}")
  }
}

///|
async fn walk_collect(prefix : String, builder : WalkBuilder) -> Array[String] {
  let paths = []
  for result in builder.build().iter() {
    let dent = match result {
      Err(_) => continue
      Ok(dent) => dent
    }
    let path = rel(prefix, dent.path())
    if path == "" {
      continue
    }
    paths.push(path)
  }
  sorted(paths)
}

///|
async fn walk_collect_entries_parallel(
  builder : WalkBuilder,
) -> Array[DirEntry] {
  let dents = []
  builder
  .build_parallel()
  .run(() => {
    result => {
      if result is Ok(dent) {
        dents.push(dent)
      }
      Continue
    }
  })
  dents
}

///|
async fn walk_collect_parallel(
  prefix : String,
  builder : WalkBuilder,
) -> Array[String] {
  let paths = []
  for dent in walk_collect_entries_parallel(builder) {
    let path = rel(prefix, dent.path())
    if path == "" {
      continue
    }
    paths.push(path)
  }
  sorted(paths)
}

///|
async fn assert_paths(
  prefix : String,
  builder : WalkBuilder,
  expected : Array[String],
) -> Unit {
  let got = walk_collect(prefix, builder)
  assert_eq(got, sorted(expected), msg="single threaded")
  let got = walk_collect_parallel(prefix, builder)
  assert_eq(got, sorted(expected), msg="parallel")
}

///|
async test "walk/no_ignores" {
  let td = TempDir::new("walk-no_ignores")
  mkdirp(td.join("a/b/c"))
  mkdirp(td.join("x/y"))
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("x/y/foo"), "")
  assert_paths(td.path(), WalkBuilder::new(td.path()), [
    "x", "x/y", "x/y/foo", "a", "a/b", "a/b/foo", "a/b/c",
  ])
  td.close()
}

///|
async test "walk/custom_ignore" {
  let td = TempDir::new("walk-custom_ignore")
  let custom_ignore = ".customignore"
  mkdirp(td.join("a"))
  wfile(td.join(custom_ignore), "foo")
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("bar"), "")
  wfile(td.join("a/bar"), "")
  let builder = WalkBuilder::new(td.path())
  builder.add_custom_ignore_filename(custom_ignore) |> ignore
  assert_paths(td.path(), builder, ["bar", "a", "a/bar"])
  td.close()
}

///|
async test "walk/custom_ignore_exclusive_use" {
  let td = TempDir::new("walk-custom_ignore_exclusive_use")
  let custom_ignore = ".customignore"
  mkdirp(td.join("a"))
  wfile(td.join(custom_ignore), "foo")
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("bar"), "")
  wfile(td.join("a/bar"), "")
  let builder = WalkBuilder::new(td.path())
  builder.ignore(false) |> ignore
  builder.git_ignore(false) |> ignore
  builder.git_global(false) |> ignore
  builder.git_exclude(false) |> ignore
  builder.add_custom_ignore_filename(custom_ignore) |> ignore
  assert_paths(td.path(), builder, ["bar", "a", "a/bar"])
  td.close()
}

///|
async test "walk/gitignore" {
  let td = TempDir::new("walk-gitignore")
  mkdirp(td.join(".git"))
  mkdirp(td.join("a"))
  wfile(td.join(".gitignore"), "foo")
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("bar"), "")
  wfile(td.join("a/bar"), "")
  assert_paths(td.path(), WalkBuilder::new(td.path()), ["bar", "a", "a/bar"])
  td.close()
}

///|
async test "walk/explicit_ignore" {
  let td = TempDir::new("walk-explicit_ignore")
  let igpath = td.join(".not-an-ignore")
  mkdirp(td.join("a"))
  wfile(igpath, "foo")
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("bar"), "")
  wfile(td.join("a/bar"), "")
  let builder = WalkBuilder::new(td.path())
  assert_true(builder.add_ignore(igpath) is None)
  assert_paths(td.path(), builder, ["bar", "a", "a/bar"])
  td.close()
}

///|
async test "walk/explicit_ignore_exclusive_use" {
  let td = TempDir::new("walk-explicit_ignore_exclusive_use")
  let igpath = td.join(".not-an-ignore")
  mkdirp(td.join("a"))
  wfile(igpath, "foo")
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("bar"), "")
  wfile(td.join("a/bar"), "")
  let builder = WalkBuilder::new(td.path())
  builder.standard_filters(false) |> ignore
  assert_true(builder.add_ignore(igpath) is None)
  assert_paths(td.path(), builder, [".not-an-ignore", "bar", "a", "a/bar"])
  td.close()
}

///|
async test "walk/gitignore_parent" {
  let td = TempDir::new("walk-gitignore_parent")
  mkdirp(td.join(".git"))
  mkdirp(td.join("a"))
  wfile(td.join(".gitignore"), "foo")
  wfile(td.join("a/foo"), "")
  wfile(td.join("a/bar"), "")
  let root = td.join("a")
  assert_paths(root, WalkBuilder::new(root), ["bar"])
  td.close()
}

///|
async test "walk/max_depth" {
  let td = TempDir::new("walk-max_depth")
  mkdirp(td.join("a/b/c"))
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("a/b/c/foo"), "")
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder, [
    "a", "a/b", "a/b/c", "foo", "a/foo", "a/b/foo", "a/b/c/foo",
  ])
  assert_paths(td.path(), builder.max_depth(Some(0)), [])
  assert_paths(td.path(), builder.max_depth(Some(1)), ["a", "foo"])
  assert_paths(td.path(), builder.max_depth(Some(2)), [
    "a", "a/b", "foo", "a/foo",
  ])
  td.close()
}

///|
async test "walk/max_depth_does_not_load_unreachable_ignore_files" {
  let td = TempDir::new("walk-max_depth_does_not_load_unreachable")
  let leaf = td.join("leaf")
  mkdirp(leaf)
  wfile(path_join(leaf, ".ignore"), "{invalid\n")
  let builder = WalkBuilder::new(td.path())
  builder.max_depth(Some(1)) |> ignore
  let mut entry : DirEntry? = None
  for result in builder.build().iter() {
    let e = result.unwrap()
    if e.path() == leaf {
      entry = Some(e)
      break
    }
  }
  assert_true(entry.unwrap().error() is None)
  assert_paths(td.path(), builder, ["leaf"])
  td.close()
}

///|
async test "walk/min_depth" {
  let td = TempDir::new("walk-min_depth")
  mkdirp(td.join("a/b/c"))
  wfile(td.join("foo"), "")
  wfile(td.join("a/foo"), "")
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("a/b/c/foo"), "")
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder, [
    "a", "a/b", "a/b/c", "foo", "a/foo", "a/b/foo", "a/b/c/foo",
  ])
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder.min_depth(Some(0)), [
    "a", "a/b", "a/b/c", "foo", "a/foo", "a/b/foo", "a/b/c/foo",
  ])
  assert_paths(td.path(), builder.min_depth(Some(1)), [
    "a", "a/b", "a/b/c", "foo", "a/foo", "a/b/foo", "a/b/c/foo",
  ])
  assert_paths(td.path(), builder.min_depth(Some(2)), [
    "a/b", "a/b/c", "a/b/c/foo", "a/b/foo", "a/foo",
  ])
  assert_paths(td.path(), builder.min_depth(Some(3)), [
    "a/b/c", "a/b/c/foo", "a/b/foo",
  ])
  assert_paths(td.path(), builder.min_depth(Some(10)), [])
  assert_paths(td.path(), builder.min_depth(Some(2)).max_depth(Some(1)), [
    "a/b", "a/foo",
  ])
  td.close()
}

///|
async test "walk/max_filesize" {
  let td = TempDir::new("walk-max_filesize")
  mkdirp(td.join("a/b"))
  wfile_size(td.join("foo"), 0)
  wfile_size(td.join("bar"), 400)
  wfile_size(td.join("baz"), 600)
  wfile_size(td.join("a/foo"), 600)
  wfile_size(td.join("a/bar"), 500)
  wfile_size(td.join("a/baz"), 200)
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder, [
    "a", "a/b", "foo", "bar", "baz", "a/foo", "a/bar", "a/baz",
  ])
  assert_paths(td.path(), builder.max_filesize(Some(0)), ["a", "a/b", "foo"])
  assert_paths(td.path(), builder.max_filesize(Some(500)), [
    "a", "a/b", "foo", "bar", "a/bar", "a/baz",
  ])
  assert_paths(td.path(), builder.max_filesize(Some(50000)), [
    "a", "a/b", "foo", "bar", "baz", "a/foo", "a/bar", "a/baz",
  ])
  td.close()
}

///|
async test "walk/symlinks" {
  let td = TempDir::new("walk-symlinks")
  mkdirp(td.join("a/b"))
  symlink(td.join("a/b"), td.join("z"))
  wfile(td.join("a/b/foo"), "")
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder, ["a", "a/b", "a/b/foo", "z"])
  assert_paths(td.path(), builder.follow_links(true), [
    "a", "a/b", "a/b/foo", "z", "z/foo",
  ])
  td.close()
}

///|
async test "walk/first_path_not_symlink" {
  let td = TempDir::new("walk-first_path_not_symlink")
  mkdirp(td.join("foo"))
  let dents = []
  for r in WalkBuilder::new(td.join("foo")).build().iter() {
    dents.push(r.unwrap())
  }
  assert_eq(1, dents.length())
  assert_true(!dents[0].path_is_symlink())
  let dents = walk_collect_entries_parallel(WalkBuilder::new(td.join("foo")))
  assert_eq(1, dents.length())
  assert_true(!dents[0].path_is_symlink())
  td.close()
}

///|
async test "walk/symlink_loop" {
  let td = TempDir::new("walk-symlink_loop")
  mkdirp(td.join("a/b"))
  symlink(td.join("a"), td.join("a/b/c"))
  let builder = WalkBuilder::new(td.path())
  assert_paths(td.path(), builder, ["a", "a/b", "a/b/c"])
  assert_paths(td.path(), builder.follow_links(true), ["a", "a/b"])
  // Check the errors reported for the loop.
  let errs = []
  for r in builder.build().iter() {
    if r is Err(e) {
      errs.push(e.to_string())
    }
  }
  assert_eq(errs, [
    "File system loop found: \{td.join("a/b/c")} points to an ancestor \{td.join("a")}",
  ])
  let errs = []
  builder
  .build_parallel()
  .run(() => {
    r => {
      if r is Err(e) {
        errs.push(e.to_string())
      }
      Continue
    }
  })
  assert_eq(errs, [
    "File system loop found: \{td.join("a/b/c")} points to an ancestor \{td.join("a")}",
  ])
  td.close()
}

///|
async test "walk/filter" {
  let td = TempDir::new("walk-filter")
  mkdirp(td.join("a/b/c"))
  mkdirp(td.join("x/y"))
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("x/y/foo"), "")
  assert_paths(td.path(), WalkBuilder::new(td.path()), [
    "x", "x/y", "x/y/foo", "a", "a/b", "a/b/foo", "a/b/c",
  ])
  assert_paths(
    td.path(),
    WalkBuilder::new(td.path()).filter_entry(entry => entry.file_name() != "a"),
    ["x", "x/y", "x/y/foo"],
  )
  td.close()
}

///|
async test "walk/empty" {
  let td = TempDir::new("walk-empty")
  assert_paths(td.path(), WalkBuilder::empty(), [])
  let empty_paths : Array[String] = []
  assert_paths(td.path(), WalkBuilder::from_iter(empty_paths), [])
  td.close()
}

///|
async test "walk/from_iter" {
  let td = TempDir::new("walk-from_iter")
  mkdirp(td.join("a/b/c"))
  mkdirp(td.join("d/e/f"))
  mkdirp(td.join("x/y"))
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("d/e/f/foo"), "")
  wfile(td.join("x/y/foo"), "")
  let paths = [td.join("a"), td.join("d"), td.join("x")]
  assert_paths(td.path(), WalkBuilder::from_iter(paths), [
    "x", "x/y", "x/y/foo", "d", "d/e", "d/e/f", "d/e/f/foo", "a", "a/b", "a/b/foo",
    "a/b/c",
  ])
  td.close()
}

///|
// This should always panic and never hang.
//
// Ref: https://github.com/BurntSushi/ripgrep/issues/3009
test "panic walk/panic_in_parallel" {
  let visit = (_ : Result[DirEntry, IgnoreError]) => abort("oops!")
  visit(Ok(DirEntry::new_stdin()))
}

///|
async test "walk/visitor panic terminates child without hanging" {
  let td = TempDir::new("walk-panic_in_parallel")
  wfile(td.join("foo.txt"), "")
  defer td.close()
  let result = @shell.Cmd("moon", [
    "run",
    @sys.current_dir().unwrap() + "/internal/ignore/internal/panic_probe",
    "--target-dir",
    td.join("probe-build"),
    "--",
    "visitor",
    td.path(),
  ]).output(timeout_ms=15000)
  assert_true(
    result.exit_code() != 0,
    msg="visitor panic must terminate the child",
  )
  assert_true(result.stdout().contains("reached visitor panic"))
}

///|
// This should always panic and never hang. The first call to the visitor
// builder is used while processing the root paths.
test "panic walk/panic_in_parallel_builder" {
  let mut builds = 0
  let build = () => {
    builds += 1
    if builds == 3 {
      abort("builder panic")
    }
  }
  for _ in 0..<3 {
    build()
  }
}

///|
async test "walk/builder panic terminates child without hanging" {
  let td = TempDir::new("walk-panic_in_parallel_builder")
  wfile(td.join("foo.txt"), "")
  defer td.close()
  let result = @shell.Cmd("moon", [
    "run",
    @sys.current_dir().unwrap() + "/internal/ignore/internal/panic_probe",
    "--target-dir",
    td.join("probe-build"),
    "--",
    "builder",
    td.path(),
  ]).output(timeout_ms=15000)
  assert_true(
    result.exit_code() != 0,
    msg="builder panic must terminate the child",
  )
  assert_true(result.stdout().contains("reached builder panic"))
}

// Additional tests specific to this port.

///|
async test "walk/sort_by_file_name" {
  let td = TempDir::new("walk-sort_by_file_name")
  mkdirp(td.join("b/z"))
  mkdirp(td.join("C"))
  wfile(td.join("a"), "")
  wfile(td.join("aa"), "")
  wfile(td.join("Z"), "")
  wfile(td.join("b/y"), "")
  wfile(td.join("b/z/x"), "")
  wfile(td.join("\u{e9}"), "")
  let builder = WalkBuilder::new(td.path()).sort_by_file_name(compare_utf8)
  let got = []
  for r in builder.build().iter() {
    got.push(rel(td.path(), r.unwrap().path()))
  }
  debug_inspect(
    got,
    content=(
      #|["", "C", "Z", "a", "aa", "b", "b/y", "b/z", "b/z/x", "é"]
    ),
  )
  // Sorting by path (reversed).
  let builder = WalkBuilder::new(td.path()).sort_by_file_path((a, b) => {
    compare_utf8(b, a)
  })
  let got = []
  for r in builder.build().iter() {
    got.push(rel(td.path(), r.unwrap().path()))
  }
  debug_inspect(
    got,
    content=(
      #|["", "é", "b", "b/z", "b/z/x", "b/y", "aa", "a", "Z", "C"]
    ),
  )
  td.close()
}

///|
async test "walk/errors" {
  let td = TempDir::new("walk-errors")
  let missing = td.join("missing")
  let errs = []
  for r in WalkBuilder::new(missing).build().iter() {
    if r is Err(e) {
      errs.push(e.to_string())
      assert_true(e.is_io())
      debug_inspect(e.depth(), content="Some(0)")
    }
  }
  assert_eq(errs.length(), 1)
  assert_true(errs[0].contains(missing))
  assert_true(errs[0].contains("No such file or directory"))
  let errs = []
  WalkBuilder::new(missing)
  .build_parallel()
  .run(() => {
    r => {
      if r is Err(e) {
        errs.push(e.to_string())
      }
      Continue
    }
  })
  assert_eq(errs.length(), 1)
  assert_true(errs[0].contains(missing))
  assert_true(errs[0].contains("No such file or directory"))
  td.close()
}

///|
async test "walk/ignore file errors are attached to entries" {
  let td = TempDir::new("walk-ignore_file_errors")
  mkdirp(td.join("a"))
  wfile(td.join("a/.ignore"), "{foo\nbar\n")
  wfile(td.join("a/bar"), "")
  wfile(td.join("a/baz"), "")
  let builder = WalkBuilder::new(td.path())
  let errs = []
  for r in builder.build().iter() {
    let dent = r.unwrap()
    if dent.error() is Some(e) {
      errs.push((rel(td.path(), dent.path()), e.to_string()))
    }
  }
  let expected = [
    (
      "a",
      td.join("a/.ignore") +
      ": line 1: error parsing glob '{foo': unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)",
    ),
  ]
  assert_eq(errs, expected)
  assert_paths(td.path(), builder, ["a", "a/baz"])
  td.close()
}

///|
async test "walk/parallel quit and skip" {
  let td = TempDir::new("walk-parallel_quit_skip")
  mkdirp(td.join("a/b"))
  mkdirp(td.join("c"))
  wfile(td.join("a/b/foo"), "")
  wfile(td.join("c/foo"), "")
  // Skip: don't descend into `a`.
  let got = []
  WalkBuilder::new(td.path())
  .build_parallel()
  .run(() => {
    r => {
      let dent = r.unwrap()
      let p = rel(td.path(), dent.path())
      got.push(p)
      if p == "a" {
        Skip
      } else {
        Continue
      }
    }
  })
  debug_inspect(
    sorted(got),
    content=(
      #|["", "a", "c", "c/foo"]
    ),
  )
  // Quit: stop right after the root.
  let got = []
  WalkBuilder::new(td.path())
  .build_parallel()
  .run(() => {
    r => {
      got.push(rel(td.path(), r.unwrap().path()))
      Quit
    }
  })
  debug_inspect(
    got,
    content=(
      #|[""]
    ),
  )
  td.close()
}

///|
async test "walk/stdin and files as roots" {
  let td = TempDir::new("walk-stdin_files")
  wfile(td.join("f"), "")
  let got = []
  for r in WalkBuilder::from_iter(["-", td.join("f")]).build().iter() {
    let dent = r.unwrap()
    got.push((dent.path(), dent.is_stdin(), dent.depth()))
  }
  assert_eq(got, [("<stdin>", true, 0), (td.join("f"), false, 0)])
  td.close()
}
