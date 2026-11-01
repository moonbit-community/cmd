///|
fn check_network_response(
  result : @harness.RunResult,
  expected : String,
) -> Unit raise {
  assert_eq(result.status, 0)
  assert_true(@harness.bytes_equal(result.stdout, @utf8.encode(expected)))
  assert_eq(result.stderr, b"")
}

///|
/// Stateful CLI coverage previously driven by core/netops/verify_cli.mbtx.
/// One loopback fixture serves all rounds; no installed curl/wget is needed.
async fn network_cli_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let oracle_failures : Array[String] = []
  @async.with_task_group <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[(String, String?)] = []
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _, connection) => {
        requests.push((request.path, request.headers.get("Authorization")))
        match request.path {
          "/auth" if request.headers.get("Authorization") is None =>
            connection
            ..send_response(401, "Unauthorized", extra_headers={
              "WWW-Authenticate": "Basic realm=\"local\"",
              "Content-Length": "0",
            })
            .end_response()
          "/cross" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "http://localhost:\{server.addr.port()}/inspect",
              "Content-Length": "0",
            })
            .end_response()
          "/cross-auth" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "http://localhost:\{server.addr.port()}/auth",
              "Content-Length": "0",
            })
            .end_response()
          "/set" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("sid", "fixture", path="/")],
            )
            .end_response()
          "/set-path" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("private", "hidden", path="/private")],
            )
            .end_response()
          "/set-domain" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[
                @http.Cookie(
                  "foreign",
                  "hidden",
                  domain="example.invalid",
                  path="/",
                ),
              ],
            )
            .end_response()
          "/set-expired" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("expired", "hidden", path="/", max_age=0L)],
            )
            .end_response()
          _ => {
            let body = "auth=" +
              request.headers.get("Authorization").unwrap_or("") +
              "\ncookie=" +
              request.headers.get("Cookie").unwrap_or("") +
              "\n"
            connection
            ..send_response(200, "OK", extra_headers={
              "Content-Length": body.length().to_string(),
            })
            ..write(body)
            .end_response()
          }
        }
      })
    }
    let base = "http://127.0.0.1:\{server.addr.port()}"
    // The allocated listener origin is the only network normalization used
    // when comparing this scenario's independently isolated backend fixtures.
    @fs.write_file(work + "/../network-origin.txt", base)
    let cases : Array[(String, Array[String], String, Int32)] = [
      (
        "curl",
        ["-sS", "-u", "user:pass", base + "/inspect"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "curl",
        [
          "-sS",
          "-u",
          "user:pass",
          "http://wrong:bad@127.0.0.1:\{server.addr.port()}/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "curl",
        ["-sS", "-b", "sid=explicit", base + "/inspect"],
        "auth=\ncookie=sid=explicit\n",
        1,
      ),
      (
        "curl",
        ["-sS", "-b", "sid=first", "-b", "sid=last", base + "/inspect"],
        "auth=\ncookie=sid=first; sid=last\n",
        1,
      ),
      (
        "curl",
        ["-sSL", "-b", "", base + "/set"],
        "auth=\ncookie=sid=fixture\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-b", "sid=explicit", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-H", "Cookie: sid=header", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-u", "user:pass", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "wget",
        ["-qO-", "--user=user", "--password=pass", base + "/auth"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        2,
      ),
      (
        "wget",
        [
          "-qO-",
          "--http-user=user",
          "--http-password=pass",
          "--auth-no-challenge",
          base + "/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "wget",
        [
          "-qO-",
          "--user=user",
          "--password=pass",
          "--auth-no-challenge",
          base + "/cross",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        2,
      ),
      (
        "wget",
        ["-qO-", "--user=user", "--password=pass", base + "/cross-auth"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        3,
      ),
      ("wget", ["-qO-", "--no-cookies", base + "/set"], "auth=\ncookie=\n", 2),
      (
        "wget",
        ["-qO-", "--http-user=user", "--http-password=pass", base + "/inspect"],
        "auth=\ncookie=\n",
        1,
      ),
      (
        "wget",
        [
          "-qO-",
          "--http-user=user",
          "--http-password=pass",
          "--auth-no-challenge",
          base + "/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
    ]
    for index, (command, args, expected, request_count) in cases {
      let before = requests.length()
      let result = network_request(
        executor,
        work,
        command,
        args,
        oracle_image?,
        oracle_failures~,
      )
      check_network_response(result, expected)
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "auth/" + index.to_string(),
          command,
          {
            "status": result.status,
            "stdout": @harness.scenario_text(result.stdout),
            "stderr": @harness.scenario_text(result.stderr),
            "requests": requests.length() - before,
          },
          {
            "status": 0,
            "stdout": expected,
            "stderr": "",
            "requests": request_count,
          },
        )
      }
      assert_eq(
        requests.length() - before,
        request_count * (if oracle_image is Some(_) { 2 } else { 1 }),
      )
      if command == "wget" && args.contains(base + "/auth") {
        assert_eq(requests[before].1, None)
        assert_eq(requests[before + 1].1, Some("Basic dXNlcjpwYXNz"))
      }
    }
    for command in ["curl", "wget"] {
      let jar = work + "/" + command + ".cookies"
      let save = if command == "curl" {
        ["-sSL", "-c", jar, base + "/set"]
      } else {
        [
          "-qO-",
          "--save-cookies=" + jar,
          "--keep-session-cookies",
          base + "/set",
        ]
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          save,
          oracle_image?,
          oracle_failures~,
        ),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_true(@fs.read_file(jar).text().contains("\tsid\tfixture"))
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/saved",
          command,
          Json(@fs.read_file(jar).text().contains("\tsid\tfixture")),
          Json(true),
        )
      }
      let load = if command == "curl" {
        ["-sS", "-b", jar, base + "/inspect"]
      } else {
        ["-qO-", "--load-cookies=" + jar, base + "/inspect"]
      }
      let loaded = network_request(
        executor,
        work,
        command,
        load,
        oracle_image?,
        oracle_failures~,
      )
      check_network_response(loaded, "auth=\ncookie=sid=fixture\n")
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/loaded",
          command,
          {
            "status": loaded.status,
            "stdout": @harness.scenario_text(loaded.stdout),
            "stderr": @harness.scenario_text(loaded.stderr),
          },
          { "status": 0, "stdout": "auth=\ncookie=sid=fixture\n", "stderr": "" },
        )
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          if command == "curl" {
            ["-sS", "-b", jar, "-H", "Cookie: sid=header", base + "/inspect"]
          } else {
            [
              "-qO-",
              "--load-cookies=" + jar,
              "--header=Cookie: sid=header",
              base + "/inspect",
            ]
          },
          oracle_image?,
          oracle_failures~,
        ),
        if command == "curl" {
          // The HTTP fixture joins repeated wire fields with a comma.
          "auth=\ncookie=sid=fixture,sid=header\n"
        } else {
          "auth=\ncookie=sid=header\n"
        },
      )
      if command == "curl" {
        check_network_response(
          network_request(
            executor,
            work,
            command,
            ["-sS", "-b", jar, "-b", "sid=manual", base + "/inspect"],
            oracle_image?,
            oracle_failures~,
          ),
          "auth=\ncookie=sid=fixture; sid=manual\n",
        )
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          if command == "curl" {
            ["-sSL", "-b", jar, "-H", "Cookie: sid=header", base + "/cross"]
          } else {
            [
              "-qO-",
              "--load-cookies=" + jar,
              "--header=Cookie: sid=header",
              base + "/cross",
            ]
          },
          oracle_image?,
          oracle_failures~,
        ),
        if command == "curl" {
          "auth=\ncookie=\n"
        } else {
          "auth=\ncookie=sid=header\n"
        },
      )
      if !(@async.platform is Windows) {
        // Match the jar's requested creation mode so both files observe the
        // process's real umask, including group-writable configurations.
        let control = work + "/mode-control-" + command
        @fs.write_file(control, "", permission=0o666)
        let stat_args = if @async.platform is MacOS {
          ["-f", "%Lp"]
        } else {
          ["-c", "%a"]
        }
        let actual_mode = @harness.run("stat", [..stat_args, jar], stdin=b"")
        let control_mode = @harness.run(
          "stat",
          [..stat_args, control],
          stdin=b"",
        )
        assert_eq(actual_mode.status, 0)
        assert_eq(control_mode.status, 0)
        assert_eq(actual_mode.stdout, control_mode.stdout)
        if oracle_image is Some(_) {
          let oracle_mode = @harness.run(
            "stat",
            [..stat_args, work + "/oracle/" + command + ".cookies"],
            stdin=b"",
          )
          assert_eq(oracle_mode.status, 0)
          if actual_mode.stdout != oracle_mode.stdout {
            oracle_failures.push(
              command +
              " cookie jar mode differs: " +
              @utf8.decode(actual_mode.stdout) +
              " != " +
              @utf8.decode(oracle_mode.stdout),
            )
          }
        }
      }
      for endpoint in ["set-path", "set-domain", "set-expired"] {
        let args = if command == "curl" {
          ["-sSL", "-b", "", base + "/" + endpoint]
        } else {
          ["-qO-", base + "/" + endpoint]
        }
        check_network_response(
          network_request(
            executor,
            work,
            command,
            args,
            oracle_image?,
            oracle_failures~,
          ),
          "auth=\ncookie=\n",
        )
      }
      let missing = work + "/absent/" + command + ".cookies"
      let args = if command == "curl" {
        ["-sSL", "-c", missing, base + "/set"]
      } else {
        ["-qO-", "--save-cookies=" + missing, base + "/set"]
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          args,
          oracle_image?,
          oracle_failures~,
        ),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_false(@fs.exists(missing))
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/missing-parent",
          command,
          Json(@fs.exists(missing)),
          Json(false),
        )
      }
    }
    let session_jar = work + "/wget-without-session.cookies"
    check_network_response(
      network_request(
        executor,
        work,
        "wget",
        ["-qO-", "--save-cookies=" + session_jar, base + "/set"],
        oracle_image?,
        oracle_failures~,
      ),
      "auth=\ncookie=sid=fixture\n",
    )
    assert_false(@fs.read_file(session_jar).text().contains("\tsid\tfixture"))
    if oracle_image is None && executor.proof is Some(proof) {
      proof.observe_equal(
        "cookie/wget/session-excluded",
        "wget",
        Json(@fs.read_file(session_jar).text().contains("\tsid\tfixture")),
        Json(false),
      )
    }
    @fs.write_file(
      work + "/../requests.json",
      @harness.canonical_json(
        Json(
          requests.map(item => {
            ({ "path": Json(item.0), "authorization": Json(item.1) } : Json)
          }),
        ),
      ),
    )
    if !oracle_failures.is_empty() {
      fail(oracle_failures.join("; "))
    }
  }
}
