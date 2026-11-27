///|
test "minimal CLI defaults and explicit address" {
  let parse = fn(args : ArrayView[String]) raise {
    match command.parse_outcome(argv=args) {
      Parsed(matches) => options(matches)
      Failed(error) => raise error
      _ => fail("expected executable arguments")
    }
  }
  let (root, addr) = parse([])
  assert_eq(root, ".")
  assert_eq(addr.to_string(), "127.0.0.1:8000")
  let (root, addr) = parse(["--host", "::1", "-p", "0", "public"])
  assert_eq(root, "public")
  assert_eq(addr.to_string(), "[::1]:0")
  let (root, addr) = parse(["--port=0", "--", "-public"])
  assert_eq(root, "-public")
  assert_eq(addr.to_string(), "127.0.0.1:0")
  let (_, addr) = parse(["-p0"])
  assert_eq(addr.port, 0)
  for
    args in [
      ["-p"],
      ["--port", "65536"],
      ["--port", "-1"],
      ["--port", "abc"],
      ["-p", "8000", "--port", "0"],
      ["--host", "localhost"],
      ["a", "b"],
      ["--spa"],
    ] {
    let result = Some(parse(args[:])) catch { _ => None }
    assert_true(result is None)
  }
}
