///|
priv suberror PrintfError {
  PrintfError(String)
}

///|
priv struct PrintfState {
  args : Array[String]
  context : Context
  output : Array[Byte]
  mut argument : Int32
  mut status : Int32
  mut stopped : Bool
  mut allocated : Bool
}

///|
fn PrintfState::next(self : PrintfState) -> String {
  match self.args.get(self.argument) {
    Some(value) => {
      self.argument += 1
      value
    }
    None => ""
  }
}

///|
async fn PrintfState::flush(self : PrintfState) -> Unit {
  if !self.output.is_empty() {
    let bytes = Bytes::from_array(self.output)
    self.output.clear()
    write_output(self.context, bytes)
  }
}

///|
async fn PrintfState::emit(self : PrintfState, bytes : Bytes) -> Unit {
  if bytes.is_empty() {
    return
  }
  // The fixed Linux Dash profile uses an 8192-byte output buffer. A single
  // larger conversion goes directly to the writer, bounding retained output
  // across repeated formats without moving small diagnostics after stdout.
  if self.allocated && 8192 - self.output.length() >= bytes.length() {
    self.output.append(bytes.to_array())
    return
  }
  self.allocated = true
  self.context.output_buffer_allocated = true
  self.flush()
  if bytes.length() < 8192 {
    self.output.append(bytes.to_array())
  } else {
    write_output(self.context, bytes)
  }
}

///|
async fn PrintfState::warn(
  self : PrintfState,
  value : String,
  warning : String?,
) -> Unit {
  if warning is Some(message) {
    self.status = 1
    write_output(self.context, "sh: printf: \{value}: \{message}\n", error=true)
  }
}

///|
fn printf_escape(
  chars : Array[Char],
  start : Int32,
  argument : Bool,
) -> (Array[Byte], Int32, Bool) {
  guard chars.get(start + 1) is Some(char) else {
    return ([b'\\'], start + 1, false)
  }
  if argument && char == 'c' {
    return ([], start + 2, true)
  }
  if char is ('0'..<='7') {
    let mut cursor = start + 1
    if argument && char == '0' {
      cursor += 1
    }
    let limit = cursor + 3
    let mut number = 0
    while cursor < chars.length() &&
          cursor < limit &&
          chars[cursor] is ('0'..<='7') {
      number = number * 8 + chars[cursor].to_int() - '0'.to_int()
      cursor += 1
    }
    return ([(number % 256).to_byte()], cursor, false)
  }
  let simple = match char {
    'a' => 7
    'b' => 8
    'f' => 12
    'n' => 10
    'r' => 13
    't' => 9
    'v' => 11
    '\\' => 92
    _ => -1
  }
  if simple >= 0 {
    ([simple.to_byte()], start + 2, false)
  } else {
    let bytes = [b'\\']
    bytes.append(@utf8.encode(char.to_string()).to_array())
    (bytes, start + 2, false)
  }
}

///|
fn printf_escaped_argument(value : String) -> (Array[Byte], Bool) {
  let chars = value.iter().collect()
  let bytes : Array[Byte] = []
  let mut cursor = 0
  while cursor < chars.length() {
    if chars[cursor] == '\\' {
      let (part, next, stop) = printf_escape(chars, cursor, true)
      bytes.append(part)
      if stop {
        return (bytes, true)
      }
      cursor = next
    } else {
      bytes.append(@utf8.encode(chars[cursor].to_string()).to_array())
      cursor += 1
    }
  }
  (bytes, false)
}

///|
fn printf_pad(
  prefix : String,
  body : String,
  width : Int32,
  left : Bool,
  zero : Bool,
) -> String {
  let size = (width - prefix.length() - body.length()).max(0)
  if left {
    prefix + body + String::make(size, ' ')
  } else if zero {
    prefix + String::make(size, '0') + body
  } else {
    String::make(size, ' ') + prefix + body
  }
}

///|
fn printf_precision(body : String, precision : Int32?) -> String {
  match precision {
    Some(0) if body == "0" => ""
    Some(size) => String::make((size - body.length()).max(0), '0') + body
    None => body
  }
}

///|
async fn printf_dimension(
  state : PrintfState,
  chars : Array[Char],
  start : Int32,
) -> (Int32, Int32) {
  if chars.get(start) == Some('*') {
    let value = state.next()
    let (number, warning) = printf_integer(value, false)
    state.warn(value, warning)
    if number > 1000000L || number < -1000000L {
      raise PrintfError(
        "printf: field width or precision exceeds builtin limit",
      )
    }
    return (number.to_int(), start + 1)
  }
  let mut size = 0
  let mut cursor = start
  while cursor < chars.length() && chars[cursor] is ('0'..<='9') {
    size = size * 10 + chars[cursor].to_int() - '0'.to_int()
    if size > 1000000 {
      raise PrintfError(
        "printf: field width or precision exceeds builtin limit",
      )
    }
    cursor += 1
  }
  (size, cursor)
}

///|
async fn printf_format(state : PrintfState, format : Array[Char]) -> Unit {
  let mut cursor = 0
  while cursor < format.length() && !state.stopped {
    let char = format[cursor]
    if char == '\\' {
      let (bytes, next, _) = printf_escape(format, cursor, false)
      state.emit(Bytes::from_array(bytes))
      cursor = next
      continue
    }
    if char != '%' {
      state.emit(@utf8.encode(char.to_string()))
      cursor += 1
      continue
    }
    cursor += 1
    if format.get(cursor) == Some('%') {
      state.emit(b"%")
      cursor += 1
      continue
    }
    let mut left = false
    let mut plus = false
    let mut space = false
    let mut zero = false
    let mut alternate = false
    while cursor < format.length() {
      match format[cursor] {
        '-' => left = true
        '+' => plus = true
        ' ' => space = true
        '0' => zero = true
        '#' => alternate = true
        _ => break
      }
      cursor += 1
    }
    let (width, next) = printf_dimension(state, format, cursor)
    cursor = next
    if width < 0 {
      left = true
    }
    let width = width.abs()
    let mut precision : Int32? = None
    if format.get(cursor) == Some('.') {
      let (value, next) = printf_dimension(state, format, cursor + 1)
      cursor = next
      if value >= 0 {
        precision = Some(value)
      }
    }
    guard format.get(cursor) is Some(conversion) else {
      raise PrintfError("printf: incomplete conversion")
    }
    cursor += 1
    let value = state.next()
    if conversion is ('s' | 'c' | 'b') {
      let bytes = match conversion {
        'b' => {
          let (bytes, stop) = printf_escaped_argument(value)
          state.stopped = stop
          bytes
        }
        'c' => [@utf8.encode(value).get(0).unwrap_or(0)]
        _ => @utf8.encode(value).to_array()
      }
      let length = if conversion == 'c' {
        bytes.length()
      } else {
        precision.unwrap_or(bytes.length()).min(bytes.length())
      }
      let padding = (width - length).max(0)
      let formatted : Array[Byte] = []
      if !left {
        for _ in 0..<padding {
          formatted.push(b' ')
        }
      }
      for index in 0..<length {
        formatted.push(bytes[index])
      }
      if left {
        for _ in 0..<padding {
          formatted.push(b' ')
        }
      }
      state.emit(Bytes::from_array(formatted))
    } else if conversion is ('d' | 'i' | 'u' | 'o' | 'x' | 'X') {
      let signed = conversion == 'd' || conversion == 'i'
      let (number, warning) = printf_integer(value, !signed)
      state.warn(value, warning)
      let negative = signed && number < 0L
      let magnitude = if negative {
        (-number).reinterpret_as_uint64()
      } else {
        number.reinterpret_as_uint64()
      }
      let radix = if conversion == 'o' {
        8UL
      } else if conversion is ('x' | 'X') {
        16UL
      } else {
        10UL
      }
      let mut body = printf_precision(
        printf_radix(magnitude, radix, conversion == 'X'),
        precision,
      )
      let mut prefix = if negative {
        "-"
      } else if signed && plus {
        "+"
      } else if signed && space {
        " "
      } else {
        ""
      }
      if alternate && conversion == 'o' && !body.has_prefix("0") {
        body = "0" + body
      }
      if alternate && conversion is ('x' | 'X') && magnitude != 0UL {
        prefix = if conversion == 'X' { "0X" } else { "0x" }
      }
      state.emit(
        @utf8.encode(
          printf_pad(
            prefix,
            body,
            width,
            left,
            zero && !left && precision is None,
          ),
        ),
      )
    } else if conversion is ('a' | 'A' | 'e' | 'E' | 'f' | 'F' | 'g' | 'G') {
      let (number, warning) = printf_float(value)
      state.warn(value, warning)
      let body = @numfmt.format_magnitude(
        number,
        conversion,
        precision,
        alternate,
        Binary64,
      )
      let finite = number is @numfmt.Finite(_, _, _)
      let sign = if number.is_negative() {
        "-"
      } else if plus {
        "+"
      } else if space {
        " "
      } else {
        ""
      }
      let (prefix, body) = if finite && conversion is ('a' | 'A') {
        (sign + body[:2].to_owned(), body[2:].to_owned())
      } else {
        (sign, body)
      }
      state.emit(
        @utf8.encode(
          printf_pad(prefix, body, width, left, zero && !left && finite),
        ),
      )
    } else {
      raise PrintfError("printf: unsupported conversion '%\{conversion}'")
    }
  }
}

///|
async fn printf_builtin(args : Array[String], context : Context) -> Int32 {
  if args.get(0) is Some(value) &&
    value.has_prefix("-") &&
    value != "--" &&
    value != "-" {
    return builtin_error(context, "printf: unsupported option '\{value}'")
  }
  let args = if args.get(0) == Some("--") { args[1:].to_owned() } else { args }
  guard args.get(0) is Some(format) else {
    return builtin_error(context, "printf: format required")
  }
  let state : PrintfState = {
    args: args[1:].to_owned(),
    context,
    output: [],
    argument: 0,
    status: 0,
    stopped: false,
    allocated: context.output_buffer_allocated,
  }
  let format = format.iter().collect()
  for ;; {
    let before = state.argument
    printf_format(state, format) catch {
      PrintfError(message) => {
        let status = builtin_error(context, message)
        state.flush()
        return status
      }
      err => raise err
    }
    if state.stopped ||
      state.argument >= state.args.length() ||
      state.argument == before {
      break
    }
  }
  state.flush()
  state.status
}
