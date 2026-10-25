///|
async test "shell retains signal termination separately from explicit exit141" {
  let session = Session::new(env={})
  assert_eq(normalize_status(-13, session.context), 141)
  assert_eq(
    session.last_signal(),
    match @async.platform {
      Windows => None
      _ => Some(13)
    },
  )
  assert_eq(session.feed("exit 141"), Exit(141))
  assert_eq(session.last_signal(), None)
}

///|
async test "shell pipeline termination follows its last command" {
  let session = Session::new(env={})
  assert_eq(session.feed("printf ignored | exit 141"), Completed(141))
  assert_eq(session.last_signal(), None)
}
