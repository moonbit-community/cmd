///|
test "curl Basic credentials and cookie sources preserve argument values" {
  let options = parse_curl_options([
    "-u", "user:p:a:ss", "-b", "a=one", "--cookie=jar.txt", "-c", "out.txt", "http://localhost/",
  ])
  assert_eq(options.user, Some("user:p:a:ss"))
  assert_eq(options.cookies, ["a=one", "jar.txt"])
  assert_eq(options.cookie_jar, Some("out.txt"))
}

///|
test "curl phase2 options preserve repeated data order and HTTP controls" {
  let options = parse_curl_options([
    "-sSL", "--max-redirs", "3", "-H", "X-Marker: value", "-X", "PATCH", "-d", "a=1",
    "--data-raw", "b=2", "--retry", "2", "--retry-delay", "0", "--connect-timeout",
    "1.5", "-m", "4", "https://example.test/x",
  ])
  assert_true(options.silent)
  assert_true(options.show_error)
  assert_true(options.location)
  assert_eq(options.max_redirects, 3)
  assert_true(options.request_method is Some(@netops.Patch))
  assert_eq(options.headers, [@netops.http_header("X-Marker", "value")])
  assert_true(options.data_specs[0].kind is FormData)
  assert_eq(options.data_specs[0].value, "a=1")
  assert_true(options.data_specs[1].kind is RawData)
  assert_eq(options.data_specs[1].value, "b=2")
  assert_eq(options.retry_count, 2)
  assert_eq(options.retry_delay_ms, 0)
  assert_eq(options.connect_timeout_ms, 1500)
  assert_eq(options.max_time_ms, Some(4000))
  assert_eq(options.urls, ["https://example.test/x"])
}

///|
test "curl phase2 options reject unsupported and conflicting forms" {
  for
    args in [
      ["-X", "CUSTOM", "https://example.test"],
      ["-J", "https://example.test/file"],
      ["-d", "body", "-T", "file", "https://example.test"],
      ["--max-redirs", "-2", "https://example.test"],
      ["--retry-delay", "0.5", "https://example.test"],
      ["--retry-max-time", "0.5", "https://example.test"],
    ] {
    try parse_curl_options(args) catch {
      CurlUsageError(_) => ()
    } noraise {
      _ => fail("expected curl usage error")
    }
  }
}

///|
test "curl max-redirs accepts the upstream unlimited sentinel" {
  let options = parse_curl_options([
    "-L", "--max-redirs", "-1", "https://example.test",
  ])
  assert_eq(options.max_redirects, -1)
}

///|
test "curl accepts the complete documented HTTP method set" {
  for
    (name, expected_method) in [
      ("GET", @netops.Get),
      ("HEAD", @netops.Head),
      ("POST", @netops.Post),
      ("PUT", @netops.Put),
      ("DELETE", @netops.Delete),
      ("CONNECT", @netops.Connect),
      ("OPTIONS", @netops.Options),
      ("TRACE", @netops.Trace),
      ("PATCH", @netops.Patch),
    ] {
    let options = parse_curl_options(["-X", name, "https://example.test"])
    assert_eq(options.request_method, Some(expected_method))
  }
}

///|
test "curl zero timeout values select their upstream disabled defaults" {
  let options = parse_curl_options([
    "--connect-timeout", "0", "--max-time", "0", "--retry-max-time", "0", "https://example.test",
  ])
  assert_eq(options.connect_timeout_ms, 300_000)
  assert_eq(options.max_time_ms, None)
  assert_eq(options.retry_max_time_ms, None)
  assert_eq(curl_retry_delay(options, 1), 1000)
  assert_eq(curl_retry_delay(options, 2), 2000)
  assert_eq(curl_retry_delay(options, 20), 600_000)
}

///|
test "curl timeout options reject invalid and out-of-range timers" {
  for
    args in [
      ["--connect-timeout", "-1", "https://example.test"],
      ["--connect-timeout", "nan", "https://example.test"],
      ["--max-time", "inf", "https://example.test"],
      ["--max-time", "2147483.648", "https://example.test"],
      ["--idle-timeout", "0", "https://example.test"],
      ["--idle-timeout", "2147483.648", "https://example.test"],
      ["--retry-max-time", "2147484", "https://example.test"],
    ] {
    try parse_curl_options(args) catch {
      CurlUsageError(_) => ()
    } noraise {
      _ => fail("expected curl timer usage error")
    }
  }
}

///|
test "curl progress formatting separates terminal and redirected stderr" {
  assert_eq(curl_progress_text(5L, Some(10L), true, false), "\r50% 5\u{1b}[K")
  assert_eq(curl_progress_text(5L, Some(10L), false, false), "")
  assert_eq(curl_progress_text(10L, Some(10L), false, true), "100% 10\n")
}

///|
test "curl retry diagnostics preserve show-error without inventing HTTP failures" {
  let options = default_curl_options()
  assert_true(curl_reports_retry_error(options, @netops.PartialBodyFailure))
  options.silent = true
  assert_false(curl_reports_retry_error(options, @netops.PartialBodyFailure))
  options.show_error = true
  assert_true(curl_reports_retry_error(options, @netops.PartialBodyFailure))
  assert_false(curl_reports_retry_error(options, @netops.HttpStatusFailure))
  options.fail = true
  assert_true(curl_reports_retry_error(options, @netops.HttpStatusFailure))
}

///|
test "curl fixed-length diagnostics use the structured missing byte count" {
  let context : @netops.TransferFailureContext = {
    phase: @netops.ResponseBody,
    framing: Some(@netops.FixedLength(9L)),
    received_bytes: 5L,
    committed_bytes: 0L,
    write_outcome_uncertain: true,
  }
  assert_eq(
    curl_error_message(
      @netops.PartialBodyFailure,
      "internal detail",
      Some(context),
    ),
    "end of response with 4 bytes missing",
  )
  assert_eq(
    curl_error_message(@netops.OutputFailure, "write failed", Some(context)),
    "write failed",
  )
  assert_eq(
    curl_error_message(@netops.PartialBodyFailure, "chunk ended", None),
    "chunk ended",
  )
}

///|
test "curl body failures need all-error retries and keep their transfer exit codes" {
  let options = default_curl_options()
  for
    (kind, code) in [
      (@netops.PartialBodyFailure, 18),
      (@netops.ReceiveFailure, 56),
      (@netops.EmptyReplyFailure, 52),
      (@netops.RewindFailure, 65),
    ] {
    assert_eq(curl_exit_kind(kind), code)
    assert_false(curl_can_retry(options, kind, None))
  }
  options.retry_connection_refused = true
  assert_false(curl_can_retry(options, @netops.PartialBodyFailure, None))
  options.retry_all_errors = true
  assert_true(curl_can_retry(options, @netops.PartialBodyFailure, None))
  assert_true(curl_can_retry(options, @netops.ReceiveFailure, None))
  assert_false(curl_can_retry(options, @netops.OutputFailure, None))
}
