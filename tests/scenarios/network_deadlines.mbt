///|
async fn network_deadlines_scenario(root : String, work : String) -> Unit {
  for
    (command, label, flag, phase) in [
      ("curl", "connect-timeout", "--connect-timeout", "connect"),
      ("curl", "idle-timeout", "--idle-timeout", "body"),
      ("curl", "max-time", "--max-time", "stream"),
      ("wget", "connect-timeout", "--connect-timeout", "connect"),
      ("wget", "read-timeout", "--read-timeout", "body"),
      ("wget", "idle-timeout", "--idle-timeout", "body"),
      ("wget", "timeout", "--timeout", "body"),
    ] {
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let started : Ref[Int64?] = Ref(None)
      let finished = Ref(false)
      let requests = Ref(0)
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          requests.val += 1
          if phase == "connect" {
            // Real TLS ClientHello must precede the held handshake.
            guard connection.read_some(max_len=1) is Some(bytes) else {
              fail("missing TLS handshake")
            }
            assert_eq(bytes, b"\x16")
          } else {
            guard connection.read_until("\r\n") is Some(line) else {
              fail("missing request")
            }
            assert_eq(line, "GET /deadline HTTP/1.1")
            while connection.read_until("\r\n") is Some(header) && header != "" {
              ()
            }
            connection.write("HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n")
            connection.write(if phase == "stream" { "a" } else { "abc" })
          }
          started.val = Some(@async.now())
          if phase == "stream" {
            for _ in 0..<99 {
              @async.sleep(40)
              connection.write("a") catch {
                _ => return
              }
            }
          } else {
            @async.sleep(10000)
          }
          finished.val = true
        })
      })
      let args = if command == "curl" {
        [
          "-s",
          "-k",
          "--retry",
          "0",
          ..if phase == "stream" {
            ["--idle-timeout", "2"]
          } else {
            []
          },
          flag,
          "0.4",
        ]
      } else {
        ["-q", "--no-check-certificate", "-t1", "-O", "-", flag + "=0.4"]
      }
      let url = (if phase == "connect" { "https" } else { "http" }) +
        "://127.0.0.1:\{server.addr.port()}/deadline"
      let result = scenario_run(work, root, command, [..args, url], cwd=work, extra_env={
        "NO_PROXY": "*",
        "no_proxy": "*",
      })
      guard started.val is Some(start) else {
        fail("timeout before fixture readiness")
      }
      let elapsed = @async.now() - start
      let body = @harness.scenario_text(result.stdout)
      let expected_body = if phase == "stream" {
        body.length() > 0 &&
        body.length() < 100 &&
        body.iter().all(ch => ch == 'a')
      } else {
        body == (if phase == "connect" { "" } else { "abc" })
      }
      let actual : Json = {
        "status": result.status,
        "stderr": @harness.scenario_text(result.stderr),
        "body": expected_body,
        "requests": requests.val,
        "expired_while_held": !finished.val &&
        elapsed >= 100L &&
        elapsed < 5000L,
      }
      let expected : Json = {
        "status": if command == "curl" {
          28
        } else {
          4
        },
        "stderr": "",
        "body": true,
        "requests": 1,
        "expired_while_held": true,
      }
      @fs.write_file(
        work + "/../" + command + "-" + label + ".timing.json",
        (
          {
            "elapsed_since_fixture_ready_ms": elapsed,
            "request_count": requests.val,
            "fixture_completed": finished.val,
            "output_bytes": result.stdout.length(),
          } : Json).stringify(indent=2),
      )
      assert_eq(actual, expected)

      @harness.assert_observation(
        command + "/" + label,
        command,
        actual,
        expected,
      )
    })
  }
}
