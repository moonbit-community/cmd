///|
async fn run_stress_cases(bin_root : String, failures : Array[String]) -> Unit {
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
