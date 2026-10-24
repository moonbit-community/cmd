///|
test "seq format decodes literals and pads after the numeric prefix" {
  let format = parse_float_format("%%[%+010.2a]%%")
  assert_eq((format.prefix, format.suffix), ("%[", "]%"))
  assert_eq(format.field(parse_float_operand("0")), "+0x0.00p+0")
  let format = parse_float_format("[%08.2f]")
  assert_eq(format.field(parse_float_operand("-1.5")), "-0001.50")
}

///|
test "seq rejects missing multiple integer and dynamic format conversions" {
  for text in ["plain", "%%", "%f %f", "%d", "%*f", "%.*f", "%.2lf", "%"] {
    try parse_float_format(text) catch {
      SeqError(_) => ()
    } noraise {
      _ => fail("the format must reject before output")
    }
  }
  assert_eq(parse_float_format("%.2Lf").conversion, 'f')
}
