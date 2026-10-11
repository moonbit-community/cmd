///|
async fn run_stress_cases(bin_root : String, failures : Array[String]) -> Unit {
  // Cross the former product cap; count records without constructing a second
  // 79 MiB expected string or millions of split String objects.
  let run = @testkit.run_with_deadline(
    @testkit.executable_path(bin_root, "seq"),
    ["10000001"],
    120000,
    stdin=b"",
  )
  let sequence = run.output
  let lines = sequence.stdout
    .iter()
    .fold(init=0, (n, b) => n + (if b == b'\n' { 1 } else { 0 }))
  if run.timed_out ||
    run.cleanup_error is Some(_) ||
    sequence.status != 0 ||
    sequence.stderr != b"" ||
    lines != 10000001 ||
    !sequence.stdout.has_suffix(b"10000000\n10000001\n") {
    failures.push(
      "seq over-cap output: timeout=\{run.timed_out}, status=\{sequence.status}, records=\{lines}, cleanup=" +
      run.cleanup_error.unwrap_or("none"),
    )
  }
  for size in [1048576, 16777216, 67108864] {
    expect(
      bin_root,
      "wc",
      ["-c"],
      Some(Bytes::make(size, b'x')),
      0,
      @utf8.encode("\{size}\n"),
      failures,
    )
  }
  expect(
    bin_root,
    "wc",
    ["-l"],
    Some(Bytes::make(1000000, b'\n')),
    0,
    b"1000000\n",
    failures,
  )
}
