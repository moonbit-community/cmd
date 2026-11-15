///|
test "GNU argv construction preserves quoting empty words and continuations" {
  assert_eq(
    shell_arguments("printf '' 'a b' a\\ b\n", " \t\n"),
    Some(["printf", "", "a b", "a b\n"]),
  )
  assert_eq(
    shell_arguments("printf before\\\nafter", ""),
    Some(["printf", "beforeafter"]),
  )
  assert_eq(
    shell_arguments("printf \\\n \tafter", ""),
    Some(["printf", "after"]),
  )
  assert_eq(
    shell_arguments("printf 'before\\\nafter'", ""),
    Some(["printf", "before\\\nafter"]),
  )
  assert_eq(shell_source("test x = x; \\\n: ", ""), Some("test x = x; \\\n: "))
  assert_eq(shell_arguments("A=1 printf value\n", ""), None)
  assert_eq(shell_source(" \\\n \t", ""), None)
  assert_eq(
    shell_arguments("printf ''\\\n after", ""),
    Some(["printf", "after"]),
  )
  assert_eq(shell_source(" \t\n", "", force_shell=true), Some(""))
  assert_eq(shell_source("\n \t", "", force_shell=true), Some(" \t"))
  assert_eq(shell_source(" \t", ":", force_shell=true), None)
}
