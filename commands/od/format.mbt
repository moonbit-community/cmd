///|
priv suberror OdError {
  OdError(String)
}

///|
priv struct Format {
  kind : Char
  size : Int32
  trailer : Bool
  floating : FloatKind?
}

///|
fn number(
  value : UInt64,
  radix : Int32,
  width : Int32,
  fill~ : Char = '0',
) -> String {
  let digits = "0123456789abcdef"
  let out : Array[Char] = []
  let mut n = value
  for ;; {
    out.push(digits[(n % radix.to_uint64()).to_int()].to_int().unsafe_to_char())
    n /= radix.to_uint64()
    if n == 0UL {
      break
    }
  }
  while out.length() < width {
    out.push(fill)
  }
  let sb = StringBuilder()
  for i = out.length() - 1; i >= 0; i = i - 1 {
    sb.write_char(out[i])
  }
  sb.to_string()
}

///|
fn spaces(count : Int32) -> String {
  let sb = StringBuilder()
  for _ in 0..<count {
    sb.write_char(' ')
  }
  sb.to_string()
}

///|
fn parse_formats(text : String) -> Array[Format] raise OdError {
  let result : Array[Format] = []
  let mut i = 0
  while i < text.length() {
    let kind = text[i].to_int().unsafe_to_char()
    if kind != 'a' &&
      kind != 'c' &&
      kind != 'd' &&
      kind != 'u' &&
      kind != 'o' &&
      kind != 'x' &&
      kind != 'f' {
      raise OdError(
        "unsupported format '\{kind}'; use a, c, integer d/u/o/x, or f formats",
      )
    }
    i += 1
    let mut floating : FloatKind? = None
    let mut size = if kind == 'a' || kind == 'c' { 1 } else { 4 }
    if kind == 'f' {
      size = 8
      floating = Some(Double)
      if i < text.length() {
        match text[i] {
          'B' => {
            floating = Some(BFloat)
            size = 2
            i += 1
          }
          'H' => {
            floating = Some(Half)
            size = 2
            i += 1
          }
          'F' => {
            floating = Some(Single)
            size = 4
            i += 1
          }
          'D' => i += 1
          'L' => {
            floating = Some(Extended80)
            size = 16
            i += 1
          }
          '0'..<='9' => {
            let start = i
            while i < text.length() && text[i] is ('0'..<='9') {
              i += 1
            }
            size = @string.parse_int(text[start:i]) catch {
              _ => raise OdError("invalid type string '\{text}'")
            }
            floating = Some(
              match size {
                2 => Half
                4 => Single
                8 => Double
                16 => Extended80
                _ =>
                  raise OdError(
                    "invalid type string '\{text}';\nthis system doesn't provide a \{size}-byte floating point type",
                  )
              },
            )
          }
          _ => ()
        }
      }
    } else if kind != 'a' && kind != 'c' && i < text.length() {
      match text[i] {
        '1' | 'C' => {
          size = 1
          i += 1
        }
        '2' | 'S' => {
          size = 2
          i += 1
        }
        '4' | 'I' => {
          size = 4
          i += 1
        }
        '8' | 'L' => {
          size = 8
          i += 1
        }
        _ => ()
      }
    }
    let trailer = i < text.length() && text[i] == 'z'
    if trailer {
      i += 1
    }
    result.push({ kind, size, trailer, floating, })
  }
  if result.is_empty() {
    raise OdError("empty output format")
  }
  result
}

///|
fn Format::width(self : Format) -> Int32 {
  if self.floating is Some(kind) {
    return kind.width()
  }
  match self.kind {
    'a' | 'c' => 3
    'x' => self.size * 2
    'o' => (self.size * 8 + 2) / 3
    'u' =>
      match self.size {
        1 => 3
        2 => 5
        4 => 10
        _ => 20
      }
    _ =>
      match self.size {
        1 => 4
        2 => 6
        4 => 11
        _ => 20
      }
  }
}

///|
fn character(byte : Byte, named : Bool) -> String {
  let names = [
    "nul", "soh", "stx", "etx", "eot", "enq", "ack", "bel", "bs", "ht", "nl", "vt",
    "ff", "cr", "so", "si", "dle", "dc1", "dc2", "dc3", "dc4", "nak", "syn", "etb",
    "can", "em", "sub", "esc", "fs", "gs", "rs", "us", "sp",
  ]
  let code = if named { byte.to_int() & 127 } else { byte.to_int() }
  let text = if named && code <= 32 {
    names[code]
  } else if named && code == 127 {
    "del"
  } else if code >= 32 && code <= 126 {
    code.unsafe_to_char().to_string()
  } else {
    match code {
      0 => "\\0"
      7 => "\\a"
      8 => "\\b"
      9 => "\\t"
      10 => "\\n"
      11 => "\\v"
      12 => "\\f"
      13 => "\\r"
      _ => number(code.to_uint64(), 8, 3)
    }
  }
  spaces(3 - text.length()) + text
}

///|
fn value_at(data : Bytes, start : Int32, size : Int32, big : Bool) -> UInt64 {
  let mut result = 0UL
  for i in 0..<size {
    let byte = if start + i < data.length() {
      data[start + i].to_uint64()
    } else {
      0UL
    }
    let shift = if big { (size - i - 1) * 8 } else { i * 8 }
    result = result | (byte << shift)
  }
  result
}

///|
fn Format::field(
  self : Format,
  data : Bytes,
  start : Int32,
  big : Bool,
) -> String {
  if self.floating is Some(kind) {
    let text = @numfmt.format_roundtrip(
      float_at(data, start, self.size, big, kind),
      kind.profile(),
    )
    return spaces(self.width() - text.length()) + text
  }
  if self.kind == 'a' || self.kind == 'c' {
    return character(data[start], self.kind == 'a')
  }
  let value = value_at(data, start, self.size, big)
  let width = self.width()
  match self.kind {
    'x' => number(value, 16, width)
    'o' => number(value, 8, width)
    'u' => number(value, 10, width, fill=' ')
    _ => {
      let signed = if self.size == 8 {
        value.reinterpret_as_int64()
      } else {
        let bits = self.size * 8
        if (value & (1UL << (bits - 1))) != 0UL {
          value.reinterpret_as_int64() - (1L << bits)
        } else {
          value.reinterpret_as_int64()
        }
      }
      let text = signed.to_string()
      spaces(width - text.length()) + text
    }
  }
}

///|
fn address(offset : Int64, base : Int32) -> String {
  if base == 0 {
    ""
  } else {
    number(offset.reinterpret_as_uint64(), base, if base == 16 { 6 } else { 7 })
  }
}

///|
fn render_row(
  data : Bytes,
  offset : Int64,
  width : Int32,
  formats : Array[Format],
  base : Int32,
  big : Bool,
  label~ : Int64? = None,
) -> String {
  let mut line_width = 0
  for format in formats {
    line_width = line_width.max((format.width() + 1) * (width / format.size))
  }
  let out = StringBuilder()
  for index, format in formats {
    let prefix = labeled_address(offset, base, label)
    out.write_string(
      if index == 0 {
        prefix
      } else {
        spaces(
          if base == 0 && label is Some(_) {
            7
          } else {
            address(offset, base).length()
          },
        )
      },
    )
    let fields = width / format.size
    let padding = line_width - fields * format.width()
    let count = (data.length() + format.size - 1) / format.size
    for field in 0..<count {
      let remaining = fields - field
      let pad = (remaining.to_int64() * padding.to_int64() / fields.to_int64() -
      (remaining - 1).to_int64() * padding.to_int64() / fields.to_int64()).to_int()
      out.write_string(spaces(pad))
      out.write_string(format.field(data, field * format.size, big))
    }
    if format.trailer {
      out.write_string(
        spaces(
          (fields - count) * format.width() +
          ((fields - count).to_int64() * padding.to_int64() / fields.to_int64()).to_int(),
        ),
      )
      out.write_string("  >")
      for byte in data {
        out.write_char(
          if byte >= b' ' && byte <= b'~' {
            byte.to_int().unsafe_to_char()
          } else {
            '.'
          },
        )
      }
      out.write_char('<')
    }
    out.write_char('\n')
  }
  out.to_string()
}
