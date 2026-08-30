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
