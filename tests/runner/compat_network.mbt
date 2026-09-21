///|
async fn run_http_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let mut wget_retry_attempts = 0
    let mut curl_retry_attempts = 0
    let mut curl_retry_all_attempts = 0
    let mut curl_retry_limited_attempts = 0
    let mut wget_retry_limited_attempts = 0
    let cross_origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => cross_origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      cross_origin.run_forever() <| ((request, body, connection) => {
        let request_name = match request.meth {
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
        let authorization = if request.headers.get("Authorization") is None {
          "clean"
        } else {
          "leaked"
        }
        let payload = body.read_all().text()
        let response = "\{request_name}:\{authorization}:\{payload}"
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": response.length().to_string(),
        })
        connection..write(response).end_response()
      })
    }
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _body, connection) => {
        match request.path {
          "/fixed" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            if request.meth == @http.Head {
              connection.end_response()
            } else {
              connection..write("hello").end_response()
            }
          }
          "/chunked" => {
            connection.send_response(200, "OK")
            connection..write("slow-").flush()
            @async.sleep(5)
            connection..write("stream").end_response()
          }
          "/redirect" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/fixed",
              "Content-Length": "0",
            })
            .end_response()
          "/method-redirect" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/request",
              "Content-Length": "0",
            })
            .end_response()
          "/cross-origin" =>
            connection
            ..send_response(307, "Temporary Redirect", extra_headers={
              "Location": "http://127.0.0.1:\{cross_origin.addr.port()}/target",
              "Content-Length": "0",
            })
            .end_response()
          "/chain-1" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/chain-2",
              "Content-Length": "0",
            })
            .end_response()
          "/chain-2" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/fixed",
              "Content-Length": "0",
            })
            .end_response()
          "/redirect-301"
          | "/redirect-302"
          | "/redirect-303"
          | "/redirect-307"
          | "/redirect-308" => {
            let status = @string.parse_int(request.path[10:])
            let reason = match status {
              301 => "Moved Permanently"
              302 => "Found"
              303 => "See Other"
              307 => "Temporary Redirect"
              _ => "Permanent Redirect"
            }
            connection
            ..send_response(status, reason, extra_headers={
              "Location": "/echo",
              "Content-Length": "0",
            })
            .end_response()
          }
          "/loop-a" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/loop-b",
              "Content-Length": "0",
            })
            .end_response()
          "/loop-b" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "/loop-a",
              "Content-Length": "0",
            })
            .end_response()
          "/echo" => {
            let content = _body.read_all().binary()
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": content.length().to_string(),
            })
            connection..write(content).end_response()
          }
          "/request" => {
            let content = _body.read_all().text()
            let request_name = match request.meth {
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
            let marker = request.headers.get("X-Marker").unwrap_or("")
            let response = "\{request_name}:\{marker}:\{content}"
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": response.length().to_string(),
            })
            connection..write(response).end_response()
          }
          "/method-check" => {
            let expected = request.headers.get("X-Expected").unwrap_or("")
            let accepted = oracle_request_name(request) == expected
            connection
            ..send_response(
              if accepted {
                200
              } else {
                400
              },
              if accepted {
                "OK"
              } else {
                "Bad Request"
              },
              extra_headers={ "Content-Length": "0" },
            )
            .end_response()
          }
          "/range" => {
            let ranged = request.headers.get("Range") == Some("bytes=3-")
            let content = if ranged { "lo" } else { "hello" }
            connection.send_response(if ranged { 206 } else { 200 }, "OK", extra_headers={
              "Content-Length": content.length().to_string(),
            })
            connection..write(content).end_response()
          }
          "/range-ignore" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            connection..write("hello").end_response()
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
          "/not-modified" =>
            connection
            ..send_response(304, "Not Modified", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/wget-retry" | "/curl-retry" => {
            if request.path == "/wget-retry" {
              wget_retry_attempts += 1
            } else {
              curl_retry_attempts += 1
            }
            let attempts = if request.path == "/wget-retry" {
              wget_retry_attempts
            } else {
              curl_retry_attempts
            }
            let success_attempt = if request.path == "/wget-retry" {
              3
            } else {
              2
            }
            if attempts < success_attempt {
              connection
              ..send_response(503, "Service Unavailable", extra_headers={
                "Content-Length": "0",
              })
              .end_response()
            } else {
              connection.send_response(200, "OK", extra_headers={
                "Content-Length": "5",
              })
              connection..write("hello").end_response()
            }
          }
          "/curl-retry-all" => {
            curl_retry_all_attempts += 1
            if curl_retry_all_attempts < 2 {
              connection
              ..send_response(404, "Not Found", extra_headers={
                "Content-Length": "0",
              })
              .end_response()
            } else {
              connection.send_response(200, "OK", extra_headers={
                "Content-Length": "5",
              })
              connection..write("hello").end_response()
            }
          }
          "/curl-retry-limited" => {
            curl_retry_limited_attempts += 1
            connection
            ..send_response(503, "Service Unavailable", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          }
          "/wget-retry-limited" => {
            wget_retry_limited_attempts += 1
            connection
            ..send_response(503, "Service Unavailable", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          }
          "/partial" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "9",
            })
            connection..write("abc").flush()
            connection.close()
          }
          "/unauthorized" =>
            connection
            ..send_response(401, "Unauthorized", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/forbidden" =>
            connection
            ..send_response(403, "Forbidden", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/busy" =>
            connection
            ..send_response(429, "Too Many Requests", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/server-error" =>
            connection
            ..send_response(500, "Internal Server Error", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/named" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
              "Content-Disposition": "attachment; filename=fixture.txt",
            })
            connection..write("hello").end_response()
          }
          "/named-encoded" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
              "Content-Disposition": "attachment; filename*=UTF-8''encoded.txt",
            })
            connection..write("hello").end_response()
          }
          "/named-partial" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "9",
              "Content-Disposition": "attachment; filename=partial.txt",
            })
            connection..write("abc").flush()
            connection.close()
          }
          "/one" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "3",
            })
            connection..write("one").end_response()
          }
          "/two" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "3",
            })
            connection..write("two").end_response()
          }
          "/missing" =>
            connection
            ..send_response(404, "Not Found", extra_headers={
              "Content-Length": "0",
            })
            .end_response()
          "/stall" => {
            @async.sleep(200)
            connection..send_response(200, "OK").end_response()
          }
          "/body-stall" => {
            connection.send_response(200, "OK", extra_headers={
              "Content-Length": "5",
            })
            connection.flush()
            @async.sleep(200)
            connection..write("later").end_response()
          }
          _ => connection..send_response(400, "Bad Request").end_response()
        }
      })
    }
    let base = "http://127.0.0.1:\{server.addr.port()}"
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget_fixed = @testkit.run(wget, ["-O", "-", base + "/fixed"])
    record_result(
      wget_fixed.status == 0 &&
      @testkit.bytes_equal(wget_fixed.stdout, b"hello") &&
      @testkit.contains_bytes(wget_fixed.stderr, "HTTP request sent") &&
      @testkit.contains_bytes(wget_fixed.stderr, "saved [5]"),
      "wget: fixed-length response or progress feedback mismatch",
      failures,
    )
    let wget_quiet = @testkit.run(wget, ["-q", "-O", "-", base + "/fixed"])
    record_result(
      wget_quiet.status == 0 &&
      @testkit.bytes_equal(wget_quiet.stdout, b"hello") &&
      wget_quiet.stderr.is_empty(),
      "wget: -q did not suppress progress",
      failures,
    )
    let wget_missing = @testkit.run(wget, ["-O", "-", base + "/missing"])
    record_result(
      wget_missing.status == 8 &&
      wget_missing.stdout.is_empty() &&
      @testkit.contains_bytes(wget_missing.stderr, "HTTP status 404 Not Found"),
      "wget: HTTP error behavior mismatch",
      failures,
    )
    let wget_quiet_missing = @testkit.run(wget, [
      "-q",
      "-O",
      "-",
      base + "/missing",
    ])
    record_result(
      wget_quiet_missing.status == 8 &&
      wget_quiet_missing.stdout.is_empty() &&
      wget_quiet_missing.stderr.is_empty(),
      "wget: -q did not suppress an HTTP error diagnostic",
      failures,
    )
    let curl_chunked = @testkit.run(curl, [base + "/chunked"])
    record_result(
      curl_chunked.status == 0 &&
      @testkit.bytes_equal(curl_chunked.stdout, b"slow-stream") &&
      @testkit.contains_bytes(curl_chunked.stderr, "0% 11"),
      "curl: unknown-length response or progress feedback mismatch",
      failures,
    )
    let curl_silent = @testkit.run(curl, ["-s", "-f", base + "/missing"])
    record_result(
      curl_silent.status == 22 && curl_silent.stderr.is_empty(),
      "curl: -s did not suppress errors",
      failures,
    )
    let curl_show_error = @testkit.run(curl, ["-sS", "-f", base + "/missing"])
    record_result(
      curl_show_error.status == 22 &&
      @testkit.contains_bytes(
        curl_show_error.stderr,
        "HTTP status 404 Not Found",
      ),
      "curl: -sS did not restore the HTTP error",
      failures,
    )
    let output_root = @fs.tmpdir(prefix="mooncmd-http")
    defer (@fs.rmdir(output_root, recursive=true) catch { _ => () })
    let output = @path.Path(output_root).join(Path("response")).to_string()
    let wget_log = @path.Path(output_root).join(Path("wget.log")).to_string()
    let wget_logged = @testkit.run(wget, [
      "-o",
      wget_log,
      "-O",
      "-",
      base + "/fixed",
    ])
    record_result(
      wget_logged.status == 0 &&
      @testkit.bytes_equal(wget_logged.stdout, b"hello") &&
      wget_logged.stderr.is_empty() &&
      @testkit.contains_bytes(
        @fs.read_file(wget_log).binary(),
        "HTTP request sent",
      ) &&
      @testkit.contains_bytes(@fs.read_file(wget_log).binary(), "saved [5]"),
      "wget: -o did not route diagnostics to its log",
      failures,
    )
    let curl_file = @testkit.run(curl, ["-s", "-o", output, base + "/fixed"])
    record_result(
      curl_file.status == 0 &&
      curl_file.stdout.is_empty() &&
      @testkit.bytes_equal(@fs.read_file(output).binary(), b"hello"),
      "curl: file output mismatch",
      failures,
    )
    let curl_timeout = @testkit.run(curl, [
      "--idle-timeout",
      "0.02",
      base + "/stall",
    ])
    record_result(
      curl_timeout.status == 28 &&
      @testkit.contains_bytes(curl_timeout.stderr, "timed out after 20"),
      "curl: idle timeout did not fail promptly",
      failures,
    )
    let wget_redirect = @testkit.run(wget, ["-q", "-O", "-", base + "/redirect"])
    record_result(
      wget_redirect.status == 0 &&
      @testkit.bytes_equal(wget_redirect.stdout, b"hello") &&
      wget_redirect.stderr.is_empty(),
      "wget: default relative redirect handling mismatch",
      failures,
    )
    let curl_redirect = @testkit.run(curl, ["-s", base + "/redirect"])
    record_result(
      curl_redirect.status == 0 && curl_redirect.stdout.is_empty(),
      "curl: followed a redirect without -L",
      failures,
    )
    let curl_location = @testkit.run(curl, ["-sL", base + "/redirect"])
    record_result(
      curl_location.status == 0 &&
      @testkit.bytes_equal(curl_location.stdout, b"hello"),
      "curl: -L relative redirect handling mismatch",
      failures,
    )
    let curl_redirect_zero = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "0",
      base + "/redirect",
    ])
    let curl_redirect_one = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "1",
      base + "/chain-1",
    ])
    let curl_redirect_two = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "2",
      base + "/chain-1",
    ])
    let curl_redirect_unlimited = @testkit.run(curl, [
      "-sL",
      "--max-redirs",
      "-1",
      base + "/chain-1",
    ])
    let wget_redirect_zero = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=0",
      base + "/redirect",
    ])
    let wget_redirect_one = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=1",
      base + "/chain-1",
    ])
    let wget_redirect_two = @testkit.run(wget, [
      "-qO-",
      "--max-redirect=2",
      base + "/chain-1",
    ])
    record_result(
      curl_redirect_zero.status == 47 &&
      curl_redirect_one.status == 47 &&
      curl_redirect_two.status == 0 &&
      @testkit.bytes_equal(curl_redirect_two.stdout, b"hello") &&
      curl_redirect_unlimited.status == 0 &&
      @testkit.bytes_equal(curl_redirect_unlimited.stdout, b"hello") &&
      wget_redirect_zero.status == 7 &&
      wget_redirect_one.status == 7 &&
      wget_redirect_two.status == 0 &&
      @testkit.bytes_equal(wget_redirect_two.stdout, b"hello"),
      "curl/wget redirect limit behavior mismatch",
      failures,
    )
    let curl_last_status = @testkit.run(curl, [
      "-sf",
      base + "/missing",
      base + "/fixed",
    ])
    record_result(
      curl_last_status.status == 0 &&
      @testkit.bytes_equal(curl_last_status.stdout, b"hello"),
      "curl: final transfer did not determine the process status",
      failures,
    )
    let curl_loop = @testkit.run(curl, ["-sSL", base + "/loop-a"])
    record_result(
      curl_loop.status == 47 &&
      @testkit.contains_bytes(curl_loop.stderr, "redirect loop"),
      "curl: redirect loop status mismatch",
      failures,
    )
    let curl_post = @testkit.run(curl, [
      "-s",
      "-d",
      "alpha=one",
      "--data-raw",
      "beta=two",
      base + "/echo",
    ])
    record_result(
      curl_post.status == 0 &&
      @testkit.bytes_equal(curl_post.stdout, b"alpha=one&beta=two"),
      "curl: repeated data body mismatch",
      failures,
    )
    let data_root = @fs.tmpdir(prefix="mooncmd-http-data")
    defer (@fs.rmdir(data_root, recursive=true) catch { _ => () })
    let data_path = @path.Path(data_root).join(Path("input.bin")).to_string()
    @fs.write_file(data_path, b"a\r\nb\x00c")
    let curl_form_file = @testkit.run(curl, [
      "-s",
      "-d",
      "@" + data_path,
      base + "/echo",
    ])
    let curl_raw = @testkit.run(curl, [
      "-s",
      "--data-raw",
      "@literal",
      base + "/echo",
    ])
    let curl_binary = @testkit.run(curl, [
      "-s",
      "--data-binary",
      "@" + data_path,
      base + "/echo",
    ])
    let curl_encoded = @testkit.run(curl, [
      "-s",
      "--data-urlencode",
      "field@" + data_path,
      base + "/echo",
    ])
    let curl_empty_data = @testkit.run(curl, [
      "-s",
      "--data-raw",
      "",
      "--data-urlencode",
      "a b",
      base + "/echo",
    ])
    record_result(
      curl_form_file.status == 0 &&
      @testkit.bytes_equal(curl_form_file.stdout, b"abc") &&
      curl_raw.status == 0 &&
      @testkit.bytes_equal(curl_raw.stdout, b"@literal") &&
      curl_binary.status == 0 &&
      @testkit.bytes_equal(curl_binary.stdout, b"a\r\nb\x00c") &&
      curl_encoded.status == 0 &&
      @testkit.bytes_equal(curl_encoded.stdout, b"field=a%0D%0Ab%00c") &&
      curl_empty_data.status == 0 &&
      @testkit.bytes_equal(curl_empty_data.stdout, b"&a%20b"),
      "curl: data file/raw/binary/urlencode behavior mismatch",
      failures,
    )
    let upload_path = @path.Path(data_root).join(Path("upload.bin")).to_string()
    @fs.write_file(upload_path, b"upload\x00bytes")
    let curl_upload = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path,
      base + "/echo",
    ])
    let curl_upload_twice = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path,
      base + "/echo",
      base + "/echo",
    ])
    let curl_upload_patch = @testkit.run(curl, [
      "-s",
      "-X",
      "PATCH",
      "-T",
      upload_path,
      base + "/request",
    ])
    let curl_upload_missing = @testkit.run(curl, [
      "-s",
      "-T",
      upload_path + ".missing",
      base + "/echo",
    ])
    record_result(
      curl_upload.status == 0 &&
      @testkit.bytes_equal(curl_upload.stdout, b"upload\x00bytes") &&
      curl_upload_twice.status == 0 &&
      @testkit.bytes_equal(
        curl_upload_twice.stdout,
        b"upload\x00bytesupload\x00bytes",
      ) &&
      curl_upload_patch.status == 0 &&
      @testkit.bytes_equal(curl_upload_patch.stdout, b"PATCH::upload\x00bytes") &&
      curl_upload_missing.status == 26 &&
      curl_upload_missing.stdout.is_empty(),
      "curl: upload file behavior mismatch",
      failures,
    )
    let curl_head = @testkit.run(curl, ["-I", base + "/fixed"])
    record_result(
      curl_head.status == 0 &&
      @testkit.contains_bytes(curl_head.stdout, "HTTP/1.1 200 OK") &&
      !@testkit.contains_bytes(curl_head.stdout, "hello"),
      "curl: HEAD response mismatch",
      failures,
    )
    let named_root = @fs.tmpdir(prefix="mooncmd-http-name")
    defer (@fs.rmdir(named_root, recursive=true) catch { _ => () })
    let curl_named = @testkit.run(
      curl,
      ["-sOJ", base + "/named"],
      cwd=named_root,
    )
    let named_path = @path.Path(named_root)
      .join(Path("fixture.txt"))
      .to_string()
    record_result(
      curl_named.status == 0 &&
      @fs.exists(named_path) &&
      @testkit.bytes_equal(@fs.read_file(named_path).binary(), b"hello"),
      "curl: -OJ content-disposition output mismatch",
      failures,
    )
    let basename_path = @path.Path(named_root).join(Path("fixed")).to_string()
    @fs.write_file(basename_path, b"old")
    let curl_basename = @testkit.run(
      curl,
      ["-sO", base + "/fixed"],
      cwd=named_root,
    )
    let encoded_path = @path.Path(named_root)
      .join(Path("encoded.txt"))
      .to_string()
    let curl_encoded_name = @testkit.run(
      curl,
      ["-sOJ", base + "/named-encoded"],
      cwd=named_root,
    )
    let curl_named_partial = @testkit.run(
      curl,
      ["-sSJO", "--remove-on-error", base + "/named-partial"],
      cwd=named_root,
    )
    let named_partial_path = @path.Path(named_root)
      .join(Path("partial.txt"))
      .to_string()
    record_result(
      curl_basename.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(basename_path).binary(), b"hello") &&
      curl_encoded_name.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(encoded_path).binary(), b"hello") &&
      curl_named_partial.status == 7 &&
      !@fs.exists(named_partial_path),
      "curl: remote filename, collision, or named cleanup mismatch",
      failures,
    )
    for status in [301, 302, 303] {
      let redirected = @testkit.run(curl, [
        "-sL",
        "-d",
        "body",
        base + "/redirect-\{status}",
      ])
      record_result(
        redirected.status == 0 && redirected.stdout.is_empty(),
        "curl: \{status} did not rewrite POST to GET",
        failures,
      )
    }
    for status in [307, 308] {
      let redirected = @testkit.run(curl, [
        "-sL",
        "-d",
        "body",
        base + "/redirect-\{status}",
      ])
      record_result(
        redirected.status == 0 &&
        @testkit.bytes_equal(redirected.stdout, b"body"),
        "curl: \{status} did not preserve the request body",
        failures,
      )
    }
    let curl_request = @testkit.run(curl, [
      "-s",
      "-H",
      "X-Marker: present",
      "-X",
      "PATCH",
      "--data-raw",
      "payload",
      base + "/request",
    ])
    record_result(
      curl_request.status == 0 &&
      @testkit.bytes_equal(curl_request.stdout, b"PATCH:present:payload"),
      "curl: method/header/body request mismatch",
      failures,
    )
    let wget_request = @testkit.run(wget, [
      "-qO-",
      "--header=X-Marker: present",
      "--method=PATCH",
      "--body-data=payload",
      base + "/request",
    ])
    record_result(
      wget_request.status == 0 &&
      @testkit.bytes_equal(wget_request.stdout, b"PATCH:present:payload"),
      "wget: method/header/body request mismatch",
      failures,
    )
    for
      request_name in [
        "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH",
      ] {
      let checked = @testkit.run(curl, [
        "-sf",
        "-X",
        request_name,
        "-H",
        "X-Expected: " + request_name,
        base + "/method-check",
      ])
      record_result(
        checked.status == 0,
        "curl: request method {request_name} did not reach the server",
        failures,
      )
    }
    let curl_explicit_redirect = @testkit.run(curl, [
      "-sL",
      "-X",
      "POST",
      "--data-raw",
      "payload",
      base + "/method-redirect",
    ])
    let wget_explicit_redirect = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      base + "/method-redirect",
    ])
    record_result(
      curl_explicit_redirect.status == 0 &&
      @testkit.bytes_equal(curl_explicit_redirect.stdout, b"POST::") &&
      wget_explicit_redirect.status == 0 &&
      @testkit.bytes_equal(wget_explicit_redirect.stdout, b"GET::"),
      "explicit request methods were not preserved across redirects",
      failures,
    )
    let cross_redirect = @testkit.run(curl, [
      "-sL",
      "-X",
      "PATCH",
      "-H",
      "Authorization: secret",
      "--data-raw",
      "payload",
      base + "/cross-origin",
    ])
    record_result(
      cross_redirect.status == 0 &&
      @testkit.bytes_equal(cross_redirect.stdout, b"PATCH:clean:payload"),
      "curl: cross-origin redirect method/body/header behavior mismatch",
      failures,
    )
    let resume_root = @fs.tmpdir(prefix="mooncmd-http-resume")
    defer (@fs.rmdir(resume_root, recursive=true) catch { _ => () })
    let resume_path = @path.Path(resume_root).join(Path("range")).to_string()
    let range_ignore_path = @path.Path(resume_root)
      .join(Path("range-ignore"))
      .to_string()
    @fs.write_file(range_ignore_path, b"hel")
    let wget_resume = @testkit.run(
      wget,
      ["-q", "-c", base + "/range"],
      cwd=resume_root,
    )
    record_result(
      wget_resume.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(resume_path).binary(), b"hello"),
      "wget: range resume mismatch",
      failures,
    )
    @fs.write_file(resume_path, b"hel")
    let wget_range_ignored = @testkit.run(
      wget,
      ["-q", "-c", base + "/range-ignore"],
      cwd=resume_root,
    )
    record_result(
      wget_range_ignored.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(range_ignore_path).binary(), b"hello"),
      "wget: ignored range response handling mismatch",
      failures,
    )
    let unchanged_path = @path.Path(resume_root)
      .join(Path("not-modified"))
      .to_string()
    @fs.write_file(unchanged_path, b"original")
    let wget_unchanged = @testkit.run(
      wget,
      ["-q", "-N", base + "/not-modified"],
      cwd=resume_root,
    )
    record_result(
      wget_unchanged.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(unchanged_path).binary(), b"original"),
      "wget: timestamping 304 changed the destination",
      failures,
    )
    let conditional_path = @path.Path(resume_root)
      .join(Path("conditional"))
      .to_string()
    @fs.write_file(conditional_path, b"preserved")
    let wget_conditional = @testkit.run(
      wget,
      ["-q", "-N", base + "/conditional"],
      cwd=resume_root,
    )
    record_result(
      wget_conditional.status == 0 &&
      @testkit.bytes_equal(
        @fs.read_file(conditional_path).binary(),
        b"preserved",
      ),
      "wget: timestamping did not send a conditional request",
      failures,
    )
    let input_root = @fs.tmpdir(prefix="mooncmd-http-input")
    defer (@fs.rmdir(input_root, recursive=true) catch { _ => () })
    let input_one = @path.Path(input_root).join(Path("urls-one")).to_string()
    let input_two = @path.Path(input_root).join(Path("urls-two")).to_string()
    let input_mixed = @path.Path(input_root)
      .join(Path("urls-mixed"))
      .to_string()
    @fs.write_file(input_one, @utf8.encode("# comment\n\n" + base + "/one\n"))
    @fs.write_file(input_two, @utf8.encode("  \n" + base + "/two\n"))
    @fs.write_file(
      input_mixed,
      @utf8.encode(base + "/missing\n" + base + "/one\n"),
    )
    let wget_inputs = @testkit.run(wget, [
      "-qO-",
      "-i",
      input_one,
      "--input-file=" + input_two,
    ])
    let wget_aggregate = @testkit.run(wget, ["-qO-", "-i", input_mixed])
    let wget_missing_input = @testkit.run(wget, [
      "-q",
      "-i",
      input_mixed + ".missing",
    ])
    record_result(
      wget_inputs.status == 0 &&
      @testkit.bytes_equal(wget_inputs.stdout, b"onetwo") &&
      wget_aggregate.status == 8 &&
      @testkit.bytes_equal(wget_aggregate.stdout, b"one") &&
      wget_missing_input.status == 3,
      "wget: input-file parsing or status aggregation mismatch",
      failures,
    )
    let append_log = @path.Path(input_root).join(Path("append.log")).to_string()
    let quiet_log = @path.Path(input_root).join(Path("quiet.log")).to_string()
    @fs.write_file(append_log, b"before\n")
    @fs.write_file(quiet_log, b"untouched\n")
    let wget_append_log = @testkit.run(wget, [
      "-a",
      append_log,
      "-O",
      "-",
      base + "/one",
    ])
    let wget_quiet_log = @testkit.run(wget, [
      "-q",
      "-a",
      quiet_log,
      "-O",
      "-",
      base + "/one",
    ])
    record_result(
      wget_append_log.status == 0 &&
      @testkit.bytes_equal(wget_append_log.stdout, b"one") &&
      @testkit.contains_bytes(@fs.read_file(append_log).binary(), "before\n--") &&
      wget_quiet_log.status == 0 &&
      @testkit.bytes_equal(wget_quiet_log.stdout, b"one") &&
      @testkit.bytes_equal(@fs.read_file(quiet_log).binary(), b"untouched\n"),
      "wget: append log or quiet/log interaction mismatch",
      failures,
    )
    let body_file = @path.Path(input_root).join(Path("body.bin")).to_string()
    @fs.write_file(body_file, b"body\x00bytes")
    let wget_body_file = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-file=" + body_file,
      base + "/echo",
    ])
    let wget_body_without_method = @testkit.run(wget, [
      "-qO-",
      "--body-data=payload",
      base + "/echo",
    ])
    let wget_body_conflict = @testkit.run(wget, [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      "--body-file=" + body_file,
      base + "/echo",
    ])
    let wget_headers = @testkit.run(wget, [
      "-qO-",
      "--header=X-Marker: first",
      "--header=X-Marker: second",
      base + "/request",
    ])
    record_result(
      wget_body_file.status == 0 &&
      @testkit.bytes_equal(wget_body_file.stdout, b"body\x00bytes") &&
      wget_body_without_method.status == 1 &&
      wget_body_without_method.stdout.is_empty() &&
      wget_body_conflict.status == 1 &&
      wget_body_conflict.stdout.is_empty() &&
      wget_headers.status == 0 &&
      @testkit.bytes_equal(wget_headers.stdout, b"GET:second:"),
      "wget: binary body file or repeated header behavior mismatch",
      failures,
    )
    let wget_retry = @testkit.run(wget, [
      "-qO-",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      "--tries=3",
      base + "/wget-retry",
    ])
    record_result(
      wget_retry.status == 0 &&
      @testkit.bytes_equal(wget_retry.stdout, b"hello") &&
      wget_retry_attempts == 3,
      "wget: HTTP retry mismatch",
      failures,
    )
    let curl_retry = @testkit.run(curl, [
      "-s",
      "--retry",
      "1",
      "--retry-delay",
      "0",
      base + "/curl-retry",
    ])
    record_result(
      curl_retry.status == 0 &&
      @testkit.bytes_equal(curl_retry.stdout, b"hello") &&
      curl_retry_attempts == 2,
      "curl: HTTP retry mismatch",
      failures,
    )
    let curl_retry_all = @testkit.run(curl, [
      "-sf",
      "--retry",
      "1",
      "--retry-all-errors",
      "--retry-delay",
      "1",
      base + "/curl-retry-all",
    ])
    let curl_retry_limited = @testkit.run(curl, [
      "-sf",
      "--retry",
      "3",
      "--retry-max-time",
      "1",
      base + "/curl-retry-limited",
    ])
    let curl_refused = @testkit.run(curl, [
      "-s", "--retry", "2", "--retry-connrefused", "--retry-max-time", "1", "http://127.0.0.1:1/unreachable",
    ])
    let wget_retry_limited = @testkit.run(wget, [
      "-qO-",
      "--tries=2",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      base + "/wget-retry-limited",
    ])
    let wget_refused = @testkit.run(wget, [
      "-qO-", "--tries=2", "--retry-connrefused", "--waitretry=0.001", "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      curl_retry_all.status == 0 &&
      @testkit.bytes_equal(curl_retry_all.stdout, b"hello") &&
      curl_retry_all_attempts == 2 &&
      curl_retry_limited.status == 22 &&
      curl_retry_limited_attempts == 1 &&
      curl_refused.status == 7 &&
      wget_retry_limited.status == 8 &&
      wget_retry_limited_attempts == 2 &&
      wget_refused.status == 4,
      "curl/wget retry classification, limits, or final status mismatch",
      failures,
    )
    for endpoint in ["unauthorized", "forbidden", "busy", "server-error"] {
      let wget_status = @testkit.run(wget, ["-qO-", base + "/" + endpoint])
      let curl_status = @testkit.run(curl, ["-sf", base + "/" + endpoint])
      record_result(
        wget_status.status == 8 && curl_status.status == 22,
        "HTTP error status mapping mismatch for \{endpoint}",
        failures,
      )
    }
    let partial_path = @path.Path(resume_root)
      .join(Path("partial.bin"))
      .to_string()
    let curl_partial = @testkit.run(curl, [
      "-sS",
      "--remove-on-error",
      "-o",
      partial_path,
      base + "/partial",
    ])
    record_result(
      curl_partial.status == 7 &&
      !@fs.exists(partial_path) &&
      @testkit.contains_bytes(curl_partial.stderr, "response body"),
      "curl: partial response cleanup mismatch",
      failures,
    )
    let collision_root = @fs.tmpdir(prefix="mooncmd-http-collision")
    defer (@fs.rmdir(collision_root, recursive=true) catch { _ => () })
    let original = @path.Path(collision_root).join(Path("fixed")).to_string()
    let numbered = original + ".1"
    @fs.write_file(original, b"original")
    let wget_collision = @testkit.run(
      wget,
      ["-q", base + "/fixed"],
      cwd=collision_root,
    )
    record_result(
      wget_collision.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(original).binary(), b"original") &&
      @testkit.bytes_equal(@fs.read_file(numbered).binary(), b"hello"),
      "wget: numbered output collision mismatch",
      failures,
    )
    let truncate = @path.Path(collision_root)
      .join(Path("truncate.bin"))
      .to_string()
    @fs.write_file(truncate, b"old-data")
    let wget_truncate = @testkit.run(wget, [
      "-q", "-t", "1", "-O", truncate, "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      wget_truncate.status == 4 && @fs.read_file(truncate).binary().is_empty(),
      "wget: -O did not truncate before connection setup",
      failures,
    )
    let wget_name_root = @fs.tmpdir(prefix="mooncmd-http-wget-name")
    defer (@fs.rmdir(wget_name_root, recursive=true) catch { _ => () })
    let wget_encoded = @path.Path(wget_name_root)
      .join(Path("encoded.txt"))
      .to_string()
    @fs.write_file(wget_encoded, b"old")
    let wget_disposition = @testkit.run(
      wget,
      ["-q", "--content-disposition", base + "/named-encoded"],
      cwd=wget_name_root,
    )
    record_result(
      wget_disposition.status == 0 &&
      @testkit.bytes_equal(@fs.read_file(wget_encoded).binary(), b"old") &&
      @testkit.bytes_equal(
        @fs.read_file(wget_encoded + ".1").binary(),
        b"hello",
      ),
      "wget: content-disposition duplicate filename behavior mismatch",
      failures,
    )
    let curl_connect_ok = @testkit.run(curl, [
      "-s",
      "--connect-timeout",
      "0.1",
      base + "/fixed",
    ])
    let curl_max_timeout = @testkit.run(curl, [
      "-s",
      "--max-time",
      "0.02",
      base + "/body-stall",
    ])
    let curl_idle_timeout = @testkit.run(curl, [
      "-s",
      "--idle-timeout",
      "0.02",
      base + "/body-stall",
    ])
    let wget_connect_ok = @testkit.run(wget, [
      "-qO-",
      "--connect-timeout=0.1",
      base + "/fixed",
    ])
    let wget_total_timeout = @testkit.run(wget, [
      "-qO-",
      "-T",
      "0.02",
      base + "/stall",
    ])
    let wget_read_timeout = @testkit.run(wget, [
      "-qO-",
      "--read-timeout=0.02",
      base + "/body-stall",
    ])
    let wget_idle_timeout = @testkit.run(wget, [
      "-qO-",
      "--idle-timeout=0.02",
      base + "/body-stall",
    ])
    record_result(
      curl_connect_ok.status == 0 &&
      @testkit.bytes_equal(curl_connect_ok.stdout, b"hello") &&
      curl_max_timeout.status == 28 &&
      curl_idle_timeout.status == 28 &&
      wget_connect_ok.status == 0 &&
      @testkit.bytes_equal(wget_connect_ok.stdout, b"hello") &&
      wget_total_timeout.status == 4 &&
      wget_read_timeout.status == 4 &&
      wget_idle_timeout.status == 4,
      "curl/wget timeout expiry or successful connection mismatch",
      failures,
    )
  }
}

///|
async fn run_https_cases(bin_root : String, failures : Array[String]) -> Unit {
  if @platform.is_windows() {
    return
  }
  @async.with_task_group <| group => {
    let current = @env.current_dir().unwrap_or(".")
    let cert = @path.Path(current)
      .join(Path("tests/fixtures/http/cert.pem"))
      .to_string()
    let key = @path.Path(current)
      .join(Path("tests/fixtures/http/key.pem"))
      .to_string()
    let output_root = @fs.tmpdir(prefix="mooncmd-https")
    defer (@fs.rmdir(output_root, recursive=true) catch { _ => () })
    let log = @path.Path(output_root).join(Path("server.log")).to_string()
    let server = @process.spawn(
      group,
      @env.args()[0],
      ["--https-server", cert, key, log],
      no_console_window=true,
      no_wait=true,
    )
    let mut port : Int? = None
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
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl_verified = @testkit.run(curl, ["-sf", url])
    let curl_insecure = @testkit.run(curl, ["-skf", url])
    let wget_verified = @testkit.run(wget, ["-qO-", url])
    let wget_insecure = @testkit.run(wget, [
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

///|
async fn run_connect_proxy(
  server : @socket.TcpServer,
  requests : Ref[Int],
) -> Unit {
  server.run_forever() <| ((client, _) => {
    requests.val = requests.val + 1
    guard client.read_until("\r\n") is Some(line) else { return }
    while client.read_until("\r\n") is Some(header) && header != "" {

    }
    guard line.has_prefix("CONNECT ") && line.find(" HTTP/") is Some(end) else {
      client.write("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n")
      return
    }
    let authority = line[8:end].to_owned()
    let destination = @socket.Tcp::connect(@socket.Addr::parse(authority))
    defer destination.close()
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    @async.with_task_group <| relay => {
      relay.spawn_bg(no_wait=true) <| () => { client.write_reader(destination) }
      destination.write_reader(client)
    }
  })
}

///|
async fn run_proxy_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let origin = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => origin.close())
    group.spawn_bg(no_wait=true) <| () => {
      origin.run_forever() <| ((_, _, connection) => {
        connection.send_response(200, "OK", extra_headers={
          "Content-Length": "5",
        })
        connection..write("hello").end_response()
      })
    }
    let proxy = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => proxy.close())
    let proxy_requests = Ref(0)
    group.spawn_bg(no_wait=true, () => run_connect_proxy(proxy, proxy_requests))
    let proxy_url = "http://127.0.0.1:\{proxy.addr.port()}"
    let url = "http://127.0.0.1:\{origin.addr.port()}/fixed"
    let curl = @testkit.executable_path(bin_root, "curl")
    let wget = @testkit.executable_path(bin_root, "wget")
    let curl_proxy = @testkit.run(
      curl,
      ["-s", "--proxy", proxy_url, "--noproxy", "", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_proxy = @testkit.run(
      wget,
      ["-qO-", url],
      extra_env=Map([
        ("http_proxy", proxy_url),
        ("HTTP_PROXY", ""),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_proxy.status == 0 &&
      @testkit.bytes_equal(curl_proxy.stdout, b"hello") &&
      wget_proxy.status == 0 &&
      @testkit.bytes_equal(wget_proxy.stdout, b"hello") &&
      proxy_requests.val == 2,
      "HTTP CONNECT proxy transfer mismatch",
      failures,
    )
    let curl_bypass = @testkit.run(
      curl,
      ["-s", "--proxy", "http://127.0.0.1:1", "--noproxy", "127.0.0.1", url],
      extra_env=Map([("NO_PROXY", "")]),
    )
    let wget_bypass = @testkit.run(
      wget,
      ["-qO-", "--no-proxy", url],
      extra_env=Map([
        ("http_proxy", "http://127.0.0.1:1"),
        ("HTTP_PROXY", "http://127.0.0.1:1"),
        ("NO_PROXY", ""),
        ("no_proxy", ""),
      ]),
    )
    record_result(
      curl_bypass.status == 0 &&
      @testkit.bytes_equal(curl_bypass.stdout, b"hello") &&
      wget_bypass.status == 0 &&
      @testkit.bytes_equal(wget_bypass.stdout, b"hello") &&
      proxy_requests.val == 2,
      "curl --noproxy or wget --no-proxy did not bypass the proxy",
      failures,
    )
  }
}
