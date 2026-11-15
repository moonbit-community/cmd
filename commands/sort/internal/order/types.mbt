///|
pub(all) suberror CliError {
  CliError(String)
}

///|
#derive(Eq)
pub(all) enum CompareMode {
  Lexical
  Numeric
  GeneralNumeric
  HumanNumeric
  Month
  Version
  Random
}

///|
priv enum GeneralNumber {
  NonNumber
  NotANumber
  NegativeInfinity
  Finite(Double)
  PositiveInfinity
}

///|
pub(all) struct Modifiers {
  mut ignore_leading_blanks : Bool
  mut dictionary_order : Bool
  mut fold_case : Bool
  mut ignore_nonprinting : Bool
  mut mode : CompareMode
  mut ordering_modes : Int32
  mut reverse : Bool
}

///|
pub(all) struct Position {
  field : Int32
  character : Int32
  skip_blanks : Bool
}

///|
pub(all) struct KeySpec {
  start : Position
  end : Position?
  modifiers : Modifiers
}

///|
pub(all) struct Entry {
  record : Bytes
  keys : Array[Bytes]
  index : Int64
}

///|
fn byte_is_blank(byte : Byte) -> Bool {
  byte is (b' ' | b'\t')
}

///|
fn byte_is_digit(byte : Byte) -> Bool {
  byte is (b'0'..<=b'9')
}

///|
pub extend CompareMode with Eq::{equal, not_equal}
