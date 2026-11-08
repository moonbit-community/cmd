///|
async fn run_http_cases(bin_root : String, failures : Array[String]) -> Unit {
  @async.with_task_group <| group => {
    let mut wget_retry_attempts = 0
    let mut curl_retry_attempts = 0
    let mut curl_retry_all_attempts = 0
    let mut curl_retry_limited_attempts = 0
    let mut wget_retry_limited_attempts = 0
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    group.spawn_bg(no_wait=true, () => @harness.run_http_fixture(server))
    // Counted retries stay local; ordinary responses use the contract fixture.
    let stateful = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => stateful.close())
    group.spawn_bg(no_wait=true) <| () => {
      stateful.run_forever() <| ((request, _body, connection) => {
        match request.path {
          "/cross-origin" =>
            connection
            ..send_response(307, "Temporary Redirect", extra_headers={
              "Location": "http://127.0.0.1:\{server.addr.port()}/cross-origin-target",
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
          _ => connection..send_response(400, "Bad Request").end_response()
        }
      })
    }
    let base = "http://127.0.0.1:\{server.addr.port()}"
    let stateful_base = "http://127.0.0.1:\{stateful.addr.port()}"

    let wget_fixed = @harness.run_command(bin_root, "wget", [
      "-O",
      "-",
      base + "/fixed",
    ])
    record_result(
      wget_fixed.status == 0 &&
      @harness.bytes_equal(wget_fixed.stdout, b"hello") &&
      @harness.contains_bytes(wget_fixed.stderr, "HTTP request sent") &&
      @harness.contains_bytes(wget_fixed.stderr, "saved [5]"),
      "wget: fixed-length response or progress feedback mismatch",
      failures,
    )
    let wget_quiet = @harness.run_command(bin_root, "wget", [
      "-q",
      "-O",
      "-",
      base + "/fixed",
    ])
    record_result(
      wget_quiet.status == 0 &&
      @harness.bytes_equal(wget_quiet.stdout, b"hello") &&
      wget_quiet.stderr.is_empty(),
      "wget: -q did not suppress progress",
      failures,
    )
    let wget_missing = @harness.run_command(bin_root, "wget", [
      "-O",
      "-",
      base + "/missing",
    ])
    record_result(
      wget_missing.status == 8 &&
      wget_missing.stdout.is_empty() &&
      @harness.contains_bytes(wget_missing.stderr, "HTTP status 404 Not Found"),
      "wget: HTTP error behavior mismatch",
      failures,
    )
    let wget_quiet_missing = @harness.run_command(bin_root, "wget", [
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
    let curl_chunked = @harness.run_command(bin_root, "curl", [
      base + "/chunked",
    ])
    record_result(
      curl_chunked.status == 0 &&
      @harness.bytes_equal(curl_chunked.stdout, b"slow-stream") &&
      @harness.contains_bytes(curl_chunked.stderr, "0% 11"),
      "curl: unknown-length response or progress feedback mismatch",
      failures,
    )
    let curl_silent = @harness.run_command(bin_root, "curl", [
      "-s",
      "-f",
      base + "/missing",
    ])
    record_result(
      curl_silent.status == 22 && curl_silent.stderr.is_empty(),
      "curl: -s did not suppress errors",
      failures,
    )
    let curl_show_error = @harness.run_command(bin_root, "curl", [
      "-sS",
      "-f",
      base + "/missing",
    ])
    record_result(
      curl_show_error.status == 22 &&
      @harness.contains_bytes(
        curl_show_error.stderr,
        "HTTP status 404 Not Found",
      ),
      "curl: -sS did not restore the HTTP error",
      failures,
    )
    let output_root = @fs.tmpdir(prefix="mooncmd-http")
    defer cleanup_compat_fixture(output_root)
    let output = @path.Path(output_root).join(Path("response")).to_string()
    let wget_log = @path.Path(output_root).join(Path("wget.log")).to_string()
    let wget_logged = @harness.run_command(bin_root, "wget", [
      "-o",
      wget_log,
      "-O",
      "-",
      base + "/fixed",
    ])
    record_result(
      wget_logged.status == 0 &&
      @harness.bytes_equal(wget_logged.stdout, b"hello") &&
      wget_logged.stderr.is_empty() &&
      @harness.contains_bytes(
        @fs.read_file(wget_log).binary(),
        "HTTP request sent",
      ) &&
      @harness.contains_bytes(@fs.read_file(wget_log).binary(), "saved [5]"),
      "wget: -o did not route diagnostics to its log",
      failures,
    )
    let curl_file = @harness.run_command(bin_root, "curl", [
      "-s",
      "-o",
      output,
      base + "/fixed",
    ])
    record_result(
      curl_file.status == 0 &&
      curl_file.stdout.is_empty() &&
      @harness.bytes_equal(@fs.read_file(output).binary(), b"hello"),
      "curl: file output mismatch",
      failures,
    )
    let curl_timeout = @harness.run_command(bin_root, "curl", [
      "--idle-timeout",
      "0.02",
      base + "/stall",
    ])
    record_result(
      curl_timeout.status == 28 &&
      @harness.contains_bytes(curl_timeout.stderr, "timed out after 20"),
      "curl: idle timeout did not fail promptly",
      failures,
    )
    // These assertions apply to both workspace and published launches.
    {
      let wget_redirect = @harness.run_command(bin_root, "wget", [
        "-q",
        "-O",
        "-",
        base + "/redirect",
      ])
      record_result(
        wget_redirect.status == 0 &&
        @harness.bytes_equal(wget_redirect.stdout, b"hello") &&
        wget_redirect.stderr.is_empty(),
        "wget: default relative redirect handling mismatch",
        failures,
      )
      let curl_redirect = @harness.run_command(bin_root, "curl", [
        "-s",
        base + "/redirect",
      ])
      record_result(
        curl_redirect.status == 0 && curl_redirect.stdout.is_empty(),
        "curl: followed a redirect without -L",
        failures,
      )
      let curl_location = @harness.run_command(bin_root, "curl", [
        "-sL",
        base + "/redirect",
      ])
      record_result(
        curl_location.status == 0 &&
        @harness.bytes_equal(curl_location.stdout, b"hello"),
        "curl: -L relative redirect handling mismatch",
        failures,
      )
    }
    let curl_redirect_zero = @harness.run_command(bin_root, "curl", [
      "-sL",
      "--max-redirs",
      "0",
      base + "/redirect",
    ])
    let curl_redirect_one = @harness.run_command(bin_root, "curl", [
      "-sL",
      "--max-redirs",
      "1",
      base + "/chain-1",
    ])
    let curl_redirect_two = @harness.run_command(bin_root, "curl", [
      "-sL",
      "--max-redirs",
      "2",
      base + "/chain-1",
    ])
    let curl_redirect_unlimited = @harness.run_command(bin_root, "curl", [
      "-sL",
      "--max-redirs",
      "-1",
      base + "/chain-1",
    ])
    let wget_redirect_zero = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--max-redirect=0",
      base + "/redirect",
    ])
    let wget_redirect_one = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--max-redirect=1",
      base + "/chain-1",
    ])
    let wget_redirect_two = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--max-redirect=2",
      base + "/chain-1",
    ])
    record_result(
      curl_redirect_zero.status == 47 &&
      curl_redirect_one.status == 47 &&
      curl_redirect_two.status == 0 &&
      @harness.bytes_equal(curl_redirect_two.stdout, b"hello") &&
      curl_redirect_unlimited.status == 0 &&
      @harness.bytes_equal(curl_redirect_unlimited.stdout, b"hello") &&
      wget_redirect_zero.status == 7 &&
      wget_redirect_one.status == 7 &&
      wget_redirect_two.status == 0 &&
      @harness.bytes_equal(wget_redirect_two.stdout, b"hello"),
      "curl/wget redirect limit behavior mismatch",
      failures,
    )
    let curl_last_status = @harness.run_command(bin_root, "curl", [
      "-sf",
      base + "/missing",
      base + "/fixed",
    ])
    record_result(
      curl_last_status.status == 0 &&
      @harness.bytes_equal(curl_last_status.stdout, b"hello"),
      "curl: final transfer did not determine the process status",
      failures,
    )
    let curl_loop = @harness.run_command(bin_root, "curl", [
      "-sSL",
      base + "/loop-a",
    ])
    record_result(
      curl_loop.status == 47 &&
      @harness.contains_bytes(curl_loop.stderr, "redirect loop"),
      "curl: redirect loop status mismatch",
      failures,
    )
    let curl_post = @harness.run_command(bin_root, "curl", [
      "-s",
      "-d",
      "alpha=one",
      "--data-raw",
      "beta=two",
      base + "/echo-body",
    ])
    record_result(
      curl_post.status == 0 &&
      @harness.bytes_equal(curl_post.stdout, b"alpha=one&beta=two"),
      "curl: repeated data body mismatch",
      failures,
    )
    let data_root = @fs.tmpdir(prefix="mooncmd-http-data")
    defer cleanup_compat_fixture(data_root)
    let data_path = @path.Path(data_root).join(Path("input.bin")).to_string()
    @fs.write_file(data_path, b"a\r\nb\x00c")
    let curl_form_file = @harness.run_command(bin_root, "curl", [
      "-s",
      "-d",
      "@" + data_path,
      base + "/echo-body",
    ])
    let curl_raw = @harness.run_command(bin_root, "curl", [
      "-s",
      "--data-raw",
      "@literal",
      base + "/echo-body",
    ])
    let curl_binary = @harness.run_command(bin_root, "curl", [
      "-s",
      "--data-binary",
      "@" + data_path,
      base + "/echo-body",
    ])
    let curl_encoded = @harness.run_command(bin_root, "curl", [
      "-s",
      "--data-urlencode",
      "field@" + data_path,
      base + "/echo-body",
    ])
    let curl_empty_data = @harness.run_command(bin_root, "curl", [
      "-s",
      "--data-raw",
      "",
      "--data-urlencode",
      "a b",
      base + "/echo-body",
    ])
    record_result(
      curl_form_file.status == 0 &&
      @harness.bytes_equal(curl_form_file.stdout, b"abc") &&
      curl_raw.status == 0 &&
      @harness.bytes_equal(curl_raw.stdout, b"@literal") &&
      curl_binary.status == 0 &&
      @harness.bytes_equal(curl_binary.stdout, b"a\r\nb\x00c") &&
      curl_encoded.status == 0 &&
      @harness.bytes_equal(curl_encoded.stdout, b"field=a%0D%0Ab%00c") &&
      curl_empty_data.status == 0 &&
      @harness.bytes_equal(curl_empty_data.stdout, b"&a%20b"),
      "curl: data file/raw/binary/urlencode behavior mismatch",
      failures,
    )
    let upload_path = @path.Path(data_root).join(Path("upload.bin")).to_string()
    @fs.write_file(upload_path, b"upload\x00bytes")
    let curl_upload = @harness.run_command(bin_root, "curl", [
      "-s",
      "-T",
      upload_path,
      base + "/echo-body",
    ])
    let curl_upload_twice = @harness.run_command(bin_root, "curl", [
      "-s",
      "-T",
      upload_path,
      base + "/echo-body",
      base + "/echo-body",
    ])
    let curl_upload_patch = @harness.run_command(bin_root, "curl", [
      "-s",
      "-X",
      "PATCH",
      "-T",
      upload_path,
      base + "/request",
    ])
    let curl_upload_missing = @harness.run_command(bin_root, "curl", [
      "-s",
      "-T",
      upload_path + ".missing",
      base + "/echo-body",
    ])
    record_result(
      curl_upload.status == 0 &&
      @harness.bytes_equal(curl_upload.stdout, b"upload\x00bytes") &&
      curl_upload_twice.status == 0 &&
      @harness.bytes_equal(
        curl_upload_twice.stdout,
        b"upload\x00bytesupload\x00bytes",
      ) &&
      curl_upload_patch.status == 0 &&
      @harness.bytes_equal(curl_upload_patch.stdout, b"PATCH::upload\x00bytes") &&
      curl_upload_missing.status == 26 &&
      curl_upload_missing.stdout.is_empty(),
      "curl: upload file behavior mismatch",
      failures,
    )
    let curl_head = @harness.run_command(bin_root, "curl", [
      "-I",
      base + "/fixed",
    ])
    record_result(
      curl_head.status == 0 &&
      @harness.contains_bytes(curl_head.stdout, "HTTP/1.1 200 OK") &&
      !@harness.contains_bytes(curl_head.stdout, "hello"),
      "curl: HEAD response mismatch",
      failures,
    )
    let named_root = @fs.tmpdir(prefix="mooncmd-http-name")
    defer cleanup_compat_fixture(named_root)
    let curl_named = @harness.run_command(
      bin_root,
      "curl",
      ["-sOJ", base + "/named"],
      cwd=named_root,
    )
    let named_path = @path.Path(named_root)
      .join(Path("fixture.txt"))
      .to_string()
    record_result(
      curl_named.status == 0 &&
      @fs.exists(named_path) &&
      @harness.bytes_equal(@fs.read_file(named_path).binary(), b"hello"),
      "curl: -OJ content-disposition output mismatch",
      failures,
    )
    let basename_path = @path.Path(named_root).join(Path("fixed")).to_string()
    @fs.write_file(basename_path, b"old")
    let curl_basename = @harness.run_command(
      bin_root,
      "curl",
      ["-sO", base + "/fixed"],
      cwd=named_root,
    )
    let encoded_path = @path.Path(named_root)
      .join(Path("encoded.txt"))
      .to_string()
    let curl_encoded_name = @harness.run_command(
      bin_root,
      "curl",
      ["-sOJ", base + "/named-encoded"],
      cwd=named_root,
    )
    let curl_named_partial = @harness.run_command(
      bin_root,
      "curl",
      ["-sSJO", "--remove-on-error", base + "/named-partial"],
      cwd=named_root,
    )
    let named_partial_path = @path.Path(named_root)
      .join(Path("partial.txt"))
      .to_string()
    record_result(
      curl_basename.status == 0 &&
      @harness.bytes_equal(@fs.read_file(basename_path).binary(), b"hello") &&
      curl_encoded_name.status == 0 &&
      @harness.bytes_equal(@fs.read_file(encoded_path).binary(), b"hello") &&
      curl_named_partial.status == 18 &&
      !@fs.exists(named_partial_path),
      "curl: remote filename, collision, or named cleanup mismatch",
      failures,
    )
    for status in [301, 302, 303] {
      let redirected = @harness.run_command(bin_root, "curl", [
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
      let redirected = @harness.run_command(bin_root, "curl", [
        "-sL",
        "-d",
        "body",
        base + "/redirect-\{status}",
      ])
      record_result(
        redirected.status == 0 &&
        @harness.bytes_equal(redirected.stdout, b"body"),
        "curl: \{status} did not preserve the request body",
        failures,
      )
    }
    let curl_request = @harness.run_command(bin_root, "curl", [
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
      @harness.bytes_equal(curl_request.stdout, b"PATCH:present:payload"),
      "curl: method/header/body request mismatch",
      failures,
    )
    let wget_request = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--header=X-Marker: present",
      "--method=PATCH",
      "--body-data=payload",
      base + "/request",
    ])
    record_result(
      wget_request.status == 0 &&
      @harness.bytes_equal(wget_request.stdout, b"PATCH:present:payload"),
      "wget: method/header/body request mismatch",
      failures,
    )
    for
      request_name in [
        "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH",
      ] {
      let checked = @harness.run_command(bin_root, "curl", [
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
    let curl_explicit_redirect = @harness.run_command(bin_root, "curl", [
      "-sL",
      "-X",
      "POST",
      "--data-raw",
      "payload",
      base + "/method-redirect",
    ])
    let wget_explicit_redirect = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      base + "/method-redirect",
    ])
    record_result(
      curl_explicit_redirect.status == 0 &&
      @harness.bytes_equal(curl_explicit_redirect.stdout, b"POST::") &&
      wget_explicit_redirect.status == 0 &&
      @harness.bytes_equal(wget_explicit_redirect.stdout, b"GET::"),
      "explicit request methods were not preserved across redirects",
      failures,
    )
    let cross_redirect = @harness.run_command(bin_root, "curl", [
      "-sL",
      "-X",
      "PATCH",
      "-H",
      "Authorization: secret",
      "--data-raw",
      "payload",
      stateful_base + "/cross-origin",
    ])
    record_result(
      cross_redirect.status == 0 &&
      @harness.bytes_equal(cross_redirect.stdout, b"PATCH:clean:payload"),
      "curl: cross-origin redirect method/body/header behavior mismatch",
      failures,
    )
    let resume_root = @fs.tmpdir(prefix="mooncmd-http-resume")
    defer cleanup_compat_fixture(resume_root)
    let range_ignore_path = @path.Path(resume_root)
      .join(Path("range-ignore"))
      .to_string()
    @fs.write_file(range_ignore_path, b"hel")
    {
      let resume_path = @path.Path(resume_root).join(Path("range")).to_string()
      let wget_resume = @harness.run_command(
        bin_root,
        "wget",
        ["-q", "-c", base + "/range"],
        cwd=resume_root,
      )
      record_result(
        wget_resume.status == 0 &&
        @harness.bytes_equal(@fs.read_file(resume_path).binary(), b"hello"),
        "wget: range resume mismatch",
        failures,
      )
    }
    let wget_range_ignored = @harness.run_command(
      bin_root,
      "wget",
      ["-q", "-c", base + "/range-ignore"],
      cwd=resume_root,
    )
    record_result(
      wget_range_ignored.status == 0 &&
      @harness.bytes_equal(@fs.read_file(range_ignore_path).binary(), b"hello"),
      "wget: ignored range response handling mismatch",
      failures,
    )
    let unchanged_path = @path.Path(resume_root)
      .join(Path("not-modified"))
      .to_string()
    @fs.write_file(unchanged_path, b"original")
    let wget_unchanged = @harness.run_command(
      bin_root,
      "wget",
      ["-q", "-N", base + "/not-modified"],
      cwd=resume_root,
    )
    record_result(
      wget_unchanged.status == 0 &&
      @harness.bytes_equal(@fs.read_file(unchanged_path).binary(), b"original"),
      "wget: timestamping 304 changed the destination",
      failures,
    )
    let conditional_path = @path.Path(resume_root)
      .join(Path("conditional"))
      .to_string()
    @fs.write_file(conditional_path, b"preserved")
    let wget_conditional = @harness.run_command(
      bin_root,
      "wget",
      ["-q", "-N", base + "/conditional"],
      cwd=resume_root,
    )
    record_result(
      wget_conditional.status == 0 &&
      @harness.bytes_equal(
        @fs.read_file(conditional_path).binary(),
        b"preserved",
      ),
      "wget: timestamping did not send a conditional request",
      failures,
    )
    let input_root = @fs.tmpdir(prefix="mooncmd-http-input")
    defer cleanup_compat_fixture(input_root)
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
    let wget_inputs = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "-i",
      input_one,
      "--input-file=" + input_two,
    ])
    let wget_aggregate = @harness.run_command(bin_root, "wget", [
      "-qO-", "-i", input_mixed,
    ])
    let wget_missing_input = @harness.run_command(bin_root, "wget", [
      "-q",
      "-i",
      input_mixed + ".missing",
    ])
    record_result(
      wget_inputs.status == 0 &&
      @harness.bytes_equal(wget_inputs.stdout, b"onetwo") &&
      wget_aggregate.status == 8 &&
      @harness.bytes_equal(wget_aggregate.stdout, b"one") &&
      wget_missing_input.status == 3,
      "wget: input-file parsing or status aggregation mismatch",
      failures,
    )
    let append_log = @path.Path(input_root).join(Path("append.log")).to_string()
    let quiet_log = @path.Path(input_root).join(Path("quiet.log")).to_string()
    @fs.write_file(append_log, b"before\n")
    @fs.write_file(quiet_log, b"untouched\n")
    let wget_append_log = @harness.run_command(bin_root, "wget", [
      "-a",
      append_log,
      "-O",
      "-",
      base + "/one",
    ])
    let wget_quiet_log = @harness.run_command(bin_root, "wget", [
      "-q",
      "-a",
      quiet_log,
      "-O",
      "-",
      base + "/one",
    ])
    record_result(
      wget_append_log.status == 0 &&
      @harness.bytes_equal(wget_append_log.stdout, b"one") &&
      @harness.contains_bytes(@fs.read_file(append_log).binary(), "before\n--") &&
      wget_quiet_log.status == 0 &&
      @harness.bytes_equal(wget_quiet_log.stdout, b"one") &&
      @harness.bytes_equal(@fs.read_file(quiet_log).binary(), b"untouched\n"),
      "wget: append log or quiet/log interaction mismatch",
      failures,
    )
    let body_file = @path.Path(input_root).join(Path("body.bin")).to_string()
    @fs.write_file(body_file, b"body\x00bytes")
    let wget_body_file = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--method=POST",
      "--body-file=" + body_file,
      base + "/echo-body",
    ])
    let wget_body_without_method = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--body-data=payload",
      base + "/echo-body",
    ])
    let wget_body_conflict = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--method=POST",
      "--body-data=payload",
      "--body-file=" + body_file,
      base + "/echo-body",
    ])
    let wget_headers = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--header=X-Marker: first",
      "--header=X-Marker: second",
      base + "/request",
    ])
    record_result(
      wget_body_file.status == 0 &&
      @harness.bytes_equal(wget_body_file.stdout, b"body\x00bytes") &&
      wget_body_without_method.status == 1 &&
      wget_body_without_method.stdout.is_empty() &&
      wget_body_conflict.status == 1 &&
      wget_body_conflict.stdout.is_empty() &&
      wget_headers.status == 0 &&
      @harness.bytes_equal(wget_headers.stdout, b"GET:second:"),
      "wget: binary body file or repeated header behavior mismatch",
      failures,
    )
    let wget_retry = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      "--tries=3",
      stateful_base + "/wget-retry",
    ])
    record_result(
      wget_retry.status == 0 &&
      @harness.bytes_equal(wget_retry.stdout, b"hello") &&
      wget_retry_attempts == 3,
      "wget: HTTP retry mismatch",
      failures,
    )
    let curl_retry = @harness.run_command(bin_root, "curl", [
      "-s",
      "--retry",
      "1",
      "--retry-delay",
      "0",
      stateful_base + "/curl-retry",
    ])
    record_result(
      curl_retry.status == 0 &&
      @harness.bytes_equal(curl_retry.stdout, b"hello") &&
      curl_retry_attempts == 2,
      "curl: HTTP retry mismatch",
      failures,
    )
    let curl_retry_all = @harness.run_command(bin_root, "curl", [
      "-sf",
      "--retry",
      "1",
      "--retry-all-errors",
      "--retry-delay",
      "1",
      stateful_base + "/curl-retry-all",
    ])
    let curl_retry_limited = @harness.run_command(bin_root, "curl", [
      "-sf",
      "--retry",
      "3",
      "--retry-max-time",
      "1",
      stateful_base + "/curl-retry-limited",
    ])
    let curl_refused = @harness.run_command(bin_root, "curl", [
      "-s", "--retry", "2", "--retry-connrefused", "--retry-max-time", "1", "http://127.0.0.1:1/unreachable",
    ])
    let wget_retry_limited = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--tries=2",
      "--retry-on-http-error=503",
      "--waitretry=0.001",
      stateful_base + "/wget-retry-limited",
    ])
    let wget_refused = @harness.run_command(bin_root, "wget", [
      "-qO-", "--tries=2", "--retry-connrefused", "--waitretry=0.001", "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      curl_retry_all.status == 0 &&
      @harness.bytes_equal(curl_retry_all.stdout, b"hello") &&
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
      let wget_status = @harness.run_command(bin_root, "wget", [
        "-qO-",
        base + "/" + endpoint,
      ])
      let curl_status = @harness.run_command(bin_root, "curl", [
        "-sf",
        base + "/" + endpoint,
      ])
      record_result(
        wget_status.status == (if endpoint == "unauthorized" { 6 } else { 8 }) &&
        curl_status.status == 22,
        "HTTP error status mapping mismatch for \{endpoint}",
        failures,
      )
    }
    let partial_path = @path.Path(resume_root)
      .join(Path("partial.bin"))
      .to_string()
    let curl_partial = @harness.run_command(bin_root, "curl", [
      "-sS",
      "--remove-on-error",
      "-o",
      partial_path,
      base + "/partial",
    ])
    record_result(
      curl_partial.status == 18 &&
      !@fs.exists(partial_path) &&
      @harness.bytes_equal(
        curl_partial.stderr,
        b"curl: (18) end of response with 6 bytes missing\n",
      ),
      "curl: partial response cleanup mismatch",
      failures,
    )
    let collision_root = @fs.tmpdir(prefix="mooncmd-http-collision")
    defer cleanup_compat_fixture(collision_root)
    let original = @path.Path(collision_root).join(Path("fixed")).to_string()
    let numbered = original + ".1"
    @fs.write_file(original, b"original")
    let wget_collision = @harness.run_command(
      bin_root,
      "wget",
      ["-q", base + "/fixed"],
      cwd=collision_root,
    )
    record_result(
      wget_collision.status == 0 &&
      @harness.bytes_equal(@fs.read_file(original).binary(), b"original") &&
      @harness.bytes_equal(@fs.read_file(numbered).binary(), b"hello"),
      "wget: numbered output collision mismatch",
      failures,
    )
    let truncate = @path.Path(collision_root)
      .join(Path("truncate.bin"))
      .to_string()
    @fs.write_file(truncate, b"old-data")
    let wget_truncate = @harness.run_command(bin_root, "wget", [
      "-q", "-t", "1", "-O", truncate, "http://127.0.0.1:1/unreachable",
    ])
    record_result(
      wget_truncate.status == 4 && @fs.read_file(truncate).binary().is_empty(),
      "wget: -O did not truncate before connection setup",
      failures,
    )
    let wget_name_root = @fs.tmpdir(prefix="mooncmd-http-wget-name")
    defer cleanup_compat_fixture(wget_name_root)
    let wget_encoded = @path.Path(wget_name_root)
      .join(Path("encoded.txt"))
      .to_string()
    @fs.write_file(wget_encoded, b"old")
    let wget_disposition = @harness.run_command(
      bin_root,
      "wget",
      ["-q", "--content-disposition", base + "/named-encoded"],
      cwd=wget_name_root,
    )
    record_result(
      wget_disposition.status == 0 &&
      @harness.bytes_equal(@fs.read_file(wget_encoded).binary(), b"old") &&
      @harness.bytes_equal(
        @fs.read_file(wget_encoded + ".1").binary(),
        b"hello",
      ),
      "wget: content-disposition duplicate filename behavior mismatch",
      failures,
    )
    let curl_connect_ok = @harness.run_command(bin_root, "curl", [
      "-s",
      "--connect-timeout",
      "0.1",
      base + "/fixed",
    ])
    let curl_max_timeout = @harness.run_command(bin_root, "curl", [
      "-s",
      "--max-time",
      "0.02",
      base + "/body-stall",
    ])
    let curl_idle_timeout = @harness.run_command(bin_root, "curl", [
      "-s",
      "--idle-timeout",
      "0.02",
      base + "/body-stall",
    ])
    let wget_connect_ok = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--connect-timeout=0.1",
      base + "/fixed",
    ])
    let wget_total_timeout = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "-T",
      "0.02",
      base + "/stall",
    ])
    let wget_read_timeout = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--read-timeout=0.02",
      base + "/body-stall",
    ])
    let wget_idle_timeout = @harness.run_command(bin_root, "wget", [
      "-qO-",
      "--idle-timeout=0.02",
      base + "/body-stall",
    ])
    record_result(
      curl_connect_ok.status == 0 &&
      @harness.bytes_equal(curl_connect_ok.stdout, b"hello") &&
      curl_max_timeout.status == 28 &&
      curl_idle_timeout.status == 28 &&
      wget_connect_ok.status == 0 &&
      @harness.bytes_equal(wget_connect_ok.stdout, b"hello") &&
      wget_total_timeout.status == 4 &&
      wget_read_timeout.status == 4 &&
      wget_idle_timeout.status == 4,
      "curl/wget timeout expiry or successful connection mismatch",
      failures,
    )
  }
}
