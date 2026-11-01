///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum CompareMode {
  Lexical
  Numeric
  GeneralNumeric
  HumanNumeric
  Month
  Version
  Random
} derive(Eq)

///|
priv enum GeneralNumber {
  NonNumber
  NotANumber
  NegativeInfinity
  Finite(Double)
  PositiveInfinity
}

///|
priv struct Modifiers {
  mut ignore_leading_blanks : Bool
  mut dictionary_order : Bool
  mut fold_case : Bool
  mut ignore_nonprinting : Bool
  mut mode : CompareMode
  mut ordering_modes : Int32
  mut reverse : Bool
}

///|
priv struct Position {
  field : Int32
  character : Int32
  skip_blanks : Bool
}

///|
priv struct KeySpec {
  start : Position
  end : Position?
  modifiers : Modifiers
}

///|
priv struct Entry {
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
