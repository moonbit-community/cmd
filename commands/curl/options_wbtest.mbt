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
test "curl progress formatting separates terminal and redirected stderr" {
  assert_eq(curl_progress_text(5L, Some(10L), true, false), "\r50% 5\u{1b}[K")
  assert_eq(curl_progress_text(5L, Some(10L), false, false), "")
  assert_eq(curl_progress_text(10L, Some(10L), false, true), "100% 10\n")
}
