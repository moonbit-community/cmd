///|
async test "line scanner preserves final-line termination" {
  let reader = @io.MemoryReader(writer => writer.write(b"one\ntwo"))
  defer reader.close()
  let scanner = LineScanner::new(reader)
  assert_eq(scanner.next(), Some({ data: b"one", terminated: true, }))
  assert_eq(scanner.next(), Some({ data: b"two", terminated: false, }))
  assert_eq(scanner.next(), None)
}

///|
async test "line scanner reports an empty terminated line" {
  let reader = @io.MemoryReader(writer => writer.write(b"\n"))
  defer reader.close()
  let scanner = LineScanner::new(reader)
  assert_eq(scanner.next(), Some({ data: b"", terminated: true, }))
  assert_eq(scanner.next(), None)
}

///|
async test "line scanner preserves records across refills and custom delimiters" {
  let long_line = Bytes::make(chunk_size * 2 + 7, b'x')
  let reader = @io.MemoryReader(writer => {
    writer.write(b"a\x00\x00")
    writer.write(long_line)
    writer.write(b"\x00tail")
  })
  defer reader.close()
  let scanner = LineScanner::new(reader, delimiter=b'\x00')
  let first = scanner.next()
  assert_eq(first, Some({ data: b"a", terminated: true, }))
  assert_eq(scanner.next(), Some({ data: b"", terminated: true, }))
  assert_eq(scanner.next(), Some({ data: long_line, terminated: true, }))
  assert_eq(scanner.next(), Some({ data: b"tail", terminated: false, }))
  assert_eq(scanner.next(), None)
  assert_eq(scanner.next(), None)
  assert_eq(first, Some({ data: b"a", terminated: true, }))
}
