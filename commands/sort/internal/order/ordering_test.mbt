///|
fn test_modifiers() -> @order.Modifiers {
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
test "key parser handles character positions and local modifiers" {
  let spec = @order.parse_key("2.2,3.4nr", test_modifiers())
  assert_eq(spec.start.field, 2)
  assert_eq(spec.start.character, 2)
  guard spec.end is Some(end) else { fail("missing key end") }
  assert_eq(end.field, 3)
  assert_eq(end.character, 4)
  assert_true(spec.modifiers.mode == Numeric)
  assert_true(spec.modifiers.reverse)
}

///|
test "sort lexical plan matches general ordering for ties reverse and raw bytes" {
  let records = [b"", b"a", b"a", b"\x80", b"a\x00", b"aa"]
  for reverse in [false, true] {
    let global = test_modifiers()
    global.reverse = reverse
    for last_resort in [false, true] {
      let compare = @order.entry_comparator([], global, last_resort)
      let entries = records.mapi((i, record) => {
        @order.make_entry(record, i.to_int64(), [], global, None)
      })
      for left in entries {
        for right in entries {
          let order = @order.compare_entries(
            left,
            right,
            [],
            global,
            last_resort,
          )
          assert_eq(
            compare(left, right),
            if order == 0 {
              left.index.compare(right.index)
            } else {
              order
            },
          )
        }
      }
    }
  }
}

///|
test "ordering modifiers on both key positions are combined" {
  let spec = @order.parse_key("2n,2r", test_modifiers())
  assert_true(spec.modifiers.mode == Numeric)
  assert_true(spec.modifiers.reverse)
}
