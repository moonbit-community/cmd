///|
fn benchmark_gzip_input_mode(recipe : String?) -> String {
  match recipe {
    Some(value) => {
      for
        mode in [
          "stored", "fixed-literals", "native-dynamic", "members", "fixed-backref-one",
          "fixed-backref-window",
        ] {
        if value == "bench-gunzip-" + mode || value == "bench-zcat-" + mode {
          return mode
        }
      }
      "native-default"
    }
    None => "native-default"
  }
}

///|
fn fixture_crc32(crc : UInt32, byte : Byte) -> UInt32 {
  let mut value = crc ^ byte.to_uint()
  for _ in 0..<8 {
    value = (value >> 1) ^ (if (value & 1U) == 1U { 0xedb88320U } else { 0U })
  }
  value
}

///|
fn fixture_u32_le(value : UInt32) -> Bytes {
  Bytes::makei(4, i => (value >> (i * 8)).to_byte())
}

///|
priv struct FixtureBits {
  mut bits : UInt32
  mut count : Int32
  bytes : Array[Byte]
}

///|
fn FixtureBits::push(self : FixtureBits, value : UInt32, count : Int32) -> Unit {
  self.bits = self.bits | (value << self.count)
  self.count += count
  while self.count >= 8 {
    self.bytes.push(self.bits.to_byte())
    self.bits = self.bits >> 8
    self.count -= 8
  }
}

///|
fn fixture_reverse_bits(value : UInt32, count : Int32) -> UInt32 {
  let mut input = value
  let mut output = 0U
  for _ in 0..<count {
    output = (output << 1) | (input & 1U)
    input = input >> 1
  }
  output
}

///|
fn benchmark_window_byte(position : Int64) -> Byte {
  let mut value = (position % 32768L).to_int().reinterpret_as_uint() + 104729U
  value = value ^ (value << 13)
  value = value ^ (value >> 17)
  value = value ^ (value << 5)
  value.to_byte()
}

///|
fn fixture_fixed_symbol(bits : FixtureBits, symbol : Int32) -> Unit {
  let (code, width) = if symbol <= 143 {
    (48 + symbol, 8)
  } else if symbol <= 255 {
    (400 + symbol - 144, 9)
  } else if symbol <= 279 {
    (symbol - 256, 7)
  } else {
    (192 + symbol - 280, 8)
  }
  bits.push(fixture_reverse_bits(code.reinterpret_as_uint(), width), width)
}

///|
fn fixture_fixed_match(
  bits : FixtureBits,
  length : Int32,
  distance : Int32,
) -> Unit {
  let bases = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
    83, 99, 115, 131, 163, 195, 227, 258,
  ]
  let extras = [
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5,
    5, 5, 0,
  ]
  let mut code = 0
  for index in 0..<bases.length() {
    if bases[index] <= length {
      code = index
    }
  }
  fixture_fixed_symbol(bits, 257 + code)
  if extras[code] > 0 {
    bits.push((length - bases[code]).reinterpret_as_uint(), extras[code])
  }
  if distance == 1 {
    bits.push(0U, 5)
  } else {
    // Fixed distance symbol29 covers24577..32768 with13extra bits.
    bits.push(fixture_reverse_bits(29U, 5), 5)
    bits.push(8191U, 13)
  }
}

///|
// This fixture deliberately requests distance1 overlap or the full32768-byte
// window distance. Source validation prevents a misleading route label or a
// compressed fixture that reconstructs something other than its declared input.
async fn write_benchmark_backref_gzip(
  source : String,
  path : String,
  distance : Int32,
) -> Unit {
  guard distance == 1 || distance == 32768 else {
    fail("unsupported fixed backreference fixture distance")
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let size = input.size()
  guard size >= distance.to_int64() else {
    fail("backreference fixture needs its complete initial history")
  }
  let mut offset = 0L
  let mut crc = 0xffffffffU
  let mut isize = 0U
  while offset < size {
    let count = (size - offset).min(65536L).to_int()
    let bytes = input.read_exactly_at(count, position=offset)
    for index, byte in bytes {
      let expected = if distance == 1 {
        b'a'
      } else {
        benchmark_window_byte(offset + index.to_int64())
      }
      guard byte == expected else {
        fail(
          "backreference fixture source differs from its declared periodic distribution",
        )
      }
      crc = fixture_crc32(crc, byte)
    }
    isize += count.reinterpret_as_uint()
    offset += count.to_int64()
  }
  let output = @fs.create(path)
  defer output.close()
  output.write(b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03")
  let bits : FixtureBits = { bits: 0U, count: 0, bytes: [], }
  bits.push(3U, 3)
  let prefix = input.read_exactly_at(distance, position=0L)
  for byte in prefix {
    fixture_fixed_symbol(bits, byte.to_int())
  }
  let mut at = distance.to_int64()
  let mut matches = 0L
  while size - at >= 3L {
    let length = (size - at).min(258L).to_int()
    fixture_fixed_match(bits, length, distance)
    at += length.to_int64()
    matches += 1L
    if bits.bytes.length() >= 65536 {
      output.write(Bytes::from_array(bits.bytes))
      bits.bytes.clear()
    }
  }
  while at < size {
    fixture_fixed_symbol(
      bits,
      if distance == 1 {
        b'a'.to_int()
      } else {
        benchmark_window_byte(at).to_int()
      },
    )
    at += 1L
  }
  fixture_fixed_symbol(bits, 256)
  if bits.count > 0 {
    bits.bytes.push(bits.bits.to_byte())
  }
  output.write(Bytes::from_array(bits.bytes))
  output.write(fixture_u32_le(crc ^ 0xffffffffU))
  output.write(fixture_u32_le(isize))
  @fs.write_file(
    path + ".features.json",
    (
      {
        "deflate_block": "fixed",
        "distance": distance,
        "initial_literal_bytes": distance,
        "match_length_max": 258,
        "match_tokens": matches,
        "source_bytes": size,
        "source_validated": true,
      } : Json).stringify(indent=2),
  )
}

///|
// Independent test-data encoders deliberately select stored or literal-only
// fixed blocks. Their output is decoded by both actual programs outside the
// encoder setup and checked against the unchanged source bytes.
async fn write_benchmark_gzip(
  source : String,
  path : String,
  mode : String,
) -> Unit {
  guard mode == "stored" || mode == "fixed-literals" else {
    fail("unknown fixed gzip fixture mode")
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let size = input.size()
  let output = @fs.create(path)
  defer output.close()
  output.write(b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03")
  let mut crc = 0xffffffffU
  let mut isize = 0U
  let mut at = 0L
  let bits : FixtureBits = { bits: 0U, count: 0, bytes: [], }
  if mode == "fixed-literals" {
    bits.push(3U, 3)
  }
  while at < size || (size == 0L && at == 0L) {
    let count = (size - at).min(65535L).to_int()
    let bytes = input.read_exactly_at(count, position=at)
    if mode == "stored" {
      output.write(
        Bytes::from_array([
          if at + count.to_int64() == size {
            b'\x01'
          } else {
            b'\x00'
          },
          count.to_byte(),
          (count >> 8).to_byte(),
          (count ^ 0xffff).to_byte(),
          ((count ^ 0xffff) >> 8).to_byte(),
        ]),
      )
      output.write(bytes)
    }
    for byte in bytes {
      crc = fixture_crc32(crc, byte)
      if mode == "fixed-literals" {
        let number = byte.to_int()
        let (code, width) = if number <= 143 {
          ((48 + number).reinterpret_as_uint(), 8)
        } else {
          ((400 + number - 144).reinterpret_as_uint(), 9)
        }
        bits.push(fixture_reverse_bits(code, width), width)
      }
    }
    if mode == "fixed-literals" && !bits.bytes.is_empty() {
      output.write(Bytes::from_array(bits.bytes))
      bits.bytes.clear()
    }
    isize += count.reinterpret_as_uint()
    at += count.to_int64()
    if size == 0L {
      break
    }
  }
  if mode == "fixed-literals" {
    bits.push(0U, 7)
    if bits.count > 0 {
      bits.bytes.push(bits.bits.to_byte())
    }
    output.write(Bytes::from_array(bits.bytes))
  }
  output.write(fixture_u32_le(crc ^ 0xffffffffU))
  output.write(fixture_u32_le(isize))
}

///|
async fn prepare_benchmark_gzip_input(
  mode : String,
  source : String,
  encoded : String,
  oracle : String,
  environment : Map[String, String],
  timeout_ms : Int32,
) -> Unit {
  if mode == "fixed-backref-one" || mode == "fixed-backref-window" {
    write_benchmark_backref_gzip(
      source,
      encoded,
      if mode == "fixed-backref-one" {
        1
      } else {
        32768
      },
    )
  } else if mode == "stored" || mode == "fixed-literals" {
    write_benchmark_gzip(source, encoded, mode)
  } else if mode == "members" {
    let input = @fs.open(source, mode=ReadOnly)
    let size = input.size()
    input.close()
    let output = @fs.create(encoded)
    defer output.close()
    let split = size / 2L
    for (number, start, length) in [(0, 0L, split), (1, split, size - split)] {
      let part = encoded + ".plain-" + number.to_string()
      let file = @fs.create(part)
      copy_recipe_range(source, file, start, length)
      file.close()
      let gzip_member = encoded + ".member-" + number.to_string()
      write_benchmark_gzip(
        part,
        gzip_member,
        if number == 0 {
          "stored"
        } else {
          "fixed-literals"
        },
      )
      copy_recipe_range(gzip_member, output, 0L, @fs.file_size(gzip_member))
      @fs.remove(part)
      @fs.remove(gzip_member)
    }
  } else {
    guard mode == "native-default" || mode == "native-dynamic" else {
      fail("unknown compressed input fixture")
    }
    corpus_observer(
      oracle + "/gzip",
      ["-n", "-c"],
      source,
      encoded,
      environment,
      timeout_ms,
    )
    if mode == "native-dynamic" {
      let file = @fs.open(encoded, mode=ReadOnly)
      defer file.close()
      let first = file.read_exactly_at(11, position=0L)
      guard first[:4] == b"\x1f\x8b\x08\x00"[:] &&
        ((first[10].to_int() >> 1) & 3) == 2 else {
        fail(
          "native-dynamic fixture did not begin with the declared dynamic block",
        )
      }
    }
  }
}
