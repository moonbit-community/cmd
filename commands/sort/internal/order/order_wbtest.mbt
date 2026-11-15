///|
fn compare_key(left : Bytes, right : Bytes, modifiers : Modifiers) -> Int32 {
  compare_prepared_key(
    transformed_key(left, modifiers),
    transformed_key(right, modifiers),
    modifiers,
  )
}

///|
fn test_modifiers() -> Modifiers {
  {
    ignore_leading_blanks: false,
    dictionary_order: false,
    fold_case: false,
    ignore_nonprinting: false,
    mode: Lexical,
    ordering_modes: 0,
    reverse: false,
  }
}

///|
test "comparison modes cover numeric and text profiles" {
  let modifiers = test_modifiers()
  modifiers.mode = GeneralNumeric
  assert_true(compare_key(b"9", b"1e2", modifiers) < 0)
  assert_true(compare_key(b"text", b"0", modifiers) < 0)
  assert_true(compare_key(b"nan", b"-inf", modifiers) < 0)
  assert_true(compare_key(b"1", b"inf", modifiers) < 0)
  modifiers.mode = HumanNumeric
  assert_true(compare_key(b"10K", b"2M", modifiers) < 0)
  assert_true(compare_key(b"999999K", b"1M", modifiers) < 0)
  modifiers.mode = Month
  assert_true(compare_key(b"JAN", b"Feb", modifiers) < 0)
  modifiers.mode = Version
  assert_true(compare_key(b"file2", b"file10", modifiers) < 0)
  assert_true(compare_key(b"file~1", b"file1", modifiers) < 0)
}

///|
test "C-locale transformations are byte based" {
  let modifiers = test_modifiers()
  modifiers.dictionary_order = true
  modifiers.fold_case = true
  modifiers.ignore_nonprinting = true
  assert_eq(transformed_key(b" A-\x01b!", modifiers), b" AB")
}

///|
test "blank separated fields retain their leading separators" {
  let spec = parse_key("2,2", test_modifiers())
  assert_eq(
    extract_key(b"x  b", spec, field_ranges(b"x  b", None)).to_owned(),
    b"  b",
  )
}
