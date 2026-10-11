///|
async test "POSIX CRC-32 vectors include the input length" {
  let empty = @io.MemoryReader(writer => writer.write(b""))
  assert_eq(checksum_reader(empty), (0xFFFFFFFFUL, 0UL))
  let hello = @io.MemoryReader(writer => writer.write(b"hello\n"))
  assert_eq(checksum_reader(hello), (3015617425UL, 6UL))
  let digits = @io.MemoryReader(writer => writer.write(b"123456789"))
  assert_eq(checksum_reader(digits), (930766865UL, 9UL))
}

///|
test "length bytes are folded from low to high order" {
  let empty_crc = 0UL
  assert_eq(crc_length(empty_crc, 0UL), 0xFFFFFFFFUL)
  assert_eq(crc_length(empty_crc, 1UL), 4215202376UL)
}
