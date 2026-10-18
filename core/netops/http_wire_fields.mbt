///|
fn wire_skip_ows(value : String, start : Int32) -> Int32 {
  let mut index = start
  while index < value.length() && value.code_unit_at(index) is (' ' | '\t') {
    index += 1
  }
  index
}

///|
fn wire_extension_token(
  value : String,
  start : Int32,
) -> Int32 raise TransferError {
  let mut index = start
  while index < value.length() &&
        !(value.code_unit_at(index) is (' ' | '\t' | ';' | '=')) {
    index += 1
  }
  guard wire_token(value[start:index].to_owned()) else {
    raise transfer_error(ReceiveFailure, "invalid HTTP chunk extension token")
  }
  index
}

///|
fn wire_chunk_extensions(value : String) -> Unit raise TransferError {
  let mut index = 0
  while index < value.length() {
    guard value.code_unit_at(index) == ';' else {
      raise transfer_error(
        ReceiveFailure,
        "invalid HTTP chunk extension separator",
      )
    }
    index = wire_skip_ows(value, index + 1)
    index = wire_extension_token(value, index)
    index = wire_skip_ows(value, index)
    if index < value.length() && value.code_unit_at(index) == '=' {
      index = wire_skip_ows(value, index + 1)
      if index < value.length() && value.code_unit_at(index) == '"' {
        index += 1
        let mut closed = false
        while index < value.length() {
          let character = value.code_unit_at(index)
          index += 1
          if character == '"' {
            closed = true
            break
          }
          if character == '\\' {
            guard index < value.length() else {
              raise transfer_error(
                ReceiveFailure,
                "unterminated HTTP chunk extension escape",
              )
            }
            let escaped = value.code_unit_at(index)
            guard (escaped >= ' ' && escaped != '\u007f') || escaped == '\t' else {
              raise transfer_error(
                ReceiveFailure,
                "invalid HTTP chunk extension escape",
              )
            }
            index += 1
          } else {
            guard (character >= ' ' && character != '\u007f') ||
              character == '\t' else {
              raise transfer_error(
                ReceiveFailure,
                "invalid HTTP chunk extension quoted value",
              )
            }
          }
        }
        guard closed else {
          raise transfer_error(
            ReceiveFailure,
            "unterminated HTTP chunk extension quoted value",
          )
        }
      } else {
        index = wire_extension_token(value, index)
      }
      index = wire_skip_ows(value, index)
    }
  }
}
