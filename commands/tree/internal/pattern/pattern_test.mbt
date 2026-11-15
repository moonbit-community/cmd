///|
test "tree patterns preserve C byte ranges alternatives directory suffixes and malformed reachability" {
  let accepts = (pattern : String, name : String) => {
    @pattern.matches_any(
      [@pattern.compile_pattern(pattern, false)],
      name,
      false,
      false,
    )
  }
  assert_true(accepts("[ab].*", "a.txt"))
  assert_false(accepts("[^a]*", "a.txt"))
  assert_true(accepts("[!a]*", "a.txt"))
  assert_false(accepts("[!a]*", "b.txt"))
  assert_true(accepts("a.txt|b.log", "b.log"))
  assert_true(accepts("|bad", "anything"))
  assert_false(accepts("bad[", "different"))
  assert_true(accepts("bad[", "badx"))
  assert_true(
    @pattern.matches_any(
      [@pattern.compile_pattern("sub/", false)],
      "sub",
      true,
      false,
    ),
  )
  assert_false(accepts("sub/", "sub"))
  assert_true(accepts("keep/**", "keep/inner"))
  assert_true(
    @pattern.matches_any(
      [@pattern.compile_pattern("*.TXT", true)],
      "z.txt",
      false,
      true,
    ),
  )
}
