///|
test "pinned IDNA rules retain historical codepoint bidi and underscore behavior" {
  for
    (input, expected) in [
      ("\u19DA.faß.example", "xn--pkf.xn--fa-hia.example"),
      ("א1١.faß.example", "xn--1-zhc05b.xn--fa-hia.example"),
      ("a·b.faß.example", "xn--ab-0ea.xn--fa-hia.example"),
      ("_é.faß.example", "xn--_-bga.xn--fa-hia.example"),
      ("℀.faß.example", "a/c.xn--fa-hia.example"),
      ("foo＠bar.example", "foo@bar.example"),
    ] {
    assert_eq(idna_host(input), expected, msg=input)
  }
  try idna_host("a/bü.example") catch {
    InvalidName => ()
  } noraise {
    _ => fail("non-LDH basic text cannot round-trip inside Punycode")
  }
}
