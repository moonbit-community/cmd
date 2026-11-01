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
fn benchmark_window_byte(position : Int64) -> Byte {
  let mut value = (position % 32768L).to_int().reinterpret_as_uint() + 104729U
  value = value ^ (value << 13)
  value = value ^ (value >> 17)
  value = value ^ (value << 5)
  value.to_byte()
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

// Fixed adversarial streams exercise the shared decoder and fixture encoders only.
// They are not eligible real-source timing inputs.

///|
async test "explicit stored fixed and concatenated gzip fixture modes roundtrip across block boundaries" {
  let directory = @fs.tmpdir(prefix="cmd-gzip-modes-")
  defer @fs.rmdir(directory, recursive=true)
  let source = directory + "/source"
  @fs.write_file(source, Bytes::makei(131075, i => (i % 256).to_byte()))
  for mode in ["stored", "fixed-literals", "members"] {
    let encoded = directory + "/" + mode + ".gz"
    prepare_benchmark_gzip_input(mode, source, encoded, "unused", Map([]), 1000)
    let file = @fs.open(encoded, mode=ReadOnly)
    let header = file.read_exactly_at(11, position=0L)
    file.close()
    assert_eq(
      (header[10].to_int() >> 1) & 3,
      if mode == "fixed-literals" {
        1
      } else {
        0
      },
    )
    assert_true(gzip_roundtrip(encoded, source, directory + "/decoded"))
  }
  let empty = directory + "/empty"
  @fs.write_file(empty, b"")
  for mode in ["stored", "fixed-literals"] {
    let encoded = directory + "/empty-" + mode
    write_benchmark_gzip(empty, encoded, mode)
    assert_true(gzip_roundtrip(encoded, empty, directory + "/empty-decoded"))
  }
}

///|
async test "fixed backreference controls preserve overlap full-window distances tails and checksums" {
  let directory = @fs.tmpdir(prefix="cmd-fixed-backrefs-")
  defer @fs.rmdir(directory, recursive=true)
  for (shape, distance) in [("backref-one-v1", 1), ("backref-window-v1", 32768)] {
    let source = directory + "/" + shape
    @fs.write_file(
      source,
      Bytes::makei(131075, index => {
        if distance == 1 {
          b'a'
        } else {
          benchmark_window_byte(index.to_int64())
        }
      }),
    )
    let encoded = source + ".gz"
    write_benchmark_backref_gzip(source, encoded, distance)
    let compressed = @fs.open(encoded, mode=ReadOnly)
    let header = compressed.read_exactly_at(11, position=0L)
    compressed.close()
    assert_eq((header[10].to_int() >> 1) & 3, 1)
    assert_true(gzip_roundtrip(encoded, source, directory + "/decoded"))
    let decoded = @fs.open(directory + "/decoded", mode=ReadOnly)
    for at in [32767L, 32768L, 32769L, 65535L, 65536L, 65537L, 131074L] {
      let expected = if distance == 1 {
        b'a'
      } else {
        benchmark_window_byte(at)
      }
      assert_eq(
        decoded.read_exactly_at(1, position=at),
        Bytes::make(1, expected),
      )
    }
    decoded.close()
    let features = @json.parse(@fs.read_file(encoded + ".features.json").text())
    assert_true(
      features
      is { "deflate_block": String("fixed"), "source_validated": True, .. },
    )
    let checksum_source = @fs.open(encoded, mode=ReadOnly)
    let checksum_byte = checksum_source.read_exactly_at(
        1,
        position=@fs.file_size(encoded) - 8L,
      )[0]
    checksum_source.close()
    let corrupt = @fs.open(encoded, mode=WriteOnly)
    corrupt.write_at(
      Bytes::make(1, (checksum_byte.to_int() ^ 1).to_byte()),
      position=@fs.file_size(encoded) - 8L,
    )
    corrupt.close()
    let accepted = gzip_roundtrip(
      encoded,
      source,
      directory + "/corrupt-decoded",
    ) catch {
      _ => false
    }
    assert_false(accepted)
    @fs.write_file(encoded, b"preserve prior fixture")
    let wrong = directory + "/wrong"
    @fs.write_file(wrong, Bytes::make(32769, b'z'))
    let generated = Some(write_benchmark_backref_gzip(wrong, encoded, distance)) catch {
      _ => None
    }
    assert_true(generated is None)
    assert_eq(@fs.read_file(encoded).binary(), b"preserve prior fixture")
  }
}

///|
async test "gzip semantic relation accepts distinct valid streams and rejects payload mismatch or corruption" {
  let directory = @fs.tmpdir(prefix="cmd-gzip-relation-")
  defer @fs.rmdir(directory, recursive=true)
  let fixed = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x4b\x4c\x4a\x06\x00\xc2\x41\x24\x35\x03\x00\x00\x00"
  let stored = b"\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03\x01\x03\x00\xfc\xffabc\xc2\x41\x24\x35\x03\x00\x00\x00"
  assert_true(fixed != stored)
  @fs.write_file(directory + "/source", b"abc")
  for (name, encoded) in [("fixed", fixed), ("stored", stored)] {
    @fs.write_file(directory + "/" + name, encoded)
    assert_true(
      gzip_roundtrip(
        directory + "/" + name,
        directory + "/source",
        directory + "/decoded",
      ),
    )
  }
  @fs.write_file(directory + "/source", b"abd")
  assert_false(
    gzip_roundtrip(
      directory + "/stored",
      directory + "/source",
      directory + "/decoded",
    ),
  )
  @fs.write_file(directory + "/corrupt", b"not gzip data")
  let accepted = gzip_roundtrip(
    directory + "/corrupt",
    directory + "/source",
    directory + "/decoded",
  ) catch {
    _ => false
  }
  assert_false(accepted)
}
