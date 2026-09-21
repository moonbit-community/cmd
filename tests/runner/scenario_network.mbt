///|
async fn network_request(
  root : String,
  wasm : Bool,
  work : String,
  command : String,
  args : Array[String],
  oracle_image? : String,
) -> @testkit.RunResult {
  let result = @testkit.run_artifact(
    root,
    wasm,
    command,
    args,
    stdin=b"",
    cwd=work,
    extra_env={ "NO_PROXY": "*", "no_proxy": "*", "LC_ALL": "C" },
  )
  let prefix = work + "/call-\{@fs.readdir(work).length()}"
  @fs.write_file(prefix + ".stdout.bin", result.stdout)
  @fs.write_file(prefix + ".stderr.bin", result.stderr)
  if oracle_image is Some(image) {
    let docker_user = @testkit.docker_user()
    let oracle_work = work + "/oracle"
    if !@fs.exists(oracle_work) {
      @fs.mkdir(oracle_work)
    }
    let oracle_args = args.map(arg => arg.replace_all(old=work, new=oracle_work))
    let run = @testkit.run_with_deadline(
      "docker",
      [
        "run",
        "--user",
        docker_user,
        "--rm",
        "-i",
        "--network",
        "host",
        "-v",
        oracle_work + ":" + oracle_work + ":rw",
        "-w",
        oracle_work,
        "-e",
        "LC_ALL=C",
        "-e",
        "NO_PROXY=*",
        "-e",
        "no_proxy=*",
        image,
        command,
        ..oracle_args,
      ],
      120000,
    )
    @fs.write_file(prefix + ".oracle.stdout.bin", run.output.stdout)
    @fs.write_file(prefix + ".oracle.stderr.bin", run.output.stderr)
    if run.timed_out ||
      run.cleanup_error is Some(_) ||
      [125, 126, 127].contains(run.output.status) {
      fail("oracle infrastructure failure")
    }
    assert_eq(result.status, run.output.status)
    assert_eq(result.stdout, run.output.stdout)
    assert_eq(result.stderr, run.output.stderr)
  }
  result
}

///|
fn check_network_response(
  result : @testkit.RunResult,
  expected : String,
) -> Unit raise {
  assert_eq(result.status, 0)
  assert_true(@testkit.bytes_equal(result.stdout, @utf8.encode(expected)))
  assert_eq(result.stderr, b"")
}

///|
/// Stateful CLI coverage previously driven by core/netops/verify_cli.mbtx.
/// One loopback fixture serves all rounds; no installed curl/wget is needed.
async fn network_cli_scenario(
  root : String,
  wasm : Bool,
  work : String,
  oracle_image? : String,
) -> Unit {
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
    let cases : Array[(String, Array[String], String, Int)] = [
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
        "auth=\ncookie=\n",
        2,
      ),
      ("wget", ["-qO-", "--no-cookies", base + "/set"], "auth=\ncookie=\n", 2),
    ]
    for (command, args, expected, request_count) in cases {
      let before = requests.length()
      check_network_response(
        network_request(root, wasm, work, command, args, oracle_image?),
        expected,
      )
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
        network_request(root, wasm, work, command, save, oracle_image?),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_true(@fs.read_file(jar).text().contains("\tsid\tfixture"))
      let load = if command == "curl" {
        ["-sS", "-b", jar, base + "/inspect"]
      } else {
        ["-qO-", "--load-cookies=" + jar, base + "/inspect"]
      }
      check_network_response(
        network_request(root, wasm, work, command, load, oracle_image?),
        "auth=\ncookie=sid=fixture\n",
      )
      if command == "curl" {
        check_network_response(
          network_request(
            root,
            wasm,
            work,
            command,
            ["-sS", "-b", jar, "-b", "sid=manual", base + "/inspect"],
            oracle_image?,
          ),
          "auth=\ncookie=sid=fixture; sid=manual\n",
        )
        let before = requests.length()
        let unsupported = network_request(root, wasm, work, command, [
          "-sS",
          "-b",
          jar,
          "-H",
          "Cookie: sid=header",
          base + "/inspect",
        ])
        assert_true(unsupported.status != 0)
        assert_eq(unsupported.stdout, b"")
        assert_true(
          @testkit.contains_bytes(
            unsupported.stderr,
            "duplicate request-header support",
          ),
        )
        assert_eq(requests.length(), before)
      }
      if !(@async.platform is Windows) {
        // A newly created ordinary file observes this process's real umask.
        let control = work + "/mode-control-" + command
        @fs.write_file(control, "")
        let stat_args = if @async.platform is MacOS {
          ["-f", "%Lp"]
        } else {
          ["-c", "%a"]
        }
        let actual_mode = @testkit.run("stat", [..stat_args, jar], stdin=b"")
        let control_mode = @testkit.run(
          "stat",
          [..stat_args, control],
          stdin=b"",
        )
        assert_eq(actual_mode.status, 0)
        assert_eq(control_mode.status, 0)
        assert_eq(actual_mode.stdout, control_mode.stdout)
        if oracle_image is Some(_) {
          let oracle_mode = @testkit.run(
            "stat",
            [..stat_args, work + "/oracle/" + command + ".cookies"],
            stdin=b"",
          )
          assert_eq(oracle_mode.status, 0)
          assert_eq(actual_mode.stdout, oracle_mode.stdout)
        }
      }
      for endpoint in ["set-path", "set-domain", "set-expired"] {
        let args = if command == "curl" {
          ["-sSL", "-b", "", base + "/" + endpoint]
        } else {
          ["-qO-", base + "/" + endpoint]
        }
        check_network_response(
          network_request(root, wasm, work, command, args, oracle_image?),
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
        network_request(root, wasm, work, command, args, oracle_image?),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_false(@fs.exists(missing))
    }
    let session_jar = work + "/wget-without-session.cookies"
    check_network_response(
      network_request(
        root,
        wasm,
        work,
        "wget",
        ["-qO-", "--save-cookies=" + session_jar, base + "/set"],
        oracle_image?,
      ),
      "auth=\ncookie=sid=fixture\n",
    )
    assert_false(@fs.read_file(session_jar).text().contains("\tsid\tfixture"))
  }
}
