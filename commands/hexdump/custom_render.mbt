///|
fn input_integer(data : BytesView, position : Int32, count : Int32) -> UInt64 {
  let mut value = 0UL
  for index in 0..<(if count < 8 { count } else { 8 }) {
    let byte = data.get(position + index).unwrap_or(b'\x00')
    value = value | (byte.to_int().to_uint64() << (index * 8))
  }
  value
}

///|
fn padded_bytes(value : BytesView, width : Int32, minus : Bool) -> Bytes {
  let output = @buffer.Buffer()
  let padding = if width > value.length() { width - value.length() } else { 0 }
  if !minus {
    output.write_string_utf8(spaces(padding))
  }
  output.write_bytes(value)
  if minus {
    output.write_string_utf8(spaces(padding))
  }
  output.to_bytes()
}

///|
fn padded_number(
  prefix : String,
  digits : String,
  atom : PrintAtom,
  zero : Bool,
) -> Bytes {
  let padding = if atom.width > prefix.length() + digits.length() {
    atom.width - prefix.length() - digits.length()
  } else {
    0
  }
  let output = @buffer.Buffer()
  if !atom.minus && !zero {
    output.write_string_utf8(spaces(padding))
  }
  output.write_string_utf8(prefix)
  if !atom.minus && zero {
    for _ in 0..<padding {
      output.write_byte(b'0')
    }
  }
  output.write_string_utf8(digits)
  if atom.minus {
    output.write_string_utf8(spaces(padding))
  }
  output.to_bytes()
}

///|
fn integer_atom(
  bits : UInt64,
  count : Int32,
  conversion : Char,
  atom : PrintAtom,
) -> Bytes {
  let signed = conversion is ('d' | 'i')
  let negative = signed && count > 0 && (bits & (1UL << (count * 8 - 1))) != 0UL
  let magnitude = if negative {
    if count == 8 {
      0UL - bits
    } else {
      (1UL << (count * 8)) - bits
    }
  } else {
    bits
  }
  let radix = match conversion {
    'o' => 8
    'x' | 'X' => 16
    _ => 10
  }
  let mut digits = if magnitude == 0UL && atom.precision == Some(0) {
    ""
  } else {
    magnitude.to_string(radix~)
  }
  if conversion == 'X' {
    digits = digits.to_upper()
  }
  let precision = atom.precision.unwrap_or(0)
  if digits.length() < precision {
    let padded = StringBuilder()
    for _ in digits.length()..<precision {
      padded.write_char('0')
    }
    padded.write_string(digits)
    digits = padded.to_string()
  }
  let prefix = if negative {
    "-"
  } else if signed && atom.plus {
    "+"
  } else if signed && atom.blank {
    " "
  } else if atom.alternate && magnitude != 0UL && radix == 16 {
    if conversion == 'X' {
      "0X"
    } else {
      "0x"
    }
  } else {
    ""
  }
  if atom.alternate && radix == 8 && (digits == "" || !digits.has_prefix("0")) {
    digits = "0" + digits
  }
  padded_number(
    prefix,
    digits,
    atom,
    atom.zero && atom.precision is None && !atom.minus,
  )
}

///|
fn ascii_name(byte : Byte) -> String {
  let names = [
    "nul", "soh", "stx", "etx", "eot", "enq", "ack", "bel", "bs", "ht", "lf", "vt",
    "ff", "cr", "so", "si", "dle", "dc1", "dc2", "dc3", "dc4", "nak", "syn", "etb",
    "can", "em", "sub", "esc", "fs", "gs", "rs", "us",
  ]
  let value = byte.to_int()
  if value < 32 {
    names[value]
  } else if value == 127 {
    "del"
  } else if value >= 128 {
    number(value.to_int64(), 16, 0)
  } else {
    value.unsafe_to_char().to_string()
  }
}

///|
fn special_string(text : String, atom : PrintAtom) -> Bytes {
  let bytes = @utf8.encode(text)
  let length = atom.precision.unwrap_or(bytes.length()).min(bytes.length())
  padded_bytes(bytes[:length], atom.width, atom.minus)
}

///|
fn atom_value(
  atom : PrintAtom,
  data : BytesView,
  position : Int32,
  address : Int64,
  blank : Bool,
) -> Bytes {
  if blank {
    return @utf8.encode(spaces(atom.width))
  }
  match atom.conversion {
    Some(Integer(conversion)) =>
      integer_atom(
        input_integer(data, position, atom.count),
        atom.count,
        conversion,
        atom,
      )
    Some(Address(conversion, _)) =>
      integer_atom(address.reinterpret_as_uint64(), 8, conversion, atom)
    Some(Floating(conversion)) => {
      let end = if position + atom.count < data.length() {
        position + atom.count
      } else {
        data.length()
      }
      let bytes = if position < data.length() {
        data[position:end]
      } else {
        b""[:]
      }
      let profile = if atom.count == 4 {
        @numfmt.Binary32
      } else {
        @numfmt.Binary64
      }
      let value = @numfmt.decode(bytes, profile)
      let negative = (
          data.get(position + atom.count - 1).unwrap_or(b'\x00') & b'\x80'
        ) !=
        b'\x00'
      let prefix = if negative {
        "-"
      } else if atom.plus {
        "+"
      } else if atom.blank {
        " "
      } else {
        ""
      }
      let digits = @numfmt.format_magnitude(
        value,
        conversion,
        atom.precision,
        atom.alternate,
        profile,
      )
      padded_number(
        prefix,
        digits,
        atom,
        atom.zero && value is @numfmt.Finite(_, _, _) && !atom.minus,
      )
    }
    Some(StringValue) => {
      let available = if position < data.length() {
        data.length() - position
      } else {
        0
      }
      let length = atom.precision.unwrap_or(available)
      let limit = if length < available { length } else { available }
      let mut end = 0
      while end < limit && data[position + end] != b'\x00' {
        end += 1
      }
      padded_bytes(data[position:position + end], atom.width, atom.minus)
    }
    Some(Character) =>
      padded_bytes(
        Bytes::from_array([data.get(position).unwrap_or(b'\x00')])[:],
        atom.width,
        atom.minus,
      )
    Some(EscapedCharacter) => {
      let byte = data.get(position).unwrap_or(b'\x00')
      if byte >= b' ' && byte <= b'~' {
        padded_bytes(Bytes::from_array([byte])[:], atom.width, atom.minus)
      } else {
        special_string(escaped_character(byte), atom)
      }
    }
    Some(PrintableCharacter) => {
      let byte = data.get(position).unwrap_or(b'\x00')
      padded_bytes(
        Bytes::from_array([
          if byte >= b' ' && byte <= b'~' {
            byte
          } else {
            b'.'
          },
        ])[:],
        atom.width,
        atom.minus,
      )
    }
    Some(AsciiName) => {
      let byte = data.get(position).unwrap_or(b'\x00')
      if byte >= b'\x80' {
        integer_atom(byte.to_int().to_uint64(), 1, 'x', atom)
      } else if byte >= b' ' && byte < b'\x7f' {
        padded_bytes(Bytes::from_array([byte])[:], atom.width, atom.minus)
      } else {
        special_string(ascii_name(byte), atom)
      }
    }
    None => b""
  }
}

///|
fn render_custom(
  format : CustomFormat,
  data : BytesView,
  offset : Int64,
  block_size : Int32,
) -> Bytes {
  let output = @buffer.Buffer()
  let mut position = 0
  for unit in format.units {
    if unit.final_address {
      break
    }
    if unit.atoms.is_empty() {
      continue
    }
    for repetition in 0..<unit.reps {
      for index, atom in unit.atoms {
        let trim = unit.reps > 1 &&
          repetition + 1 == unit.reps &&
          index + 1 == unit.atoms.length() &&
          unit.trim_tail &&
          atom.conversion is None
        let prefix = if trim {
          atom.prefix[:atom.prefix.length() - 1]
        } else {
          atom.prefix[:]
        }
        let sequence = colored_sequence(
          atom,
          data,
          position,
          offset + position.to_int64(),
        )
        if sequence is Some(sequence) {
          output.write_string_utf8(sequence)
        }
        output.write_bytes(prefix)
        let blank = data.length() < block_size &&
          position >= data.length() &&
          atom.conversion is Some(_)
        output.write_bytes(
          atom_value(atom, data, position, offset + position.to_int64(), blank)[:],
        )
        if sequence is Some(_) {
          output.write_string_utf8("\u001b[0m")
        }
        position += atom.count
      }
    }
  }
  output.to_bytes()
}

///|
fn render_final(unit : FormatUnit, address : Int64) -> Bytes {
  let output = @buffer.Buffer()
  for atom in unit.atoms {
    match atom.conversion {
      Some(Address(_, _)) => {
        let sequence = colored_sequence(atom, b""[:], 0, address)
        if sequence is Some(sequence) {
          output.write_string_utf8(sequence)
        }
        output.write_bytes(atom.prefix[:])
        output.write_bytes(atom_value(atom, b""[:], 0, address, false)[:])
        if sequence is Some(_) {
          output.write_string_utf8("\u001b[0m")
        }
      }
      None => output.write_bytes(atom.prefix[:])
      _ => ()
    }
  }
  output.to_bytes()
}
