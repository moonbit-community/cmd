///|
async test "sleep cancellation cannot accept an immediate successful no-op" {
  // This host child exercises the Native observer only; the retained cohort
  // invokes the actual product sleep command through its configured launcher.
  let (program, args) = if @async.platform is Windows {
    ("cmd.exe", ["/d", "/c", "exit", "0"])
  } else {
    ("/usr/bin/true", [])
  }
  assert_false(observe_sleep_cancellation(program, args))
}
