///|
async test "physical file read expansion preserves logical decoder and binary windows" {
  for count in [65532, 65535, 262140, 262143, 1048572, 1048575] {
    let input = b"hit\n" + Bytes::make(count, b'a') + b"\xe8\nhit\x00tail\nhit"
    for encoding in [None, Some("shift_jis"), Some("utf-8"), Some("utf-16le")] {
      for
        binary in [
          @searcher.BinaryNone,
          @searcher.BinaryQuit(b'\x00'),
          @searcher.BinaryConvert(b'\x00'),
        ] {
        assert_eq(
          span_output(
            input,
            "hit",
            true,
            chunk=1048576,
            initial_buffer=true,
            initial_capacity=1048576,
            encoding~,
            binary~,
            line_numbers=true,
          ),
          span_output(
            input,
            "hit",
            true,
            chunk=1048576,
            encoding~,
            binary~,
            line_numbers=true,
          ),
        )
      }
    }
  }
}

///|
async test "physical file read expansion keeps short-file probes small and grows only after a full block" {
  for size in [0, 5, 65535, 65536, 262144, 1048577] {
    let probe = FileReadProbe::{
      inner: @searcher.SliceReader::from_bytes(Bytes::make(size, b'x')),
      requests: [],
    }
    let reader = FileReadBuffer::new(probe, FixedArray::make(1048576, b'\x00'))
    let out = FixedArray::make(65536, b'\x00')
    let mut total = @searcher.Reader::read(reader, out, 0, 3)
    while @searcher.Reader::read(reader, out, 0, 65536) is n && n > 0 {
      total += n
    }
    assert_eq(total, size)
    assert_eq(probe.requests[0], 65536)
    if size < 65536 {
      assert_true(probe.requests.all(n => n == 65536))
    } else {
      assert_true(probe.requests[1] == 1048576)
    }
  }
}
