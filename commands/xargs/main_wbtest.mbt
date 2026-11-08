///|
fn replacement_lines(text : String, eof~ : String? = None) -> Array[String] {
  let result : Array[String] = []
  for line in text.split("\n") {
    let value = line.trim().to_owned()
    let is_eof = match eof {
      Some(marker) => value == marker
      None => false
    }
    if value != "" && !is_eof {
      result.push(value)
    } else if is_eof {
      break
    }
  }
  result
}

///|
test "xargs tokenization and replacement keep argument boundaries" {
  assert_eq(parse_words("one 'two three' four\\ five"), [
    "one", "two three", "four five",
  ])
  assert_eq(replacement_lines("  first line  \n\nsecond\n"), [
    "first line", "second",
  ])
  assert_eq(replace_arguments(["pre{}post", "{}"], "{}", "value"), [
    "prevaluepost", "value",
  ])
}

///|
test "xargs maps child outcomes to findutils status classes" {
  assert_eq(child_status(0), 0)
  assert_eq(child_status(1), 123)
  assert_eq(child_status(126), 123)
  assert_eq(child_status(255), 124)
  assert_eq(child_status(-9), 125)
  for status in 1..<=254 {
    assert_eq(combine_status(0, Exited(status)), 123)
  }
  assert_eq(combine_status(0, FailedToLaunch(CommandNotInvokable)), 126)
  assert_eq(combine_status(0, FailedToLaunch(CommandNotFound)), 127)
}
