///|
async fn run_tail_follow_cases(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let tail = @testkit.executable_path(bin_root, "tail")
  let append_lines = run_tail_follow_process(
    tail,
    ["--follow", "--sleep-interval", "0.02", "-n", "2"],
    [b"one\ntwo\nthree\n"],
    [b"four\n"],
    [None],
  )
  record_tail_follow_result(
    append_lines, b"two\nthree\nfour\n", "line append", failures,
  )
  let append_bytes = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-c", "2"],
    [b"abcdef"],
    [b"gh"],
    [None],
  )
  record_tail_follow_result(append_bytes, b"efgh", "byte append", failures)
  let no_newline = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-n", "1"],
    [b"left"],
    [b"-right\n"],
    [None],
  )
  record_tail_follow_result(no_newline, b"left-right\n", "no newline", failures)
  let truncated = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02"],
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
  )
  record_tail_follow_result(
    truncated, b"before\nappend\nreset\n", "truncate recovery", failures,
  )
  let multiple = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-q", "-n", "1"],
    [b"first\n", b"second\n"],
    [b"first-add\n", b"second-add\n"],
    [None, None],
  )
  record_tail_follow_result(
    multiple, b"first\nsecond\nfirst-add\nsecond-add\n", "multiple files", failures,
  )
  let with_headers = run_tail_follow_process(
    tail,
    ["-f", "-s", "0.02", "-v", "-n", "1"],
    [b"header-one\n", b"header-two\n"],
    [b"", b""],
    [None, None],
  )
  if !@testkit.contains_bytes(with_headers.0, "==> ") ||
    !@testkit.contains_bytes(with_headers.0, "header-one") ||
    !@testkit.contains_bytes(with_headers.0, "header-two") {
    compat_fail(
      "tail: verbose follow headers missing: \{with_headers.0}",
      failures,
    )
  }
  let default_interval = run_tail_follow_process(
    tail,
    ["-f", "-q", "-n", "0"],
    [b""],
    [b"default\n"],
    [None],
    poll_wait_ms=1100,
  )
  record_tail_follow_result(
    default_interval, b"default\n", "default interval", failures,
  )
}
