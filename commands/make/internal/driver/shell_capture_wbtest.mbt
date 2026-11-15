///|
async test "shell syntax errors become status two without executing an invalid line" {
  for script in ["if", "printf prefix; if", "printf prefix; then"] {
    let error : ShellCapture = { bytes: [], }
    let (status, output) = capture_shell(script, {}, ".", error~)
    assert_eq(status, 2)
    assert_eq(output, "")
    assert_true(
      @utf8.decode(Bytes::from_array(error.bytes)).contains("unexpected"),
    )
  }
}

///|
async test "shell runtime errors keep prior output and do not poison later expansion" {
  for
    script in [
      "printf prefix; : $((1/0))", "printf prefix; set -u; printf \"$QA31_UNSET\"",
      "printf prefix; test bad -eq 1",
    ] {
    let error : ShellCapture = { bytes: [], }
    let (status, output) = capture_shell(script, {}, ".", error~)
    assert_eq(status, 2)
    assert_eq(output, "prefix")
    assert_false(error.bytes.is_empty())
    let (status, output) = capture_shell("printf recovered; exit 7", {}, ".")
    assert_eq(status, 7)
    assert_eq(output, "recovered")
  }
}

///|
async test "shell output ends at its first NUL before UTF8 decoding" {
  for script in ["printf 'a\\000b'; exit 7", "printf 'a\\000\\377'; exit 7"] {
    let (status, output) = capture_shell(script, {}, ".")
    assert_eq(status, 7)
    assert_eq(output, "a")
  }
  try capture_shell("printf '\\377\\000'", {}, ".") catch {
    MakeError(message) =>
      assert_eq(message, "shell output before its first NUL is not valid UTF-8")
    error => raise error
  } noraise {
    _ => fail("invalid UTF8 before NUL was accepted")
  }
}
