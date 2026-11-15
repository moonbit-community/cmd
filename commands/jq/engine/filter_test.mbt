///|
test "compiled filters reuse lexical code with fresh per-value scopes" {
  let filter = @engine.compile("def twice(x): x + x; twice(.n)")
  assert_eq(filter.apply({ "n": 3 }), [6])
  assert_eq(filter.apply({ "n": 7 }), [14])
  assert_eq(
    @engine.compile("if . < 0 then -1 elif . == 0 then 0 else 1 end").apply(0),
    [0],
  )
  assert_eq(@engine.compile("1 and 2, false or 2").apply(null), [true, true])
}

///|
test "compilation rejects unknown lexical references and module dependencies" {
  for
    source in [
      "missing", "$missing", "def f: $x; 10 as $x | f", "import \"x\" as x; .", "include \"x\"; .",
    ] {
    try @engine.compile(source) catch {
      _ => ()
    } noraise {
      _ => fail("invalid standalone filter compiled: " + source)
    }
  }
}

///|
test "value filters reject host requests without treating them as EOF" {
  for
    source in [
      "input", "inputs", "input_filename", "input_line_number", "\"x\" | modulemeta",
    ] {
    let filter = @engine.compile(source)
    try filter.apply(null) catch {
      error =>
        assert_true(
          error.to_string().contains("unavailable for a supplied JSON value"),
        )
    } noraise {
      _ => fail("host request unexpectedly succeeded: " + source)
    }
  }
  assert_eq(@engine.compile("try input catch .").apply(null), [
    Json::string("input/inputs is unavailable for a supplied JSON value"),
  ])
  assert_eq(@engine.compile("def input: 42; input").apply(null), [42])
  assert_eq(@engine.compile("limit(0; inputs)").apply(null), [])
}

///|
test "a failed value produces no result array and does not poison later calls" {
  let filter = @engine.compile("., (10 / .)")
  try filter.apply(0) catch {
    _ => ()
  } noraise {
    _ => fail("division by zero must discard the value's results")
  }
  assert_eq(filter.apply(2), [2, 5])
  assert_eq(
    @engine.compile("foreach .[] as $x (0; . + $x; empty)").apply([1, 2]),
    [],
  )
}
