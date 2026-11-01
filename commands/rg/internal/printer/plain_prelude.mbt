///|
/// Assemble a complete unstyled prelude synchronously. Only the prelude is
/// copied; the possibly unbounded record remains borrowed by the async writer.
fn format_plain_prelude(
  out : @termcolor.ByteVec,
  path : Bytes?,
  path_terminator : Byte?,
  line : Int64?,
  column : Int64?,
  byte_offset : Int64?,
  separator : Bytes,
) -> Unit {
  out.clear()
  if path is Some(path) {
    out.extend_bytes(path)
    match path_terminator {
      Some(term) => out.push(term)
      None => out.extend_bytes(separator)
    }
  }
  append_plain_number(out, line, separator)
  append_plain_number(out, column, separator)
  append_plain_number(out, byte_offset, separator)
}

///|
fn append_plain_number(
  out : @termcolor.ByteVec,
  number : Int64?,
  separator : Bytes,
) -> Unit {
  if number is Some(number) {
    let start = format_decimal(number)
    out.extend_slice(decimal_scratch, start, decimal_scratch.length())
    out.extend_bytes(separator)
  }
}
