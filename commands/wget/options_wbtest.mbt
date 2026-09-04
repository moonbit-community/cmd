///|
test "wget phase2 options map upstream HTTP controls" {
  let options = parse_wget_options([
    "-q", "-O-", "-i", "urls.txt", "--header=X-Marker: value", "--method=PATCH",
    "--body-data=payload", "--retry-on-http-error=429,503", "--tries=3", "--max-redirect=4",
    "--connect-timeout=1.5", "--read-timeout=.25", "https://example.test/x",
  ])
  assert_true(options.quiet)
  assert_eq(options.output_document, Some("-"))
  assert_eq(options.input_files, ["urls.txt"])
  assert_eq(options.headers, [@netops.http_header("X-Marker", "value")])
  assert_true(options.request_method is @netops.Patch)
  assert_true(options.body is @netops.BytesBody(b"payload"))
  assert_eq(options.retry_http_statuses, [429, 503])
  assert_eq(options.tries, 3)
  assert_eq(options.max_redirects, 4)
  assert_eq(options.connect_timeout_ms, 1500)
  assert_eq(options.read_timeout_ms, 250)
  assert_eq(options.urls, ["https://example.test/x"])
}

///|
test "wget phase2 options reject invalid methods, statuses, and timeouts" {
  for
    args in [
      ["--method=CUSTOM", "https://example.test"],
      ["--retry-on-http-error=99", "https://example.test"],
      ["--read-timeout=0", "https://example.test"],
      ["--max-redirect=-1", "https://example.test"],
    ] {
    try parse_wget_options(args) catch {
      WgetUsageError(_) => ()
    } noraise {
      _ => fail("expected wget usage error")
    }
  }
}

///|
test "wget accepts documented methods and preserves repeated option order" {
  for
    name in [
      "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH",
    ] {
    let options = parse_wget_options([
      "-i",
      "one",
      "--input-file=two",
      "--method=" + name,
      "https://example.test",
    ])
    assert_eq(options.request_method, @netops.parse_http_method(name))
    assert_eq(options.input_files, ["one", "two"])
  }
  let logs = parse_wget_options([
    "-o", "first", "-a", "second", "https://example.test",
  ])
  assert_eq(logs.log_file, Some("second"))
  assert_true(logs.append_log)
  let unlimited = parse_wget_options(["--tries=0", "https://example.test"])
  assert_eq(unlimited.tries, 0)
}

///|
test "wget timeout options reject invalid and out-of-range timers" {
  for
    args in [
      ["-T", "0", "https://example.test"],
      ["--connect-timeout=-1", "https://example.test"],
      ["--connect-timeout=nan", "https://example.test"],
      ["--read-timeout=inf", "https://example.test"],
      ["--idle-timeout=2147483.648", "https://example.test"],
      ["--waitretry=0", "https://example.test"],
    ] {
    try parse_wget_options(args) catch {
      WgetUsageError(_) => ()
    } noraise {
      _ => fail("expected wget timer usage error")
    }
  }
}

///|
test "wget retries transient connections but gates connection refusal" {
  let options = default_options()
  assert_true(
    wget_can_retry(
      options,
      @netops.ConnectionFailure,
      None,
      "connection reset by peer",
    ),
  )
  assert_false(
    wget_can_retry(
      options,
      @netops.ConnectionFailure,
      None,
      "connection refused",
    ),
  )
  options.retry_connection_refused = true
  assert_true(
    wget_can_retry(
      options,
      @netops.ConnectionFailure,
      None,
      "connection refused",
    ),
  )
}

///|
test "wget terminal progress formatting is a single dynamic line" {
  assert_eq(
    wget_progress_text("file", 5L, Some(10L)),
    "\rfile 50% [5/10]\u{1b}[K",
  )
  assert_eq(wget_progress_text("file", 5L, None), "\rfile 5 bytes\u{1b}[K")
}
