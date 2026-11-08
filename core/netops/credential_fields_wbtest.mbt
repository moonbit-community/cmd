///|
test "wget credentials distinguish omitted and empty URL passwords" {
  let options = transfer_options(
    profile=WgetProfile,
    basic_user="option-user",
    basic_password="option-password",
  )
  for
    (authority, expected) in [
      ("url-user:url-password@a.example", Some("url-user:url-password")),
      ("url-user:@a.example", Some("url-user:")),
      ("url-user@a.example", Some("url-user:option-password")),
      ("url%3Auser:secret%3Avalue@a.example", Some("url:user:secret:value")),
      ("a.example", Some("option-user:option-password")),
    ] {
    assert_eq(
      parse_absolute_url("http://" + authority + "/").basic_credentials(options),
      expected,
    )
  }
  let missing = transfer_options(profile=WgetProfile)
  assert_eq(
    parse_absolute_url("http://user@a.example/").basic_credentials(missing),
    None,
  )
  assert_eq(
    parse_absolute_url("http://user:@a.example/").basic_credentials(missing),
    Some("user:"),
  )
  assert_eq(
    parse_absolute_url("http://a.example/").basic_credentials(
      transfer_options(profile=WgetProfile, basic_user="user"),
    ),
    None,
  )
}

///|
test "curl explicit credential fields preserve original serialized values" {
  let url = parse_absolute_url("http://url:secret@a.example/")
  for
    (user, password, expected) in [
      (Some("user"), None, Some("user")),
      (Some("user"), Some(""), Some("user:")),
      (Some(""), Some("secret"), Some(":secret")),
      (Some("u"), Some("p:tail"), Some("u:p:tail")),
      (None, None, None),
    ] {
    assert_eq(
      url.basic_credentials(
        transfer_options(
          profile=CurlProfile,
          basic_user?=user,
          basic_password?=password,
        ),
      ),
      expected,
    )
  }
}
