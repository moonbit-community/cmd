///|
async test "initial file buffering preserves BOM binary windows legacy decoding and read failures" {
  for
    input in [
      b"hit\nhit two\nlast hit",
      b"\xef\xbb\xbfhit\nhit two\n",
      b"\xff\xfeh\x00i\x00t\x00\n\x00h\x00i\x00t\x00",
      b"h\n\x00hit\nhit\n",
      b"hi\nhit\x00tail\nhit\n",
      b"hit\n" + Bytes::make(65530, b'x') + b"hit\nhit tail",
    ] {
    for
      binary in [
        @searcher.BinaryNone,
        @searcher.BinaryQuit(b'\x00'),
        @searcher.BinaryConvert(b'\x00'),
      ] {
      for read_failure in [false, true] {
        assert_eq(
          span_output(
            input,
            "hit",
            true,
            binary~,
            read_failure~,
            line_numbers=true,
            initial_buffer=true,
          ),
          span_output(
            input,
            "hit",
            true,
            binary~,
            read_failure~,
            line_numbers=true,
          ),
        )
      }
    }
  }
  for
    encoding in [
      "big5", "euc-kr", "shift_jis", "gbk", "utf-8", "utf-16le", "utf-16be",
    ] {
    for count in [1, 3, 4, 8190, 8191, 8192, 65532, 65533, 65534, 65536] {
      let input = Bytes::make(count, b'a') + b"\xe8"
      assert_eq(
        span_output(
          input,
          ".",
          false,
          encoding=Some(encoding),
          initial_buffer=true,
        ),
        span_output(input, ".", false, encoding=Some(encoding)),
      )
    }
  }
}
