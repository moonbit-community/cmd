///|
const SHERLOCK : Bytes = b"For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached.\n"

///|
fn drive(format : Format, source : Bytes, stride : Int, capacity : Int) -> (Bytes, Status) raise {
  let decoder = Decoder::new(format)
  let output = FixedArray::make(capacity, b'\x00')
  let collected = @buffer.Buffer()
  let mut position = 0
  let mut available = 0
  let mut needs_input = true
  for iteration in 0..<1000000 {
    if needs_input && position == available && available < source.length() {
      available = (available + stride).min(source.length())
    }
    let result = decoder.step(source[position:available], output.mut_view(), end=available == source.length())
    assert_true(result.consumed >= 0 && result.consumed <= available - position)
    assert_true(result.produced >= 0 && result.produced <= capacity)
    position += result.consumed
    collected.write_bytes(Bytes::from_array(output[:result.produced]))
    needs_input = result.status is NeedInput
    match result.status {
      Done => { assert_eq(position, source.length()); return (collected.to_bytes(), Done) }
      Failed(message) => return (collected.to_bytes(), Failed(message))
      NeedInput => {
        assert_eq(position, available)
        assert_true(available < source.length(), msg="decoder requested input after physical EOF")
      }
      NeedOutput => assert_true(result.consumed > 0 || result.produced > 0, msg="no-progress decoder")
    }
    assert_true(iteration < 999999, msg="decoder did not terminate")
  }
  fail("unreachable decoder iteration limit")
}

///|
async test "all eight formats preserve frozen fixture bytes across tiny buffers" {
  let formats : Array[(Format, String)] = [(Gzip, "gz"), (Bzip2, "bz2"), (Lz4, "lz4"),
    (Brotli, "br"), (Zstd, "zst"), (Compress, "Z"), (Lzma, "lzma"), (Xz, "xz")]
  for (format, extension) in formats {
    let source = @fs.read_file("internal/codec/stream/testdata/sherlock." + extension).binary()
    for stride in [1, 2, 3, 7, 17, 64, 65536] {
      for capacity in [1, 7, 8192] {
        let (actual, status) = drive(format, source, stride, capacity)
        assert_eq(status, Done, msg="\{extension} stride=\{stride} capacity=\{capacity}")
        assert_eq(actual, SHERLOCK)
      }
    }
  }
}

///|
async test "concatenated framed formats survive every input boundary" {
  let formats : Array[(Format, String)] = [(Gzip, "gz"), (Bzip2, "bz2"), (Lz4, "lz4"), (Zstd, "zst")]
  for (format, extension) in formats {
    let source = @fs.read_file("internal/codec/stream/testdata/sherlock." + extension).binary()
    for stride in [1, 7, source.length(), source.length() + 1] {
      let (actual, status) = drive(format, source + source, stride, 17)
      assert_eq(status, Done, msg=extension)
      assert_eq(actual, SHERLOCK + SHERLOCK)
    }
  }
}

///|
test "gzip checksum failures retain all decoded bytes before the error" {
  let encoded = @gzip.compress(b"first line\nsecond line\n")
  let corrupted = Bytes::makei(encoded.length(), i => if i == encoded.length() - 8 {
    (encoded[i].to_int() ^ 1).to_byte()
  } else { encoded[i] })
  let (decoded, status) = drive(Gzip, corrupted, 1, 3)
  assert_eq(decoded, b"first line\nsecond line\n")
  assert_true(status is Failed(_))
}

///|
async test "truncated streams fail without replacing decoded output with raw bytes" {
  let formats : Array[(Format, String)] = [(Gzip, "gz"), (Bzip2, "bz2"), (Lz4, "lz4"), (Brotli, "br"), (Zstd, "zst"), (Lzma, "lzma")]
  for (format, extension) in formats {
    let source = @fs.read_file("internal/codec/stream/testdata/sherlock." + extension).binary()
    let (_, status) = drive(format, source[:source.length() - 1].to_owned(), 1, 7)
    assert_true(status is Failed(_), msg=extension)
  }
}
