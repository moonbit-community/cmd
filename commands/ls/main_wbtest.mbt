///|
test "explicit time selection sorts unless an explicit size sort wins" {
  for args in [["-u"], ["-c"], ["--time=access"], ["--time=mtime"]] {
    assert_true(ls_options(parse_arguments(args)).sort == SortByTime)
  }
  for args in [["-Su"], ["-uS"], ["-tS"], ["--time=ctime", "-S"]] {
    assert_true(ls_options(parse_arguments(args)).sort == SortBySize)
  }
  assert_true(ls_options(parse_arguments(["-St"])).sort == SortByTime)
  assert_eq(ls_options(parse_arguments(["-uc"])).time, StatusChangeTime)
  assert_eq(ls_options(parse_arguments(["-cu"])).time, AccessTime)
}

///|
test "link selection and directory classification preserve option precedence" {
  assert_true(
    ls_options(parse_arguments([])).links == FollowCommandLineDirectories,
  )
  for args in [["-d"], ["-F"], ["-R", "-F"], ["-LH", "-P"]] {
    assert_true(ls_options(parse_arguments(args)).links == NeverFollowLinks)
  }
  for args in [["-H"], ["-dFH"], ["-H", "-dF"], ["-LPH"]] {
    assert_true(
      ls_options(parse_arguments(args)).links == FollowCommandLineLinks,
    )
  }
  assert_true(ls_options(parse_arguments(["-PHL"])).links == FollowAllLinks)
  assert_false(ls_options(parse_arguments(["-aA"])).all)
  assert_true(ls_options(parse_arguments(["-Aa"])).all)
}

///|
async test "command-line dereferencing differs from traversal and reports broken links" {
  if @async.platform is Windows {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-ls-links")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let directory = join_path(root, "directory")
  let link = join_path(root, "link")
  let broken = join_path(root, "broken")
  @fs.mkdir(directory)
  @fs.symlink(target=directory, link)
  @fs.symlink(target=join_path(root, "missing"), broken)
  assert_eq(displayed_kind(link, FollowCommandLineLinks, true), Directory)
  assert_eq(displayed_kind(link, FollowCommandLineLinks, false), SymLink)
  assert_eq(displayed_kind(link, FollowAllLinks, false), Directory)
  assert_eq(displayed_kind(link, NeverFollowLinks, true), SymLink)
  assert_eq(displayed_kind(link, FollowCommandLineDirectories, true), Directory)
  assert_eq(displayed_kind(broken, FollowCommandLineDirectories, true), SymLink)
  assert_eq(displayed_kind(broken, NeverFollowLinks, true), SymLink)
  try displayed_kind(broken, FollowCommandLineLinks, true) catch {
    @os_error.OSError(_) as error => assert_true(error.is_ENOENT())
    error => raise error
  } noraise {
    _ => fail("-H must report a dangling command-line link")
  }
  try displayed_kind(broken, FollowAllLinks, false) catch {
    @os_error.OSError(_) as error => assert_true(error.is_ENOENT())
    error => raise error
  } noraise {
    _ => fail("-L must report a dangling directory entry")
  }
}

///|
test "time sorting uses nanoseconds with bytewise ties and reverse order" {
  let newer : LsEntry = {
    name: "z",
    path: "z",
    kind: Some(Regular),
    timestamp: Some({ seconds: 10L, nanoseconds: 2, }),
    size: Some(1L),
  }
  let older : LsEntry = {
    name: "a",
    path: "a",
    kind: Some(Regular),
    timestamp: Some({ seconds: 10L, nanoseconds: 1, }),
    size: Some(1L),
  }
  let options = ls_options(parse_arguments(["-c"]))
  assert_true(compare_entries(newer, older, options) < 0)
  assert_true(
    compare_entries(newer, older, ls_options(parse_arguments(["-cr"]))) > 0,
  )
  assert_true(
    compare_entries(newer, older, ls_options(parse_arguments(["-S"]))) > 0,
  )
}
