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
test "FTP startup policy accepts booleans without changing HTTP options" {
  for value in ["on", "OFF", "yes", "No", "1", "0"] {
    assert_eq(config_arguments("passive_ftp = " + value), [])
    assert_eq(execute_arguments("PaSsIvE-FtP=" + value), [])
  }
  assert_true(parse_options(config_arguments("passive_ftp=on\nquiet=on")).quiet)
  for value in ["", "maybe", "2"] {
    try execute_arguments("passive_ftp=" + value) catch {
      UsageError(message) =>
        assert_eq(
          message,
          "passive_ftp: Invalid boolean '" + value + "'; use `on' or `off'.",
        )
    } noraise {
      _ => fail("invalid FTP configuration boolean accepted")
    }
  }
  for value in [" \t", "\u0000passive_ftp=on", "  # passive_ftp=on"] {
    try execute_arguments(value) catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("blank execute command accepted")
    }
  }
}

///|
async test "system configuration falls back only when the override cannot be read" {
  let root = @fs.tmpdir(prefix="wget-system-config-")
  defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
  let default_path = root + "/system-wgetrc"
  let override_path = root + "/override-wgetrc"
  @fs.write_file(default_path, "quiet=on\npassive_ftp=on\n")
  for path in [None, Some(""), Some(root + "/missing"), Some(root)] {
    assert_eq(system_config_arguments(default_path, path), ["--quiet"])
  }
  @fs.write_file(override_path, "quiet=off\n")
  assert_eq(system_config_arguments(default_path, Some(override_path)), [
    "--no-quiet",
  ])
  @fs.write_file(override_path, "")
  assert_eq(system_config_arguments(default_path, Some(override_path)), [])
  @fs.write_file(override_path, "passive_ftp=maybe\n")
  try system_config_arguments(default_path, Some(override_path)) catch {
    ConfigError(code, message) => {
      assert_eq(code, 2)
      assert_true(message.contains(override_path))
    }
    error => raise error
  } noraise {
    _ => fail("invalid readable override fell back to default configuration")
  }
  @fs.write_file(default_path, "passive_ftp=maybe\n")
  try system_config_arguments(default_path, Some(root + "/missing")) catch {
    ConfigError(code, message) => {
      assert_eq(code, 2)
      assert_true(message.contains(default_path))
    }
    error => raise error
  } noraise {
    _ => fail("invalid fallback configuration was ignored")
  }
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
