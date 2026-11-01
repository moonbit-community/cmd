///|
#warnings("-result_error_return")
fn parse_format(s : String) -> Result[HyperlinkFormat, HyperlinkFormatError] {
  try HyperlinkFormat::parse(s) catch {
    HyperlinkFormatError(_) as e => Err(e)
  } noraise {
    f => Ok(f)
  }
}

///|
#warnings("-result_error_return")
fn format_err(
  kind : HyperlinkFormatErrorKind,
) -> Result[HyperlinkFormat, HyperlinkFormatError] {
  Err(HyperlinkFormatError(kind))
}

///|
test "build_format" {
  let builder = FormatBuilder::new()
  builder.append_slice("foo://").append_slice("bar-").append_slice("baz")
  |> ignore
  builder.append_var("path")
  let format = builder.build()
  assert_eq(format.to_string(), "foo://bar-baz{path}")
  assert_eq(format.parts[0], Text("foo://bar-baz"))
  assert_false(format.is_empty())
}

///|
test "build_empty_format" {
  let format = FormatBuilder::new().build()
  assert_true(format.is_empty())
  assert_eq(format, HyperlinkFormat::empty())
}

///|
test "handle_alias" {
  assert_true(parse_format("file") is Ok(_))
  assert_true(parse_format("none") is Ok(_))
  assert_true(HyperlinkFormat::parse("none").is_empty())
}

///|
test "parse_format" {
  let format = HyperlinkFormat::parse("foo://{host}/bar/{path}:{line}:{column}")
  assert_eq(format.to_string(), "foo://{host}/bar/{path}:{line}:{column}")
  assert_eq(format.parts.length(), 8)
  assert_true(format.parts.contains(Path))
  assert_true(format.parts.contains(Line))
  assert_true(format.parts.contains(Column))
}

///|
test "parse_valid" {
  assert_true(HyperlinkFormat::parse("").is_empty())
  assert_eq(HyperlinkFormat::parse("foo://{path}").to_string(), "foo://{path}")
  assert_eq(
    HyperlinkFormat::parse("foo://{path}/bar").to_string(),
    "foo://{path}/bar",
  )
  HyperlinkFormat::parse("f://{path}") |> ignore
  HyperlinkFormat::parse("f:{path}") |> ignore
  HyperlinkFormat::parse("f-+.:{path}") |> ignore
  HyperlinkFormat::parse("f42:{path}") |> ignore
  HyperlinkFormat::parse("42:{path}") |> ignore
  HyperlinkFormat::parse("+:{path}") |> ignore
  HyperlinkFormat::parse("F42:{path}") |> ignore
  HyperlinkFormat::parse("F42://foo{{bar}}{path}") |> ignore
}

///|
test "parse_invalid" {
  assert_eq(parse_format("foo://bar"), format_err(NoVariables))
  assert_eq(parse_format("foo://{line}"), format_err(NoPathVariable))
  assert_eq(parse_format("foo://{path"), format_err(UnclosedVariable))
  assert_eq(parse_format("foo://{path}:{column}"), format_err(NoLineVariable))
  assert_eq(parse_format("{path}"), format_err(InvalidScheme))
  assert_eq(parse_format(":{path}"), format_err(InvalidScheme))
  assert_eq(parse_format("f*:{path}"), format_err(InvalidScheme))
  assert_eq(parse_format("foo://{bar}"), format_err(InvalidVariable("bar")))
  assert_eq(parse_format("foo://{}}bar}"), format_err(InvalidVariable("")))
  assert_eq(parse_format("foo://{b}}ar}"), format_err(InvalidVariable("b")))
  assert_eq(parse_format("foo://{bar}}}"), format_err(InvalidVariable("bar")))
  assert_eq(parse_format("foo://{{bar}"), format_err(InvalidCloseVariable))
  assert_eq(parse_format("foo://{{{bar}"), format_err(InvalidVariable("bar")))
  assert_eq(parse_format("foo://{b{{ar}"), format_err(InvalidVariable("b{{ar")))
  assert_eq(parse_format("foo://{bar{{}"), format_err(InvalidVariable("bar{{")))
}

///|
/// Byte-wise lexicographic comparison of ASCII strings.
fn ascii_less(a : String, b : String) -> Bool {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i] < b[i]
    }
  }
  a.length() < b.length()
}

///|
test "aliases_are_sorted" {
  let aliases = hyperlink_aliases()
  let mut prev = aliases[0].name
  for i in 1..<aliases.length() {
    let name = aliases[i].name
    assert_true(ascii_less(prev, name))
    prev = name
  }
}

///|
test "alias_names_are_reasonable" {
  for al in hyperlink_aliases() {
    assert_true(
      al.name
      .iter()
      .all(c => {
        (c >= 'a' && c <= 'z') ||
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        c == '+' ||
        c == '-' ||
        c == '.'
      }),
    )
  }
}

///|
test "aliases_are_valid_formats" {
  for al in hyperlink_aliases() {
    assert_true(parse_format(al.format) is Ok(_))
  }
}

///|
test "format error messages" {
  let msg = (s : String) => {
    match parse_format(s) {
      Err(e) => e.to_string()
      Ok(_) => "ok"
    }
  }
  inspect(
    msg("foo://bar"),
    content="at least a {path} variable is required in a hyperlink format, or otherwise use a valid alias: default, none, cursor, file, grep+, kitty, macvim, textmate, vscode, vscode-insiders, vscodium",
  )
  inspect(
    msg("foo://{line}"),
    content="the {path} variable is required in a hyperlink format",
  )
  inspect(
    msg("foo://{bar}"),
    content="invalid hyperlink format variable: 'bar', choose from: path, line, column, host, wslprefix",
  )
}

///|
async test "hyperlink path encoding" {
  let env = HyperlinkEnvironment::new()
  let p = HyperlinkPath::from_path("/a b/c%d/é.txt", env).unwrap()
  assert_eq(p.bytes, @utf8.encode("/a%20b/c%25d/é.txt"))
  // Relative paths have no hyperlink without a canonicalizer.
  assert_true(HyperlinkPath::from_path("rel/path", env) is None)
  env.canonicalize(Some(p => Some("/home/user/" + p))) |> ignore
  let p = HyperlinkPath::from_path("rel/path", env).unwrap()
  assert_eq(p.bytes, b"/home/user/rel/path")
  env.canonicalize(Some(_ => None)) |> ignore
  assert_true(HyperlinkPath::from_path("/x", env) is None)
}
