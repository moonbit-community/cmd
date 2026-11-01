///|
priv struct FileReadProbe {
  inner : @searcher.SliceReader
  requests : Array[Int32]
}

///|
impl @searcher.Reader for FileReadProbe with fn read(self, buf, start, len) {
  self.requests.push(len)
  @searcher.Reader::read(self.inner, buf, start, len)
}

///|
async test "initial file buffering preserves chunk boundaries offsets and EOF" {
  let storage = FixedArray::make(65536, b'\x00')
  for size in [0, 1, 2, 3, 7, 8192, 65535, 65536, 65537, 262150] {
    let bytes = Bytes::makei(size, i => (i % 251).to_byte())
    let probe = FileReadProbe::{
      inner: @searcher.SliceReader::from_bytes(bytes),
      requests: [],
    }
    let reader = FileReadBuffer::new(probe, storage)
    let reference = @searcher.SliceReader::from_bytes(bytes)
    for wanted in [0, 3, 8192, 8192, 65533, 262144, 1, 0] {
      let left = FixedArray::make(wanted + 2, b'\xff')
      let right = FixedArray::make(wanted + 2, b'\xff')
      let a = @searcher.Reader::read(reader, left, 1, wanted)
      let b = @searcher.Reader::read(reference, right, 1, wanted)
      assert_eq(a, b)
      assert_eq(left, right)
    }
    assert_eq(probe.requests[0], 65536)
    if size < 65536 {
      assert_eq(probe.requests.length(), if size == 0 { 1 } else { 2 })
    }
  }
}

///|
async test "initial file buffering leaves large first requests unchanged" {
  let probe = FileReadProbe::{
    inner: @searcher.SliceReader::from_bytes(b"data"),
    requests: [],
  }
  let reader = FileReadBuffer::new(probe, FixedArray::make(8, b'\x00'))
  let output = FixedArray::make(32, b'\x00')
  assert_eq(@searcher.Reader::read(reader, output, 0, 32), 4)
  assert_eq(probe.requests, [32])
}

///|
async test "file prefix policy excludes early exits and non-search modes" {
  for options in [[], ["-c"], ["--count-matches"], ["--json"]] {
    let args = [..options, "hit", "."]
    let plan = ExecutionPlan::from_low_args(low(args))
    assert_true(plan.buffer_file_reads())
  }
  for
    options in [
      ["-q"],
      ["-l"],
      ["--files-without-match"],
      ["-m", "1"],
      ["--stop-on-nonmatch"],
    ] {
    let args = [..options, "hit", "."]
    let plan = ExecutionPlan::from_low_args(low(args))
    assert_false(plan.buffer_file_reads())
  }
}

///|
priv struct FileReadCancellation {
  mut reads : Int32
}

///|
impl @searcher.Reader for FileReadCancellation with fn read(self, buf, start, _) {
  self.reads += 1
  if self.reads == 1 {
    for i in 0..<5 {
      buf[start + i] = b'a'
    }
    5
  } else {
    @async.sleep(60000)
    0
  }
}

///|
async test "initial file buffering propagates cancellation after copying cached bytes" {
  let probe = FileReadCancellation::{ reads: 0, }
  let reader = FileReadBuffer::new(probe, FixedArray::make(8, b'\x00'))
  let output = FixedArray::make(8, b'\x00')
  assert_eq(@searcher.Reader::read(reader, output, 0, 3), 3)
  let returned = Ref(false)
  let result = @async.with_timeout_opt(10, () => {
    let count = @searcher.Reader::read(reader, output, 0, 8)
    returned.val = true
    count
  })
  assert_eq(result, None)
  assert_false(returned.val)
  assert_eq(probe.reads, 2)
}
