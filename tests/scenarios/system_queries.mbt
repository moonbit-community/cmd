///|
async fn system_reference(
  work : String,
  root : String,
  name : String,
  args : Array[String],
) -> Unit {
  let locale = { "LC_ALL": "C", "POSIXLY_CORRECT": "1" }
  let reference = @harness.run(name, args, stdin=b"", extra_env=locale)
  let candidate = scenario_run(work, root, name, args, extra_env=locale)
  assert_eq(reference.status, 0)
  assert_eq(candidate.status, 0)
  assert_eq(reference.stderr, b"")
  assert_eq(candidate.stderr, b"")
  if name == "free" {
    // RAM counters can change between invocations. Header layout and configured
    // memory/swap totals must agree; candidate arithmetic uses one snapshot.
    let actual = @utf8.decode(candidate.stdout).split("\n").to_array()
    let oracle = @utf8.decode(reference.stdout).split("\n").to_array()
    assert_eq(actual.length(), oracle.length())
    assert_eq(actual[0], oracle[0])
    for index = 1; index <= 3; index = index + 1 {
      let fields = actual[index]
        .split(" ")
        .filter(s => !s.is_empty())
        .to_array()
      let wanted = oracle[index]
        .split(" ")
        .filter(s => !s.is_empty())
        .to_array()
      assert_eq(fields.length(), wanted.length())
      assert_eq(fields[0], wanted[0])
      assert_eq(fields[1], wanted[1])
    }
  } else if name == "uptime" && candidate.stdout != reference.stdout {
    // Elapsed minutes can roll over while starting the Wasm runtime.
    let after = @harness.run(name, args, stdin=b"", extra_env=locale)
    assert_eq(candidate.stdout, after.stdout)
  } else {
    assert_eq(candidate.stdout, reference.stdout)
  }
}
