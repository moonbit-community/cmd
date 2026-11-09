///|
test "decode request paths once and reject traversal and platform aliases" {
  for
    (target, expected) in [
      ("/", ""),
      ("/hello%20world.txt?download=1", "hello world.txt"),
      ("/a+b.txt", "a+b.txt"),
      ("/%E4%B8%AD.txt", "中.txt"),
      ("//nested///file", "nested/file"),
      ("/%252e%252e/file", "%2e%2e/file"),
    ] {
    assert_eq(request_path(target), Some(expected))
  }
  for
    target in [
      "*", "http://host/file", "/../secret", "/%2e%2E/secret", "/a/%2e/secret", "/a%2f..%2fsecret",
      "/%5c..%5csecret", "/%00.txt", "/%ff", "/%", "/%0g", "/C:/secret", "/file:stream",
      "/aux.txt", "/COM1", "/a./file", "/a%20/file",
    ] {
    assert_eq(request_path(target), None, msg=target)
  }
}

///|
test "canonical root containment requires a component boundary" {
  let sep = if @async.platform is Windows { "\\" } else { "/" }
  let root = "root" + sep + "public"
  assert_true(inside_root(root, root))
  assert_true(inside_root(root, root + sep + "file"))
  assert_false(inside_root(root, root + "-private" + sep + "secret"))
  assert_true(inside_root(sep, sep + "file"))
}

///|
test "MIME mappings and binary fallback" {
  for
    (path, expected) in [
      ("index.HTML", "text/html"),
      ("style.css", "text/css"),
      ("app.mjs", "text/javascript"),
      ("module.wasm", "application/wasm"),
      ("data.json", "application/json"),
      ("image.svg", "image/svg+xml"),
      ("font.woff2", "font/woff2"),
      ("no-extension", "application/octet-stream"),
      ("data.unknown", "application/octet-stream"),
    ] {
    assert_eq(mime_type(path), expected)
  }
}

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
  assert_eq(addr.port(), 0)
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
