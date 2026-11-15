///|
pub(all) struct Spec {
  style : Style
  cols : Int32
  group : Int32
  upper : Bool
  ebcdic : Bool
  display_offset : UInt64
}

///|
pub suberror DecodeError {
  DecodeError(String)
}

///|
fn checked_offset(left : Int64, right : Int64) -> Int64 raise DecodeError {
  if (right > 0L && left > 9223372036854775807L - right) ||
    (right < 0L && left < -9223372036854775807L - 1L - right) {
    raise DecodeError("xxd: addressed offset overflow.")
  }
  left + right
}
