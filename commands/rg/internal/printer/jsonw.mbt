///|
/// A minimal streaming JSON writer that produces byte-identical output to
/// `serde_json`'s compact and pretty (two space indent) formatters.
pub struct JsonWriter {
  priv out : @termcolor.ByteVec
  priv pretty : Bool
  priv mut current_indent : Int32
  priv mut has_value : Bool
  priv firsts : Array[Bool]
}

///|
/// Create a new JSON writer appending to `out`.
pub fn JsonWriter::new(
  out : @termcolor.ByteVec,
  pretty~ : Bool = false,
) -> JsonWriter {
  { out, pretty, current_indent: 0, has_value: false, firsts: [], }
}

///|
fn JsonWriter::raw(self : JsonWriter, s : String) -> Unit {
  for i in 0..<s.length() {
    self.out.push(s[i].to_byte())
  }
}

///|
fn JsonWriter::indent(self : JsonWriter) -> Unit {
  for _ in 0..<self.current_indent {
    self.raw("  ")
  }
}

///|
/// Begins an object (`{`).
pub fn JsonWriter::begin_object(self : JsonWriter) -> Unit {
  if self.pretty {
    self.current_indent += 1
    self.has_value = false
  }
  self.raw("{")
  self.firsts.push(true)
}

///|
/// Ends an object (`}`).
pub fn JsonWriter::end_object(self : JsonWriter) -> Unit {
  self.firsts.pop() |> ignore
  if self.pretty {
    self.current_indent -= 1
    if self.has_value {
      self.raw("\n")
      self.indent()
    }
  }
  self.raw("}")
}

///|
/// Begins an array (`[`).
pub fn JsonWriter::begin_array(self : JsonWriter) -> Unit {
  if self.pretty {
    self.current_indent += 1
    self.has_value = false
  }
  self.raw("[")
  self.firsts.push(true)
}

///|
/// Ends an array (`]`).
pub fn JsonWriter::end_array(self : JsonWriter) -> Unit {
  self.firsts.pop() |> ignore
  if self.pretty {
    self.current_indent -= 1
    if self.has_value {
      self.raw("\n")
      self.indent()
    }
  }
  self.raw("]")
}

///|
fn JsonWriter::take_first(self : JsonWriter) -> Bool {
  let n = self.firsts.length()
  let first = self.firsts[n - 1]
  self.firsts[n - 1] = false
  first
}

///|
/// Writes an object key (and the `:` separator). Must be followed by a
/// value.
pub fn JsonWriter::key(self : JsonWriter, name : String) -> Unit {
  let first = self.take_first()
  if self.pretty {
    self.raw(if first { "\n" } else { ",\n" })
    self.indent()
  } else if !first {
    self.raw(",")
  }
  self.write_escaped_string(name)
  self.raw(if self.pretty { ": " } else { ":" })
}

///|
/// Must be called after each object value or array element is complete.
pub fn JsonWriter::end_value(self : JsonWriter) -> Unit {
  if self.pretty {
    self.has_value = true
  }
}

///|
/// Begins an array element.
pub fn JsonWriter::element(self : JsonWriter) -> Unit {
  let first = self.take_first()
  if self.pretty {
    self.raw(if first { "\n" } else { ",\n" })
    self.indent()
  } else if !first {
    self.raw(",")
  }
}

///|
/// Writes `null`.
pub fn JsonWriter::null(self : JsonWriter) -> Unit {
  self.raw("null")
}

///|
/// Writes an unsigned integer (given as an `Int64` that must be
/// non-negative, or a `UInt64`).
pub fn JsonWriter::uint64(self : JsonWriter, n : UInt64) -> Unit {
  self.raw(n.to_string())
}

///|
/// Writes an escaped JSON string from a MoonBit string.
pub fn JsonWriter::write_escaped_string(self : JsonWriter, s : String) -> Unit {
  let tmp = @termcolor.ByteVec::new(capacity=s.length() + 1)
  tmp.extend_string(s)
  self.write_escaped_utf8(tmp.storage(), 0, tmp.length())
}

///|
/// Writes `buf[start:end]`, which must be valid UTF-8, as an escaped JSON
/// string.
pub fn JsonWriter::write_escaped_utf8(
  self : JsonWriter,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  self.out.push(b'"')
  let mut plain_start = start
  for i in start..<end {
    let b = buf[i]
    let esc : String? = match b {
      b'\x08' => Some("\\b")
      b'\t' => Some("\\t")
      b'\n' => Some("\\n")
      b'\x0C' => Some("\\f")
      b'\r' => Some("\\r")
      b'"' => Some("\\\"")
      b'\\' => Some("\\\\")
      _ =>
        if b < b'\x20' {
          let n = b.to_int()
          Some("\\u00" + hex_digit(n >> 4) + hex_digit(n & 0xF))
        } else {
          None
        }
    }
    if esc is Some(e) {
      self.out.extend_slice(buf, plain_start, i)
      self.raw(e)
      plain_start = i + 1
    }
  }
  self.out.extend_slice(buf, plain_start, end)
  self.out.push(b'"')
}

///|
fn hex_digit(n : Int32) -> String {
  let c = if n < 10 { n + '0' } else { n - 10 + 'a' }
  c.unsafe_to_char().to_string()
}
