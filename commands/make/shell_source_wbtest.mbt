///|
test "GNU direct argv keeps literal linefeeds while shell argv removes them" {
  assert_eq(
    make_shell_source("printf before\nif", ""),
    Some("'printf' 'before\nif'"),
  )
  assert_eq(
    make_shell_source("printf 'before\nafter'", ""),
    Some("'printf' 'before\nafter'"),
  )
  assert_eq(
    make_shell_source("printf \"before\nafter\"", ""),
    Some("printf \"beforeafter\""),
  )
  assert_eq(
    make_shell_source("printf before;\nif", ""),
    Some("printf before;if"),
  )
  assert_eq(
    make_shell_source("printf before # comment\nprintf after", ""),
    Some("printf before # commentprintf after"),
  )
  assert_eq(
    make_shell_source("printf before\nif", ":"),
    Some("printf beforeif"),
  )
  assert_eq(
    make_shell_source("printf before\nif", "", force_shell=true),
    Some("printf beforeif"),
  )
}

///|
test "GNU argv construction preserves quoting empty words and continuations" {
  assert_eq(
    make_shell_fast_arguments("printf '' 'a b' a\\ b\n", " \t\n"),
    Some(["printf", "", "a b", "a b\n"]),
  )
  assert_eq(
    make_shell_fast_arguments("printf before\\\nafter", ""),
    Some(["printf", "beforeafter"]),
  )
  assert_eq(
    make_shell_fast_arguments("printf \\\n \tafter", ""),
    Some(["printf", "after"]),
  )
  assert_eq(
    make_shell_fast_arguments("printf 'before\\\nafter'", ""),
    Some(["printf", "before\\\nafter"]),
  )
  assert_eq(
    make_shell_source("test x = x; \\\n: ", ""),
    Some("test x = x; \\\n: "),
  )
  assert_eq(make_shell_fast_arguments("A=1 printf value\n", ""), None)
  assert_eq(make_shell_source(" \\\n \t", ""), None)
  assert_eq(
    make_shell_fast_arguments("printf ''\\\n after", ""),
    Some(["printf", "after"]),
  )
  assert_eq(make_shell_source(" \t\n", "", force_shell=true), Some(""))
  assert_eq(make_shell_source("\n \t", "", force_shell=true), Some(" \t"))
  assert_eq(make_shell_source(" \t", ":", force_shell=true), None)
}

///|
async test "no-command shell expansions retain status and skip exported side effects" {
  let root = @fs.tmpdir(prefix="make-no-command-")
  defer @fs.rmdir(root, recursive=true)
  let variables : Map[String, Variable] = {
    ".SHELLSTATUS": { value: "7", immediate: true, },
    "EFFECT": { value: "$(shell printf wrong > marker)", immediate: false, },
  }
  let exported = ExportPolicy::new(["EFFECT"])
  for script in ["", " \t", "\\\n", " \t\\\n \t"] {
    assert_eq(
      shell_result(
        script,
        variables,
        {},
        0,
        root,
        exported,
        Expansion::new(original={}),
        trim_newlines=true,
      ),
      "",
    )
    assert_eq(variables[".SHELLSTATUS"].value, "7")
    assert_false(@fs.exists(root + "/marker"))
  }
  variables["SHELL"] = { value: "sh", immediate: true, }
  variables["IFS"] = { value: ":", immediate: true, }
  assert_eq(
    shell_result(
      " \t",
      variables,
      {},
      0,
      root,
      exported,
      Expansion::new(original={}),
      trim_newlines=true,
    ),
    "",
  )
  assert_eq(variables[".SHELLSTATUS"].value, "7")
  assert_false(@fs.exists(root + "/marker"))
}

///|
async test "empty shell calls still validate recursive selector expansion" {
  let variables : Map[String, Variable] = {
    "IFS": { value: "$(BAD)", immediate: false, },
    "BAD": { value: "$(BAD)", immediate: false, },
  }
  try expand("$(shell )", variables, {}, 0) catch {
    MakeError(message) =>
      assert_eq(message, "recursive variable 'BAD' references itself")
    error => raise error
  } noraise {
    _ => fail("an empty script hid a selector expansion failure")
  }
}
