///|
async fn serve_static_scenario(
  root : String,
  work : String,
  restricted : Bool,
) -> Unit {
  let public = work + "/public"
  @fs.mkdir(public + "/nested", recursive=true)
  @fs.mkdir(public + "/empty")
  @fs.mkdir(work + "/public-private")
  @fs.write_file(public + "/index.html", "<h1>hello</h1>\n")
  @fs.write_file(public + "/nested/index.html", "nested\n")
  @fs.write_file(public + "/app.CSS", "body{}\n")
  @fs.write_file(public + "/hello world.txt", "space\n")
  @fs.write_file(work + "/public-private/secret.txt", "secret\n")
  let binary = Bytes::from_array(Array::make(150000, b'\xff')) + b"\x00\x80\n"
  @fs.write_file(public + "/data.bin", binary)
  // Windows ordinary CI accounts need not have symlink creation privileges.
  let links = !(@async.platform is Windows)
  if links {
    @fs.symlink(public + "/escape", target=work + "/public-private")
    @fs.mkdir(public + "/index-escape")
    @fs.symlink(
      public + "/index-escape/index.html",
      target=work + "/public-private/secret.txt",
    )
    @fs.symlink(public + "/alias.CSS", target=public + "/hello world.txt")
  }
  let policy_path = work + "/policy.json"
  let denied_statuses : Array[Int32] = []
  if restricted {
    @fs.write_file(
      policy_path,
      ({ "fs": { "read": [public] }, "net": { "bind": ["127.0.0.1:*"] } } : Json).stringify(
        indent=2,
      ),
    )
    let denied = @harness.run_with_deadline(
      @harness.command_program(),
      @harness.command_args(
        root,
        "serve",
        ["--port", "0", public],
        policy=@harness.repository_path("tests/fixtures/policy/deny-all.json"),
      ),
      5000,
    )
    assert_false(denied.timed_out)
    assert_eq(denied.cleanup_error, None)
    assert_eq(denied.output.status, 1)
    assert_eq(denied.output.stdout, b"")
    assert_true(
      @utf8.decode_lossy(denied.output.stderr).contains(
        "Sandbox policy blocked file read",
      ),
    )
    @fs.write_file(
      work + "/deny-bind.json",
      ({ "fs": { "read": [public] } } : Json).stringify(),
    )
    let bind_denied = @harness.run_with_deadline(
      @harness.command_program(),
      @harness.command_args(
        root,
        "serve",
        ["--port", "0", public],
        policy=work + "/deny-bind.json",
      ),
      5000,
    )
    assert_false(bind_denied.timed_out)
    assert_eq(bind_denied.cleanup_error, None)
    assert_eq(bind_denied.output.status, 1)
    assert_eq(bind_denied.output.stdout, b"")
    assert_true(
      @utf8.decode_lossy(bind_denied.output.stderr).contains(
        "Sandbox policy blocked",
      ),
    )
    denied_statuses.append([denied.output.status, bind_denied.output.status])
  }
  let (reader_out, stdout) = @process.read_from_process()
  let (reader_err, stderr) = @process.read_from_process()
  defer reader_out.close()
  defer reader_err.close()
  @async.with_task_group(group => {
    let out_task = group.spawn(() => reader_out.read_all().binary())
    let policy = if restricted { Some(policy_path) } else { None }
    let child = @harness.spawn(
      group,
      @harness.command_program(),
      @harness.command_args(
        root,
        "serve",
        ["--host", "127.0.0.1", "--port", "0", public],
        policy?,
      ),
      cwd=work,
      stdout~,
      stderr~,
      cancel_handler=@process.graceful_cancel(timeout=1000),
    )
    let ready = @async.with_timeout(5000, () => reader_err.read_until("\n"))
    guard ready is Some(ready) else { fail("serve exited before listening") }
    let address = ready.split("http://").last().unwrap().trim().to_owned()
    let trace : Array[Json] = []
    let expected : Array[Json] = []
    let check : async (String, @http.RequestMethod, Int32, String?, Bytes) -> Unit = (
      target,
      meth,
      status,
      mime,
      bytes,
    ) => {
      let (response, body) = @http.request(
        "http://" + address + target,
        meth,
        {},
        b"",
      )
      assert_eq(response.code, status, msg=target)
      assert_eq(body.binary(), bytes, msg=target)
      if mime is Some(mime) {
        assert_eq(response.headers.get("Content-Type"), Some(mime), msg=target)
        assert_eq(
          response.headers.get("X-Content-Type-Options"),
          Some("nosniff"),
        )
      }
      if status == 200 {
        assert_eq(
          response.headers.get("Content-Length"),
          Some(
            if meth is Head {
              binary.length().to_string()
            } else {
              bytes.length().to_string()
            },
          ),
        )
        assert_eq(response.headers.get("Connection"), Some("close"), msg=target)
      }
      trace.push({
        "target": target,
        "status": response.code,
        "bytes": body.binary().length(),
        "mime": response.headers.get("Content-Type"),
      })
      expected.push({
        "target": target,
        "status": status,
        "bytes": bytes.length(),
        "mime": mime,
      })
    }
    check("/", Get, 200, Some("text/html"), b"<h1>hello</h1>\n")
    check("/nested/", Get, 200, Some("text/html"), b"nested\n")
    let (redirect, redirect_body) = @http.request(
      "http://" + address + "//nested?x=1",
      Get,
      {},
      b"",
    )
    assert_eq(redirect.code, 301)
    assert_eq(redirect.headers.get("Location"), Some("/nested/?x=1"))
    assert_eq(redirect_body.binary(), b"")
    check("/app.CSS?x=1", Get, 200, Some("text/css"), b"body{}\n")
    check("/hello%20world.txt", Get, 200, Some("text/plain"), b"space\n")
    check("/data.bin", Get, 200, Some("application/octet-stream"), binary)
    check("/data.bin", Head, 200, Some("application/octet-stream"), b"")
    for
      target in [
        "/../public-private/secret.txt", "/%2e%2e/public-private/secret.txt", "/%2e%2e%5cpublic-private%5csecret.txt",
        "/file%00", "/%ff", "/file:stream",
      ] {
      check(target, Get, 400, None, b"")
    }
    for target in ["/missing", "/empty/"] {
      check(target, Get, 404, None, b"")
    }
    check("/data.bin", Post, 405, None, b"")
    if links {
      check("/escape/secret.txt", Get, 404, None, b"")
      check("/index-escape/", Get, 404, None, b"")
      check("/alias.CSS", Get, 200, Some("text/css"), b"space\n")
    }
    child.cancel()
    @async.with_timeout(5000, () => {
      child.wait() |> ignore
      assert_eq(out_task.wait(), b"")
      @fs.write_file(work + "/stderr", ready + reader_err.read_all().text())
    })
    @fs.write_file(work + "/requests.json", Json(trace).stringify(indent=2))

    @harness.assert_observation(
      if restricted {
        "serve/policy"
      } else {
        "serve/static"
      },
      "serve",
      {
        "responses": trace[:15].to_owned(),
        "denied_statuses": denied_statuses,
        "child_reaped": true,
      },
      {
        "responses": expected[:15].to_owned(),
        "denied_statuses": if restricted {
          [1, 1]
        } else {
          []
        },
        "child_reaped": true,
      },
    )
  })
}
