///|
test "unexpand converts leading and all blanks" {
  assert_eq(unexpand_bytes(b"        x\n", false, false, [8]), b"\tx\n")
  assert_eq(unexpand_bytes(b"x        y\n", true, false, [8]), b"x\t y\n")
}

///|
test "unexpand first-only and explicit stops" {
  assert_eq(
    unexpand_bytes(b"        x        y\n", true, true, [8]),
    b"\tx        y\n",
  )
  assert_eq(unexpand_bytes(b"          x\n", true, false, [4, 10]), b"\t\tx\n")
}
