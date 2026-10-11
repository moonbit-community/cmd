///|
test "byte regex conversion is reversible for all byte values" {
  let data = Bytes::makei(256, i => i.to_byte())
  assert_eq(@bytere.bytes(@bytere.text(data)), data)
}

///|
test "byte regex is leftmost longest and captures BRE groups" {
  let basic = @bytere.compile("a\\|ab")
  let hit = basic.find("zabc").unwrap()
  assert_eq(hit.start, 1)
  assert_eq(hit.end, 3)
  let capture = @bytere.compile("a\\(b.*\\)").find("abc").unwrap()
  assert_eq(capture.groups[1], Some("bc"))
  assert_eq(@bytere.compile("a+", extended=false).find("a+").unwrap().end, 2)
  assert_eq(@bytere.compile("a+", extended=true).find("aaa").unwrap().end, 3)
}

///|
test "byte regex captures follow GNU sed 4.9 alternative order" {
  assert_eq(
    @bytere.compile("\\(foo\\|bar\\)[0-9]*").find("foo12").unwrap().groups[1],
    Some("foo"),
  )
  assert_eq(
    @bytere.compile("\\(a\\|aa\\)").find("aa").unwrap().groups[1],
    Some("aa"),
  )
  assert_eq(
    @bytere.compile("\\(a\\|aa\\)\\(a*\\)").find("aa").unwrap().groups[1],
    Some("a"),
  )
}
