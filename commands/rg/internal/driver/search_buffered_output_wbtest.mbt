///|
async test "buffered standard output preserves numbered records failures and decoding" {
  let cases = [
    b"skip\nhit one\nhit two\nskip\nhit three",
    b"\xef\xbb\xbfhit\r\nhit\r\nskip\r\nhit",
    b"\xff\xfeh\x00i\x00t\x00\n\x00h\x00i\x00t\x00",
    b"hit\n" + Bytes::make(8192, b'x') + b"hit\nhit\n",
    b"hit\n" + Bytes::make(65537, b'x') + b"hit\nhit\n",
    b"hit\nhit\x00tail\nhit\n",
  ]
  for input in cases {
    for
      term in [
        @matcher.LineTerminator::byte(b'\n'),
        @matcher.LineTerminator::crlf(),
        @matcher.LineTerminator::byte(b'\x00'),
      ] {
      for
        binary in [
          @searcher.BinaryNone,
          @searcher.BinaryQuit(b'\x00'),
          @searcher.BinaryConvert(b'\x00'),
        ] {
        for budget in [0, 1, 7, 8191, 8192, 1000000] {
          for line_buffered in [false, true] {
            let original = span_output(
              input,
              "hit",
              false,
              term~,
              binary~,
              budget~,
              partial=3,
              line_numbers=true,
              byte_offsets=true,
              path=Some("nested/file"),
              line_buffered~,
            )
            let buffered = span_output(
              input,
              "hit",
              true,
              term~,
              binary~,
              budget~,
              partial=3,
              line_numbers=true,
              byte_offsets=true,
              path=Some("nested/file"),
              line_buffered~,
            )
            assert_eq(buffered, original)
          }
        }
      }
    }
  }
  for chunk in [1, 3, 7, 65536] {
    let input = b"hit\nhit two\nmiss\nhit tail"
    assert_eq(
      span_output(
        input,
        "hit",
        true,
        chunk~,
        read_failure=true,
        line_numbers=true,
      ),
      span_output(
        input,
        "hit",
        false,
        chunk~,
        read_failure=true,
        line_numbers=true,
      ),
    )
    for max_matches in [Some(0L), Some(1L), Some(2L), None] {
      assert_eq(
        span_output(input, "hit", true, chunk~, line_numbers=true, max_matches~),
        span_output(
          input,
          "hit",
          false,
          chunk~,
          line_numbers=true,
          max_matches~,
        ),
      )
    }
  }
}
