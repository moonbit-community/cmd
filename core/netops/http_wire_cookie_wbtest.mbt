///|
async test "public transfer preserves original repeated Set-Cookie fields independently of storage" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let values = [
        "first=one; HttpOnly; path=/; Max-Age=0003600", "second=two; Path=/; SameSite=Lax",
      ]
      let response = "HTTP/1.1 103 Early Hints\r\nSet-Cookie: early=hidden\r\n\r\n" +
        "HTTP/1.1 200 OK\r\nSet-Cookie: " +
        values[0] +
        "\r\nsEt-CoOkIe: " +
        values[1] +
        "\r\nContent-Length: 2\r\n\r\nok"
      let requests : Array[String] = []
      let server = serve_raw_bytes_response(
        group,
        @utf8.encode(response),
        requests~,
      )
      let url = "http://127.0.0.1:\{server.addr.port()}/"
      for profile in [StrictProfile, CurlProfile, WgetProfile] {
        let jar = CookieJar::new()
        let observed : Array[Array[HttpHeader]] = []
        let result = transfer(
          url,
          DiscardOutput,
          transfer_options(profile~, cookie_jar=jar),
          observer=event => {
            if event is ResponseStarted(headers~, ..) {
              observed.push(headers)
            }
          },
        )
        assert_eq(result.status, 200)
        assert_eq(result.received, 2L)
        assert_eq(observed.length(), 1)
        for fields in [result.headers, observed[0]] {
          let cookies = fields.filter(header => {
            header.name.to_lower() == "set-cookie"
          })
          assert_eq(cookies.map(header => header.value), values)
          assert_eq(cookies.map(header => header.name), [
            "Set-Cookie", "sEt-CoOkIe",
          ])
        }
        let stored = jar.netscape()
        assert_true(stored.contains("\tfirst\tone\n"))
        assert_true(stored.contains("\tsecond\ttwo\n"))
        assert_false(stored.contains("\tearly\t"))
        ignore(
          transfer(
            url,
            DiscardOutput,
            transfer_options(profile~, cookie_jar=jar),
          ),
        )
        let sent = requests.last().unwrap()
        assert_true(sent.contains("first=one"))
        assert_true(sent.contains("second=two"))
        assert_false(sent.contains("early=hidden"))
      }
    })
  })
}

///|
async test "public transfer ignores malformed cookies without losing response headers or body" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-cookie-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for malformed in ["broken", "odd=value; Max-Age=nope; Path=/"] {
        let values = [malformed, "valid=ok; Path=/"]
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nSet-Cookie: " +
          values[0] +
          "\r\nSet-Cookie: " +
          values[1] +
          "\r\nContent-Length: 3\r\n\r\nxyz",
        )
        for profile in [StrictProfile, CurlProfile, WgetProfile] {
          for use_jar in [false, true] {
            @fs.write_file(path, "preserve until a complete response")
            let jar = CookieJar::new()
            let result = transfer(
              "http://127.0.0.1:\{server.addr.port()}/",
              FileOutput(
                path~,
                mode=Truncate,
                content_disposition=false,
                remove_on_error=false,
              ),
              transfer_options(
                profile~,
                cookie_jar?=if use_jar { Some(jar) } else { None },
              ),
            )
            assert_eq(result.status, 200)
            assert_eq(result.received, 3L)
            assert_eq(@fs.read_file(path).binary(), b"xyz")
            assert_eq(
              result.headers
              .filter(header => header.name.to_lower() == "set-cookie")
              .map(header => header.value),
              values,
            )
            assert_eq(jar.netscape().contains("\tvalid\tok\n"), use_jar)
            assert_false(jar.netscape().contains("\todd\t"))
          }
        }
      }
    })
  })
}

///|
fn wire_cookie_response(values : Array[String], location : String?) -> String {
  let output = StringBuilder()
  if location is Some(location) {
    output.write_string(
      "HTTP/1.1 302 Found\r\nLocation: " +
      location +
      "\r\nContent-Length: 0\r\n",
    )
  } else {
    output.write_string("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n")
  }
  for value in values {
    output.write_string("Set-Cookie: " + value + "\r\n")
  }
  output.write_string("\r\n")
  if location is None {
    output.write_string("ok")
  }
  output.to_string()
}

///|
async fn wire_cookie_sequence_server(
  group : @async.TaskGroup[Unit],
  responses : Array[String],
  requests : Array[Array[String]],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      let cookies : Array[String] = []
      while connection.read_until("\r\n") is Some(line) && line != "" {
        if line.to_lower().has_prefix("cookie:") {
          cookies.push(line)
        }
      }
      let index = requests.length()
      requests.push(cookies)
      guard index < responses.length() else {
        fail("unexpected extra cookie fixture request")
      }
      connection.write(responses[index])
    })
  })
  server
}

///|
async test "public transfer applies invalid Max-Age updates in response order" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for profile in [StrictProfile, CurlProfile, WgetProfile] {
        for variant in ["seeded", "valid-invalid", "invalid-valid"] {
          let values = match variant {
            "seeded" => ["sid=new; Max-Age=nope; Path=/", "valid=ok; Path=/"]
            "valid-invalid" =>
              [
                "sid=good; Path=/", "sid=bad; Max-Age=nope; Path=/", "valid=ok; Path=/",
              ]
            _ =>
              [
                "sid=bad; Max-Age=nope; Path=/", "sid=good; Path=/", "valid=ok; Path=/",
              ]
          }
          let responses = []
          if variant == "seeded" {
            responses.push(
              wire_cookie_response(["sid=old; Path=/"], Some("/replace")),
            )
          }
          responses.push(wire_cookie_response(values, Some("/final")))
          responses.push(wire_cookie_response([], None))
          let requests : Array[Array[String]] = []
          let server = wire_cookie_sequence_server(group, responses, requests)
          let jar = CookieJar::new()
          let visible : Array[Array[String]] = []
          let result = transfer(
            "http://127.0.0.1:\{server.addr.port()}/start",
            DiscardOutput,
            transfer_options(
              profile~,
              redirects=FollowRedirects(3),
              cookie_jar=jar,
            ),
            observer=event => {
              if event is ResponseStarted(headers~, ..) {
                visible.push(
                  headers
                  .filter(header => header.name.to_lower() == "set-cookie")
                  .map(header => header.value),
                )
              }
            },
          )
          assert_eq(result.status, 200)
          assert_eq(result.received, 2L)
          assert_eq(requests.length(), responses.length())
          assert_eq(requests[0], [])
          if variant == "seeded" {
            assert_eq(requests[1], ["Cookie: sid=old"])
          }
          assert_eq(visible[visible.length() - 2], values)
          let retained = if variant == "seeded" { "old" } else { "good" }
          let keeps_sid = profile != CurlProfile || variant == "invalid-valid"
          let expected = if !keeps_sid {
            "Cookie: valid=ok"
          } else if profile == CurlProfile {
            "Cookie: valid=ok; sid=good"
          } else {
            "Cookie: sid=" + retained + "; valid=ok"
          }
          assert_eq(requests.last().unwrap(), [expected])
          let stored = jar.netscape()
          assert_true(stored.contains("\tvalid\tok\n"))
          assert_eq(stored.contains("\tsid\t"), keeps_sid)
          if keeps_sid {
            assert_true(stored.contains("\tsid\t" + retained + "\n"))
          }
        }
      }
    })
  })
}

///|
async test "public transfer orders curl cookies by specificity and preserved creation order" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for profile in [StrictProfile, CurlProfile, WgetProfile] {
        for
          (blocks, curl_header, wget_header, strict_header) in [
            (
              [["a=1; Path=/", "longname=2; Path=/", "bb=3; Path=/"]],
              "Cookie: longname=2; bb=3; a=1",
              "Cookie: a=1; bb=3; longname=2",
              "Cookie: a=1; longname=2; bb=3",
            ),
            (
              [["aa=1; Path=/", "bb=2; Path=/", "cc=3; Path=/"]],
              "Cookie: cc=3; bb=2; aa=1",
              "Cookie: aa=1; bb=2; cc=3",
              "Cookie: aa=1; bb=2; cc=3",
            ),
            (
              [["cc=3; Path=/", "bb=2; Path=/", "aa=1; Path=/"]],
              "Cookie: aa=1; bb=2; cc=3",
              "Cookie: aa=1; bb=2; cc=3",
              "Cookie: cc=3; bb=2; aa=1",
            ),
            (
              [
                ["aa=old; Path=/", "bb=2; Path=/"],
                ["aa=new; Path=/", "cc=3; Path=/"],
              ],
              "Cookie: cc=3; bb=2; aa=new",
              "Cookie: aa=new; bb=2; cc=3",
              "Cookie: aa=new; bb=2; cc=3",
            ),
            (
              [
                ["sid=bad; Max-Age=nope; Path=/"],
                ["sid=good; Path=/", "valid=ok; Path=/"],
              ],
              "Cookie: valid=ok; sid=good",
              "Cookie: sid=good; valid=ok",
              "Cookie: sid=good; valid=ok",
            ),
          ] {
          let responses = []
          for index, values in blocks {
            responses.push(wire_cookie_response(values, Some("/hop-\{index}")))
          }
          responses.push(wire_cookie_response([], None))
          let requests : Array[Array[String]] = []
          let server = wire_cookie_sequence_server(group, responses, requests)
          let jar = CookieJar::new()
          let result = transfer(
            "http://127.0.0.1:\{server.addr.port()}/start",
            DiscardOutput,
            transfer_options(
              profile~,
              redirects=FollowRedirects(3),
              cookie_jar=jar,
            ),
          )
          assert_eq(result.status, 200)
          assert_eq(requests.length(), responses.length())
          assert_eq(requests[0], [])
          let expected = match profile {
            CurlProfile => curl_header
            WgetProfile => wget_header
            StrictProfile => strict_header
          }
          assert_eq(requests.last().unwrap(), [expected])
        }
      }
    })
  })
}

///|
async test "public transfer distinguishes numeric Max-Age overflow from nonnumeric attributes" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for profile in [StrictProfile, CurlProfile, WgetProfile] {
        for age in ["9223372036854775808", "999999999999999999999999999999"] {
          let values = [
            "sid=new; Max-Age=" + age + "; Path=/",
            "valid=ok; Path=/",
          ]
          let responses = [
            wire_cookie_response(["sid=old; Path=/"], Some("/replace")),
            wire_cookie_response(values, Some("/final")),
            wire_cookie_response([], None),
          ]
          let requests : Array[Array[String]] = []
          let server = wire_cookie_sequence_server(group, responses, requests)
          let jar = CookieJar::new()
          let result = transfer(
            "http://127.0.0.1:\{server.addr.port()}/start",
            DiscardOutput,
            transfer_options(
              profile~,
              redirects=FollowRedirects(3),
              cookie_jar=jar,
            ),
          )
          assert_eq(result.status, 200)
          assert_eq(requests.length(), 3)
          assert_eq(requests[0], [])
          assert_eq(requests[1], ["Cookie: sid=old"])
          let expected = match profile {
            CurlProfile => "Cookie: valid=ok; sid=new"
            WgetProfile => "Cookie: valid=ok"
            StrictProfile => "Cookie: sid=old; valid=ok"
          }
          assert_eq(requests[2], [expected])
          let stored = jar.entries.filter(cookie => cookie.name == "sid")
          match profile {
            CurlProfile => {
              assert_eq(stored.length(), 1)
              assert_eq(stored[0].value, "new")
              assert_true(stored[0].expires is Some(_))
            }
            WgetProfile => assert_eq(stored.length(), 0)
            StrictProfile => {
              assert_eq(stored.length(), 1)
              assert_eq(stored[0].value, "old")
              assert_eq(stored[0].expires, None)
            }
          }
        }
      }
    })
  })
}

///|
test "cookie profiles cap curl Max-Age with fixed-clock overflow and rounding boundaries" {
  let url = parse_absolute_url("https://example.test/")
  for profile in [StrictProfile, CurlProfile, WgetProfile] {
    for
      (now, age, curl_expiry) in [
        (100L, 1L, 101L),
        (100L, 34560000L, 34560100L),
        (100L, 34560001L, 34560120L),
        (89L, 9223372036854775807L, 34560060L),
        (90L, 9223372036854775807L, 34560120L),
        (9223372036820219777L, 9223372036854775807L, 9223372036854775807L),
      ] {
      let jar = CookieJar::new()
      jar.receive(
        url,
        [@http.Cookie("age", "value", max_age=age)],
        now,
        profile~,
      )
      let expected = if profile == CurlProfile {
        curl_expiry
      } else {
        now + age.min(9223372036854775807L - now)
      }
      assert_eq(jar.entries.length(), 1)
      assert_eq(jar.entries[0].expires, Some(expected))
    }
    for age in [0L, -1L] {
      let jar = CookieJar::new()
      jar.receive(url, [@http.Cookie("age", "old")], 100L, profile~)
      jar.receive(
        url,
        [@http.Cookie("age", "new", max_age=age)],
        100L,
        profile~,
      )
      assert_eq(jar.entries.length(), 0)
    }
  }
  let overlong = "sid=new; Max-Age=9999999999999999999999999999999999; Path=/"
  assert_true(wire_cookie(overlong, WgetProfile) is None)
  assert_true(wire_cookie(overlong, StrictProfile) is None)
  assert_true(wire_cookie(overlong, CurlProfile) is Some(_))
  let padded = "0000000000000000" + "000000000000001"
  assert_eq(padded.length(), 31)
  let accepted = wire_cookie("sid=new; Max-Age=" + padded, WgetProfile).unwrap()
  assert_eq(accepted.max_age, Some(1L))
  let oversized = "sid=new; Max-Age=0" + padded
  assert_true(wire_cookie(oversized, WgetProfile) is None)
  for profile in [StrictProfile, CurlProfile] {
    assert_eq(wire_cookie(oversized, profile).unwrap().max_age, Some(1L))
  }
}
