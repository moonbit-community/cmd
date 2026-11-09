///|
#derive(FromJson)
priv struct AuthenticationRoute {
  path : String
  credential : String?
  location : String?
  deny : Bool
  plain : Bool
  challenge : String
  failure_status : Int32
}

///|
#derive(FromJson)
priv struct AuthenticationExpected {
  status : Int32
  stdout : String
  stderr : String
  requests : Array[String]
}

///|
#derive(FromJson)
priv struct AuthenticationCase {
  label : String
  args : Array[String]
  urls : Array[String]
  routes : Array[AuthenticationRoute]
  oracle_request_lines : Array[String]
  expected : AuthenticationExpected
}

///|
async fn authentication_cases() -> Array[AuthenticationCase] {
  let mut root = @fs.realpath(".")
  while !@fs.exists(root + "/moon.work") {
    let parent = @path.Path(root).dirname().to_string()
    guard parent != root else {
      fail("authentication corpus requires the workspace")
    }
    root = parent
  }
  let source = @json.parse(
    @fs.read_file(root + "/tests/fixtures/network/wget-authentication.json").text(),
  )
  guard source is { "schema": 1, "cases": Array(rows), .. } else {
    fail("frozen authentication corpus required")
  }
  assert_eq(rows.length(), 73)
  let fixtures : Array[AuthenticationCase] = @json.from_json(Json(rows))
  let seen : Set[String] = Set([])
  for fixture in fixtures {
    assert_true(
      fixture.label != "" && !seen.contains(fixture.label),
      msg="missing or duplicate authentication ID",
    )
    seen.add(fixture.label)
    assert_true(!fixture.urls.is_empty(), msg=fixture.label)
    assert_eq(
      fixture.oracle_request_lines.length(),
      fixture.expected.requests.length(),
      msg=fixture.label,
    )
    let paths : Set[String] = Set([])
    for route in fixture.routes {
      assert_true(
        route.path.has_prefix("/") && !paths.contains(route.path),
        msg=fixture.label,
      )
      paths.add(route.path)
      assert_true(
        route.failure_status == 401 || route.failure_status == 403,
        msg=fixture.label,
      )
    }
  }
  fixtures
}

///|
async fn authentication_headers(
  connection : @socket.Tcp,
) -> (String, Array[(String, String)]) {
  let first = connection.read_until("\r\n").unwrap()
  let fields : Array[(String, String)] = []
  while connection.read_until("\r\n") is Some(line) && line != "" {
    let split = line.find(":").unwrap()
    fields.push(
      (line[:split].to_owned().to_lower(), line[split + 1:].trim().to_owned()),
    )
  }
  (first, fields)
}

///|
async fn check_authentication_case(fixture : AuthenticationCase) -> Unit {
  let directory = @fs.tmpdir(prefix="wget-authentication")
  defer @async.protect_from_cancel(() => @fs.rmdir(directory, recursive=true))
  let body = Bytes::from_array([0, 1, 2, 65, 66, 67, 255, 13, 10])
  @fs.write_file(directory + "/body.bin", body)
  let output = directory + "/output"
  let requests : Array[String] = []
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        let (tunnel, _) = authentication_headers(connection)
        assert_true(tunnel.has_prefix("CONNECT "))
        connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
        let (start, fields) = authentication_headers(connection)
        let parts = start.split(" ").to_array()
        assert_eq(parts.length(), 3)
        assert_eq(parts[2], "HTTP/1.1")
        let path = parts[1].to_owned()
        assert_true(path.has_prefix("/"))
        let hosts = fields.filter(pair => pair.0 == "host").map(pair => pair.1)
        assert_eq(hosts.length(), 1)
        let auth = fields
          .filter(pair => pair.0 == "authorization")
          .map(pair => pair.1)
        let length = fields
          .iter()
          .find_first(pair => pair.0 == "content-length")
        let length : Int32 = match length {
          Some((_, value)) => @json.from_json(@json.parse(value))
          None => 0
        }
        let bytes = if length > 0 {
          connection.read_exactly(length)
        } else {
          b""
        }
        requests.push(
          parts[0].to_owned() +
          " " +
          hosts[0].to_lower() +
          " " +
          path +
          " auth=" +
          auth.join("|") +
          " body=" +
          @crypto.bytes_to_hex_string(bytes),
        )
        guard fixture.routes.iter().find_first(route => route.path == path)
          is Some(route) else {
          fail("unregistered authentication path: " + path)
        }
        let rejected = route.deny ||
          route.plain ||
          (route.credential is Some(credential) && auth != [credential])
        let status = if rejected {
          if route.failure_status == 403 {
            "403 Forbidden"
          } else {
            "401 Unauthorized"
          }
        } else if route.location is Some(_) {
          "302 Found"
        } else {
          "200 OK"
        }
        let fields = if rejected && !route.plain {
          "WWW-Authenticate: " + route.challenge + "\r\n"
        } else if route.location is Some(location) {
          "Location: " + location + "\r\n"
        } else {
          ""
        }
        let body = if rejected {
          "denied\n"
        } else if route.location is Some(_) {
          ""
        } else {
          "ok\n"
        }
        connection.write(
          "HTTP/1.1 " +
          status +
          "\r\n" +
          fields +
          "Content-Length: " +
          body.length().to_string() +
          "\r\nConnection: close\r\n\r\n" +
          body,
        )
      })
    })
    let args = ["-qO-", "-t1", ..fixture.args, ..fixture.urls]
    let options = parse_options(args[:]) catch {
      UsageError(message) => {
        assert_eq(fixture.expected.status, 2, msg=fixture.label)
        assert_eq(
          "wget: " + message + "\n",
          fixture.expected.stderr,
          msg=fixture.label,
        )
        assert_eq(fixture.expected.stdout, "", msg=fixture.label)
        assert_eq(requests, fixture.expected.requests, msg=fixture.label)
        return
      }
    }
    assert_true(options.quiet, msg=fixture.label)
    assert_eq(fixture.expected.stderr, "", msg=fixture.label)
    // Observe bytes through a private file sink; CLI scenarios retain stdout,
    // diagnostics and process-level effects. All authentication policy runs here.
    options.output_document = Some(output)
    options.utf8_hosts = false
    if options.body is @netops.FileBody(path) {
      assert_eq(path, "body.bin", msg=fixture.label)
      options.body = @netops.FileBody(directory + "/body.bin")
    }
    let status = run(options, lookup_env=name => {
      if name == "http_proxy" {
        Some("http://127.0.0.1:" + server.addr.port().to_string())
      } else {
        None
      }
    })
    assert_eq(status, fixture.expected.status, msg=fixture.label)
    assert_eq(
      @fs.read_file(output).text(),
      fixture.expected.stdout,
      msg=fixture.label,
    )
    assert_eq(requests, fixture.expected.requests, msg=fixture.label)
    assert_eq(
      @fs.read_file(directory + "/body.bin").binary(),
      body,
      msg=fixture.label,
    )
    let entries = @fs.readdir(directory, sort=true, include_hidden=true)
    entries.sort_by((left, right) => left.lexical_compare(right))
    assert_eq(
      entries,
      ["body.bin", "output"],
      msg=fixture.label + ": entries=" + entries.join(","),
    )
  })
}

///|
async test "all frozen authentication records preserve credential scope, replay and cache transitions" {
  for fixture in authentication_cases() {
    @async.with_timeout(5000, () => check_authentication_case(fixture)) catch {
      error => fail(fixture.label + ": " + error.to_string())
    }
  }
}
