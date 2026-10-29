///|
priv struct OutputProbe {
  bytes : Array[Byte]
  mut calls : Int32
  limit : Int32
  fail_after : Int32
}

///|
async test "synchronous output admission is atomic and retains failure state" {
  let sink = OutputProbe::{ bytes: [], calls: 0, limit: 2, fail_after: 100, }
  let output = @stream.BlockWriter::new(sink, size=8)
  assert_true(output.try_write_slice(b"abc".to_fixedarray(), 0, 3))
  assert_false(output.try_write_slice(b"123456".to_fixedarray(), 0, 6))
  assert_eq(sink.calls, 0)
  output.flush()
  assert_eq(Bytes::from_array(sink.bytes), b"abc")
  let line = @stream.BlockWriter::new(sink, size=8, line_buffered=true)
  assert_false(line.try_write_slice(b"line\n".to_fixedarray(), 0, 5))
  line.flush()
  assert_eq(Bytes::from_array(sink.bytes), b"abc")
  let broken = OutputProbe::{ bytes: [], calls: 0, limit: 2, fail_after: 1, }
  let output = @stream.BlockWriter::new(broken, size=8)
  assert_true(output.try_write_slice(b"abcdef".to_fixedarray(), 0, 6))
  assert_true(
    try {
      output.flush()
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(output.try_write_slice(b"retry".to_fixedarray(), 0, 5))
      false
    } catch {
      _ => true
    },
  )
  output.flush()
  assert_eq(Bytes::from_array(broken.bytes), b"ab")
  assert_eq(broken.calls, 2)
}

///|
impl @io.Writer for OutputProbe with fn write_once(self, bytes, offset~, len~) {
  self.calls += 1
  if self.calls > self.fail_after {
    fail("injected output failure")
  }
  let count = len.min(self.limit)
  for index in offset..<(offset + count) {
    self.bytes.push(bytes[index])
  }
  count
}

///|
async test "shared output preserves slices, partial writes and line buffering" {
  let sink = OutputProbe::{ bytes: [], calls: 0, limit: 3, fail_after: 100, }
  let output = @stream.BlockWriter::new(sink, size=8, line_buffered=true)
  output.write_bytes(b"a")
  assert_eq(sink.calls, 0)
  output.write_slice([b'x', b'b', b'\n', b'y'], 1, 3)
  assert_eq(Bytes::from_array(sink.bytes), b"ab\n")
  output.write_bytes(b"0123456789")
  output.write_bytes(b"tail")
  output.flush()
  output.flush()
  assert_eq(Bytes::from_array(sink.bytes), b"ab\n0123456789tail")
}

///|
async test "failed shared output never replays a partially written prefix" {
  let sink = OutputProbe::{ bytes: [], calls: 0, limit: 2, fail_after: 1, }
  let output = @stream.BlockWriter::new(sink, size=8)
  output.write_bytes(b"abcdef")
  let failed = try {
    defer output.flush()
    output.flush()
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(Bytes::from_array(sink.bytes), b"ab")
  assert_eq(sink.calls, 2)
  let failed = try {
    output.write_bytes(b"retry")
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(sink.calls, 2)
}

///|
priv struct ReentrantOutput {
  owner : Ref[@stream.BlockWriter?]
  bytes : Array[Byte]
  rejected : Ref[Bool]
}

///|
impl @io.Writer for ReentrantOutput with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  self.rejected.val = try {
    self.owner.val.unwrap().write_bytes(b"overwrite")
    false
  } catch {
    _ => true
  }
  for index in offset..<(offset + len) {
    self.bytes.push(bytes[index])
  }
  len
}

///|
async test "an in-flight output block cannot be overwritten by reentrant writes" {
  let sink = ReentrantOutput::{
    owner: Ref(None),
    bytes: [],
    rejected: Ref(false),
  }
  let output = @stream.BlockWriter::new(sink, size=8)
  sink.owner.val = Some(output)
  output.write_bytes(b"stable")
  output.flush()
  assert_true(sink.rejected.val)
  assert_eq(Bytes::from_array(sink.bytes), b"stable")
}

///|
priv struct SuspendedOutput {
  calls : Ref[Int32]
}

///|
impl @io.Writer for SuspendedOutput with fn write_once(self, _, offset~, len~) {
  ignore(offset)
  self.calls.val += 1
  @async.sleep(10000)
  len
}

///|
async test "cancelled flush consumes its queue without a second write" {
  let sink = SuspendedOutput::{ calls: Ref(0), }
  let output = @stream.BlockWriter::new(sink, size=8)
  output.write_bytes(b"pending")
  assert_true(@async.with_timeout_opt(20, () => output.flush()) is None)
  output.flush()
  assert_eq(sink.calls.val, 1)
}

///|
async test "shared output copies offset views and owns queued caller storage" {
  let sink = OutputProbe::{ bytes: [], calls: 0, limit: 3, fail_after: 100, }
  let output = @stream.BlockWriter::new(sink, size=32)
  output.write_bytes(b"prefix-0123456789abcdefghi-suffix"[7:26])
  let caller : FixedArray[Byte] = [b'x', b'y', b'z']
  output.write_slice(caller, 0, 3)
  caller[0] = b'!'
  output.flush()
  assert_eq(Bytes::from_array(sink.bytes), b"0123456789abcdefghixyz")
}

///|
async test "buffered output equals concatenation across capacities and fragment kinds" {
  for size in [0, 1, 2, 8, 16, 17, 32] {
    for line_buffered in [false, true] {
      let sink = OutputProbe::{
        bytes: [],
        calls: 0,
        limit: 3,
        fail_after: 100000,
      }
      let output = @stream.BlockWriter::new(sink, size~, line_buffered~)
      let expected : Array[Byte] = []
      for index, length in [0, 1, 2, 15, 16, 17, 33, 129] {
        let bytes = Bytes::makei(length + 6, i => {
          ((i * 17 + index) % 256).to_byte()
        })
        let view = bytes[3:3 + length]
        if index % 2 == 0 {
          output.write_bytes(view)
        } else {
          let data = FixedArray::makei(bytes.length(), i => bytes[i])
          output.write_slice(data, 3, 3 + length)
          data.fill(b'!')
        }
        for byte in view {
          expected.push(byte)
        }
        output.write_bytes(b"\r\n\x00\xff")
        expected.append([b'\r', b'\n', b'\x00', b'\xff'])
        if index % 3 == 0 {
          output.flush()
          assert_eq(Bytes::from_array(sink.bytes), Bytes::from_array(expected))
        }
      }
      output.flush()
      assert_eq(Bytes::from_array(sink.bytes), Bytes::from_array(expected))
    }
  }
}
