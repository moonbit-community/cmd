///|
/// Keep cookie grammar byte-oriented without asking UTF-8 decoding to admit or
/// replace an octet. Only explicit text-facing boundaries decode UTF-8.
fn cookie_text(bytes : Bytes) -> String {
  let out = StringBuilder()
  for byte in bytes {
    out.write_char(byte.to_int().to_char().unwrap())
  }
  out.to_string()
}

///|
fn cookie_bytes(text : String) -> Bytes {
  Bytes::from_array(
    text
    .iter()
    .map(character => {
      guard character.to_int() <= 255 else {
        abort("non-octet cookie parser text")
      }
      character.to_int().to_byte()
    })
    .to_array(),
  )
}
