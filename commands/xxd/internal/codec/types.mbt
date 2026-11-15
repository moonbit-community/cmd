///|
pub(all) enum Style {
  Normal
  Plain
  Include
  Bits
  Little
}

///|
fn hex_val(byte : Byte) -> Int32 {
  match byte {
    b'0'..<=b'9' => byte.to_int() - 0x30
    b'a'..<=b'f' => byte.to_int() - 0x61 + 10
    b'A'..<=b'F' => byte.to_int() - 0x41 + 10
    _ => -1
  }
}
