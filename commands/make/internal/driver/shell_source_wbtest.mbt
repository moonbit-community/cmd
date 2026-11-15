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
