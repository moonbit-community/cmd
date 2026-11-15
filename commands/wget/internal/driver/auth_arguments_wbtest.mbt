///|
test "HTTP credential options take precedence independently of argument order" {
  for
    args in [
      [
        "--http-user=http", "--http-password=secret", "--user=general", "--password=other",
      ],
      [
        "--user=general", "--password=other", "--http-user=http", "--http-password=secret",
      ],
    ] {
    let options = parse_options(args)
    assert_eq(options.user, Some("http"))
    assert_eq(options.password, Some("secret"))
  }
  assert_eq(parse_options(["--user=u"]).password, None)
  assert_eq(parse_options(["--password="]).password, Some(""))
}

///|
test "attached Basic challenge booleans preserve literal option operands" {
  for value in ["on", "YES", "1"] {
    assert_true(
      parse_options(["--auth-no-challenge=" + value]).auth_no_challenge,
    )
  }
  for value in ["off", "NO", "0"] {
    assert_false(
      parse_options(["--auth-no-challenge", "--auth-no-challenge=" + value]).auth_no_challenge,
    )
  }
  assert_true(
    parse_options(["--auth-no-challenge=off", "--auth-no-challenge"]).auth_no_challenge,
  )
  let long_value = parse_options([
    "--password", "--auth-no-challenge", "--", "--auth-no-challenge",
  ])
  assert_eq(long_value.password, Some("--auth-no-challenge"))
  assert_eq(long_value.urls, ["--auth-no-challenge"])
  assert_false(long_value.auth_no_challenge)
  let short_value = parse_options([
    "-qO", "--auth-no-challenge", "--auth-no-challenge",
  ])
  assert_eq(short_value.output_document, Some("--auth-no-challenge"))
  assert_true(short_value.auth_no_challenge)
}
