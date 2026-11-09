///|
#derive(FromJson)
priv struct CookieCorpusCase {
  label : String?
  id : String?
  tool : String?
  hosts : Array[String]
  fields : Array[Array[String]]
  input : String
  keep_session : Bool?
  url_encoding_flags : Array[String]?
  expected : Json
}

///|
async fn cookie_corpus(name : String, count : Int32) -> Array[CookieCorpusCase] {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @path.Path(root).dirname().to_string()
    guard parent != root else {
      fail("cookie corpus requires the repository workspace")
    }
    root = parent
  }
  let source = @json.parse(
    @fs.read_file(root + "/tests/fixtures/network/" + name + ".json").text(),
  )
  guard source is { "schema": 1, "cases": Array(rows), .. } else {
    fail("invalid cookie corpus: " + name)
  }
  assert_eq(rows.length(), count, msg=name)
  let cases : Array[CookieCorpusCase] = @json.from_json(Json(rows))
  let seen : Set[String] = Set([])
  for fixture in cases {
    let id = fixture.id.unwrap_or(fixture.label.unwrap_or(""))
    assert_true(
      id != "" && !seen.contains(id),
      msg=name + ": missing or duplicate record ID",
    )
    seen.add(id)
    assert_true(!fixture.hosts.is_empty(), msg=id)
    assert_eq(fixture.hosts.length(), fixture.fields.length(), msg=id)
  }
  cases
}

///|
fn corpus_cookie_rows(text : String) -> Array[String] {
  text
  .split("\n")
  .filter(line => {
    line != "" && (!line.has_prefix("#") || line.has_prefix("#HttpOnly_"))
  })
  .map(StringView::to_owned)
  .collect()
}

///|
fn check_cookie_corpus(fixture : CookieCorpusCase) -> Unit raise {
  let id = fixture.id.unwrap_or(fixture.label.unwrap_or(""))
  let profile = if fixture.tool == Some("curl") {
    CurlProfile
  } else {
    WgetProfile
  }
  // Original corpora exclude current-second and relative-future expectations.
  // Use a fixed instant before every retained future expiry, independent of CI.
  let now = 1794096000L
  guard fixture.expected is Object(expected) else {
    fail(id + ": missing expectations")
  }
  let cookies : Array[String] = @json.from_json(expected["cookies"])
  let rows : Array[Array[String]] = match expected.get("rows_by_phase") {
    Some(value) => @json.from_json(value)
    None => {
      let saved : Array[String] = @json.from_json(expected["rows"])
      [saved, saved]
    }
  }
  let orders : Array[Array[String]]? = expected
    .get("row_orders")
    .map(value => @json.from_json(value))
  assert_eq(rows.length(), 2, msg=id)
  assert_eq(cookies.length(), fixture.hosts.length() + 1, msg=id)
  let mut input = fixture.input
  let mut cursor = 0
  for pass in 0..<2 {
    let jar = CookieJar::new()
    if profile == WgetProfile {
      jar.load_netscape_at(input, now, profile)
    }
    let indices = if pass == 0 {
      fixture.hosts.mapi((index, _) => index)
    } else {
      [fixture.hosts.length() - 1]
    }
    for index in indices {
      if profile == CurlProfile {
        jar.load_netscape_at(input, now, profile)
      }
      let url = parse_absolute_url(
        "http://" + fixture.hosts[index] + "/step/" + index.to_string(),
      ).for_transfer(
        profile,
        utf8_hosts=profile == CurlProfile ||
          fixture.url_encoding_flags
          .unwrap_or([])
          .contains("--local-encoding=UTF-8"),
      )
      assert_eq(
        jar.header_for(url, now, profile~).unwrap_or(""),
        cookies[cursor],
        msg=id + ": request " + cursor.to_string(),
      )
      cursor += 1
      if pass == 0 {
        let received : Array[Cookie] = []
        for field in fixture.fields[index] {
          let (_, value) = wire_field("Set-Cookie: " + field)
          if wire_cookie(value, profile) is Some(cookie) {
            received.push(cookie)
          }
        }
        jar.receive(url, received, now, profile~)
      }
      if profile == CurlProfile {
        // Curl saves after each URL, expiring tombstones before the next load.
        ignore(jar.netscape(now~, profile~))
      }
    }
    let saved = jar.netscape(
      include_session=profile == CurlProfile ||
        fixture.keep_session.unwrap_or(true),
      now~,
      profile~,
    )
    let actual = corpus_cookie_rows(saved)
    if orders is Some(orders) {
      assert_eq(actual, orders[pass], msg=id + ": row order")
    }
    let sorted = actual.copy()
    sorted.sort_by((left, right) => left.lexical_compare(right))
    assert_eq(sorted, rows[pass], msg=id + ": saved rows")
    input = saved
  }
  assert_eq(cursor, cookies.length(), msg=id)
}

///|
async test "complete Wget cookie dialect corpus preserves request, save and reload state" {
  for fixture in cookie_corpus("wget-cookies", 58) {
    check_cookie_corpus(fixture)
  }
}

///|
async test "complete Wget expiry corpus preserves request, save and reload state" {
  for fixture in cookie_corpus("wget-cookie-expiry", 194) {
    check_cookie_corpus(fixture)
  }
}

///|
async test "complete Wget date corpus preserves request, save and reload state" {
  for fixture in cookie_corpus("wget-cookie-dates", 87) {
    check_cookie_corpus(fixture)
  }
}

///|
async test "complete Curl and Wget Domain corpus preserves admission and row order" {
  for fixture in cookie_corpus("cookie-domains", 255) {
    check_cookie_corpus(fixture) catch {
      error => fail(fixture.id.unwrap() + ": " + error.to_string())
    }
  }
}
