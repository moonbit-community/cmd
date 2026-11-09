///|
test "transfer replay rejects changed request effects and missing exchanges" {
  let origin = "GET /retry HTTP/1.1"
  let fields = "\r\nHost: retry.example\r\nCookie: sid=old\r\n"
  let tunnel = "CONNECT retry.example:80 HTTP/1.1\r\nHost: 127.0.0.1:8123\r\n"
  let exchanges : Array[Json] = [
    {
      "request_line": "GET http://retry.example/retry HTTP/1.1",
      "host_fields": ["Host: retry.example"],
      "cookie": "sid=old",
      "cookie_fields": ["Cookie: sid=old"],
    },
  ]
  transfer_check_requests(
    [(origin, "sid=old", origin + fields)],
    [tunnel],
    exchanges,
    candidate=true,
    proxy_authority="127.0.0.1:8123",
  )
  for
    (requests, tunnels) in [
      ([], []),
      ([(origin, "sid=new", origin + fields)], [tunnel]),
      ([("GET /wrong HTTP/1.1", "sid=old", origin + fields)], [tunnel]),
      (
        [(origin, "sid=old", origin + fields + "Host: retry.example\r\n")],
        [tunnel],
      ),
      (
        [
          (
            origin,
            "sid=old",
            origin + fields + "Authorization: Basic changed\r\n",
          ),
        ],
        [tunnel],
      ),
      ([(origin, "sid=old", origin + fields)], []),
      ([(origin, "sid=old", origin + fields + "Authorization:\r\n")], [tunnel]),
      (
        [(origin, "sid=old", origin + fields)],
        ["CONNECT other.example:80 HTTP/1.1\r\nHost: 127.0.0.1:8123\r\n"],
      ),
      (
        [
          (origin, "sid=old", origin + fields),
          (origin, "sid=old", origin + fields),
        ],
        [tunnel, tunnel],
      ),
    ] {
    let accepted = try {
      transfer_check_requests(
        requests,
        tunnels,
        exchanges,
        candidate=true,
        proxy_authority="127.0.0.1:8123",
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}

///|
test "transfer replay distinguishes absent and empty Cookie fields" {
  let expected : Array[Json] = [
    {
      "request_line": "GET http://retry.example/retry HTTP/1.1",
      "host_fields": ["Host: retry.example"],
      "cookie": "",
      "cookie_fields": [],
    },
  ]
  let start = "GET http://retry.example/retry HTTP/1.1"
  let headers = start + "\r\nHost: retry.example\r\n"
  transfer_check_requests(
    [(start, "", headers)],
    [],
    expected,
    candidate=false,
    proxy_authority="unused",
  )
  for field in ["Cookie:\r\n", "Authorization:\r\n"] {
    let accepted = try {
      transfer_check_requests(
        [(start, "", headers + field)],
        [],
        expected,
        candidate=false,
        proxy_authority="unused",
      )
      true
    } catch {
      _ => false
    }
    assert_false(accepted)
  }
}

///|
test "transfer replay preserves nested file bytes and requires complete snapshots" {
  let expected : Json = [
    {
      "name": "output",
      "kind": "directory",
      "entries": [{ "name": "inner", "hex": "00ff" }],
    },
  ]
  assert_eq(transfer_expected_files(expected), expected)
  for
    other in [
      ([{ "name": "output", "hex": "00ff" }] : Json),
      ([{ "name": "output", "kind": "directory", "entries": [] }] : Json),
      (
        [
          {
            "name": "output",
            "kind": "directory",
            "entries": [{ "name": "inner", "hex": "00fe" }],
          },
        ] : Json),
    ] {
    assert_true(transfer_expected_files(other) != expected)
  }
  let accepted = try {
    ignore(transfer_phase_expected({ "files_after_complete": false }))
    true
  } catch {
    _ => false
  }
  assert_false(accepted)
}

///|
async test "cancelled transfer replay retains candidate wire after observers stop" {
  let work = @fs.tmpdir(prefix="mooncmd-replay-cancel-")
  defer @fs.rmdir(work, recursive=true)
  let entered = Ref(false)
  let executor : Executor = {
    proof: None,
    invoke: invocation => {
      let authority = invocation.environment["http_proxy"]
        .strip_prefix("http://")
        .unwrap()
        .to_owned()
      let connection = @socket.Tcp::connect(@socket.Addr::parse(authority))
      defer connection.close()
      connection.write(
        "CONNECT retry.example:80 HTTP/1.1\r\nHost: " + authority + "\r\n\r\n",
      )
      assert_eq(
        connection.read_until("\r\n"),
        Some("HTTP/1.1 200 Connection Established"),
      )
      assert_eq(connection.read_until("\r\n"), Some(""))
      connection.write("GET /retry HTTP/1.1\r\nHost: retry.example\r\n\r\n")
      entered.val = true
      @async.sleep(10000)
      fail("cancelled test executor must never return")
    },
  }
  let completed = @async.with_timeout_opt(500, () => {
    network_curl_transfers_scenario(executor, work, corpus="curl-http-retry")
  })
  assert_true(completed is None)
  assert_true(entered.val)
  let evidence = work + "/budget-expired-complete-503-without-fail.evidence"
  let path = evidence + "/phase-0.wire.json"
  let bytes = @fs.read_file(path).binary()
  let wire = transfer_object(@json.parse(@utf8.decode(bytes)))
  assert_eq(transfer_array(wire["candidate"]).length(), 1)
  assert_eq(transfer_array(wire["candidate_connect"]).length(), 1)
  assert_eq(transfer_array(wire["candidate_files_before_response"]).length(), 1)
  assert_true(transfer_array(wire["candidate_responses"]).is_empty())
  assert_true(transfer_array(wire["oracle"]).is_empty())
  assert_true(transfer_array(wire["oracle_responses"]).is_empty())
  assert_eq(wire["candidate_returned"], Json(false))
  assert_eq(wire["observer_quiesced"], Json(true))
  let names = @fs.readdir(evidence)
  assert_false(
    names.any(name => {
      name.has_suffix(".execution.json") || name.has_suffix(".status.txt")
    }),
  )
  let ends = names.filter(name => name.has_suffix(".invocation-end.json"))
  assert_eq(ends.length(), 1)
  assert_true(
    @json.parse(@fs.read_file(evidence + "/" + ends[0]).text())
    is { "returned": false, .. },
  )
  @async.sleep(50)
  assert_eq(@fs.read_file(path).binary(), bytes)
}
