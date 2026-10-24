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
priv struct FormatUnit {
  atoms : Array[PrintAtom]
  mut reps : Int32
  explicit_reps : Bool
  count : Int32
  final_address : Bool
  trim_tail : Bool
}

///|
priv struct CustomFormat {
  units : Array[FormatUnit]
  count : Int32
}

///|
priv enum FormatEntry {
  Builtin(String)
  Custom(CustomFormat)
}

///|
priv struct FormatProgram {
  entries : Array[FormatEntry]
  block_size : Int32
  final_unit : FormatUnit?
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
fn bad_format(source : BytesView) -> Unit raise HexdumpError {
  raise HexdumpError("bad format {\{format_text(source)}}")
}

///|
fn bad_conversion(name : String) -> Unit raise HexdumpError {
  raise HexdumpError("bad conversion character %\{name}")
}

///|
fn bad_count(name : String) -> Unit raise HexdumpError {
  raise HexdumpError("bad byte count for conversion character \{name}")
}
