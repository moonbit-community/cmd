///|
test "URL host input encoding is explicit and rejects unsupported encodings" {
  assert_false(parse_options(["http://bücher.example/"]).utf8_hosts)
  for encoding in ["UTF-8", "utf8"] {
    assert_true(
      parse_options(["--local-encoding=" + encoding, "http://bücher.example/"]).utf8_hosts,
    )
  }
  for encoding in ["ASCII", "US-ASCII", "ANSI_X3.4-1968"] {
    assert_false(
      parse_options(["--local-encoding=" + encoding, "http://bücher.example/"]).utf8_hosts,
    )
  }
  for encoding in ["", "ISO-8859-1", "UTF-16"] {
    try
      parse_options(["--local-encoding=" + encoding, "http://bücher.example/"])
    catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("unsupported URL encoding accepted")
    }
  }
}

///|
test "Basic authentication and session persistence are explicit" {
  let options = parse_options([
    "--user=first", "--http-user=final", "--password=p:a:ss", "--load-cookies=in.txt",
    "--save-cookies=out.txt", "--keep-session-cookies", "http://localhost/",
  ])
  assert_eq(options.user, Some("final"))
  assert_eq(options.password, Some("p:a:ss"))
  assert_false(options.auth_no_challenge)
  assert_eq(options.load_cookies, Some("in.txt"))
  assert_eq(options.save_cookies, Some("out.txt"))
  assert_true(options.keep_session_cookies)
}

///|
test "HTTP options map upstream HTTP controls" {
  let options = parse_options([
    "-q", "-O-", "-i", "urls.txt", "--header=X-Marker: value", "--method=PATCH",
    "--body-data=payload", "--retry-on-http-error=429,503", "--tries=3", "--max-redirect=4",
    "--connect-timeout=1.5", "--read-timeout=.25", "https://example.test/x",
  ])
  assert_true(options.quiet)
  assert_eq(options.output_document, Some("-"))
  assert_eq(options.input_files, ["urls.txt"])
  assert_eq(options.headers, [@netops.http_header("X-Marker", "value")])
  assert_true(options.request_method is @netops.Patch)
  assert_true(options.method_explicit)
  assert_true(options.body is @netops.BytesBody(b"payload"))
  assert_eq(options.retry_http_statuses, [429, 503])
  assert_eq(options.tries, 3)
  assert_eq(options.max_redirects, 4)
  assert_eq(options.connect_timeout_ms, 1500)
  assert_eq(options.read_timeout_ms, 250)
  assert_eq(options.urls, ["https://example.test/x"])
}

///|
test "HTTP options reject invalid methods, statuses, and timeouts" {
  for
    args in [
      ["--method=CUSTOM", "https://example.test"],
      ["--retry-on-http-error=99", "https://example.test"],
      ["--read-timeout=0", "https://example.test"],
      ["--max-redirect=-1", "https://example.test"],
    ] {
    try parse_options(args) catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("expected wget usage error")
    }
  }
}

///|
test "repeated inputs and option precedence" {
  let options = parse_options([
    "-i", "one", "--input-file=two", "--method=post", "https://example.test",
  ])
  assert_eq(options.request_method, @netops.Post)
  assert_true(options.method_explicit)
  assert_eq(options.input_files, ["one", "two"])
  let logs = parse_options([
    "-o", "first", "-a", "second", "https://example.test",
  ])
  assert_eq(logs.log_file, Some("second"))
  assert_true(logs.append_log)
  let unlimited = parse_options(["--tries=0", "https://example.test"])
  assert_eq(unlimited.tries, 0)
  let body_without_method = parse_options([
    "--body-data=value", "https://example.test",
  ])
  assert_true(body_without_method.request_method is @netops.Get)
  assert_false(body_without_method.method_explicit)
  let conflicting_body = parse_options([
    "--method=POST", "--body-data=value", "--body-file=file", "https://example.test",
  ])
  assert_true(conflicting_body.body_options_conflict)
}

///|
test "timeout options reject invalid and out-of-range timers" {
  for
    args in [
      ["-T", "0", "https://example.test"],
      ["--connect-timeout=-1", "https://example.test"],
      ["--connect-timeout=nan", "https://example.test"],
      ["--read-timeout=inf", "https://example.test"],
      ["--idle-timeout=2147483.648", "https://example.test"],
      ["--waitretry=0", "https://example.test"],
    ] {
    try parse_options(args) catch {
      UsageError(_) => ()
    } noraise {
      _ => fail("expected wget timer usage error")
    }
  }
}

///|
test "retries transient connections but gates connection refusal" {
  let options = default_options()
  assert_true(
    can_retry(
      options,
      @netops.ConnectionFailure,
      None,
      "connection reset by peer",
    ),
  )
  assert_false(
    can_retry(options, @netops.ConnectionFailure, None, "connection refused"),
  )
  options.retry_connection_refused = true
  assert_true(
    can_retry(options, @netops.ConnectionFailure, None, "connection refused"),
  )
}

///|
test "terminal progress formatting is a single dynamic line" {
  assert_eq(progress_text("file", 5L, Some(10L)), "\rfile 50% [5/10]\u{1b}[K")
  assert_eq(progress_text("file", 5L, None), "\rfile 5 bytes\u{1b}[K")
}
