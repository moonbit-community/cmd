///|
// RFC 1951 decoder. Keeping the bit cursor here makes output produced before
// truncated input observable, including when no full trailer remains to prefetch.
priv struct Bits {
  data : Bytes
  mut position : Int32
  mut pending : UInt32
  mut available : Int32
}

///|
fn Bits::take(self : Bits, count : Int32) -> Int32 raise {
  while self.available < count {
    guard self.position < self.data.length() else {
      fail("unexpected end of file")
    }
    self.pending = self.pending |
      (self.data[self.position].to_uint() << self.available)
    self.position += 1
    self.available += 8
  }
  let value = self.pending & ((1U << count) - 1U)
  self.pending = self.pending >> count
  self.available -= count
  value.reinterpret_as_int()
}

///|
fn Bits::align(self : Bits) -> Unit {
  self.pending = 0U
  self.available = 0
}

///|
priv struct Huffman {
  codes : Map[Int32, Int32]
  width : Int32
}

///|
fn huffman(lengths : Array[Int32], strict~ : Bool = false) -> Huffman raise {
  let counts = Array::make(16, 0)
  let mut width = 0
  for length in lengths {
    guard length >= 0 && length <= 15 else {
      fail("invalid Huffman code length")
    }
    if length > 0 {
      counts[length] += 1
      if length > width {
        width = length
      }
    }
  }
  let next = Array::make(16, 0)
  let mut space = 1
  let mut code = 0
  for length in 1..<=15 {
    space = space * 2 - counts[length]
    guard space >= 0 else { fail("oversubscribed Huffman tree") }
    code = (code + counts[length - 1]) << 1
    next[length] = code
  }
  if space > 0 && (strict || (width != 0 && width != 1)) {
    fail("incomplete Huffman tree")
  }
  let codes : Map[Int32, Int32] = Map([])
  for symbol, length in lengths {
    if length == 0 {
      continue
    }
    let mut reversed = 0
    let mut value = next[length]
    for _ in 0..<length {
      reversed = (reversed << 1) | (value & 1)
      value = value >> 1
    }
    next[length] += 1
    codes[(length << 16) | reversed] = symbol
  }
  { codes, width, }
}

///|
fn Huffman::read(self : Huffman, bits : Bits) -> Int32 raise {
  let mut code = 0
  for length in 1..<=self.width {
    code = code | (bits.take(1) << (length - 1))
    if self.codes.get((length << 16) | code) is Some(symbol) {
      return symbol
    }
  }
  fail("invalid Huffman code")
}

///|
fn fixed_trees() -> (Huffman, Huffman) raise {
  let lengths = Array::makei(288, symbol => {
    if symbol <= 143 {
      8
    } else if symbol <= 255 {
      9
    } else if symbol <= 279 {
      7
    } else {
      8
    }
  })
  (huffman(lengths), huffman(Array::make(32, 5)))
}

///|
fn dynamic_trees(bits : Bits) -> (Huffman, Huffman) raise {
  let literal_count = bits.take(5) + 257
  let distance_count = bits.take(5) + 1
  let code_count = bits.take(4) + 4
  guard literal_count <= 286 else { fail("invalid literal code count") }
  let order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]
  let code_lengths = Array::make(19, 0)
  for index in 0..<code_count {
    code_lengths[order[index]] = bits.take(3)
  }
  let tree = huffman(code_lengths, strict=true)
  let total = literal_count + distance_count
  let lengths : Array[Int32] = []
  while lengths.length() < total {
    let symbol = tree.read(bits)
    let (value, count) = match symbol {
      0..<=15 => (symbol, 1)
      16 => {
        guard !lengths.is_empty() else { fail("missing previous code length") }
        (lengths[lengths.length() - 1], bits.take(2) + 3)
      }
      17 => (0, bits.take(3) + 3)
      18 => (0, bits.take(7) + 11)
      _ => fail("invalid code-length symbol")
    }
    guard count <= total - lengths.length() else {
      fail("code-length repeat exceeds tree")
    }
    for _ in 0..<count {
      lengths.push(value)
    }
  }
  guard lengths[256] > 0 else { fail("missing end-of-block code") }
  (
    huffman(lengths[:literal_count].to_owned()),
    huffman(lengths[literal_count:].to_owned()),
  )
}

///|
let crc_table : FixedArray[UInt32] = FixedArray::makei(256, index => {
  let mut value = index.reinterpret_as_uint()
  for _ in 0..<8 {
    value = (value >> 1) ^ (if (value & 1U) == 0U { 0U } else { 0xedb88320U })
  }
  value
})

///|
fn update_crc(crc : UInt32, byte : Byte) -> UInt32 {
  (crc >> 8) ^ crc_table[((crc ^ byte.to_uint()) & 0xffU).reinterpret_as_int()]
}

///|
priv struct InflateOutput {
  window : FixedArray[Byte]
  mut cursor : Int32
  mut history : Int32
  mut crc : UInt32
  mut size : UInt32
  pending : Array[Byte]
  writer : &@io.Writer
  test_only : Bool
}

///|
async fn InflateOutput::push(self : InflateOutput, byte : Byte) -> Unit {
  self.window[self.cursor] = byte
  self.cursor = (self.cursor + 1) & 32767
  if self.history < 32768 {
    self.history += 1
  }
  self.crc = update_crc(self.crc, byte)
  self.size += 1U
  if !self.test_only {
    self.pending.push(byte)
    if self.pending.length() >= 65536 {
      flush_pending(self.pending, self.writer)
    }
  }
}

///|
let length_base : ReadOnlyArray[Int32] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra : ReadOnlyArray[Int32] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

///|
let distance_base : ReadOnlyArray[Int32] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let distance_extra : ReadOnlyArray[Int32] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
async fn compressed_block(
  bits : Bits,
  literal : Huffman,
  distance : Huffman,
  output : InflateOutput,
) -> Unit {
  for ;; {
    let symbol = literal.read(bits)
    if symbol < 256 {
      output.push(symbol.to_byte())
    } else if symbol == 256 {
      return
    } else {
      guard symbol <= 285 else { fail("invalid length symbol") }
      let length = length_base[symbol - 257] +
        bits.take(length_extra[symbol - 257])
      let distance_symbol = distance.read(bits)
      guard distance_symbol < 30 else { fail("invalid distance symbol") }
      let count = distance_base[distance_symbol] +
        bits.take(distance_extra[distance_symbol])
      guard count <= output.history else {
        fail("distance exceeds output history")
      }
      for _ in 0..<length {
        output.push(output.window[(output.cursor - count) & 32767])
      }
    }
  }
}

///|
async fn inflate(
  data : Bytes,
  start : Int32,
  writer : &@io.Writer,
  test_only : Bool,
) -> (Int32, UInt32, UInt32) {
  let bits : Bits = { data, position: start, pending: 0U, available: 0, }
  let output : InflateOutput = {
    window: FixedArray::make(32768, b'\x00'),
    cursor: 0,
    history: 0,
    crc: 0xffffffffU,
    size: 0U,
    pending: [],
    writer,
    test_only,
  }
  errdefer flush_pending(output.pending, writer)
  let mut is_last = false
  while !is_last {
    is_last = bits.take(1) != 0
    match bits.take(2) {
      0 => {
        bits.align()
        let length = bits.take(16)
        guard (length ^ bits.take(16)) == 0xffff else {
          fail("invalid stored-block length")
        }
        for _ in 0..<length {
          output.push(bits.take(8).to_byte())
        }
      }
      1 => {
        let (literal, distance) = fixed_trees()
        compressed_block(bits, literal, distance, output)
      }
      2 => {
        let (literal, distance) = dynamic_trees(bits)
        compressed_block(bits, literal, distance, output)
      }
      _ => fail("reserved deflate block type")
    }
  }
  bits.align()
  flush_pending(output.pending, writer)
  (bits.position, output.crc ^ 0xffffffffU, output.size)
}
