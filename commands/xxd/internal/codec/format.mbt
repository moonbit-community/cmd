///|
fn hex_digit(value : Int32, upper~ : Bool = false) -> Char {
  (if value < 10 {
    0x30 + value
  } else {
    (if upper { 0x41 } else { 0x61 }) + value - 10
  }).unsafe_to_char()
}

///|
pub fn write_hex_byte(
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
pub fn dump_line(data : ArrayView[Byte], opts : Spec, offset : Int64) -> Bytes {
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
  Bytes::from_array(line[:display + data.length() + 1])
}
