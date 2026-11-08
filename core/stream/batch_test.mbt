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
