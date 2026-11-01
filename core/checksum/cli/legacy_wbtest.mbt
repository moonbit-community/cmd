///|
async test "legacy digest encodings preserve GNU checksums and byte counts" {
  for
    (algorithm, bits, expected) in [
      (@checksum.Bsd, 16, "08288     1 payload\n"),
      (Sysv, 16, "304 1 payload\n"),
      (Crc, 32, "1112837078 4 payload\n"),
      (Crc32b, 32, "1200128334 4 payload\n"),
    ] {
    let spec : DigestSpec = { algorithm, bits, }
    let reader = @io.MemoryReader(writer => writer.write(b"abc\n"))
    defer reader.close()
    let (digest, _) = @checksum.digest_reader(spec, reader)
    assert_eq(
      output_record(
        spec, digest, 4UL, "payload", false, true, false, false, false,
      ),
      expected,
    )
  }
}
