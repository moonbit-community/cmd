///|
async test "C profile counts every byte across a 64 KiB read boundary" {
  let boundary = @stream.chunk_size
  let data = Bytes::make(boundary - 1, b'a') + b"\xc3\xa9\xff\n"
  let reader = @io.MemoryReader(writer => {
    writer.write(data[:boundary])
    writer.write(data[boundary:])
  })
  defer reader.close()
  let selection : Selection = {
    lines: false,
    words: false,
    chars: true,
    bytes: false,
    max_line_length: false,
  }
  let counts = count_reader(reader, selection)
  assert_eq(counts.chars, data.length().to_int64())
  assert_eq(counts.bytes, 0L)
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
    assert_eq(
      counts.chars,
      if selection.chars {
        data.length().to_int64()
      } else {
        0L
      },
    )
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

///|
async test "wc retains partial counters after a read error" {
  let reader = @io.MemoryReader(writer => {
    @async.pause()
    writer.write(b"one\nlong")
    @async.pause()
    fail("injected read failure")
  })
  defer reader.close()
  let selection : Selection = {
    lines: true,
    words: true,
    chars: true,
    bytes: true,
    max_line_length: true,
  }
  let (counts, error) = read_counted(reader, "input", selection)
  assert_true(error is Some(_))
  let counts = counts.unwrap()
  assert_eq(
    (
      counts.lines,
      counts.words,
      counts.chars,
      counts.bytes,
      counts.max_line_length,
    ),
    (1L, 2L, 8L, 8L, 4L),
  )
}
