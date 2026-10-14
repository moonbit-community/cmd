///|
pub fn oracle_request_name(request : @http.Request) -> String {
  match request.meth {
    Get => "GET"
    Head => "HEAD"
    Post => "POST"
    Put => "PUT"
    Delete => "DELETE"
    Connect => "CONNECT"
    Options => "OPTIONS"
    Trace => "TRACE"
    Patch => "PATCH"
  }
}

///|
pub async fn run_http_fixture(server : @http.Server) -> Unit {
  server.run_forever() <| ((request, body, connection) => {
    match request.path {
      "/auth-cookie-challenge" if request.headers.get("Authorization") is None =>
        connection
        ..send_response(401, "Unauthorized", extra_headers={
          "WWW-Authenticate": "Basic realm=\"fixture\"",
          "Content-Length": "0",
        })
        .end_response()
      "/auth-cookie" | "/auth-cookie-challenge" => {
        let response = "auth=" +
          request.headers.get("Authorization").unwrap_or("") +
          "\ncookie=" +
          request.headers.get("Cookie").unwrap_or("") +
          "\n"
        connection
        ..send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        ..write(response)
        .end_response()
      }
      "/set-cookie" | "/set-cookie-path" | "/set-cookie-domain" => {
        let cookie = match request.path {
          "/set-cookie-path" => @http.Cookie("sid", "fixture", path="/private")
          "/set-cookie-domain" =>
            @http.Cookie("sid", "fixture", path="/", domain="example.invalid")
          _ => @http.Cookie("sid", "fixture", path="/")
        }
        connection
        ..send_response(
          302,
          "Found",
          extra_headers={ "Location": "/auth-cookie", "Content-Length": "0" },
          cookies=[cookie],
        )
        .end_response()
      }
      "/cross-cookie" =>
        connection
        ..send_response(302, "Found", extra_headers={
          "Location": "http://localhost:\{server.addr.port()}/auth-cookie",
          "Content-Length": "0",
        })
        .end_response()
      "/fixed" | "/named.txt" => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        if request.meth == @http.Head {
          connection.end_response()
        } else {
          connection..write("hello").end_response()
        }
      }
      "/second" => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        connection..write("world").end_response()
      }
      "/redirect" =>
        connection
        ..send_response(302, "Found", extra_headers={
          "Location": "/fixed",
          "Content-Length": "0",
        })
        .end_response()
      "/redirect-explicit" =>
        connection
        ..send_response(302, "Found", extra_headers={
          "Location": "/echo",
          "Content-Length": "0",
        })
        .end_response()
      "/echo" => {
        let content = body.read_all().binary()
        let response = @utf8.encode(oracle_request_name(request) + ":") +
          content
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        connection..write(response).end_response()
      }
      "/inspect" => {
        let content = body.read_all().binary()
        let marker = request.headers.get("X-Marker").unwrap_or("")
        let response = @utf8.encode(
            oracle_request_name(request) + ":" + marker + ":",
          ) +
          content
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        connection..write(response).end_response()
      }
      "/range" => {
        let ranged = request.headers.get("Range") == Some("bytes=3-")
        let content = if ranged { "lo" } else { "hello" }
        if ranged {
          connection.send_response(206, "OK", extra_headers={
            "Content-Length": content.length().to_string(),
            "Content-Range": "bytes 3-4/5",
          })
        } else {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": content.length().to_string(),
          })
        }
        connection..write(content).end_response()
      }
      "/conditional" =>
        if request.headers.get("If-Modified-Since") is Some(_) {
          connection
          ..send_response(304, "Not Modified", extra_headers={
            "Content-Length": "0",
          })
          .end_response()
        } else {
          connection.send_response(200, "OK", extra_headers={
            "Content-Length": "5",
          })
          connection..write("fresh").end_response()
        }
      "/named-header" => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
          "Content-Disposition": "attachment; filename=fixture.txt",
        })
        connection..write("hello").end_response()
      }
      "/missing" =>
        connection
        ..send_response(404, "Not Found", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
      _ =>
        connection
        ..send_response(400, "Bad Request", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
    }
  })
}

///|
pub async fn run_http_fixture_process() -> Unit {
  let server = @http.Server(@socket.Addr::parse("0.0.0.0:0"))
  @stdio.stdout.write(server.addr.port().to_string() + "\n")
  run_http_fixture(server)
}

///|
/// Startup owns the child until its endpoint has been accepted. Every failed
/// exit, including external cancellation, waits for protected cleanup; a cleanup
/// error retains the startup diagnostic and cannot become semantic evidence.
async fn[X] await_fixture_startup(
  label : String,
  timeout_ms : Int32,
  startup : async () -> X,
  cleanup : async () -> Unit,
) -> X {
  let completed = Ref(false)
  let failure : Ref[String?] = Ref(None)
  defer (if !completed.val {
    @async.protect_from_cancel(() => {
      cleanup() catch {
        error =>
          fail(
            failure.val.unwrap_or(label + " fixture startup cancelled") +
            "; direct child cleanup failed: " +
            error.to_string(),
          )
      }
    })
  })
  let result = try @async.with_timeout_opt(timeout_ms, startup) catch {
    error => Err(error)
  } noraise {
    value => Ok(value)
  }
  match result {
    Ok(Some(value)) => {
      completed.val = true
      value
    }
    Ok(None) => {
      let detail = label + " fixture startup deadline exceeded"
      failure.val = Some(detail)
      fail(detail)
    }
    Err(error) => {
      failure.val = Some(
        label + " fixture startup failed: " + error.to_string(),
      )
      raise error
    }
  }
}

///|
fn fixture_port(label : String, text : String) -> Int32 raise {
  let port = @string.parse_int(text.trim().to_owned()) catch {
    error =>
      fail(label + " fixture reported an invalid port: " + error.to_string())
  }
  guard port > 0 && port <= 65535 else {
    fail(label + " fixture reported an out-of-range port: " + port.to_string())
  }
  port
}

///|
pub async fn spawn_http_fixture_process(
  group : @async.TaskGroup[Unit],
  timeout_ms~ : Int32 = 2000,
) -> (@process.Process, @process.ReadFromProcess, String) {
  let (port_reader, port_writer) = @process.read_from_process()
  let handed_off = Ref(false)
  defer (if !handed_off.val { port_reader.close() })
  let program = @env.args()[0]
  record_execution_environment(program)
  let process = @process.spawn(
    group,
    program,
    ["--http-fixture-server"],
    stdout=port_writer,
    no_console_window=true,
    no_wait=true,
  )
  let port = await_fixture_startup(
    "HTTP",
    timeout_ms,
    () => {
      let line = port_reader.read_until("\n")
      guard line is Some(line) else {
        fail("HTTP fixture closed before reporting a port")
      }
      fixture_port("HTTP", line)
    },
    () => {
      process.cancel()
      ignore(process.wait())
    },
  )
  handed_off.val = true
  (process, port_reader, "http://127.0.0.1:\{port}")
}

///|
pub async fn spawn_https_fixture_process(
  group : @async.TaskGroup[Unit],
  root : String,
  fixture_directory~ : String = "tests/fixtures/http",
  timeout_ms~ : Int32 = 2000,
) -> (@process.Process, String) {
  let cert = @fs.realpath(fixture_directory + "/cert.pem")
  let key = @fs.realpath(fixture_directory + "/key.pem")
  let fixture_root = @fs.realpath(fixture_directory)
  let log = @path.Path(root).join(Path("https.log")).to_string()
  let output = @process.redirect_to_file(log)
  record_execution_environment("openssl")
  let process = @process.spawn(
    group,
    "openssl",
    ["s_server", "-accept", "127.0.0.1:0", "-cert", cert, "-key", key, "-WWW"],
    cwd=fixture_root,
    stdout=output,
    stderr=output,
    no_console_window=true,
    no_wait=true,
  )
  let url = await_fixture_startup(
    "HTTPS",
    timeout_ms,
    () => {
      while true {
        if @fs.exists(log) {
          let text = @fs.read_file(log).text()
          if text.find("ACCEPT ") is Some(index) {
            let suffix = text[index + 7:].to_owned()
            // Wait for the complete line before validating a log still being
            // written by the TLS fixture process.
            if suffix.find("\n") is Some(end) {
              let line = suffix[:end].trim().to_owned()
              guard line.rev_find(":") is Some(colon) else {
                fail("HTTPS fixture reported an invalid listening address")
              }
              let port = fixture_port("HTTPS", line[colon + 1:].to_owned())
              return "https://127.0.0.1:\{port}"
            }
          }
        }
        @async.sleep(10)
      } nobreak {
        fail("HTTPS fixture startup ended without an endpoint")
      }
    },
    () => {
      process.cancel()
      ignore(process.wait())
    },
  )
  (process, url)
}
