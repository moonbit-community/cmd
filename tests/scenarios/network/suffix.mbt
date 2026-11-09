///|
priv struct SuffixCase {
  label : String
  host : String
  target : String
  field : String?
  input : String
  curl_cookie : String
  wget_cookie : String
  curl_rows : Array[String]
}

///|
async fn suffix_request(connection : @socket.Tcp) -> (String, String, String) {
  guard connection.read_until("\r\n") is Some(start) else {
    fail("missing proxy fixture request line")
  }
  let wire = StringBuilder()
  wire.write_string(start + "\r\n")
  let cookies : Array[String] = []
  while connection.read_until("\r\n") is Some(line) && line != "" {
    wire.write_string(line + "\r\n")
    if line.to_lower().has_prefix("cookie:") {
      cookies.push(line[7:].trim_start(chars=" \t").to_owned())
    }
  }
  (start, cookies.join("; "), wire.to_string())
}

///|
async fn network_cookie_suffix_scenario(
  executor : Executor,
  work : String,
  failures : Array[String],
  oracle_image? : String,
) -> Unit {
  let cases : Array[SuffixCase] = []
  for
    (label, host, domain, accepted) in [
      ("icann", "shop.co.uk", "co.uk", false),
      ("private", "tenant.blogspot.com", "blogspot.com", false),
      ("wildcard-child", "a.test.ck", "test.ck", false),
      ("wildcard-base", "a.kawasaki.jp", "kawasaki.jp", false),
      ("exception", "a.city.kawasaki.jp", "city.kawasaki.jp", true),
      ("exception-ck", "a.www.ck", "www.ck", true),
      ("noncontiguous", "forgot.his.name", "his.name", false),
      ("noncontiguous-positive", "other.his.name", "his.name", true),
      ("unknown-suffix", "a.unknown", "unknown", false),
      ("unknown-registrable", "a.b.unknown", "b.unknown", true),
      ("alabel", "a.xn--55qx5d.cn", "xn--55qx5d.cn", false),
      ("mixed-case", "a.example.com", "EXAMPLE.COM", true),
      ("multiple-dots", "x..co.uk", "..co.uk", false),
      ("trailing-dot", "a.co.uk.", "co.uk.", false),
      ("current-private", "tenant.0g0.jp", "0g0.jp", false),
    ] {
    cases.push({
      label,
      host,
      target: host,
      field: Some("sid=v; Domain=" + domain + "; Path=/"),
      input: "",
      curl_cookie: if accepted {
        "sid=v"
      } else {
        ""
      },
      wget_cookie: if accepted || label == "trailing-dot" {
        "sid=v"
      } else {
        ""
      },
      curl_rows: if accepted {
        ["." + domain + "\tTRUE\t/\tFALSE\t0\tsid\tv"]
      } else {
        []
      },
    })
  }
  for
    (label, host, target) in [
      ("exact-same", "co.uk", "co.uk"),
      ("exact-child", "co.uk", "child.co.uk"),
      ("exact-private-child", "blogspot.com", "child.blogspot.com"),
    ] {
    cases.push({
      label,
      host,
      target,
      field: Some("sid=v; Domain=" + host + "; Path=/"),
      input: "",
      curl_cookie: if host == target {
        "sid=v"
      } else {
        ""
      },
      wget_cookie: "sid=v",
      curl_rows: [host + "\tFALSE\t/\tFALSE\t0\tsid\tv"],
    })
  }
  for
    (label, domain, host) in [
      ("jar-icann", "co.uk", "a.co.uk"),
      ("jar-private", "blogspot.com", "a.blogspot.com"),
      ("jar-wildcard", "test.ck", "a.test.ck"),
    ] {
    cases.push({
      label,
      host,
      target: host,
      field: None,
      input: "." + domain + "\tTRUE\t/\tFALSE\t0\tsid\tv\n",
      curl_cookie: "",
      wget_cookie: "sid=v",
      curl_rows: [],
    })
  }
  cases.push({
    label: "invalid-deletion",
    host: "shop.co.uk",
    target: "shop.co.uk",
    field: Some("sid=; Domain=co.uk; Path=/; Max-Age=0"),
    input: ".co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n",
    curl_cookie: "",
    wget_cookie: "",
    curl_rows: [],
  })
  for
    (label, host, domain) in [
      ("invalid-update", "shop.co.uk", "co.uk"),
      ("private-update", "tenant.blogspot.com", "blogspot.com"),
    ] {
    cases.push({
      label,
      host,
      target: host,
      field: Some("sid=new; Domain=" + domain + "; Path=/"),
      input: "." + domain + "\tTRUE\t/\tFALSE\t0\tsid\told\n",
      curl_cookie: "",
      wget_cookie: "",
      curl_rows: [],
    })
  }
  cases.push({
    label: "foreign-domain-discard",
    host: "shop.co.uk",
    target: "victim.example",
    field: Some("sid=new; Domain=victim.example; Path=/"),
    input: ".victim.example\tTRUE\t/\tFALSE\t0\tsid\told\n",
    curl_cookie: "sid=old",
    wget_cookie: "",
    curl_rows: [".victim.example\tTRUE\t/\tFALSE\t0\tsid\told"],
  })
  cases.push({
    label: "path-rejection",
    host: "shop.co.uk",
    target: "shop.co.uk/blocked",
    field: Some("sid=; Domain=co.uk; Path=/blocked; Max-Age=0"),
    input: ".co.uk\tTRUE\t/blocked\tFALSE\t0\tsid\told\n",
    curl_cookie: "",
    wget_cookie: "sid=old",
    curl_rows: [],
  })
  cases.push({
    label: "jar-leading-dots",
    host: "localhost",
    target: "localhost",
    field: None,
    input: ".localhost\tFALSE\t/\tFALSE\t0\tone\tv\n" +
    "..localhost\tFALSE\t/\tFALSE\t0\ttwo\tv\n" +
    "...localhost\tFALSE\t/\tFALSE\t0\tthree\tv\n" +
    "..example.com\tFALSE\t/\tFALSE\t0\tfour\tv\n",
    curl_cookie: "one=v",
    wget_cookie: "",
    curl_rows: [
      "localhost\tFALSE\t/\tFALSE\t0\tone\tv", "..localhost\tFALSE\t/\tFALSE\t0\tthree\tv",
      ".example.com\tFALSE\t/\tFALSE\t0\tfour\tv",
    ],
  })
  cases.push({
    label: "wget-repeated-dot-discard",
    host: "x...co.uk",
    target: "x...co.uk",
    field: Some("sid=; Domain=...co.uk; Path=/; Max-Age=0"),
    input: "...co.uk\tTRUE\t/\tFALSE\t0\tsid\told\n",
    curl_cookie: "",
    wget_cookie: "",
    curl_rows: [],
  })
  cases.push({
    label: "jar-invalid-ip",
    host: "localhost",
    target: "localhost",
    field: None,
    input: "::0x1\tFALSE\t/\tFALSE\t0\tone\tv\n::1_2\tFALSE\t/\tFALSE\t0\ttwo\tv\n",
    curl_cookie: "",
    wget_cookie: "",
    curl_rows: [],
  })
  cases.push({
    label: "reload-exact",
    host: "co.uk",
    target: "co.uk",
    field: None,
    input: "",
    curl_cookie: "",
    wget_cookie: "",
    curl_rows: [],
  })
  cases.push({
    label: "reload-exception",
    host: "a.city.kawasaki.jp",
    target: "a.city.kawasaki.jp",
    field: None,
    input: "",
    curl_cookie: "sid=v",
    wget_cookie: "",
    curl_rows: [".city.kawasaki.jp\tTRUE\t/\tFALSE\t0\tsid\tv"],
  })
  for
    (label, host, field, input, cookie, row) in [
      (
        "case-jar",
        "a.example.com",
        None,
        ".EXAMPLE.COM\tTRUE\t/\tFALSE\t0\tsid\tv\n",
        "sid=v",
        ".EXAMPLE.COM\tTRUE\t/\tFALSE\t0\tsid\tv",
      ),
      (
        "case-replacement",
        "a.example.com",
        Some("sid=new; Domain=eXample.com; Path=/"),
        ".EXAMPLE.COM\tTRUE\t/\tFALSE\t0\tsid\told\n",
        "sid=new",
        ".eXample.com\tTRUE\t/\tFALSE\t0\tsid\tnew",
      ),
      (
        "case-overlay",
        "a.example.com",
        Some("sid=plain; Domain=example.com; Path=/"),
        ".EXAMPLE.COM\tTRUE\t/\tTRUE\t0\tsid\tsecure\n",
        "",
        ".EXAMPLE.COM\tTRUE\t/\tTRUE\t0\tsid\tsecure",
      ),
      (
        "case-host",
        "A.Example.com",
        Some("sid=v; Path=/"),
        "",
        "sid=v",
        "A.Example.com\tFALSE\t/\tFALSE\t0\tsid\tv",
      ),
    ] {
    cases.push({
      label,
      host,
      target: "a.example.com",
      field,
      input,
      curl_cookie: cookie,
      wget_cookie: "",
      curl_rows: [row],
    })
  }
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let field : Ref[String?] = Ref(None)
    let target = Ref("")
    let requests : Array[(String, String, String)] = []
    let tunnels : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        let mut request = suffix_request(connection)
        if request.0.has_prefix("CONNECT ") {
          tunnels.push(request.2)
          connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
          request = suffix_request(connection)
        }
        requests.push(request)
        if request.0.contains("/set ") {
          connection.write(
            "HTTP/1.1 302 Found\r\nLocation: http://" +
            target.val +
            "/inspect\r\n" +
            (match field.val {
              Some(field) => "Set-Cookie: " + field + "\r\n"
              None => ""
            }) +
            "Content-Length: 0\r\nConnection: close\r\n\r\n",
          )
        } else {
          let body = "cookie=" + request.1 + "\n"
          connection.write(
            "HTTP/1.1 200 OK\r\nContent-Length: \{body.length()}\r\nConnection: close\r\n\r\n" +
            body,
          )
        }
      })
    })
    let proxy = "http://127.0.0.1:\{server.addr.port()}"
    for fixture in cases {
      let commands = if fixture.label.has_prefix("wget-") {
        ["wget"]
      } else if [
          "jar-leading-dots", "jar-invalid-ip", "reload-exact", "reload-exception",
        ].contains(fixture.label) ||
        fixture.label.has_prefix("case-") {
        ["curl"]
      } else {
        ["curl", "wget"]
      }
      for command in commands {
        let directory = work + "/cookie-suffix-" + command + "-" + fixture.label
        @fs.mkdir(directory)
        let reload_source = match fixture.label {
          "reload-exact" => Some(work + "/cookie-suffix-curl-exact-same")
          "reload-exception" => Some(work + "/cookie-suffix-curl-exception")
          _ => None
        }
        let input = match reload_source {
          Some(source) => @fs.read_file(source + "/saved.jar").text()
          None => "# Netscape HTTP Cookie File\n" + fixture.input
        }
        @fs.write_file(directory + "/input.jar", input)
        if oracle_image is Some(_) {
          @fs.mkdir(directory + "/oracle")
          @fs.write_file(
            directory + "/oracle/input.jar",
            match reload_source {
              Some(source) => @fs.read_file(source + "/oracle/saved.jar").text()
              None => input
            },
          )
        }
        field.val = fixture.field
        target.val = fixture.target
        requests.clear()
        tunnels.clear()
        let candidate : Array[(String, String, String)] = []
        let candidate_tunnels : Array[String] = []
        defer @async.protect_from_cancel(() => {
          let wires : Json = {
            "candidate": @json.to_json(candidate),
            "oracle": @json.to_json(requests),
            "candidate_connect": @json.to_json(candidate_tunnels),
            "oracle_connect": @json.to_json(tunnels),
          }
          @fs.write_file(
            directory + "/requests.wire.json",
            wires.stringify(indent=2),
          )
        })
        let observing : Executor = {
          invoke: invocation => {
            let execution = (executor.invoke)(invocation)
            candidate.append(requests)
            candidate_tunnels.append(tunnels)
            requests.clear()
            tunnels.clear()
            execution
          },
        }
        let url = "http://" + fixture.host + "/set"
        let args = if command == "curl" {
          [
            "-sSL",
            "--proxy",
            proxy,
            "-b",
            directory + "/input.jar",
            "-c",
            directory + "/saved.jar",
            url,
          ]
        } else {
          ["-qO-", "-t1", "--load-cookies=" + directory + "/input.jar", url]
        }
        let result = network_request(
          observing,
          directory,
          command,
          args,
          environment={
            "LC_ALL": "C",
            "NO_PROXY": "",
            "no_proxy": "",
            "http_proxy": proxy,
            "HTTP_PROXY": proxy,
          },
          trace_suffix=command == "curl" || fixture.field is Some(_),
          oracle_image?,
          oracle_failures=failures,
        )
        let expected_cookie = if command == "curl" {
          fixture.curl_cookie
        } else {
          fixture.wget_cookie
        }
        check_network_response(result, "cookie=" + expected_cookie + "\n")
        assert_eq(candidate.length(), 2, msg=command + " " + fixture.label)
        assert_eq(candidate[1].1, expected_cookie)
        assert_eq(
          requests.length(),
          if oracle_image is Some(_) {
            2
          } else {
            0
          },
        )
        if oracle_image is Some(_) {
          assert_eq(
            requests[1].1,
            expected_cookie,
            msg="oracle " + command + " " + fixture.label,
          )
          assert_eq(
            @fs.read_file(directory + "/oracle/input.jar").text(),
            match reload_source {
              Some(source) => @fs.read_file(source + "/oracle/saved.jar").text()
              None => input
            },
          )
        }
        assert_eq(@fs.read_file(directory + "/input.jar").text(), input)
        let rows = if command == "curl" {
          cookie_rows(@fs.read_file(directory + "/saved.jar").text())
        } else {
          []
        }
        let expected_rows = if command == "curl" {
          fixture.curl_rows.copy()
        } else {
          []
        }
        expected_rows.sort_by((left, right) => left.lexical_compare(right))
        assert_eq(rows, expected_rows, msg=command + " " + fixture.label)
        if command == "curl" && oracle_image is Some(_) {
          assert_eq(
            cookie_rows(@fs.read_file(directory + "/oracle/saved.jar").text()),
            expected_rows,
            msg="oracle " + fixture.label,
          )
        }
        if oracle_image is None {
          @harness.assert_observation(
            "cookie-suffix/" + command + "-" + fixture.label,
            command,
            {
              "status": result.status,
              "stdout": @harness.scenario_text(result.stdout),
              "stderr": @harness.scenario_text(result.stderr),
              "requests": candidate.length(),
              "cookie": candidate[1].1,
              "rows": rows,
            },
            {
              "status": 0,
              "stdout": "cookie=" + expected_cookie + "\n",
              "stderr": "",
              "requests": 2,
              "cookie": expected_cookie,
              "rows": expected_rows,
            },
          )
        }
      }
    }
  })
}
