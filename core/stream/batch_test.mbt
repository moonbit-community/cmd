///|
async test "batch visitor resumes after every stop and interleaves with next" {
  let long = Bytes::make(1048581, b'x')
  let reader = @io.MemoryReader(writer => {
    writer.write(b"a\x00\x00four\x00" + long + b"\x00tail")
  })
  defer reader.close()
  let scanner = @stream.RecordReader::new(reader, delimiter=b'\x00')
  let data : Array[BytesView] = []
  let endings : Array[Bool] = []
  while scanner.next_batch() is Some(batch) {
    while !batch.each_while((line, terminated) => {
            data.push(line)
            endings.push(terminated)
            false
          }) {
      if batch.next() is Some(record) {
        data.push(record.data)
        endings.push(record.terminated)
      }
    }
    let mut called = false
    assert_true(
      batch.each_while((_, _) => {
        called = true
        false
      }),
    )
    assert_true(!called)
  }
  assert_eq(data.map(view => view.to_owned()), [
    b"a", b"", b"four", long, b"tail",
  ])
  assert_eq(endings, [true, true, true, true, false])
}

///|
test "word-at-a-time byte counts match scalar counts in offset views" {
  let source = Bytes::makei(1050, index => (index % 256).to_byte())
  for needle in 0..<256 {
    for offset in 0..<16 {
      for length in [0, 1, 7, 8, 9, 15, 16, 17, 1024] {
        let view = source[offset:offset + length]
        let mut expected = 0
        for byte in view {
          if byte == needle.to_byte() {
            expected += 1
          }
        }
        assert_eq(@stream.count_byte(view, needle.to_byte()), expected)
      }
    }
  }
  for needle in 0..<256 {
    let data = Bytes::makei(64, index => (needle ^ (index % 2)).to_byte())
    assert_eq(@stream.count_byte(data, needle.to_byte()), 32)
    assert_eq(
      @stream.count_byte(Bytes::make(32, needle.to_byte()), needle.to_byte()),
      32,
    )
  }
}
