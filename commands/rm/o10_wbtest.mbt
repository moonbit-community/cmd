///|
test "rm interaction normalization preserves option order and literal operands" {
  assert_eq(interaction_args(["-fI", "--interactive", "a", "--", "-i"]), [
    "-f", "--interactive=once", "--interactive=always", "a", "--", "-i",
  ])
  for
    (value, expected) in [
      ("n", Some("never")),
      ("no", Some("never")),
      ("once", Some("once")),
      ("a", Some("always")),
      ("yes", Some("always")),
      ("", None),
      ("sometimes", None),
    ] {
    assert_eq(interactive_choice(value), expected)
  }
}
