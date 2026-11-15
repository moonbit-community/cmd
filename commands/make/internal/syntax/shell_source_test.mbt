///|
test "GNU direct argv keeps literal linefeeds while shell argv removes them" {
  assert_eq(
    @syntax.shell_source("printf before\nif", ""),
    Some("'printf' 'before\nif'"),
  )
  assert_eq(
    @syntax.shell_source("printf 'before\nafter'", ""),
    Some("'printf' 'before\nafter'"),
  )
  assert_eq(
    @syntax.shell_source("printf \"before\nafter\"", ""),
    Some("printf \"beforeafter\""),
  )
  assert_eq(
    @syntax.shell_source("printf before;\nif", ""),
    Some("printf before;if"),
  )
  assert_eq(
    @syntax.shell_source("printf before # comment\nprintf after", ""),
    Some("printf before # commentprintf after"),
  )
  assert_eq(
    @syntax.shell_source("printf before\nif", ":"),
    Some("printf beforeif"),
  )
  assert_eq(
    @syntax.shell_source("printf before\nif", "", force_shell=true),
    Some("printf beforeif"),
  )
}
