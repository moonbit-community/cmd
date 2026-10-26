// Port of the unit tests in `ignore/src/default_types.rs`.

///|
test "default_types/default_types_are_sorted" {
  let types = default_types()
  assert_eq(types.length(), 219)
  let mut previous_name = types[0].0[0]
  for i in 1..<types.length() {
    let name = types[i].0[0]
    if compare_utf8(name, previous_name) <= 0 {
      fail(
        "\"\{name}\" should be sorted before \"\{previous_name}\" in `DEFAULT_TYPES`",
      )
    }
    previous_name = name
  }
}

///|
test "default_types/default_types_aliases_are_sorted" {
  for entry in default_types() {
    let aliases = entry.0
    for i in 1..<aliases.length() {
      if compare_utf8(aliases[i - 1], aliases[i]) > 0 {
        fail("this alias list is not sorted: \{Repr(aliases)}")
      }
    }
  }
}
