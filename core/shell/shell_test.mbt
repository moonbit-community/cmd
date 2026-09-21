///|
async test "public session keeps source state and distinguishes exit" {
  let session = @shell.Session::new(env={})
  assert_eq(session.feed("if true; then\n"), @shell.NeedMoreInput)
  assert_eq(session.feed("V=ready; fi\n"), @shell.Completed(0))
  assert_eq(session.feed("test \"$V\" = ready\n"), @shell.Completed(0))
  assert_eq(session.feed("exit 7\n"), @shell.Exit(7))
  assert_eq(session.finish(), @shell.Exit(7))
}

///|
async test "public capture reports status and preserves whitespace" {
  let (status, output) = @shell.capture("printf 'value \\n'; false")
  assert_eq(status, 1)
  assert_eq(output, "value \n")
}
