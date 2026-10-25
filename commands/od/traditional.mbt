///|
fn traditional_offset(text : String) -> Int64? raise OdError {
  let mut body = if text.has_prefix("+") { text[1:].to_owned() } else { text }
  if body == "" || !(body[0] is ('0'..<='9')) {
    return None
  }
  let decimal = body.has_suffix(".") ||
    body.has_suffix(".b") ||
    body.has_suffix(".B")
  let radix = if decimal {
    10
  } else if body.has_prefix("0x") || body.has_prefix("0X") {
    16
  } else {
    8
  }
  let mut multiplier = 1L
  if radix != 16 && (body.has_suffix("b") || body.has_suffix("B")) {
    multiplier = if body.has_suffix("B") { 1024L } else { 512L }
    body = body[:body.length() - 1].to_owned()
  }
  if decimal {
    body = body[:body.length() - 1].to_owned()
  }
  if radix == 16 {
    body = body[2:].to_owned()
  }
  if body == "" ||
    !body
    .iter()
    .all(character => {
      if radix == 16 {
        character is ('0'..<='9' | 'a'..<='f' | 'A'..<='F')
      } else if radix == 10 {
        character is ('0'..<='9')
      } else {
        character is ('0'..<='7')
      }
    }) {
    return None
  }
  let value = @string.parse_int64(body, base=radix) catch {
    _ => raise OdError("\{text}: Numerical result out of range")
  }
  if value > 9223372036854775807L / multiplier {
    raise OdError("\{text}: Numerical result out of range")
  }
  Some(value * multiplier)
}

///|
fn traditional_operands(
  parsed : @cli.ParsedArgs,
) -> (Array[String], Int64?, Int64?) raise OdError {
  let traditional = parsed.contains("traditional")
  let modern = [
    "address-radix", "skip-bytes", "read-bytes", "strings", "format", "output-duplicates",
  ].any(name => parsed.contains(name))
  let files = parsed.operands
  if !traditional && modern {
    return (files, None, None)
  }
  match files {
    [offset] if traditional || offset.has_prefix("+") =>
      if traditional_offset(offset) is Some(skip) {
        return ([], Some(skip), None)
      }
    [file, offset] if traditional ||
      offset.has_prefix("+") ||
      (offset.length() > 0 && offset[0] is ('0'..<='9')) =>
      if traditional_offset(offset) is Some(second) {
        if traditional && traditional_offset(file) is Some(first) {
          return ([], Some(first), Some(second))
        }
        return ([file], Some(second), None)
      }
    [file, offset, label] if traditional =>
      if traditional_offset(offset) is Some(skip) &&
        traditional_offset(label) is Some(label) {
        return ([file], Some(skip), Some(label))
      }
    _ => ()
  }
  if traditional && files.length() > 1 {
    raise OdError(
      "extra operand '\{files[1]}'\nod: compatibility mode supports at most one file\nTry 'od --help' for more information.",
    )
  }
  (files, None, None)
}

///|
fn labeled_address(offset : Int64, base : Int32, label : Int64?) -> String {
  match label {
    None => address(offset, base)
    Some(delta) => {
      let pseudo = "(" +
        address(
          if base == 0 {
            offset
          } else {
            offset + delta
          },
          if base == 0 {
            8
          } else {
            base
          },
        ) +
        ")"
      if base == 0 {
        pseudo
      } else {
        address(offset, base) + " " + pseudo
      }
    }
  }
}
