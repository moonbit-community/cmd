///|
fn suffix_test_literal(text : StringView) -> String? raise {
  let text = text.trim()
  if text == "null" {
    return None
  }
  guard text.has_prefix("'") && text.has_suffix("'") else {
    fail("invalid independent PSL corpus literal")
  }
  Some(text[1:text.length() - 1].to_owned())
}

///|
async test "complete official public suffix corpus keeps independent expectations" {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @path.Path(root).dirname().to_string()
    guard parent != root else { fail("public suffix corpus workspace missing") }
    root = parent
  }
  let bytes = @fs.read_file(root + "/tests/fixtures/psl/test_psl.txt").binary()
  assert_eq(
    @crypto.bytes_to_hex_string(@crypto.sha256(bytes)),
    "8f50ad958916d6a8f79fba2363501475571acce752757f9126fe9d2f17dd920d",
  )
  let mut count = 0
  for line in @utf8.decode(bytes).split("\n") {
    guard line.has_prefix("checkPublicSuffix(") else { continue }
    guard line.has_suffix(");") else { fail("invalid PSL corpus record") }
    let pair = line[18:line.length() - 2].split(",").to_array()
    assert_eq(pair.length(), 2)
    let host = suffix_test_literal(pair[0])
    let expected = suffix_test_literal(pair[1])
    let actual = match host {
      None => None
      Some(host) if host.has_prefix(".") => None
      Some(host) => {
        let mut domain = host.to_lower()
        let mut registrable = None
        while !cookie_public_suffix(domain) {
          match domain.find(".") {
            Some(dot) => {
              registrable = Some(domain)
              domain = domain[dot + 1:].to_owned()
            }
            None => break
          }
        }
        registrable
      }
    }
    assert_eq(actual, expected, msg=line.to_owned())
    count += 1
  }
  assert_eq(count, 78)
}

///|
test "cookie suffix lookup preserves wildcard exceptions and non-contiguous rules" {
  for
    domain in [
      "co.uk", "blogspot.com", "kawasaki.jp", "test.ck", "unknown", "公司.cn",
      "xn--55qx5d.cn",
    ] {
    assert_true(cookie_public_suffix(domain), msg=domain)
  }
  for
    domain in [
      "www.ck", "city.kawasaki.jp", "his.name", "a.unknown", "under_score.example",
    ] {
    assert_false(cookie_public_suffix(domain), msg=domain)
  }
  assert_eq(cookie_longest_suffix("a.b.forgot.his.name"), "forgot.his.name")
}

///|
test "suffix lookup retains oversized names and IPv6 text boundaries" {
  assert_false(cookie_public_suffix("a.".repeat(255) + "com"))
  assert_false(cookie_ip_literal("::ffff:192.168.001.2"))
  assert_true(cookie_ip_literal("::ffff:192.168.1.2"))
  assert_eq(cookie_longest_suffix("a.".repeat(300) + "co.uk"), "co.uk")
}
