///|
async test "source-derived partition proofs reject wrong boundaries despite identical concatenation" {
  let root = @fs.tmpdir(prefix="cmd-partition-proof-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(
    root + "/source",
    b"before\nSECTION one\nbody\nSECTION two\ntail",
  )
  @fs.mkdir(root + "/pieces")
  @fs.write_file(root + "/pieces/part-00", b"before\n")
  @fs.write_file(root + "/pieces/part-01", b"SECTION one\nbody\n")
  @fs.write_file(root + "/pieces/part-02", b"SECTION two\ntail")
  assert_eq(
    check_partition_source(
      root + "/pieces",
      root + "/source",
      Some(b"SECTION "),
    ),
    [],
  )
  @fs.write_file(root + "/pieces/part-00", b"before\nS")
  @fs.write_file(root + "/pieces/part-01", b"ECTION one\nbody\n")
  assert_false(
    check_partition_source(
      root + "/pieces",
      root + "/source",
      Some(b"SECTION "),
    ).is_empty(),
  )
}

///|
async test "byte partition proof rejects extra empty fragments and covers empty input" {
  let root = @fs.tmpdir(prefix="cmd-byte-partition-proof-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/source", b"abc")
  @fs.mkdir(root + "/pieces")
  @fs.write_file(root + "/pieces/part-aa", b"abc")
  assert_eq(check_partition_source(root + "/pieces", root + "/source", None), [])
  @fs.write_file(root + "/pieces/part-ab", b"")
  assert_false(
    check_partition_source(root + "/pieces", root + "/source", None).is_empty(),
  )
  @fs.write_file(root + "/empty", b"")
  @fs.mkdir(root + "/none")
  assert_eq(check_partition_source(root + "/none", root + "/empty", None), [])
  @fs.write_file(root + "/none/part-aa", b"")
  assert_false(
    check_partition_source(root + "/none", root + "/empty", None).is_empty(),
  )
}
