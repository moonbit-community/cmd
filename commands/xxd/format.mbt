///|
fn hex_digit(value : Int32, upper~ : Bool = false) -> Char {
  (if value < 10 {
    0x30 + value
  } else {
    (if upper { 0x41 } else { 0x61 }) + value - 10
  }).unsafe_to_char()
}

///|
fn write_hex_byte(
  output : StringBuilder,
  byte : Byte,
  upper~ : Bool = false,
) -> Unit {
  output.write_char(hex_digit(byte.to_int() >> 4, upper~))
  output.write_char(hex_digit(byte.to_int() & 15, upper~))
}

///|
fn display_byte(byte : Byte, ebcdic : Bool) -> Byte {
  let code = byte.to_int()
  let code = if !ebcdic {
    code
  } else {
    match code {
      129..<=137 => code - 129 + 0x61
      145..<=153 => code - 145 + 0x6a
      162..<=169 => code - 162 + 0x73
      193..<=201 => code - 193 + 0x41
      209..<=217 => code - 209 + 0x4a
      226..<=233 => code - 226 + 0x53
      240..<=249 => code - 240 + 0x30
      64 => 32
      75 => 46
      76 => 60
      77 => 40
      78 => 43
      79 => 124
      80 => 38
      90 => 33
      91 => 36
      92 => 42
      93 => 41
      94 => 59
      95 => 126
      96 => 45
      97 => 47
      107 => 44
      108 => 37
      109 => 95
      110 => 62
      111 => 63
      121 => 96
      122 => 58
      123 => 35
      124 => 64
      125 => 39
      126 => 61
      127 => 34
      154 => 94
      173 => 91
      189 => 93
      192 => 123
      208 => 125
      224 => 92
      _ => 46
    }
  }
  if code >= 32 && code < 127 {
    code.to_byte()
  } else {
    b'.'
  }
}

///|
fn dump_line(data : ArrayView[Byte], opts : Options, offset : Int64) -> Bytes {
  // Display offsets wrap like the provider's unsigned long; input positions stay checked.
  let address = (offset.reinterpret_as_uint64() + opts.display_offset).to_string(
    radix=16,
  )
  let prefix = StringBuilder()
  for _ in address.length()..<8 {
    prefix.write_char('0')
  }
  prefix.write_string(address)
  prefix.write_char(':')
  let prefix = @utf8.encode(prefix.to_string())
  let line : FixedArray[Byte] = FixedArray::make(
    prefix.length() + opts.cols * 10 + 16,
    b' ',
  )
  for index, byte in prefix {
    line[index] = byte
  }
  let group_width = if opts.style is Bits {
    8 * opts.group + 1
  } else {
    2 * opts.group + 1
  }
  let width = if opts.style is Little {
    group_width * ((opts.cols + opts.group - 1) / opts.group)
  } else {
    (group_width * opts.cols - 1) / opts.group
  }
  let display = prefix.length() + 3 + width
  for position, byte in data {
    let index = if opts.style is Little {
      position ^ (opts.group - 1)
    } else {
      position
    }
    let at = prefix.length() + 1 + group_width * index / opts.group
    if opts.style is Bits {
      for bit in 0..<8 {
        line[at + bit] = if (byte.to_int() & (1 << (7 - bit))) != 0 {
          b'1'
        } else {
          b'0'
        }
      }
    } else {
      line[at] = hex_digit(byte.to_int() >> 4, upper=opts.upper)
        .to_int()
        .to_byte()
      line[at + 1] = hex_digit(byte.to_int() & 15, upper=opts.upper)
        .to_int()
        .to_byte()
    }
    line[display + position] = display_byte(byte, opts.ebcdic)
  }
  line[display + data.length()] = b'\n'
  Bytes::from_array(line[:display + data.length() + 1].to_owned())
}

///|
fn include_name(path : String, symbol_name : String?) -> String? {
  let raw = match symbol_name {
    Some(name) => name
    None => if path == "-" { return None } else { path }
  }
  let output = StringBuilder()
  if raw.length() > 0 && raw[0] is ('0'..<='9') {
    output.write_string("__")
  }
  for byte in @utf8.encode(raw) {
    output.write_char(
      if byte is (b'a'..<=b'z' | b'A'..<=b'Z' | b'0'..<=b'9') {
        byte.to_int().unsafe_to_char()
      } else {
        '_'
      },
    )
  }
  Some(output.to_string())
}

///|
async fn Output::text(self : Output, text : String) -> Unit {
  self.write(@utf8.encode(text))
}

///|
priv struct ZeroLines {
  mut count : Int32
  mut second : Bytes
  mut last : Bytes
}

///|
fn ZeroLines::line(
  self : ZeroLines,
  output : @buffer.Buffer,
  line : Bytes,
  zero : Bool,
) -> Unit {
  if zero {
    if self.count == 0 {
      output.write_bytes(line[:])
    } else if self.count == 1 {
      self.second = line
    }
    self.last = line
    if self.count < 4 {
      self.count += 1
    }
  } else {
    if self.count == 2 {
      output.write_bytes(self.second[:])
    } else if self.count > 2 {
      output.write_bytes(b"*\n"[:])
    }
    output.write_bytes(line[:])
    self.count = 0
  }
}

///|
fn ZeroLines::finish(self : ZeroLines, output : @buffer.Buffer) -> Unit {
  if self.count == 2 {
    output.write_bytes(self.second[:])
  } else if self.count == 3 {
    output.write_bytes(self.second[:])
    output.write_bytes(self.last[:])
  } else if self.count > 3 {
    output.write_bytes(b"*\n"[:])
    output.write_bytes(self.last[:])
  }
}

///|
async fn dump_stream(
  reader : &@io.Reader,
  output : Output,
  opts : Options,
  start_offset : Int64,
  path : String,
  positioned_file~ : @fs.File? = None,
) -> Unit {
  let pending : Array[Byte] = []
  let zero_lines : ZeroLines = { count: 0, second: b"", last: b"", }
  let mut offset = start_offset
  let mut consumed = 0L
  let mut column = 0
  let name = if opts.style is Include {
    include_name(path, opts.name)
  } else {
    None
  }
  if name is Some(name) {
    output.text("unsigned char " + name + "[] = {\n")
  }
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  while opts.limit != Some(consumed) {
    let maximum = match opts.limit {
      Some(limit) => (limit - consumed).min(65536L).to_int()
      None => 65536
    }
    let count = match positioned_file {
      Some(file) =>
        file.read_at(
          buffer,
          position=checked_add(
            start_offset, consumed, 4, "xxd: input offset overflow.",
          ),
          len=maximum,
        )
      None => reader.read(buffer, max_len=maximum)
    }
    if count == 0 {
      break
    }
    let text = StringBuilder()
    let formatted = @buffer.Buffer()
    for index in 0..<count {
      let byte = buffer[index]
      if opts.style is Plain {
        write_hex_byte(text, byte, upper=opts.upper)
        if opts.cols > 0 {
          column += 1
          if column == opts.cols {
            text.write_char('\n')
            column = 0
          }
        }
      } else if opts.style is Include {
        text.write_string(
          if column == 0 {
            if consumed == 0L && index == 0 {
              "  "
            } else {
              ",\n  "
            }
          } else {
            ", "
          },
        )
        text.write_string(if opts.upper { "0X" } else { "0x" })
        write_hex_byte(text, byte, upper=opts.upper)
        column = (column + 1) % opts.cols
      } else {
        pending.push(byte)
        if pending.length() == opts.cols {
          zero_lines.line(
            formatted,
            dump_line(pending, opts, offset),
            opts.autoskip && pending.all(byte => byte == b'\x00'),
          )
          pending.clear()
          offset = checked_add(
            offset,
            opts.cols.to_int64(),
            4,
            "xxd: input offset overflow.",
          )
        }
      }
    }
    consumed = checked_add(
      consumed,
      count.to_int64(),
      4,
      "xxd: input offset overflow.",
    )
    if opts.style is Plain || opts.style is Include {
      output.text(text.to_string())
    } else {
      output.write(formatted.to_bytes())
    }
  }
  match opts.style {
    Plain => if column != 0 || opts.cols == 0 { output.write(b"\n") }
    Include => {
      if consumed > 0L {
        output.write(b"\n")
      }
      if name is Some(name) {
        output.text(
          "};\nunsigned int " + name + "_len = " + consumed.to_string() + ";\n",
        )
      }
    }
    _ => {
      let formatted = @buffer.Buffer()
      if pending.is_empty() {
        zero_lines.finish(formatted)
      } else {
        zero_lines.line(formatted, dump_line(pending, opts, offset), false)
      }
      output.write(formatted.to_bytes())
    }
  }
}
