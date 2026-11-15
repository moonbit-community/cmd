///|
priv enum Conversion {
  Integer(Char)
  Floating(Char)
  StringValue
  Character
  EscapedCharacter
  PrintableCharacter
  AsciiName
  Address(Char, Bool)
}

///|
priv enum ColorValue {
  AnyValue
  NumberValue(Int32)
  StringBytes(Bytes)
}

///|
priv struct ColorRule {
  sequence : String
  inverted : Bool
  value : ColorValue
  offset : Int64?
  span : Int32
}

///|
priv struct PrintAtom {
  prefix : Bytes
  conversion : Conversion?
  width : Int32
  precision : Int32?
  minus : Bool
  plus : Bool
  blank : Bool
  zero : Bool
  alternate : Bool
  count : Int32
  colors : Array[ColorRule]
}

///|
pub struct UnitSpec {
  priv atoms : Array[PrintAtom]
  priv mut reps : Int32
  priv explicit_reps : Bool
  priv count : Int32
  priv final_address : Bool
  priv trim_tail : Bool
}

///|
pub struct Format {
  priv units : Array[UnitSpec]
  priv count : Int32
}

///|
pub(all) enum Entry {
  Builtin(String)
  Custom(Format)
}

///|
pub struct Program {
  entries : Array[Entry]
  block_size : Int32
  final_unit : UnitSpec?
}

///|
fn format_space(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\n' | b'\r' | b'\x0b' | b'\x0c')
}

///|
fn format_text(bytes : BytesView) -> String {
  @utf8.decode_lossy(bytes)
}

///|
fn bad_format(source : BytesView) -> Unit raise FormatError {
  raise FormatError("bad format {\{format_text(source)}}")
}

///|
fn bad_conversion(name : String) -> Unit raise FormatError {
  raise FormatError("bad conversion character %\{name}")
}

///|
fn bad_count(name : String) -> Unit raise FormatError {
  raise FormatError("bad byte count for conversion character \{name}")
}
