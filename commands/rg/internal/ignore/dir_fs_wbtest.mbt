// Port of the unit tests in `ignore/src/dir.rs` (native only: they need a
// writable scratch directory with symlinks and file removal).

///|
fn partial(err : IgnoreError) -> Array[IgnoreError] {
  match err {
    Partial(errs) => errs
    _ => abort("expected partial error but got \{err}")
  }
}

///|
async test "dir/explicit_ignore" {
  let td = TempDir::new("dir-explicit_ignore")
  wfile(td.join("not-an-ignore"), "foo\n!bar")
  let (gi, err) = Gitignore::new(td.join("not-an-ignore"))
  assert_true(err is None)
  let (ig, err) = IgnoreBuilder::new()
    .add_ignore(gi)
    .build()
    .add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/git_exclude" {
  let td = TempDir::new("dir-git_exclude")
  mkdirp(td.join(".git/info"))
  wfile(td.join(".git/info/exclude"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/gitignore" {
  let td = TempDir::new("dir-gitignore")
  mkdirp(td.join(".git"))
  wfile(td.join(".gitignore"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/gitignore_with_jj" {
  let td = TempDir::new("dir-gitignore_with_jj")
  mkdirp(td.join(".jj"))
  wfile(td.join(".gitignore"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/gitignore_no_git" {
  let td = TempDir::new("dir-gitignore_no_git")
  wfile(td.join(".gitignore"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_none())
  assert_true(ig.matched("bar", false).is_none())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/gitignore_allowed_no_git" {
  let td = TempDir::new("dir-gitignore_allowed_no_git")
  wfile(td.join(".gitignore"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new()
    .require_git(false)
    .build()
    .add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/ignore" {
  let td = TempDir::new("dir-ignore")
  wfile(td.join(".ignore"), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
async test "dir/custom_ignore" {
  let td = TempDir::new("dir-custom_ignore")
  let custom_ignore = ".customignore"
  wfile(td.join(custom_ignore), "foo\n!bar")
  let (ig, err) = IgnoreBuilder::new()
    .add_custom_ignore_filename(custom_ignore)
    .build()
    .add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_ignore())
  assert_true(ig.matched("bar", false).is_whitelist())
  assert_true(ig.matched("baz", false).is_none())
  td.close()
}

///|
// Tests that a custom ignore file will override an .ignore.
async test "dir/custom_ignore_over_ignore" {
  let td = TempDir::new("dir-custom_ignore_over_ignore")
  let custom_ignore = ".customignore"
  wfile(td.join(".ignore"), "foo")
  wfile(td.join(custom_ignore), "!foo")
  let (ig, err) = IgnoreBuilder::new()
    .add_custom_ignore_filename(custom_ignore)
    .build()
    .add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_whitelist())
  td.close()
}

///|
// Tests that earlier custom ignore files have lower precedence than later.
async test "dir/custom_ignore_precedence" {
  let td = TempDir::new("dir-custom_ignore_precedence")
  let custom_ignore1 = ".customignore1"
  let custom_ignore2 = ".customignore2"
  wfile(td.join(custom_ignore1), "foo")
  wfile(td.join(custom_ignore2), "!foo")
  let (ig, err) = IgnoreBuilder::new()
    .add_custom_ignore_filename(custom_ignore1)
    .add_custom_ignore_filename(custom_ignore2)
    .build()
    .add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_whitelist())
  td.close()
}

///|
// Tests that an .ignore will override a .gitignore.
async test "dir/ignore_over_gitignore" {
  let td = TempDir::new("dir-ignore_over_gitignore")
  wfile(td.join(".gitignore"), "foo")
  wfile(td.join(".ignore"), "!foo")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("foo", false).is_whitelist())
  td.close()
}

///|
// Tests that exclude has lower precedent than both .ignore and .gitignore.
async test "dir/exclude_lowest" {
  let td = TempDir::new("dir-exclude_lowest")
  wfile(td.join(".gitignore"), "!foo")
  wfile(td.join(".ignore"), "!bar")
  mkdirp(td.join(".git/info"))
  wfile(td.join(".git/info/exclude"), "foo\nbar\nbaz")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  assert_true(ig.matched("baz", false).is_ignore())
  assert_true(ig.matched("foo", false).is_whitelist())
  assert_true(ig.matched("bar", false).is_whitelist())
  td.close()
}

///|
async test "dir/errored" {
  let td = TempDir::new("dir-errored")
  wfile(td.join(".gitignore"), "{foo")
  let (_, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is Some(_))
  td.close()
}

///|
async test "dir/errored_both" {
  let td = TempDir::new("dir-errored_both")
  wfile(td.join(".gitignore"), "{foo")
  wfile(td.join(".ignore"), "{bar")
  let (_, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_eq(2, partial(err.unwrap()).length())
  td.close()
}

///|
async test "dir/errored_partial" {
  let td = TempDir::new("dir-errored_partial")
  mkdirp(td.join(".git"))
  wfile(td.join(".gitignore"), "{foo\nbar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is Some(_))
  assert_true(ig.matched("bar", false).is_ignore())
  // Check the rendering of the error.
  let expected = td.join(".gitignore") +
    ": line 1: error parsing glob '{foo': unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)"
  assert_eq(err.unwrap().to_string(), expected)
  td.close()
}

///|
async test "dir/errored_partial_and_ignore" {
  let td = TempDir::new("dir-errored_partial_and_ignore")
  wfile(td.join(".gitignore"), "{foo\nbar")
  wfile(td.join(".ignore"), "!bar")
  let (ig, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is Some(_))
  assert_true(ig.matched("bar", false).is_whitelist())
  td.close()
}

///|
async test "dir/not_present_empty" {
  let td = TempDir::new("dir-not_present_empty")
  let (_, err) = IgnoreBuilder::new().build().add_child(td.path())
  assert_true(err is None)
  td.close()
}

///|
async test "dir/stops_at_git_dir" {
  // This tests that .gitignore files beyond a .git barrier aren't
  // matched, but .ignore files are.
  let td = TempDir::new("dir-stops_at_git_dir")
  mkdirp(td.join(".git"))
  mkdirp(td.join("foo/.git"))
  wfile(td.join(".gitignore"), "foo")
  wfile(td.join(".ignore"), "bar")
  let ig0 = IgnoreBuilder::new().build()
  let (ig1, err) = ig0.add_child(td.path())
  assert_true(err is None)
  let (ig2, err) = ig1.add_child(path_join(ig1.path(), "foo"))
  assert_true(err is None)
  assert_true(ig1.matched("foo", false).is_ignore())
  assert_true(ig2.matched("foo", false).is_none())
  assert_true(ig1.matched("bar", false).is_ignore())
  assert_true(ig2.matched("bar", false).is_ignore())
  td.close()
}

///|
async test "dir/absolute_parent" {
  let td = TempDir::new("dir-absolute_parent")
  mkdirp(td.join(".git"))
  mkdirp(td.join("foo"))
  wfile(td.join(".gitignore"), "bar")
  // First, check that the parent gitignore file isn't detected if the
  // parent isn't added. This establishes a baseline.
  let ig0 = IgnoreBuilder::new().build()
  let (ig1, err) = ig0.add_child(td.join("foo"))
  assert_true(err is None)
  assert_true(ig1.matched("bar", false).is_none())
  // Second, check that adding a parent directory actually works.
  let ig0 = IgnoreBuilder::new().build()
  let (ig1, err) = ig0.add_parents(td.join("foo"))
  assert_true(err is None)
  let (ig2, err) = ig1.add_child(td.join("foo"))
  assert_true(err is None)
  assert_true(ig2.matched("bar", false).is_ignore())
  td.close()
}

///|
async test "dir/absolute_parent_anchored" {
  let td = TempDir::new("dir-absolute_parent_anchored")
  mkdirp(td.join(".git"))
  mkdirp(td.join("src/llvm"))
  wfile(td.join(".gitignore"), "/llvm/\nfoo")
  let ig0 = IgnoreBuilder::new().build()
  let (ig1, err) = ig0.add_parents(td.join("src"))
  assert_true(err is None)
  let (ig2, err) = ig1.add_child("src")
  assert_true(err is None)
  assert_true(ig1.matched("llvm", true).is_none())
  assert_true(ig2.matched("llvm", true).is_none())
  assert_true(ig2.matched("src/llvm", true).is_none())
  assert_true(ig2.matched("foo", false).is_ignore())
  assert_true(ig2.matched("src/foo", false).is_ignore())
  td.close()
}

///|
async test "dir/absolute_parent_matchers_are_cached_across_roots" {
  let td = TempDir::new("dir-absolute_parent_matchers_are_cached")
  mkdirp(td.join(".git"))
  mkdirp(td.join("src/build"))
  mkdirp(td.join("tests/build"))
  wfile(td.join(".gitignore"), "tests/**/build/\n")
  let ig0 = IgnoreBuilder::new().build()
  let (src_parents, err) = ig0.add_parents(td.join("src"))
  assert_true(err is None)
  let (src, err) = src_parents.add_child(td.join("src"))
  assert_true(err is None)
  let (tests_parents, err) = ig0.add_parents(td.join("tests"))
  assert_true(err is None)
  let (tests, err) = tests_parents.add_child(td.join("tests"))
  assert_true(err is None)
  assert_true(physical_equal(src_parents.inner, tests_parents.inner))
  assert_true(src.matched("build", true).is_none())
  assert_true(tests.matched("build", true).is_ignore())
  td.close()
}

///|
/// Returns the path of `td` relative to the current directory, like the
/// CLI walk does for `rg pat src tests`.
fn relative_root(td : TempDir) -> String {
  let cwd = @sys.current_dir().unwrap()
  match path_strip_prefix(td.path(), cwd) {
    Some(p) => p
    None => td.path()
  }
}

///|
/// Parent matchers are shared across search roots, but path rewriting for
/// absolute parents must use each root's own base path.
///
/// Regression for: https://github.com/BurntSushi/ripgrep/issues/3376
/// and https://github.com/BurntSushi/ripgrep/issues/3419
async test "dir/multi_root_gitignore_order_independent" {
  let td = TempDir::new("dir-multi_root_gitignore_order_independent")
  // Use paths relative to CWD like the CLI walk does for `rg pat src tests`.
  let root = relative_root(td)
  let src_root = path_join(root, "src")
  let tests_root = path_join(root, "tests")
  mkdirp(td.join(".git"))
  mkdirp(td.join("src"))
  mkdirp(td.join("tests"))
  wfile(td.join(".gitignore"), "src/invalid\n")
  wfile(td.join("src/invalid"), "x")
  wfile(td.join("src/valid"), "x")
  wfile(td.join("tests/valid"), "x")
  let ig0 = IgnoreBuilder::new().build()
  // Historically buggy order: search `src` first, then `tests`.
  let (src_parents, err) = ig0.add_parents(src_root)
  assert_true(err is None)
  let (src, err) = src_parents.add_child(src_root)
  assert_true(err is None)
  let (tests_parents, err) = ig0.add_parents(tests_root)
  assert_true(err is None)
  let (tests, err) = tests_parents.add_child(tests_root)
  assert_true(err is None)
  assert_true(physical_equal(src_parents.inner, tests_parents.inner))
  // Each root must carry its own absolute_base even though inners are
  // shared.
  assert_true(src.absolute_base.unwrap() != tests.absolute_base.unwrap())
  assert_true(
    src.matched(path_join(src_root, "invalid"), false).is_ignore(),
    msg="parent .gitignore must apply for the src root even when another root was prepared in the same process",
  )
  assert_true(src.matched(path_join(src_root, "valid"), false).is_none())
  assert_true(tests.matched(path_join(tests_root, "valid"), false).is_none())
  // Reverse order should behave the same way.
  let ig0 = IgnoreBuilder::new().build()
  let (tests_parents, err) = ig0.add_parents(tests_root)
  assert_true(err is None)
  let (tests, err) = tests_parents.add_child(tests_root)
  assert_true(err is None)
  let (src_parents, err) = ig0.add_parents(src_root)
  assert_true(err is None)
  let (src, err) = src_parents.add_child(src_root)
  assert_true(err is None)
  assert_true(src.matched(path_join(src_root, "invalid"), false).is_ignore())
  assert_true(src.matched(path_join(src_root, "valid"), false).is_none())
  assert_true(tests.matched(path_join(tests_root, "valid"), false).is_none())
  td.close()
}

///|
/// Same multi-root / order issue for non-git ignore files (e.g. `.rgignore`
/// via custom ignore names).
///
/// Regression for: https://github.com/BurntSushi/ripgrep/issues/3320
async test "dir/multi_root_custom_ignore_order_independent" {
  let td = TempDir::new("dir-multi_root_custom_ignore_order_independent")
  let root = relative_root(td)
  let alpha_root = path_join(root, "alpha")
  let beta_root = path_join(root, "beta")
  mkdirp(td.join("alpha"))
  mkdirp(td.join("beta"))
  wfile(td.join(".rgignore"), "beta/**/*.svg\n")
  wfile(td.join("alpha/a.txt"), "x")
  wfile(td.join("beta/x.svg"), "x")
  let ig0 = IgnoreBuilder::new()
    .add_custom_ignore_filename(".rgignore")
    .ignore(false)
    .git_ignore(false)
    .git_global(false)
    .git_exclude(false)
    .build()
  let (alpha_parents, err) = ig0.add_parents(alpha_root)
  assert_true(err is None)
  let (alpha, err) = alpha_parents.add_child(alpha_root)
  assert_true(err is None)
  let (beta_parents, err) = ig0.add_parents(beta_root)
  assert_true(err is None)
  let (beta, err) = beta_parents.add_child(beta_root)
  assert_true(err is None)
  assert_true(alpha.absolute_base.unwrap() != beta.absolute_base.unwrap())
  assert_true(alpha.matched(path_join(alpha_root, "a.txt"), false).is_none())
  assert_true(
    beta.matched(path_join(beta_root, "x.svg"), false).is_ignore(),
    msg="parent .rgignore must apply for the beta root regardless of which root was set up first",
  )
  td.close()
}

///|
async test "dir/git_info_exclude_in_linked_worktree" {
  let td = TempDir::new("dir-git_info_exclude_in_linked_worktree")
  let git_dir = td.join(".git")
  mkdirp(path_join(git_dir, "info"))
  wfile(path_join(git_dir, "info/exclude"), "ignore_me")
  mkdirp(path_join(git_dir, "worktrees/linked-worktree"))
  let commondir_path = path_join(git_dir, "worktrees/linked-worktree/commondir")
  mkdirp(td.join("linked-worktree"))
  let worktree_git_dir_abs = "gitdir: " +
    path_join(git_dir, "worktrees/linked-worktree")
  wfile(td.join("linked-worktree/.git"), worktree_git_dir_abs)
  // relative commondir
  wfile(commondir_path, "../..")
  let ib = IgnoreBuilder::new().build()
  let (ignore, err) = ib.add_child(td.join("linked-worktree"))
  assert_true(err is None)
  assert_true(ignore.matched("ignore_me", false).is_ignore())
  // absolute commondir
  wfile(commondir_path, git_dir)
  let (ignore, err) = ib.add_child(td.join("linked-worktree"))
  assert_true(err is None)
  assert_true(ignore.matched("ignore_me", false).is_ignore())
  // missing commondir file
  @sys.remove_file(commondir_path)
  let (_, err) = ib.add_child(td.join("linked-worktree"))
  // We squash the error in this case, because it occurs in repositories
  // that are not linked worktrees but have submodules.
  assert_true(err is None)
  wfile(td.join("linked-worktree/.git"), "garbage")
  let (_, err) = ib.add_child(td.join("linked-worktree"))
  assert_true(err is None)
  wfile(td.join("linked-worktree/.git"), "gitdir: garbage")
  let (_, err) = ib.add_child(td.join("linked-worktree"))
  assert_true(err is None)
  td.close()
}

///|
async test "dir/canonicalize" {
  let td = TempDir::new("dir-canonicalize")
  mkdirp(td.join("a/b"))
  symlink(td.join("a/b"), td.join("link"))
  symlink("a", td.join("rel"))
  let real = canonicalize(td.path())
  assert_eq(canonicalize(td.join("link")), path_join(real, "a/b"))
  assert_eq(canonicalize(td.join("rel/b/..")), path_join(real, "a"))
  assert_eq(canonicalize(td.join("a/./b/../b")), path_join(real, "a/b"))
  try canonicalize(td.join("missing")) catch {
    _ => ()
  } noraise {
    _ => fail("expected an error")
  }
  td.close()
}
