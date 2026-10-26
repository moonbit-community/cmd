///|
async test "vector counters agree with scalar counting for all bytes and boundary offsets" {
  for padding in 0..<32 {
    let data = Bytes::make(padding, b'x') +
      Bytes::makei(1024, index => (index % 256).to_byte()) +
      b"tail"
    let mut lines = 0L
    let mut words = 0L
    let mut in_word = false
    for byte in data {
      if byte == b'\n' {
        lines += 1L
      }
      if is_space_byte(byte) {
        in_word = false
      } else if !in_word {
        words += 1L
        in_word = true
      }
    }
    for split in [1, 15, 16, 17, 31, 32, 33, 1000] {
      let reader = @io.MemoryReader(writer => {
        writer.write(data[:split])
        writer.write(data[split:])
      })
      defer reader.close()
      let counts = count_reader(reader, {
        lines: true,
        words: true,
        chars: true,
        bytes: true,
        max_line_length: false,
      })
      assert_eq(counts.lines, lines)
      assert_eq(counts.words, words)
      assert_eq(counts.bytes, data.length().to_int64())
      assert_eq(counts.chars, counts.bytes)
    }
  }
}

///|
async test "vector word carry survives one MiB reads and unterminated records" {
  for separator in [b"", b" ", b"\t", b"\n", b"\x0b", b"\x0c", b"\r"] {
    let input = Bytes::make(1048575, b'x') + separator + b"tail"
    let reader = @io.MemoryReader(writer => writer.write(input))
    defer reader.close()
    let counts = count_reader(reader, {
      lines: true,
      words: true,
      chars: false,
      bytes: true,
      max_line_length: false,
    })
    assert_eq(counts.words, if separator.is_empty() { 1L } else { 2L })
    assert_eq(counts.lines, if separator == b"\n" { 1L } else { 0L })
    assert_eq(counts.bytes, input.length().to_int64())
  }
}
