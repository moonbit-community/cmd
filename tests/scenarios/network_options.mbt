///|
async fn network_options_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let observed : Array[Json] = []
    let headers : Array[Json] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, body, connection) => {
        let payload = body.read_all().text()
        headers.push({
          "marker": request.headers.get("X-Marker").unwrap_or(""),
          "agent": request.headers.get("User-Agent").unwrap_or(""),
        })
        observed.push({
          "path": request.path,
          "method": @harness.oracle_request_name(request),
          "body": payload,
          "auth": request.headers.get("Authorization").unwrap_or(""),
        })
        match request.path {
          "/denied" =>
            connection
            ..send_response(403, "Forbidden", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/redirect/0" | "/redirect/1" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Content-Length": "0",
              "Location": if request.path == "/redirect/0" {
                "/redirect/1"
              } else {
                "/fixed"
              },
            })
            .end_response()
          _ =>
            connection
            ..send_response(200, "OK", extra_headers={ "Content-Length": "5" })
            ..write("hello")
            .end_response()
        }
      })
    })
    let base = "http://127.0.0.1:\{server.addr.port()}"
    for
      (label, args, expected_request) in [
        (
          "data-urlencode",
          ["-sS", "--data-urlencode", "name=a b&é", base + "/inspect"],
          (
            {
              "path": "/inspect",
              "method": "POST",
              "body": "name=a%20b%26%C3%A9",
              "auth": "",
            } : Json),
        ),
        (
          "basic",
          ["-sS", "--basic", "-u", "user:pass", base + "/inspect"],
          (
            {
              "path": "/inspect",
              "method": "GET",
              "body": "",
              "auth": "Basic dXNlcjpwYXNz",
            } : Json),
        ),
      ] {
      observed.clear()
      let result = scenario_run(work, root, "curl", args, cwd=work, extra_env={
        "NO_PROXY": "*",
        "no_proxy": "*",
      })
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "requests": Json(observed),
      }
      let expected : Json = {
        "status": 0,
        "stdout": "hello",
        "stderr": "",
        "requests": [expected_request],
      }
      assert_eq(actual, expected)
      if proof is Some(proof) {
        proof.observe_equal("curl/" + label, "curl", actual, expected)
      }
    }
    for command in ["curl", "wget"] {
      observed.clear()
      headers.clear()
      let args = if command == "curl" {
        [
          "-sS",
          "-H",
          "X-Marker: first",
          "-H",
          "X-Marker: second",
          "-H",
          "User-Agent: coverage",
          base + "/inspect",
        ]
      } else {
        [
          "-qO-",
          "--header=X-Marker: first",
          "--header=X-Marker: second",
          "--header=User-Agent: coverage",
          base + "/inspect",
        ]
      }
      let result = scenario_run(work, root, command, args, cwd=work, extra_env={
        "NO_PROXY": "*",
        "no_proxy": "*",
      })
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "headers": Json(headers),
        "requests": observed.length(),
      }
      let expected : Json = {
        "status": 0,
        "stdout": "hello",
        "stderr": "",
        "headers": [{ "marker": "second", "agent": "coverage" }],
        "requests": 1,
      }
      assert_eq(actual, expected)
      if proof is Some(proof) {
        proof.observe_equal(
          command + "/header-replacement",
          command,
          actual,
          expected,
        )
      }
    }
    for append in [false, true] {
      observed.clear()
      let path = work + (if append { "/append.log" } else { "/replace.log" })
      @fs.write_file(path, "old log\n")
      let result = scenario_run(
        work,
        root,
        "wget",
        [
          "-t1",
          "-O",
          "-",
          if append {
            "--append-output"
          } else {
            "--output-file"
          },
          path,
          base + "/denied",
        ],
        cwd=work,
        extra_env={ "NO_PROXY": "*", "no_proxy": "*" },
      )
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "log": @fs.read_file(path).text(),
        "requests": observed.length(),
      }
      let expected : Json = {
        "status": 8,
        "stdout": "",
        "stderr": "",
        "log": (if append { "old log\n" } else { "" }) +
        "--  " +
        base +
        "/denied\nHTTP request sent, awaiting response... 403 Forbidden\nLength: 0\nSaving to: 'stdout'\nwget: server returned HTTP status 403 Forbidden\n",
        "requests": 1,
      }
      assert_eq(actual, expected)
      if proof is Some(proof) {
        let normalized_actual : Json = {
          "status": result.status,
          "stdout": @harness.scenario_text(result.stdout),
          "stderr": @harness.scenario_text(result.stderr),
          "log_exact": actual == expected,
          "requests": observed.length(),
        }
        proof.observe_equal(
          "wget/" + (if append { "append-output" } else { "output-file" }),
          "wget",
          normalized_actual,
          {
            "status": 8,
            "stdout": "",
            "stderr": "",
            "log_exact": true,
            "requests": 1,
          },
        )
      }
    }
    for limit in [1, 2] {
      observed.clear()
      let result = scenario_run(
        work,
        root,
        "wget",
        [
          "-q",
          "-t1",
          "-O",
          "-",
          "--max-redirect=" + limit.to_string(),
          base + "/redirect/0",
        ],
        cwd=work,
        extra_env={ "NO_PROXY": "*", "no_proxy": "*" },
      )
      let paths = observed.map(row => {
        if row is Object(fields) {
          fields["path"]
        } else {
          Json::null()
        }
      })
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "paths": Json(paths),
      }
      let expected : Json = {
        "status": if limit == 1 {
          7
        } else {
          0
        },
        "stdout": if limit == 1 {
          ""
        } else {
          "hello"
        },
        "stderr": "",
        "paths": Json(
          if limit == 1 {
            ["/redirect/0", "/redirect/1"]
          } else {
            ["/redirect/0", "/redirect/1", "/fixed"]
          },
        ),
      }
      assert_eq(actual, expected)
      if proof is Some(proof) {
        proof.observe_equal(
          "wget/redirect-" + limit.to_string(),
          "wget",
          actual,
          expected,
        )
      }
    }
    let proxy = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => proxy.close())
    let proxy_count = Ref(0)
    let targets : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      run_connect_proxy(proxy, proxy_count, targets~)
    })
    let proxy_url = "http://127.0.0.1:\{proxy.addr.port()}"
    for (command, bypass) in [("curl", false), ("wget", false), ("wget", true)] {
      observed.clear()
      targets.clear()
      proxy_count.val = 0
      let args = if command == "curl" {
        ["-sS", "--proxy", proxy_url, "--noproxy", "", base + "/fixed"]
      } else {
        [
          "-q",
          "-t1",
          "-O",
          "-",
          ..if bypass {
            ["--no-proxy"]
          } else {
            []
          },
          base + "/fixed",
        ]
      }
      let result = scenario_run(work, root, command, args, cwd=work, extra_env={
        "NO_PROXY": "",
        "no_proxy": "",
        "http_proxy": proxy_url,
        "HTTP_PROXY": proxy_url,
      })
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "proxy_requests": proxy_count.val,
        "target": targets ==
        (if bypass { [] } else { ["127.0.0.1:\{server.addr.port()}"] }),
        "origin_requests": observed.length(),
      }
      let expected : Json = {
        "status": 0,
        "stdout": "hello",
        "stderr": "",
        "proxy_requests": if bypass {
          0
        } else {
          1
        },
        "target": true,
        "origin_requests": 1,
      }
      assert_eq(actual, expected)
      if proof is Some(proof) {
        proof.observe_equal(
          command + "/" + (if bypass { "no-proxy" } else { "proxy" }),
          command,
          actual,
          expected,
        )
      }
    }
  })
}
