///|
priv struct HostCase {
  label : String
  input : String
  location : String?
  hosts : Array[String]
  targets : Array[String]
  seed : String
}

///|
fn host_field(wire : String, name : String) -> String {
  let values : Array[String] = []
  for line in wire.split("\r\n") {
    if line.to_owned().to_lower().has_prefix(name + ":") {
      values.push(line[name.length() + 1:].trim_start(chars=" \t").to_owned())
    }
  }
  values.join("; ")
}

///|
fn host_cookie(fixture : HostCase, index : Int32) -> String {
  if fixture.label == "mapped-bracket-cookie" {
    if index == 0 {
      "bracket_plain=two"
    } else {
      "bracket_plain=two; new_plain=value"
    }
  } else if fixture.seed != "" &&
    (index == 0 || fixture.label != "cross-origin") {
    "seed=1"
  } else {
    ""
  }
}

///|
fn host_observations(
  requests : Array[(String, String, String)],
  fixture : HostCase,
  command : String,
) -> Json raise {
  assert_eq(requests.length(), fixture.hosts.length())
  let fields : Array[Json] = []
  for index, request in requests {
    let host = fixture.hosts[index]
    let wire_host = if command == "wget" && fixture.label == "mapped-colon" {
      "[" + host + "]"
    } else {
      host
    }
    let proxy_host = if command == "wget" {
      wire_host.replace_all(old="@", new="%40")
    } else {
      wire_host
    }
    guard request.0.strip_prefix("GET ") is Some(target) &&
      target.strip_suffix(" HTTP/1.1") is Some(target) else {
      fail("unexpected IDNA request method or version")
    }
    let target = target
      .strip_prefix("http://" + proxy_host)
      .unwrap_or(target)
      .to_owned()
    // The workspace uses a CONNECT tunnel for HTTP proxies; fixed clients
    // may send absolute form. Validate the complete expected line in either
    // form without reparsing delimiters introduced by hostname mapping.
    assert_true(
      request.0 == "GET " + target + " HTTP/1.1" ||
      request.0 == "GET http://" + proxy_host + target + " HTTP/1.1",
      msg=request.0,
    )
    let authorization = if command == "curl" &&
      index > 0 &&
      ["cross-origin", "mapped-collision"].contains(fixture.label) {
      ""
    } else {
      "Basic dXNlcjpzZWNyZXQ="
    }
    assert_eq(target, fixture.targets[index])
    let cookie = host_cookie(fixture, index)
    assert_eq(host_field(request.2, "host"), wire_host)
    assert_eq(host_field(request.2, "authorization"), authorization)
    assert_eq(request.1, cookie)
    fields.push({
      "host": host_field(request.2, "host"),
      "target": target,
      "authorization": host_field(request.2, "authorization"),
      "cookie": request.1,
    })
  }
  Json(fields)
}

///|
async fn network_idna_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let cases : Array[HostCase] = []
  for
    (label, input, expected) in [
      ("unicode", "bücher.example", "xn--bcher-kva.example"),
      ("decomposed", "bu\u0308cher.example", "xn--bcher-kva.example"),
      ("percent", "b%C3%BCcher.example", "xn--bcher-kva.example"),
      ("sharp-s", "faß.example", "xn--fa-hia.example"),
      ("whole-host-retry", "😀.faß.example", "xn--e28h.fass.example"),
      ("empty-label", "a..bücher.example", "a..xn--bcher-kva.example"),
      ("pinned-category", "\u19da.faß.example", "xn--pkf.xn--fa-hia.example"),
      ("underscore", "_é.faß.example", "xn--_-bga.xn--fa-hia.example"),
      ("mapped-slash", "℀.faß.example", "a/c.xn--fa-hia.example"),
      ("mapped-at", "foo＠bar.example", "foo@bar.example"),
      ("mapped-colon", "foo：80.bü.example", "foo:80.xn--b-eha.example"),
      ("explicit-port", "bücher.example:8080", "xn--bcher-kva.example:8080"),
    ] {
    cases.push({
      label,
      input: "http://" + input + "/start",
      location: None,
      hosts: [expected],
      targets: ["/start"],
      seed: "",
    })
  }
  let seed = "xn--bcher-kva.example\tFALSE\t/\tFALSE\t0\tseed\t1\n"
  cases.append([
    {
      label: "mapped-bracket-cookie",
      input: "http://［127.0.0.1］/start",
      location: Some("/next"),
      hosts: ["[127.0.0.1]", "[127.0.0.1]"],
      targets: ["/start", "/next"],
      seed: "127.0.0.1\tFALSE\t/\tTRUE\t0\tplain_secure\tone\n[127.0.0.1]\tFALSE\t/\tFALSE\t0\tbracket_plain\ttwo\n",
    },
    {
      label: "same-origin-alias",
      input: "http://bücher.example/start",
      location: Some("http://xn--bcher-kva.example/next"),
      hosts: ["xn--bcher-kva.example", "xn--bcher-kva.example"],
      targets: ["/start", "/next"],
      seed,
    },
    {
      label: "cross-origin",
      input: "http://bücher.example/start",
      location: Some("http://other.example/next"),
      hosts: ["xn--bcher-kva.example", "other.example"],
      targets: ["/start", "/next"],
      seed,
    },
    {
      label: "mapped-relative",
      input: "http://℀.faß.example/start",
      location: Some("/next"),
      hosts: ["a/c.xn--fa-hia.example", "a/c.xn--fa-hia.example"],
      targets: ["/start", "/next"],
      seed: "",
    },
    {
      label: "mapped-collision",
      input: "http://℀.example/x",
      location: Some("http://a/c.example/x"),
      hosts: ["a/c.example", "a"],
      targets: ["/x", "/c.example/x"],
      seed: "",
    },
  ])
  let failures : Array[String] = []
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[(String, String, String)] = []
    let tunnels : Array[String] = []
    let location : Ref[String?] = Ref(None)
    let response_cookies = Ref("")
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        let mut request = suffix_request(connection)
        if request.0.has_prefix("CONNECT ") {
          tunnels.push(request.2)
          connection.write("HTTP/1.1 200 Connected\r\n\r\n")
          request = suffix_request(connection)
        }
        requests.push(request)
        if requests.length() == 1 && location.val is Some(target) {
          connection.write(
            "HTTP/1.1 302 Found\r\nLocation: " +
            target +
            "\r\n" +
            response_cookies.val +
            "Content-Length: 0\r\nConnection: close\r\n\r\n",
          )
        } else {
          connection.write(
            "HTTP/1.1 200 OK\r\nContent-Length: 3\r\nConnection: close\r\n\r\nok\n",
          )
        }
      })
    })
    let proxy = "http://127.0.0.1:\{server.addr.port()}"
    for fixture in cases {
      for
        command in (if fixture.label == "mapped-bracket-cookie" {
          ["curl"]
        } else {
          ["curl", "wget"]
        }) {
        let directory = work + "/idna-" + command + "-" + fixture.label
        @fs.mkdir(directory)
        let input = "# Netscape HTTP Cookie File\n" + fixture.seed
        @fs.write_file(directory + "/input.jar", input)
        if oracle_image is Some(_) {
          @fs.mkdir(directory + "/oracle")
          @fs.write_file(directory + "/oracle/input.jar", input)
        }
        location.val = fixture.location
        response_cookies.val = if fixture.label == "mapped-bracket-cookie" {
          "Set-Cookie: new_plain=value; Path=/\r\nSet-Cookie: __Secure-new=value; Path=/; Secure\r\n"
        } else {
          ""
        }
        requests.clear()
        tunnels.clear()
        let candidate : Array[(String, String, String)] = []
        let candidate_tunnels : Array[String] = []
        defer @async.protect_from_cancel(() => {
          @fs.write_file(
            directory + "/requests.wire.json",
            Json({
              "candidate": @json.to_json(candidate),
              "oracle": @json.to_json(requests),
              "candidate_connect": @json.to_json(candidate_tunnels),
              "oracle_connect": @json.to_json(tunnels),
            }).stringify(indent=2),
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
        let args = if command == "curl" {
          [
            "-sL",
            "-u",
            "user:secret",
            "--proxy",
            proxy,
            "-b",
            directory + "/input.jar",
            fixture.input,
          ]
        } else {
          [
            "-qO-",
            "-t1",
            "--local-encoding=UTF-8",
            "--auth-no-challenge",
            "--user=user",
            "--password=secret",
            "--load-cookies=" + directory + "/input.jar",
            fixture.input,
          ]
        }
        if fixture.label == "mapped-bracket-cookie" {
          args.append(["-c", directory + "/saved.jar"])
        }
        // The workspace always tunnels HTTP proxies. Match that route in
        // Curl explicitly: its ordinary forward-proxy URL rewrite can reject
        // mapped delimiters before any request or cookie observation.
        let oracle_args = if command == "curl" {
          [..args, "--proxytunnel"]
        } else {
          args
        }
        let result = network_request(
          observing,
          directory,
          command,
          args,
          environment={
            "LC_ALL": "C.UTF-8",
            "NO_PROXY": "",
            "no_proxy": "",
            "http_proxy": proxy,
            "HTTP_PROXY": proxy,
          },
          oracle_image?,
          oracle_args~,
          oracle_failures=failures,
        )
        check_network_response(result, "ok\n")
        let observed = host_observations(candidate, fixture, command)
        if oracle_image is Some(_) {
          assert_eq(host_observations(requests, fixture, command), observed)
          assert_eq(
            @fs.read_file(directory + "/oracle/input.jar").text(),
            input,
          )
        } else {
          assert_true(requests.is_empty())
        }
        assert_eq(@fs.read_file(directory + "/input.jar").text(), input)
        let bracket_rows = [
          "127.0.0.1\tFALSE\t/\tTRUE\t0\tplain_secure\tone", "[127.0.0.1]\tFALSE\t/\tFALSE\t0\tbracket_plain\ttwo",
          "[127.0.0.1]\tFALSE\t/\tFALSE\t0\tnew_plain\tvalue",
        ]
        let rows = if fixture.label == "mapped-bracket-cookie" {
          let actual = cookie_rows(
            @fs.read_file(directory + "/saved.jar").text(),
          )
          assert_eq(actual, bracket_rows)
          if oracle_image is Some(_) {
            assert_eq(
              cookie_rows(@fs.read_file(directory + "/oracle/saved.jar").text()),
              bracket_rows,
            )
          }
          actual
        } else {
          []
        }
        if oracle_image is None {
          let expected : Array[Json] = []
          for index, host in fixture.hosts {
            expected.push({
              "host": if command == "wget" && fixture.label == "mapped-colon" {
                "[" + host + "]"
              } else {
                host
              },
              "target": fixture.targets[index],
              "authorization": if command == "curl" &&
                index > 0 &&
                ["cross-origin", "mapped-collision"].contains(fixture.label) {
                ""
              } else {
                "Basic dXNlcjpzZWNyZXQ="
              },
              "cookie": host_cookie(fixture, index),
            })
          }
          if fixture.label == "mapped-bracket-cookie" {
            @harness.assert_observation(
              "idna/curl-mapped-bracket-cookie",
              command,
              {
                "status": result.status,
                "stdout": @harness.scenario_text(result.stdout),
                "stderr": @harness.scenario_text(result.stderr),
                "requests": observed,
                "rows": rows,
              },
              {
                "status": 0,
                "stdout": "ok\n",
                "stderr": "",
                "requests": expected,
                "rows": bracket_rows,
              },
            )
          } else {
            @harness.assert_observation(
              "idna/" + command + "-" + fixture.label,
              command,
              {
                "status": result.status,
                "stdout": @harness.scenario_text(result.stdout),
                "stderr": @harness.scenario_text(result.stderr),
                "requests": observed,
              },
              {
                "status": 0,
                "stdout": "ok\n",
                "stderr": "",
                "requests": expected,
              },
            )
          }
        }
      }
    }
  })
  guard failures.is_empty() else { fail(failures.join("\n")) }
}
