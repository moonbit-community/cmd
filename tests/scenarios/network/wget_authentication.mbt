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
priv struct AuthenticationCase {
  label : String
  args : Array[String]
  urls : Array[String]
  routes : Array[AuthenticationRoute]
  oracle_request_lines : Array[String]
  expected : Json
}

///|
fn authentication_request(
  request : (String, String, String),
  body : Bytes,
  oracle_request_line : String?,
) -> (String, Array[String], String) raise {
  let start = request.0.split(" ").to_array()
  assert_eq(start.length(), 3)
  assert_eq(start[2].to_owned(), "HTTP/1.1")
  assert_eq(request.1, "")
  let host = host_field(request.2, "host").to_lower()
  let target = start[1].to_owned()
  let path = if target.has_prefix("http://") {
    let tail = target[7:]
    let split = tail.find("/").unwrap()
    // Wget's proxy URI can retain URL userinfo. Bind the complete line to
    // the original oracle wire instead of accepting an arbitrary authority.
    assert_eq(Some(request.0), oracle_request_line)
    tail[split:].to_owned()
  } else {
    assert_true(target.has_prefix("/"))
    target
  }
  let authorizations : Array[String] = []
  for line in request.2.split("\r\n") {
    if line.to_owned().to_lower().has_prefix("authorization:") {
      authorizations.push(line[14:].trim().to_owned())
    }
  }
  (
    path,
    authorizations,
    start[0].to_owned() +
    " " +
    host +
    " " +
    path +
    " auth=" +
    authorizations.join("|") +
    " body=" +
    @crypto.bytes_to_hex_string(body),
  )
}

///|
fn authentication_observation(
  request : (String, String, String),
  body : Bytes,
  oracle_request_line : String?,
  wires : Array[(String, Bytes)],
  errors : Array[String],
) -> (String, Array[String], String) raise {
  wires.push((request.2, body))
  let result = Ok(authentication_request(request, body, oracle_request_line)) catch {
    error => Err(error)
  }
  match result {
    Ok(observation) => observation
    Err(error) => {
      errors.push(error.to_string())
      raise error
    }
  }
}

///|
async fn network_wget_authentication_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let corpus = @json.parse(
    @fs.read_file(
      @harness.repository_root() +
      "/tests/fixtures/network/wget-authentication.json",
    ).text(),
  )
  guard corpus is { "schema": 1, "cases": Array(cases), .. } else {
    fail("frozen Wget authentication corpus required")
  }
  assert_eq(cases.length(), 73)
  let file_body = Bytes::from_array([0, 1, 2, 65, 66, 67, 255, 13, 10])
  let failures : Array[String] = []
  for value in cases {
    let fixture : AuthenticationCase = @json.from_json(value)
    guard fixture.expected is { "requests": Array(expected_requests), .. } else {
      fail("frozen authentication observations required")
    }
    assert_eq(fixture.oracle_request_lines.length(), expected_requests.length())
    let directory = work + "/wget-authentication-" + fixture.label
    @fs.mkdir(directory)
    @fs.write_file(directory + "/sentinel", b"unchanged\n")
    @fs.write_file(directory + "/body.bin", file_body)
    if oracle_image is Some(_) {
      @fs.mkdir(directory + "/oracle")
      @fs.write_file(directory + "/oracle/sentinel", b"unchanged\n")
      @fs.write_file(directory + "/oracle/body.bin", file_body)
    }
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let requests : Array[String] = []
      let wires : Array[(String, Bytes)] = []
      let tunnels : Array[String] = []
      let candidate : Array[String] = []
      let candidate_wires : Array[(String, Bytes)] = []
      let candidate_tunnels : Array[String] = []
      let observer_errors : Array[String] = []
      defer @async.protect_from_cancel(() => {
        let trace : Json = {
          "candidate": @json.to_json(candidate_wires),
          "oracle": @json.to_json(wires),
          "candidate_connect": Json(candidate_tunnels),
          "oracle_connect": Json(tunnels),
          "candidate_requests": Json(candidate),
          "oracle_requests": Json(requests),
          "observer_errors": Json(observer_errors),
        }
        @fs.write_file(
          directory + "/requests.wire.json",
          trace.stringify(indent=2) + "\n",
        )
      })
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let mut request = suffix_request(connection)
          if request.0.has_prefix("CONNECT ") {
            tunnels.push(request.2)
            connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
            request = suffix_request(connection)
          }
          let length = host_field(request.2, "content-length")
          let length = if length == "" {
            0
          } else {
            @json.from_json(@json.parse(length))
          }
          let body = if length > 0 {
            connection.read_exactly(length)
          } else {
            b""
          }
          let (path, auth, observed) = authentication_observation(
            request,
            body,
            fixture.oracle_request_lines.get(wires.length()),
            wires,
            observer_errors,
          )
          requests.push(observed)
          guard fixture.routes.iter().find_first(route => route.path == path)
            is Some(route) else {
            fail("unregistered authentication path " + path)
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
          let response = if rejected {
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
            response.length().to_string() +
            "\r\nConnection: close\r\n\r\n" +
            response,
          )
        })
      })
      let observing : Executor = {
        invoke: invocation => {
          let before = @fs.readdir(directory, sort=true, include_hidden=true)
          let execution = (executor.invoke)(invocation)
          candidate.append(requests)
          candidate_wires.append(wires)
          candidate_tunnels.append(tunnels)
          requests.clear()
          wires.clear()
          tunnels.clear()
          assert_eq(
            @fs.readdir(directory, sort=true, include_hidden=true),
            before,
          )
          execution
        },
      }
      let args = ["-qO-", "-t1", ..fixture.args, ..fixture.urls]
      let result = network_request(
        observing,
        directory,
        "wget",
        args,
        oracle_args=["--no-config", "--no-netrc", ..args],
        oracle_image?,
        oracle_failures=failures,
        environment={
          "LC_ALL": "C",
          "NO_PROXY": "",
          "no_proxy": "",
          "http_proxy": "http://127.0.0.1:" + server.addr.port().to_string(),
          "HTTP_PROXY": "",
          "https_proxy": "",
          "HTTPS_PROXY": "",
          "all_proxy": "",
          "ALL_PROXY": "",
        },
      )
      assert_true(observer_errors.is_empty(), msg=observer_errors.join("\n"))
      let observed : Json = {
        "status": Json(result.status),
        "stdout": Json(@harness.scenario_text(result.stdout)),
        "stderr": Json(@harness.scenario_text(result.stderr)),
        "requests": Json(candidate),
      }
      assert_eq(observed, fixture.expected, msg=fixture.label)
      assert_eq(@fs.read_file(directory + "/sentinel").binary(), b"unchanged\n")
      assert_eq(@fs.read_file(directory + "/body.bin").binary(), file_body)
      if oracle_image is Some(_) {
        assert_eq(
          Json(requests),
          Json(expected_requests),
          msg="oracle " + fixture.label,
        )
        assert_eq(
          @fs.readdir(directory + "/oracle", sort=true, include_hidden=true),
          ["body.bin", "sentinel"],
        )
        assert_eq(
          @fs.read_file(directory + "/oracle/sentinel").binary(),
          b"unchanged\n",
        )
        assert_eq(
          @fs.read_file(directory + "/oracle/body.bin").binary(),
          file_body,
        )
      } else {
        assert_true(requests.is_empty())

        @harness.assert_observation(
          "wget-authentication/" + fixture.label,
          "wget",
          observed,
          fixture.expected,
        )
      }
    })
  }
  guard failures.is_empty() else { fail(failures.join("\n")) }
}
