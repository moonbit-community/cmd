///|
test "UTF-8 counter preserves incomplete trailing sequences" {
  let first = count_utf8_chars(b"ascii\xc3", false)
  assert_eq(first, (5L, 5))
  let completed = count_utf8_chars(b"\xc3\xa9", true)
  assert_eq(completed, (1L, 2))
}

///|
test "UTF-8 counter skips malformed input" {
  assert_eq(count_utf8_chars(b"a\xffb", true), (2L, 3))
}

///|
async test "selected counters preserve words widths and split UTF-8" {
  let data = b"one\ttwo\n\xc3\xa9 \xffx\nlast\xf0\x90"
  let selections : Array[Selection] = [
    {
      lines: true,
      words: true,
      chars: true,
      bytes: true,
      max_line_length: true,
    },
    {
      lines: true,
      words: false,
      chars: false,
      bytes: false,
      max_line_length: false,
    },
    {
      lines: false,
      words: false,
      chars: false,
      bytes: true,
      max_line_length: false,
    },
    {
      lines: false,
      words: false,
      chars: true,
      bytes: false,
      max_line_length: false,
    },
  ]
  for selection in selections {
    let reader = @io.MemoryReader(writer => {
      writer.write(data[:9])
      writer.write(data[9:])
    })
    defer reader.close()
    let counts = count_reader(reader, selection)
    assert_eq(counts.lines, if selection.lines { 2L } else { 0L })
    assert_eq(counts.words, if selection.words { 5L } else { 0L })
    assert_eq(counts.chars, if selection.chars { 16L } else { 0L })
    assert_eq(
      counts.bytes,
      if selection.bytes {
        data.length().to_int64()
      } else {
        0L
      },
    )
    assert_eq(
      counts.max_line_length,
      if selection.max_line_length {
        11L
      } else {
        0L
      },
    )
  }
}
