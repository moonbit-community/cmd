///|
test "config quoting and separators preserve option values" {
  assert_eq(
    config_arguments(
      "# comment\nheader = \"X-Test: one\\ttwo\"\nurl: http://example.test/\nsilent\n",
    ),
    [
      "--header", "X-Test: one\ttwo", "--url", "http://example.test/", "--silent",
    ],
  )
  assert_eq(
    config_arguments("--header \"X: \\\"quoted\\\"\\\\tail\"\nuser=\"u:p\"\n"),
    ["--header", "X: \"quoted\"\\tail", "--user", "u:p"],
  )
  for
    text in [
      "header\nurl=http://example.test/", "silent = yes", "unknown = value",
    ] {
    try config_arguments(text) catch {
      ConfigLineError(_, _) => ()
      error => raise error
    } noraise {
      _ => fail("invalid config accepted")
    }
  }
}

///|
async fn expand_config(
  args : ArrayView[String],
  read : async (String) -> String,
  depth : Int32,
) -> Array[String] {
  let output : Array[String] = []
  expand_config_into(output, args, read, depth)
  output
}

///|
async test "included config arguments retain URL and last-option order" {
  let read : async (String) -> String = path => {
    match path {
      "outer" => "url=http://first.test/\nsilent\nconfig=inner\n"
      "inner" => "header=\"X-Test: nested\"\nurl=http://second.test/\n"
      _ => fail("unexpected config path")
    }
  }
  let args = expand_config(
    ["-qKouter", "--no-silent", "http://third.test/", "--", "-literal"],
    read,
    0,
  )
  let options = parse_options(args)
  assert_eq(options.urls, [
    "http://first.test/", "http://second.test/", "http://third.test/", "-literal",
  ])
  assert_false(options.silent)
  assert_eq(options.headers, [@netops.http_header("X-Test", "nested")])
  assert_eq(expand_config(["-o", "-K", "--header=K:value"], read, 0), [
    "-o", "-K", "--header", "K:value",
  ])
}

///|
async test "recursive config loading stops before opening the next file" {
  let reads = Ref(0)
  try
    expand_config(
      ["-K", "loop"],
      _ => {
        reads.val += 1
        "config=loop"
      },
      0,
    )
  catch {
    ConfigOptionError(_, _) => assert_eq(reads.val, MaxConfigDepth)
    error => raise error
  } noraise {
    _ => fail("recursive config accepted")
  }
}

///|
async test "invalid options stop before later config input is read" {
  let reads = Ref(0)
  for
    args in [
      ["-q", "--missing-option", "-K", "-"],
      ["-q", "--retry", "invalid", "-K", "-"],
      ["-q", "--retry", "invalid", "--retry", "0", "-K", "-"],
      ["-q", "--silent=bad", "-K", "-"],
      ["-q", "--max-time", "invalid", "-H", "@-"],
    ] {
    try
      expand_config(
        args,
        _ => {
          reads.val += 1
          ""
        },
        0,
      )
    catch {
      UsageError(_) => assert_eq(reads.val, 0)
      error => raise error
    } noraise {
      _ => fail("invalid option accepted")
    }
  }
  try config_arguments("retry=invalid\nretry=0") catch {
    ConfigLineError("retry", "expected a proper numerical parameter") => ()
    error => raise error
  } noraise {
    _ => fail("invalid value was overwritten")
  }
  try
    expand_config(
      ["-q", "-I", "--no-head", "-K", "-"],
      _ => {
        reads.val += 1
        ""
      },
      0,
    )
  catch {
    OptionConflict("--no-head") => assert_eq(reads.val, 0)
    error => raise error
  } noraise {
    _ => fail("conflicting methods accepted")
  }
}
