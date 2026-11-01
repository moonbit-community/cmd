// Port of `ignore/tests/gitignore_matched_path_or_any_parents_tests.rs`.

///|
const IGNORE_FILE : String = "../../tests/fixtures/rg/ignore/gitignore_matched_path_or_any_parents_tests.gitignore"

///|
async fn get_gitignore() -> @ignore.Gitignore {
  let builder = @ignore.GitignoreBuilder::new("ROOT")
  let error = builder.add(IGNORE_FILE)
  assert_true(error is None, msg="failed to open gitignore file")
  builder.build()
}

///|
test "panic test_path_should_be_under_root" {
  // Keep this synchronous so the test runner can observe the expected panic.
  let builder = @ignore.GitignoreBuilder::new("ROOT")
  ignore(builder.add_line(Some(IGNORE_FILE), "file_root_00"))
  let gitignore = builder.build()
  let path = "/tmp/some_file"
  gitignore.matched_path_or_any_parents(path, false) |> ignore
}

///|
async test "test_files_in_root" {
  let gitignore = get_gitignore()
  let m = (path : String) => gitignore.matched_path_or_any_parents(path, false)
  //
  // 0x
  assert_true(m("ROOT/file_root_00").is_ignore())
  assert_true(m("ROOT/file_root_01").is_none())
  assert_true(m("ROOT/file_root_02").is_none())
  assert_true(m("ROOT/file_root_03").is_none())
  //
  // 1x
  assert_true(m("ROOT/file_root_10").is_ignore())
  assert_true(m("ROOT/file_root_11").is_none())
  assert_true(m("ROOT/file_root_12").is_none())
  assert_true(m("ROOT/file_root_13").is_none())
  //
  // 2x
  assert_true(m("ROOT/file_root_20").is_none())
  assert_true(m("ROOT/file_root_21").is_none())
  assert_true(m("ROOT/file_root_22").is_none())
  assert_true(m("ROOT/file_root_23").is_none())
  //
  // 3x
  assert_true(m("ROOT/file_root_30").is_ignore())
  assert_true(m("ROOT/file_root_31").is_none())
  assert_true(m("ROOT/file_root_32").is_none())
  assert_true(m("ROOT/file_root_33").is_none())
}

///|
async test "test_files_in_deep" {
  let gitignore = get_gitignore()
  let m = (path : String) => gitignore.matched_path_or_any_parents(path, false)
  //
  // 0x
  assert_true(m("ROOT/parent_dir/file_deep_00").is_ignore())
  assert_true(m("ROOT/parent_dir/file_deep_01").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_02").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_03").is_none())
  //
  // 1x
  assert_true(m("ROOT/parent_dir/file_deep_10").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_11").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_12").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_13").is_none())
  //
  // 2x
  assert_true(m("ROOT/parent_dir/file_deep_20").is_ignore())
  assert_true(m("ROOT/parent_dir/file_deep_21").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_22").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_23").is_none())
  //
  // 3x
  assert_true(m("ROOT/parent_dir/file_deep_30").is_ignore())
  assert_true(m("ROOT/parent_dir/file_deep_31").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_32").is_none())
  assert_true(m("ROOT/parent_dir/file_deep_33").is_none())
}

///|
async test "test_dirs_in_root" {
  let gitignore = get_gitignore()
  let m = (path : String, is_dir : Bool) => {
    gitignore.matched_path_or_any_parents(path, is_dir)
  }
  //
  // 00
  assert_true(m("ROOT/dir_root_00", true).is_ignore())
  assert_true(m("ROOT/dir_root_00/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_00/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_00/child_dir/file", false).is_ignore())
  //
  // 01
  assert_true(m("ROOT/dir_root_01", true).is_ignore())
  assert_true(m("ROOT/dir_root_01/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_01/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_01/child_dir/file", false).is_ignore())
  //
  // 02
  assert_true(m("ROOT/dir_root_02", true).is_none()) // dir itself doesn't match
  assert_true(m("ROOT/dir_root_02/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_02/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_02/child_dir/file", false).is_ignore())
  //
  // 03
  assert_true(m("ROOT/dir_root_03", true).is_none()) // dir itself doesn't match
  assert_true(m("ROOT/dir_root_03/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_03/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_03/child_dir/file", false).is_ignore())
  //
  // 10
  assert_true(m("ROOT/dir_root_10", true).is_ignore())
  assert_true(m("ROOT/dir_root_10/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_10/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_10/child_dir/file", false).is_ignore())
  //
  // 11
  assert_true(m("ROOT/dir_root_11", true).is_ignore())
  assert_true(m("ROOT/dir_root_11/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_11/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_11/child_dir/file", false).is_ignore())
  //
  // 12
  assert_true(m("ROOT/dir_root_12", true).is_none()) // dir itself doesn't match
  assert_true(m("ROOT/dir_root_12/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_12/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_12/child_dir/file", false).is_ignore())
  //
  // 13
  assert_true(m("ROOT/dir_root_13", true).is_none())
  assert_true(m("ROOT/dir_root_13/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_13/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_13/child_dir/file", false).is_ignore())
  //
  // 20
  assert_true(m("ROOT/dir_root_20", true).is_none())
  assert_true(m("ROOT/dir_root_20/file", false).is_none())
  assert_true(m("ROOT/dir_root_20/child_dir", true).is_none())
  assert_true(m("ROOT/dir_root_20/child_dir/file", false).is_none())
  //
  // 21
  assert_true(m("ROOT/dir_root_21", true).is_none())
  assert_true(m("ROOT/dir_root_21/file", false).is_none())
  assert_true(m("ROOT/dir_root_21/child_dir", true).is_none())
  assert_true(m("ROOT/dir_root_21/child_dir/file", false).is_none())
  //
  // 22
  assert_true(m("ROOT/dir_root_22", true).is_none())
  assert_true(m("ROOT/dir_root_22/file", false).is_none())
  assert_true(m("ROOT/dir_root_22/child_dir", true).is_none())
  assert_true(m("ROOT/dir_root_22/child_dir/file", false).is_none())
  //
  // 23
  assert_true(m("ROOT/dir_root_23", true).is_none())
  assert_true(m("ROOT/dir_root_23/file", false).is_none())
  assert_true(m("ROOT/dir_root_23/child_dir", true).is_none())
  assert_true(m("ROOT/dir_root_23/child_dir/file", false).is_none())
  //
  // 30
  assert_true(m("ROOT/dir_root_30", true).is_ignore())
  assert_true(m("ROOT/dir_root_30/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_30/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_30/child_dir/file", false).is_ignore())
  //
  // 31
  assert_true(m("ROOT/dir_root_31", true).is_ignore())
  assert_true(m("ROOT/dir_root_31/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_31/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_31/child_dir/file", false).is_ignore())
  //
  // 32
  assert_true(m("ROOT/dir_root_32", true).is_none()) // dir itself doesn't match
  assert_true(m("ROOT/dir_root_32/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_32/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_32/child_dir/file", false).is_ignore())
  //
  // 33
  assert_true(m("ROOT/dir_root_33", true).is_none()) // dir itself doesn't match
  assert_true(m("ROOT/dir_root_33/file", false).is_ignore())
  assert_true(m("ROOT/dir_root_33/child_dir", true).is_ignore())
  assert_true(m("ROOT/dir_root_33/child_dir/file", false).is_ignore())
}

///|
async test "test_dirs_in_deep" {
  let gitignore = get_gitignore()
  let m = (path : String, is_dir : Bool) => {
    gitignore.matched_path_or_any_parents(path, is_dir)
  }
  //
  // 00
  assert_true(m("ROOT/parent_dir/dir_deep_00", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_00/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_00/child_dir", true).is_ignore())
  //
  // 01
  assert_true(m("ROOT/parent_dir/dir_deep_01", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_01/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_01/child_dir", true).is_ignore())
  //
  // 02
  assert_true(m("ROOT/parent_dir/dir_deep_02", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_02/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_02/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_02/child_dir/file", false).is_none())
  //
  // 03
  assert_true(m("ROOT/parent_dir/dir_deep_03", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_03/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_03/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_03/child_dir/file", false).is_none())
  //
  // 10
  assert_true(m("ROOT/parent_dir/dir_deep_10", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_10/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_10/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_10/child_dir/file", false).is_none())
  //
  // 11
  assert_true(m("ROOT/parent_dir/dir_deep_11", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_11/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_11/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_11/child_dir/file", false).is_none())
  //
  // 12
  assert_true(m("ROOT/parent_dir/dir_deep_12", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_12/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_12/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_12/child_dir/file", false).is_none())
  //
  // 13
  assert_true(m("ROOT/parent_dir/dir_deep_13", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_13/file", false).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_13/child_dir", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_13/child_dir/file", false).is_none())
  //
  // 20
  assert_true(m("ROOT/parent_dir/dir_deep_20", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_20/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_20/child_dir", true).is_ignore())
  //
  // 21
  assert_true(m("ROOT/parent_dir/dir_deep_21", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_21/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_21/child_dir", true).is_ignore())
  //
  // 22
  // dir itself doesn't match
  assert_true(m("ROOT/parent_dir/dir_deep_22", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_22/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_22/child_dir", true).is_ignore())
  //
  // 23
  // dir itself doesn't match
  assert_true(m("ROOT/parent_dir/dir_deep_23", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_23/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_23/child_dir", true).is_ignore())
  //
  // 30
  assert_true(m("ROOT/parent_dir/dir_deep_30", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_30/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_30/child_dir", true).is_ignore())
  //
  // 31
  assert_true(m("ROOT/parent_dir/dir_deep_31", true).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_31/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_31/child_dir", true).is_ignore())
  //
  // 32
  // dir itself doesn't match
  assert_true(m("ROOT/parent_dir/dir_deep_32", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_32/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_32/child_dir", true).is_ignore())
  //
  // 33
  // dir itself doesn't match
  assert_true(m("ROOT/parent_dir/dir_deep_33", true).is_none())
  assert_true(m("ROOT/parent_dir/dir_deep_33/file", false).is_ignore())
  assert_true(m("ROOT/parent_dir/dir_deep_33/child_dir", true).is_ignore())
}

///|
/// Skip a Byte-Order Mark (BOM) at the beginning of the file, matching Git's
/// behavior.
///
/// Ref: <https://github.com/BurntSushi/ripgrep/issues/2177>
async test "gitignore_skip_bom" {
  let builder = @ignore.GitignoreBuilder::new("ROOT")
  let error = builder.add(
    "../../tests/fixtures/rg/ignore/gitignore_skip_bom.gitignore",
  )
  assert_true(error is None, msg="failed to open gitignore file")
  let g = builder.build()
  assert_true(g.matched("ignore/this/path", false).is_ignore())
}
