///|
test "shared-input builtins remain explicit implementation boundaries" {
  for name in ["input", "inputs"] {
    try @ast.eval(parse_filter(name), Json::null()).collect() catch {
      @ast.EvalError(message) =>
        assert_eq(message, "Undefined function: " + name)
      error => raise error
    } noraise {
      _ => fail("shared-input builtin unexpectedly became available")
    }
  }
}

///|
test "module and namespace syntax remain explicit implementation boundaries" {
  for
    source in [
      "import \"values\" as values; values::get", "include \"values\"; get", "module {}; .",
    ] {
    try parse_filter(source) catch {
      _ => ()
    } noraise {
      _ => fail("module boundary must be reassessed")
    }
  }
}
