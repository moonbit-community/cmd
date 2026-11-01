///|
async fn run_https_cases(bin_root : String, failures : Array[String]) -> Unit {
  if @platform.is_windows() {
    return
  }
  @async.with_task_group <| group => {
    let current = @harness.repository_root()
    let cert = @path.Path(current)
      .join(Path("tests/fixtures/http/cert.pem"))
      .to_string()
    let key = @path.Path(current)
      .join(Path("tests/fixtures/http/key.pem"))
      .to_string()
    let output_root = @fs.tmpdir(prefix="mooncmd-https")
    defer cleanup_compat_fixture(output_root)
    let log = @path.Path(output_root).join(Path("server.log")).to_string()
    let program = @env.args()[0]
    let server = @process.spawn(
      group,
      program,
      ["--https-server", cert, key, log],
      no_console_window=true,
      no_wait=true,
    )
    let mut port : Int32? = None
    for attempt = 0; attempt < 100; attempt = attempt + 1 {
      if @fs.exists(log) {
        let text = @fs.read_file(log).text()
        if text.find("ACCEPT ") is Some(index) {
          let suffix = text[index + 7:].to_owned()
          let line = suffix.split("\n").next().unwrap_or("")
          if line.rev_find(":") is Some(colon) {
            port = try @string.parse_int(line[colon + 1:].to_owned()) catch {
              _ => None
            } noraise {
              value => Some(value)
            }
            if port is Some(_) {
              break
            }
          }
        }
      }
      @async.sleep(10)
    }
    guard port is Some(port) else {
      server.cancel()
      ignore(server.wait()) catch {
        _ => ()
      }
      compat_fail("HTTPS fixture did not report a listening port", failures)
      return
    }
    let url = "https://127.0.0.1:\{port}/"

    let curl_verified = @harness.run_command(bin_root, "curl", ["-sf", url])
    let curl_insecure = @harness.run_command(bin_root, "curl", ["-skf", url])
    let wget_verified = @harness.run_command(bin_root, "wget", ["-qO-", url])
    let wget_insecure = @harness.run_command(bin_root, "wget", [
      "-qO-", "--no-check-certificate", url,
    ])
    record_result(
      curl_verified.status == 60 &&
      curl_insecure.status == 0 &&
      wget_verified.status == 5 &&
      wget_insecure.status == 0,
      "HTTPS certificate verification controls mismatch",
      failures,
    )
    server.cancel()
    ignore(server.wait()) catch {
      _ => ()
    }
  }
}
