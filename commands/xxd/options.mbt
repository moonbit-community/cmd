///|
priv suberror CliError {
  CliError(Int32, String)
}

///|
priv enum Style {
  Normal
  Plain
  Include
  Bits
  Little
}

///|
priv struct Seek {
  relative : Bool
  negative : Bool
  amount : Int64
}

///|
priv struct Options {
  style : Style
  cols : Int32
  group : Int32
  upper : Bool
  ebcdic : Bool
  autoskip : Bool
  reverse : Bool
  limit : Int64?
  seek : Seek?
  display_offset : UInt64
  name : String?
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

///|
fn magnitude(text : String) -> (Bool, UInt64) {
  let mut index = 0
  while index < text.length() &&
        text[index] is (' ' | '\t' | '\n' | '\r' | '\u000b' | '\u000c') {
    index += 1
  }
  let negative = index < text.length() && text[index] == '-'
  if index < text.length() && text[index] is ('-' | '+') {
    index += 1
  }
  let mut radix = 10
  if index < text.length() && text[index] == '0' {
    radix = 8
    if index + 2 < text.length() &&
      text[index + 1] is ('x' | 'X') &&
      text[index + 2] is ('0'..<='9' | 'a'..<='f' | 'A'..<='F') {
      radix = 16
      index += 2
    }
  }
  let mut value = 0UL
  let mut overflow = false
  while index < text.length() {
    let digit = match text[index] {
      '0'..<='9' => text[index].to_int() - 0x30
      'a'..<='f' => text[index].to_int() - 0x61 + 10
      'A'..<='F' => text[index].to_int() - 0x41 + 10
      _ => break
    }
    if digit >= radix {
      break
    }
    if value > (18446744073709551615UL - digit.to_uint64()) / radix.to_uint64() {
      overflow = true
    } else if !overflow {
      value = value * radix.to_uint64() + digit.to_uint64()
    }
    index += 1
  }
  (negative, if overflow { 18446744073709551615UL } else { value })
}

///|
fn number(text : String) -> Int64 {
  let (negative, value) = magnitude(text)
  if negative {
    if value >= 9223372036854775808UL {
      -9223372036854775807L - 1L
    } else {
      -value.reinterpret_as_int64()
    }
  } else {
    (if value > 9223372036854775807UL { 9223372036854775807UL } else { value }).reinterpret_as_int64()
  }
}

///|
fn parse_seek(text : String) -> Seek {
  let relative = text.has_prefix("+")
  let start = if relative { 1 } else { 0 }
  let negative = start < text.length() && text[start] == '-'
  let start = start + (if negative { 1 } else { 0 })
  { relative, negative, amount: number(text[start:].to_owned()), }
}

///|
fn checked_add(
  left : Int64,
  right : Int64,
  status : Int32,
  message : String,
) -> Int64 raise CliError {
  if (right > 0L && left > 9223372036854775807L - right) ||
    (right < 0L && left < -9223372036854775807L - 1L - right) {
    raise CliError(status, message)
  }
  left + right
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  args.map(arg => {
    match arg {
      "-ps" | "-postscript" | "--postscript" | "-plain" => "--plain"
      "--revert" | "-revert" => "--reverse"
      "-autoskip" => "--autoskip"
      "-bits" => "--bits"
      "-littleendian" => "--little"
      "-ebcdic" => "--ebcdic"
      "-groupsize" | "-group" => "--group"
      "-offset" => "--offset"
      "-cols" => "--cols"
      "-skip" | "-seek" | "--skip" => "--seek"
      "-len" => "--len"
      "-name" => "--name"
      "-upper" => "--upper"
      "-include" => "--include"
      _ => arg
    }
  })
}

///|
fn options(parsed : @cli.ParsedArgs) -> Options raise CliError {
  let mut style = Normal
  let mut autoskip = false
  for name in parsed.order {
    match name {
      "plain" => style = Plain
      "include" => style = Include
      "bits" => style = Bits
      "little" => style = Little
      "autoskip" => autoskip = !autoskip
      _ => ()
    }
  }
  let default_cols = match style {
    Plain => 30
    Include => 12
    Bits => 6
    _ => 16
  }
  let cols = number(
    parsed.last_value("cols").unwrap_or(default_cols.to_string()),
  ).to_int()
  let cols = if cols == 0 && !(style is Plain) { default_cols } else { cols }
  if cols < 0 ||
    (cols < 1 && !(style is Plain)) ||
    ((style is Normal || style is Bits || style is Little) && cols > 256) {
    raise CliError(1, "xxd: invalid number of columns (max. 256).")
  }
  let default_group = match style {
    Bits => 1
    Normal => 2
    Little => 4
    _ => 0
  }
  let group = number(
    parsed.last_value("group").unwrap_or(default_group.to_string()),
  ).to_int()
  let group = if group < 0 { default_group } else { group }
  let group = if group < 1 || group > cols {
    cols
  } else if style is Little && (group & (group - 1)) != 0 {
    raise CliError(
      1, "xxd: number of octets per group must be a power of 2 with -e.",
    )
  } else {
    group
  }
  let seek = parsed.last_value("seek").map(parse_seek)
  let (negative, value) = magnitude(parsed.last_value("offset").unwrap_or("0"))
  {
    style,
    cols,
    group,
    upper: parsed.contains("upper"),
    ebcdic: parsed.contains("ebcdic"),
    autoskip,
    reverse: parsed.contains("reverse"),
    seek,
    limit: parsed.last_value("len").map(number).filter(n => n >= 0L),
    display_offset: if negative {
      0UL - value
    } else {
      value
    },
    name: parsed.last_value("name"),
  }
}
