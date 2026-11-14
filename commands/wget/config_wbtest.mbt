///|
fn config_arguments(text : String) -> Array[String] raise UsageError {
  let args : Array[String] = []
  for raw in text.split("\n") {
    args.append(config_setting(raw.to_owned()))
  }
  args
}

///|
test "wget config uses unquoted values and canonical setting names" {
  let options = parse_options(
    config_arguments(
      "# ignored\nHTTP_User = account\nhttp-password = p:a ss # literal\nquiet = on\nuse_proxy = off\ncookies = no\nheader=X-Test: first\nheader=\nheader=X-Test: last\n",
    ),
  )
  assert_eq(options.user, Some("account"))
  assert_eq(options.password, Some("p:a ss # literal"))
  assert_true(options.quiet)
  assert_true(options.no_proxy)
  assert_false(options.cookies)
  assert_eq(options.headers, [@netops.http_header("X-Test", "last")])
  let auth = parse_options(config_arguments("auth_no_challenge=on\n"))
  assert_true(auth.auth_no_challenge)
  assert_true(auth.urls.is_empty())
  assert_eq(config_arguments("input=urls.txt"), ["--input-file", "urls.txt"])
  for text in ["", "# comment"] {
    try execute_arguments(text) catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("empty execute command accepted")
    }
  }
  for text in ["quiet yes", "quiet=maybe", "no_cookies=on", "missing=value"] {
    try config_arguments(text) catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("invalid config accepted")
    }
  }
}

///|
test "later timeout settings override both configured and explicit deadlines" {
  let options = parse_options(
    [..config_arguments("read_timeout=1\nconnect_timeout=2"), "--timeout", "3"],
  )
  assert_eq(options.connect_timeout_ms, 3000)
  assert_eq(options.read_timeout_ms, 3000)
  let options = parse_options(
    [
      ..config_arguments("timeout=3"),
      "--connect-timeout",
      "2",
      "--read-timeout",
      "1",
    ],
  )
  assert_eq(options.connect_timeout_ms, 2000)
  assert_eq(options.read_timeout_ms, 1000)
  let options = parse_options([
    "--read-timeout", "1", "--timeout", "3", "--idle-timeout", "4",
  ])
  assert_eq(options.connect_timeout_ms, 3000)
  assert_eq(options.read_timeout_ms, 4000)
}

///|
test "configuration selector scanning respects option values and the delimiter" {
  assert_eq(
    config_tokens([
      "-qO--config", "--header=--no-config", "-equiet=off", "--auth-no-challenge",
      "--", "--config",
    ]),
    [
      ("-q", None),
      ("-O", Some("--config")),
      ("--header", Some("--no-config")),
      ("-e", Some("quiet=off")),
      ("--auth-no-challenge", None),
      ("--", None),
      ("--config", None),
    ],
  )
}
