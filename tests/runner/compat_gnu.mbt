///|
async fn compare_gnu(
  bin_root : String,
  command : String,
  args : Array[String],
  stdin : Bytes,
  failures : Array[String],
) -> Unit {
  let candidate = @testkit.run(
    @testkit.executable_path(bin_root, command),
    args,
    stdin~,
    extra_env=Map([("LC_ALL", "C")]),
  ) catch {
    err => {
      compat_fail(
        "\{command}: candidate differential run failed: \{err}",
        failures,
      )
      return
    }
  }
  let oracle = @testkit.run(
    command,
    args,
    stdin~,
    extra_env=Map([("LC_ALL", "C")]),
  ) catch {
    err => {
      compat_fail("\{command}: GNU oracle failed: \{err}", failures)
      return
    }
  }
  if candidate.status != oracle.status {
    compat_fail(
      "\{command}: GNU status mismatch: candidate=\{candidate.status}, oracle=\{oracle.status}",
      failures,
    )
  }
  if !@testkit.bytes_equal(candidate.stdout, oracle.stdout) {
    compat_fail(
      "\{command}: GNU stdout mismatch: candidate=\{candidate.stdout}, oracle=\{oracle.stdout}",
      failures,
    )
  }
}

///|
async fn compare_gnu_tail_follow(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  let args = ["-f", "-q", "-n", "1"]
  let candidate = run_tail_follow_process(
    @testkit.executable_path(bin_root, "tail"),
    args,
    [b"first\nsecond\n"],
    [b"third\n"],
    [None],
    poll_wait_ms=1200,
  )
  let oracle = run_tail_follow_process(
    "tail",
    args,
    [b"first\nsecond\n"],
    [b"third\n"],
    [None],
    poll_wait_ms=1200,
  )
  if !@testkit.bytes_equal(candidate.0, oracle.0) {
    compat_fail(
      "tail: GNU follow stdout mismatch; candidate=\{candidate.0}, oracle=\{oracle.0}",
      failures,
    )
  }
  if !@testkit.bytes_equal(candidate.1, oracle.1) {
    compat_fail(
      "tail: GNU follow stderr mismatch; candidate=\{candidate.1}, oracle=\{oracle.1}",
      failures,
    )
  }
  let candidate_truncate = run_tail_follow_process(
    @testkit.executable_path(bin_root, "tail"),
    args,
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
    poll_wait_ms=1200,
  )
  let oracle_truncate = run_tail_follow_process(
    "tail",
    args,
    [b"before\n"],
    [b"append\n"],
    [Some(b"reset\n")],
    poll_wait_ms=1200,
  )
  if !@testkit.bytes_equal(candidate_truncate.0, oracle_truncate.0) {
    compat_fail(
      "tail: GNU truncate stdout mismatch; candidate=\{candidate_truncate.0}, oracle=\{oracle_truncate.0}",
      failures,
    )
  }
  if candidate_truncate.1.length() != 0 {
    compat_fail(
      "tail: descriptor follow must recover from truncation silently: \{candidate_truncate.1}",
      failures,
    )
  }
}

///|
async fn run_gnu_differential(
  bin_root : String,
  failures : Array[String],
) -> Unit {
  compare_gnu(bin_root, "base64", [], b"hello world", failures)
  compare_gnu(bin_root, "cat", [], b"\x00\xfftext\n", failures)
  compare_gnu(bin_root, "cut", ["-d,", "-f1,3"], b"x,y,z\n1,2,3\n", failures)
  compare_gnu(bin_root, "head", ["-n", "2"], b"1\n2\n3\n", failures)
  compare_gnu(bin_root, "sha256sum", [], b"hello world", failures)
  compare_gnu(bin_root, "sort", ["-n"], b"10\n2\n1\n", failures)
  compare_gnu(bin_root, "tail", ["-n", "2"], b"1\n2\n3\n", failures)
  compare_gnu_tail_follow(bin_root, failures)
  compare_gnu(bin_root, "tr", ["a-z", "A-Z"], b"hello world\n", failures)
}
