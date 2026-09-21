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
pub async fn spawn_http_fixture_process(
  group : @async.TaskGroup[Unit],
) -> (@process.Process, @process.ReadFromProcess, String) {
  let (port_reader, port_writer) = @process.read_from_process()
  let process = @process.spawn(
    group,
    @env.args()[0],
    ["--http-fixture-server"],
    stdout=port_writer,
    no_console_window=true,
    no_wait=true,
  )
  let line = port_reader.read_until("\n")
  guard line is Some(line) else {
    fail("release-runner: HTTP fixture closed before reporting a port")
  }
  let port = @string.parse_int(line.trim().to_owned()) catch {
    err => fail("release-runner: invalid HTTP fixture port: \{err}")
  }
  (process, port_reader, "http://127.0.0.1:\{port}")
}
