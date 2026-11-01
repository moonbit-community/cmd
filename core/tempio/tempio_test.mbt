///|
async test "temporary directories are exclusive, scoped and idempotently cleaned" {
  let parent = @tempio.Directory::new(prefix="cmd-tempio-test-")
  defer parent.close()
  let a = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  let b = @tempio.Directory::new(prefix="child-", parent=Some(parent.path()))
  assert_true(a.path() != b.path())
  @fs.write_file(a.path() + "/record", b"data")
  a.close()
  a.close()
  b.close()
  assert_eq(@fs.readdir(parent.path()).length(), 0)
}

///|
async test "range copy preserves exact offsets and rejects incomplete extents" {
  let root = @tempio.Directory::new(prefix="cmd-range-test-")
  defer root.close()
  @fs.write_file(root.path() + "/data", b"prefix-data-tail")
  let file = @fs.open(root.path() + "/data", mode=ReadOnly)
  defer file.close()
  let output = RangeOutput::{ bytes: [], }
  @tempio.copy_range(file, 7L, 11L, FixedArray::make(3, b'\x00'), output)
  assert_eq(Bytes::from_array(output.bytes), b"data")
  let failed = try {
    @tempio.copy_range(file, 0L, 100L, FixedArray::make(8, b'\x00'), output)
    false
  } catch {
    @io.ReaderClosed => true
    _ => false
  }
  assert_true(failed)
}

///|
priv struct RangeOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for RangeOutput with fn write_once(self, bytes, offset~, len~) {
  for index in offset..<(offset + len) {
    self.bytes.push(bytes[index])
  }
  len
}
