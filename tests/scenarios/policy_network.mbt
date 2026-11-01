///|
async fn check_allowed_network_policy(
  root : String,
  failures : Array[String],
) -> Unit {
  @async.with_task_group <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((_, _, connection) => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "14",
        })
        connection..write("policy-net-ok\n").end_response()
      })
    }
    let url = "http://127.0.0.1:\{server.addr.port()}/allowed"
    let curl = moon_run(root, "net-local.json", "curl", ["-s", url]) catch {
      err => {
        failures.push("curl: allowed network invocation failed: \{err}")
        return
      }
    }
    let wget = moon_run(root, "net-local.json", "wget", ["-qO-", url]) catch {
      err => {
        failures.push("wget: allowed network invocation failed: \{err}")
        return
      }
    }
    record(
      stdout_is(curl, b"policy-net-ok\n"),
      "curl: local network policy did not allow the configured endpoint",
      failures,
    )
    record(
      stdout_is(wget, b"policy-net-ok\n"),
      "wget: local network policy did not allow the configured endpoint",
      failures,
    )
  }
}
