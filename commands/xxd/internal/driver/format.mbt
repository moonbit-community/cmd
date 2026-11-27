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
      output.write_bytesview(line[:])
    } else if self.count == 1 {
      self.second = line
    }
    self.last = line
    if self.count < 4 {
      self.count += 1
    }
  } else {
    if self.count == 2 {
      output.write_bytesview(self.second[:])
    } else if self.count > 2 {
      output.write_bytesview(b"*\n"[:])
    }
    output.write_bytesview(line[:])
    self.count = 0
  }
}

///|
fn ZeroLines::finish(self : ZeroLines, output : @buffer.Buffer) -> Unit {
  if self.count == 2 {
    output.write_bytesview(self.second[:])
  } else if self.count == 3 {
    output.write_bytesview(self.second[:])
    output.write_bytesview(self.last[:])
  } else if self.count > 3 {
    output.write_bytesview(b"*\n"[:])
    output.write_bytesview(self.last[:])
  }
}

///|
async fn dump_stream(
  reader : &@io.BinaryReader,
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
      Some(limit) => (limit - consumed).min(buffer.length().to_int64()).to_int()
      None => buffer.length()
    }
    let count = match positioned_file {
      Some(file) =>
        file
        .at(
          checked_add(start_offset, consumed, 4, "xxd: input offset overflow."),
        )
        .read_into(buffer.mut_view(end=maximum))
      None => reader.read_into(buffer.mut_view(end=maximum))
    }
    if count == 0 {
      break
    }
    let text = StringBuilder()
    let formatted = @buffer.Buffer()
    for index in 0..<count {
      let byte = buffer[index]
      if opts.style is Plain {
        @codec.write_hex_byte(text, byte, upper=opts.upper)
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
        @codec.write_hex_byte(text, byte, upper=opts.upper)
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
